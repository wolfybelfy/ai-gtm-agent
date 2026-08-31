# ZoomInfo API playbook — RE-ADOPTED 2026-08-20 (user order, supersedes the same-day removal)

_History, honestly: ZoomInfo was removed from this system earlier on 2026-08-20 by user order
(commit c494453; Q11 CLOSED). Later the same day the user ordered it back: "do accurate
uptodate research and set up zoominfo for this system, so that it works in automated way."
This file is that setup. The standing rule "never re-adopt without a new explicit user
decision" is satisfied by that order — this paragraph is its dated record. A prior version of
this file (commit b28b849, parallel session) was deleted in the removal; this version was
re-researched from scratch — every fact below was fetched live from docs.zoominfo.com on
2026-08-20 THIS session, or is marked [GAP]._

## The API surface (all fetched 2026-08-20)

### Auth — OAuth2 client credentials (https://docs.zoominfo.com/docs/client-credentials-flow)
- `POST https://api.zoominfo.com/gtm/oauth/v1/token`
- Headers: `Authorization: Basic base64(client_id:client_secret)` (doc-recommended),
  `Content-Type: application/x-www-form-urlencoded`, `Accept: application/json`
- Body: `grant_type=client_credentials` (optional `scope`, space-delimited; omitted = all
  configured scopes)
- Response carries `access_token` + `expires_in` (seconds). Request a fresh token per run;
  no refresh-token flow documented.

### Search Contacts — FREE (https://docs.zoominfo.com/reference/searchinterface_searchcontact)
- `POST https://api.zoominfo.com/gtm/data/v1/contacts/search`
- Filters include `companyId` / `companyName` / `companyWebsite`, `jobTitle` /
  `exactJobTitle`, `managementLevel`, `department`, location fields.
- Returns names, titles, company, `contactAccuracyScore` (75–99) and HINTS
  (`hasEmail`, `hasDirectPhone`, `hasMobilePhone`) — doc-verbatim: it "does not return
  emails, phone numbers, or any other data that can be used to engage".
- Doc-verbatim cost: "This endpoint does not consume any credits nor do contacts returned
  count towards record limits." Pagination `page[number]` / `page[size]` (1–100, default 25).

### Enrich Contacts — 1 credit per MATCHED returned record (https://docs.zoominfo.com/reference/enrichinterface_enrichcontact)
- `POST https://api.zoominfo.com/gtm/data/v1/contacts/enrich`
- Up to 25 records per request via `matchPersonInput` array (fields incl. `personId`,
  `firstName`, `lastName`, `companyName`, `companyId`, `jobTitle`, `emailAddress`,
  `contactAccuracyScoreMin`).
- `outputFields` (required array) — we request: id, firstName, lastName, email, jobTitle,
  companyName, contactAccuracyScore, hasCanadianEmail, validDate.
- **`requiredFields` is the cost guard** — doc-verbatim mechanism: a contact missing a
  required field is not returned; and "If we fail to find the record and return 'No match'
  or if we return an error code a credit will not be charged." So `requiredFields:["email"]`
  = we are never charged for a contact ZoomInfo has no email for.
- `hasCanadianEmail` in the response = our Gate-3/CASL tripwire (flag, never auto-clear).
- Rate limits not published; HTTP 429 supported — honor Retry-After, stop on repeat.

### Credentials (https://docs.zoominfo.com/docs/standard-app)
- Created as a "Standard App": Enterprise → ZoomInfo **Developer Portal → Create App**;
  GTM.ai self-serve → **Developer tab → Create**. Issues **Client ID + Client Secret**.
- Doc-verbatim requirement: "a GTM.ai or Enterprise license with API access".
- [GAP: whether OUR package includes API access, and whether Developer Portal access works
  while the account lock stands — only the user's portal can answer. See setup step 0/1.]

## Our wiring (built 2026-08-20, runs automatically once credentials exist)

- Secrets: `ZOOMINFO_CLIENT_ID` + `ZOOMINFO_CLIENT_SECRET` user env vars (rule 3 — user
  creates and sets them; never in files; Claude never sees the literals).
- `scripts\zoominfo-enrich.ps1` — the deterministic verified-email step:
  - Scope: a play's `buying-group.csv` rows that have a BLANK email and NO hold (Gate-3
    holds, bench holds and non-US rows are skipped mechanically; both buying-group schema
    generations handled).
  - Suppression re-checked per person before any write (rule 8).
  - Enrich call carries `requiredFields:["email"]` + accuracy floor (default 85); matched
    results below the floor or with `hasCanadianEmail=true` are written as REVIEW-flagged,
    never as clean.
  - Hard credit cap per run (`-MaxCredits`, default 10); dry-run by default; `-Execute`
    spends. Every result lands in `staging\enrich\enrich-results.csv` (provider `zoominfo`)
    and the play's buying-group; a [SYSTEM] alert summarizes spend + outcomes.
  - Stop-on-anomaly: unexpected response shape / 4xx / repeated 429 → stop, queue alert,
    raw response saved for attended review.
- Monday chain: **stage 2c** (after the stage-2b play build) runs
  `zoominfo-enrich.ps1 -Auto -Execute` over the plays in today's
  `staging\play-queue\<date>.csv`. Credentials are captured pre-strip and restored ONLY for
  this stage (rule-7 posture: the web-reading stage 2 never holds them); missing credentials
  = logged WARN skip, never a run failure — the automation self-activates the first Monday
  after the env vars exist.

## User-side setup (in order; system is already wired and waits on these)
0. Confirm the ZoomInfo ACCOUNT is unlocked (it has been locked at ZoomInfo since before
   2026-07-28; every API call 401s until this is resolved with ZoomInfo).
1. Confirm the package includes API access ("GTM.ai or Enterprise license with API access");
   if unsure, ask your ZoomInfo admin/CSM.
2. Create the Standard App (Developer Portal → Create App) → copy Client ID + Secret.
3. In your own terminal: `setx ZOOMINFO_CLIENT_ID "<id>"` and
   `setx ZOOMINFO_CLIENT_SECRET "<secret>"`, then open a fresh session.
4. Tell the system to run the verification ladder (attended): token test → one free search
   → ONE 1-credit enrich with declared spend → then the caps govern routine runs.

## Division of labour (Clay REMOVED entirely 2026-08-24, user order — ZoomInfo is the SOLE provider)
ZoomInfo contact search = free per-person verify + roster hints (verdict-gated, never a
mapping-run tool per `config\enrichment-policy.md`); ZoomInfo enrich = THE verified-email
step, verdict-gated, capped, suppression-checked. There is no parallel enrichment path.
Breadth mapping (rosters, org spines) runs on free public sources only; historical Clay-era
roster pulls survive read-only in `staging\enrich\people-*.csv`.
