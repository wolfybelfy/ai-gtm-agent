# hubspot-setup.ps1 - creates the "clean corner" schema pieces that CAN be scripted
# (reference\hubspot-playbook.md): property group `trigger_system` on companies + the three
# ts_ summary properties. Saved view + task queue are UI-only (documented click-path).
# SAFETY (CLAUDE.md rule 4): DRY RUN by default. A real write needs BOTH -Execute AND
# -AuditConfirmed (pass it only after BUILD-STATE records the RevOps audit as done), and is
# blocked by the kill-switch file staging\hubspot\WRITES-PAUSED. Idempotent: existing group/
# properties are left untouched. Token: $env:HUBSPOT_PRIVATE_APP_TOKEN (never logged).
# Exit codes: 0 ok/dry, 2 no token, 3 kill switch or audit gate, 4 API failure.
param(
    [switch]$Execute,
    [switch]$AuditConfirmed
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Get-TriggerSystemRoot

$killSwitch = Join-Path $root 'staging\hubspot\WRITES-PAUSED'
if (Test-Path $killSwitch) { Write-Host 'BLOCKED: staging\hubspot\WRITES-PAUSED exists - all CRM writes stopped (research continues).'; exit 3 }

$token = $env:HUBSPOT_PRIVATE_APP_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host 'No HUBSPOT_PRIVATE_APP_TOKEN in environment.'
    Write-Host 'Setup: a super admin creates the private app (scopes in reference\hubspot-playbook.md),'
    Write-Host 'then the user runs:  setx HUBSPOT_PRIVATE_APP_TOKEN "pat-..."  and opens a NEW shell.'
    exit 2
}

$groupName = 'trigger_system'
$props = @(
    @{ name = 'ts_last_tier';         label = 'TS Last Tier';          type = 'string'; fieldType = 'text';
       description = 'trigger-system: tier of the most recent play on this company (STRIKE/SEQUENCE/WATCH). Full history lives in immutable play notes (play_id).' },
    @{ name = 'ts_last_window_close'; label = 'TS Last Window Close';  type = 'date';   fieldType = 'date';
       description = 'trigger-system: window-close date of the most recent play.' },
    @{ name = 'ts_suppression_until'; label = 'TS Suppression Until';  type = 'date';   fieldType = 'date';
       description = 'trigger-system: do not target this company before this date.' }
)

if (-not $Execute) {
    Write-Host 'DRY RUN (pass -Execute -AuditConfirmed to write). Would ensure:'
    Write-Host "  property group companies/$groupName (label 'Trigger System')"
    foreach ($p in $props) { Write-Host "  property companies/$($p.name) ($($p.type)) in $groupName" }
    exit 0
}
if (-not $AuditConfirmed) {
    Write-Host 'REFUSED: -Execute without -AuditConfirmed. The RevOps workflow audit must be recorded'
    Write-Host 'in BUILD-STATE before the first CRM write (plan v1.1 entry criterion). Then re-run with both switches.'
    exit 3
}

# group (GET then create if missing)
$g = Invoke-HubSpotApi -Method GET -Path "/crm/v3/properties/companies/groups/$groupName" -Token $token
if ($g.ok) {
    Write-Host "group $groupName already exists - left untouched."
} else {
    if ($g.status -ne 404) { Write-Host "API error reading group ($($g.status)): $($g.err)"; exit 4 }
    $c = Invoke-HubSpotApi -Method POST -Path '/crm/v3/properties/companies/groups' -Token $token -Body @{ name = $groupName; label = 'Trigger System'; displayOrder = -1 }
    if (-not $c.ok) { Write-Host "API error creating group ($($c.status)): $($c.err)"; exit 4 }
    Write-Host "created property group $groupName."
}

foreach ($p in $props) {
    $r = Invoke-HubSpotApi -Method GET -Path "/crm/v3/properties/companies/$($p.name)" -Token $token
    if ($r.ok) { Write-Host "property $($p.name) already exists - left untouched."; continue }
    if ($r.status -ne 404) { Write-Host "API error reading $($p.name) ($($r.status)): $($r.err)"; exit 4 }
    $body = @{ name = $p.name; label = $p.label; type = $p.type; fieldType = $p.fieldType; groupName = $groupName; description = $p.description }
    $c = Invoke-HubSpotApi -Method POST -Path '/crm/v3/properties/companies' -Token $token -Body $body
    if (-not $c.ok) { Write-Host "API error creating $($p.name) ($($c.status)): $($c.err)"; exit 4 }
    Write-Host "created property $($p.name)."
}

Write-Host 'Done. Remaining ONE-TIME UI steps (cannot be scripted - hubspot-playbook.md):'
Write-Host '  1. Tasks home -> create queue "Trigger Strikes" (share with SDR + backup); note its queue id.'
Write-Host '  2. Companies index -> filter ts_last_tier is known -> save view "Trigger System - active plays".'
exit 0
