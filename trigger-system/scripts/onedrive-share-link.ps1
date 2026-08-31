# onedrive-share-link.ps1 - create an ORGANIZATION-ONLY view link for a file in the
# play-doc owner's OneDrive (Unbound IA Corp tenant), via Microsoft Graph.
#
# Added 2026-08-24 (user order: play docs live in OneDrive; the HubSpot note carries a
# 3-line brief + the doc link). This script exists so play-doc sharing is automated and
# auditable: org-scope links ONLY (never "anyone"), view ONLY (never edit), and the
# secret never appears on a command line.
#
# HARDENED 2026-08-25 after the original never worked. Root cause was NOT sync lag: the
# 08-24 device-code sign-in bound to asingh@unboundia.com (the browser's already-signed-in
# account) while every play doc lives in upawar's OneDrive, so Graph correctly answered 404
# for a file that was correctly on disk. The old 404 text ("synced yet?") named only the
# wrong cause and sent the next session hunting a sync bug for hours.
# Two fixes, both here: (1) an IDENTITY GUARD refuses to act on a token belonging to anyone
# but -ExpectedUpn; (2) -WhoAmI / -ListRoot answer "who am I and what can I actually see?"
# in one call, and the 404 message now names BOTH possible causes.
#
# Auth: MSGRAPH_REFRESH_TOKEN user env var (rule 3) - seeded by scripts\onedrive-signin.ps1.
# Each run mints a fresh access token and re-stores the rotated refresh token.
#
# Usage:
#   .\onedrive-share-link.ps1 -WhoAmI
#   .\onedrive-share-link.ps1 -ListRoot
#   .\onedrive-share-link.ps1 -DrivePath "Trigger Plays/Veeam Play - Kumar.docx"
#
# Exit codes: 0 = ok, 1 = error, 2 = WRONG ACCOUNT, 3 = credentials absent,
#             4 = token too old to verify identity (re-run onedrive-signin.ps1).
param(
    [string]$DrivePath = '',
    [switch]$WhoAmI,
    [switch]$ListRoot,
    [string]$ExpectedUpn = 'upawar@unboundia.com',
    [string]$ClientId = '',
    [string]$Tenant = ''
)
$ErrorActionPreference = 'Stop'
if ($ClientId -eq '') { $ClientId = [Environment]::GetEnvironmentVariable('MSGRAPH_CLIENT_ID','User') }
if ([string]::IsNullOrWhiteSpace($ClientId)) { $ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e' }
# single-tenant app -> tenant authority, never /organizations (AADSTS50194)
if ($Tenant -eq '') { $Tenant = [Environment]::GetEnvironmentVariable('MSGRAPH_TENANT_ID','User') }
if ([string]::IsNullOrWhiteSpace($Tenant)) { $Tenant = '3f20fc11-607c-459f-a093-7586b2972eb3' }

$rt = [Environment]::GetEnvironmentVariable('MSGRAPH_REFRESH_TOKEN', 'User')
if ([string]::IsNullOrWhiteSpace($rt)) {
    Write-Host 'MSGRAPH_REFRESH_TOKEN not set - run: scripts\onedrive-signin.ps1'
    exit 3
}

# ---- mint an access token; persist the rotated refresh token --------------------------------
try {
    $tok = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token" -Body @{
        grant_type    = 'refresh_token'
        client_id     = $ClientId
        refresh_token = $rt
        scope         = 'Files.ReadWrite offline_access User.Read'
    }
} catch {
    # Surface the ACTUAL AAD error body. A bare "400 Bad Request" here is undiagnosable and
    # cost real hours on 2026-08-24/25; the AADSTS code names the cause every time.
    $body = ''
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $body = $_.ErrorDetails.Message }
    elseif ($_.Exception.Response) {
        try { $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream()); $body = $sr.ReadToEnd() } catch { }
    }
    Write-Host "token refresh failed: $($_.Exception.Message)"
    if ($body -ne '') { Write-Host ("  AAD said: " + $body) }
    if ($body -match 'AADSTS65001' -or $body -match 'consent_required') {
        Write-Host '  CAUSE: this token never consented to the User.Read scope the identity guard needs.'
        Write-Host '         (Tokens seeded before 2026-08-25 are all in this state.)'
    }
    Write-Host '  FIX: re-run scripts\onedrive-signin.ps1'
    exit 1
}
if ($tok.refresh_token) { [Environment]::SetEnvironmentVariable('MSGRAPH_REFRESH_TOKEN', $tok.refresh_token, 'User') }
$h = @{ Authorization = "Bearer $($tok.access_token)" }

