# alert-mailer.ps1 - drains staging\alerts\*.md via Outlook COM (classic Outlook, signed-in
# profile, ZERO stored credentials). Phase-4 component built 2026-07-28 (earliest automatable
# piece - plan Part J). STRUCTURAL RAILS (CLAUDE.md rule 1): reads ONLY staging\alerts\ and
# config\alert-recipients.csv (paths fixed, not parameters); recipients resolve ONLY from that
# git-committed CSV; unknown list_name -> refuse. This script is the sole mail-capable
# component and it cannot address a prospect by construction.
# BINDING RULE (from the Phase-0 failure, BUILD-STATE smoke results): never trust .Send() -
# verify the item LEFT the Outbox and APPEARS in Sent Items before writing the SENT receipt;
# if stuck in Outbox, re-issue .Send() once (the exact fix that worked); otherwise FAIL loudly.
# Run as its own process. Sessions that fetch web content must not hold this COM object (rule 7).
# Exit codes: 0 = all pending alerts sent (or none pending), 1 = >=1 alert failed,
#             3 = recipients csv missing (config error).
param(
    [switch]$DryRun,
    [int]$DrainTimeoutSec = 90
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Get-TriggerSystemRoot
$alertsDir = Join-Path $root 'staging\alerts'
$sentDir = Join-Path $alertsDir 'sent'
$recipientsCsv = Join-Path $root 'config\alert-recipients.csv'

if (-not (Test-Path $recipientsCsv)) { Write-Host "FATAL: recipients csv missing: $recipientsCsv"; exit 3 }
if (-not (Test-Path $sentDir)) { New-Item -ItemType Directory -Force -Path $sentDir | Out-Null }
$recipients = @(Import-Csv $recipientsCsv)

$validTypes = @('DIGEST','STRIKE','HOT-REPLY','ESCALATION','SYSTEM')
$validPrefixes = @('[DIGEST]','[STRIKE]','[HOT REPLY]','[ESCALATION]','[SYSTEM]')

function Parse-AlertFile {
    param([string]$Path)
    # Header block = leading non-blank lines. Core 4 (TYPE/SUBJECT/TO/STATUS) required.
    # Optional (added 2026-08-17, play-scorecard emails): FORMAT: text|html (default text),
    # ATTACH: <repo-relative path> (repeatable). Body starts after the first blank line.
    # LINK / LINK-TEXT (added 2026-08-20): consumed by alert-teams.ps1 only; tolerated and
    # ignored here so one alert file can serve both lanes.
    $lines = [IO.File]::ReadAllLines($Path)
    $hdr = @{}; $attach = @(); $bodyStart = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i].Trim()
        if ($ln -eq '') { $bodyStart = $i + 1; break }
        if ($ln -match '^(TYPE|SUBJECT|TO|CC|STATUS|FORMAT|ATTACH|LINK|LINK-TEXT|TEAMS):\s*(.*)$') {
            if ($Matches[1] -eq 'ATTACH') { $attach += $Matches[2].Trim() }
            else { $hdr[$Matches[1]] = $Matches[2].Trim() }
        } else {
            return @{ ok = $false; err = "line $($i+1) is not a header line: '$ln'" }
        }
    }
    foreach ($k in @('TYPE','SUBJECT','TO','STATUS')) {
        if (-not $hdr.ContainsKey($k)) { return @{ ok = $false; err = "missing header $k" } }
    }
    if ($validTypes -notcontains $hdr.TYPE) { return @{ ok = $false; err = "TYPE '$($hdr.TYPE)' invalid" } }
    $prefixOk = $false
    foreach ($p in $validPrefixes) { if ($hdr.SUBJECT.StartsWith($p)) { $prefixOk = $true } }
    if (-not $prefixOk) { return @{ ok = $false; err = "SUBJECT must start with one of $($validPrefixes -join ' ')" } }
    $format = 'text'
    if ($hdr.ContainsKey('FORMAT')) {
        $format = $hdr.FORMAT.ToLower()
        if (@('text','html') -notcontains $format) { return @{ ok = $false; err = "FORMAT '$($hdr.FORMAT)' invalid (text|html)" } }
    }
    $files = @()
    foreach ($a in $attach) {
        if ($a -match '\.\.') { return @{ ok = $false; err = "ATTACH path '$a' contains '..' - refused" } }
        $full = Join-Path $root $a
        if (-not (Test-Path $full -PathType Leaf)) { return @{ ok = $false; err = "ATTACH file not found: $a" } }
        $files += (Resolve-Path $full).Path
    }
    $body = ''
    if ($bodyStart -lt $lines.Count) { $body = ($lines[$bodyStart..($lines.Count-1)] -join "`r`n").Trim() }
    return @{ ok = $true; hdr = $hdr; body = $body; format = $format; attach = $files }
}

