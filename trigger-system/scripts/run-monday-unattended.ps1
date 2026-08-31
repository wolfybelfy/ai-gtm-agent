# run-monday-unattended.ps1 - the SCHEDULED Monday entry point (no human present).
#
# Chain (each stage its own process, rule-7 separation):
#   1. watch-monday.ps1        deterministic capture/diff/signals (holds no credentials by design)
#   2. claude.exe -p           HEADLESS semantic triage per runbooks\monday-headless-prompt.md
#                              -> credentials are STRIPPED from its environment here (rule 7:
#                              a web-reading session holds no CRM/enrichment credentials).
#                              Writes the digest alert + staging\play-queue\<date>.csv for 2b.
#   2b. claude.exe -p          HEADLESS play build per runbooks\play-build-headless.md (added
#                              2026-08-17; Clay removed 2026-08-24 by user order - builds run
#                              from on-disk rosters/maps with staleness flags; people-data
#                              verification is stage 2c's job via ZoomInfo). No credentials,
#                              web tools DISABLED (--disallowedTools WebFetch WebSearch).
#                              Runs only if stage 2 succeeded AND the play queue has rows.
#   3. alert-mailer.ps1        separate credential-clean process; drains staging\alerts\ to the
#                              INTERNAL recipients in config\alert-recipients.csv only
# Any stage failing -> a [FAIL] alert file is queued so stage 3 reports it to the team.
# Registered in Task Scheduler as 'trigger-system-monday-watch' (weekly, MON). -SmokeTest
# exercises the chain without the watcher/mailer. Exit: 0 all stages ok, 1 otherwise.
param(
    [switch]$SmokeTest,
    [string]$ClaudeExe = 'C:\Users\admin\.local\bin\claude.exe',
    # user directive 2026-08-03: analysis quality > cost for the weekly triage.
    # MODEL HISTORY (keep - it explains itself the next time a limit trips):
    #   - claude-fable-5 from 2026-08-03 (the directive's chosen implementation).
    #   - 2026-08-25: fable-5 returned "You've hit your monthly spend limit. Switch to
    #     another model to continue." on upawar@unboundia.com while opus-5 / sonnet-5 /
    #     haiku-4.5 all answered HEADLESS-OK the same minute -> default moved to
    #     claude-opus-5 as an emergency substitution, -SmokeTest proven.
    #   - 2026-08-26: fable-5 re-tested on the same account -> HEADLESS-OK exit 0 (the user
    #     enabled usage credits); the limit premise expired, so the directive's chosen model
    #     is RESTORED. claude-opus-5 remains the proven fallback: if fable-5 trips again,
    #     pass -ClaudeModel claude-opus-5 (or re-edit this default) - the whole chain is
    #     model-agnostic beyond this one parameter.
    [string]$ClaudeModel = 'claude-fable-5',
    [int]$ClaudeTimeoutMin = 90,
    [int]$PlayBuildTimeoutMin = 60,
    [int]$RetryWaitMin = 15   # pause before the one limit-class retry (parameterized so tests need not sleep 15m)
)
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Get-TriggerSystemRoot
$stamp = Get-Date -Format 'yyyy-MM-dd'
$logDir = Join-Path $root 'logs\unattended'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
# -SmokeTest logs under a DIFFERENT name (2026-08-26): watch-catchup-guard.ps1 counts any
# <date>-unattended.log dated >= Monday as "this week's run happened", so a smoke log written
# mid-week would MASK a missed Monday and the guard would never catch up. Smoke evidence also
# must not overwrite a real run's log/outputs from the same day.
$logLeaf = "$stamp-unattended.log"
if ($SmokeTest) { $logLeaf = "$stamp-smoketest.log" }
$log = Join-Path $logDir $logLeaf
$smokePfx = ''
if ($SmokeTest) { $smokePfx = 'smoketest-' }
$overallOk = $true
$psExe = (Join-Path $PSHOME 'powershell.exe')

