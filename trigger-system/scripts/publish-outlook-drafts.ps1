# Draft-only Outlook COM adapter. Dry-run is the default; -Execute is explicit.
param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [switch]$DryRun,
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'
if ($DryRun -and $Execute) { throw 'Choose either -DryRun or -Execute.' }
$resolved = (Resolve-Path -LiteralPath $InputPath).Path
$payload = Get-Content -Raw -LiteralPath $resolved | ConvertFrom-Json
if ($payload.action -ne 'save_draft') { throw 'Payload action must be save_draft.' }

$drafts = @($payload.drafts)
if (-not $Execute) {
    Write-Host ("DRY RUN: validated {0} Outlook draft payload(s); no Outlook items created." -f $drafts.Count)
    foreach ($draft in $drafts) {
        if ($draft.action -ne 'save_draft') { throw 'Every item action must be save_draft.' }
        Write-Host ("  would save draft: {0} -> {1}" -f $draft.subject, $draft.to)
    }
    exit 0
}

$root = Split-Path -Parent $PSScriptRoot
$receiptDir = Join-Path $root 'staging\runtime\outlook-receipts'
if (-not (Test-Path -LiteralPath $receiptDir)) {
    New-Item -ItemType Directory -Force -Path $receiptDir | Out-Null
}
$outlook = New-Object -ComObject Outlook.Application
try {
    foreach ($draft in $drafts) {
        if ($draft.action -ne 'save_draft') { throw 'Every item action must be save_draft.' }
        if ([string]::IsNullOrWhiteSpace($draft.idempotency_key)) { throw 'Draft is missing idempotency_key.' }
        $receipt = Join-Path $receiptDir ($draft.idempotency_key + '.json')
        if (Test-Path -LiteralPath $receipt) {
            Write-Host ("SKIP existing draft receipt: {0}" -f $draft.idempotency_key)
            continue
        }
        $mail = $outlook.CreateItem(0)
        try {
            $mail.To = [string]$draft.to
            $mail.Subject = [string]$draft.subject
            $mail.Body = [string]$draft.body
            $mail.Save()
            @{
                idempotency_key = [string]$draft.idempotency_key
                saved_utc = [DateTime]::UtcNow.ToString('o')
                subject = [string]$draft.subject
            } | ConvertTo-Json | Set-Content -LiteralPath $receipt -Encoding UTF8
            Write-Host ("SAVED Outlook draft: {0}" -f $draft.subject)
        } finally {
            if ($null -ne $mail) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($mail) }
        }
    }
} finally {
    if ($null -ne $outlook) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($outlook) }
}

