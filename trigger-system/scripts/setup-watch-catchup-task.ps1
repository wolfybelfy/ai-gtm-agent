# setup-watch-catchup-task.ps1 - scheduler setup for the missed-Monday lifetime fix
# (2026-08-17). Idempotent - safe to re-run any time. Run as the logged-on user (the same
# account that owns trigger-system-monday-watch). Two changes:
#
#   1. trigger-system-monday-watch gains WakeToRun (the machine wakes itself at 08:30 if
#      asleep). StartWhenAvailable REMOVED 2026-08-21 (verified failure: Windows held the
#      missed 08-17 instance and fired it at the NEXT BOOT - Friday 08-21 10:57 - a ghost
#      run 4 days late that burned a claude usage window. The guard below is the SOLE
#      catch-up authority; it knows the failed-counts-as-done rule, Windows does not.)
#   2. registers trigger-system-watch-catchup: runs watch-catchup-guard.ps1 at every logon,
#      daily at 09:00, and hourly (10-year repetition; logon+daily never expire). The guard
#      exits instantly unless this week's Monday run is owed and missing - so a Monday the
#      laptop slept through gets caught within the hour of it waking, and a Monday it was
#      powered off through gets caught at next logon.
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$guard = Join-Path $scriptDir 'watch-catchup-guard.ps1'
if (-not (Test-Path $guard)) { throw "guard script not found: $guard" }

# ---- 1. main task: WakeToRun ON, StartWhenAvailable OFF (2026-08-21 ghost-run fix) ---------
$mainSet = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
           -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 4)
Set-ScheduledTask -TaskName 'trigger-system-monday-watch' -Settings $mainSet | Out-Null
Write-Host 'OK: trigger-system-monday-watch updated (WakeToRun on, StartWhenAvailable off - guard owns catch-up)'

# ---- 2. catch-up guard task ----------------------------------------------------------------
$action = New-ScheduledTaskAction -Execute (Join-Path $PSHOME 'powershell.exe') `
          -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $guard)
$trigLogon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigDaily = New-ScheduledTaskTrigger -Daily -At '09:00'
$hourStart = (Get-Date).AddHours(1)
$hourStart = $hourStart.Date.AddHours($hourStart.Hour)   # next full hour, always in the future
$trigHourly = New-ScheduledTaskTrigger -Once -At $hourStart `
              -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 3650)
$guardSet = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 4) `
            -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'trigger-system-watch-catchup' -Action $action `
    -Trigger $trigLogon, $trigDaily, $trigHourly -Settings $guardSet -Force | Out-Null
Write-Host 'OK: trigger-system-watch-catchup registered (logon + daily 09:00 + hourly)'

# ---- verify --------------------------------------------------------------------------------
foreach ($name in 'trigger-system-monday-watch', 'trigger-system-watch-catchup') {
    $t = Get-ScheduledTask -TaskName $name
    Write-Host ('--- {0}: State={1} WakeToRun={2} StartWhenAvailable={3} BatteryStartBlocked={4}' -f `
        $name, $t.State, $t.Settings.WakeToRun, $t.Settings.StartWhenAvailable, $t.Settings.DisallowStartIfOnBatteries)
}
