# detect-stack-tells.ps1 -- scan a day's ATS snapshots for martech stack-pain tells
# (candidate trigger martech_replatform, added untested 2026-07-28). READS ONLY
# data\snapshots\<date>\ats\* (data already captured); writes data\stack-tells\<date>.csv.
# Standalone + additive: no changes to snapshot/diff machinery; safe to skip any day.
# v1 honesty: matches whatever text the feed payload contains (titles always; full JD
# text only where the ATS includes it). Title-level coverage is recorded in the note.
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)
$ErrorActionPreference = 'Stop'

$snapDir = Join-Path $RepoRoot ("data\snapshots\" + $Date + "\ats")
if (-not (Test-Path $snapDir)) { Write-Error ("no snapshot dir for " + $Date); exit 2 }
$outDir = Join-Path $RepoRoot 'data\stack-tells'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# tell patterns (case-insensitive). Kept precise on purpose - false positives poison rankings.
$tells = @(
    'marketing technology architect',
    'martech modernization',
    'martech manager',
    'marketing analytics engineer',
    'marketing data engineer',
    'marketing operations engineer',
    'MAP consolidation',
    'MAP migration',
    'marketing automation migration',
    'Marketo',
    'Eloqua',
    'Pardot',
    'reverse ETL',
    'Hightouch',
    'warehouse-native'
)

# VENDOR-CONFLICT MAP (built 2026-07-28 from real false positives on day 1):
# if the account SELLS or OWNS the tool, a mention is product/domain vocabulary, NOT stack pain.
# Adobe owns Marketo; Oracle owns Eloqua; Salesforce owns Pardot; warehouse vendors own ETL vocabulary.
$vendorOf = @{
    'marketo'          = @('adobe')
    'eloqua'           = @('oracle', 'netsuite')
    'pardot'           = @('salesforce')
    'reverse etl'      = @('snowflake', 'databricks', 'insightsoftware', 'alteryx')
    'warehouse-native' = @('snowflake', 'databricks')
    'hightouch'        = @('snowflake', 'databricks')
}

$rows = New-Object System.Collections.Generic.List[object]
$files = Get-ChildItem $snapDir -File
foreach ($f in $files) {
    $accountId = ($f.BaseName -replace '\.p\d+$', '')
    $text = [System.IO.File]::ReadAllText($f.FullName)
    foreach ($t in $tells) {
        $pattern = [regex]::Escape($t)
        $matches2 = [regex]::Matches($text, $pattern, 'IgnoreCase')
        if ($matches2.Count -gt 0) {
            $m = $matches2[0]
            $start = [Math]::Max(0, $m.Index - 70)
            $len = [Math]::Min(180, $text.Length - $start)
            $ctx = ($text.Substring($start, $len) -replace '\s+', ' ').Trim()
            $cls = 'stack_fact'
            $vendors = $vendorOf[$t.ToLowerInvariant()]
            if ($vendors -and ($vendors -contains $accountId)) { $cls = 'vendor_noise' }
            $rows.Add([PSCustomObject][ordered]@{
                date            = $Date
                account_id      = $accountId
                tell            = $t
                classification  = $cls
                hit_count       = $matches2.Count
                context_snippet = $ctx
                source_file     = ("data/snapshots/" + $Date + "/ats/" + $f.Name)
            })
        }
    }
}

# collapse multi-page duplicates: keep one row per account+tell with summed hits
$final = $rows | Group-Object { $_.account_id + '|' + $_.tell } | ForEach-Object {
    $first = $_.Group[0]
    $first.hit_count = ($_.Group | Measure-Object hit_count -Sum).Sum
    $first
} | Sort-Object account_id, tell

$outCsv = Join-Path $outDir ($Date + '.csv')
$tmp = $outCsv + '.tmp'
$text2 = (@($final) | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
[System.IO.File]::WriteAllText($tmp, $text2, [System.Text.Encoding]::UTF8)
Move-Item -Path $tmp -Destination $outCsv -Force

$real = @($final | Where-Object { $_.classification -eq 'stack_fact' })
Write-Output ("scanned " + $files.Count + " files; " + @($final).Count + " account+tell pairs (" + $real.Count + " stack_fact, " + (@($final).Count - $real.Count) + " vendor_noise filtered)")
@($final) | ForEach-Object { Write-Output ("  [" + $_.classification + "] " + $_.account_id + " :: " + $_.tell + " x" + $_.hit_count) }
Write-Output "NOTE: stack_fact = the account's own team USES the tool (candidate martech_replatform evidence). A tell is EVIDENCE, never a fired trigger on its own - promotion to scoring requires the weekly review."
Write-Output ("WROTE: " + $outCsv)
exit 0
