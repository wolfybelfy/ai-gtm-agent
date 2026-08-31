# zoominfo-enrich.ps1 - the verified-email step (ZoomInfo GTM API, re-adopted 2026-08-20 by
# user order). Deterministic and verdict-gated: enriches ONLY buying-group rows of named
# plays, only rows with a BLANK email and NO hold, suppression-checked per person (rule 8),
# hard credit cap per run.
#
# API contracts (fetched live from docs.zoominfo.com 2026-08-20; reference\zoominfo-api-playbook.md):
#   token:  POST https://api.zoominfo.com/gtm/oauth/v1/token   (client credentials, Basic)
#   enrich: POST https://api.zoominfo.com/gtm/data/v1/contacts/enrich  (<=25 records;
#           1 credit per MATCHED returned record; requiredFields ["email"] = never charged
#           for a contact ZoomInfo has no email for; no-match/error = no charge)
# RESPONSE-ENVELOPE HONESTY: the docs name the fields but not the exact envelope. This script
# parses defensively; if it cannot recognize the shape it STOPS, saves the raw response to
# staging\enrich\ for attended review, queues an alert, and exits 1 having written nothing.
# The first -Execute run is the attended verification-ladder step by design.
#
# Secrets: ZOOMINFO_CLIENT_ID / ZOOMINFO_CLIENT_SECRET user env vars (rule 3). Missing ->
# exit 3 (the Monday wrapper logs a WARN and moves on; automation self-activates once set).
# DRY RUN by default: plans eligible rows, calls NOTHING. -Execute spends (capped).
# Exit codes: 0 ok/dry, 1 anomaly or >=1 failure, 3 credentials absent.
param(
    [string]$PlayId = '',
    [switch]$Auto,
    [switch]$Execute,
    [int]$MaxCredits = 25,   # anomaly guard, not a spend gate (user rule 2026-08-21: every play enriches, spend not a concern)
    [int]$AccuracyMin = 85
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
Use-Tls12
$root = Get-TriggerSystemRoot
$stamp = (Get-Date).ToString('yyyy-MM-dd')
$nowUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

$ziId = $env:ZOOMINFO_CLIENT_ID
$ziSecret = $env:ZOOMINFO_CLIENT_SECRET
if ($Execute -and ([string]::IsNullOrWhiteSpace($ziId) -or [string]::IsNullOrWhiteSpace($ziSecret))) {
    Write-Host 'ZOOMINFO_CLIENT_ID / ZOOMINFO_CLIENT_SECRET not set - skipping (set them and this step self-activates).'
    exit 3
}

# ---- CSV helpers (all-quoted serializer discipline; header line preserved byte-identical) --
function Split-CsvLine {
    param([string]$Line)
    $fields = New-Object System.Collections.ArrayList
    $sb = New-Object System.Text.StringBuilder
    $inQ = $false
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $c = $Line[$i]
        if ($inQ) {
            if ($c -eq '"') {
                if ($i + 1 -lt $Line.Length -and $Line[$i+1] -eq '"') { [void]$sb.Append('"'); $i++ }
                else { $inQ = $false }
            } else { [void]$sb.Append($c) }
        } else {
            if ($c -eq '"') { $inQ = $true }
            elseif ($c -eq ',') { [void]$fields.Add($sb.ToString()); [void]$sb.Clear() }
            else { [void]$sb.Append($c) }
        }
    }
    [void]$fields.Add($sb.ToString())
    return ,@($fields.ToArray())
}
function Q { param([string]$s) '"' + ($s -replace '"','""') + '"' }
function Join-CsvLine { param([string[]]$Fields) (($Fields | ForEach-Object { Q $_ }) -join ',') }

