# diff.ps1 - diffs the latest two snapshot days by job ID per account (plan Part D):
# new / removed / days_open / stale_60d / reposted. A REMOVED job is an event to interpret
# (filled? pulled? ATS moved?) - this script never classifies it further.
# Also: finalizes the day's manifest coverage states (pending_diff -> checked_changed|checked_unchanged),
# and maintains the first-seen ledger data\snapshots\job-first-seen.csv (idempotent: same
# inputs twice -> identical diff.json and ledger; no wall-clock values in outputs).
# Baseline day (no earlier snapshot folder): seeds the ledger, marks manifest rows 'partial'
# with a baseline note, writes diff.json with coverage='baseline'.
# Exit codes: 0 = ok, 2 = snapshot day missing/unusable.
param(
    [string]$SnapshotRoot = '',
    [string]$DateStamp = '',      # default: latest day folder under SnapshotRoot
    [int]$StaleDays = 60,
    [int]$RepostWindowDays = 45
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Get-TriggerSystemRoot
if ($SnapshotRoot -eq '') { $SnapshotRoot = Join-Path $root 'data\snapshots' }
$ledgerPath = Join-Path $SnapshotRoot 'job-first-seen.csv'

$dayDirs = @(Get-ChildItem -Path $SnapshotRoot -Directory -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object Name)
if ($dayDirs.Count -eq 0) { Write-Host 'FATAL: no snapshot day folders.'; exit 2 }
if ($DateStamp -eq '') { $DateStamp = $dayDirs[-1].Name }
$todayDir = Join-Path $SnapshotRoot $DateStamp
if (-not (Test-Path (Join-Path $todayDir 'manifest.csv'))) { Write-Host "FATAL: no manifest for $DateStamp"; exit 2 }
$prevName = ''
# Only a day that actually holds an ats\ capture can serve as the prior day. VERIFIED FAILURE
# 2026-08-03: an evidence-only day folder (2026-08-02\ats-verify, no ats\) was picked as prev
# and every account went 'no_prior' - the whole week's diff went blind. Evidence captures now
# live in data\verify\, and this guard makes the resolver immune either way.
foreach ($d in $dayDirs) {
    if ($d.Name -lt $DateStamp -and (Test-Path (Join-Path $d.FullName 'ats'))) { $prevName = $d.Name }
}
$today = [datetime]::ParseExact($DateStamp, 'yyyy-MM-dd', $null)

function Get-Jobs {
    # returns @{ ok; missing; jobs = array of @{key,title,location} } for one account's stored
    # snapshot (incl. page files). ok=$false means parse failure; missing=$true means no file.
    # (Hashtable contract on purpose: PS 5.1 pipeline-flattens multi-value returns.)
    param([string]$DayDir, [string]$AccountId, [string]$AtsType)
    $files = @()
    $p1 = Join-Path (Join-Path $DayDir 'ats') "$AccountId.json"
    if (-not (Test-Path $p1)) { return @{ ok = $true; missing = $true; jobs = @() } }
    $files += $p1
    $files += @(Get-ChildItem -Path (Join-Path $DayDir 'ats') -Filter "$AccountId.p*.json" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { $_.FullName })
    $jobs = New-Object System.Collections.ArrayList
    foreach ($f in $files) {
        $parsed = $null
        try { $parsed = ConvertFrom-JsonBig -Text ([IO.File]::ReadAllText($f)) } catch { return @{ ok = $false; missing = $false; jobs = @() } }
        $items = $null
        switch ($AtsType) {
            'greenhouse'      { $items = Get-JsonProp $parsed 'jobs' }
            'lever'           { $items = $parsed }
            'ashby'           { $items = Get-JsonProp $parsed 'jobs' }
            'smartrecruiters' { $items = Get-JsonProp $parsed 'content' }
            'recruitee'       { $items = Get-JsonProp $parsed 'offers' }
            'workday'         { $items = Get-JsonProp $parsed 'jobPostings' }
        }
        if ($null -eq $items) { return @{ ok = $false; missing = $false; jobs = @() } }
        foreach ($j in $items) {
            $key = ''; $title = ''; $loc = ''
            switch ($AtsType) {
                'greenhouse'      { $key = Get-JsonProp $j 'id'; $title = Get-JsonProp $j 'title'; $l = Get-JsonProp $j 'location'; if ($l) { $loc = Get-JsonProp $l 'name' } }
                'lever'           { $key = Get-JsonProp $j 'id'; $title = Get-JsonProp $j 'text';  $c = Get-JsonProp $j 'categories'; if ($c) { $loc = Get-JsonProp $c 'location' } }
                'ashby'           { $key = Get-JsonProp $j 'id'; $title = Get-JsonProp $j 'title'; $loc = Get-JsonProp $j 'location' }
                'smartrecruiters' { $key = Get-JsonProp $j 'id'; $title = Get-JsonProp $j 'name';  $l = Get-JsonProp $j 'location'; if ($l) { $loc = Get-JsonProp $l 'city' } }
                'recruitee'       { $key = Get-JsonProp $j 'id'; $title = Get-JsonProp $j 'title'; $loc = Get-JsonProp $j 'city' }
                'workday'         { $key = Get-JsonProp $j 'externalPath'; $title = Get-JsonProp $j 'title'; $loc = Get-JsonProp $j 'locationsText' }
            }
            if ($null -ne $key -and ('' + $key) -ne '') {
                [void]$jobs.Add(@{ key = ('' + $key); title = ('' + $title); location = ('' + $loc) })
            }
        }
    }
    return @{ ok = $true; missing = $false; jobs = @($jobs) }
}

function Get-NormTitle([string]$t) { (($t + '').ToLower() -replace '\s+', ' ').Trim() }

# ledger load
$ledger = @{}
if (Test-Path $ledgerPath) {
    foreach ($r in @(Import-Csv $ledgerPath)) { $ledger[$r.job_key] = $r }
}

# manifest load
$manifestPath = Join-Path $todayDir 'manifest.csv'
$manifest = @(Import-Csv $manifestPath)

$diffAccounts = New-Object System.Collections.ArrayList
$totNew = 0; $totRemoved = 0

foreach ($m in $manifest) {
    if ($m.coverage_state -ne 'pending_diff' -and $m.coverage_state -notmatch '^checked_') { continue }
    $id = $m.account_id; $type = $m.ats_type
    $acct = [ordered]@{ account_id = $id; coverage = ''; new = @(); removed = @(); stale = @(); counts = $null }

    $tRes = Get-Jobs -DayDir $todayDir -AccountId $id -AtsType $type
    if (-not $tRes.ok) { $m.coverage_state = 'parse_failure'; $m.note = ('' + $m.note + ' diff: today parse failed').Trim(); $acct.coverage = 'parse_failure'; [void]$diffAccounts.Add($acct); continue }
    if ($tRes.missing) { $acct.coverage = 'no_today_file'; $m.coverage_state = 'source_unavailable'; $m.note = ('' + $m.note + ' diff: today snapshot file missing').Trim(); [void]$diffAccounts.Add($acct); continue }
    $tj = $tRes.jobs

    # ledger upsert for today's jobs (idempotent)
    $todayKeys = @{}
    foreach ($j in $tj) {
        $jk = "$id|$($j.key)"
        $todayKeys[$jk] = $j
        if ($ledger.ContainsKey($jk)) {
            $row = $ledger[$jk]
            $row.last_seen = $DateStamp
            $row.status = 'open'
            $row.title = $j.title
        } else {
            $ledger[$jk] = [PSCustomObject][ordered]@{
                job_key = $jk; account_id = $id; title = $j.title
                first_seen = $DateStamp; last_seen = $DateStamp; status = 'open'; removed_date = ''
            }
        }
    }

    if ($prevName -eq '') {
        $acct.coverage = 'baseline'
        $m.coverage_state = 'partial'
        $m.note = ('' + $m.note + ' baseline day - no prior day to diff').Trim()
        $acct.counts = @{ today = $tj.Count; new = 0; removed = 0; stale = 0 }
        [void]$diffAccounts.Add($acct); continue
    }

    $pRes = Get-Jobs -DayDir (Join-Path $SnapshotRoot $prevName) -AccountId $id -AtsType $type
    if (-not $pRes.ok) { $acct.coverage = 'prev_parse_failure'; $m.coverage_state = 'parse_failure'; $m.note = ('' + $m.note + ' diff: prev-day parse failed').Trim(); [void]$diffAccounts.Add($acct); continue }
    $pj = $pRes.jobs
    if ($pRes.missing) {
        $acct.coverage = 'no_prior'
        $m.coverage_state = 'partial'
        $m.note = ('' + $m.note + ' no prior snapshot for this account (baseline)').Trim()
        $acct.counts = @{ today = $tj.Count; new = 0; removed = 0; stale = 0 }
        [void]$diffAccounts.Add($acct); continue
    }

    $prevKeys = @{}
    foreach ($j in $pj) { $prevKeys["$id|$($j.key)"] = $j }

    $newList = New-Object System.Collections.ArrayList
    $remList = New-Object System.Collections.ArrayList
    $staleList = New-Object System.Collections.ArrayList

    # Removals are stamped BEFORE the new-jobs loop so a remove+re-add inside the SAME diff
    # window is visible to repost detection (it scans ledger rows with status='removed').
    # Order fixed 2026-08-15: the old order ran removals last, so the servicenow ABX repost
    # (removed and re-added between 08-10 and 08-14) was never flagged - found 2026-08-14.
    foreach ($jk in ($prevKeys.Keys | Sort-Object)) {
        if (-not $todayKeys.ContainsKey($jk)) {
            $j = $prevKeys[$jk]
            [void]$remList.Add([ordered]@{ key = $j.key; title = $j.title; location = $j.location })
            if ($ledger.ContainsKey($jk)) {
                $lrow = $ledger[$jk]
                if ($lrow.status -ne 'removed') { $lrow.status = 'removed'; $lrow.removed_date = $DateStamp }
            }
        }
    }

    foreach ($jk in ($todayKeys.Keys | Sort-Object)) {
        $j = $todayKeys[$jk]
        $lrow = $ledger[$jk]
        $daysOpen = ([int]($today - [datetime]::ParseExact($lrow.first_seen, 'yyyy-MM-dd', $null)).TotalDays)
        if (-not $prevKeys.ContainsKey($jk)) {
            $entry = [ordered]@{ key = $j.key; title = $j.title; location = $j.location }
            # repost detection: same account + normalized title removed within the window
            $nt = Get-NormTitle $j.title
            foreach ($lk in $ledger.Keys) {
                $cand = $ledger[$lk]
                if ($cand.account_id -eq $id -and $cand.status -eq 'removed' -and $cand.removed_date -ne '' -and $lk -ne $jk) {
                    if ((Get-NormTitle $cand.title) -eq $nt) {
                        $rd = [datetime]::ParseExact($cand.removed_date, 'yyyy-MM-dd', $null)
                        if (($today - $rd).TotalDays -le $RepostWindowDays -and ($today - $rd).TotalDays -ge 0) {
                            $entry.reposted_from = $cand.job_key; break
                        }
                    }
                }
            }
            [void]$newList.Add($entry)
        }
        if ($daysOpen -ge $StaleDays) {
            [void]$staleList.Add([ordered]@{ key = $j.key; title = $j.title; days_open = $daysOpen })
        }
    }
    $acct.coverage = 'ok'
    $acct.new = @($newList)
    $acct.removed = @($remList)
    $acct.stale = @($staleList)
    $acct.counts = @{ today = $tj.Count; new = $newList.Count; removed = $remList.Count; stale = $staleList.Count }
    $totNew += $newList.Count; $totRemoved += $remList.Count
    if (($newList.Count + $remList.Count) -gt 0) { $m.coverage_state = 'checked_changed' } else { $m.coverage_state = 'checked_unchanged' }
    $m.note = ('' + $m.note + " diff:+$($newList.Count)-$($remList.Count)").Trim()
    [void]$diffAccounts.Add($acct)
}

# write diff.json (deterministic: ordered accounts, no wall-clock)
$diffObj = [ordered]@{
    generated_from = @($prevName, $DateStamp)
    stale_days = $StaleDays
    repost_window_days = $RepostWindowDays
    accounts = @($diffAccounts | Sort-Object { $_.account_id })
}
Write-AtomicText -Path (Join-Path $todayDir 'diff.json') -Content (($diffObj | ConvertTo-Json -Depth 8) + "`n")

# rewrite manifest with finalized states (atomic)
$csvText = ($manifest | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
Write-AtomicText -Path $manifestPath -Content ($csvText + "`r`n")

# rewrite ledger (atomic, sorted for determinism)
$ledgerRows = $ledger.Values | Sort-Object job_key
$ledgerText = ($ledgerRows | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
Write-AtomicText -Path $ledgerPath -Content ($ledgerText + "`r`n")

if ($prevName -eq '') { Write-Host "diff $DateStamp : BASELINE day (ledger seeded, no comparison possible)." }
else { Write-Host "diff $prevName -> $DateStamp : +$totNew new, -$totRemoved removed across $($diffAccounts.Count) account(s)." }
Write-Host "outputs: $(Join-Path $todayDir 'diff.json') ; ledger: $ledgerPath"
exit 0
