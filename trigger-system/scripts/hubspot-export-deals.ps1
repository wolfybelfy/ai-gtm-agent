# hubspot-export-deals.ps1 - pulls closed-won / closed-lost deals into the canonical staging
# files (staging\SCHEMAS.md): staging\hubspot\closed-won.csv + closed-lost.csv. READ-ONLY
# against HubSpot (needs crm.objects.deals.read + companies.read); the kill switch does not
# apply (it guards writes). The importer maps HubSpot fields to THE canonical columns here at
# the staging boundary - the schema never chases the export format.
# Won  = hs_is_closed_won EQ true. Lost = hs_is_closed EQ true AND hs_is_closed_won EQ false.
# NOTE: portal-specific stage semantics get confirmed at the RevOps conversation; first live
# run should be eyeballed against the HubSpot UI counts.
# DRY RUN by default (page-1 counts only); -Execute writes the CSVs (atomic).
# Exit codes: 0 ok/dry, 2 no token, 4 API failure.
param(
    [switch]$Execute,
    [int]$MaxPages = 20
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Get-TriggerSystemRoot
$outDir = Join-Path $root 'staging\hubspot'

$token = $env:HUBSPOT_PRIVATE_APP_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) { Write-Host 'No HUBSPOT_PRIVATE_APP_TOKEN in environment.'; exit 2 }

function Search-Deals {
    param([array]$Filters, [string]$Label)
    $all = New-Object System.Collections.ArrayList
    $after = $null; $page = 0
    do {
        $page++
        $body = @{
            filterGroups = @(@{ filters = $Filters })
            properties = @('dealname','amount','closedate','dealstage','hs_is_closed_won')
            limit = 100
        }
        if ($null -ne $after) { $body.after = $after }
        $r = Invoke-HubSpotApi -Method POST -Path '/crm/v3/objects/deals/search' -Token $token -Body $body
        if (-not $r.ok) { Write-Host "API error searching $Label deals ($($r.status)): $($r.err)"; return $null }
        foreach ($d in @(Get-JsonProp $r.data 'results')) { [void]$all.Add($d) }
        $after = $null
        $paging = Get-JsonProp $r.data 'paging'
        if ($null -ne $paging) { $next = Get-JsonProp $paging 'next'; if ($null -ne $next) { $after = Get-JsonProp $next 'after' } }
        if (-not $Execute) { break }   # dry run: first page only
    } while ($null -ne $after -and $page -lt $MaxPages)
    return @($all)
}

function Get-CompanyForDeals {
    # returns hashtable dealId -> @{name;domain} via association read + batch company read
    param([array]$Deals)
    $map = @{}
    $companyIds = @{}
    foreach ($d in $Deals) {
        $id = '' + (Get-JsonProp $d 'id')
        $a = Invoke-HubSpotApi -Method GET -Path "/crm/v3/objects/deals/$id/associations/companies" -Token $token
        if ($a.ok) {
            $res = @(Get-JsonProp $a.data 'results')
            if ($res.Count -gt 0) {
                $cid = '' + (Get-JsonProp $res[0] 'id')
                $map[$id] = $cid
                $companyIds[$cid] = $true
            }
        }
        Start-Sleep -Milliseconds 120   # stay far under rate limits
    }
    $companies = @{}
    $ids = @($companyIds.Keys)
    for ($i = 0; $i -lt $ids.Count; $i += 100) {
        $chunk = $ids[$i..([Math]::Min($i + 99, $ids.Count - 1))]
        $body = @{ properties = @('name','domain'); inputs = @($chunk | ForEach-Object { @{ id = $_ } }) }
        $r = Invoke-HubSpotApi -Method POST -Path '/crm/v3/objects/companies/batch/read' -Token $token -Body $body
        if ($r.ok) {
            foreach ($c in @(Get-JsonProp $r.data 'results')) {
                $cid = '' + (Get-JsonProp $c 'id')
                $p = Get-JsonProp $c 'properties'
                $companies[$cid] = @{ name = ('' + (Get-JsonProp $p 'name')); domain = ('' + (Get-JsonProp $p 'domain')) }
            }
        }
    }
    $out = @{}
    foreach ($dealId in $map.Keys) {
        $cid = $map[$dealId]
        if ($companies.ContainsKey($cid)) { $out[$dealId] = $companies[$cid] }
    }
    return $out
}

function Export-Cohort {
    param([array]$Deals, [hashtable]$CompanyMap, [string]$OutFile)
    $asOf = Get-Date -Format 'yyyy-MM-dd'
    $rows = New-Object System.Collections.ArrayList
    foreach ($d in $Deals) {
        $id = '' + (Get-JsonProp $d 'id')
        $p = Get-JsonProp $d 'properties'
        $close = '' + (Get-JsonProp $p 'closedate')
        if ($close.Length -ge 10) { $close = $close.Substring(0, 10) }
        $acct = @{ name = ''; domain = '' }
        if ($CompanyMap.ContainsKey($id)) { $acct = $CompanyMap[$id] }
        [void]$rows.Add(([PSCustomObject][ordered]@{
            deal_id = $id
            account_name = $acct.name
            domain = $acct.domain
            team_hint = ''
            event_date = $close
            amount = ('' + (Get-JsonProp $p 'amount'))
            reason_or_source = ('' + (Get-JsonProp $p 'dealstage'))
            as_of_date = $asOf
            notes = ('' + (Get-JsonProp $p 'dealname'))
        }))
    }
    $csv = ($rows | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
    Write-AtomicText -Path $OutFile -Content ($csv + "`r`n")
    Write-Host "wrote $($rows.Count) rows -> $OutFile"
}

$won = Search-Deals -Label 'won' -Filters @(@{ propertyName = 'hs_is_closed_won'; operator = 'EQ'; value = 'true' })
if ($null -eq $won) { exit 4 }
$lost = Search-Deals -Label 'lost' -Filters @(
    @{ propertyName = 'hs_is_closed';     operator = 'EQ'; value = 'true' },
    @{ propertyName = 'hs_is_closed_won'; operator = 'EQ'; value = 'false' })
if ($null -eq $lost) { exit 4 }

Write-Host "deals found: won=$($won.Count) lost=$($lost.Count) $(if (-not $Execute) { '(dry run: first page only)' })"
if (-not $Execute) { Write-Host 'Pass -Execute to fetch all pages + associations and write the staging CSVs.'; exit 0 }

Write-Host 'resolving company associations (this is the slow part)...'
$wonMap = Get-CompanyForDeals -Deals $won
$lostMap = Get-CompanyForDeals -Deals $lost
Export-Cohort -Deals $won  -CompanyMap $wonMap  -OutFile (Join-Path $outDir 'closed-won.csv')
Export-Cohort -Deals $lost -CompanyMap $lostMap -OutFile (Join-Path $outDir 'closed-lost.csv')
Write-Host 'done. (Files are gitignored - contact/deal data never enters git.)'
exit 0
