# watch-monday.ps1 - the single entry point for the weekly watch run.
#
# WHY: the run is now five steps across four scripts. On 2026-07-28 a lane was skipped by hand and
# nothing on disk recorded it, which delayed the system's first STRIKE by 24 hours. This runner
# exists so "the watch ran" is one command with one verdict, and so a step that did not produce its
# output is a LOUD failure rather than a quiet gap.
#
# Cadence: MONDAY, end to end (user directive 2026-07-29, BUILD-STATE decision log). The accepted
# and logged blind spot is a job posting that opens AND closes inside the same week. Feeds carry
# posted dates, so anything opened mid-week and still open is seen on Monday.
#
# This is a WEB-READING run (CLAUDE.md rule 7): no CRM credentials, no mail, no Outlook COM.
# Draining alerts and any HubSpot write happen in a separate, credential-holding invocation.
#
# Exit codes: 0 = every step ran AND produced its expected output; 1 = at least one step failed.
param(
    [string]$DateStamp = (Get-Date -Format 'yyyy-MM-dd'),
    [int]$MaxPages = 50,               # pinned by BUILD-STATE decision; change only via a logged decision
    [switch]$SkipSnapshot,
    [switch]$SkipSec,
    [switch]$SkipNews
)
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'lib.ps1')

$root = Get-TriggerSystemRoot
$dayRoot = Join-Path $root ("data\snapshots\$DateStamp")
$results = New-Object System.Collections.ArrayList
$psExe = (Join-Path $PSHOME 'powershell.exe')

function Invoke-Step {
    # Runs one script in its own process so a fatal error inside it cannot abort this runner,
    # then checks that the artefact it is supposed to produce actually exists.
    param(
        [string]$Name,
        [string]$Script,
        [string[]]$ScriptArgs,
        [string]$ExpectPath,
        [string]$ExpectDesc,
        [switch]$Skip,
        [string]$SkipReason
    )
    if ($Skip) {
        Write-Host ""
        Write-Host "=== $Name : SKIPPED ($SkipReason)"
        [void]$results.Add([PSCustomObject]@{ step = $Name; exit_code = ''; produced = ''; status = 'SKIPPED'; detail = $SkipReason })
        return
    }
    Write-Host ""
    Write-Host "=== $Name"
    $path = Join-Path $PSScriptRoot $Script
    if (-not (Test-Path $path)) {
        Write-Host "    FAIL - script not found: $path"
        [void]$results.Add([PSCustomObject]@{ step = $Name; exit_code = ''; produced = 'no'; status = 'FAIL'; detail = "script missing: $Script" })
        return
    }
    # The repo path contains a space ("ICP Converstion Intelligence"). Start-Process joins
    # -ArgumentList with spaces, so an unquoted path is split and powershell.exe reports
    # "the file does not have a '.ps1' extension". Quote it explicitly.
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $path + '"')) + $ScriptArgs
    $p = Start-Process -FilePath $psExe -ArgumentList $argList -NoNewWindow -Wait -PassThru
    $code = $p.ExitCode

    $produced = 'n/a'
    $ok = ($code -eq 0)
    if ($ExpectPath -ne '') {
        if (Test-Path $ExpectPath) { $produced = 'yes' } else { $produced = 'no'; $ok = $false }
    }
    $status = 'OK'; $detail = ''
    if (-not $ok) {
        $status = 'FAIL'
        if ($code -ne 0) { $detail = "exit $code" }
        if ($produced -eq 'no') { $detail = (($detail + '; ' + $ExpectDesc + ' not written').Trim('; ')) }
    }
    Write-Host ("    exit=$code  produced=$produced  -> $status")
    [void]$results.Add([PSCustomObject]@{ step = $Name; exit_code = $code; produced = $produced; status = $status; detail = $detail })
}

Write-Host "watch-monday $DateStamp  (MaxPages=$MaxPages)"
Write-Host "repo: $root"

# 0. config gate. A broken accounts.csv would make every downstream step lie quietly.
Invoke-Step -Name 'validate-accounts' -Script 'validate-accounts.ps1' -ScriptArgs @() -ExpectPath '' -ExpectDesc ''

# 1. ATS capture
Invoke-Step -Name 'snapshot' -Script 'snapshot.ps1' `
    -ScriptArgs @('-DateStamp', $DateStamp, '-MaxPages', "$MaxPages") `
    -ExpectPath (Join-Path $dayRoot 'manifest.csv') -ExpectDesc 'manifest.csv' `
    -Skip:$SkipSnapshot -SkipReason 'requested by -SkipSnapshot'

# 2. ATS change detection. This also FINALIZES manifest coverage_state to checked_changed /
#    checked_unchanged, so the ats_jobs ledger row is only truthful after this step.
Invoke-Step -Name 'diff' -Script 'diff.ps1' `
    -ScriptArgs @('-DateStamp', $DateStamp) `
    -ExpectPath (Join-Path $dayRoot 'diff.json') -ExpectDesc 'diff.json' `
    -Skip:$SkipSnapshot -SkipReason 'nothing new to diff (-SkipSnapshot)'

