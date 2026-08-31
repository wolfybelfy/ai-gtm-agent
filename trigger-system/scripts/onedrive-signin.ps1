# onedrive-signin.ps1 - device-code sign-in that seeds MSGRAPH_REFRESH_TOKEN for
# onedrive-share-link.ps1. Re-runnable: run it again whenever the refresh token is lost,
# revoked, or bound to the wrong person.
#
# WHY THIS EXISTS (2026-08-25, after a VERIFIED failure worth remembering): the 2026-08-24
# sign-in COMPLETED SUCCESSFULLY and still produced a broken system. The operator entered the
# device code correctly, but the browser was already signed in as asingh@unboundia.com, so the
# token bound to Amit's OneDrive while every play doc lives in upawar's. Graph then answered
# every lookup with 404 "file not found in cloud drive (synced yet?)" - which reads like a sync
# lag and is not. Hours went into the wrong hypothesis.
# This script makes that class of failure impossible: it asks Graph WHO the token belongs to
# and REFUSES to store a token whose UPN is not -ExpectedUpn. A wrong account now fails loudly
# at sign-in instead of silently at first use.
#
# Auth: public client 14d82eec-204b-4c2f-b7e8-296a70dab67e, scopes
# "Files.ReadWrite offline_access User.Read". User.Read is required for the identity guard -
# without it /me returns 403 and the account cannot be verified (the 08-24 token lacked it).
# The refresh token is stored in the MSGRAPH_REFRESH_TOKEN *user env var*, never in a file
# (CLAUDE.md rule 3), and rotates on every use.
#
# Exit codes: 0 = verified + stored, 1 = error/timeout/declined, 2 = WRONG ACCOUNT (not stored).
param(
    [string]$ExpectedUpn = 'upawar@unboundia.com',
    [int]$TimeoutMin = 15,
    # Default = Microsoft's first-party "Microsoft Graph Command Line Tools". Override (or set
    # the MSGRAPH_CLIENT_ID user env var) to point at a dedicated tenant app registration -
    # preferable long term, because a dedicated app can be scoped to exactly Files.ReadWrite +
    # User.Read and assigned to one person, instead of relying on a shared Microsoft app.
    [string]$ClientId = '',
    # SINGLE-TENANT apps MUST use their own tenant authority. /common and /organizations are
    # multi-tenant endpoints and reject a single-tenant app with AADSTS50194. The dedicated
    # Unbound IA app registration (2026-08-25) is single-tenant, so the default is the tenant id.
    [string]$Tenant = ''
)
$ErrorActionPreference = 'Stop'
if ($ClientId -eq '') { $ClientId = [Environment]::GetEnvironmentVariable('MSGRAPH_CLIENT_ID','User') }
if ([string]::IsNullOrWhiteSpace($ClientId)) { $ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e' }
$clientId = $ClientId
if ($Tenant -eq '') { $Tenant = [Environment]::GetEnvironmentVariable('MSGRAPH_TENANT_ID','User') }
if ([string]::IsNullOrWhiteSpace($Tenant)) { $Tenant = '3f20fc11-607c-459f-a093-7586b2972eb3' }
$scope    = 'Files.ReadWrite offline_access User.Read'
$tokenUri = "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token"

function Read-ErrorBody($errRecord) {
    if ($errRecord.ErrorDetails -and $errRecord.ErrorDetails.Message) { return $errRecord.ErrorDetails.Message }
    if ($errRecord.Exception.Response) {
        try {
            $sr = New-Object System.IO.StreamReader($errRecord.Exception.Response.GetResponseStream())
            return $sr.ReadToEnd()
        } catch { return '' }
    }
    return ''
}

# ---- 1. request the device code ------------------------------------------------------------
try {
    $dc = Invoke-RestMethod -Method Post -Uri ("https://login.microsoftonline.com/" + $Tenant + "/oauth2/v2.0/devicecode") -Body @{ client_id = $clientId; scope = $scope }
} catch {
    Write-Host "FAILED to start device-code flow: $($_.Exception.Message)"
    Write-Host (Read-ErrorBody $_)
    exit 1
}

Write-Host ''
Write-Host '============================================================'
Write-Host '  SIGN IN AS THE PLAY-DOC OWNER'
Write-Host '============================================================'
Write-Host ("  1. Open : " + $dc.verification_uri)
Write-Host ("  2. Code : " + $dc.user_code)
Write-Host ("  3. Sign in as: " + $ExpectedUpn)
Write-Host ''
Write-Host '  IMPORTANT - this is the step that failed on 2026-08-24:'
Write-Host '  If the page shows a DIFFERENT account already signed in, click'
Write-Host '  "Use another account" (or open the link in a private/InPrivate'
Write-Host '  window). Do NOT accept a pre-signed-in account. A wrong account'
Write-Host '  here completes without error and breaks every later call.'
Write-Host ''
Write-Host ("  Waiting up to $TimeoutMin minute(s)...")
Write-Host ''

# ---- 2. poll for completion ----------------------------------------------------------------
$interval = [int]$dc.interval
if ($interval -lt 3) { $interval = 3 }
$deadline = (Get-Date).AddMinutes($TimeoutMin)
$tok = $null
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds $interval
    try {
        $tok = Invoke-RestMethod -Method Post -Uri $tokenUri -Body @{
            grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
            client_id   = $clientId
            device_code = $dc.device_code
        }
        break
    } catch {
        $raw = Read-ErrorBody $_
        $code = ''
        try { $code = (ConvertFrom-Json $raw).error } catch { }
        if ($code -eq 'authorization_pending') { continue }
        if ($code -eq 'slow_down') { $interval += 5; continue }
        if ($code -eq 'expired_token') { Write-Host 'The device code expired. Re-run this script.'; exit 1 }
        if ($code -eq 'authorization_declined') { Write-Host 'Sign-in was declined in the browser.'; exit 1 }
        Write-Host "Token poll failed: $code"; Write-Host $raw; exit 1
    }
}
if ($null -eq $tok) { Write-Host "Timed out after $TimeoutMin minute(s) - nobody completed the sign-in. Nothing stored."; exit 1 }

