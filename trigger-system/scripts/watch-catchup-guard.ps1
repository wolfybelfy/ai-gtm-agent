# watch-catchup-guard.ps1 - makes a missed Monday watch impossible to stay missed.
#
# WHY THIS EXISTS (2026-08-17, verified failure): the 08:30 Monday trigger missed because the
# laptop was asleep (WakeToRun was off) and Windows' StartWhenAvailable catch-up provably did
# NOT fire after resume - LastRunTime stayed 08-10, NumberOfMissedRuns=1, machine awake all
# afternoon, no run. Scheduler-native catch-up is unreliable after sleep-resume, so we stop
# depending on it: this guard runs at every logon, daily at 09:00, and hourly; it exits
# silently unless this week's Monday run is OWED and MISSING, in which case it launches the
# exact chain the 08:30 task would have (run-monday-unattended.ps1, which queues its own
# [SYSTEM] FAIL alerts and writes the same logs).
#
# Decision rule:
#   deadline  = most recent Monday 08:30 (local time)
#   satisfied = any logs\unattended\YYYY-MM-DD-unattended.log dated >= that Monday
#   owed      = now >= deadline AND not satisfied AND main task not currently Running
# A FAILED run still counts as satisfied on purpose: the wrapper already queued a FAIL alert
# and recovery is an attended job - hourly full-chain retries against 65 live sources would
# be a hammering loop, not a fix.
# Concurrency: main-task Running check + named mutex; the task itself is registered with
# MultipleInstances=IgnoreNew as a third layer.
# Exit codes: 0 = nothing owed, stood down, or catch-up ran clean; 1 = catch-up ran and failed.
param(
    [switch]$WhatIfOnly   # print the decision, launch nothing
)
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Get-TriggerSystemRoot
$logDir = Join-Path $root 'logs\unattended'
$guardLog = Join-Path $logDir 'catchup-guard.log'

function GLog([string]$Msg) {
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    $line = ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Msg)
    Write-Host $line
    Add-Content -Path $guardLog -Value $line -Encoding UTF8
}

# ---- 1. when was this week's run due? ------------------------------------------------------
$now = Get-Date
$daysSinceMonday = (([int]$now.DayOfWeek) + 6) % 7   # Monday=0 ... Sunday=6
$monday = $now.Date.AddDays(-$daysSinceMonday)
$deadline = $monday.AddHours(8).AddMinutes(30)
if ($now -lt $deadline) { exit 0 }   # Monday before 08:30 - nothing due yet

# ---- 2. did a run already happen this week? (wrapper logs are named by run date) -----------
$satisfied = $false
if (Test-Path $logDir) {
    foreach ($f in (Get-ChildItem -Path $logDir -Filter '*-unattended.log' -File)) {
        if ($f.Name -match '^(\d{4}-\d{2}-\d{2})-unattended\.log$') {
            $d = $null
            try { $d = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null) } catch { continue }
            if ($null -ne $d -and $d -ge $monday) { $satisfied = $true; break }
        }
    }
}
if ($satisfied) { exit 0 }

# ---- 3. is the main task mid-run right now? (fired at 08:30, still working) ----------------
try {
    $t = Get-ScheduledTask -TaskName 'trigger-system-monday-watch' -ErrorAction Stop
    if ($t.State -eq 'Running') {
        GLog 'run owed but trigger-system-monday-watch is Running - standing down'
        exit 0
    }
} catch { }   # task missing/unreadable: the guard still catches up

if ($WhatIfOnly) {
    GLog ('WhatIf: run for week of {0:yyyy-MM-dd} is OWED and MISSING - would launch now' -f $monday)
    exit 0
}

# ---- 4. one guard at a time (logon trigger + hourly tick can coincide) ---------------------
$mtx = $null
try { $mtx = New-Object System.Threading.Mutex($false, 'Global\trigger-system-watch-catchup') }
catch { $mtx = New-Object System.Threading.Mutex($false, 'Local\trigger-system-watch-catchup') }
$acquired = $false
try { $acquired = $mtx.WaitOne(0) }
catch [System.Threading.AbandonedMutexException] { $acquired = $true }  # prior guard died holding it; ownership passed to us
if (-not $acquired) { exit 0 }

# ---- 5. launch the real chain --------------------------------------------------------------
try {
    GLog ('run for week of {0:yyyy-MM-dd} MISSED (deadline {1:yyyy-MM-dd HH:mm}) - launching run-monday-unattended.ps1' -f $monday, $deadline)
    $psExe = Join-Path $PSHOME 'powershell.exe'
    & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run-monday-unattended.ps1')
    $code = $LASTEXITCODE
    GLog ('catch-up run finished, wrapper exit={0}' -f $code)
    if ($code -ne 0) { exit 1 }
    exit 0
} finally {
    try { $mtx.ReleaseMutex() | Out-Null } catch { }
    $mtx.Dispose()
}
