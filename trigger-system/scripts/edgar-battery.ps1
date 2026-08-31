# edgar-battery.ps1 - EDGAR full-text query battery (spec section 7), MEASUREMENT MODE by default.
#
# Runs the queries in config\edgar-battery.csv against the SEC full-text search endpoint and
# writes hit evidence + a per-query summary. In measurement mode (the default, and the ONLY mode
# until the spec's Phase 3 exit criteria are met) it SENDS NOTHING and adds NO signal rows -
# it exists to establish per-query hit-rate baselines ("first run of every query = measurement
# run: log hit counts, send nothing").
#
# VERIFIED FACTS THIS SCRIPT IS BUILT ON (all live-tested 2026-08-06):
#   - endpoint: https://efts.sec.gov/LATEST/search-index?q=...&forms=...&dateRange=custom
#     &startdt=YYYY-MM-DD&enddt=YYYY-MM-DD&from=N   (Elasticsearch JSON; 100 hits/page)
#   - the spec's server-side sics= parameter is IGNORED (identical counts with/without; Vail
#     Resorts and an insurance group came back "filtered") and ciks= is BROKEN (padded -> HTTP
#     500; unpadded -> silent zero even for q="Snowflake" on Snowflake's own 10-K year).
#     THEREFORE all SIC and TAL filtering is CLIENT-SIDE via the verified _source.sics and
#     _source.ciks fields on every hit.
#   - hits carry: adsh, form/file_type, file_date, ciks[], sics[], display_names[], items.
#
# Battery rules implemented (spec section 7): DEF 14A appears in no forms list; every query is
# date-windowed (full-text index reaches back to 2001 - an undated query surfaces decade-old
# ghosts, a verified failure mode); dedupe by adsh within the run; hits on TAL filers are marked
# cik_lane_covered (the CIK lane already sees every TAL filing - a battery hit on a TAL filer is
# redundant confirmation, NEVER a second source).
#
# Exit codes: 0 = ran (per-query truth in the summary), 2 = config unusable.
param(
    [string]$BatteryCsv = '',
    [string]$ClassificationCsv = '',
    [string]$SnapshotRoot = '',
    [string]$DateStamp = (Get-Date -Format 'yyyy-MM-dd'),
    [ValidateSet('weekly','monthly','all')][string]$Cadence = 'weekly',
    [int]$MaxPagesPerQuery = 3,
    [int]$DelayMs = 300,
    [string]$UserAgent = 'UnboundIA-signal-watcher upawar@unboundia.com'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
Use-Tls12

$root = Get-TriggerSystemRoot
if ($BatteryCsv -eq '')        { $BatteryCsv        = Join-Path $root 'config\edgar-battery.csv' }
if ($ClassificationCsv -eq '') { $ClassificationCsv = Join-Path $root 'config\edgar-classification.csv' }
if ($SnapshotRoot -eq '')      { $SnapshotRoot      = Join-Path $root 'data\snapshots' }
foreach ($f in @($BatteryCsv, $ClassificationCsv)) {
    if (-not (Test-Path $f)) { Write-Host "FATAL: required config not found: $f"; exit 2 }
}
$battery = @(Import-Csv $BatteryCsv)
if ($battery.Count -eq 0) { Write-Host 'FATAL: battery csv has no rows'; exit 2 }

$techSics = @('7372','7370','7371','7379')
# TAL CIK set for client-side scoping, as UNPADDED strings (hit ciks arrive padded; normalize).
$talCiks = @{}
foreach ($c in @(Import-Csv $ClassificationCsv)) {
    $k = ('' + $c.cik).Trim()
    if ($k -match '^\d{10}$') { $talCiks[[string][int]$k] = ('' + $c.account_id) }
}
Write-Host ("TAL CIK set: " + $talCiks.Count + " filers")

$dayRoot = Join-Path $SnapshotRoot $DateStamp
if (-not (Test-Path $dayRoot)) { New-Item -ItemType Directory -Force -Path $dayRoot | Out-Null }

$summary = New-Object System.Collections.ArrayList
$kept    = New-Object System.Collections.ArrayList
$seenAdsh = @{}
$today = [datetime]::ParseExact($DateStamp, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)

foreach ($qr in $battery) {
    if ($Cadence -ne 'all' -and ('' + $qr.cadence).Trim() -ne $Cadence) { continue }
    $qid = ('' + $qr.query_id).Trim()
    $winDays = [int]$qr.window_days
    $startdt = $today.AddDays(-$winDays).ToString('yyyy-MM-dd')
    $filter = ('' + $qr.client_filter).Trim()
    $qEnc = [uri]::EscapeDataString(('' + $qr.q))
    $formsEnc = ('' + $qr.forms).Trim()

    $rawTotal = -1; $fetched = 0; $keptN = 0; $talN = 0; $nonTal = @{}; $dupN = 0
    $status = 'ok'; $truncated = 'no'
    for ($page = 0; $page -lt $MaxPagesPerQuery; $page++) {
        $from = $page * 100
        $url = 'https://efts.sec.gov/LATEST/search-index?q=' + $qEnc + '&forms=' + $formsEnc +
               '&dateRange=custom&startdt=' + $startdt + '&enddt=' + $DateStamp + '&from=' + $from
        $res = Invoke-HttpGetRaw -Url $url -UserAgent $UserAgent
        if (-not $res.ok) {
            # One retry after a pause: a 403 here proved transient on 2026-08-06 (manual re-run of
            # the same query returned 200 with a legitimate result).
            Start-Sleep -Milliseconds 2500
            $res = Invoke-HttpGetRaw -Url $url -UserAgent $UserAgent
        }
        if (-not $res.ok) { $status = 'http_' + $res.status; break }
        $j = ConvertFrom-JsonBig -Text $res.content
        if ($null -eq $j) { $status = 'parse_failure'; break }
        $hitsObj = Get-JsonProp $j 'hits'
        if ($null -eq $hitsObj) { $status = 'shape_failure'; break }
        if ($rawTotal -lt 0) {
            $tot = Get-JsonProp $hitsObj 'total'
            $rawTotal = 0
            if ($null -ne $tot) { $v = Get-JsonProp $tot 'value'; if ($null -ne $v) { $rawTotal = [int]$v } }
        }
        $hits = Get-JsonProp $hitsObj 'hits'
        $n = 0; if ($null -ne $hits) { $n = Get-JsonCount $hits }
        if ($n -eq 0) { break }
        for ($i = 0; $i -lt $n; $i++) {
            $fetched++
            $src = Get-JsonProp $hits[$i] '_source'
            if ($null -eq $src) { continue }
            $adsh = ('' + (Get-JsonProp $src 'adsh')).Trim()
            $hitCiks = @(); $raw = Get-JsonProp $src 'ciks'
            if ($null -ne $raw) { foreach ($x in $raw) { $hitCiks += [string][int]('' + $x) } }
            $hitSics = @(); $raw = Get-JsonProp $src 'sics'
            if ($null -ne $raw) { foreach ($x in $raw) { $hitSics += ('' + $x).Trim() } }
            $isTal = $false
            foreach ($hc in $hitCiks) { if ($talCiks.ContainsKey($hc)) { $isTal = $true; break } }
            # client-side filter (server params refuted - see header)
            if ($filter -eq 'tech_sics') {
                $pass = $false
                foreach ($s in $hitSics) { if ($techSics -contains $s) { $pass = $true; break } }
                if (-not $pass) { continue }
            } elseif ($filter -eq 'tal_ciks') {
                if (-not $isTal) { continue }
            }
            if ($seenAdsh.ContainsKey($adsh)) { $dupN++; continue }
            $seenAdsh[$adsh] = $qid
            $keptN++
            if ($isTal) { $talN++ }
            $names = @(); $raw = Get-JsonProp $src 'display_names'
            if ($null -ne $raw) { foreach ($x in $raw) { $names += ('' + $x) } }
            if (-not $isTal -and $names.Count -gt 0) { $nonTal[$names[0]] = $true }
            [void]$kept.Add([PSCustomObject][ordered]@{
                query_id = $qid; adsh = $adsh
                form = ('' + (Get-JsonProp $src 'file_type'))
                file_date = ('' + (Get-JsonProp $src 'file_date'))
                ciks = ($hitCiks -join '|'); sics = ($hitSics -join '|')
                display_names = (($names -join ' | ') -replace '[\r\n]+', ' ')
                tal_covered = $(if ($isTal) { 'cik_lane_covered' } else { '' })
            })
        }
        if ($fetched -ge $rawTotal -or $n -lt 100) { break }
        Start-Sleep -Milliseconds $DelayMs
    }
    if ($status -eq 'ok' -and $rawTotal -gt ($MaxPagesPerQuery * 100)) { $truncated = 'yes' }
    [void]$summary.Add([PSCustomObject][ordered]@{
        date = $DateStamp; query_id = $qid; lane = ('' + $qr.lane); cadence = ('' + $qr.cadence)
        window_days = $winDays; status = $status; raw_total = $rawTotal; fetched = $fetched
        kept_after_filter = $keptN; dup_within_run = $dupN; tal_covered = $talN
        nontal_entities = $nonTal.Count; truncated = $truncated
        client_filter = $filter
    })
    Write-Host ("[$qid] " + $status + " raw=" + $rawTotal + " kept=" + $keptN + " tal=" + $talN +
                " nontal_entities=" + $nonTal.Count + $(if ($truncated -eq 'yes') { ' TRUNCATED' } else { '' }))
    Start-Sleep -Milliseconds $DelayMs
}

$sumPath = Join-Path $dayRoot 'edgar-battery-summary.csv'
Write-AtomicText -Path $sumPath -Content ((($summary | ConvertTo-Csv -NoTypeInformation) -join "`r`n") + "`r`n")
$hitPath = Join-Path $dayRoot 'edgar-battery-hits.csv'
if ($kept.Count -gt 0) {
    Write-AtomicText -Path $hitPath -Content ((($kept | ConvertTo-Csv -NoTypeInformation) -join "`r`n") + "`r`n")
} else {
    Write-AtomicText -Path $hitPath -Content "query_id,adsh,form,file_date,ciks,sics,display_names,tal_covered`r`n"
}
Write-Host ''
Write-Host ("edgar-battery $DateStamp ($Cadence) done: " + $summary.Count + " queries, " + $kept.Count + " kept hits")
Write-Host ("  summary: " + $sumPath)
Write-Host ("  hits:    " + $hitPath)
Write-Host '  MEASUREMENT MODE: no signal rows emitted; triage does not consume these files until Phase 3 promotion (spec exit criteria).'
exit 0