# ---- IDENTITY GUARD (the 2026-08-25 fix) ----------------------------------------------------
try {
    $me = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/me' -Headers $h
} catch {
    Write-Host 'cannot verify which account this token belongs to (/me failed).'
    Write-Host "  $($_.Exception.Message)"
    Write-Host '  A 403 here means the token predates the identity guard (no User.Read scope).'
    Write-Host '  Re-run: scripts\onedrive-signin.ps1'
    exit 4
}
$actual = ('' + $me.userPrincipalName).Trim()
if ($actual.ToLower() -ne $ExpectedUpn.ToLower()) {
    Write-Host '*** WRONG ACCOUNT - refusing to act ***'
    Write-Host ("    expected : " + $ExpectedUpn)
    Write-Host ("    token is : " + $actual + "  (" + $me.displayName + ")")
    Write-Host '    Re-run scripts\onedrive-signin.ps1 and use "Use another account".'
    exit 2
}

try { $drive = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/me/drive' -Headers $h }
catch { Write-Host "drive lookup failed: $($_.Exception.Message)"; exit 1 }

if ($WhoAmI) {
    Write-Host ("identity : " + $me.displayName + " <" + $actual + ">")
    Write-Host ("drive    : " + $drive.driveType + " (owner " + $drive.owner.user.displayName + ")")
    Write-Host ("webUrl   : " + $drive.webUrl)
    Write-Host 'identity guard: PASS'
    exit 0
}

if ($ListRoot) {
    Write-Host ("root of " + $drive.webUrl + " :")
    try { $kids = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/me/drive/root/children?$top=200' -Headers $h }
    catch { Write-Host "root listing failed: $($_.Exception.Message)"; exit 1 }
    foreach ($k in $kids.value) {
        $kind = 'FILE'
        if ($k.folder) { $kind = 'DIR ' }
        Write-Host ("  [" + $kind + "] " + $k.name)
    }
    exit 0
}

if ([string]::IsNullOrWhiteSpace($DrivePath)) {
    Write-Host 'nothing to do: pass -DrivePath "<folder>/<file>", or -WhoAmI / -ListRoot.'
    exit 1
}

# ---- resolve the item -----------------------------------------------------------------------
$encPath = ($DrivePath -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
try {
    $item = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/drive/root:/$encPath" -Headers $h
} catch {
    Write-Host ("file not found in the CLOUD copy of this drive: " + $DrivePath)
    Write-Host ("  drive: " + $drive.webUrl)
    Write-Host '  Two causes are possible - check both, in this order:'
    Write-Host '   1. WRONG FOLDER/NAME - run -ListRoot to see what the cloud actually holds.'
    Write-Host '   2. NOT SYNCED YET - the file exists locally but OneDrive has not uploaded it.'
    Write-Host '      Look for the green check in Explorer, or right-click the OneDrive tray'
    Write-Host '      icon and confirm sync is not paused, then retry.'
    Write-Host ("  (raw: " + $_.Exception.Message + ")")
    exit 1
}
Write-Host ("cloud item: " + $item.name + "  size=" + $item.size + "  modified=" + $item.lastModifiedDateTime)

# ---- org-scope, view-only link --------------------------------------------------------------
try {
    $link = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/me/drive/items/$($item.id)/createLink" `
        -Headers $h -ContentType 'application/json' -Body '{"type":"view","scope":"organization"}'
} catch {
    Write-Host "createLink failed: $($_.Exception.Message)"
    Write-Host '  If the tenant blocks organization-scope links, an admin must allow them.'
    exit 1
}
Write-Host ("scope: " + $link.link.scope + "  type: " + $link.link.type)
Write-Host ("SHARE_LINK: " + $link.link.webUrl)
exit 0