# 2b. marketing-candidate extraction from the diff - feeds the semantic JD read (headless or
#     attended) a ~20-row file instead of the full diff. Added 2026-08-03 after the semantic
#     read fell 2 weeks behind facing raw diffs.
Invoke-Step -Name 'extract-mktg' -Script 'extract-mktg-postings.ps1' `
    -ScriptArgs @('-DateStamp', $DateStamp) `
    -ExpectPath (Join-Path $dayRoot 'mktg-new-postings.csv') -ExpectDesc 'mktg-new-postings.csv' `
    -Skip:$SkipSnapshot -SkipReason 'no fresh diff (-SkipSnapshot)'

# 3. martech stack tells (evidence-only lane)
Invoke-Step -Name 'stack-tells' -Script 'detect-stack-tells.ps1' `
    -ScriptArgs @('-Date', $DateStamp) `
    -ExpectPath (Join-Path $root "data\stack-tells\$DateStamp.csv") -ExpectDesc 'stack-tells csv'

# 4. SEC + news lanes, and the coverage ledger for EVERY lane including the ones nobody ran
$csArgs = @('-DateStamp', $DateStamp)
if ($SkipSec)  { $csArgs += '-SkipSec' }
if ($SkipNews) { $csArgs += '-SkipNews' }
Invoke-Step -Name 'collect-signals' -Script 'collect-signals.ps1' `
    -ScriptArgs $csArgs `
    -ExpectPath (Join-Path $dayRoot 'coverage.csv') -ExpectDesc 'coverage.csv'

# EDGAR full-text query battery (EDGAR module spec section 7) - MEASUREMENT MODE until the
# Phase 3 exit criteria pass (per-query baselines + noise queries tightened). Its outputs are
# hit-count evidence only; triage does NOT consume them yet (headless prompt says so too).
Invoke-Step -Name 'edgar-battery' -Script 'edgar-battery.ps1' `
    -ScriptArgs @('-DateStamp', $DateStamp, '-Cadence', 'weekly') `
    -ExpectPath (Join-Path $dayRoot 'edgar-battery-summary.csv') -ExpectDesc 'edgar-battery-summary.csv' `
    -Skip:$SkipSec -SkipReason 'EDGAR network work skipped by -SkipSec'

# ---------------------------------------------------------------- verdict
Write-Host ""
Write-Host "================ watch-monday $DateStamp ================"
foreach ($r in $results) {
    $line = "  " + ('' + $r.step).PadRight(20) + ('' + $r.status).PadRight(9) + ("exit=" + $r.exit_code).PadRight(16) + ("produced=" + $r.produced).PadRight(15)
    if (('' + $r.detail) -ne '') { $line += ('' + $r.detail) }
    Write-Host $line
}

$failed  = @($results | Where-Object { $_.status -eq 'FAIL' })
$skipped = @($results | Where-Object { $_.status -eq 'SKIPPED' })

# receipt on disk: a run that was never recorded is indistinguishable from a run that never happened
$receipt = @("watch-monday run receipt", "date: $DateStamp", "max_pages: $MaxPages", "") +
           ($results | ForEach-Object { "$($_.step): $($_.status) exit=$($_.exit_code) produced=$($_.produced) $($_.detail)" }) +
           @("", "verdict: " + $(if ($failed.Count -gt 0) { "FAIL ($($failed.Count) step(s))" } else { "PASS" }))
if (Test-Path $dayRoot) { Write-AtomicText -Path (Join-Path $dayRoot 'watch-run.txt') -Content (($receipt -join "`r`n") + "`r`n") }

if ($skipped.Count -gt 0) { Write-Host ("  NOTE: $($skipped.Count) step(s) skipped by switch - this run is NOT a full watch.") }
if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "VERDICT: FAIL - $($failed.Count) step(s) did not complete. Do NOT treat today as covered."
    Write-Host "         coverage.csv is the per-account, per-lane truth; read it before scoring anything."
    exit 1
}
Write-Host ""
Write-Host "VERDICT: PASS - every step ran and produced its output."
Write-Host "  next: read data\snapshots\$DateStamp\signals-new.csv and coverage.csv, then runbooks\monday-watch.md step 3 onward."
exit 0