function Read-LinesShared {
    # tolerate files held open by Excel/editors (FileShare ReadWrite)
    param([string]$Path)
    $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $sr = New-Object System.IO.StreamReader($fs, $true)
        $txt = $sr.ReadToEnd()
    } finally { $fs.Dispose() }
    return ,@($txt -split "`r`n|`n")
}
# ---- ZoomInfo HTTP (never throws; honors one 429 Retry-After) ------------------------------
function Get-ZiToken {
    $pair = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$ziId`:$ziSecret"))
    try {
        $r = Invoke-WebRequest -Uri 'https://api.zoominfo.com/gtm/oauth/v1/token' -Method Post `
            -Headers @{ Authorization = "Basic $pair"; Accept = 'application/json' } `
            -ContentType 'application/x-www-form-urlencoded' -Body 'grant_type=client_credentials' `
            -UseBasicParsing -TimeoutSec 60
        $j = ConvertFrom-JsonBig -Text $r.Content
        $tok = '' + (Get-JsonProp $j 'access_token')
        if ($tok -ne '') { return @{ ok = $true; token = $tok; err = '' } }
        return @{ ok = $false; token = ''; err = 'token response had no access_token' }
    } catch {
        return @{ ok = $false; token = ''; err = $_.Exception.Message }
    }
}
function Invoke-ZiPost {
    param([string]$Url, [string]$Token, [string]$BodyJson)
    for ($try = 1; $try -le 2; $try++) {
        try {
            # JSON:API media type is REQUIRED (plain application/json got HTTP 406 live 2026-08-20).
            # Body goes as UTF-8 BYTES: PS 5.1 sends strings Latin-1, which corrupts any
            # non-ASCII names require an explicit UTF-8 byte body on Windows PowerShell.
            # NO charset parameter here: JSON:API forbids media-type params (servers may 415).
            $r = Invoke-WebRequest -Uri $Url -Method Post -Body ([Text.Encoding]::UTF8.GetBytes($BodyJson)) -ContentType 'application/vnd.api+json' `
                -Headers @{ Authorization = "Bearer $Token"; accept = 'application/vnd.api+json' } `
                -UseBasicParsing -TimeoutSec 120
            $content = $r.Content
            if ($content -is [byte[]]) { $content = [System.Text.Encoding]::UTF8.GetString($content) }  # vnd.api+json arrives as bytes
            return @{ ok = $true; status = [int]$r.StatusCode; content = $content; err = '' }
        } catch [System.Net.WebException] {
            $status = 0
            if ($null -ne $_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -eq 429 -and $try -eq 1) {
                $wait = 30
                try { $ra = $_.Exception.Response.Headers['Retry-After']; if ($ra -match '^\d+$') { $wait = [Math]::Min([int]$ra, 120) } } catch {}
                Write-Host "429 rate limited - waiting $wait s (one retry)"; Start-Sleep -Seconds $wait; continue
            }
            return @{ ok = $false; status = $status; content = ''; err = $_.Exception.Message }
        } catch {
            return @{ ok = $false; status = 0; content = ''; err = $_.Exception.Message }
        }
    }
}

# ---- alert queue ---------------------------------------------------------------------------
function Queue-SystemAlert {
    param([string]$Slug, [string]$Subject, [string]$Body)
    $hm = (Get-Date).ToString('HHmmss')   # seconds precision - two runs in one minute overwrote each other 2026-08-20
    $file = Join-Path $root ("staging\alerts\$stamp-$hm-system-$Slug.md")
    $content = "TYPE: SYSTEM`r`nSUBJECT: $Subject`r`nTO: default`r`nSTATUS: pending`r`n`r`n$Body`r`n"
    Write-AtomicText -Path $file -Content $content
}

# ---- resolve target plays ------------------------------------------------------------------
$playIds = @()
if ($Auto) {
    $queueFile = Join-Path $root ("staging\play-queue\$stamp.csv")
    if (Test-Path $queueFile) {
        $qLines = [IO.File]::ReadAllLines($queueFile)
        if ($qLines.Count -gt 1) {
            $qHdr = Split-CsvLine -Line $qLines[0]
            $pIdx = [Array]::IndexOf(($qHdr | ForEach-Object { $_.Trim('"') }), 'play_id')
            if ($pIdx -ge 0) {
                foreach ($ql in ($qLines | Select-Object -Skip 1)) {
                    if ($ql.Trim() -eq '') { continue }
                    $qf = Split-CsvLine -Line $ql
                    if ($qf.Count -gt $pIdx -and $qf[$pIdx] -ne '') { $playIds += $qf[$pIdx] }
                }
            }
        }
    }
    if ($playIds.Count -eq 0) { Write-Host "auto mode: no play queue rows for $stamp - nothing to enrich."; exit 0 }
} elseif ($PlayId -ne '') {
    $playIds = @($PlayId)
} else {
    Write-Host 'usage: zoominfo-enrich.ps1 -PlayId <plays folder name> [-Execute] | -Auto [-Execute]'; exit 1
}
$playIds = @($playIds | Select-Object -Unique)

