# collect-signals.ps1 - the non-jobs signal lanes of the Monday watch, plus the coverage ledger.
#
# WHY THIS EXISTS: snapshot.ps1 covers the ATS lane only, so an un-run lane used to leave no trace
# on disk at all. A skipped news sweep on 2026-07-28 delayed the system's first STRIKE by 24 hours
# and nothing recorded that the lane had not run. This script adds the two signal lanes that were
# VERIFIED to work on 2026-07-29, and writes one coverage row per account per lane every run -
# including an explicit not_run row for every lane nobody ran.
#
# LANES OWNED HERE (see config\lanes.csv for the full catalogue):
#   sec_filings  data.sec.gov submissions API. Needs a declared User-Agent per SEC fair access;
#                without one it returns 403. Accepts 8-K AND 6-K AND annual/proxy forms - foreign
#                private issuers (thomson-reuters, sap) file 6-K and an 8-K-only filter misses them.
#   news_broad   Google News RSS, per-account query from accounts.csv news_query.
#   news_wire    Same query scoped to the wire services, so items are the company's own releases.
#
# NOT owned here: per-site newsroom scraping. Verified 2026-07-29 that 4 of 5 newsrooms cannot be
# read automatically (JS shells / site nav). That lane is on-demand browser work, ledgered not_run.
#
# Evidence class: news items are SECONDARY sources. This script surfaces candidates; the evidence
# rules in config\scoring-rules.md still require a primary source before anything fires.
#
# Exit codes: 0 = ran (per-account truth is in coverage.csv), 2 = config unusable.
param(
    [string]$AccountsCsv = '',
    [string]$LanesCsv = '',
    [string]$SecItemMapCsv = '',
    [string]$SnapshotRoot = '',
    [string]$DateStamp = (Get-Date -Format 'yyyy-MM-dd'),
    [int]$DelayMs = 1500,
    [int]$NewsWindowDays = 8,
    [int]$WireWindowDays = 30,
    [int]$SecLookbackDays = 30,
    [string]$SecUserAgent = 'Unbound IA trigger-system (upawar@unboundia.com)',
    [switch]$SkipSec,
    [switch]$SkipNews
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
Use-Tls12

$root = Get-TriggerSystemRoot
if ($AccountsCsv -eq '')   { $AccountsCsv   = Join-Path $root 'config\accounts.csv' }
if ($LanesCsv -eq '')      { $LanesCsv      = Join-Path $root 'config\lanes.csv' }
if ($SecItemMapCsv -eq '') { $SecItemMapCsv = Join-Path $root 'config\sec-item-map.csv' }
if ($SnapshotRoot -eq '')  { $SnapshotRoot  = Join-Path $root 'data\snapshots' }

foreach ($f in @($AccountsCsv, $LanesCsv, $SecItemMapCsv)) {
    if (-not (Test-Path $f)) { Write-Host "FATAL: required config not found: $f"; exit 2 }
}
try { $accounts = @(Import-Csv $AccountsCsv) } catch { Write-Host "FATAL: cannot read $AccountsCsv : $($_.Exception.Message)"; exit 2 }
try { $lanes    = @(Import-Csv $LanesCsv) }    catch { Write-Host "FATAL: cannot read $LanesCsv : $($_.Exception.Message)"; exit 2 }
try { $itemMap  = @(Import-Csv $SecItemMapCsv) } catch { Write-Host "FATAL: cannot read $SecItemMapCsv : $($_.Exception.Message)"; exit 2 }
if ($accounts.Count -eq 0) { Write-Host "NOTE: accounts csv has no data rows - nothing to collect."; exit 0 }

$itemLookup = @{}
foreach ($m in $itemMap) { $itemLookup[('' + $m.item_code).Trim()] = $m }

# Forms worth surfacing. 425 and S-4 are merger communications - among the strongest acquisition
# evidence there is. 40-F is the Canadian annual form (thomson-reuters is a Canadian filer).
# D and D/A added 2026-07-30: Reg-D raise paperwork from private accounts (databricks, stripe)
# typically lands 2-4 weeks BEFORE press coverage (reference\gtm-intel-2026-07-30.md). S-1/F-1/
# 8-A12B added same day: IPO registration surfacing - a listing is a major spend-change event.
# Form 15 family + Form 25 added 2026-08-06 (EDGAR module spec section 3): deregistration /
# delisting = going private = an account STATE CHANGE (PE lane), never an account deletion.
# Before this, going-private events were invisible to the lane (jamf's 15-12G proved the gap).
$formsOfInterest = @('8-K','6-K','10-K','10-Q','20-F','40-F','DEF 14A','425','S-4','D','D/A','S-1','S-1/A','F-1','8-A12B','15-12B','15-12G','15-15D','25','25-NSE')

$dayRoot = Join-Path $SnapshotRoot $DateStamp
$secDir  = Join-Path $dayRoot 'sec'
$newsDir = Join-Path $dayRoot 'news'
foreach ($d in @($dayRoot, $secDir, $newsDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null } }

$runId = New-RunId -DateStamp $DateStamp
$coverage = New-Object System.Collections.ArrayList
$signals  = New-Object System.Collections.ArrayList
$cutoff   = ([datetime]::ParseExact($DateStamp, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)).AddDays(-$SecLookbackDays)

function Add-Coverage {
    param([string]$AccountId, [string]$Lane, [string]$State, $ItemsSeen = '', $ItemsNew = '',
          $HttpStatus = '', $Bytes = '', [string]$Sha = '', [string]$Note = '')
    [void]$coverage.Add([PSCustomObject][ordered]@{
        run_id = $runId; date = $DateStamp; account_id = $AccountId; lane = $Lane
        coverage_state = $State; items_seen = $ItemsSeen; items_new = $ItemsNew
        http_status = $HttpStatus; bytes = $Bytes; sha256 = $Sha; note = $Note
    })
}

function Add-Signal {
    param([string]$AccountId, [string]$Lane, [string]$ItemId, [string]$ItemDate, [string]$ItemType,
          [string]$Title, [string]$Url, [string]$Source, [string]$Relevance, [string]$CandidateTrigger, [string]$Note)
    [void]$signals.Add([PSCustomObject][ordered]@{
        run_id = $runId; date = $DateStamp; account_id = $AccountId; lane = $Lane
        item_id = $ItemId; item_date = $ItemDate; item_type = $ItemType
        title = $Title; url = $Url; source = $Source
        relevance = $Relevance; candidate_trigger = $CandidateTrigger; note = $Note
    })
}

function Clean-Text {
    # CSV-safe single line. ConvertTo-Csv quotes correctly, but embedded newlines make the file
    # painful to read and to diff, so they are collapsed here.
    param([AllowEmptyString()][string]$S)
    if ($null -eq $S) { return '' }
    return (($S -replace '[\r\n\t]+', ' ') -replace '\s+', ' ').Trim()
}

function Get-PrevLaneFile {
    # Most recent EARLIER snapshot day that actually holds this lane file for this account.
    # Per-lane (not global) on purpose: the SEC and news lanes start today while the ATS lane
    # already has 2026-07-28, so a global "previous day" would be wrong for both new lanes.
    param([string]$RelPath)
    if (-not (Test-Path $SnapshotRoot)) { return '' }
    $days = @(Get-ChildItem -Path $SnapshotRoot -Directory -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' -and $_.Name -lt $DateStamp } |
              Sort-Object Name -Descending)
    foreach ($d in $days) {
        $p = Join-Path $d.FullName $RelPath
        if (Test-Path $p) { return $p }
    }
    return ''
}

function Get-SecFilings {
    # Returns an array of filing objects from a submissions payload. filings.recent is a set of
    # PARALLEL arrays (form[i] belongs with filingDate[i]), not an array of objects.
    param([AllowEmptyString()][string]$Text)
    $parsed = ConvertFrom-JsonBig -Text $Text
    if ($null -eq $parsed) { return $null }
    $filings = Get-JsonProp $parsed 'filings'
    if ($null -eq $filings) { return $null }
    $recent = Get-JsonProp $filings 'recent'
    if ($null -eq $recent) { return $null }

    $form = Get-JsonProp $recent 'form'
    $date = Get-JsonProp $recent 'filingDate'
    $acc  = Get-JsonProp $recent 'accessionNumber'
    if ($null -eq $form -or $null -eq $date -or $null -eq $acc) { return $null }
    $items = Get-JsonProp $recent 'items'
    $pdoc  = Get-JsonProp $recent 'primaryDocument'
    $pdesc = Get-JsonProp $recent 'primaryDocDescription'

    $n = Get-JsonCount $form
    $out = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $n; $i++) {
        $it = ''; $pd = ''; $de = ''
        if ($null -ne $items -and $i -lt (Get-JsonCount $items)) { $it = '' + $items[$i] }
        if ($null -ne $pdoc  -and $i -lt (Get-JsonCount $pdoc))  { $pd = '' + $pdoc[$i] }
        if ($null -ne $pdesc -and $i -lt (Get-JsonCount $pdesc)) { $de = '' + $pdesc[$i] }
        [void]$out.Add([PSCustomObject]@{
            form = ('' + $form[$i]); filingDate = ('' + $date[$i]); accession = ('' + $acc[$i])
            items = $it; primaryDocument = $pd; primaryDocDescription = $de
        })
    }
    # leading comma stops PowerShell unrolling the collection on return. Without it a company with
    # exactly one filing comes back as a bare object and loses .Count under Set-StrictMode 2.0.
    return ,$out
}

