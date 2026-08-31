# TAL selection criteria — Phase 1 criteria memo (v1, 2026-07-28)
_Status: **CRITERIA SET (recommended), selection EXECUTED on the seed, sales sign-off PENDING.** The plan's Phase 1 entry rule ("proceed on seed if criteria lag; mark rebuilt rows LIKELY until sales confirms") is in effect: every admitted row carries a LIKELY mark in `config\accounts.csv` notes until sales leadership confirms. Prepared by the trigger-system session, 2026-07-28._

## 0. The seed (provenance)
- File: `data\imports\2026-07-28-tal-seed-q3-2026-phase1-paid.xlsx` ("Q3 2026 TAL Phase 1 for Paid", received from the user 2026-07-28 — a day early; promised for 07-29). Extraction: `data\imports\2026-07-28-tal-seed-extracted.csv`.
- Contents observed: **157 companies** (unique domains, zero dupes), researched by the company's own team: domain, industry, size band, revenue (provider figure + manually-validated figure), ownership type, HQ + country, LinkedIn URL, B2B classification text, **demand-gen team-size research with named roles and a LOW/MEDIUM/HIGH rubric**, ZoomInfo-style intent topics, 2025 paid-media spend estimates, parent-company research. One tracked note: **G42 — "Active prospect through parent core42"** (the only Ameena-notes entry).
- Profile: 156 US + 1 UAE (G42); 80 Public / 70 Private / 7 unlabeled; sizes mostly 1,001-5,000 (81), 5,001-10,000 (31), 10,001+ (32); industries: Software Development 140, Technology/Internet 11, blank 6. Six rows are name+domain only (under-researched): JumpCloud, Checkmarx, BambooHR, Veracode, G42, Illumio.

## 1. What the list is for (fixed by strategy)
25 accounts whose **marketing teams** we watch daily for in-window buying triggers. Teams are the unit; the checkpoint is >=75 scoreable teams across the 25 (Phase 2). An account earns its slot by being watchable AND winnable, not by logo prestige.

## 2. Hard criteria (RECOMMENDED — every admitted account passes; sales to confirm)
- **ICP fit:** B2B software / cloud / SaaS / security / dev-infrastructure companies (the seed's own universe: 151 of 157 rows are Software Development or Technology & Internet). Consumer-only businesses excluded. [LIKELY — this is the seed's implicit ICP, read from the data; sales confirms the segment list.]
- **Size band:** >=1,001 employees (multi-team marketing orgs exist here — the teams-not-logos thesis needs teams, plural). 501-1,000 admissible only with strong signals (scored -1). Under-researched rows (no size data) not auto-admissible.
- **Region/legal:** US = pilot-eligible working assumption until Gate 3's lawful-basis matrix lands. Non-US rows are **watch-only** until their country row exists. G42 (UAE) is admitted watch-only on exactly this rule.
- **Marketing org observable:** operationalized as: passed per-account discovery with at least one live, verified watch surface (structured ATS feed tested live, or a capturable careers page) — see section 4. Zero-surface accounts are replaced.
- **Conflict-free:** Gate 1 signed conflict list still OPEN. Interim: the seed's own flags are honored — **G42 is watch-only, no outreach** (active prospect via parent Core42 per Ameena's note). `is_client=false` is assumed for all rows (this is a prospect TAL) and marked LIKELY until Gate 1 confirms.

