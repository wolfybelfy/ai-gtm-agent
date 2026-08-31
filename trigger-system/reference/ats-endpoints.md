# ATS public job-board endpoints — verification record + fetcher contract
_All "VERIFIED" rows were fetched live on **2026-07-28** from this machine and returned HTTP 200 with the exact shape described. Anything not fetched this session is labeled HYPOTHESIS and must be verified against the first real account that uses it (CLAUDE.md rule 6: no URLs from memory ship unverified)._

`snapshot.ps1` consumes this contract. Job identity key for diffing is per-ATS (`diff.ps1` uses it).

## Greenhouse — VERIFIED 2026-07-28
- **Endpoint:** `GET https://boards-api.greenhouse.io/v1/boards/{board_token}/jobs`
- **Tested against:** `stripe` → 200, `{"jobs":[...]}`, **534 jobs** (snapshot.ps1 smoke run; an earlier WebFetch preview undercounted at 300 — script counts are authoritative).
- **Shape:** `jobs[]` with `id`, `internal_job_id`, `title`, `company_name`, `absolute_url`, `location.name`, `updated_at`, `first_published`, `requisition_id`, `language`, `metadata`.
- **Job key:** `id`. **Count:** `jobs.Length`.
- **Descriptions:** NOT included by default. `?content=true` adds them — snapshot deliberately does NOT use it (JD semantic reading fetches the single job's `absolute_url` on demand during daily-watch; keeps snapshots small).
- **Discovery:** careers page links to `boards.greenhouse.io/{token}` or `job-boards.greenhouse.io/{token}`; the token is the last path segment.

## Lever — VERIFIED 2026-07-28
- **Endpoint:** `GET https://api.lever.co/v0/postings/{site}?mode=json`
- **Tested against:** `spotify` → 200, JSON **array**, **106 postings** (snapshot.ps1 smoke run; the WebFetch preview undercounted at 11).
- **Shape:** array of `id`, `text` (title), `categories{commitment, department, location, team, allLocations}`, `createdAt` (epoch ms), `country`, `workplaceType`, `hostedUrl`, `applyUrl`, plus full description fields (`description*`, `lists`, `additional*`).
- **Job key:** `id`. **Count:** array length.
- **Note:** descriptions ARE embedded (no way to omit) — responses grow with board size; acceptable, see size note below.
- **Discovery:** careers page links to `jobs.lever.co/{site}`.

## Ashby — VERIFIED 2026-07-28
- **Endpoint:** `GET https://api.ashbyhq.com/posting-api/job-board/{board}`
- **Tested against:** `linear` → 200, `{"jobs":[...]}`, 8 jobs. (`openai` also responded but the payload exceeded 10 MB — proof the endpoint is live AND that Ashby embeds full `descriptionHtml`/`descriptionPlain` per job. snapshot.ps1 handles large bodies fine locally.)
- **Shape:** `jobs[]` with `id`, `title`, `department`, `team`, `employmentType`, `location`, `secondaryLocations`, `publishedAt`, `isListed`, `isRemote`, `workplaceType`, `address.postalAddress`, `jobUrl`, `applyUrl`, `descriptionHtml`, `descriptionPlain`.
- **Job key:** `id`. **Count:** `jobs.Length`.
- **Discovery:** careers page links to `jobs.ashbyhq.com/{board}`.

## SmartRecruiters — VERIFIED 2026-07-28
- **Endpoint:** `GET https://api.smartrecruiters.com/v1/companies/{companyIdentifier}/postings` (paged: `?limit=100&offset=N`)
- **Tested against:** `smartrecruiters` → 200, `{offset, limit, totalFound, content:[...]}`, totalFound 8.
- **Shape:** `content[]` with `id`, `name` (title), `uuid`, `refNumber`, `company{identifier,name}`, `releasedDate`, `location{city, region, country, remote, fullLocation}`, `industry`, `department`, `function`, `typeOfEmployment`, `experienceLevel`.
- **Job key:** `id`. **Count:** `totalFound` (fetcher pages until `content` accumulated == totalFound or safety cap 10 pages).

## Workday — VERIFIED 2026-07-28 (local POST test)
- **Pattern:** `POST https://{tenant}.wd{N}.myworkdayjobs.com/wday/cxs/{tenant}/{site}/jobs` with JSON body `{"limit":20,"offset":0,"searchText":""}` → `{total, jobPostings:[...]}`.
- **Tested against:** tenant `nvidia`, site `NVIDIAExternalCareerSite` → 200, `total=2000`, posting fields exactly: `bulletFields`, `externalPath`, `locationsText`, `postedOn`, `title`.
- **Job key:** `externalPath`. **Caveats:** `postedOn` is RELATIVE text ("Posted Today") — never parse it; days_open comes from our own first-seen ledger. Huge boards hit the paging cap (MaxPages) — the manifest note says so explicitly, and per-account discovery should point `ats_feed_url` at the most specific site (a regional/BU site beats the global one).
- **Discovery:** careers page redirects to `{tenant}.wd{N}.myworkdayjobs.com/{site}`; the CXS URL is derived from tenant + site.

## Recruitee — HYPOTHESIS (NOT verified; test attempt on a stale company 404'd)
- **Pattern:** `GET https://{company}.recruitee.com/api/offers/` → `{offers:[...]}`.
- Verify against the first real account on Recruitee before trusting; until then classify such an account `page_only` or `manual_review`.

## page_only
- Raw HTML `GET` of `careers_url`, stored verbatim. Coverage state is at best `partial` (unstructured); daily-watch reads it semantically. JS-rendered career sites may capture little — that is a finding to record per-account in Phase 1 discovery (`notes` column), not to paper over.

## Fetcher rules (all ATS types)
1. 2-second politeness delay between accounts; one fetch per account per day; honest User-Agent `trigger-system-snapshot/1.0`.
2. TLS 1.2 forced (PowerShell 5.1 default can be older).
3. Raw response stored **verbatim** (tamper-evidence — CLAUDE.md data classes); `sha256` of raw bytes in the manifest.
4. Atomic writes: temp file + rename. No partial snapshot ever bears a final name.
5. Every manifest row carries a coverage state: `checked_unchanged | checked_changed | partial | source_unavailable | parse_failure | manual_review` — set `checked_*` only after diff.ps1 runs; snapshot itself records `fetched_ok` facts (http_status, bytes, job_count) and `source_unavailable`/`parse_failure` on failure.
6. Size note: Ashby/Lever embed descriptions; multi-MB days are possible. Git delta-compresses near-identical dailies well. Tripwire: if `data\snapshots\` pack size exceeds ~500 MB, revisit storage (log a BUILD-STATE decision; options: strip description bodies to per-job hashes, or move raw bodies out of git). Do NOT pre-optimize before the tripwire fires.

## ats_type enum (decision 2026-07-28, logged in BUILD-STATE)
Plan Part D listed `greenhouse|lever|workday|page_only|none` illustratively. Widened to
`greenhouse | lever | ashby | smartrecruiters | recruitee | workday | page_only | none`
because Ashby/SmartRecruiters are common in the segment and both verified live today. `none` still requires a stated reason in `notes` (no silent blanks). `validate-accounts.ps1` enforces this enum.