# ---- 3. IDENTITY GUARD - the whole point of this script -------------------------------------
$h = @{ Authorization = "Bearer $($tok.access_token)" }
try {
    $me = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/me' -Headers $h
} catch {
    Write-Host "Signed in, but /me failed - cannot verify WHICH account this is, so the token is NOT stored."
    Write-Host "  $($_.Exception.Message)"
    Write-Host "  (If this is a 403, the User.Read scope was not granted.)"
    exit 1
}
$actual = ('' + $me.userPrincipalName).Trim()
Write-Host ("Signed in as : " + $me.displayName + " <" + $actual + ">")

if ($actual.ToLower() -ne $ExpectedUpn.ToLower()) {
    Write-Host ''
    Write-Host '*** WRONG ACCOUNT - TOKEN NOT STORED ***'
    Write-Host ("    expected : " + $ExpectedUpn)
    Write-Host ("    got      : " + $actual)
    Write-Host '    This is exactly the 2026-08-24 failure. Re-run this script and use'
    Write-Host '    "Use another account" / a private window to pick the right identity.'
    Write-Host '    The previously stored token (if any) was left untouched.'
    exit 2
}

# also confirm the drive we will actually write links against
try {
    $d = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/me/drive' -Headers $h
    Write-Host ("Drive        : " + $d.driveType + " - " + $d.webUrl)
} catch {
    Write-Host "WARN: /me/drive lookup failed: $($_.Exception.Message)"
}

if (-not $tok.refresh_token) { Write-Host 'No refresh_token returned (offline_access not granted?) - nothing stored.'; exit 1 }
[Environment]::SetEnvironmentVariable('MSGRAPH_REFRESH_TOKEN', $tok.refresh_token, 'User')
Write-Host ''
Write-Host 'VERIFIED + STORED: MSGRAPH_REFRESH_TOKEN (user env var) now belongs to the expected account.'
Write-Host 'Next: scripts\onedrive-share-link.ps1 -WhoAmI    (should echo the same identity)'
exit 0
