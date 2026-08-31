# discover-ats.ps1 - per-account ATS + newsroom discovery (Phase 1 admission machinery).
# Layered waterfall (decision 2026-07-28, user-directed "do not miss things"):
#   Layer 1: site crawl - homepage + careers pages; scan RAW HTML (incl. scripts/iframes)
#            for ATS signatures; collect ALL Workday regional sites and test each.
#   Layer 2: direct ATS API probes - slug guesses (domain stem, name variants) tested
#            straight against greenhouse/lever/ashby/smartrecruiters/recruitee APIs.
#            A 200 with a parsable jobs payload is definitive; no search engine needed.
#   (Layers 3-4 - web search operators + manual review - run OUTSIDE this script by the
#    session, on rows this script leaves unresolved. This script never guesses silently.)
# Output: one CSV row per account with everything found + how it was found.
# Politeness: 1s minimum between HTTP calls; honest User-Agent. ASCII only (policy 2026-07-28).
param(
    [Parameter(Mandatory=$true)][string]$CandidatesCsv,   # columns: name,domain (extra columns ignored)
    [Parameter(Mandatory=$true)][string]$OutCsv,
    [int]$DelayMs = 1000,
    [int]$MaxProbeGuesses = 4
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
Use-Tls12
$UA = 'trigger-system-discovery/1.0'

function Invoke-DiscGet([string]$Url, [int]$TimeoutSec = 45) {
    Start-Sleep -Milliseconds $script:DelayMs
    return Invoke-HttpGetRaw -Url $Url -TimeoutSec $TimeoutSec -UserAgent $script:UA
}
function Invoke-DiscPost([string]$Url, [string]$BodyJson, [int]$TimeoutSec = 45) {
    Start-Sleep -Milliseconds $script:DelayMs
    return Invoke-HttpPostJsonRaw -Url $Url -BodyJson $BodyJson -TimeoutSec $TimeoutSec -UserAgent $script:UA
}

# ---- feed testers: return @{ ok; status; count; feedUrl } -----------------------------
function Test-Greenhouse([string]$Token) {
    $u = "https://boards-api.greenhouse.io/v1/boards/$Token/jobs"
    $r = Invoke-DiscGet $u
    $n = -1
    if ($r.ok) { $j = ConvertFrom-JsonBig $r.content; $jobs = Get-JsonProp $j 'jobs'; if ($null -ne $jobs) { $n = Get-JsonCount $jobs } }
    return @{ ok = ($r.ok -and $n -ge 0); status = $r.status; count = $n; feedUrl = $u }
}
function Test-Lever([string]$Site, [bool]$Eu) {
    $host2 = 'api.lever.co'; if ($Eu) { $host2 = 'api.eu.lever.co' }
    $u = "https://$host2/v0/postings/$Site" + '?mode=json'
    $r = Invoke-DiscGet $u
    $n = -1
    if ($r.ok) { $j = ConvertFrom-JsonBig $r.content; if ($null -ne $j) { $n = Get-JsonCount $j } }
    return @{ ok = ($r.ok -and $n -ge 0); status = $r.status; count = $n; feedUrl = $u }
}
function Test-Ashby([string]$Board) {
    $u = "https://api.ashbyhq.com/posting-api/job-board/$Board"
    $r = Invoke-DiscGet $u -TimeoutSec 90
    $n = -1
    if ($r.ok) { $j = ConvertFrom-JsonBig $r.content; $jobs = Get-JsonProp $j 'jobs'; if ($null -ne $jobs) { $n = Get-JsonCount $jobs } }
    return @{ ok = ($r.ok -and $n -ge 0); status = $r.status; count = $n; feedUrl = $u }
}
function Test-SmartRecruiters([string]$Company) {
    $u = "https://api.smartrecruiters.com/v1/companies/$Company/postings"
    $r = Invoke-DiscGet ($u + '?limit=10')
    $n = -1
    if ($r.ok) { $j = ConvertFrom-JsonBig $r.content; $t = Get-JsonProp $j 'totalFound'; if ($null -ne $t) { $n = [int]$t } }
    return @{ ok = ($r.ok -and $n -ge 0); status = $r.status; count = $n; feedUrl = $u }
}
function Test-Workday([string]$Tenant, [string]$Wdn, [string]$Site) {
    $u = "https://$Tenant.wd$Wdn.myworkdayjobs.com/wday/cxs/$Tenant/$Site/jobs"
    $r = Invoke-DiscPost $u '{"limit":1,"offset":0,"searchText":""}'
    $n = -1
    if ($r.ok) { $j = ConvertFrom-JsonBig $r.content; $t = Get-JsonProp $j 'total'; if ($null -ne $t) { $n = [int]$t } }
    return @{ ok = ($r.ok -and $n -ge 0); status = $r.status; count = $n; feedUrl = $u }
}
function Test-Recruitee([string]$Company) {
    $u = "https://$Company.recruitee.com/api/offers/"
    $r = Invoke-DiscGet $u
    $n = -1
    if ($r.ok) { $j = ConvertFrom-JsonBig $r.content; $o = Get-JsonProp $j 'offers'; if ($null -ne $o) { $n = Get-JsonCount $o } }
    return @{ ok = ($r.ok -and $n -ge 0); status = $r.status; count = $n; feedUrl = $u }
}

# ---- signature extraction over raw HTML ----------------------------------------------
function Get-AtsSignatures([string]$Html) {
    # returns hashtable of lists keyed by ats type; workday entries are "tenant|wdN|site" (site may be '')
    $found = @{ greenhouse = @(); lever = @(); levereu = @(); ashby = @(); smartrecruiters = @(); workday = @(); recruitee = @(); foreign = @() }
    if ([string]::IsNullOrEmpty($Html)) { return $found }

    foreach ($m in [regex]::Matches($Html, 'greenhouse\.io/embed/job_board\?[^"''\s<>]*?for=([A-Za-z0-9_-]+)')) {
        $found.greenhouse += $m.Groups[1].Value.ToLower()
    }
    foreach ($m in [regex]::Matches($Html, 'boards-api\.greenhouse\.io/v1/boards/([A-Za-z0-9_-]+)')) {
        $found.greenhouse += $m.Groups[1].Value.ToLower()
    }
    foreach ($m in [regex]::Matches($Html, '(?:job-boards|boards)\.greenhouse\.io/([A-Za-z0-9_-]+)')) {
        $t = $m.Groups[1].Value.ToLower()
        if ($t -notin @('embed', 'v1', 'js')) { $found.greenhouse += $t }
    }
    foreach ($m in [regex]::Matches($Html, 'jobs\.lever\.co/([A-Za-z0-9_-]+)')) { $found.lever += $m.Groups[1].Value }
    foreach ($m in [regex]::Matches($Html, 'jobs\.eu\.lever\.co/([A-Za-z0-9_-]+)')) { $found.levereu += $m.Groups[1].Value }
    foreach ($m in [regex]::Matches($Html, 'jobs\.ashbyhq\.com/([A-Za-z0-9._%-]+)')) { $found.ashby += $m.Groups[1].Value.TrimEnd('.') }
    foreach ($m in [regex]::Matches($Html, '(?:careers|jobs)\.smartrecruiters\.com/([A-Za-z0-9_-]+)')) {
        $t = $m.Groups[1].Value
        if ($t -ne 'oneclick-ui' -and $t -ne 'job-api') { $found.smartrecruiters += $t }
    }
    foreach ($m in [regex]::Matches($Html, '([a-z0-9-]+)\.wd(\d+)\.myworkdayjobs\.com(/[A-Za-z0-9_/%-]*)?')) {
        $tenant = $m.Groups[1].Value
        $wdn = $m.Groups[2].Value
        $site = ''
        if ($m.Groups[3].Success) {
            $segs = @($m.Groups[3].Value.Trim('/').Split('/') | Where-Object { $_ -ne '' })
            foreach ($seg in $segs) {
                if ($seg -match '^[a-z]{2}(-[A-Za-z]{2,4})?$') { continue }   # locale like en-US
                if ($seg -in @('job', 'jobs', 'wday', 'login', 'details')) { break }
                $site = $seg
                break
            }
        }
        $found.workday += ($tenant + '|' + $wdn + '|' + $site)
    }
    foreach ($m in [regex]::Matches($Html, '([a-z0-9-]+)\.recruitee\.com')) {
        $t = $m.Groups[1].Value
        if ($t -notin @('www', 'app', 'api', 'careers', 'd10zminp1cyta8')) { $found.recruitee += $t }
    }
    foreach ($pat in @(
            @('icims', 'icims\.com'),
            @('successfactors', '(?:successfactors\.com|jobs\.sap\.com|careers\.sap\.com)'),
            @('eightfold', 'eightfold\.ai'),
            @('phenom', 'phenom(?:people)?\.com'),
            @('avature', 'avature\.net'),
            @('oracle-hcm', '(?:oraclecloud\.com/hcmUI|taleo\.net)'),
            @('jobvite', 'jobvite\.com'),
            @('breezy', 'breezy\.hr'),
            @('bamboohr', 'bamboohr\.com/(?:jobs|careers)'),
            @('amazon-jobs', 'amazon\.jobs'),
            @('dayforce', 'dayforcehcm\.com'),
            @('ultipro', '(?:ultipro\.com|recruiting\.ulti)'),
            @('greenhouse-api-alt', 'api\.greenhouse\.io'))) {
        if ([regex]::IsMatch($Html, $pat[1])) { $found.foreign += $pat[0] }
    }
    foreach ($k in @($found.Keys)) { $found[$k] = @($found[$k] | Select-Object -Unique) }
    return $found
}

function Get-CareersLinks([string]$Html, [string]$Domain) {
    # ranked candidate careers URLs from raw hrefs
    $out = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrEmpty($Html)) { return $out }
    foreach ($m in [regex]::Matches($Html, '(?i)href\s*=\s*["'']([^"''#<>\s]+)["'']')) {
        $u = $m.Groups[1].Value
        if ($u -notmatch '(?i)(career|jobs|join-?us|work-?with-?us|working-?at)') { continue }
        if ($u -match '(?i)(linkedin\.com|facebook\.com|twitter\.com|x\.com|youtube\.com|instagram\.com|glassdoor|indeed\.com|mailto:|javascript:)') { continue }
        if ($u -match '^//') { $u = 'https:' + $u }
        elseif ($u -match '^/') { $u = 'https://' + $Domain + $u }
        elseif ($u -notmatch '^https?://') { continue }
        $rank = 1
        if ($u -match '(?i)career') { $rank = 3 } elseif ($u -match '(?i)/jobs') { $rank = 2 }
        $out.Add([PSCustomObject]@{ url = $u; rank = $rank })
    }
    return @($out | Sort-Object -Property @{Expression = 'rank'; Descending = $true} | Select-Object -ExpandProperty url -Unique)
}