function Log([string]$Msg) {
    $line = ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Msg)
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding UTF8
}
function Queue-FailAlert([string]$Stage, [string]$Detail) {
    $alertDir = Join-Path $root 'staging\alerts'
    if (-not (Test-Path $alertDir)) { New-Item -ItemType Directory -Force -Path $alertDir | Out-Null }
    $safe = ($Detail -replace '[\r\n]+', ' ')
    if ($safe.Length -gt 900) { $safe = $safe.Substring(0, 900) }
    # TYPE must be one the mailer accepts (alert-mailer.ps1 validTypes) or the failure
    # notice itself is skipped as malformed and never mailed - found 2026-08-15 sweep.
    $body = @(
        'TYPE: SYSTEM',
        ('SUBJECT: [SYSTEM] FAIL: unattended Monday run {0} - stage {1} failed' -f $stamp, $Stage),
        'TO: default',
        'STATUS: pending',
        '',
        ('Stage: ' + $Stage),
        ('Detail: ' + $safe),
        ('Log: logs\unattended\' + $logLeaf),
        'Action: open a claude session in trigger-system and say "unattended Monday failed - recover".'
    ) -join "`r`n"
    $file = Join-Path $alertDir ("$stamp-fail-$Stage.md")
    Set-Content -Path $file -Value $body -Encoding UTF8
    Log "queued FAIL alert: $file"
}

# Shared headless-claude invoker (extracted 2026-08-17 when stage 2b was added; behavior for
# stage 2 is byte-for-byte the proven 2026-08-17 retry-once logic).
# Retry-once-on-limit (added 2026-08-17, VERIFIED transient class): the 18:00 catch-up run was
# refused in 15s with "You've hit your monthly spend limit. Switch to another model to
# continue." yet the IDENTICAL call succeeded ~90 min later and the account showed remaining
# quota. That refusal class is transient - one retry after a pause keeps a whole Monday's work
# from dying on it. Timeouts do NOT retry (a long hang is a different class and doubling it
# risks the 4h task limit). Returns $true on success.
function Invoke-HeadlessClaude {
    param(
        [string]$StageLabel,      # for Log lines
        [string]$Prompt,
        [string]$OutPrefix,       # output file: <stamp>-<OutPrefix>[-retry].txt
        [int]$TimeoutMin,
        [string]$ExtraArgs = '',  # appended after --model (already-quoted fragments only)
        [string]$FailName,        # Queue-FailAlert stage name on non-limit failure
        [string]$TimeoutFailName, # Queue-FailAlert stage name on timeout
        [string]$ExpectText = ''  # if set, exit-0 output must contain this text (smoke checks)
    )
    $maxAttempts = 2
    $limitPattern = '(?i)spend limit|usage limit|rate limit|overloaded|try again later'
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $suffix = ''
        if ($attempt -gt 1) { $suffix = '-retry' }   # keep attempt 1's output as evidence
        $outFile = Join-Path $logDir ("$stamp-$OutPrefix$suffix.txt")
        Log "$StageLabel : invoking claude -p (model=$ClaudeModel, timeout=${TimeoutMin}m, attempt $attempt/$maxAttempts)"
        # Start-Process joins -ArgumentList with spaces WITHOUT quoting (verified failure in
        # the first smoke test: the prompt fragmented and claude saw no request). Quote explicitly.
        $q = ('"' + ($Prompt -replace '"', '\"') + '"')
        $argStr = "-p $q --model $ClaudeModel"
        if ($ExtraArgs) { $argStr += " $ExtraArgs" }
        $proc = Start-Process -FilePath $ClaudeExe -ArgumentList $argStr -WorkingDirectory $root `
                -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError ($outFile + '.err')
        $null = $proc.Handle   # PS 5.1: cache the handle NOW or ExitCode is unreadable after exit
        if (-not $proc.WaitForExit($TimeoutMin * 60 * 1000)) {
            $proc.Kill()
            Queue-FailAlert -Stage $TimeoutFailName -Detail "claude -p exceeded $TimeoutMin minutes and was killed; partial work may be uncommitted"
            Log "$StageLabel TIMEOUT - killed"
            return $false
        }
        $proc.WaitForExit()   # PS 5.1: timed WaitForExit(true) can leave ExitCode unset until a blocking wait
        Log ("$StageLabel exit=" + $proc.ExitCode + " (attempt $attempt)")
        $tail = ''
        if (Test-Path $outFile) { $tail = (Get-Content $outFile -Tail 5) -join ' | ' }
        if ($proc.ExitCode -eq 0) {
            if ($ExpectText -ne '' -and (Test-Path $outFile)) {
                $txt = Get-Content $outFile -Raw
                if ($txt -match [regex]::Escape($ExpectText)) { Log "$StageLabel : expected text confirmed" }
                else { Log "$StageLabel FAIL: expected text '$ExpectText' not found"; return $false }
            }
            return $true
        }
        if ($attempt -lt $maxAttempts -and $tail -match $limitPattern) {
            Log ("$StageLabel : limit-class refusal ('" + $tail + "') - waiting $RetryWaitMin min, then one retry")
            Start-Sleep -Seconds ($RetryWaitMin * 60)
            continue
        }
        Queue-FailAlert -Stage $FailName -Detail ("claude -p exit " + $proc.ExitCode + " after $attempt attempt(s); tail: " + $tail)
        return $false
    }
    return $false
}

Log "=== unattended Monday run start (SmokeTest=$SmokeTest) root=$root"

# ---- claude account pin (ROOT CAUSE of the 08-17 + 08-21 spend-limit failures, found
# 2026-08-21): CLAUDE_CONFIG_DIR was only ever set in interactive shells, and this task runs
# -NoProfile - so headless claude fell back to a DIFFERENT account than the intended one.
# Pin it explicitly so every child claude in this chain uses the intended account.
#
# ACCOUNT MIGRATED 2026-08-25: the pinned .claude2 account (perfectlearnerforyou@gmail.com)
# lost Claude Code access at 15:04Z ("Your organization has disabled Claude subscription
# access for Claude Code"). Every headless stage (2, 2b) would have failed on the 08-31 run.
# Repointed to ~\.claude (upawar@unboundia.com, UNBOUND IA) - the live account. Proven with
# run-monday-unattended.ps1 -SmokeTest the same day. The 08-21 lesson still holds: this MUST
# stay pinned, because -NoProfile means no interactive env var ever reaches this task.
$env:CLAUDE_CONFIG_DIR = 'C:\Users\admin\.claude'
Log "claude config pinned: CLAUDE_CONFIG_DIR=$env:CLAUDE_CONFIG_DIR"

# ---- stage 1: deterministic watcher --------------------------------------------------------
if (-not $SmokeTest) {
    Log 'stage 1: watch-monday.ps1'
    & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'watch-monday.ps1') *>> $log
    $code = $LASTEXITCODE
    Log "stage 1 exit=$code"
    if ($code -ne 0) { $overallOk = $false; Queue-FailAlert -Stage 'watcher' -Detail "watch-monday.ps1 exit $code - see log; claude triage still attempted on partial outputs" }
} else { Log 'stage 1 skipped (SmokeTest)' }

# ---- stage 2: headless claude triage (web-reading -> NO credentials) -----------------------
$stage2Ok = $false
if (-not (Test-Path $ClaudeExe)) {
    $overallOk = $false
    Queue-FailAlert -Stage 'claude-missing' -Detail "claude.exe not found at $ClaudeExe"
} else {
    # rule 7: the web-reading semantic session must hold no credentials. Capture the ZoomInfo
    # pair first (stage 2c enrichment legitimately needs it restored; re-adopted 2026-08-20).
    # Clay REMOVED entirely 2026-08-24 by user order - no Clay key exists anywhere anymore.
    $ziIdCap = $env:ZOOMINFO_CLIENT_ID
    $ziSecretCap = $env:ZOOMINFO_CLIENT_SECRET
    Remove-Item Env:HUBSPOT_PRIVATE_APP_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:ZOOMINFO_CLIENT_ID -ErrorAction SilentlyContinue
    Remove-Item Env:ZOOMINFO_CLIENT_SECRET -ErrorAction SilentlyContinue
    Remove-Item Env:TEAMS_ALERT_WEBHOOK_URL -ErrorAction SilentlyContinue   # post-capable secret (alert-teams.ps1)
    Log 'stage 2: credentials stripped from child environment'
    if ($SmokeTest) {
        $prompt = 'Reply with exactly: HEADLESS-OK'
        $extra = ''
        $expect = 'HEADLESS-OK'
    } else {
        $prompt = ('Read the file runbooks\monday-headless-prompt.md in this repo and follow it exactly. Today is {0}.' -f $stamp)
        $extra = '--dangerously-skip-permissions'
        $expect = ''
    }
    Push-Location $root
    try {
        $stage2Ok = Invoke-HeadlessClaude -StageLabel 'stage 2' -Prompt $prompt -OutPrefix ($smokePfx + 'claude-out') `
                    -TimeoutMin $ClaudeTimeoutMin -ExtraArgs $extra -FailName 'claude-triage' `
                    -TimeoutFailName 'claude-timeout' -ExpectText $expect
    } finally { Pop-Location }
    if (-not $stage2Ok) { $overallOk = $false }

    # ---- stage 2b: headless play build (on-disk data only -> NO web) -----------------------
    # Builds run from on-disk rosters/maps with staleness flags (Clay removed 2026-08-24);
    # roster/email verification is stage 2c's job (ZoomInfo). WebFetch/WebSearch disabled at
    # the CLI; ALL secrets remain stripped. Skipped when triage failed (no trustworthy queue)
    # or when the queue is empty (quiet week - no claude spend).
    if ($SmokeTest) {
        Push-Location $root
        try {
            $ok2b = Invoke-HeadlessClaude -StageLabel 'stage 2b' -Prompt 'Reply with exactly: HEADLESS-OK' `
                    -OutPrefix 'smoketest-playbuild-out' -TimeoutMin $PlayBuildTimeoutMin -ExtraArgs '' `
                    -FailName 'play-build' -TimeoutFailName 'play-build-timeout' -ExpectText 'HEADLESS-OK'
        } finally { Pop-Location }
        if (-not $ok2b) { $overallOk = $false }
    } elseif (-not $stage2Ok) {
        Log 'stage 2b skipped: triage failed - no trustworthy play queue'
    } else {
        $queueFile = Join-Path $root ("staging\play-queue\$stamp.csv")
        $queueRows = 0
        if (Test-Path $queueFile) { $queueRows = ((Get-Content $queueFile | Measure-Object -Line).Lines - 1) }
        if ($queueRows -le 0) {
            Log "stage 2b skipped: play queue empty ($queueFile rows=$queueRows)"
        } else {
            Log "stage 2b: play queue has $queueRows row(s)"
            Log 'stage 2b: no credentials (builds run on on-disk rosters; ZoomInfo verifies at stage 2c)'
            $prompt2b = ('Read the file runbooks\play-build-headless.md in this repo and follow it exactly. Today is {0}.' -f $stamp)
            Push-Location $root
            try {
                $ok2b = Invoke-HeadlessClaude -StageLabel 'stage 2b' -Prompt $prompt2b -OutPrefix 'playbuild-out' `
                        -TimeoutMin $PlayBuildTimeoutMin -ExtraArgs '--dangerously-skip-permissions --disallowedTools WebFetch WebSearch' `
                        -FailName 'play-build' -TimeoutFailName 'play-build-timeout'
            } finally { Pop-Location }
            if (-not $ok2b) { $overallOk = $false }
        }
    }
}

# ---- stage 2c: deterministic verified-email enrichment (ZoomInfo; added 2026-08-20) --------
# Runs AFTER the play build, over the same play queue, as a deterministic script (no model).
# Credentials restored ONLY for this stage; the web-reading stage 2 never held them (rule 7).
# Missing credentials or an empty queue = logged skip, never a failure - the stage
# self-activates on the first run after the user sets ZOOMINFO_CLIENT_ID/SECRET.
if (-not $SmokeTest) {
    $ziHave = $false
    try { $ziHave = (-not [string]::IsNullOrWhiteSpace($ziIdCap)) -and (-not [string]::IsNullOrWhiteSpace($ziSecretCap)) } catch { $ziHave = $false }
    if ($ziHave) {
        $env:ZOOMINFO_CLIENT_ID = $ziIdCap
        $env:ZOOMINFO_CLIENT_SECRET = $ziSecretCap
        Log 'stage 2c: zoominfo-enrich.ps1 -Auto -Execute (credentials restored for this stage only)'
        & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'zoominfo-enrich.ps1') -Auto -Execute *>> $log
        $code = $LASTEXITCODE
        Remove-Item Env:ZOOMINFO_CLIENT_ID -ErrorAction SilentlyContinue
        Remove-Item Env:ZOOMINFO_CLIENT_SECRET -ErrorAction SilentlyContinue
        Log "stage 2c exit=$code"
        if ($code -eq 3) { Log 'stage 2c WARN: child reported credentials absent - skipped' }
        elseif ($code -ne 0) { $overallOk = $false; Queue-FailAlert -Stage 'zoominfo-enrich' -Detail "zoominfo-enrich.ps1 exit $code - see log; failure paths write nothing to buying groups" }
    } else {
        Log 'stage 2c skipped: ZOOMINFO_CLIENT_ID/SECRET not set (set them and this stage self-activates)'
    }
} else { Log 'stage 2c skipped (SmokeTest)' }

# ---- stage 3: internal alert mailer (separate credential-clean process) --------------------
if (-not $SmokeTest) {
    Log 'stage 3: alert-mailer.ps1 drain'
    & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'alert-mailer.ps1') *>> $log
    $code = $LASTEXITCODE
    Log "stage 3 exit=$code"
    if ($code -ne 0) { $overallOk = $false; Log 'stage 3 reported failures - alerts remain queued for the next attended session' }
} else { Log 'stage 3 skipped (SmokeTest)' }

# ---- stage 3b: Teams channel cards (added 2026-08-20, lane live) ---------------------------
# Posts unstamped staging\alerts\*.md as Adaptive Cards. The webhook was stripped from this
# process at stage 2 (rule 7); the child re-reads the User-scope env var from the registry
# (alert-teams.ps1's documented fallback). Exit 2 = webhook unconfigured -> WARN only, never
# a run failure; real post failures fail the run and the files stay unstamped for retry.
if (-not $SmokeTest) {
    Log 'stage 3b: alert-teams.ps1 post'
    & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'alert-teams.ps1') -Execute *>> $log
    $code = $LASTEXITCODE
    Log "stage 3b exit=$code"
    if ($code -eq 2) { Log 'stage 3b WARN: no webhook configured - Teams lane skipped, run not failed' }
    elseif ($code -ne 0) { $overallOk = $false; Log 'stage 3b reported failures - cards stay unstamped for retry' }
} else { Log 'stage 3b skipped (SmokeTest)' }

Log ("=== unattended Monday run end - overallOk=" + $overallOk)
if ($overallOk) { exit 0 } else { exit 1 }