function Get-SecRelevance {
    # Highest-relevance item wins; returns relevance + the candidate triggers those items imply.
    param([string]$ItemsCsv, [string]$Form)
    $rank = @{ 'disqualifying' = 4; 'high' = 3; 'medium' = 2; 'low' = 1; 'none' = 0; '' = 0 }
    $best = ''; $bestRank = -1; $trigs = @()
    foreach ($code in ($ItemsCsv -split ',')) {
        $c = $code.Trim()
        if ($c -eq '' -or -not $itemLookup.ContainsKey($c)) { continue }
        $row = $itemLookup[$c]
        $rel = ('' + $row.relevance).Trim()
        $r = 0; if ($rank.ContainsKey($rel)) { $r = $rank[$rel] }
        if ($r -gt $bestRank) { $bestRank = $r; $best = $rel }
        $t = ('' + $row.candidate_trigger).Trim()
        if ($t -ne '' -and $trigs -notcontains $t) { $trigs += $t }
    }
    if ($best -eq '') {
        # No item codes at all. 6-K is where foreign issuers put material news, so it must be read;
        # annual/quarterly/proxy forms are context.
        if ($Form -eq 'D' -or $Form -eq 'D/A') {
            # Form D carries no item codes. It is the funding_round primary source for private
            # accounts - filed with the SEC typically 2-4 weeks before any press coverage.
            $best = 'high'
            if ($trigs -notcontains 'funding_round') { $trigs += 'funding_round' }
        }
        elseif ($Form -eq 'S-1' -or $Form -eq 'S-1/A' -or $Form -eq 'F-1' -or $Form -eq '8-A12B') {
            # IPO registration/listing forms. High relevance, no auto-trigger: Claude triages
            # what an imminent listing means for the account before anything is scored.
            $best = 'high'
        }
        elseif ($Form -eq '15-12B' -or $Form -eq '15-12G' -or $Form -eq '15-15D' -or $Form -eq '25' -or $Form -eq '25-NSE') {
            # Deregistration / delisting notice. HIGH: triage must decide whether this is the
            # company going private (-> reclassify to PE lane, re-run edgar-classify.ps1) or a
            # single security class being retired (verified benign class 2026-08-06: taboola
            # 25-NSE = warrants; twilio Form 25 2022 - both still active 10-K filers).
            $best = 'high'
        }
        elseif ($Form -eq '6-K' -or $Form -eq '425' -or $Form -eq 'S-4') { $best = 'high' }
        elseif ($Form -eq '8-K') { $best = 'medium' }
        elseif ($Form -eq 'DEF 14A') {
            # Proxy statement: RECORD UPDATE ONLY, never an alert (spec section 3 - proxy-season
            # CMO-comp mentions are a verified false-positive class). Triage reads relevance
            # 'high' rows only, so 'low' structurally keeps DEF 14A out of the alert path; the
            # extraction runbook still mines it for officer tenure evidence.
            $best = 'low'
        }
        else { $best = 'low' }
    }
    return @{ relevance = $best; triggers = ($trigs -join '|') }
}