function Get-NewsroomCandidates([string]$Html, [string]$Domain) {
    $stem = $Domain.Split('.')[0]
    $out = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrEmpty($Html)) { return @() }
    foreach ($m in [regex]::Matches($Html, '(?i)href\s*=\s*["'']([^"''#<>\s]+)["'']')) {
        $u = $m.Groups[1].Value
        if ($u -notmatch '(?i)(newsroom|press|/news\b|/news/|/news$|news\.|media-center|/media/|blog)') { continue }
        if ($u -match '(?i)(linkedin\.com|facebook\.com|twitter\.com|x\.com|youtube\.com|instagram\.com|mailto:|javascript:)') { continue }
        if ($u -match '^//') { $u = 'https:' + $u }
        elseif ($u -match '^/') { $u = 'https://' + $Domain + $u }
        elseif ($u -notmatch '^https?://') { continue }
        # same-company constraint: host must contain the domain stem
        try { $hostName = ([uri]$u).Host } catch { continue }
        if ($hostName -notmatch [regex]::Escape($stem)) { continue }
        $rank = 0
        if ($u -match '(?i)newsroom') { $rank = 5 }
        elseif ($u -match '(?i)press') { $rank = 4 }
        elseif ($u -match '(?i)(/news\b|/news/|/news$|news\.)') { $rank = 3 }
        elseif ($u -match '(?i)(media-center|/media/)') { $rank = 2 }
        elseif ($u -match '(?i)blog') { $rank = 1 }
        $out.Add([PSCustomObject]@{ url = $u; rank = $rank })
    }
    return @($out | Sort-Object -Property @{Expression = 'rank'; Descending = $true} | Select-Object -ExpandProperty url -Unique)
}