## 3. Selection scoring (deterministic; run 2026-07-28 on all 157)
Formula (documented so anyone can recompute; scored fields come from the seed file itself):
- Demand-gen team rating **HIGH +3 / MEDIUM +2 / LOW +0** (the seed's own research verdicts, parsed from the rubric text)
- **Intent present +2** (Intent Topic not blank/"-" — i.e. B2B Marketing / Demand Generation surging)
- **Paid-media spend 2025: >=$1M +2, >=$300K +1**
- **Paid ads currently running +1**
- **US-listed public +1** (EDGAR 8-K coverage for acquisition/expansion triggers)
- **Size 501-1,000: -1; size unresearched: -2**
- Tie-break: spend desc, then name asc. Max score = 9.
Scoring artifact committed at `data\imports\2026-07-28-tal-scoring.csv` (all 157 rows with parsed fields + scores). Top 32 + G42 (criteria-based admission, section 2) went to discovery.
**Caveat (honesty):** the demand-gen ratings and spend figures are the TAL team's research, not independently verified — they rank candidates, they do not assert facts. Phase 2 team mapping re-verifies teams with evidence URLs per row.

## 4. Watchability admission (per-account discovery, 2026-07-28)
Every candidate went through the layered discovery waterfall (`scripts\discover-ats.ps1` + session layers 3-4; decision logged in BUILD-STATE):
1. **Site crawl** — homepage + careers pages, raw-HTML signature scan (catches ATS links embedded in scripts/iframes on JS-heavy sites); ALL Workday regional sites collected and tested, largest board = primary feed, rest recorded as secondary.
2. **Direct ATS API probes** — slug guesses tested straight against Greenhouse/Lever/Ashby/SmartRecruiters/Recruitee public APIs; a 200 with parsable jobs payload is definitive proof, no search engine involved.
3. **Web search operators** for stragglers and regional portals.
4. **Manual deep-dive** on anything still unresolved — no silent classification.
Custom-platform findings verified live this session: **amazon.jobs public search JSON** (200, hits=423 for AWS marketing, 100 rows/page, sort=recent) -> AWS is watchable as page_only with a JSON careers_url; **careers.microsoft.com** Phenom SPA captures thin (29KB shell) and its jobs API host serves a broken cert (*.azureedge.net mismatch) -> page_only with partial-coverage note; **careers.linkedin.com** serves 143KB capturable HTML but the job list itself is authwalled -> page_only, hiring triggers via weekly search cross-check.
**Known blind spot (recorded, not papered over):** roles posted ONLY to LinkedIn/job boards and never to the company's own surface are invisible to deterministic snapshots. Mitigation: the weekly per-account WebSearch cross-check recipe in `reference\trigger-sources.md`; every accounts.csv row's notes say which surfaces are watched.

## 5. Rebuild procedure (seed -> final 25) — status
1. ~~Load seed rows; KEEP/REPLACE + rationale per row~~ -> DONE via scoring + discovery; rationale in accounts.csv notes.
2. ~~Fill every accounts.csv column; per-account ATS discovery is part of admission~~ -> DONE (this session).
3. ~~validate-accounts.ps1 — zero violations~~ -> see BUILD-STATE test log for the run receipt.
4. Walking-skeleton picks: section 7.
5. First snapshot day: same-day (2026-07-28) — the daily habit starts here and never stops.

## 6. Seed corrections found during rebuild (evidence-based; report back to the TAL team)
- **LinkedIn** — seed says "Public Company"; absent from SEC's current ticker registry (Microsoft subsidiary since 2016). Ticker blank; EDGAR triggers ride parent MSFT.
- **NetSuite** — seed says "Public Company"; absent (Oracle subsidiary since 2016). Ticker blank; parent ORCL.
- **Red Hat** — seed says "Public Company"; absent (IBM subsidiary since 2019). Ticker blank; parent IBM.
- **SolarWinds** — seed says "Public Company"; absent from the current SEC registry (taken private 2025). Ticker blank. The committed scoring file keeps the seed's original label (reproducibility — the score is computed from the seed as received); this correction lives here and in accounts.csv notes. With the +1 removed it would rank 8 instead of 9 — still comfortably admitted.
- **AWS** — seed lists domain amazon.com; the SEC filer is parent Amazon.com Inc (AMZN). Account watches the AWS unit; EDGAR rides the parent.
- Six under-researched rows (section 0) were not auto-admissible; G42 admitted on explicit criteria (only non-US row; exercises the Gate-1 + Gate-3 hold rails in the skeleton).

## 7. Selection outcome + walking-skeleton picks — **v2, TRIGGER-HEAT RANKED (2026-07-28 night)**
_v1 (static-score top-24) was REPLACED the same evening on the user's directive: "the 25 accounts are the highest-intent ones - don't move on by just naming big logos." The v1 table below the v2 section is retained for the audit trail._

**v2 method (artifacts: `data\imports\2026-07-28-trigger-heat-ranking.csv` + `2026-07-28-marketing-role-counts.csv`):**
- Live discovery extended to the **top 100** scored seed rows (33 + 68 accounts swept; 54 structured feeds found and live-tested in total).
- For every account: **open marketing-family roles counted TODAY** from its live feed (title regex, samples kept as evidence). Method labeled per row: verified feed / page-approximation / unknown (JS shell - unknown is NEVER treated as zero, but unmeasurable accounts cannot outrank measured heat).
- **heat = hiring evidence (0-5, size-normalized: mid-size surge bonus, routine-giant damper) + intent flag (+2) + paid-spend tier (+2/+1) - size penalties.** Big-logo volume deliberately cannot auto-win.
- Workday pager bug caught during the run (CXS serves pages past the end -> 10x duplicate counts); fixed against the feed's own total and the 12 affected accounts recounted before any ranking was read.

**The heat-25 (see accounts.csv notes for per-row evidence):**
STAYED (12): Adobe (42 live mktg roles), Autodesk (17), AWS (15), SolarWinds (14), Braze (13), Okta (12), ServiceNow (8), SAP (~23 approx), Twilio (5), RingCentral (4), PayPal (5), Red Hat (4).
NEW (13): **Snowflake (29), Stripe (26), Thomson Reuters (21), Databricks (12), Datadog (11), Asana (10), insightsoftware (10), Samsara (8), Smartsheet (8), Alteryx (7), BlackLine (6), Bloomreach (4), Odoo (~6 approx)** - every feed live-verified on admission.
OUT (12 from v1): Microsoft, LinkedIn, Paycom, Akamai, Cisco, Workday, Qualtrics, Upwork, Cornerstone OnDemand, Avalara, Intuit, GoDaddy - out on measured-zero or unmeasurable hiring (JS-shell careers sites). They re-enter the moment browser/search measurement shows heat; "unknown" is recorded as unknown, not as zero-forever.
ANNEX row 26: G42 - watch-only skeleton rep (Gate-1 + Gate-3 holds), outside the heat ranking on purpose.
NetSuite (browser-checked per user instruction, via the AI Agent Chrome profile): Oracle's portal shows 86 keyword hits for "NetSuite marketing" - **all sales titles, zero marketing roles visible** -> no heat, stays out; browser watch-path documented.

**Walking-skeleton picks v2:**
1. Greenhouse rep: **braze** (13 live marketing roles - live trigger material)
2. page_only rep: **odoo** (own recruitment app, capturable page)
3. Multi-BU enterprise: **thomson-reuters** (legal/tax/news BUs; 21 live roles)
4. Legal-restricted region: **g42** (dual hold: Gate-3 UAE + Gate-1 active-prospect - play must stop at both gates)
5. Expected-quiet: **redhat** (4 roles at a 10k+ giant - proves honest "checked, no change")

## 7-v1 (superseded same day; audit trail)
**Admitted 25 = ranked top-24 by score (with one watchability replacement) + G42 (criteria admission).** validate-accounts.ps1: OK, 25 rows, zero violations (run receipt in BUILD-STATE).

| # | account | ats | jobs at admission | found by |
|---|---|---|---|---|
| 1 | aws | page_only (amazon.jobs search JSON) | 423 AWS-mktg hits | layer 3+4 |
| 2 | adobe | workday | 841 | layer 3 (search) |
| 3 | microsoft | page_only | shell capture | layer 3+4 |
| 4 | linkedin | greenhouse (hidden board) | 53 | layer 2 (probe) |
| 5 | autodesk | workday | 509 | layer 1 (crawl) |
| 6 | ringcentral | workday | 62 | layer 1 (crawl) |
| 7 | solarwinds | greenhouse | 91 | layer 2 (probe) |
| 8 | paypal | workday (site "jobs") | 162 | layer 3 (search) |
| 9 | paycom | page_only (own ATS) | 164KB page | layer 3+4 |
| 10 | okta | greenhouse | 361 | layer 2 (probe) |
| 11 | sap | page_only (SuccessFactors) | 124KB search page | layer 3+4 |
| 12 | akamai | page_only (Oracle HCM shell) | 11KB shell | layer 3+4 |
| 13 | twilio | greenhouse | 184 | layer 2 (probe) |
| 14 | cisco | page_only (custom) | 173KB job list | layer 3+4 |
| 15 | workday | workday (dogfood) | 344 | layer 1 (crawl) |
| 16 | braze | greenhouse | 232 | layer 2 (probe) |
| 17 | servicenow | smartrecruiters | 435 | layer 2 (probe) |
| 18 | qualtrics | greenhouse | 52 | layer 2 (probe) |
| 19 | redhat | workday (site "jobs") | 218 | layer 3 (search) |
| 20 | upwork | greenhouse | 10 | layer 2 (probe) |
| 21 | cornerstone-ondemand | page_only (own CSOD ATS) | 375KB page | layer 3+4 |
| 22 | avalara | page_only (iCIMS/Jibe) | 507KB page | layer 3+4 |
| 23 | intuit | page_only (own platform) | 546KB page | layer 3+4 |
| 24 | godaddy | greenhouse | 26 | layer 2 (probe) — REPLACEMENT for NetSuite |
| 25 | g42 | page_only | careers board 200 | criteria admission; WATCH-ONLY |

- **Replaced: NetSuite** (rank 24) — Oracle WAF returns 403 to every scripted careers fetch (2 URLs tested); no observable watch surface within rails (no bot-wall evasion, ever). GoDaddy (rank 25) admitted in its place. Swap back only if sales insists AND accepts a manual-only watch path.
- **Not admitted (spares, in rank order):** Xero, Indeed, Salesforce, Docusign, Taboola, Odoo, Dynatrace — discovery data for each sits in the discovery CSV; Taboola/Xero/GoDaddy-class swaps cost one validation + snapshot day.
- **Layer-2 vindication (why the waterfall exists):** 9 of 15 structured feeds were found by direct API probe — boards no page links to (LinkedIn's hidden greenhouse being the cleanest example). A homepage-only crawl would have missed them.

**Walking-skeleton picks (plan Phase 1 step 2; slots per v1.1):**
1. Greenhouse/Lever rep: **braze** (greenhouse, 232 jobs, marketing-tech ICP twin)
2. page_only rep: **paycom** (own-ATS page, server-rendered, clean capture)
3. Multi-BU enterprise: **intuit** (QuickBooks / Mailchimp / Credit Karma)
4. Legal-restricted region: **g42** (AE; exercises Gate-3 hold AND Gate-1 active-prospect hold — play walks to draft, stops at both gates, on purpose)
5. Expected-no-signal: **upwork** (10-job board; proves honest "checked, no change" reporting)

## 8. Sign-off
- Criteria confirmed by: **UNSET — sales leadership (ask #4)** — date: UNSET
- Rebuilt list reviewed by: **UNSET — user** — date: UNSET
- Prepared by: Claude (trigger-system session), 2026-07-28, on the plan's proceed-on-seed rule; every row LIKELY until the two lines above are signed.
- **Open question for sales (explicit):** the top of the ranking is heavy with mega-caps (AWS, Adobe, Microsoft, SAP, Cisco, Salesforce, Intuit, PayPal...). The seed's own data put them there (biggest teams, biggest spend, intent present). If sales judges mega-caps unwinnable for Unbound's motion, say so — ranked replacements 26-35 are ready in the scoring file and a swap costs one validation + snapshot day, nothing else.
