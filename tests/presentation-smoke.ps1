$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$html = Get-Content -Raw -LiteralPath (Join-Path $root 'index.html')
$script = Get-Content -Raw -LiteralPath (Join-Path $root 'script.js')
$css = Get-Content -Raw -LiteralPath (Join-Path $root 'styles.css')

$required = @(
  'A comment is a signal, not a converted lead.',
  'Clay prepares the record. The SDR works the account.',
  'CRM ownership','work email and phone','SDR-ready brief','call opener',
  'LinkedIn touch','account director','nurture','Northstar Cloud',
  'Illustrative account','Observed evidence','Verified capability','Pilot choice',
  'Research basis','site:linkedin.com/posts','40+ reactions','100+ reactions',
  'AWS OpenSearch','Todyl','converstion example.png','converstion example 3.png',
  'conversion example 2.png','Amy Spencer','dozens of touchpoints','human review',
  'Salesloft','Outreach','positive reply','meeting held','qualified opportunity'
)
$missing = $required | Where-Object { $html -notmatch [regex]::Escape($_) }
if ($missing) { Write-Host 'FAIL: required presentation markers missing'; exit 1 }

$forbidden = @(
  'Databricks','What would make this strategy commercially useful',
  'How a disclosed business problem could lead to','assumption-table',
  'conflict-table','machine-flow','THE ASK','Unbound IA Commercial Signal Graph',
  'Five strategic decisions','6 to 7 points','Hard stop overrides the score'
)
$found = $forbidden | Where-Object { $html -match [regex]::Escape($_) }
if ($found) { Write-Host 'FAIL: removed framing remains'; exit 1 }

$ordered = @('premise','operating-model','discovery','evidence','validation','clay',
  'sdr-brief','cadence','response','example','proof','pilot','discussion','research')
$previous = -1
foreach ($id in $ordered) {
  $marker = 'id=' + [char]34 + $id + [char]34
  $position = $html.IndexOf($marker)
  if ($position -le $previous) { Write-Host 'FAIL: section missing or out of order'; exit 1 }
  $previous = $position
}

$scriptRequired = @('reading-progress','window.scrollY',
  'document.documentElement.scrollHeight','textarea.select()',
  'document.execCommand','window.prompt')
$scriptMissing = $scriptRequired | Where-Object { $script -notmatch [regex]::Escape($_) }
if ($scriptMissing) { Write-Host 'FAIL: required script behavior missing'; exit 1 }

$cssRequired = @('.reading-column','max-width:980px','.signal-spine','.spine-step',
  '.state-observed','.state-verified','.state-review','.state-illustrative',
  'object-fit:contain','@media (max-width:760px)',
  '@media (prefers-reduced-motion:reduce)','overflow-x:hidden')
$cssMissing = $cssRequired | Where-Object { $css -notmatch [regex]::Escape($_) }
if ($cssMissing) { Write-Host 'FAIL: required linear styles missing'; exit 1 }

Write-Host 'PASS: linear account-activation presentation smoke checks passed'
