# Draft-only Outlook COM adapter. Dry-run is the default; -Execute is explicit.
param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [string]$OperatorEmail,
    [switch]$DryRun,
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'
if ($DryRun -and $Execute) { throw 'Choose either -DryRun or -Execute.' }
$resolved = (Resolve-Path -LiteralPath $InputPath).Path
$payload = Get-Content -Raw -LiteralPath $resolved | ConvertFrom-Json
if ($payload.action -ne 'save_draft') { throw 'Payload action must be save_draft.' }

$drafts = @($payload.drafts)
if ($null -ne $payload.internal_digest) {
    $digestRecipient = $OperatorEmail
    if ([string]::IsNullOrWhiteSpace($digestRecipient)) {
        $digestRecipient = [Environment]::GetEnvironmentVariable('AI_GTM_OPERATOR_EMAIL')
    }
    if ($Execute -and [string]::IsNullOrWhiteSpace($digestRecipient)) {
        throw 'AI_GTM_OPERATOR_EMAIL or -OperatorEmail is required to save the internal digest draft.'
    }
    if ([string]::IsNullOrWhiteSpace($digestRecipient)) {
        $digestRecipient = '<AI_GTM_OPERATOR_EMAIL>'
    }
    $drafts += [PSCustomObject]@{
        action = [string]$payload.internal_digest.action
        to = $digestRecipient
        subject = [string]$payload.internal_digest.subject
        body = [string]$payload.internal_digest.body
        idempotency_key = [string]$payload.internal_digest.idempotency_key
    }
}
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
$propertyName = 'AI_GTM_IDEMPOTENCY_KEY'

function Write-ReceiptAtomically {
    param([string]$Path, [object]$Draft, [bool]$Recovered)
    $temporary = $Path + '.tmp-' + $PID
    @{
        idempotency_key = [string]$Draft.idempotency_key
        saved_utc = [DateTime]::UtcNow.ToString('o')
        subject = [string]$Draft.subject
        recovered_from_outlook = $Recovered
    } | ConvertTo-Json | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

try {
    $mapi = $outlook.GetNamespace('MAPI')
    $draftFolder = $mapi.GetDefaultFolder(16)
    foreach ($draft in $drafts) {
        if ($draft.action -ne 'save_draft') { throw 'Every item action must be save_draft.' }
        if ([string]::IsNullOrWhiteSpace($draft.idempotency_key)) { throw 'Draft is missing idempotency_key.' }
        $receipt = Join-Path $receiptDir ($draft.idempotency_key + '.json')
        if (Test-Path -LiteralPath $receipt) {
            Write-Host ("SKIP existing draft receipt: {0}" -f $draft.idempotency_key)
            continue
        }
        $alreadySaved = $false
        foreach ($existing in @($draftFolder.Items)) {
            try {
                $property = $existing.UserProperties.Find($propertyName, $true)
                if ($null -ne $property -and [string]$property.Value -eq [string]$draft.idempotency_key) {
                    $alreadySaved = $true
                    break
                }
            } finally {
                if ($null -ne $existing) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($existing) }
            }
        }
        if ($alreadySaved) {
            Write-ReceiptAtomically -Path $receipt -Draft $draft -Recovered $true
            Write-Host ("SKIP existing Outlook draft: {0}" -f $draft.idempotency_key)
            continue
        }
        $mail = $outlook.CreateItem(0)
        try {
            $mail.To = [string]$draft.to
            $mail.Subject = [string]$draft.subject
            $mail.Body = [string]$draft.body
            $property = $mail.UserProperties.Add($propertyName, 1, $true)
            $property.Value = [string]$draft.idempotency_key
            $mail.Save()
            Write-ReceiptAtomically -Path $receipt -Draft $draft -Recovered $false
            Write-Host ("SAVED Outlook draft: {0}" -f $draft.subject)
        } finally {
            if ($null -ne $mail) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($mail) }
        }
    }
} finally {
    if ($null -ne $draftFolder) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($draftFolder) }
    if ($null -ne $mapi) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($mapi) }
    if ($null -ne $outlook) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($outlook) }
}
