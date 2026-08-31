# alert-teams.ps1 - posts pending alert files from staging\alerts\ into a Microsoft Teams
# channel via a Teams "Workflows" incoming webhook (Power Automate: "When a Teams webhook
# request is received" -> "Post card in a chat or channel").
#
# DESIGN (mirrors alert-mailer.ps1; CLAUDE.md hard rule 1 analog):
#   - Reads ONLY staging\alerts\*.md (the 4-line header format in staging\SCHEMAS.md).
#   - The channel is the recipient: the webhook URL is channel-bound and lives ONLY in the
#     user env var TEAMS_ALERT_WEBHOOK_URL (rule 3: secrets never in files). No prospect
#     addresses exist anywhere in this path.
#   - Does NOT touch STATUS (the Outlook mailer remains the mail-of-record). Idempotency:
#     a file that already contains a TEAMS-POSTED: line is skipped forever.
#   - DRY RUN by default; -Execute posts. ASCII-only file (PS 5.1 policy).
# Exit codes: 0 ok/dry, 1 >=1 post failed, 2 no webhook URL on -Execute.
param(
    [switch]$Execute
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Get-TriggerSystemRoot
$alertDir = Join-Path $root 'staging\alerts'

$hook = $env:TEAMS_ALERT_WEBHOOK_URL
if ([string]::IsNullOrWhiteSpace($hook)) {
    # fall back to the User-scope env var from the registry, so a fresh setx works without
    # restarting the parent process (same reason scheduled tasks always see it)
    $hook = [Environment]::GetEnvironmentVariable('TEAMS_ALERT_WEBHOOK_URL', 'User')
}
if ($Execute -and [string]::IsNullOrWhiteSpace($hook)) {
    Write-Host 'No TEAMS_ALERT_WEBHOOK_URL env var - cannot post. Create the webhook in Teams (channel > Workflows > "Post to a channel when a webhook request is received"), then set the env var.'
    exit 2
}

$files = @(Get-ChildItem -Path $alertDir -Filter '*.md' -File -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) { Write-Host 'no alert files - nothing to post.'; exit 0 }

$failures = 0; $posted = 0; $planned = 0
foreach ($f in $files) {
    $raw = [IO.File]::ReadAllText($f.FullName)
    if ($raw -match 'TEAMS-POSTED:') { continue }
    $lines = [IO.File]::ReadAllLines($f.FullName)
    # Header block = leading KEY: lines until the first blank line (same shape the mailer
    # parses). LINK / LINK-TEXT (added 2026-08-20, user-confirmed trigger-brief card format)
    # render as an Action.OpenUrl button. The old metadata line (type/list/file) is GONE by
    # the same decision - the card carries only human content.
    $subject = ''; $type = ''; $link = ''; $linkText = 'Open the play in HubSpot'; $teamsFlag = ''
    $bodyStart = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i].Trim()
        if ($ln -eq '') { $bodyStart = $i + 1; break }
        if ($ln -match '^(TYPE|SUBJECT|TO|STATUS|FORMAT|ATTACH|LINK|LINK-TEXT|TEAMS):\s*(.*)$') {
            switch ($Matches[1]) {
                'SUBJECT'   { $subject = $Matches[2].Trim() }
                'TYPE'      { $type = $Matches[2].Trim() }
                'LINK'      { $link = $Matches[2].Trim() }
                'LINK-TEXT' { $linkText = $Matches[2].Trim() }
                'TEAMS'     { $teamsFlag = $Matches[2].Trim().ToLower() }
            }
        } else { $bodyStart = $i; break }
    }
    # USER RULE 2026-08-21: the channel carries ONLY play-ready cards (play generated +
    # assigned to an owner). Fails, digests and system updates stay on the email lane.
    # Only files explicitly marked TEAMS: yes are posted; everything else is skipped.
    if ($teamsFlag -ne 'yes') { continue }
    if ($subject -eq '') { $subject = $f.Name }
    $bodyText = (($lines | Select-Object -Skip $bodyStart) | Where-Object { $_ -notmatch '^TEAMS-POSTED:' }) -join "`n"
    $bodyText = $bodyText.Trim()
    if ($bodyText.Length -gt 3000) { $bodyText = $bodyText.Substring(0, 3000) + "`n[truncated - full alert: staging\alerts\$($f.Name)]" }

    if (-not $Execute) {
        $planned++
        Write-Host "PLAN would post: $subject (file: $($f.Name); link: $(if ($link -ne '') { 'yes' } else { 'no' }))"
        continue
    }

    $content = @{
        '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
        type = 'AdaptiveCard'
        version = '1.4'
        msteams = @{ width = 'Full' }
        body = @(
            @{ type = 'TextBlock'; size = 'Medium'; weight = 'Bolder'; text = $subject; wrap = $true },
            @{ type = 'TextBlock'; text = $bodyText; wrap = $true }
        )
    }
    if ($link -ne '') {
        $content.actions = @(@{ type = 'Action.OpenUrl'; title = $linkText; url = $link })
    }
    $card = @{
        type = 'message'
        attachments = @(@{
            contentType = 'application/vnd.microsoft.card.adaptive'
            content = $content
        })
    }
    $json = $card | ConvertTo-Json -Depth 12
    # PS 5.1 sends STRING bodies as Latin-1 -> non-ASCII in a card (em-dash in a subject) goes
    # out as invalid UTF-8. BYTE bodies are sent verbatim (same class as the 2026-08-26 HubSpot
    # 400; fixed at lib.ps1's Invoke-HubSpotApi the same day).
    $bodyBytes = [Text.Encoding]::UTF8.GetBytes($json)
    try {
        Invoke-RestMethod -Method Post -Uri $hook -ContentType 'application/json; charset=utf-8' -Body $bodyBytes | Out-Null
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Add-Content -Path $f.FullName -Value ("TEAMS-POSTED: " + $stamp + " BY: alert-teams.ps1") -Encoding ASCII
        $posted++
        Write-Host "POSTED [$type] $subject"
    } catch {
        $failures++
        Write-Host "FAIL posting $($f.Name): $($_.Exception.Message)"
    }
}

if (-not $Execute) { Write-Host "DRY RUN done: $planned alert(s) would be posted."; exit 0 }
Write-Host "teams post done: $posted posted, $failures failed."
if ($failures -gt 0) { exit 1 } else { exit 0 }
