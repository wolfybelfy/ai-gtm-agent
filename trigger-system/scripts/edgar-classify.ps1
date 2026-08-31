# edgar-classify.ps1 - EDGAR module Phase 0: live TAL filer classification (spec section 1.2).
#
# For every account in config\accounts.csv, determines FROM LIVE SEC DATA (never from a table in
# a spec document - the spec itself orders reverification and its own audit was stale on jamf):
#   filer_status      active_filer | foreign_filer | parent_filer | pe_owned | private_no_filer
#                     | needs_verification
#   fiscal_year_end   the submissions JSON fiscalYearEnd field (MMDD, e.g. 0131) - window
#                     arithmetic must use the account's own calendar, never assume Dec 31
#   last_annual_*     newest 10-K / 20-F / 40-F on file (active = < 15 months old per spec)
#   form15_evidence   any Form 15 family filing seen (deregistration = going private = PE lane,
#                     an account state change, NEVER an account deletion)
# Output: config\edgar-classification.csv (one row per account). Re-run quarterly per spec.
#
# CIK-less accounts: classified private_no_filer from the existing verified evidence; the official
# ticker map is scanned for their names as an IPO tripwire - any hit is flagged
# needs_verification for a manual identity check (NEVER auto-assigned: GNSS=Genasys and
# CNXN=PC Connection were verified false name-matches on 2026-08-02).
#
# Exit codes: 0 = wrote classification, 2 = config unusable.
param(
    [string]$AccountsCsv = '',
    [string]$OutCsv = '',
    [int]$DelayMs = 400,
    [string]$UserAgent = 'UnboundIA-signal-watcher upawar@unboundia.com'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')
Use-Tls12

$root = Get-TriggerSystemRoot
if ($AccountsCsv -eq '') { $AccountsCsv = Join-Path $root 'config\accounts.csv' }
if ($OutCsv -eq '')      { $OutCsv      = Join-Path $root 'config\edgar-classification.csv' }
if (-not (Test-Path $AccountsCsv)) { Write-Host "FATAL: $AccountsCsv not found"; exit 2 }
$accounts = @(Import-Csv $AccountsCsv)
if ($accounts.Count -eq 0) { Write-Host 'FATAL: no account rows'; exit 2 }

$today = Get-Date -Format 'yyyy-MM-dd'
$fifteenMonthsAgo = (Get-Date).AddMonths(-15)
$annualForms = @('10-K','20-F','40-F')
$form15Family = @('15-12B','15-12G','15-15D','25','25-NSE')

# One fetch of the official ticker map for the IPO tripwire on CIK-less accounts.
$tickerNames = @()
$tick = Invoke-HttpGetRaw -Url 'https://www.sec.gov/files/company_tickers.json' -UserAgent $UserAgent
if ($tick.ok) {
    $tj = ConvertFrom-JsonBig -Text $tick.content
    if ($null -ne $tj) {
        foreach ($p in $tj.PSObject.Properties) {
            $tickerNames += [PSCustomObject]@{
                title = ('' + (Get-JsonProp $p.Value 'title'))
                ticker = ('' + (Get-JsonProp $p.Value 'ticker'))
                cik = ('' + (Get-JsonProp $p.Value 'cik_str'))
            }
        }
    }
}
Write-Host ("ticker map: " + $tickerNames.Count + " entries " + $(if ($tick.ok) { '(live)' } else { '(UNAVAILABLE - IPO tripwire skipped this run)' }))

$rows = New-Object System.Collections.ArrayList
$i = 0
foreach ($a in $accounts) {
    $i++
    $id = ('' + $a.account_id).Trim()
    if ($id -eq '') { continue }
    $cik = ('' + $a.sec_edgar).Trim()
    $acctName = ('' + $a.account_name).Trim()

    $status = ''; $legal = ''; $fye = ''; $lastAnnualForm = ''; $lastAnnualDate = ''
    $lastForm = ''; $lastDate = ''; $f15 = ''; $note = ''

    if ($cik -match '^\d{10}$') {
        if ($i -gt 1) { Start-Sleep -Milliseconds $DelayMs }
        $res = Invoke-HttpGetRaw -Url ('https://data.sec.gov/submissions/CIK' + $cik + '.json') -UserAgent $UserAgent
        if (-not $res.ok) {
            $status = 'needs_verification'
            $note = 'submissions fetch failed HTTP ' + $res.status + ' - reclassify manually'
        } else {
            $j = ConvertFrom-JsonBig -Text $res.content
            $legal = ('' + (Get-JsonProp $j 'name'))
            $fye = ('' + (Get-JsonProp $j 'fiscalYearEnd'))
            $filings = Get-JsonProp $j 'filings'
            $recent = $null
            if ($null -ne $filings) { $recent = Get-JsonProp $filings 'recent' }
            if ($null -ne $recent) {
                $forms = Get-JsonProp $recent 'form'
                $dates = Get-JsonProp $recent 'filingDate'
                $n = Get-JsonCount $forms
                for ($k = 0; $k -lt $n; $k++) {
                    $fm = ('' + $forms[$k]); $fd = ('' + $dates[$k])
                    if ($k -eq 0) { $lastForm = $fm; $lastDate = $fd }
                    if ($lastAnnualDate -eq '' -and $annualForms -contains $fm) { $lastAnnualForm = $fm; $lastAnnualDate = $fd }
                    if ($f15 -eq '' -and $form15Family -contains $fm) { $f15 = $fm + ' filed ' + $fd }
                }
            }
            $annualFresh = $false
            $ad = [datetime]::MinValue
            if ($lastAnnualDate -ne '' -and [datetime]::TryParseExact($lastAnnualDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$ad)) {
                $annualFresh = ($ad -gt $fifteenMonthsAgo)
            }
            # Parent-CIK accounts: the registered legal name is a DIFFERENT company. EXPLICIT list,
            # not a heuristic - both name heuristics tried on 2026-08-06 misfired in one direction
            # or the other ("Thomson Reuters Corporation" vs "THOMSON REUTERS CORP /CAN/" = same
            # company; "Amazon Web Services" vs "AMAZON COM INC" = subsidiary). These accounts are
            # DELIBERATELY watched via a parent CIK, each identity-verified live:
            #   aws -> AMZN 0001018724, redhat -> IBM 0000051143 (both 2026-08-06);
            #   linkedin -> MSFT 0000789019 (EX-21 of MSFT FY2026 10-K filed 2026-07-29) and
            #   splunk -> CSCO 0000858877 (CSCO 10-K EX-21.1 filed 2025-09-03) - both added to
            #   this list 2026-08-15 after a refresh run silently reclassified them active_filer
            #   (the list had not been extended with the 2026-08-14 TAL expansion).
            $parentCikAccounts = @('aws', 'redhat', 'linkedin', 'splunk')
            $isParent = ($parentCikAccounts -contains $id)
            if ($lastAnnualDate -eq '' -and $f15 -eq '' -and ($lastForm -eq 'D' -or $lastForm -eq 'D/A')) {
                # Private Reg-D raiser (stripe, databricks - identities verified 2026-08-02).
                $status = 'regd_filer'
                $note = 'private company with a Reg D filing history - no annuals expected; the Form D lane covers funding rounds (filed typically 2-4 weeks pre-press)'
            } elseif ($f15 -ne '' -and -not $annualFresh) {
                # Deregistration AGE decides the lane (split added 2026-08-15; before this, an
                # epicor-style 2015 deregistration got the same "12-18mo PE mandate" note as
                # jamf's 2026 one). Form 15 within 24 months = live PE-mandate window (pe_owned);
                # older = deregistered_form15 (CIK kept as a tripwire, no active PE-window claim).
                $f15Age = [datetime]::MinValue
                $f15DateStr = ''
                if ($f15 -match '(\d{4}-\d{2}-\d{2})') { $f15DateStr = $Matches[1] }
                $f15Recent = $false
                if ($f15DateStr -ne '' -and [datetime]::TryParseExact($f15DateStr, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$f15Age)) {
                    $f15Recent = ($f15Age -gt (Get-Date).AddMonths(-24))
                }
                if ($f15Recent) {
                    $status = 'pe_owned'
                    $note = 'deregistered (' + $f15 + ') - PE lane per spec section 6: intensified non-EDGAR watching 12-18mo post-close; NOT a dead account'
                } else {
                    $status = 'deregistered_form15'
                    $note = 'deregistered long ago (' + $f15 + ') - outside any PE mandate window; CIK kept as a re-registration tripwire only'
                }
            } elseif ($isParent) {
                $status = 'parent_filer'
                $note = 'account is a subsidiary; this CIK is the parent (' + $legal + ') - extract segment-level statements only'
            } elseif ($annualFresh -and ($lastAnnualForm -eq '20-F' -or $lastAnnualForm -eq '40-F')) {
                $status = 'foreign_filer'
                $note = 'foreign private issuer - annual ' + $lastAnnualForm + ' + irregular 6-K cadence'
            } elseif ($annualFresh) {
                $status = 'active_filer'
            } else {
                $status = 'needs_verification'
                $note = 'CIK exists but newest annual (' + $lastAnnualForm + ' ' + $lastAnnualDate + ') is stale and no Form 15 seen - check for late filer / recent IPO with no annual yet'
                if ($lastAnnualDate -eq '') { $note = 'CIK exists but no annual on file - likely recent registrant (Reg D / pre-IPO); triage manually' }
            }
        }
    } else {
        $status = 'private_no_filer'
        $note = 'no CIK on file (verified absent in prior identity checks) - jobs/news/funding lanes cover this account'
        # IPO tripwire: exact-ish name scan of the official ticker map. A hit is ONLY a flag.
        if ($acctName -ne '' -and $tickerNames.Count -gt 0) {
            $needle = $acctName.ToLower()
            foreach ($t in $tickerNames) {
                if ($t.title.ToLower() -eq $needle -or $t.title.ToLower().StartsWith($needle + ' ')) {
                    $status = 'needs_verification'
                    $note = 'ticker-map name hit: "' + $t.title + '" (' + $t.ticker + ', CIK ' + $t.cik + ') - IDENTITY CHECK REQUIRED before adopting (GNSS/CNXN false-match precedent)'
                    break
                }
            }
        }
    }

    [void]$rows.Add([PSCustomObject][ordered]@{
        account_id = $id; cik = $cik; filer_status = $status; legal_name = $legal
        fiscal_year_end = $fye; last_annual_form = $lastAnnualForm; last_annual_date = $lastAnnualDate
        last_filing_form = $lastForm; last_filing_date = $lastDate; form15_evidence = $f15
        classification_checked_on = $today; note = $note
    })
    Write-Host ("[$id] " + $status + $(if ($fye -ne '') { ' FYE=' + $fye } else { '' }) + $(if ($f15 -ne '') { ' ' + $f15 } else { '' }))
}

Write-AtomicText -Path $OutCsv -Content ((($rows | ConvertTo-Csv -NoTypeInformation) -join "`r`n") + "`r`n")
Write-Host ''
Write-Host ("wrote " + $rows.Count + " rows -> " + $OutCsv)
$byStatus = $rows | Group-Object filer_status | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Host ("status split: " + ($byStatus -join ' '))
exit 0