# ---- suppression (provider-neutral; absence of the domain baseline = STOP) ----------------
$baselineFile = Join-Path $root 'config\suppression-baseline.csv'
if (-not (Test-Path $baselineFile)) { Write-Host 'FATAL: config\suppression-baseline.csv missing - suppression-first policy forbids proceeding.'; exit 1 }
$supFiles = @($baselineFile)
$localSupFile = Join-Path $root 'staging\suppression-local.csv'
if (Test-Path $localSupFile) { $supFiles += $localSupFile }
$supPeople = @(); $supEmails = @(); $supDomains = @()
foreach ($supFile in $supFiles) {
    $supLines = [IO.File]::ReadAllLines($supFile)
    if ($supLines.Count -le 1) { continue }
    $sHdr = (Split-CsvLine -Line $supLines[0]) | ForEach-Object { $_.Trim('"').Trim().ToLower() }
    $iEmail = [Array]::IndexOf($sHdr, 'email'); $iPerson = [Array]::IndexOf($sHdr, 'person'); $iSupDomain = [Array]::IndexOf($sHdr, 'domain')
    foreach ($sl in ($supLines | Select-Object -Skip 1)) {
        if ($sl.Trim() -eq '') { continue }
        $sf = Split-CsvLine -Line $sl
        if ($iEmail -ge 0 -and $sf.Count -gt $iEmail -and $sf[$iEmail] -ne '') { $supEmails += $sf[$iEmail].ToLower() }
        if ($iPerson -ge 0 -and $sf.Count -gt $iPerson -and $sf[$iPerson] -ne '') { $supPeople += $sf[$iPerson].ToLower() }
        if ($iSupDomain -ge 0 -and $sf.Count -gt $iSupDomain -and $sf[$iSupDomain] -ne '') { $supDomains += $sf[$iSupDomain].ToLower() }
    }
}
$supPeople = @($supPeople | Select-Object -Unique); $supEmails = @($supEmails | Select-Object -Unique); $supDomains = @($supDomains | Select-Object -Unique)

# ---- per-play processing -------------------------------------------------------------------
$holdPattern = '(?i)gate-?3|do.?not.?contact|no.?send|\bhold\b|\bbench\b'
$totalPlanned = 0; $totalVerified = 0; $totalReview = 0; $totalNoMatch = 0; $creditsSpent = 0
$failures = 0
$summaryLines = @()
$token = $null

