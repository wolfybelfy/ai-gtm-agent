# extract-sdr-signals.ps1 -- pull the SDR master sheet's RESEARCH SIGNAL columns (M&A,
# expansion, senior hire, funding, growth, prestige, scores) for the accounts in
# config\accounts.csv. Read-only COM. Accounts absent from the sheet produce NO row
# (they stay blank in the workbook -- "not researched" is a real state, never faked).
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$SourceXlsx = '',
    [string]$StampDate = '2026-07-28'
)
$ErrorActionPreference = 'Stop'
if (-not $SourceXlsx) { $SourceXlsx = Join-Path $RepoRoot ('data\imports\' + $StampDate + '-sdr-master-tal.xlsx') }
if (-not (Test-Path $SourceXlsx)) { Write-Error ("missing: " + $SourceXlsx); exit 2 }

$accounts = @(Import-Csv (Join-Path $RepoRoot 'config\accounts.csv'))
$want = @{}
foreach ($a in $accounts) {
    $d = $a.domain.Trim().ToLowerInvariant()
    if ($d.StartsWith('www.')) { $d = $d.Substring(4) }
    $want[$d] = $a.account_id
}

# column map validated against the header row before reading (fail loud on drift)
$cols = [ordered]@{
    company_name        = 2
    domain              = 3
    total_job_count     = 9
    has_expansion_news  = 11
    expansion_reasoning = 12
    senior_mktg_hire    = 13
    qualifying_hire     = 14
    is_role_senior      = 15
    latest_round_i4     = 16
    rebrand_pivot       = 17
    rebrand_presence    = 18
    employee_count      = 20
    pct_emp_growth_3    = 21
    prestige_status     = 23
    on_prestige_list    = 24
    ma_activity         = 27
    ma_available        = 28
    ma_summary          = 30
    icp_scoring         = 31
    intent_change_score = 32
    final_score         = 33
    latest_round        = 34
    has_series_a_plus   = 35
    assigned_region     = 37
    owner               = 39
    comments            = 40
}
$expectHeaders = @{ 2 = 'Company Name'; 3 = 'Company domain'; 33 = 'Final Score'; 39 = 'Owner' }

$out = New-Object System.Collections.Generic.List[object]
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
try {
    $wb = $xl.Workbooks.Open($SourceXlsx, 0, $true)
    $ws = $wb.Worksheets.Item('Master')
    foreach ($k in $expectHeaders.Keys) {
        $h = [string]$ws.Cells.Item(1, $k).Text
        if ($h.Trim() -ne $expectHeaders[$k]) { Write-Error ("header drift col " + $k + ": '" + $h + "'"); exit 3 }
    }
    $lastRow = $ws.Cells.Item($ws.Rows.Count, 2).End(-4162).Row
    $arr = $ws.Range($ws.Cells.Item(2, 1), $ws.Cells.Item($lastRow, 40)).Value2
    for ($r = 1; $r -le ($lastRow - 1); $r++) {
        $dom = ([string]$arr[$r, 3]).Trim().ToLowerInvariant()
        if ($dom.StartsWith('www.')) { $dom = $dom.Substring(4) }
        if (-not $dom -or -not $want.ContainsKey($dom)) { continue }
        $rec = [ordered]@{ account_id = $want[$dom]; sheet_row = ($r + 1) }
        foreach ($name in $cols.Keys) {
            $v = $arr[$r, $cols[$name]]
            $rec[$name] = if ($null -eq $v) { '' } else { ([string]$v).Trim() }
        }
        $out.Add([PSCustomObject]$rec)
    }
}
finally {
    if ($wb) { $wb.Close($false) }
    $xl.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl) | Out-Null
}

$outCsv = Join-Path $RepoRoot ('data\imports\' + $StampDate + '-sdr-signals-for-accounts.csv')
$tmp = $outCsv + '.tmp'
[System.IO.File]::WriteAllText($tmp, (($out | ConvertTo-Csv -NoTypeInformation) -join "`r`n"), [System.Text.Encoding]::UTF8)
Move-Item -Path $tmp -Destination $outCsv -Force
Write-Output ("matched " + $out.Count + " of " + $accounts.Count + " accounts in the SDR master sheet")
$out | ForEach-Object { Write-Output ("  " + $_.account_id + " | M&A=" + $_.ma_activity + " | expansion=" + $_.has_expansion_news + " | senior_hire=" + $_.qualifying_hire + " | score=" + $_.final_score) }
Write-Output ("WROTE: " + $outCsv)
exit 0