function Get-SlugGuesses([string]$Name, [string]$Domain) {
    $g = New-Object System.Collections.Generic.List[string]
    $stem = $Domain.Split('.')[0].ToLower()
    $g.Add($stem)
    $paren = ''
    if ($Name -match '\(([^)]+)\)') { $paren = $Matches[1].Trim().ToLower() -replace '[^a-z0-9]', '' }
    if ($paren -ne '' -and $paren.Length -ge 2) { $g.Add($paren) }
    $base = ($Name -replace '\([^)]*\)', '').Trim().ToLower()
    $nospace = $base -replace '[^a-z0-9]', ''
    $hyphen = ($base -replace '[^a-z0-9]+', '-').Trim('-')
    $first = ($base -split '[^a-z0-9]+')[0]
    foreach ($x in @($nospace, $hyphen, $first)) { if ($x -and $x.Length -ge 3) { $g.Add($x) } }
    return @($g | Select-Object -Unique | Select-Object -First $script:MaxProbeGuesses)
}

# ---- main -----------------------------------------------------------------------------
if (-not (Test-Path $CandidatesCsv)) { Write-Host "FATAL: not found: $CandidatesCsv"; exit 3 }
$cands = @(Import-Csv $CandidatesCsv)
Write-Host ("discover-ats: " + $cands.Count + " candidates, delay " + $DelayMs + "ms")
$results = New-Object System.Collections.Generic.List[object]