$pending = @(Get-ChildItem -Path $alertsDir -Filter '*.md' -File -ErrorAction SilentlyContinue)
if ($pending.Count -eq 0) { Write-Host 'No alert files in staging\alerts\ - nothing to do.'; exit 0 }

$failures = 0
$plan = New-Object System.Collections.ArrayList
foreach ($f in $pending) {
    $p = Parse-AlertFile -Path $f.FullName
    if (-not $p.ok) { Write-Host "SKIP (malformed) $($f.Name): $($p.err)"; $failures++; continue }
    if ($p.hdr.STATUS -eq 'sent') { Write-Host "SKIP (already sent) $($f.Name)"; continue }
    if ($p.hdr.STATUS -ne 'pending') { Write-Host "SKIP (status '$($p.hdr.STATUS)') $($f.Name)"; $failures++; continue }
    # ROUTING RAIL (user rule 2026-08-24): the SDR/leadership roster receives [STRIKE] emails
    # ONLY. Every other type (SYSTEM, DIGEST, HOT-REPLY, ESCALATION) may address the operator
    # 'default' list and nothing else; CC exists only on STRIKE. Enforced here so no
    # runbook/session mistake can route system noise to the team.
    if ($p.hdr.TYPE -ne 'STRIKE' -and $p.hdr.TO -ne 'default') {
        Write-Host "FAIL $($f.Name): TYPE $($p.hdr.TYPE) may only address list 'default' (only [STRIKE] emails reach the SDR/leadership roster - user rule 2026-08-24)."
        $failures++; continue
    }
    if ($p.hdr.ContainsKey('CC') -and $p.hdr.TYPE -ne 'STRIKE') {
        Write-Host "FAIL $($f.Name): CC is allowed on TYPE STRIKE only (user rule 2026-08-24)."
        $failures++; continue
    }
    $to = @($recipients | Where-Object { $_.list_name -eq $p.hdr.TO } | ForEach-Object { ('' + $_.address).Trim() } | Where-Object { $_ -match '^\S+@\S+\.\S+$' })
    if ($to.Count -eq 0) {
        Write-Host "FAIL $($f.Name): list_name '$($p.hdr.TO)' resolves to no recipient in alert-recipients.csv - refusing."
        $failures++; continue
    }
    $cc = @()
    if ($p.hdr.ContainsKey('CC')) {
        $cc = @($recipients | Where-Object { $_.list_name -eq $p.hdr.CC } | ForEach-Object { ('' + $_.address).Trim() } | Where-Object { $_ -match '^\S+@\S+\.\S+$' })
        if ($cc.Count -eq 0) {
            Write-Host "FAIL $($f.Name): CC list '$($p.hdr.CC)' resolves to no recipient in alert-recipients.csv - refusing."
            $failures++; continue
        }
    }
    foreach ($addr in ($to + $cc)) { if ($addr -notlike '*@unboundia.com') { Write-Host "WARN $($f.Name): recipient '$addr' is not @unboundia.com - check the CSV." } }
    [void]$plan.Add(@{ file = $f; hdr = $p.hdr; body = $p.body; to = $to; cc = $cc; format = $p.format; attach = $p.attach })
}

if ($plan.Count -eq 0) {
    Write-Host 'Nothing sendable.'
    if ($failures -gt 0) { exit 1 } else { exit 0 }
}
if ($DryRun) {
    Write-Host "DRY RUN - would send $($plan.Count) alert(s):"
    foreach ($x in $plan) {
        $ccNote = ''; if ($x.cc.Count -gt 0) { $ccNote = " CC: $($x.cc -join '; ')" }
        Write-Host "  $($x.file.Name) -> $($x.to -join '; ')$ccNote  [$($x.hdr.SUBJECT)] format=$($x.format)"
        foreach ($a in $x.attach) { Write-Host "    + attach: $a" }
    }
    if ($failures -gt 0) { exit 1 } else { exit 0 }
}

