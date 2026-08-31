# count-marketing-roles.ps1 - live trigger-heat measurement (Phase 1 re-selection, decision 2026-07-28).
# For every discovered account: count OPEN MARKETING-FAMILY ROLES right now.
#   structured feeds -> parse titles (reuses today's snapshot files when present; else one live fetch)
#   page_only server-rendered pages -> title matches in raw HTML (labeled html_approx)
#   JS shells / blocked -> unknown (browser or search later; never guessed)
# Output CSV: account, domain, ats_type, method, total_jobs, mktg_roles, sample titles.
# ASCII only. Politeness 1s between live fetches.
param(
    [Parameter(Mandatory=$true)][string[]]$DiscoveryCsvs,
    [Parameter(Mandatory=$true)][string]$OutCsv,
    [string]$SnapshotDir = '',
    [int]$DelayMs = 1000,
    [int]$MaxPages = 50
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
Use-Tls12
$UA = 'trigger-system-discovery/1.0'

# marketing-family title matcher (conservative; word-ish boundaries; sample titles kept as evidence)
# NOTE: PS variable names are CASE-INSENSITIVE - the pattern is ReadOnly and no other variable may
# reuse this name in any casing (a lowercase result variable once clobbered it; incident 2026-07-28).
Set-Variable -Name MktgPattern -Option ReadOnly -Value '(?i)(marketing|marketer|demand[ -]?gen|growth[ -]market|brand (manager|director|lead|strategist)|paid (media|search|social)|campaign (manager|specialist|lead|strategist)|\babm\b|account[ -]based market|content (marketing|strategist)|lifecycle market|events? (marketing|manager)|communications (manager|director|lead|specialist)|public relations|\bpr (manager|director)\b|\bseo\b|\bsem\b|media buy)'

function Get-TitlesFromJson([string]$AtsType, [string]$Content) {
    $titles = New-Object System.Collections.Generic.List[string]
    $j = ConvertFrom-JsonBig $Content
    if ($null -eq $j) { return ,$titles }
    switch ($AtsType) {
        'greenhouse'      { $arr = Get-JsonProp $j 'jobs';        foreach ($x in @($arr)) { $t = Get-JsonProp $x 'title'; if ($t) { $titles.Add([string]$t) } } }
        'ashby'           { $arr = Get-JsonProp $j 'jobs';        foreach ($x in @($arr)) { $t = Get-JsonProp $x 'title'; if ($t) { $titles.Add([string]$t) } } }
        'lever'           { foreach ($x in @($j)) { $t = Get-JsonProp $x 'text'; if ($t) { $titles.Add([string]$t) } } }
        'smartrecruiters' { $arr = Get-JsonProp $j 'content';     foreach ($x in @($arr)) { $t = Get-JsonProp $x 'name'; if ($t) { $titles.Add([string]$t) } } }
        'workday'         { $arr = Get-JsonProp $j 'jobPostings'; foreach ($x in @($arr)) { $t = Get-JsonProp $x 'title'; if ($t) { $titles.Add([string]$t) } } }
        'recruitee'       { $arr = Get-JsonProp $j 'offers';      foreach ($x in @($arr)) { $t = Get-JsonProp $x 'title'; if ($t) { $titles.Add([string]$t) } } }
        'amazon'          { $arr = Get-JsonProp $j 'jobs';        foreach ($x in @($arr)) { $t = Get-JsonProp $x 'title'; if ($t) { $titles.Add([string]$t) } } }
    }
    # ,$titles: PS unrolls a returned collection (1 item -> bare string, 0 -> $null) and the
    # caller's .Count then throws under StrictMode. Same fix as collect-signals.ps1 (2026-08-15,
    # crashed live on lexmark's single-posting Workday feed 2026-08-15).
    return ,$titles
}

function Get-AccountId([string]$Name) { (($Name -replace '\([^)]*\)', '') -replace '[^A-Za-z0-9]+', '-').Trim('-').ToLower() }

$rows = New-Object System.Collections.Generic.List[object]
foreach ($csv in $DiscoveryCsvs) {
    if (-not (Test-Path $csv)) { Write-Host "SKIP missing: $csv"; continue }
    foreach ($r in @(Import-Csv $csv)) { $rows.Add($r) }
}
Write-Host ("count-marketing-roles: " + $rows.Count + " discovery rows")

$out = New-Object System.Collections.Generic.List[object]
foreach ($r in $rows) {
    $name = ('' + $r.name).Trim()
    $domain = ('' + $r.domain).Trim().ToLower()
    $ats = ('' + $r.ats_type).Trim()
    $feed = ('' + $r.ats_feed_url).Trim()
    $careers = ('' + $r.careers_url).Trim()
    $acct = Get-AccountId $name
    $titles = New-Object System.Collections.Generic.List[string]
    $method = ''
    $totalJobs = -1

    if ($ats -ne '' -and $feed -ne '') {
        # 1) local snapshot reuse (today's captured feed pages)
        $usedLocal = $false
        if ($SnapshotDir -ne '') {
            # accounts.csv ids differ from generated ids for some (aws, redhat...) - try both forms
            $cands = @($acct)
            $short = $domain.Split('.')[0]
            if ($cands -notcontains $short) { $cands += $short }
            foreach ($id in $cands) {
                $base = Join-Path $SnapshotDir ("ats\" + $id + ".json")
                if (Test-Path $base) {
                    foreach ($f in (Get-ChildItem (Join-Path $SnapshotDir 'ats') -Filter ($id + '*.json'))) {
                        $c = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
                        foreach ($t in (Get-TitlesFromJson $ats $c)) { $titles.Add($t) }
                    }
                    $usedLocal = $true
                    $method = 'snapshot'
                    break
                }
            }
        }
        # 2) live fetch when no local capture
        if (-not $usedLocal) {
            $method = 'live_feed'
            if ($ats -eq 'workday') {
                # Workday CXS keeps returning results for offsets past the end - the ONLY safe stop
                # is the feed's own total from page 1 (incident 2026-07-28: 10x duplicate inflation).
                $offset = 0
                $wdTotal = -1
                for ($p = 0; $p -lt $MaxPages; $p++) {
                    Start-Sleep -Milliseconds $DelayMs
                    $resp = Invoke-HttpPostJsonRaw -Url $feed -BodyJson ('{"limit":20,"offset":' + $offset + ',"searchText":""}') -TimeoutSec 60 -UserAgent $UA
                    if (-not $resp.ok) { break }
                    if ($wdTotal -lt 0) {
                        $j0 = ConvertFrom-JsonBig $resp.content
                        $t0 = Get-JsonProp $j0 'total'
                        if ($null -ne $t0) { $wdTotal = [int]$t0 } else { $wdTotal = 0 }
                    }
                    $pg = Get-TitlesFromJson 'workday' $resp.content
                    if ($pg.Count -eq 0) { break }
                    foreach ($t in $pg) { $titles.Add($t) }
                    $offset += 20
                    if ($wdTotal -ge 0 -and $offset -ge $wdTotal) { break }
                }
            } elseif ($ats -eq 'smartrecruiters') {
                $offset = 0
                for ($p = 0; $p -lt $MaxPages; $p++) {
                    Start-Sleep -Milliseconds $DelayMs
                    $resp = Invoke-HttpGetRaw -Url ($feed + '?limit=100&offset=' + $offset) -TimeoutSec 60 -UserAgent $UA
                    if (-not $resp.ok) { break }
                    $pg = Get-TitlesFromJson 'smartrecruiters' $resp.content
                    if ($pg.Count -eq 0) { break }
                    foreach ($t in $pg) { $titles.Add($t) }
                    $offset += 100
                }
            } else {
                Start-Sleep -Milliseconds $DelayMs
                $resp = Invoke-HttpGetRaw -Url $feed -TimeoutSec 90 -UserAgent $UA
                if ($resp.ok) { foreach ($t in (Get-TitlesFromJson $ats $resp.content)) { $titles.Add($t) } }
            }
        }
        $totalJobs = $titles.Count
    }
    elseif ($careers -ne '') {
        # page_only: amazon-jobs JSON careers_url parses as a feed; server-rendered HTML gets approx title matching
        Start-Sleep -Milliseconds $DelayMs
        $resp = Invoke-HttpGetRaw -Url $careers -TimeoutSec 60 -UserAgent $UA
        if ($resp.ok) {
            if ($careers -match 'amazon\.jobs' -and $careers -match 'search\.json') {
                $j = ConvertFrom-JsonBig $resp.content
                $hits = Get-JsonProp $j 'hits'
                foreach ($t in (Get-TitlesFromJson 'amazon' $resp.content)) { $titles.Add($t) }
                $totalJobs = 0; if ($null -ne $hits) { $totalJobs = [int]$hits }
                $method = 'amazon_json'
            } else {
                $method = 'html_approx'
                # decode entities lightly, strip tags, then scan line-ish fragments for title matches
                $txt = $resp.content -replace '<script[\s\S]*?</script>', ' ' -replace '<style[\s\S]*?</style>', ' ' -replace '<[^>]+>', "`n"
                $txt = $txt -replace '&amp;', '&' -replace '&#39;|&apos;', "'" -replace '&quot;', '"'
                foreach ($ln in ($txt -split "`n")) {
                    $s = $ln.Trim()
                    if ($s.Length -lt 8 -or $s.Length -gt 90) { continue }
                    if ($s -match $MktgPattern -and $s -notmatch '(?i)(cookie|privacy|policy|learn more|about|solutions|products|platform|pricing|resources|login|footer|copyright)') { $titles.Add($s) }
                }
                $totalJobs = -1
            }
        } else { $method = 'blocked_' + $resp.status }
    }
    else { $method = 'no_surface' }

    $roleHits = @($titles | Where-Object { ([string]$_) -match $MktgPattern })
    $sample = @($roleHits | Select-Object -Unique -First 8) -join ' ~ '
    $out.Add([PSCustomObject][ordered]@{
        name        = $name
        domain      = $domain
        ats_type    = $ats
        method      = $method
        total_jobs  = $totalJobs
        mktg_roles  = $roleHits.Count
        mktg_sample = $sample
    })
    Write-Host ("  " + $domain.PadRight(28) + " " + $method.PadRight(12) + " total=" + $totalJobs + " mktg=" + $roleHits.Count)
}

$tmp = $OutCsv + '.tmp'
$out | Export-Csv -Path $tmp -NoTypeInformation -Encoding UTF8
Move-Item -Force $tmp $OutCsv
Write-Host ("WROTE: " + $OutCsv)
exit 0
