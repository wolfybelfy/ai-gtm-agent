# Safe operator entry point. It prepares local payloads and never invokes a paid or mail provider.
param(
    [switch]$DryRun,
    [switch]$Fixture,
    [string]$InputPath = '',
    [string]$OutputPath = '',
    [string]$AsOf = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ($Fixture) {
    $InputPath = Join-Path $root 'fixtures\monday'
} elseif ([string]::IsNullOrWhiteSpace($InputPath)) {
    $InputPath = Join-Path $root 'staging\runtime\inbox'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $root ("staging\runtime\runs\{0}" -f $AsOf)
}
if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input handoff is missing: $InputPath"
}

Push-Location $root
try {
    & python -m agent.cli dry-run --input $InputPath --output $OutputPath --as-of $AsOf
    if ($LASTEXITCODE -ne 0) { throw "AI GTM pipeline failed with exit $LASTEXITCODE" }
    Write-Host "Payloads are local only. Review digest.md before running any provider adapter."
} finally {
    Pop-Location
}
