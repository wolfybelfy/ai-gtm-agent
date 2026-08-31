# validate-accounts.ps1 - schema gate for config\accounts.csv (runs at TAL intake, Phase 1,
# and any time rows change). The canonical columns are plan Part D; the ats_type enum is the
# 2026-07-28 widened set (BUILD-STATE decision; reference\ats-endpoints.md).
# Exit codes: 0 = clean, 2 = violations found, 3 = file missing/unreadable.
param(
    [string]$AccountsCsv = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Get-TriggerSystemRoot
if ($AccountsCsv -eq '') { $AccountsCsv = Join-Path $root 'config\accounts.csv' }

$canonical = @('account_id','account_name','domain','ticker','region','ats_type','ats_feed_url','careers_url','newsroom_url','is_client','client_note','sec_edgar','added_date','notes','news_query')
$atsEnum = @('greenhouse','lever','ashby','smartrecruiters','recruitee','workday','page_only','none')
$structured = @('greenhouse','lever','ashby','smartrecruiters','recruitee','workday')

if (-not (Test-Path $AccountsCsv)) { Write-Host "FATAL: not found: $AccountsCsv"; exit 3 }
$violations = New-Object System.Collections.ArrayList
function Add-V([int]$RowNum, [string]$Msg) { [void]$violations.Add("row $RowNum : $Msg") }

# header check against the raw first line (Import-Csv would silently tolerate reordering)
$firstLine = (Get-Content $AccountsCsv -TotalCount 1)
$header = @()
if ($null -ne $firstLine) { $header = $firstLine.Split(',') | ForEach-Object { $_.Trim().Trim('"') } }
$headerOk = $true
if ($header.Count -ne $canonical.Count) { $headerOk = $false }
else { for ($k = 0; $k -lt $canonical.Count; $k++) { if ($header[$k] -ne $canonical[$k]) { $headerOk = $false } } }
if (-not $headerOk) {
    Write-Host "VIOLATION: header mismatch."
    Write-Host "  expected: $($canonical -join ',')"
    Write-Host "  found:    $($header -join ',')"
    exit 2
}

$rows = @()
try { $rows = @(Import-Csv $AccountsCsv) } catch { Write-Host "FATAL: unreadable csv: $($_.Exception.Message)"; exit 3 }
if ($rows.Count -eq 0) { Write-Host "OK (header only, no data rows yet)"; exit 0 }

$seenIds = @{}
$seenDomains = @{}
$n = 1
foreach ($r in $rows) {
    $n++   # header is line 1
    $id = ('' + $r.account_id).Trim()
    if ($id -eq '') { Add-V $n 'account_id empty' }
    elseif ($id -cnotmatch '^[a-z0-9][a-z0-9-]*$') { Add-V $n "account_id '$id' must be lowercase kebab (a-z 0-9 -)" }
    elseif ($seenIds.ContainsKey($id)) { Add-V $n "duplicate account_id '$id' (first at row $($seenIds[$id]))" } else { $seenIds[$id] = $n }

    if (('' + $r.account_name).Trim() -eq '') { Add-V $n 'account_name empty' }

    $dom = ('' + $r.domain).Trim().ToLower()
    if ($dom -eq '') { Add-V $n 'domain empty' }
    elseif ($dom -notmatch '^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$') { Add-V $n "domain '$dom' not a bare domain (no scheme, no path)" }
    elseif ($seenDomains.ContainsKey($dom)) { Add-V $n "duplicate domain '$dom' (first at row $($seenDomains[$dom]))" } else { $seenDomains[$dom] = $n }

    if (('' + $r.region).Trim() -eq '') { Add-V $n 'region empty' }

    $t = ('' + $r.ats_type).Trim().ToLower()
    if ($atsEnum -notcontains $t) { Add-V $n "ats_type '$t' not in enum ($($atsEnum -join '|'))" }
    if ($structured -contains $t) {
        $feed = ('' + $r.ats_feed_url).Trim()
        if ($feed -notmatch '^https://') { Add-V $n "ats_type=$t requires https ats_feed_url (got '$feed')" }
    }
    if ($t -eq 'page_only' -and ('' + $r.careers_url).Trim() -notmatch '^https?://') { Add-V $n 'page_only requires careers_url' }
    if ($t -eq 'none' -and ('' + $r.notes).Trim() -eq '') { Add-V $n "ats_type=none requires a stated reason in notes (no silent blanks - plan Part D)" }

    $ic = ('' + $r.is_client).Trim().ToLower()
    if (@('true','false','yes','no','0','1') -notcontains $ic) { Add-V $n "is_client '$($r.is_client)' not a boolean-ish value" }
    if (@('true','yes','1') -contains $ic -and ('' + $r.client_note).Trim() -eq '') { Add-V $n 'is_client=true requires client_note (which team/engagement)' }

    $ad = ('' + $r.added_date).Trim()
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($ad, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        Add-V $n "added_date '$ad' not yyyy-MM-dd"
    }

    # sec_edgar drives the SEC filings lane. Blank is LEGITIMATE (private co / subsidiary) and
    # produces an explicit not_run ledger row - but a malformed CIK would silently 404 forever.
    $cik = ('' + $r.sec_edgar).Trim()
    if ($cik -ne '' -and $cik -notmatch '^\d{10}$') { Add-V $n "sec_edgar '$cik' must be a zero-padded 10-digit CIK or blank" }

    # news_query drives the news lane. Blank means that account is invisible to it.
    if (('' + $r.news_query).Trim() -eq '') { Add-V $n 'news_query empty - the account would be silently absent from the news lane' }
}

# Informational row-count note only - the list has grown 25 -> 26 -> 36 -> 65 (2026-08-14); no
# fixed target exists anymore, so just print the count (stale hardcoded 25 removed 2026-08-15).
Write-Host "NOTE: $($rows.Count) data rows."

if ($violations.Count -gt 0) {
    Write-Host "$($violations.Count) VIOLATION(S):"
    $violations | ForEach-Object { Write-Host "  - $_" }
    exit 2
}
Write-Host "OK: $($rows.Count) rows, all checks passed."
exit 0