foreach ($playFolder in $playIds) {
    $bgPath = Join-Path $root ("plays\$playFolder\buying-group.csv")
    if (-not (Test-Path $bgPath)) { Write-Host "SKIP $playFolder - no buying-group.csv"; continue }
    try { $lines = Read-LinesShared -Path $bgPath }
    catch { Write-Host "SKIP $playFolder - buying-group unreadable ($($_.Exception.Message))"; $failures++; continue }
    $lines = @($lines | Where-Object { $null -ne $_ })
    if ($lines.Count -lt 2) { Write-Host "SKIP $playFolder - empty buying group"; continue }
    $headerLine = $lines[0]
    $hdr = (Split-CsvLine -Line $headerLine) | ForEach-Object { $_.Trim('"').Trim() }
    # schema generations: new = full_name,...,region,...,email,email_status,...,hold ; old = person_name,...,email,phone,source,as_of
    $iName = [Array]::IndexOf($hdr, 'full_name'); if ($iName -lt 0) { $iName = [Array]::IndexOf($hdr, 'person_name') }
    if ($iName -lt 0) { $iName = [Array]::IndexOf($hdr, 'name') }  # pre-08 plays (snowflake 08-03): name,title,triad_role,city,...
    $iTitle = [Array]::IndexOf($hdr, 'title')
    $iRole = [Array]::IndexOf($hdr, 'triad_role')
    $iCompany = [Array]::IndexOf($hdr, 'company')
    $iDomain = [Array]::IndexOf($hdr, 'company_domain')
    $iRegion = [Array]::IndexOf($hdr, 'region')
    $iEmail = [Array]::IndexOf($hdr, 'email')
    $iStatus = [Array]::IndexOf($hdr, 'email_status')
    $iHold = [Array]::IndexOf($hdr, 'hold')
    if ($iName -lt 0 -or $iEmail -lt 0) { Write-Host "SKIP $playFolder - unrecognized buying-group header"; $failures++; continue }

    # account name + DOMAIN from accounts.csv (domain = the stale-email tripwire; name = old-schema fallback)
    $accountCompany = ''; $accountDomain = ''
    if ($playFolder -match '^\d{4}-\d{2}-\d{2}-([a-z0-9]+)-') {
        $accId = $Matches[1]
        $accLines = [IO.File]::ReadAllLines((Join-Path $root 'config\accounts.csv'))
        foreach ($al in ($accLines | Select-Object -Skip 1)) {
            $af = Split-CsvLine -Line $al
            if ($af.Count -gt 2 -and $af[0] -eq $accId) { $accountCompany = $af[1]; $accountDomain = $af[2]; break }
        }
    }
    if ($accountDomain -ne '' -and $supDomains -contains $accountDomain.ToLower()) {
        Write-Host "SUPPRESSED account domain: $accountDomain - ZoomInfo not called"
        continue
    }

    $rows = @(); foreach ($ln in ($lines | Select-Object -Skip 1)) { if ($ln.Trim() -ne '') { $rows += ,(Split-CsvLine -Line $ln) } }
    $eligible = @()
    for ($ri = 0; $ri -lt $rows.Count; $ri++) {
        $f = $rows[$ri]
        $name = $f[$iName]
        $email = if ($f.Count -gt $iEmail) { $f[$iEmail] } else { '' }
        if ($email -ne '') { continue }
        $holdTxt = ''
        if ($iHold -ge 0 -and $f.Count -gt $iHold) { $holdTxt = $f[$iHold] }
        $roleTxt = if ($iRole -ge 0 -and $f.Count -gt $iRole) { $f[$iRole] } else { '' }
        $statusTxt = if ($iStatus -ge 0 -and $f.Count -gt $iStatus) { $f[$iStatus] } else { '' }
        if ($holdTxt -ne '' -or $roleTxt -match $holdPattern -or $statusTxt -match '(?i)gate-?3|no enrichment') { Write-Host "  hold-skip: $name"; continue }
        if ($iRegion -ge 0 -and $f.Count -gt $iRegion -and $f[$iRegion] -notmatch '^(?i)us') { Write-Host "  region-skip (non-US): $name"; continue }
        if ($supPeople -contains $name.ToLower()) { Write-Host "  SUPPRESSED: $name"; continue }
        $company = if ($iCompany -ge 0 -and $f.Count -gt $iCompany) { $f[$iCompany] } else { $accountCompany }
        $title = if ($iTitle -ge 0 -and $f.Count -gt $iTitle) { $f[$iTitle] } else { '' }
        $parts = @($name -split '\s+' | Where-Object { $_ -ne '' -and $_ -notmatch '^"' })
        if ($parts.Count -lt 2) { Write-Host "  name-skip (cannot split): $name"; continue }
        $eligible += ,@{ rowIndex = $ri; name = $name; first = $parts[0]; last = $parts[$parts.Count-1]; company = $company; title = $title }
    }
    if ($eligible.Count -eq 0) { Write-Host "$playFolder : no eligible rows (all filled, held, or suppressed)"; continue }
    if ($eligible.Count -gt 25) { $eligible = $eligible[0..24]; Write-Host "$playFolder : capped at 25 per request" }
    $totalPlanned += $eligible.Count

    if (-not $Execute) {
        Write-Host "PLAN $playFolder : would enrich $($eligible.Count) row(s): $(@($eligible | ForEach-Object { $_.name }) -join ', ')"
        continue
    }
    if ($creditsSpent -ge $MaxCredits) { Write-Host "$playFolder : credit cap $MaxCredits reached - deferred"; continue }
    # the cap must bound the BATCH TOO: every matched record in a request is charged server-side
    $budget = $MaxCredits - $creditsSpent
    if ($eligible.Count -gt $budget) {
        Write-Host "$playFolder : batch trimmed to remaining credit budget ($budget of $($eligible.Count) eligible)"
        $eligible = @($eligible[0..($budget - 1)])
    }

    if ($null -eq $token) {
        $tk = Get-ZiToken
        if (-not $tk.ok) { Write-Host "FATAL: token request failed - $($tk.err)"; Queue-SystemAlert -Slug 'zoominfo-token-fail' -Subject '[SYSTEM] FAIL: ZoomInfo token request failed' -Body "The enrichment step could not authenticate. Error: $($tk.err). Check the account lock / credentials."; exit 1 }
        $token = $tk.token
    }

    # contactAccuracyScoreMin REJECTED live (HTTP 400, bisected 2026-08-20) despite docs - floor enforced client-side below
    $inputs = @($eligible | ForEach-Object { @{ firstName = $_.first; lastName = $_.last; companyName = $_.company; jobTitle = $_.title } })
    $body = @{ data = @{ type = 'ContactEnrich'; attributes = @{ matchPersonInput = $inputs
               outputFields = @('id','firstName','lastName','email','jobTitle','companyName','contactAccuracyScore','hasCanadianEmail','validDate')
               requiredFields = @('email') } } } | ConvertTo-Json -Depth 8
    $resp = Invoke-ZiPost -Url 'https://api.zoominfo.com/gtm/data/v1/contacts/enrich' -Token $token -BodyJson $body
    if (-not $resp.ok) {
        $failures++
        Write-Host "FAIL $playFolder : enrich HTTP $($resp.status) - $($resp.err)"
        Queue-SystemAlert -Slug "zoominfo-fail-$($playFolder.Substring(11))" -Subject '[SYSTEM] FAIL: ZoomInfo enrichment call failed' -Body "Play $playFolder : HTTP $($resp.status) $($resp.err). No credits should have been charged on an error (doc-verbatim). Nothing was written."
        continue
    }
    # defensive parse: walk the JSON for objects that carry email + firstName + lastName
    $rawPath = Join-Path $root ("staging\enrich\zoominfo-raw-$stamp-$((Get-Date).ToString('HHmmss')).json")
    Write-AtomicText -Path $rawPath -Content $resp.content
    $j = ConvertFrom-JsonBig -Text $resp.content
    $found = New-Object System.Collections.ArrayList
    function Walk-Json { param($Node)
        if ($null -eq $Node) { return }
        if ($Node -is [System.Collections.IDictionary]) {
            if ($Node.Contains('email') -and $Node.Contains('firstName') -and $Node.Contains('lastName')) { [void]$script:found.Add($Node) }
            foreach ($v in @($Node.Values)) { Walk-Json -Node $v }
        } elseif ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
            foreach ($item in $Node) { Walk-Json -Node $item }
        } else {
            $props = $null
            try { $props = $Node.PSObject.Properties } catch {}
            if ($null -ne $props) {
                $names = @($props | ForEach-Object Name)
                if ($names -contains 'email' -and $names -contains 'firstName' -and $names -contains 'lastName') { [void]$script:found.Add($Node) }
                foreach ($p in $props) { if ($p.Name -ne 'PSObject') { Walk-Json -Node $p.Value } }
            }
        }
    }
    Walk-Json -Node $j
    # A 200 can legitimately carry ZERO contact objects: when every requested contact is a
    # NoMatch, ZoomInfo returns data[] entries of type "NoMatch" (matchStatus
    # NON_MATCH_BY_REQUIRED_FIELDS = it holds no email for that person, so NOTHING is charged -
    # exactly the requiredFields:["email"] behaviour this script's header documents).
    # That is a NORMAL, FREE outcome, and the per-row loop below already records it correctly
    # as "no match". Treating it as an ANOMALY (as this script did until 2026-08-26) stopped
    # the play, queued a [SYSTEM] alert and would fail stage 2c of the Monday chain for an
    # outcome that simply means "ZoomInfo has no email on file". Caught live 2026-08-26 on the
    # autodesk revalidation (1 eligible row -> all-NoMatch -> false anomaly, exit 1).
    # Genuine unrecognized-shape detection is preserved: it fires only when there are NEITHER
    # contact objects NOR recognizable NoMatch entries.
    $noMatchSeen = 0
    $dataArr = Get-JsonProp $j 'data'
    if ($null -ne $dataArr) {
        foreach ($d in @($dataArr)) {
            $ty = '' + (Get-JsonProp $d 'type')
            $mt = ''
            $mo = Get-JsonProp $d 'meta'
            if ($null -ne $mo) { $mt = '' + (Get-JsonProp $mo 'matchStatus') }
            if ($ty -eq 'NoMatch' -or $mt -like 'NON_MATCH*') { $noMatchSeen++ }
        }
    }
    if ($found.Count -eq 0 -and $noMatchSeen -gt 0) {
        Write-Host "$playFolder : all $noMatchSeen requested contact(s) returned NoMatch (no email on file; no credit charged)."
    }
    if ($found.Count -eq 0 -and $noMatchSeen -eq 0) {
        $failures++
        Write-Host "ANOMALY $playFolder : HTTP 200 but no recognizable contact objects - raw saved to $rawPath; STOPPING this play, nothing written."
        Queue-SystemAlert -Slug "zoominfo-shape-$($playFolder.Substring(11))" -Subject '[SYSTEM] ZoomInfo response shape needs attended review' -Body "Play $playFolder : the enrich call returned 200 but the response envelope was not recognized. Raw response saved at staging\enrich\$(Split-Path $rawPath -Leaf). Review it attended and refine the parser; nothing was written to the buying group."
        continue
    }

    # map results to eligible rows by name (ci), write back
    $resultsCsv = Join-Path $root 'staging\enrich\enrich-results.csv'
    if (-not (Test-Path $resultsCsv)) { Write-AtomicText -Path $resultsCsv -Content '"request_id","play_id","email","email_verified","phone","provider_or_method","resolved_date","notes"' }
    $resultLines = @()
    $changed = $false
    foreach ($e in $eligible) {
        $hit = $null
        foreach ($fo in $found) {
            $fn = ('' + (Get-JsonProp $fo 'firstName')).ToLower(); $lnm = ('' + (Get-JsonProp $fo 'lastName')).ToLower()
            if ($fn -eq $e.first.ToLower() -and $lnm -eq $e.last.ToLower()) { $hit = $fo; break }
        }
        if ($null -eq $hit) { $totalNoMatch++; $summaryLines += "no match: $($e.name)"; $resultLines += (Join-CsvLine -Fields @((New-RunId -DateStamp $stamp), $playFolder, '', 'no', '', 'zoominfo', $stamp, 'no-match (no credit per docs)')); continue }
        $em = '' + (Get-JsonProp $hit 'email')
        $acc = '' + (Get-JsonProp $hit 'contactAccuracyScore')
        $ca = '' + (Get-JsonProp $hit 'hasCanadianEmail')
        if ($em -eq '') { $totalNoMatch++; $summaryLines += "match without email (requiredFields should prevent this): $($e.name)"; continue }
        $creditsSpent++
        if ($supEmails -contains $em.ToLower()) {
            $summaryLines += "SUPPRESSED post-enrich (email on suppression list): $($e.name) - email NOT written"
            $resultLines += (Join-CsvLine -Fields @((New-RunId -DateStamp $stamp), $playFolder, $em, 'suppressed', '', 'zoominfo', $stamp, 'email matched local suppression - not imported'))
            continue
        }
        # STALE-DOMAIN tripwire (added after the live catch 2026-08-20: ZoomInfo returned a
        # freshworks.com address for the new Veeam CMO - accuracy 98, wrong company. Provider
        # email records lag job moves; the domain check catches what the accuracy score cannot.)
        # acceptable set = the row's own domain AND the account domain (acquisition plays live
        # across both, e.g. getmaintainx.com people migrating to autodesk.com - either is clean)
        $expDoms = @()
        if ($iDomain -ge 0 -and $rows[$e.rowIndex].Count -gt $iDomain -and $rows[$e.rowIndex][$iDomain] -ne '') { $expDoms += $rows[$e.rowIndex][$iDomain].ToLower() }
        if ($accountDomain -ne '') { $expDoms += $accountDomain.ToLower() }
        $expDoms = @($expDoms | Select-Object -Unique)
        $emDom = ''
        if ($em -match '@([^@]+)$') { $emDom = $Matches[1].ToLower() }
        $flag = ''
        if ($expDoms.Count -gt 0 -and $emDom -ne '' -and $expDoms -notcontains $emDom) { $flag = "STALE-DOMAIN ($emDom vs expected $($expDoms -join '/')) - prior-company record, DO NOT USE" }
        elseif ($ca -match '(?i)true') { $flag = 'CASL REVIEW (hasCanadianEmail=true) - Gate-3 check before any send' }
        elseif ($acc -ne '' -and [int]$acc -lt $AccuracyMin) { $flag = "LOW ACCURACY $acc - attended review" }
        $status = if ($flag -ne '') { "REVIEW: $flag; zoominfo $stamp accuracy $acc" } else { "verified zoominfo $stamp (accuracy $acc)" }
        if ($flag -ne '') { $totalReview++ } else { $totalVerified++ }
        $summaryLines += "$($status.Split(';')[0]): $($e.name)"
        $resultLines += (Join-CsvLine -Fields @((New-RunId -DateStamp $stamp), $playFolder, $em, 'yes', '', 'zoominfo', $stamp, $status))
        if ($flag -match '^STALE-DOMAIN') {
            # wrong-company address: NEVER written to the roster in any schema
        } elseif ($flag -ne '' -and $iStatus -lt 0) {
            # old schema has no status column to carry a REVIEW flag - leave the row blank;
            # the results ledger + alert carry the flagged address for attended review
        } else {
            $f = $rows[$e.rowIndex]
            while ($f.Count -le $iEmail) { $f += '' }
            $f[$iEmail] = $em
            if ($iStatus -ge 0) { while ($f.Count -le $iStatus) { $f += '' }; $f[$iStatus] = $status }
            $rows[$e.rowIndex] = $f
            $changed = $true
        }
        if ($creditsSpent -ge $MaxCredits) { Write-Host "credit cap $MaxCredits reached mid-play"; break }
    }
    if ($resultLines.Count -gt 0) {
        $existing = [IO.File]::ReadAllText($resultsCsv).TrimEnd("`r","`n")
        Write-AtomicText -Path $resultsCsv -Content ($existing + "`r`n" + ($resultLines -join "`r`n") + "`r`n")
    }
    if ($changed) {
        $out = New-Object System.Collections.ArrayList
        [void]$out.Add($headerLine)
        foreach ($f in $rows) { [void]$out.Add((Join-CsvLine -Fields $f)) }
        # round-trip gate: every serialized row must re-parse to identical fields
        $rtOk = $true
        for ($ri = 0; $ri -lt $rows.Count; $ri++) {
            $re = Split-CsvLine -Line $out[$ri + 1]
            if ((($re -join ([char]1)) -ne ($rows[$ri] -join ([char]1)))) { $rtOk = $false; break }
        }
        if (-not $rtOk) { Write-Host "FATAL $playFolder : round-trip check failed - buying-group NOT written"; $failures++; continue }
        try {
            Write-AtomicText -Path $bgPath -Content (($out.ToArray() -join "`r`n") + "`r`n")
            Write-Host "$playFolder : buying-group.csv updated"
        } catch {
            $failures++
            Write-Host "FAIL $playFolder : buying-group locked for write ($($_.Exception.Message)) - results are in enrich-results.csv; re-run write when the file is closed"
        }
    }
}

if (-not $Execute) { Write-Host "DRY RUN done: $totalPlanned row(s) would be sent for enrichment (cap $MaxCredits credits)."; exit 0 }
$sum = "ZoomInfo enrichment run $nowUtc`: $totalVerified verified, $totalReview review-flagged, $totalNoMatch no-match, $creditsSpent credit(s) spent (cap $MaxCredits)."
Write-Host $sum
if (($totalVerified + $totalReview + $totalNoMatch) -gt 0) {
    Queue-SystemAlert -Slug 'zoominfo-enrich-summary' -Subject '[SYSTEM] Verified emails added by ZoomInfo' -Body ($sum + "`r`n`r`n" + ($summaryLines -join "`r`n") + "`r`n`r`nAddresses live only in the play buying-group files (never in git). Review-flagged rows need an attended look before any send.")
}
if ($failures -gt 0) { exit 1 } else { exit 0 }

