# snapshot.ps1 - daily ATS job-board snapshot for every account in config\accounts.csv.
# Contract: reference\ats-endpoints.md (verified endpoints + fetcher rules) and plan Part D:
# raw responses stored VERBATIM under data\snapshots\<date>\ats\ (tamper-evidence),
# manifest.csv receipt per account, atomic writes, run_id on every row, coverage states.
# Coverage-state semantics written by THIS script (diff.ps1 finalizes checked_* later):
#   pending_diff        structured fetch OK - transient until diff.ps1 rewrites it
#   partial             page_only HTML captured (unstructured by nature)
#   source_unavailable  fetch failed (http_status/note say why)
#   parse_failure       fetched but the payload didn't parse / count (raw still stored)
#   manual_review       ats_type=none - machine can't check; the manual path covers it
# Exit codes: 0 = ran (per-account truth is in the manifest), 2 = accounts csv unusable.
param(
    [string]$AccountsCsv = '',
    [string]$SnapshotRoot = '',
    [string]$DateStamp = (Get-Date -Format 'yyyy-MM-dd'),
    [int]$DelaySeconds = 2,
    [int]$MaxPages = 10
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
Use-Tls12

$root = Get-TriggerSystemRoot
if ($AccountsCsv -eq '')  { $AccountsCsv  = Join-Path $root 'config\accounts.csv' }
if ($SnapshotRoot -eq '') { $SnapshotRoot = Join-Path $root 'data\snapshots' }

if (-not (Test-Path $AccountsCsv)) { Write-Host "FATAL: accounts csv not found: $AccountsCsv"; exit 2 }
try { $accounts = @(Import-Csv $AccountsCsv) } catch { Write-Host "FATAL: cannot read $AccountsCsv : $($_.Exception.Message)"; exit 2 }
if ($accounts.Count -eq 0) { Write-Host "NOTE: accounts csv has no data rows - nothing to snapshot."; exit 0 }

$dayDir = Join-Path (Join-Path $SnapshotRoot $DateStamp) 'ats'
if (-not (Test-Path $dayDir)) { New-Item -ItemType Directory -Force -Path $dayDir | Out-Null }
$runId = New-RunId -DateStamp $DateStamp
$manifestRows = New-Object System.Collections.ArrayList

function Get-JobCount {
    param([string]$AtsType, $Parsed)
    switch ($AtsType) {
        'greenhouse'      { return Get-JsonCount (Get-JsonProp $Parsed 'jobs') }
        'lever'           { return Get-JsonCount $Parsed }
        'ashby'           { return Get-JsonCount (Get-JsonProp $Parsed 'jobs') }
        'smartrecruiters' { $t = Get-JsonProp $Parsed 'totalFound'; if ($null -ne $t) { return [int]$t } else { return -1 } }
        'recruitee'       { return Get-JsonCount (Get-JsonProp $Parsed 'offers') }
        'workday'         { $t = Get-JsonProp $Parsed 'total'; if ($null -ne $t) { return [int]$t } else { return -1 } }
        default           { return -1 }
    }
}

$i = 0
foreach ($a in $accounts) {
    $i++
    if ($i -gt 1) { Start-Sleep -Seconds $DelaySeconds }   # politeness: fixed inter-account delay

    $id   = ('' + $a.account_id).Trim()
    $type = ('' + $a.ats_type).Trim().ToLower()
    $feed = ('' + $a.ats_feed_url).Trim()
    $careers = ('' + $a.careers_url).Trim()

    $row = [ordered]@{
        account_id = $id; ats_type = $type; url = ''; http_status = ''
        bytes = ''; job_count = ''; sha256 = ''
        fetched_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        run_id = $runId; coverage_state = ''; note = ''
    }

    if ($id -eq '') { $row.coverage_state = 'parse_failure'; $row.note = 'row has empty account_id'; [void]$manifestRows.Add([PSCustomObject]$row); continue }

    if ($type -eq 'none') {
        $row.coverage_state = 'manual_review'
        $row.note = 'ats_type=none - manual path per accounts.csv notes'
        [void]$manifestRows.Add([PSCustomObject]$row); Write-Host "[$id] none -> manual_review"; continue
    }

    if ($type -eq 'page_only') {
        if ($careers -eq '') {
            $row.coverage_state = 'source_unavailable'; $row.note = 'careers_url missing'
            [void]$manifestRows.Add([PSCustomObject]$row); Write-Host "[$id] page_only -> no careers_url"; continue
        }
        $row.url = $careers
        $res = Invoke-HttpGetRaw -Url $careers
        $row.http_status = $res.status
        if (-not $res.ok) {
            $row.coverage_state = 'source_unavailable'; $row.note = $res.err
        } else {
            $file = Join-Path $dayDir "$id.html"
            Write-AtomicText -Path $file -Content $res.content
            $row.bytes = (Get-Item $file).Length
            $row.sha256 = Get-FileSha256 -Path $file
            $row.coverage_state = 'partial'; $row.note = 'unstructured HTML capture'
        }
        [void]$manifestRows.Add([PSCustomObject]$row); Write-Host "[$id] page_only -> $($row.coverage_state)"; continue
    }

    # structured ATS types
    if ($feed -eq '') {
        $row.coverage_state = 'source_unavailable'; $row.note = 'ats_feed_url missing for structured ats_type'
        [void]$manifestRows.Add([PSCustomObject]$row); Write-Host "[$id] $type -> feed url missing"; continue
    }
    $row.url = $feed

    $pagesStored = 0
    $res = $null
    if ($type -eq 'workday') {
        $res = Invoke-HttpPostJsonRaw -Url $feed -BodyJson '{"limit":20,"offset":0,"searchText":""}'
    } else {
        $res = Invoke-HttpGetRaw -Url $feed
    }
    $row.http_status = $res.status

    if (-not $res.ok) {
        $row.coverage_state = 'source_unavailable'; $row.note = $res.err
        [void]$manifestRows.Add([PSCustomObject]$row); Write-Host "[$id] $type -> source_unavailable ($($res.status))"; continue
    }

    # store page 1 verbatim
    $file = Join-Path $dayDir "$id.json"
    Write-AtomicText -Path $file -Content $res.content
    $pagesStored = 1
    $row.bytes = (Get-Item $file).Length
    $row.sha256 = Get-FileSha256 -Path $file

    # parse + count (+ page if the ATS is paged and page 1 didn't cover the total)
    $parsed = $null
    $parseOk = $true
    try { $parsed = ConvertFrom-JsonBig -Text $res.content } catch { $parseOk = $false }
    if (-not $parseOk -or $null -eq $parsed) {
        $row.coverage_state = 'parse_failure'; $row.note = 'stored raw; JSON parse failed'
        [void]$manifestRows.Add([PSCustomObject]$row); Write-Host "[$id] $type -> parse_failure"; continue
    }

    $count = Get-JobCount -AtsType $type -Parsed $parsed
    if ($count -lt 0) {
        $row.coverage_state = 'parse_failure'; $row.note = 'stored raw; expected shape not found'
        [void]$manifestRows.Add([PSCustomObject]$row); Write-Host "[$id] $type -> parse_failure (shape)"; continue
    }
    $row.job_count = $count

    if ($type -eq 'smartrecruiters' -or $type -eq 'workday') {
        # paged APIs: fetch remaining pages so the day's snapshot is complete
        $pageSize = 100; $bodyTemplate = ''
        if ($type -eq 'workday') { $pageSize = 20 }
        $have = 0
        if ($type -eq 'smartrecruiters') { $have = Get-JsonCount (Get-JsonProp $parsed 'content') }
        if ($type -eq 'workday')         { $have = Get-JsonCount (Get-JsonProp $parsed 'jobPostings') }
        $offset = $have
        $page = 1
        while ($offset -lt $count -and $page -lt $MaxPages) {
            Start-Sleep -Seconds 1
            $page++
            $pres = $null
            if ($type -eq 'workday') {
                $pres = Invoke-HttpPostJsonRaw -Url $feed -BodyJson ('{"limit":20,"offset":' + $offset + ',"searchText":""}')
            } else {
                $sep = '?'; if ($feed.Contains('?')) { $sep = '&' }
                $pres = Invoke-HttpGetRaw -Url ($feed + $sep + 'limit=' + $pageSize + '&offset=' + $offset)
            }
            if (-not $pres.ok) { $row.note = "paging stopped at offset $offset : $($pres.err)"; break }
            Write-AtomicText -Path (Join-Path $dayDir ("$id.p$page.json")) -Content $pres.content
            $pagesStored++
            $pparsed = $null
            try { $pparsed = ConvertFrom-JsonBig -Text $pres.content } catch { $row.note = "page $page parse failed (raw stored)"; break }
            $got = 0
            if ($type -eq 'smartrecruiters') { $got = Get-JsonCount (Get-JsonProp $pparsed 'content') }
            if ($type -eq 'workday')         { $got = Get-JsonCount (Get-JsonProp $pparsed 'jobPostings') }
            if ($got -le 0) { break }
            $offset += $got
        }
        if ($pagesStored -gt 1 -and $row.note -eq '') { $row.note = "paged: $pagesStored files" }
        if ($offset -lt $count -and $page -ge $MaxPages) { $row.note = ($row.note + " CAPPED at $MaxPages pages ($offset of $count)").Trim() }
    }

    $row.coverage_state = 'pending_diff'
    [void]$manifestRows.Add([PSCustomObject]$row)
    Write-Host "[$id] $type -> ok ($count jobs, $pagesStored file(s))"
}

# manifest (atomic, no BOM)
$manifestPath = Join-Path (Join-Path $SnapshotRoot $DateStamp) 'manifest.csv'
$csvText = ($manifestRows | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
Write-AtomicText -Path $manifestPath -Content ($csvText + "`r`n")

$states = $manifestRows | Group-Object coverage_state | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Host ""
Write-Host "snapshot $DateStamp done. run_id=$runId accounts=$($manifestRows.Count) [$($states -join ' ')]"
Write-Host "manifest: $manifestPath"
exit 0