function Get-RssItems {
    # XPath rather than dotted property access: under Set-StrictMode 2.0 a missing XML element
    # would throw, and a feed with zero items is a normal result, not an error.
    param([AllowEmptyString()][string]$Text)
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $false
    $doc.LoadXml($Text)
    $nodes = $doc.SelectNodes('/rss/channel/item')
    $out = New-Object System.Collections.ArrayList
    if ($null -eq $nodes) { return ,$out }
    foreach ($nd in $nodes) {
        $title = ''; $link = ''; $pub = ''; $src = ''
        $t = $nd.SelectSingleNode('title');   if ($null -ne $t) { $title = $t.InnerText }
        $l = $nd.SelectSingleNode('link');    if ($null -ne $l) { $link  = $l.InnerText }
        $s = $nd.SelectSingleNode('source');  if ($null -ne $s) { $src   = $s.InnerText }
        $p = $nd.SelectSingleNode('pubDate')
        # VERIFIED FAILURE 2026-07-29: a query returning no results yields a placeholder item whose
        # pubDate is null. Casting that to [datetime] throws and kills the whole run.
        if ($null -ne $p -and ('' + $p.InnerText).Trim() -ne '') {
            $dt = [datetime]::MinValue
            if ([datetime]::TryParse($p.InnerText, [ref]$dt)) { $pub = $dt.ToString('yyyy-MM-dd') }
        }
        if (('' + $link).Trim() -eq '') { continue }   # no stable id means it cannot be diffed
        [void]$out.Add([PSCustomObject]@{ title = (Clean-Text $title); link = $link.Trim(); pubDate = $pub; source = (Clean-Text $src) })
    }
    # VERIFIED FAILURE 2026-07-29 (negative test): a feed returning 0 or 1 items unrolled on return
    # and then $items.Count threw PropertyNotFoundStrict, killing the run mid-account.
    return ,$out
}

