# extract-mktg-postings.ps1 - deterministic pre-classifier for the semantic JD read.
#
# WHY: the semantic layer fell 2 weeks behind because it faced the FULL diff (hundreds of rows).
# This step reduces every Monday diff to the handful of marketing-candidate postings, so the
# triage (headless or attended) reads ~20 rows, not ~500. Title-regex is deliberately BROAD -
# the semantic reader disqualifies noise; this script must never silently drop a candidate.
# Output: data\snapshots\<date>\mktg-new-postings.csv (account_id,title,location,job_key,
# reposted_from). job_key resolves to a JD URL from the account's snapshot json at read time.
# Exit: 0 ok (file always written, even 0-row), 2 diff.json missing.
param(
    [string]$DateStamp = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$SnapshotRoot = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Get-TriggerSystemRoot
if ($SnapshotRoot -eq '') { $SnapshotRoot = Join-Path $root 'data\snapshots' }
$diffPath = Join-Path (Join-Path $SnapshotRoot $DateStamp) 'diff.json'
if (-not (Test-Path $diffPath)) { Write-Host "FATAL: no diff.json for $DateStamp"; exit 2 }

$rx = '(?i)marketing|\bbrand\b|communications|\bcomms\b|demand[ -]gen|\bevents?\b|\bABM\b|campaign|\bgrowth\b|\bcontent\b|\bPMM\b|go[ -]to[ -]market|\bGTM\b|field marketing|lifecycle|SEO|paid media|advertising'

$diff = (Get-Content $diffPath -Raw) | ConvertFrom-Json
$rows = New-Object System.Collections.ArrayList
foreach ($a in $diff.accounts) {
    $newJobs = @()
    try { $newJobs = @($a.new) } catch { $newJobs = @() }
    foreach ($j in $newJobs) {
        if ($null -eq $j) { continue }
        $t = ('' + $j.title)
        if ($t -notmatch $rx) { continue }
        $rp = ''
        try { $rp = ('' + $j.reposted_from) } catch { $rp = '' }
        [void]$rows.Add([PSCustomObject][ordered]@{
            account_id = ('' + $a.account_id); title = $t
            location = ('' + $j.location); job_key = ('' + $j.key); reposted_from = $rp
        })
    }
}
$outPath = Join-Path (Join-Path $SnapshotRoot $DateStamp) 'mktg-new-postings.csv'
if ($rows.Count -gt 0) {
    Write-AtomicText -Path $outPath -Content ((($rows | ConvertTo-Csv -NoTypeInformation) -join "`r`n") + "`r`n")
} else {
    Write-AtomicText -Path $outPath -Content "account_id,title,location,job_key,reposted_from`r`n"
}
Write-Host ("extract-mktg-postings {0}: {1} candidate posting(s) -> {2}" -f $DateStamp, $rows.Count, $outPath)
exit 0
