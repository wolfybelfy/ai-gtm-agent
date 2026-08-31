# assign-sdrs.ps1 -- deterministically map every account in config\accounts.csv to an SDR
# using the extracted master sheet (data\imports\<date>-sdr-assignments-extracted.csv).
# Match order: normalized domain, then normalized company name (exact only -- no fuzzy).
# No match -> default owner per user rule 2026-07-28 ("auto assign to Sayali"; the sheet
# spells the tab/owner 'Saylee' -- treated as the same person, flagged in the note).
# Multiple distinct owners for one account -> Master-sheet owner wins, all owners noted,
# match flagged manual_review. Output: config\sdr-assignments.csv (internal names only).
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ExtractCsv = '',
    [string]$DefaultOwner = 'Saylee',
    [string]$StampDate = '2026-07-28'
)
$ErrorActionPreference = 'Stop'

if (-not $ExtractCsv) { $ExtractCsv = Join-Path $RepoRoot ('data\imports\' + $StampDate + '-sdr-assignments-extracted.csv') }
$accountsCsv = Join-Path $RepoRoot 'config\accounts.csv'
$outCsv = Join-Path $RepoRoot 'config\sdr-assignments.csv'
foreach ($f in @($ExtractCsv, $accountsCsv)) { if (-not (Test-Path $f)) { Write-Error ("missing input: " + $f); exit 2 } }

function Get-NormDomain([string]$d) {
    $x = $d.Trim().ToLowerInvariant().TrimEnd('/')
    if ($x.StartsWith('www.')) { $x = $x.Substring(4) }
    return $x
}
function Get-NormName([string]$n) {
    return (($n.ToLowerInvariant() -replace '[^a-z0-9]', ''))
}

$sheetRows = @(Import-Csv $ExtractCsv)
$accounts = @(Import-Csv $accountsCsv)

# index sheet rows by normalized domain and normalized name
$byDomain = @{}
$byName = @{}
foreach ($r in $sheetRows) {
    $nd = Get-NormDomain $r.domain
    if ($nd) {
        if (-not $byDomain.ContainsKey($nd)) { $byDomain[$nd] = New-Object System.Collections.Generic.List[object] }
        $byDomain[$nd].Add($r)
    }
    $nn = Get-NormName $r.company_name
    if ($nn) {
        if (-not $byName.ContainsKey($nn)) { $byName[$nn] = New-Object System.Collections.Generic.List[object] }
        $byName[$nn].Add($r)
    }
}

$out = New-Object System.Collections.Generic.List[object]
$summary = New-Object System.Collections.Generic.List[string]
foreach ($a in $accounts) {
    $nd = Get-NormDomain $a.domain
    $nameFull = Get-NormName $a.account_name
    $nameNoParen = Get-NormName (($a.account_name -replace '\(.*?\)', ''))

    $hits = $null
    $matchSource = ''
    if ($byDomain.ContainsKey($nd)) { $hits = $byDomain[$nd]; $matchSource = 'domain' }
    elseif ($byName.ContainsKey($nameFull)) { $hits = $byName[$nameFull]; $matchSource = 'name' }
    elseif ($nameNoParen -ne $nameFull -and $byName.ContainsKey($nameNoParen)) { $hits = $byName[$nameNoParen]; $matchSource = 'name' }

    $owner = ''
    $note = ''
    $matchedSheet = ''
    $matchedRow = ''
    $matchedName = ''
    $matchedDomain = ''
    $sheetComment = ''
    if ($hits) {
        $owners = @($hits | ForEach-Object { $_.owner } | Where-Object { $_ } | Sort-Object -Unique)
        $sheetComment = (@($hits | ForEach-Object { $_.comments } | Where-Object { $_ } | Sort-Object -Unique) -join ' / ')
        $best = @($hits | Where-Object { $_.sheet -eq 'Master' })
        if ($best.Count -eq 0) { $best = @($hits) }
        $pick = $best[0]
        $owner = $pick.owner
        $matchedSheet = $pick.sheet
        $matchedRow = $pick.sheet_row
        $matchedName = $pick.company_name
        $matchedDomain = $pick.domain
        if ($owners.Count -gt 1) {
            $matchSource = $matchSource + '-CONFLICT'
            $note = 'manual_review: multiple owners in sheet [' + ($owners -join ', ') + ']; Master row owner used'
        }
        if (-not $owner) {
            $owner = $DefaultOwner
            $matchSource = $matchSource + '-blank-owner'
            $note = 'matched row had blank owner; default rule applied'
        }
    }
    else {
        $owner = $DefaultOwner
        $matchSource = 'default-sayali-rule'
        $note = 'not present in master sheet; auto-assigned per user rule 2026-07-28 (user spelling Sayali = sheet owner Saylee)'
    }
    if ($a.account_id -eq 'g42') {
        $note = ($note + ' | WATCH-ONLY, NO OUTREACH: owner is bookkeeping only; both holds (Gate-3 UAE, Gate-1 active-prospect) remain').Trim(' |')
    }
    $out.Add([PSCustomObject][ordered]@{
        account_id          = $a.account_id
        account_name        = $a.account_name
        domain              = $a.domain
        sdr_owner           = $owner
        match_source        = $matchSource
        matched_sheet       = $matchedSheet
        matched_sheet_row   = $matchedRow
        matched_company     = $matchedName
        matched_domain      = $matchedDomain
        sheet_comment       = $sheetComment
        assigned_date       = $StampDate
        note                = $note
    })
    $summary.Add($a.account_id + ' -> ' + $owner + ' (' + $matchSource + ')')
}

# output validation before write: one row per account, no blank owners
if ($out.Count -ne $accounts.Count) { Write-Error ("row count mismatch: " + $out.Count + " vs " + $accounts.Count); exit 3 }
$dupes = @($out | Group-Object account_id | Where-Object { $_.Count -gt 1 })
if ($dupes.Count -gt 0) { Write-Error ("duplicate account_ids: " + (($dupes | ForEach-Object { $_.Name }) -join ', ')); exit 3 }
$blank = @($out | Where-Object { -not $_.sdr_owner })
if ($blank.Count -gt 0) { Write-Error ("blank owners: " + (($blank | ForEach-Object { $_.account_id }) -join ', ')); exit 3 }

$tmp = $outCsv + '.tmp'
$text = ($out | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
[System.IO.File]::WriteAllText($tmp, $text, [System.Text.Encoding]::UTF8)
Move-Item -Path $tmp -Destination $outCsv -Force

$summary | ForEach-Object { Write-Output $_ }
$matched = @($out | Where-Object { $_.match_source -notlike 'default*' }).Count
Write-Output ("WROTE: " + $outCsv + " (" + $out.Count + " rows; " + $matched + " matched in sheet, " + ($out.Count - $matched) + " defaulted to " + $DefaultOwner + ")")
exit 0
