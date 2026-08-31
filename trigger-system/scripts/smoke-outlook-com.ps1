# smoke-outlook-com.ps1 - Phase 0 smoke test (plan Part A-3 / Part C Phase 0)
# Sends ONE email from the signed-in classic-Outlook profile TO ITSELF, nothing else.
# Structurally self-only: the recipient is read from the profile's own account list;
# there is no parameter and no code path to address anyone else (safety rail E-1).
$ErrorActionPreference = 'Stop'
try {
    $ol = New-Object -ComObject Outlook.Application
    Write-Output "COM-CREATE: OK (Outlook.Application)"
} catch {
    Write-Output "COM-CREATE: FAIL - $($_.Exception.Message)"
    exit 1
}
try {
    $ns = $ol.GetNamespace("MAPI")
    $addrs = @()
    foreach ($a in $ns.Accounts) { $addrs += $a.SmtpAddress }
    Write-Output ("ACCOUNTS: " + ($addrs -join '; '))
    if ($addrs.Count -eq 0) { Write-Output "RESULT: FAIL - no mail accounts in profile"; exit 1 }
    $self = $addrs[0]
    $mail = $ol.CreateItem(0)
    $mail.To = $self
    $mail.Subject = "[SYSTEM] trigger-system Phase 0 smoke test $(Get-Date -Format s)"
    $mail.Body = "Automated Phase 0 smoke test: Outlook COM send-to-self from the trigger-system alert path. If this arrived, the alert mechanism works. No action needed."
    $mail.Send()
    Write-Output "SENT-TO: $self"
    Write-Output "RESULT: OK (queued in Outlook outbox; delivery confirms end-to-end)"
} catch {
    Write-Output "RESULT: FAIL - $($_.Exception.Message)"
    exit 1
}
