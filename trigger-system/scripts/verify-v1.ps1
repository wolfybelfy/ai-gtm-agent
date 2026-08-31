param(
    [string]$ExpectedOriginalHead = 'c48311296f5c96e9a0514e5964d864df868cf2ed',
    [string]$ExpectedOriginalFingerprint = '4156d8fa95b7162571a86cfd16e33a3c656335e6d47a551d32b7ff13271cea21'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent $root

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    Write-Host ("PASS: " + $Message)
}

$AllowedVolatilePrefixes = @('data/','logs/','staging/','plays/','briefs/','deliverables/','_doc_work/')

function Test-VolatilePath([string]$RelativePath) {
    $normalized = $RelativePath.Replace('\', '/').Trim('"')
    foreach ($prefix in $AllowedVolatilePrefixes) {
        if ($normalized.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Get-ProtectedFingerprint([string]$Repository) {
    $entries = foreach ($relative in (& git -C $Repository ls-files)) {
        $normalized = $relative.Replace('\', '/')
        if (-not (Test-VolatilePath $normalized)) {
            $absolute = Join-Path $Repository $relative
            $hash = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash.ToLowerInvariant()
            "$normalized|$hash"
        }
    }
    $payload = (($entries | Sort-Object) -join "`n")
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
        return ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

Push-Location $root
try {
    Write-Host '=== Python tests ==='
    & python -m unittest discover -s tests -p 'test_*.py' -v
    Assert-True ($LASTEXITCODE -eq 0) 'all Python tests passed'

    Write-Host '=== Suppression baseline ==='
    $baseline = Join-Path $root 'config\suppression-baseline.csv'
    $domains = @(Import-Csv -LiteralPath $baseline | ForEach-Object { $_.domain.ToLower().Trim() })
    $unique = @($domains | Sort-Object -Unique)
    Assert-True ($domains.Count -eq 648) 'suppression-baseline.csv contains 648 rows'
    Assert-True ($unique.Count -eq 648) 'all 648 suppression domains are unique'

    Write-Host '=== Runtime safety scan ==='
    $scriptNames = @(Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -File | ForEach-Object { $_.Name } | Sort-Object)
    $expectedScripts = @('.gitkeep','ai-gtm.ps1','publish-outlook-drafts.ps1','verify-v1.ps1') | Sort-Object
    Assert-True (($scriptNames -join '|') -eq ($expectedScripts -join '|')) 'active script directory matches the v1 allowlist'
    $activeFiles = @((Join-Path $root 'scripts\ai-gtm.ps1'), (Join-Path $root 'scripts\publish-outlook-drafts.ps1'))
    foreach ($file in $activeFiles) {
        $text = Get-Content -Raw -LiteralPath $file
        Assert-True (-not $text.Contains('.Send(')) ("no .Send( call in " + (Split-Path $file -Leaf))
        foreach ($excluded in @('HubSpot','Teams','OneDrive','Clay','JustCall','Serper')) {
            Assert-True ($text.IndexOf($excluded, [StringComparison]::OrdinalIgnoreCase) -lt 0) ("no excluded provider " + $excluded + " in " + (Split-Path $file -Leaf))
        }
    }

    Write-Host '=== Idempotent fixture run ==='
    $verifyOutput = Join-Path $root ("staging\runtime\verification-{0}" -f $PID)
    $first = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\ai-gtm.ps1') -DryRun -Fixture -OutputPath $verifyOutput -AsOf '2026-08-31' 2>&1 | Out-String)
    Assert-True ($LASTEXITCODE -eq 0) 'first fixture pipeline run exited zero'
    Assert-True ($first -match 'built run') 'first fixture pipeline built a run'
    $second = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\ai-gtm.ps1') -DryRun -Fixture -OutputPath $verifyOutput -AsOf '2026-08-31' 2>&1 | Out-String)
    Assert-True ($LASTEXITCODE -eq 0) 'second fixture pipeline run exited zero'
    Assert-True ($second -match 'reused run') 'second fixture pipeline reused the checkpoint'
    $payload = Get-Content -Raw -LiteralPath (Join-Path $verifyOutput 'drafts.json') | ConvertFrom-Json
    Assert-True (@($payload.drafts).Count -eq 1) 'fixture produced exactly one draft payload without duplication'

    Write-Host '=== Outlook dry-run ==='
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\publish-outlook-drafts.ps1') -InputPath (Join-Path $verifyOutput 'drafts.json') -DryRun
    Assert-True ($LASTEXITCODE -eq 0) 'Outlook adapter dry-run created no Outlook items'

    Write-Host '=== Git isolation ==='
    $remotes = (& git -C $repo remote -v 2>&1 | Out-String)
    Assert-True ($remotes -notmatch 'trigger-based-outbound-system|ICP.Converstion.Intelligence') 'new repository has no remote pointing to the original project'
    $commonDirText = (& git -C $repo rev-parse --path-format=absolute --git-common-dir).Trim()
    $commonDir = (Resolve-Path -LiteralPath $commonDirText).Path
    $newProjectRoot = Split-Path -Parent $commonDir
    $documentsRoot = Split-Path -Parent $newProjectRoot
    $original = Join-Path $documentsRoot 'ICP Converstion Intelligence\trigger-system'
    Assert-True (Test-Path -LiteralPath $original) 'original project guard path exists'
    $originalHead = (& git -C $original rev-parse HEAD).Trim()
    Assert-True ($originalHead -eq $ExpectedOriginalHead) 'original Git HEAD matches the recorded pre-build value'
    $unexpectedStatus = @()
    foreach ($line in (& git -C $original status --porcelain=v1 --untracked-files=all)) {
        if ($line.Length -lt 4) { continue }
        $relative = $line.Substring(3).Trim()
        if (-not (Test-VolatilePath $relative)) { $unexpectedStatus += $line }
    }
    Assert-True ($unexpectedStatus.Count -eq 0) 'original has no changes outside explicit volatile runtime paths'
    $originalFingerprint = Get-ProtectedFingerprint $original
    Assert-True ($originalFingerprint -eq $ExpectedOriginalFingerprint) 'all tracked non-volatile original files match the pre-build fingerprint'

    Write-Host '=== Existing presentation smoke ==='
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tests\presentation-smoke.ps1')
    Assert-True ($LASTEXITCODE -eq 0) 'existing presentation smoke test passed'

    Write-Host 'VERIFIED: AI GTM Agent v1 deterministic shipping checks passed.'
} finally {
    Pop-Location
}
