# fix-outlook-prompts.ps1 - one-time, run ELEVATED (right-click > Run as administrator, or via
# the Start-Process -Verb RunAs command Claude provides). Purpose: stop Outlook's Object Model
# Guard from asking "Allow?" on every programmatic send from the alert mailer.
# Sets BOTH known control points (whichever this Office build honors wins):
#   1. HKLM policy: PromptOOMSend=1, PromptOOMAddressBookAccess=1  (1 = automatically approve)
#   2. HKLM Outlook security: ObjectModelGuard=2                   (2 = never warn)
# Verification is EMPIRICAL: after this, restart Outlook and run scripts\smoke-outlook-com.ps1.
# If sends start failing instead of prompting (auto-deny), delete these values to revert:
#   Remove-ItemProperty on the same paths/names.
$ErrorActionPreference = 'Continue'

$targets = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Security'; Values = @{ PromptOOMSend = 1; PromptOOMAddressBookAccess = 1 } },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Office\16.0\Outlook\Security';          Values = @{ ObjectModelGuard = 2 } },
    @{ Path = 'HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Security'; Values = @{ PromptOOMSend = 1; PromptOOMAddressBookAccess = 1 } }
)

foreach ($t in $targets) {
    try {
        if (-not (Test-Path $t.Path)) { New-Item -Path $t.Path -Force | Out-Null }
        foreach ($k in $t.Values.Keys) {
            Set-ItemProperty -Path $t.Path -Name $k -Value $t.Values[$k] -Type DWord -ErrorAction Stop
            Write-Host ("OK   " + $t.Path + " -> " + $k + " = " + $t.Values[$k])
        }
    } catch {
        Write-Host ("FAIL " + $t.Path + " : " + $_.Exception.Message)
    }
}

Write-Host ''
Write-Host 'Done. Next: restart Outlook, then run scripts\smoke-outlook-com.ps1 to confirm no prompt.'
Write-Host 'Press Enter to close this window.'
Read-Host | Out-Null