# ensure classic Outlook is RUNNING before any send (Phase-0 lesson: COM against a
# not-fully-running Outlook queues without submitting)
$coldStart = $false
if (-not (Get-Process OUTLOOK -ErrorAction SilentlyContinue)) {
    Write-Host 'Outlook not running - starting it...'
    Start-Process outlook.exe
    $coldStart = $true
    $waited = 0
    while (-not (Get-Process OUTLOOK -ErrorAction SilentlyContinue) -and $waited -lt 60) { Start-Sleep -Seconds 3; $waited += 3 }
    if (-not (Get-Process OUTLOOK -ErrorAction SilentlyContinue)) { Write-Host 'FATAL: Outlook did not start.'; exit 1 }
}
$ol = New-Object -ComObject Outlook.Application
$ns = $ol.GetNamespace('MAPI')
if ($coldStart) { Start-Sleep -Seconds 10 }   # let transport come up after a cold start
$outbox = $ns.GetDefaultFolder(4)   # olFolderOutbox
$sentItems = $ns.GetDefaultFolder(5) # olFolderSentMail

function Test-InOutbox([string]$Subject) {
    foreach ($it in @($outbox.Items)) { if ($it.Subject -eq $Subject) { return $it } }
    return $null
}
function Test-InSentItems([string]$Subject) {
    $items = $sentItems.Items
    try { $items.Sort('[SentOn]', $true) } catch { }   # unsorted scan still works, just wider
    $n = 0
    foreach ($it in @($items)) {
        $n++
        if ($n -gt 30) { break }
        if ($it.Subject -eq $Subject) { return $true }
    }
    return $false
}

foreach ($x in $plan) {
    $subject = $x.hdr.SUBJECT
    $ccNote = ''; if ($x.cc.Count -gt 0) { $ccNote = " (CC: $($x.cc -join '; '))" }
    Write-Host "sending: $($x.file.Name) -> $($x.to -join '; ')$ccNote"
    try {
        $mail = $ol.CreateItem(0)
        $mail.To = ($x.to -join ';')
        if ($x.cc.Count -gt 0) { $mail.CC = ($x.cc -join ';') }
        $mail.Subject = $subject
        # Footer de-jargoned 2026-08-17 (user: reader-facing emails carry no system internals).
        if ($x.format -eq 'html') {
            $mail.HTMLBody = $x.body
        } else {
            $mail.Body = $x.body + "`r`n`r`n--`r`nUnbound trigger system"
        }
        foreach ($a in $x.attach) { [void]$mail.Attachments.Add($a) }
        $mail.Send()
    } catch {
        Write-Host "FAIL $($x.file.Name): COM send raised: $($_.Exception.Message)"
        Add-Content -Path $x.file.FullName -Encoding UTF8 -Value "FAILED: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) reason: COM send exception: $($_.Exception.Message)"
        $failures++; continue
    }

    # VERIFY 1: Outbox drains (retry .Send() once at half-timeout if stuck - the Phase-0 fix)
    $drained = $false; $resent = $false; $elapsed = 0
    while ($elapsed -lt $DrainTimeoutSec) {
        Start-Sleep -Seconds 3; $elapsed += 3
        $stuck = Test-InOutbox -Subject $subject
        if ($null -eq $stuck) { $drained = $true; break }
        if (-not $resent -and $elapsed -ge [int]($DrainTimeoutSec / 2)) {
            Write-Host "  still in Outbox after ${elapsed}s - re-issuing Send() once (known Phase-0 failure mode)"
            try { $stuck.Send() } catch { Write-Host "  re-Send raised: $($_.Exception.Message)" }
            $resent = $true
        }
    }
    # VERIFY 2: appears in Sent Items
    $inSent = $false
    if ($drained) {
        $elapsed = 0
        while ($elapsed -lt 30) {
            if (Test-InSentItems -Subject $subject) { $inSent = $true; break }
            Start-Sleep -Seconds 3; $elapsed += 3
        }
    }

    if ($drained -and $inSent) {
        $utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        $content = [IO.File]::ReadAllText($x.file.FullName)
        $content = $content -replace 'STATUS:\s*pending', 'STATUS: sent'
        $content = $content.TrimEnd() + "`r`nSENT: $utc BY: com-mailer`r`n"
        Write-AtomicText -Path (Join-Path $sentDir $x.file.Name) -Content $content
        Remove-Item -Path $x.file.FullName -Force
        Write-Host "  SENT + verified (Outbox drained, Sent Items confirmed) -> sent\$($x.file.Name)"
    } else {
        $reason = 'not confirmed in Sent Items within 30s'
        if (-not $drained) { $reason = "still in Outbox after ${DrainTimeoutSec}s (re-send attempted: $resent)" }
        Write-Host "  FAIL $($x.file.Name): $reason - file stays pending for retry"
        Add-Content -Path $x.file.FullName -Encoding UTF8 -Value "FAILED: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) reason: $reason"
        $failures++
    }
}

if ($failures -gt 0) { Write-Host "$failures failure(s)."; exit 1 }
Write-Host 'All pending alerts sent and verified.'
exit 0