function Invoke-NewsLane {
    param([string]$AccountId, [string]$Lane, [string]$Query, [int]$WindowDays, [string]$FileSuffix,
          [switch]$NoFetch)
    $file = Join-Path $newsDir "$AccountId.$FileSuffix.xml"
    $content = ''
    $status = ''

    # -SkipNews means "do not hit the network", NOT "pretend this lane never ran". If today's raw
    # capture is already on disk we re-derive from it. Without this, re-running with a skip flag
    # SILENTLY REPLACES a completed lane's rows with not_run and destroys the day's signals.
    if ($NoFetch) {
        if (-not (Test-Path $file)) {
            Add-Coverage -AccountId $AccountId -Lane $Lane -State 'not_run' -Note 'skipped by -SkipNews and no capture exists for this date'
            return
        }
        $content = [System.IO.File]::ReadAllText($file)
        $status = 'cached'
    } else {
        $q = $Query + ' when:' + $WindowDays + 'd'
        $url = 'https://news.google.com/rss/search?q=' + [uri]::EscapeDataString($q) + '&hl=en-US&gl=US&ceid=US:en'
        $newsUa = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
        $res = Invoke-HttpGetRaw -Url $url -UserAgent $newsUa
        if (-not $res.ok) {
            Add-Coverage -AccountId $AccountId -Lane $Lane -State 'source_unavailable' -HttpStatus $res.status -Note (Clean-Text $res.err)
            Write-Host ("  [$AccountId] $Lane -> source_unavailable ($($res.status))")
            return
        }
        Write-AtomicText -Path $file -Content $res.content
        $content = $res.content
        $status = $res.status
    }
    $bytes = (Get-Item $file).Length
    $sha = Get-FileSha256 -Path $file

    # NO @() here. Get-RssItems returns ,$out so the collection arrives intact and .Count is real.
    # Wrapping it again in @() nests the ArrayList one level deep, and then $it.link resolves via
    # PowerShell member enumeration instead of failing - which corrupts every row silently.
    $items = $null
    try { $items = Get-RssItems -Text $content }
    catch {
        Add-Coverage -AccountId $AccountId -Lane $Lane -State 'parse_failure' -HttpStatus $status -Bytes $bytes -Sha $sha -Note (Clean-Text ('stored raw; RSS parse failed: ' + $_.Exception.Message))
        Write-Host ("  [$AccountId] $Lane -> parse_failure"); return
    }

    $prev = Get-PrevLaneFile -RelPath ("news\$AccountId.$FileSuffix.xml")
    $seenLinks = @{}
    $baseline = $true
    if ($prev -ne '') {
        $baseline = $false
        try {
            $prevItems = Get-RssItems -Text ([System.IO.File]::ReadAllText($prev))
            foreach ($pi in $prevItems) { $seenLinks[$pi.link] = $true }
        } catch { $baseline = $true }   # unreadable prior capture: treat as baseline, never as "nothing new"
    }

    $newCount = 0
    foreach ($it in $items) {
        if (-not $baseline -and $seenLinks.ContainsKey($it.link)) { continue }
        $newCount++
        Add-Signal -AccountId $AccountId -Lane $Lane -ItemId $it.link -ItemDate $it.pubDate -ItemType 'news' `
                   -Title $it.title -Url $it.link -Source $it.source -Relevance '' -CandidateTrigger '' `
                   -Note $(if ($baseline) { 'baseline capture - first run of this lane for this account' } else { '' })
    }

    $state = 'checked_unchanged'
    $note = ''
    if ($baseline) { $state = 'partial'; $note = 'baseline - no prior capture of this lane to diff against' }
    elseif ($newCount -gt 0) { $state = 'checked_changed' }
    if ($items.Count -eq 0 -and -not $baseline) { $note = 'feed returned zero items - query may be too narrow' }
    if ($status -eq 'cached') { $note = (($note + '; re-derived from this date already-captured feed, not refetched').Trim('; ')) }
    Add-Coverage -AccountId $AccountId -Lane $Lane -State $state -ItemsSeen $items.Count -ItemsNew $newCount `
                 -HttpStatus $status -Bytes $bytes -Sha $sha -Note $note
    Write-Host ("  [$AccountId] $Lane -> $state ($($items.Count) items, $newCount new)")
}

# ---------------------------------------------------------------- SEC + news, per account
$i = 0
foreach ($a in $accounts) {
    $i++
    $id = ('' + $a.account_id).Trim()
    if ($id -eq '') { continue }
    if ($i -gt 1) { Start-Sleep -Milliseconds $DelayMs }
    Write-Host "[$id]"

    # ---- sec_filings
    $cik = ('' + $a.sec_edgar).Trim()
    $secFile = Join-Path $secDir "$id.json"
    # Same contract as the news lanes: -SkipSec means do not hit the network, not "erase the lane".
    if ($SkipSec -and -not (Test-Path $secFile)) {
        Add-Coverage -AccountId $id -Lane 'sec_filings' -State 'not_run' -Note 'skipped by -SkipSec and no capture exists for this date'
    } elseif ($cik -eq '') {
        Add-Coverage -AccountId $id -Lane 'sec_filings' -State 'not_run' -Note 'no sec_edgar CIK - private company or subsidiary; this lane cannot cover it'
        Write-Host ("  [$id] sec_filings -> not_run (no CIK)")
    } elseif ($cik -notmatch '^\d{10}$') {
        Add-Coverage -AccountId $id -Lane 'sec_filings' -State 'parse_failure' -Note "sec_edgar '$cik' is not a zero-padded 10-digit CIK"
        Write-Host ("  [$id] sec_filings -> parse_failure (bad CIK)")
    } else {
        $url = 'https://data.sec.gov/submissions/CIK' + $cik + '.json'
        $secContent = ''
        $secStatus = ''
        $secOk = $true
        if ($SkipSec) {
            $secContent = [System.IO.File]::ReadAllText($secFile)
            $secStatus = 'cached'
        } else {
            $res = Invoke-HttpGetRaw -Url $url -UserAgent $SecUserAgent
            $secOk = $res.ok; $secStatus = $res.status
            if ($secOk) { Write-AtomicText -Path $secFile -Content $res.content; $secContent = $res.content }
            else {
                Add-Coverage -AccountId $id -Lane 'sec_filings' -State 'source_unavailable' -HttpStatus $res.status -Note (Clean-Text $res.err)
                Write-Host ("  [$id] sec_filings -> source_unavailable ($($res.status))")
            }
        }
        if ($secOk) {
            $file = $secFile
            $bytes = (Get-Item $file).Length
            $sha = Get-FileSha256 -Path $file
            $filings = $null
            try { $filings = Get-SecFilings -Text $secContent } catch { $filings = $null }
            if ($null -eq $filings) {
                Add-Coverage -AccountId $id -Lane 'sec_filings' -State 'parse_failure' -HttpStatus $secStatus -Bytes $bytes -Sha $sha -Note 'stored raw; filings.recent shape not found'
                Write-Host ("  [$id] sec_filings -> parse_failure (shape)")
            } else {
                $prev = Get-PrevLaneFile -RelPath "sec\$id.json"
                $seenAcc = @{}
                $baseline = $true
                if ($prev -ne '') {
                    $baseline = $false
                    try {
                        $pf = Get-SecFilings -Text ([System.IO.File]::ReadAllText($prev))
                        if ($null -ne $pf) { foreach ($x in $pf) { $seenAcc[$x.accession] = $true } } else { $baseline = $true }
                    } catch { $baseline = $true }
                }
                $cikPlain = [int]$cik
                $newCount = 0; $inWindow = 0
                foreach ($f in $filings) {
                    if ($formsOfInterest -notcontains $f.form) { continue }
                    $fd = [datetime]::MinValue
                    if (-not [datetime]::TryParseExact($f.filingDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$fd)) { continue }
                    if ($fd -lt $cutoff) { continue }   # bounded lookback: a first run must not emit years of filings
                    $inWindow++
                    if (-not $baseline -and $seenAcc.ContainsKey($f.accession)) { continue }
                    $newCount++
                    $rel = Get-SecRelevance -ItemsCsv $f.items -Form $f.form
                    $accNoDash = $f.accession.Replace('-', '')
                    # URL shape verified live 2026-07-29 (both index and primary doc returned 200).
                    $link = 'https://www.sec.gov/Archives/edgar/data/' + $cikPlain + '/' + $accNoDash + '/' + $f.accession + '-index.htm'
                    $titleBits = @($f.form)
                    if ($f.items -ne '') { $titleBits += ('items ' + $f.items) }
                    if ($f.primaryDocDescription -ne '') { $titleBits += $f.primaryDocDescription }
                    Add-Signal -AccountId $id -Lane 'sec_filings' -ItemId $f.accession -ItemDate $f.filingDate -ItemType $f.form `
                               -Title (Clean-Text ($titleBits -join ' - ')) -Url $link -Source 'SEC EDGAR' `
                               -Relevance $rel.relevance -CandidateTrigger $rel.triggers `
                               -Note $(if ($baseline) { 'baseline capture - first run of this lane for this account' } else { '' })
                }
                $state = 'checked_unchanged'; $note = ''
                if ($baseline) { $state = 'partial'; $note = "baseline - no prior capture; emitted filings within $SecLookbackDays days only" }
                elseif ($newCount -gt 0) { $state = 'checked_changed' }
                if ($secStatus -eq 'cached') { $note = (($note + '; re-derived from this date already-captured filing index, not refetched').Trim('; ')) }
                Add-Coverage -AccountId $id -Lane 'sec_filings' -State $state -ItemsSeen $inWindow -ItemsNew $newCount `
                             -HttpStatus $secStatus -Bytes $bytes -Sha $sha -Note $note
                Write-Host ("  [$id] sec_filings -> $state ($inWindow in window, $newCount new)")
            }
        }
        if (-not $SkipSec) { Start-Sleep -Milliseconds $DelayMs }
    }

    # ---- news lanes
    $nq = ('' + $a.news_query).Trim()
    if ($nq -eq '') {
        Add-Coverage -AccountId $id -Lane 'news_broad' -State 'parse_failure' -Note 'news_query is blank - account is invisible to the news lane'
        Add-Coverage -AccountId $id -Lane 'news_wire'  -State 'parse_failure' -Note 'news_query is blank - account is invisible to the news lane'
        Write-Host ("  [$id] news -> parse_failure (blank news_query)")
    } else {
        Invoke-NewsLane -AccountId $id -Lane 'news_broad' -Query $nq -WindowDays $NewsWindowDays -FileSuffix 'broad' -NoFetch:$SkipNews
        if (-not $SkipNews) { Start-Sleep -Milliseconds $DelayMs }
        $wireQ = $nq + ' (site:prnewswire.com OR site:businesswire.com OR site:globenewswire.com)'
        Invoke-NewsLane -AccountId $id -Lane 'news_wire' -Query $wireQ -WindowDays $WireWindowDays -FileSuffix 'wire' -NoFetch:$SkipNews
    }
}

# ---------------------------------------------------------------- fold in the lanes this script does not own
# ats_jobs: the manifest IS the receipt, finalized by diff.ps1.
$manifestPath = Join-Path $dayRoot 'manifest.csv'
if (Test-Path $manifestPath) {
    $mrows = @()
    try { $mrows = @(Import-Csv $manifestPath) } catch { $mrows = @() }
    foreach ($m in $mrows) {
        Add-Coverage -AccountId ('' + $m.account_id) -Lane 'ats_jobs' -State ('' + $m.coverage_state) `
                     -ItemsSeen ('' + $m.job_count) -HttpStatus ('' + $m.http_status) -Bytes ('' + $m.bytes) `
                     -Sha ('' + $m.sha256) -Note (Clean-Text ('' + $m.note))
    }
} else {
    foreach ($a in $accounts) {
        Add-Coverage -AccountId ('' + $a.account_id).Trim() -Lane 'ats_jobs' -State 'not_run' -Note 'no manifest.csv for this day - snapshot.ps1 did not run'
    }
}

# stack_tells: a scan that ran and found nothing is NOT the same as a scan that never ran.
$stackPath = Join-Path $root ("data\stack-tells\$DateStamp.csv")
if (Test-Path $stackPath) {
    # Only stack_fact counts as movement. vendor_noise is the account's OWN product vocabulary
    # (Adobe/Marketo, Snowflake/reverse-ETL) - counting it would mark an account changed on the
    # strength of a tell the detector already threw away.
    $hits = @{}
    try {
        foreach ($s in @(Import-Csv $stackPath)) {
            if (('' + $s.classification).Trim() -ne 'stack_fact') { continue }
            $k = ('' + $s.account_id).Trim()
            if ($k -ne '') { if ($hits.ContainsKey($k)) { $hits[$k]++ } else { $hits[$k] = 1 } }
        }
    } catch {}
    foreach ($a in $accounts) {
        $id = ('' + $a.account_id).Trim()
        $c = 0; if ($hits.ContainsKey($id)) { $c = $hits[$id] }
        $st = 'checked_unchanged'; if ($c -gt 0) { $st = 'checked_changed' }
        Add-Coverage -AccountId $id -Lane 'stack_tells' -State $st -ItemsSeen $c -Note 'evidence-only lane; never fires a trigger by itself'
    }
} else {
    foreach ($a in $accounts) {
        Add-Coverage -AccountId ('' + $a.account_id).Trim() -Lane 'stack_tells' -State 'not_run' -Note "no data\stack-tells\$DateStamp.csv - detect-stack-tells.ps1 did not run"
    }
}

# every remaining lane in the catalogue gets an explicit not_run row, carrying its reason.
foreach ($ln in $lanes) {
    $lid = ('' + $ln.lane_id).Trim()
    if (('' + $ln.ledger_source).Trim() -ne 'none') { continue }
    foreach ($a in $accounts) {
        Add-Coverage -AccountId ('' + $a.account_id).Trim() -Lane $lid -State 'not_run' -Note (Clean-Text ('' + $ln.note))
    }
}

# ---------------------------------------------------------------- write
$covPath = Join-Path $dayRoot 'coverage.csv'
Write-AtomicText -Path $covPath -Content ((($coverage | ConvertTo-Csv -NoTypeInformation) -join "`r`n") + "`r`n")

$sigPath = Join-Path $dayRoot 'signals-new.csv'
if ($signals.Count -gt 0) {
    Write-AtomicText -Path $sigPath -Content ((($signals | ConvertTo-Csv -NoTypeInformation) -join "`r`n") + "`r`n")
} else {
    Write-AtomicText -Path $sigPath -Content ("run_id,date,account_id,lane,item_id,item_date,item_type,title,url,source,relevance,candidate_trigger,note`r`n")
}

$byState = $coverage | Group-Object coverage_state | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }
$expected = $accounts.Count * (@($lanes).Count)
Write-Host ""
Write-Host "collect-signals $DateStamp done. run_id=$runId"
Write-Host "  coverage rows : $($coverage.Count) (catalogue expects $expected = $($accounts.Count) accounts x $(@($lanes).Count) lanes)"
Write-Host "  states        : $($byState -join ' ')"
Write-Host "  new signals   : $($signals.Count)"
Write-Host "  coverage      : $covPath"
Write-Host "  signals       : $sigPath"
if ($coverage.Count -ne $expected) { Write-Host "  WARNING: coverage row count does not match the lane catalogue - a lane is missing from the ledger." }
exit 0
