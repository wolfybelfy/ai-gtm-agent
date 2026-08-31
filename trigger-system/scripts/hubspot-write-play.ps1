# hubspot-write-play.ps1 - drains staging\hubspot\outbox\*.jsonl into HubSpot using the v1.2
# play-record model (staging\SCHEMAS.md): per play -> ONE immutable note (assoc to company,
# typeId 190 VERIFIED) + ONE task (default association, date-pinned endpoint VERIFIED) +
# PATCH of the ts_ summary props (allowlisted). Idempotency: a line with applied_date set is
# never re-applied; play_id is stamped in the note body.
# SAFETY ORDER (checked in this order, every run):
#   1. kill switch staging\hubspot\WRITES-PAUSED  -> refuse (exit 3)
#   2. token $env:HUBSPOT_PRIVATE_APP_TOKEN       -> required for -Execute (exit 2)
#   3. -Execute without -AuditConfirmed           -> refuse (exit 3; RevOps audit gate)
# DRY RUN by default: shows the per-record plan; with a token present it also resolves the
# company (read-only) so the plan is concrete. Optional: $env:HUBSPOT_TASK_QUEUE_ID and
# $env:HUBSPOT_OWNER_ID stamp hs_task_queue_id / hubspot_owner_id on created tasks.
# Exit codes: 0 ok/dry, 1 >=1 record failed, 2 no token, 3 gate refused.
param(
    [switch]$Execute,
    [switch]$AuditConfirmed,
    [string]$AppliedBy = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Get-TriggerSystemRoot
$outboxDir = Join-Path $root 'staging\hubspot\outbox'

$killSwitch = Join-Path $root 'staging\hubspot\WRITES-PAUSED'
if ((Test-Path $killSwitch) -and $Execute) { Write-Host 'BLOCKED: WRITES-PAUSED exists - no CRM writes (research continues).'; exit 3 }

$token = $env:HUBSPOT_PRIVATE_APP_TOKEN
if ($Execute) {
    if ([string]::IsNullOrWhiteSpace($token)) { Write-Host 'No HUBSPOT_PRIVATE_APP_TOKEN - cannot execute.'; exit 2 }
    if (-not $AuditConfirmed) { Write-Host 'REFUSED: -Execute needs -AuditConfirmed (RevOps audit recorded in BUILD-STATE first).'; exit 3 }
    if ($AppliedBy -eq '') { Write-Host 'REFUSED: -Execute needs -AppliedBy (who is applying these records).'; exit 3 }
}

$files = @(Get-ChildItem -Path $outboxDir -Filter '*.jsonl' -File -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) { Write-Host 'outbox empty - nothing to drain.'; exit 0 }

function Resolve-Company {
    param([string]$MatchKey)
    if ($MatchKey -match '^\d+$') { return @{ ok = $true; id = $MatchKey; how = 'direct id' } }
    if ([string]::IsNullOrWhiteSpace($token)) { return @{ ok = $false; id = ''; how = 'unresolved (no token)' } }
    $body = @{ filterGroups = @(@{ filters = @(@{ propertyName = 'domain'; operator = 'EQ'; value = $MatchKey }) })
               properties = @('name','domain'); limit = 2 }
    $r = Invoke-HubSpotApi -Method POST -Path '/crm/v3/objects/companies/search' -Token $token -Body $body
    if (-not $r.ok) { return @{ ok = $false; id = ''; how = "search failed ($($r.status))" } }
    $results = @(Get-JsonProp $r.data 'results')
    if ($results.Count -eq 0) { return @{ ok = $false; id = ''; how = "no company with domain=$MatchKey" } }
    $note = ''
    if ($results.Count -gt 1) { $note = ' (MULTIPLE matches - took first; verify)' }
    return @{ ok = $true; id = ('' + (Get-JsonProp $results[0] 'id')); how = "domain search$note" }
}

$failures = 0; $applied = 0; $planned = 0
foreach ($f in $files) {
    $lines = [IO.File]::ReadAllLines($f.FullName)
    $outLines = New-Object System.Collections.ArrayList
    $changed = $false
    $ln = 0
    foreach ($line in $lines) {
        $ln++
        if ($line.Trim() -eq '') { continue }
        $rec = $null
        try { $rec = $line | ConvertFrom-Json } catch {
            Write-Host "FAIL $($f.Name):$ln unparseable JSON - left as-is"; $failures++; [void]$outLines.Add($line); continue
        }
        $playId = '' + (Get-JsonProp $rec 'play_id')
        $alreadyApplied = ('' + (Get-JsonProp $rec 'applied_date')) -ne ''
        if ($alreadyApplied) { [void]$outLines.Add($line); continue }

        $matchKey = '' + (Get-JsonProp $rec 'match_key')
        $company = Resolve-Company -MatchKey $matchKey

        if (-not $Execute) {
            $planned++
            Write-Host "PLAN $($f.Name):$ln play=$playId company[$matchKey -> $($company.how)] note+task+props"
            [void]$outLines.Add($line); continue
        }
        if (-not $company.ok) {
            Write-Host "FAIL $($f.Name):$ln play=$playId company unresolved: $($company.how)"; $failures++; [void]$outLines.Add($line); continue
        }

        $nowUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        # 1) immutable note (assoc note->company typeId 190, VERIFIED 2026-07-28)
        $noteBody = @{
            properties = @{ hs_timestamp = $nowUtc; hs_note_body = ('' + (Get-JsonProp $rec 'note_body_md')) }
            associations = @(@{ to = @{ id = $company.id }
                                types = @(@{ associationCategory = 'HUBSPOT_DEFINED'; associationTypeId = 190 }) })
        }
        $noteRes = Invoke-HubSpotApi -Method POST -Path '/crm/v3/objects/notes' -Token $token -Body $noteBody
        if (-not $noteRes.ok) { Write-Host "FAIL $($f.Name):$ln note create ($($noteRes.status)): $($noteRes.err)"; $failures++; [void]$outLines.Add($line); continue }
        $noteId = '' + (Get-JsonProp $noteRes.data 'id')

        # 2) task (+ default association via the date-pinned endpoint, VERIFIED 2026-07-28)
        $task = Get-JsonProp $rec 'task'
        $due = '' + (Get-JsonProp $task 'due'); if ($due -eq '') { $due = $nowUtc }
        $tier = ''
        $props = Get-JsonProp $rec 'company_summary_props'
        if ($null -ne $props) { $tier = '' + (Get-JsonProp $props 'ts_last_tier') }
        $prio = 'MEDIUM'; if ($tier -eq 'STRIKE') { $prio = 'HIGH' }
        # reminder = the due timestamp (epoch ms - the format PROVEN accepted 2026-08-13).
        # Without hs_task_reminders, API-created tasks fire NO notification to the owner at all
        # (learned on the veeam pipeline test); the reminder is what pings email/in-app/Teams.
        $dueMs = [DateTimeOffset]::Parse($due).ToUnixTimeMilliseconds()
        $taskProps = @{
            hs_timestamp = $due
            hs_task_subject = "[$tier] play $playId"
            hs_task_body = "trigger-system play $playId - full context in the play note. Ack + work from the Trigger Strikes queue."
            hs_task_status = 'NOT_STARTED'; hs_task_priority = $prio; hs_task_type = 'TODO'
            hs_task_reminders = ('' + $dueMs)
        }
        if ($env:HUBSPOT_TASK_QUEUE_ID) { $taskProps.hs_task_queue_id = $env:HUBSPOT_TASK_QUEUE_ID }
        # AUTOMATIC ASSIGNMENT (2026-08-13): the play record's task.owner field carries the
        # owner id in parentheses, e.g. "Kumar Ambuj (90285852)" - parse and stamp it, so the
        # right person is assigned per play with no manual env var. Env var stays as fallback.
        $ownerField = '' + (Get-JsonProp $task 'owner')
        if ($ownerField -match '\((\d+)\)') { $taskProps.hubspot_owner_id = $Matches[1] }
        elseif ($env:HUBSPOT_OWNER_ID)      { $taskProps.hubspot_owner_id = $env:HUBSPOT_OWNER_ID }
        $taskRes = Invoke-HubSpotApi -Method POST -Path '/crm/v3/objects/tasks' -Token $token -Body @{ properties = $taskProps }
        if (-not $taskRes.ok) { Write-Host "FAIL $($f.Name):$ln task create ($($taskRes.status)): $($taskRes.err)"; $failures++; [void]$outLines.Add($line); continue }
        $taskId = '' + (Get-JsonProp $taskRes.data 'id')
        $assocRes = Invoke-HubSpotApi -Method PUT -Path "/crm/objects/2026-03/tasks/$taskId/associations/default/companies/$($company.id)" -Token $token
        if (-not $assocRes.ok) { Write-Host "WARN $($f.Name):$ln task association failed ($($assocRes.status)) - task exists unassociated: $taskId" }

        # 3) ts_ summary props (allowlist enforced - nothing else can be patched)
        if ($null -ne $props) {
            $allow = @('ts_last_tier','ts_last_window_close','ts_suppression_until')
            $patch = @{}
            foreach ($k in $allow) { $v = Get-JsonProp $props $k; if ($null -ne $v -and ('' + $v) -ne '') { $patch[$k] = ('' + $v) } }
            if ($patch.Count -gt 0) {
                $pRes = Invoke-HubSpotApi -Method PATCH -Path "/crm/v3/objects/companies/$($company.id)" -Token $token -Body @{ properties = $patch }
                if (-not $pRes.ok) { Write-Host "WARN $($f.Name):$ln company props patch failed ($($pRes.status)): $($pRes.err)" }
            }
        }

        # 4) stamp the record (idempotency)
        $rec | Add-Member -NotePropertyName applied_date -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd') -Force
        $rec | Add-Member -NotePropertyName applied_by -NotePropertyValue $AppliedBy -Force
        $rec | Add-Member -NotePropertyName response_ref -NotePropertyValue "note:$noteId;task:$taskId;company:$($company.id)" -Force
        [void]$outLines.Add(($rec | ConvertTo-Json -Depth 10 -Compress))
        $changed = $true; $applied++
        Write-Host "APPLIED $($f.Name):$ln play=$playId note=$noteId task=$taskId company=$($company.id)"
    }
    if ($changed) {
        Write-AtomicText -Path $f.FullName -Content (($outLines -join "`r`n") + "`r`n")
    }
}

if (-not $Execute) { Write-Host "DRY RUN done: $planned record(s) would be applied."; if ($failures -gt 0) { exit 1 } else { exit 0 } }
Write-Host "drain done: $applied applied, $failures failed."
if ($failures -gt 0) { exit 1 } else { exit 0 }
