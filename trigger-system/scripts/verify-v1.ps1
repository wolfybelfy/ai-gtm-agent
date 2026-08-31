param(
    [string]$ExpectedOriginalHead = 'c48311296f5c96e9a0514e5964d864df868cf2ed'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent $root

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    Write-Host ("PASS: " + $Message)
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
    $activeFiles = @(
        (Join-Path $root 'scripts\ai-gtm.ps1'),
        (Join-Path $root 'scripts\publish-outlook-drafts.ps1'),
        (Join-Path $root 'scripts\zoominfo-enrich.ps1')
    )
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
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\publish-outlook-drafts.ps1') -InputPath (Join-Path $root 'fixtures\monday\drafts.json') -DryRun
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
    $protectedStatus = (& git -C $original status --porcelain=v1 -- CLAUDE.md config context reference runbooks scripts 2>&1 | Out-String).Trim()
    Assert-True ([string]::IsNullOrWhiteSpace($protectedStatus)) 'original protected source paths have no working-tree changes'

    Write-Host '=== Existing presentation smoke ==='
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tests\presentation-smoke.ps1')
    Assert-True ($LASTEXITCODE -eq 0) 'existing presentation smoke test passed'

    Write-Host 'VERIFIED: AI GTM Agent v1 deterministic shipping checks passed.'
} finally {
    Pop-Location
}