foreach ($c in $cands) {
    $name = ('' + $c.name).Trim()
    $domain = ('' + $c.domain).Trim().ToLower()
    if ($domain -eq '') { continue }
    Write-Host ("--- " + $name + " (" + $domain + ")")
    $notes = New-Object System.Collections.Generic.List[string]
    $method = ''

    # Layer 1a: homepage ($homeResp, not $home - HOME is a read-only automatic variable)
    $homeResp = Invoke-DiscGet ("https://" + $domain + "/")
    $homeStatus = $homeResp.status
    $pool = $homeResp.content

    # Layer 1b: careers page(s) - linked first, then common paths
    $careersUrl = ''
    $careersStatus = 0
    $links = Get-CareersLinks $homeResp.content $domain
    $tried = 0
    foreach ($u in $links) {
        if ($tried -ge 2) { break }
        $tried++
        $r = Invoke-DiscGet $u
        if ($r.ok) { $careersUrl = $u; $careersStatus = $r.status; $pool = $pool + "`n" + $r.content; break }
        if ($careersUrl -eq '') { $careersUrl = $u; $careersStatus = $r.status }   # keep best-effort URL + its status
    }
    if ($careersUrl -eq '' -or $careersStatus -ne 200) {
        foreach ($p in @('/careers', '/careers/', '/jobs', '/company/careers')) {
            $u = 'https://' + $domain + $p
            $r = Invoke-DiscGet $u
            if ($r.ok) { $careersUrl = $u; $careersStatus = $r.status; $pool = $pool + "`n" + $r.content; break }
        }
    }

    # Layer 1c: signature scan over everything fetched
    $sig = Get-AtsSignatures $pool
    $atsType = ''; $atsToken = ''; $feedUrl = ''; $feedStatus = 0; $feedCount = -1; $wdAlt = ''

    if ($sig.workday.Count -gt 0) {
        # test every distinct workday (tenant,wdN,site); keep the largest board as primary
        $best = $null
        $alts = New-Object System.Collections.Generic.List[string]
        foreach ($w in $sig.workday) {
            $parts = $w.Split('|')
            if ($parts[2] -eq '') { $alts.Add($parts[0] + '.wd' + $parts[1] + ' site-unresolved'); continue }
            $t = Test-Workday $parts[0] $parts[1] $parts[2]
            if ($t.ok) {
                $alts.Add($parts[2] + '=' + $t.count)
                if ($null -eq $best -or $t.count -gt $best.count) { $best = $t; $atsToken = $parts[0] + '|wd' + $parts[1] + '|' + $parts[2] }
            } else {
                $alts.Add($parts[2] + '=HTTP' + $t.status)
            }
        }
        if ($null -ne $best) {
            $atsType = 'workday'; $feedUrl = $best.feedUrl; $feedStatus = $best.status; $feedCount = $best.count
            $method = 'crawl'
            $wdAlt = ($alts -join '; ')
        } else {
            $notes.Add('workday signature seen but no site testable: ' + ($alts -join '; '))
        }
    }
    if ($atsType -eq '' -and $sig.greenhouse.Count -gt 0) {
        foreach ($tok in $sig.greenhouse) {
            $t = Test-Greenhouse $tok
            if ($t.ok) { $atsType = 'greenhouse'; $atsToken = $tok; $feedUrl = $t.feedUrl; $feedStatus = $t.status; $feedCount = $t.count; $method = 'crawl'; break }
        }
    }
    if ($atsType -eq '' -and ($sig.lever.Count -gt 0 -or $sig.levereu.Count -gt 0)) {
        foreach ($tok in $sig.lever) {
            $t = Test-Lever $tok $false
            if ($t.ok) { $atsType = 'lever'; $atsToken = $tok; $feedUrl = $t.feedUrl; $feedStatus = $t.status; $feedCount = $t.count; $method = 'crawl'; break }
        }
        if ($atsType -eq '') {
            foreach ($tok in $sig.levereu) {
                $t = Test-Lever $tok $true
                if ($t.ok) { $atsType = 'lever'; $atsToken = $tok + ' (eu)'; $feedUrl = $t.feedUrl; $feedStatus = $t.status; $feedCount = $t.count; $method = 'crawl'; break }
            }
        }
    }
    if ($atsType -eq '' -and $sig.ashby.Count -gt 0) {
        foreach ($tok in $sig.ashby) {
            $t = Test-Ashby $tok
            if ($t.ok) { $atsType = 'ashby'; $atsToken = $tok; $feedUrl = $t.feedUrl; $feedStatus = $t.status; $feedCount = $t.count; $method = 'crawl'; break }
        }
    }
    if ($atsType -eq '' -and $sig.smartrecruiters.Count -gt 0) {
        foreach ($tok in $sig.smartrecruiters) {
            $t = Test-SmartRecruiters $tok
            if ($t.ok) { $atsType = 'smartrecruiters'; $atsToken = $tok; $feedUrl = $t.feedUrl; $feedStatus = $t.status; $feedCount = $t.count; $method = 'crawl'; break }
        }
    }
    if ($atsType -eq '' -and $sig.recruitee.Count -gt 0) {
        foreach ($tok in $sig.recruitee) {
            $t = Test-Recruitee $tok
            if ($t.ok) { $atsType = 'recruitee'; $atsToken = $tok; $feedUrl = $t.feedUrl; $feedStatus = $t.status; $feedCount = $t.count; $method = 'crawl'; break }
        }
    }

    # Layer 2: direct API probes when the crawl resolved nothing structured
    if ($atsType -eq '') {
        $guesses = Get-SlugGuesses $name $domain
        $notes.Add('probes tried: ' + ($guesses -join ','))
        foreach ($gz in $guesses) {
            $t = Test-Greenhouse $gz
            if ($t.ok) { $atsType = 'greenhouse'; $atsToken = $gz; $feedUrl = $t.feedUrl; $feedStatus = $t.status; $feedCount = $t.count; $method = 'probe'; break }
            $t = Test-Lever $gz $false
            if ($t.ok) { $atsType = 'lever'; $atsToken = $gz; $feedUrl = $t.feedUrl; $feedStatus = $t.status; $feedCount = $t.count; $method = 'probe'; break }
            $t = Test-Ashby $gz
            if ($t.ok) { $atsType = 'ashby'; $atsToken = $gz; $feedUrl = $t.feedUrl; $feedStatus = $t.status; $feedCount = $t.count; $method = 'probe'; break }
            $t = Test-SmartRecruiters $gz
            if ($t.ok -and $t.count -gt 0) { $atsType = 'smartrecruiters'; $atsToken = $gz; $feedUrl = $t.feedUrl; $feedStatus = $t.status; $feedCount = $t.count; $method = 'probe'; break }
            $t = Test-Recruitee $gz
            if ($t.ok) { $atsType = 'recruitee'; $atsToken = $gz; $feedUrl = $t.feedUrl; $feedStatus = $t.status; $feedCount = $t.count; $method = 'probe'; break }
        }
    }
    if ($atsType -eq '') { $method = 'unresolved' }

    # newsroom
    $newsUrl = ''; $newsStatus = 0
    $ncands = Get-NewsroomCandidates $homeResp.content $domain
    $ntried = 0
    foreach ($u in $ncands) {
        if ($ntried -ge 3) { break }
        $ntried++
        $r = Invoke-DiscGet $u
        if ($r.ok) { $newsUrl = $u; $newsStatus = $r.status; break }
    }

    if ($sig.foreign.Count -gt 0) { $notes.Add('other ATS detected: ' + ($sig.foreign -join ',')) }

    $results.Add([PSCustomObject][ordered]@{
        name             = $name
        domain           = $domain
        homepage_status  = $homeStatus
        careers_url      = $careersUrl
        careers_status   = $careersStatus
        ats_type         = $atsType
        ats_token        = $atsToken
        ats_feed_url     = $feedUrl
        feed_status      = $feedStatus
        feed_job_count   = $feedCount
        wd_sites         = $wdAlt
        newsroom_url     = $newsUrl
        newsroom_status  = $newsStatus
        discovery_method = $method
        notes            = ($notes -join ' | ')
    })
    Write-Host ("    ats=" + $atsType + " token=" + $atsToken + " jobs=" + $feedCount + " method=" + $method + " news=" + $newsUrl)
}

$tmp = $OutCsv + '.tmp'
$results | Export-Csv -Path $tmp -NoTypeInformation -Encoding UTF8
Move-Item -Force $tmp $OutCsv
Write-Host ("WROTE: " + $OutCsv + " (" + $results.Count + " rows)")
exit 0
