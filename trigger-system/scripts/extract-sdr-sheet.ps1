# extract-sdr-sheet.ps1 -- read the SDR master TAL workbook (Excel COM, read-only) and
# flatten every sheet's data rows to one CSV: sheet, row, company_name, domain,
# final_score, assigned_region, owner, comments. Column positions are validated against
# the header row before any data is read (fails loudly on layout drift, never guesses).
# The original xlsx is copied to data\imports\ first (preserve-forever rule).
param(
    [string]$SourceXlsx = "C:\Users\admin\Downloads\Q2 2026 Master SD+SDR TAL (1).xlsx",
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$StampDate = "2026-07-28"
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SourceXlsx)) { Write-Error "Source xlsx not found: $SourceXlsx"; exit 2 }
$importDir = Join-Path $RepoRoot 'data\imports'
if (-not (Test-Path $importDir)) { Write-Error "imports dir missing: $importDir"; exit 2 }

$xlsxCopy = Join-Path $importDir ($StampDate + '-sdr-master-tal.xlsx')
if (-not (Test-Path $xlsxCopy)) { Copy-Item -Path $SourceXlsx -Destination $xlsxCopy }
Write-Output ("PRESERVED: " + $xlsxCopy)

# expected header texts at fixed columns (from the 2026-07-28 structure probe)
$expect = @{ 2 = 'Company Name'; 3 = 'Company domain'; 33 = 'Final Score'; 37 = 'Assigned Region'; 39 = 'Owner'; 40 = 'Comments' }

$outRows = New-Object System.Collections.Generic.List[object]
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
try {
    $wb = $xl.Workbooks.Open($SourceXlsx, 0, $true)
    foreach ($ws in $wb.Worksheets) {
        $name = $ws.Name
        # validate header positions on this sheet
        $headerOk = $true
        foreach ($col in $expect.Keys) {
            $h = [string]$ws.Cells.Item(1, $col).Text
            if ($h.Trim() -ne $expect[$col]) {
                Write-Output ("HEADER MISMATCH sheet=" + $name + " col=" + $col + " expected='" + $expect[$col] + "' got='" + $h + "' -- SHEET SKIPPED, review manually")
                $headerOk = $false
            }
        }
        if (-not $headerOk) { continue }
        # real extent: last non-empty row in column B (Company Name); xlUp = -4162
        $lastRow = $ws.Cells.Item($ws.Rows.Count, 2).End(-4162).Row
        if ($lastRow -lt 2) { Write-Output ("SHEET " + $name + ": no data rows"); continue }
        # bulk read cols 1..40 for rows 2..lastRow
        $arr = $ws.Range($ws.Cells.Item(2, 1), $ws.Cells.Item($lastRow, 40)).Value2
        for ($r = 1; $r -le ($lastRow - 1); $r++) {
            $cname = [string]$arr[$r, 2]
            if (-not $cname -or -not $cname.Trim()) { continue }
            $outRows.Add([PSCustomObject][ordered]@{
                sheet           = $name
                sheet_row       = ($r + 1)
                company_name    = $cname.Trim()
                domain          = ([string]$arr[$r, 3]).Trim()
                final_score     = ([string]$arr[$r, 33]).Trim()
                assigned_region = ([string]$arr[$r, 37]).Trim()
                owner           = ([string]$arr[$r, 39]).Trim()
                comments        = ([string]$arr[$r, 40]).Trim()
            })
        }
        Write-Output ("SHEET " + $name + ": data rows 2.." + $lastRow + " -> " + ($lastRow - 1) + " scanned")
    }
}
finally {
    if ($wb) { $wb.Close($false) }
    $xl.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl) | Out-Null
}

$outCsv = Join-Path $importDir ($StampDate + '-sdr-assignments-extracted.csv')
$tmp = $outCsv + '.tmp'
$text = ($outRows | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
[System.IO.File]::WriteAllText($tmp, $text, [System.Text.Encoding]::UTF8)
Move-Item -Path $tmp -Destination $outCsv -Force
Write-Output ("WROTE: " + $outCsv + " (" + $outRows.Count + " rows)")
exit 0
