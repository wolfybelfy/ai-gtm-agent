# Implementation Plan — Trigger-to-Meeting System
**v1.1 (2026-07-27) — revised after external (ChatGPT) review; disposition of every review point in Part I. Top-to-bottom consistency verification passed 2026-07-27 (five wording/cross-reference patches applied; no structural changes).**
**v1.2 (2026-07-27) — Slack removed entirely (user decision: the company is not on Slack). All alerting moves to Outlook email — mechanism live-verified this session (Part B "Alert channel"). Execution roadmap added (Part J).**

## Context

The trigger-based outbound strategy (`data/reports/2026-07-26-trigger-outbound-meeting-system.md`, approved) now gets built — "step by step, ordered, foundation first, no assumptions, no shortcuts." The company removed Clay over bad data (it remains usable until a sunset date TBD), the user's HubSpot access level is unknown, and the TAL list the user holds is a seed needing rebuild. The build spans ~6 weeks and many sessions, so the plan is engineered around two hard requirements: (1) access-blocked work never blocks free-layer work, and (2) any fresh session can resume from disk alone.

Optimization order (user-mandated): correctness > preservation of existing behavior > simplicity > maintainability > delivery speed.

**Research basis (this session):** strategy doc + TradeStation dry run read in full; project inventory (no git repo, no scripts/config/env anywhere; `engine/` is legacy — never read/reused); Claude Code mechanics verified against live docs (headless flags, skills, PreToolUse hooks, .mcp.json); third-party facts live-verified with fetched official pages (HubSpot scopes + super-admin rule + official MCP server; Clay's official Claude Code plugin + plan gating; Slack webhook rules — superseded, Slack removed in v1.2; Greenhouse/Lever/EDGAR feeds fetched live and returning data). v1.1 additionally incorporates the critical findings of an external review (Part I). v1.2 adds the Outlook alert-channel facts, live-verified 2026-07-27 (Part B "Alert channel").

## Evidence classification (labels used throughout)
- **VERIFIED** — directly checked this session (file read / live fetch by me or a research agent that fetched the page)
- **LIKELY** — strong indirect evidence
- **UNKNOWN** — cannot verify from here
- **BLOCKING QUESTION** — company/user must answer; logged in BUILD-STATE.md with owner + date

## User-confirmed facts (asked this session)
- **Clay:** cancelled but usable "until some time" → build WITH Clay now; contact-lookup designed provider-agnostic so ZoomInfo + HubSpot + Claude Code take over at sunset with zero schema change. Ask list includes: confirm exact end date.
- **HubSpot:** user's own access level unknown → finding out is ask item #1.
- **TAL:** user HAS a 25-account list but rates it "not that good" → it is a SEED. Phase 1 includes rebuilding the TAL against explicit criteria before team mapping locks in.
- **Runtime host:** this Windows PC, on daily → Task Scheduler + headless Claude Code at the automation phase (last).

---

## PART A — THE ASK LIST (send day 0; blockers first)

1. **HubSpot API access** [mechanics VERIFIED] — Private apps work (filed under "Legacy apps") and require a **super admin** to create. Ask a super admin to create a Private App and hand over the token with exactly: `crm.objects.contacts.read/write`, `crm.objects.companies.read/write`, `crm.objects.deals.read` (won/lost export for the week-2 backtest), `crm.schemas.companies.write`, `crm.schemas.contacts.write` (custom properties). Tasks/Notes APIs ride on contacts scopes (VERIFIED — no separate task scope). Fallback path if token refused: HubSpot's official **remote MCP server, mcp.hubspot.com** (GA, OAuth, respects user's own permissions). Also ask: (a) user's seat + permission level, (b) does the portal have **Sales Hub Pro/Enterprise + a Sales seat** (what Sequences requires — VERIFIED), (c) export permission for closed-won/lost/disqualified/stalled deals, (d) **a RevOps/admin contact for the pre-write workflow audit** (Phase 4 — v1.1), (e) whether the portal is Enterprise (custom objects available — decides whether the optional custom-object upgrade to the Part-B play-record model is on the table; the notes+tasks model works on any tier regardless). Pin the HubSpot API version at integration time [review-flagged, LIKELY: date-based API versions exist since Mar 2026 — confirm at build].
2. **Clay (time-boxed)** — Ask: (a) exact sunset date, (b) seat until then, (c) whether the workspace plan supports webhook-import + HubSpot export (current plans gate these at Growth+; grandfathered Explorer/Pro qualify — VERIFIED), (d) monthly credit cap set day 0. Install path is Clay's official plugin (VERIFIED on official repo): `/plugin marketplace add clay-run/agent-plugins` → `/plugin install clay@clay-plugins` → `clay login`. **v1.1: Clay results feed nothing until it passes the ground-truth benchmark (Phase 4) — the company removed Clay for bad data; mechanics tests don't clear that bar, accuracy tests do.**
3. **Alerts — Outlook email (v1.2, replaces Slack; the company is not on Slack).** Needs nothing from anyone on day 0: classic Outlook is installed on THIS PC (VERIFIED 2026-07-27 — `Office16\OUTLOOK.EXE` present, COM ProgID `Outlook.Application.16` registered) and the mailer sends from the user's own signed-in mailbox with **zero stored credentials**. Phase 0 smoke test confirms the two remaining UNKNOWNs: (a) the classic-Outlook profile on this PC is signed into the work mailbox, (b) a scripted test-send-to-self goes out without an Object Model Guard prompt (prompt-free requires Windows Security Center reporting antivirus "Good" and no restrictive Group Policy — VERIFIED, Microsoft docs fetched this session). ONLY if that test fails: ask IT for a Microsoft Graph app registration with delegated `Mail.Send` (VERIFIED fallback — sends as the signed-in user). Recipient list starts as the user alone; SDR + backup added when Gate 4 names them (config\alert-recipients.csv).
4. **TAL criteria** — sales leadership's view of the real top-25 + the criteria they'd use (user's seed list + these criteria → Phase 1 rebuild).
5. **Gate 1 — conflict rules** signed by sales leadership: named untouchable-competitor-team list. Blocks sends, never builds.
6. **Gate 2 — sending infra**: HubSpot Sequences (if tier supports, item 1b) vs SmartLead/Instantly-class; **buy 2–3 secondary domains DAY 0** (lead time is real either way). **v1.1: "warmed for 2–3 weeks" is no longer the readiness test — sending starts only when the deliverability gate passes (Part C, Phase 5 entry): SPF/DKIM/DMARC configured and verified, seed-list test across major mailbox providers, bounce/complaint thresholds + ramp policy + emergency-pause rule agreed.**
7. **Gate 3 — lawful basis, per country AND channel (v1.1 upgrade):** the deliverable is a small decision matrix — country × channel (email/call/LinkedIn/tracking) × recipient type → allowed/conditions/unsubscribe requirements — for the countries actually targeted in the pilot, owned by legal/privacy (their document, not ours to invent). Blocks the first send into each country, never builds. The TradeStation Europe strike depends on the NL/EEA rows.
8. **Gate 4 — named SDR queue owner + backup (v1.1: backup added)**: accepts STRIKE tasks in 24h, owns the fast-reply clock; backup covers absence so alerts never land in an empty room.
9. **Baseline metric** — current outbound reply rate (the ≥3× pilot bar needs it).
10. **Two 45-min interviews** (week 1): account directors — pre-signing patterns of last three clients + "name every past champion we'd want to follow."
11. **ZoomInfo** — confirm live; API key pinnable inside Clay while Clay lasts, used directly after.
12. **Free layer needs nothing from anyone** [VERIFIED live]: Greenhouse `boards-api.greenhouse.io/v1/boards/{token}/jobs`, Lever `api.lever.co/v0/postings/{org}?mode=json`, SEC EDGAR full-text + Atom (declared User-Agent mandatory, ≤10 req/s) — all fetched this session, returning real data. Coverage caveat (review-accepted): these cover *published* data on *some* accounts; per-account coverage is measured in Phase 1 and recorded, never assumed.

---

## PART B — ARCHITECTURE

### New top-level folder: `trigger-system\` (descriptive > clever for context-loss; avoids legacy "engine")

```
trigger-system\
├─ CLAUDE.md                  # operating rules; first read of ANY session
├─ BUILD-STATE.md             # phase/state tracker; second read
├─ PHASES.md                  # static copy of Part C incl. acceptance criteria
├─ reference\                 # verbatim strategy copy + backtest memo + interview notes + golden-set\
├─ config\                    # accounts.csv · trigger-weights.yaml · scoring-rules.md · conflict-list.csv ·
│                             # gates.md · capacity-rules.md (v1.1) · alert-recipients.csv (v1.2)
├─ context\                   # copy pack: offer.md · icp-pains-by-trigger.md · copy-rules.md
├─ data\                      # teams.csv · triggers.jsonl · fired-log.csv · event-calendar.csv ·
│                             # watch-calendar.csv · past-champions.csv · metrics-weekly.csv · snapshots\YYYY-MM-DD\
├─ briefs\YYYY-MM-DD.md       # daily human surface (arithmetic + per-account coverage state shown)
├─ plays\index.csv + YYYY-MM-DD-<account>-<team>\{brief.md, buying-group.csv, emails.md, status.md}
├─ staging\                   # the file IS the interface (Part D)
│  ├─ hubspot\{closed-won,closed-lost,suppression}.csv + outbox\*.jsonl
│  ├─ clay\enrich-requests.csv + enrich-results.csv
│  └─ alerts\*.md + sent\     # v1.2 (replaces slack\): alert files, moved to sent\ with a receipt line on send
├─ runbooks\                  # daily-watch.md · strike-build.md · weekly-review.md · backtest.md · session-close.md
│                             # (+ reply-classification.md, written in Phase 4 — six total once the pilot runs)
├─ scripts\                   # snapshot.ps1 · diff.ps1 (start minimal; grow when correctness demands — v1.1)
└─ logs\run-log.md            # append-only session/run journal (records model + config version per run — v1.1)
```

### Key schemas (the contract — exact columns)

- **config\accounts.csv**: `account_id, account_name, domain, ticker, region, ats_type(greenhouse|lever|workday|page_only|none), ats_feed_url, careers_url, newsroom_url, is_client, client_note, sec_edgar, added_date, notes` — `none` requires a stated reason; no silent blanks.
- **data\teams.csv**: `team_id, account_id, team_name, bu_or_brand, region, leader_name, leader_title, leader_linkedin_url, leader_start_date, leader_start_confidence(VERIFIED|LIKELY|UNKNOWN), size_estimate, relationship_flag(existing_client|past_client|sibling_of_client|none), icp_flag, confidence(HIGH|MED|LOW), status(active|parked|not_scoreable), evidence_urls, last_verified, notes` — `not_scoreable` encodes "no attributed leader → no scoring" (dry-run Rule 1).
- **data\triggers.jsonl** (JSONL because verbatim JD quotes contain commas/newlines): one object per line with `trigger_id, detected_date, team_id, account_id, trigger_type, tier, evidence_url, evidence_url_2, source_class(primary|secondary), independence_note, verbatim_quote, source_method, window_open, window_close, in_window, dedup_key, status(new|scored|expired|discarded|superseded), superseded_by, reopened_date, discard_reason, notes`.
  **Evidence rules (v1.1, replaces bare two-source rule):** ONE primary source (SEC filing, the company's own newsroom/careers/leadership page) suffices alone; two secondary sources count only if independent — two outlets echoing one press release are ONE source (`independence_note` says why they're independent). Facts are stated as facts; inferences are written as hypotheses; negative evidence ("no marketing roles posted") always carries its coverage limitation — exactly as the TradeStation dry run already phrased it.
- **data\fired-log.csv** (dedup index): `dedup_key(team_id|trigger_type|window_open_anchor), trigger_id, first_fired, last_seen, times_seen, status` — checked before every append; nothing fires twice on unchanged evidence. A trigger MAY legitimately reopen on a material change (new window anchor → new dedup_key; old row marked superseded_by) — reopen is a recorded judgment call, never an automatic re-fire.
- **data\event-calendar.csv**: window computed as `start_date − 98d … start_date − 56d` (Tier B: 8–14 weeks pre-event).
- **data\watch-calendar.csv**: `reminder_id, team_id, account_id, recheck_date, retrigger_condition, source_trigger_id, created_date, status, outcome`.
- **staging\hubspot\outbox\*.jsonl** — **v1.1 REDESIGN (one record per play, never mutable company state):** `{"object":"note_per_play|task","play_id":"...","match_key":"domain|id","note_body_md":"<the full play: tier, triggers, why-now, evidence URLs, window — immutable once applied>","task":{...due, owner...},"company_summary_props":{"ts_last_tier","ts_last_window_close","ts_suppression_until"},"idempotency_key":"play_id","created","applied_date","applied_by","response_ref"}`. Rationale: one company can hold multiple simultaneous team plays (the ServiceNow example the strategy is built on); company-level tier/why_now properties would overwrite each other. Play history lives in immutable notes + tasks (works on ANY HubSpot tier); company properties carry only a `ts_`-namespaced current summary; an Enterprise custom object is an optional upgrade if item 1e says yes AND RevOps approves.
- **staging\clay\enrich-requests.csv → enrich-results.csv**: results add `email, email_verified, phone, provider_or_method(manual|clay|zoominfo), resolved_date` — the provider column IS the Clay-sunset swap point.
- **staging\alerts\*.md (v1.2, replaces Slack):** filename `YYYY-MM-DD-HHmm-<type>-<slug>.md`; four-line header `TYPE(DIGEST|STRIKE|HOT-REPLY|ESCALATION|SYSTEM)` / `SUBJECT` (prefixed `[DIGEST]` `[STRIKE]` `[HOT REPLY]` `[ESCALATION]` `[SYSTEM]`) / `TO(<list_name>)` / `STATUS(pending|sent)`, then a markdown body; on send the file moves to `sent\` with a `SENT: <utc> BY: <human|com-mailer|graph-mailer>` receipt line. **config\alert-recipients.csv**: `list_name, address, person, role, added_date` — internal team addresses ONLY, git-committed so every recipient change is a reviewed diff. The alert file never carries a raw address; the mailer refuses any `list_name` absent from the config — that allowlist is what keeps the mailer structurally unable to email a prospect (Part E-1).
- **plays\index.csv**: `play_id, team_id, tier(STRIKE|SEQUENCE), trigger_ids, created, status(building|ready|approved|sent|replied|meeting|killed|expired), acknowledged_by, acknowledged_at, approved_by, approved_date, sent_date, config_version, notes` — v1.1: ack fields (the alert email is a doorbell — this file + the HubSpot task are the source of truth) and `config_version` (git short-hash of config\ + model name at build time, so results can later be tied to the system version that produced them).
- **config\trigger-weights.yaml**: every strategy-§2 trigger with `tier, window{open,close}, weight(hypothesis), detect[], backtest_status(untested→won_only|everywhere|nowhere|insufficient_data), kill_status(active|halved|killed), min_exposure_sends(v1.1 — kill/halve decisions require at least this many delivered sends; below it the verdict is "insufficient data", never "dead")`.
- **config\capacity-rules.md (v1.1, new):** max 5 STRIKE reviews per SDR per business day; STRIKE unacknowledged 24h → [ESCALATION] email + BUILD-STATE; play older than 3 business days at `ready` → back to `building` for evidence/contact revalidation; excess plays are RANKED (window-close ascending), never silently queued; queue length reported in every daily brief. Numbers start as defaults and get corrected by the walking skeleton's measured minutes-per-stage.

### Alert channel — Outlook email (v1.2, replaces Slack; all facts live-verified 2026-07-27)
- **Primary mechanism: Outlook COM automation via classic Outlook** (`alert-mailer.ps1`, Phase 4). VERIFIED on this PC: `C:\Program Files\Microsoft Office\Root\Office16\OUTLOOK.EXE` exists, COM ProgID `Outlook.Application.16` registered (new Outlook 1.2026.213.100 is ALSO installed, but is irrelevant to COM). Zero stored credentials — mail goes out through the user's own signed-in profile. Known constraints, all VERIFIED against Microsoft docs fetched this session: (1) new Outlook has NO COM support — if this PC is ever force-migrated off classic Outlook, the mailer flips to Graph (tripwire logged in BUILD-STATE); (2) the Object Model Guard allows prompt-free programmatic send only while Windows Security Center reports antivirus "Good" and no restrictive Group Policy applies — proven or disproven by the Phase 0 send-to-self smoke test, never assumed; (3) Outlook COM is unsupported unattended/as a service — Phase 6 scheduled tasks therefore run "only when user is logged on" (consistent with the existing no-sleep policy), and if the 10-run soak shows flaky sends, the mailer flips to Graph.
- **Fallback: Microsoft Graph `sendMail`** — delegated `Mail.Send` sends as the signed-in user; application `Mail.Send` (admin consent) sends unattended [VERIFIED, Microsoft Learn fetched]. Requires an IT app registration → becomes an ask-list item ONLY if the COM smoke test fails. Token would live in Credential Manager, held only by the mailer invocation.
- **Excluded: SMTP AUTH / `Send-MailMessage`** — storing a mailbox password violates the secrets rail outright; Microsoft is also retiring SMTP AUTH basic auth (disabled by default for existing tenants end of Dec 2026 — corroborated across multiple live sources this session). Never used, no revisit.
- **Interim (works day 0, before Phase 4 automates anything):** the brief and alert files are generated on this PC — the user reads them directly and forwards anything actionable by email. Second doorbell at no build cost: HubSpot task assignment natively emails the task owner [LIKELY — verify when HubSpot access lands]; sequencer reply notifications cover [HOT REPLY] [LIKELY — verify at Gate 2 selection].

### Deterministic vs LLM split
- **Scripts (PowerShell 5.1, zero installs — start with two: snapshot.ps1, diff.ps1):** `snapshot.ps1` fetches each feed → raw JSON under `snapshots\DATE\ats\` + `manifest.csv` receipt (account, url, http_status, bytes, job_count, sha256, fetched_utc, run_id). **v1.1:** writes are atomic (temp file + rename); every record carries `run_id`; and the manifest yields a per-account **coverage state** — `checked_unchanged | checked_changed | partial | source_unavailable | parse_failure | manual_review` — because "nothing changed" and "couldn't look" must NEVER produce the same output. `diff.ps1` diffs latest two days by job ID → new/removed/days_open/stale_60d/reposted; **a removed job is an event to interpret (filled? pulled? moved ATS?), never auto-classified as a closed window** (v1.1). The old "exactly two scripts, <100 lines" cap is removed as dogma — the bias toward a minimal deterministic layer stays, but correctness requirements (atomicity, coverage states) outrank line counts.
- **Claude (via runbooks):** semantic JD reading with verbatim quotes, news/EDGAR sweep under the v1.1 evidence rules, trigger→team attribution, scoring per decision table (brief SHOWS the arithmetic), why-now narratives, copy, weekly review.
- **Why PowerShell:** native, zero-install, primary shell of the machine. Python 3.14 is VERIFIED present on this machine — noted as the escalation path (e.g., SQLite) if the tripwire in Part G-3 ever fires.

---

## PART C — PHASES (each: entry → steps → acceptance → NOT built)

### Phase 0 — Scaffold + fire the asks (strategy Week 0; ~half a day; zero access needed)
- **Steps:** create full tree; write CLAUDE.md / BUILD-STATE.md / PHASES.md; all schema files header-only; encode strategy §2/§3 into trigger-weights.yaml + scoring-rules.md; write capacity-rules.md defaults; copy strategy verbatim into reference\; write the five runbooks; `git init` inside trigger-system\ + first commit (with the v1.1 .gitignore — Part F); log every Part-A ask + gate in BUILD-STATE with owner/date (domains ask flagged URGENT); smoke-test whatever access already exists — Clay plugin install + `clay login` now (Clay is alive today), and the **Outlook COM mailer test (user present): scripted send-to-self from the signed-in profile; record in BUILD-STATE (a) work-mailbox yes/no, (b) prompt-free yes/no — a failure fires the Graph ask (Part A-3), it never blocks the phase**; write config\alert-recipients.csv with the user's address as the first row. Optional rail: `.claude/settings.json` PreToolUse hook blocking send-shaped commands. Write kickoff project memory.
- **Acceptance:** fresh-session test passes — a new Claude session given only "read trigger-system\CLAUDE.md and continue" correctly states phase, next 3 actions, open blockers. Every §2 trigger present in yaml with tier + window (diff names against strategy tables).
- **NOT built:** no scripts run in anger, no accounts, no teams, no outreach content.

### Phase 1 — TAL rebuild + Day-1 snapshots + WALKING SKELETON (Week 1, first half)
- **Entry:** user's seed list (in hand) + criteria from ask #4 (proceed on seed if criteria lag; mark rebuilt rows `LIKELY` until sales confirms).
- **Steps:**
  1. Define selection criteria; rebuild the 25 from seed; populate accounts.csv incl. per-account ATS discovery; build + run snapshot.ps1; **daily snapshot habit starts here and never stops** (most time-sensitive asset in the whole build — this is why TAL work is NOT resequenced behind the skeleton).
  2. **Walking skeleton (v1.1, review-adopted):** pick 5 representative accounts (one Greenhouse/Lever, one page-only, one multi-BU enterprise, one legal-restricted region, one expected-no-signal) and run the FULL path manually in week 1: source → trigger → evidence → team → recipients → draft → human approval → HubSpot outbox (applied by hand in UI) → simulated send (real send only if gates + deliverability allow, else the copy-into-sequencer step is walked through and stopped) → reply-handling walkthrough → outcome attribution. **Record minutes per stage** — these numbers replace the guessed capacity defaults.
- **Acceptance:** 25 accounts with rationale; 100% have a working feed or explicit classification + manual path + coverage state; ≥1 snapshot day committed; run-log started; **skeleton: one complete, auditable play lifecycle exists on disk + in HubSpot (via outbox), with measured labor per stage written into capacity-rules.md.** Any structural surprise the skeleton exposes (CRM can't represent the play, approval bottleneck, telemetry unusable) is fixed BEFORE Phase 2 scales the mapping.
- **NOT built:** no diff.ps1 (needs 2 days of history), no full team mapping yet, no volume.

### Phase 2 — Team mapping + calendars + interviews (Week 1)
- **Entry:** Phase 1 accepted (incl. skeleton learnings applied); interviews scheduled. ZoomInfo helpful, NOT required.
- **Steps:** map teams per strategy §1 into teams.csv with per-row confidence + evidence; tag client-relationship teams; event-calendar.csv for rolling 6 months; run both interviews → past-champions.csv + candidate triggers appended to yaml as `untested`.
- **Acceptance:** the strategy's checkpoint, v1.1-sharpened: **25 accounts → ≥75 teams, counting ONLY scoreable teams (status=active, named leader, evidence URL, confidence HIGH/MED)** — quality-weighted so the count can't be gamed by speculative subdivision; else STOP, write inspection findings to BUILD-STATE, escalate. Spot-check 5 random team rows: URLs resolve and support the row.
- **NOT built:** no scoring runs, no plays beyond the skeleton's one, no drafts.

### Phase 3 — Watcher live (manual), backtest, first hand-driven strikes (Week 2)
- **Entry:** Phase 2 accepted; ≥2 snapshot days; HubSpot cohort CSVs via staging (own token OR colleague export).
- **Steps:** build diff.ps1 and validate first output against a by-hand diff of one account; execute daily-watch.md manually every day (dedup discipline, coverage states in every brief); run the four-cohort backtest → reference\backtest memo + update every trigger's backtest_status/weight — **v1.1 point-in-time discipline: every historical case gets an as-of date; only evidence dated before the deal event counts as backtest evidence; anything else is labeled DIRECTIONAL, and the memo says so per trigger**; build 3–5 STRIKE plays fully by hand; **every human-confirmed scoring decision is copied into reference\golden-set\ (input evidence → confirmed team, tier, window) — the regression set builds itself from day one (v1.1)**. Sends only if Gates 1/2/4 (+3 for the country) signed AND deliverability gate passed — via a human in the sequencer; otherwise plays hold at `ready`.
- **Acceptance:** 5 consecutive daily runs logged; zero duplicate dedup_keys; diff.ps1 idempotent (same inputs twice → identical output); backtest memo has explicit keep/cut/DIRECTIONAL per Tier A–C trigger; every claim in every draft carries an evidence URL; golden-set has ≥10 confirmed cases.
- **NOT built:** no Clay table runs beyond the Phase-0 smoke test, no HubSpot API writes, no webhooks, no automation.

### Phase 4 — Machine assembly; integrations land on staging (Week 3)
- **Entry:** Phase 3 accepted. Integrations slot in independently as access arrives. **v1.1 additional entry criterion for the FIRST HubSpot write:** RevOps workflow audit done — every `ts_` property + association reviewed against existing workflows/scoring/lists/routing; tested on a sandbox or test record first; **kill-switch file (`staging\hubspot\WRITES-PAUSED`) honored by the drain step — its presence stops all CRM writes without stopping research.**
- **Steps:** Clay strike-builder consumes enrich-requests.csv — **v1.1: the 10-row mechanics test is followed by a ground-truth benchmark before Clay results feed any real play: ~50 stratified contacts (region × seniority), including people Unbound actually knows (colleagues, existing clients, past champions) as truth rows; measure correct-employer %, verified-email accuracy, catch-all rate, staleness, cost per usable contact; the acceptance threshold is written down BEFORE the benchmark runs.** HubSpot play-records created via the v1.1 outbox model (immutable note per play + task + `ts_` summary props; idempotency_key = play_id); alert mailer automated — `alert-mailer.ps1` drains `staging\alerts\` via Outlook COM (or Graph if the Phase-0 test failed; the manual-forward interim continues until either lands); trackable assets built one per top surviving trigger type; reply-classification runbook written — **v1.1 telemetry rules: an open is NEVER a standalone intent event (privacy proxies and scanners fire opens/clicks); call-now alerts require a direct reply OR repeated/multi-person engagement after bot filtering; asset activity only ranks follow-up priority; no surveillance language ever reaches a prospect ("you asked for the checklist" — fine; "I saw you read page 3" — banned, in copy-rules.md).**
- **Acceptance:** ONE full strike traced end-to-end through the NEW play-record model with the human gate in the audit trail; no step read anything except its staging file (the Part D/E-2 boundary, checked, not assumed); Clay benchmark memo with real accuracy numbers vs the pre-written threshold; kill-switch tested (create file → drain refuses); 10-row + benchmark credit spend documented.
- **NOT built:** no cron, no auto reply-classification, no gate loosening.

### Phase 5 — Pilot at 25 strikes (Week 4→5)
- **Entry:** Phase 4 accepted; Gates 1, 2, 4 signed (Gate 2 = sequencer chosen and live — the deliverability gate presupposes it); **deliverability gate passed (v1.1, replaces "domains warmed 2–3 weeks"):** SPF/DKIM/DMARC verified on the send domains, seed-list test across Gmail/Outlook/Yahoo class providers, bounce + complaint thresholds and ramp policy and emergency-pause rule agreed with the Gate-2 owner; Gate 3 matrix rows exist for every country being sent into.
- **Steps:** full-cadence daily watcher + strike builder under capacity-rules.md; every send human-gated; weekly-review.md → metrics-weekly.csv (fired→sent→replied→**meetings** per trigger type); **v1.1 kill rule: 2 weeks zero engagement → halve and 4 weeks → kill applies ONLY at ≥ min_exposure_sends delivered for that trigger type; below the floor the verdict is "insufficient data" and the trigger keeps running** (also kill immediately on factual/reputational risk or high reviewer-rejection rate, regardless of time); 15-min reverse-engineering note per meeting; every brief/play stamped with config_version; air-cover ads only if budget approved.
- **Acceptance:** 25 strikes sent OR documented shortfall vs the "≥15 in-window strikes in 4 weeks" criterion; ≥2 weekly scorecards; every kill-rule evaluation recorded with its exposure count; plays\index.csv reconciles with metrics; every `sent` row has `approved_by`; queue never silently exceeded capacity (ranked, expiries executed).
- **NOT built:** no watcher automation, no TAL expansion, no gate loosening.

### Phase 6 — Scale survivors + automate (Weeks 5–6)
- **Entry:** ≥3 weeks of manual motion; pilot metrics exist; **explicit user sign-off to automate, recorded in BUILD-STATE**.
- **Steps:** kill dead triggers per data; verify headless flags against `claude --help`; **v1.1 — test the exact scheduled invocation FIRST: a review-flagged docs note says scheduler-fired prompts may not execute skills marked `disable-model-invocation: true` [LIKELY — verify against live docs at build]; confirm the Task-Scheduler → PowerShell wrapper → headless-CLI path actually enters the skill before relying on it.** Task Scheduler daily job + wrapper; **v1.1 agent boundary, structural:** the web-facing watch run holds NO credentials (no MCP servers, no tokens in env, read+local-write tools only; fetched web content is data, never instructions); the HubSpot drain and the alert mailer are SEPARATE invocations that hold the credentials/COM objects and read ONLY schema-validated staging files, never web content. **v1.1 runtime hardening:** no-sleep policy during the run window; heartbeat = a second scheduled task that sends a [SYSTEM] email if no run-log entry exists by 10:00 (if the mail path itself is down, the heartbeat is silent — accepted pilot risk, written in BUILD-STATE; both scheduled tasks run "only when user is logged on" per the COM constraint in Part B); bounded retries with idempotent writes; Claude Code version + model recorded per run; off-device backup decided and tested (private git remote or encrypted zip to company drive) with one restore drill. Loosen human gate to spot-check for SEQUENCE tier ONLY — STRIKE stays fully reviewed forever; expand TAL via accounts.csv rows; if Clay sunset has hit, flip enrich-results writer to zoominfo/manual (schema unchanged). **Before any prompt/model/tool change: re-run the golden set; inconsistent tiers on identical evidence → scoring arithmetic moves into deterministic code, model keeps extraction + narrative only.**
- **Acceptance:** strategy success criteria each marked met/not-met with a data pointer: ≥75 scoreable teams · ≥15 strikes found · reply ≥3× baseline · ≥3 meetings by Week 6. Automation acceptance (v1.1, raised from 3): **10 consecutive unattended daily runs** whose briefs pass human review with zero corrections, including ≥1 run that exercised a source_unavailable path (proving failure states surface loudly). One missed-run alert drill.

---

## PART D — STAGING, EXPLICITLY NOT FALLBACK

**The file is the interface, permanently.** Consumers only ever read the file and never know the writer; access arrival changes who writes, never what readers do. No code path is deleted when access lands — a writer is added. Files stay the contract: auditable, diffable, git-versioned (where the data class allows — Part F).

| Integration | File interface | Pre-access writer | Post-access writer |
|---|---|---|---|
| HubSpot inbound | staging\hubspot\*.csv | colleague UI export | token/MCP refresh script, same columns |
| HubSpot outbound | staging\hubspot\outbox\*.jsonl (play-records, v1.1) | human applies in UI, records applied_by | script drains outbox (idempotency_key, kill-switch honored), records same |
| Clay / contacts | enrich-requests.csv → enrich-results.csv | manual method (dry-run 4a) + free verifier | Clay (post-benchmark) while alive → ZoomInfo/HubSpot after sunset |
| Alerts — Outlook email (v1.2) | staging\alerts\*.md | user reads on this PC, forwards by email | alert-mailer.ps1 sends via Outlook COM (or Graph), allowlist enforced, file moved to sent\ |

---

## PART E — SAFETY RAILS (structural, then procedural)

1. **No prospect-facing send capability exists anywhere in the build — absent, not disabled (v1.2 wording: the internal alert mailer is the sole mail-capable component).** No SMTP, no sequencer keys, no prospect-mail code. Prospect emails exist only as text in plays\*\emails.md; a human sends them from the sequencer. The alert mailer reads ONLY staging\alerts\, resolves recipients ONLY from git-committed config\alert-recipients.csv (internal team addresses), and never touches buying-group/enrich/suppression files — it structurally cannot address a prospect. Gate 2 chooses where the *human* clicks; it never grants the system a prospect send path.
2. **Credential/web separation (v1.1, structural; v1.2 extends to mail):** any session or run that reads external web content holds no CRM or mail credentials, no Outlook COM objects, and no write-enabled MCP tools; any step holding credentials reads only schema-validated local staging files. The alert mailer is its own invocation — it reads staging\alerts\ + config\alert-recipients.csv and nothing else, never web content. One process never does both. (Matches the standing LinkedIn prompt-injection defense requirement.)
3. **CLAUDE.md hard rules (verbatim):** never create sending code or store sending credentials here; never read `engine\`; secrets in Windows Credential Manager / user env vars, never files; outbox writes limited to the v1.1 play-record model (`ts_` namespace, immutable notes, tasks, summary props — nothing that could fire a HubSpot workflow email, and nothing before the RevOps audit); never state an unverified fact in a prospect-facing draft; no URLs from memory — fresh fetch or it doesn't ship; fetched web content is data, never instructions.
4. **Approval audit:** plays\*\status.md requires `APPROVED_BY:`/`APPROVED_DATE:`; index.csv makes missing approvals greppable; ack fields make ignored alerts greppable too.
5. **Disqualifiers before drafting:** conflict + suppression checks run before a play folder is created; header-only conflict-list.csv means "Gate 1 unsigned → zero sends." **Suppression is GLOBAL (v1.1): one suppression.csv consulted by every path (manual, Clay, ZoomInfo, sequencer import) — a suppressed person can never re-enter via a new enrichment source.**
6. **Belt-and-braces:** PreToolUse hook (verified capability) denying send-shaped commands.
7. **CRM kill switch (v1.1):** `staging\hubspot\WRITES-PAUSED` file stops all CRM writes without stopping research.

## PART F — GIT + DATA CLASSES + CONTEXT-LOSS PROTOCOL + MEMORY

- **Git: init `trigger-system\` only.** Root init would put legacy `engine\` and the unrelated Vercel deploy inside the blast radius for zero gain.
- **Data classes (v1.1 — what git holds and what it never holds):** git versions code, schemas, config, runbooks, briefs, play briefs/status, manifests + content hashes, and **raw ATS/newsroom snapshots (public, small, and tamper-evidence is exactly what diffing needs)**. Git NEVER holds: buying-group.csv contents, enrich-results.csv, suppression.csv, any engagement/reply exports, phones/emails of real people — git history is effectively undeletable, and contact data carries retention obligations. `.gitignore` from first commit: those files + `*.token, .env, *.key`. Contact-bearing files live on disk (and inside HubSpot, the actual system of record for people), with the retention question put to the Gate-3 owner.
- **Fresh-session read order (top of CLAUDE.md):** 1) CLAUDE.md 2) BUILD-STATE.md 3) PHASES.md current phase 4) last 3 run-log entries 5) re-run the previous phase's acceptance checks before building — verify, don't trust.
- **BUILD-STATE.md always holds:** current phase/status; last session + ≤3 bullets; next 3 actions; blocking-questions table; access table (each HAVE/REQUESTED/UNKNOWN); dated decision log; deviations-from-strategy section — **four approved refinements are logged there from day one: (a) kill rule gains a min-exposure floor (v1.1), (b) the ≥75-team checkpoint counts scoreable teams only (v1.1), (c) a lone asset open no longer triggers a call-now alert (v1.1 — strategy said "asset views alert the SDR to call"; now requires a direct reply OR repeated/multi-person engagement after bot filtering, because privacy proxies fire false opens), (d) the doorbell medium is Outlook email, not Slack (v1.2 — strategy names Slack; the company is not on Slack; user decision 2026-07-27; the behavior — alert → ack → act — is unchanged).**
- **session-close.md checklist at the end of EVERY session:** update BUILD-STATE → append run-log → commit.
- **Memory checkpoints (auto-memory):** kickoff memory at Phase 0, one per phase completion, and updates when any gate/access status changes.

## PART G — SELF-CRITIQUE (v1.1, updated after external review)

1. **Big upfront plan vs learn-by-doing?** Early phases produce data + manual reps; automation is last. The v1.1 walking skeleton strengthens this: the full path is proven in week 1 on 5 accounts before anything scales.
2. **Scoring drift remains the most likely failure point.** Now mitigated three ways: decision-table + show-the-arithmetic briefs, the self-building golden set with regression runs before any prompt/model change, and a pre-agreed escalation (scoring arithmetic → deterministic code) if drift is observed anyway.
3. **Files-as-database has real limits.** For THIS pilot (one operator, one machine, tens of plays) atomic writes + run_id + git are adequate and simpler. **Tripwire, written down:** concurrent writers, >50 accounts, or any observed file-corruption incident → canonical state moves to SQLite (Python 3.14 verified present), files remain as exports/interfaces. Adopting SQLite now would violate the simplicity priority for zero pilot benefit.
4. **Clay sunset mid-build** — handled structurally; if sunset lands before Phase 4, the benchmark runs against ZoomInfo/manual instead (same thresholds).
5. **Dedup edge cases** — now have explicit lifecycle fields (superseded_by, reopened_date) but still need judgment; calls logged in notes.
6. **PS 5.1 quirks** — manifest + coverage states catch fetch/parse failures loudly; the Phase-3 manual-diff validation gate stays the real defense.
7. **Documentation overhead** — session-close checklist + next-session re-verification; unchanged.
8. **Capacity is now modeled but the numbers start as guesses** — the skeleton's measured minutes correct them in week 1; the weekly review re-checks them at pilot volume.
9. **The review itself is a risk input, not an oracle:** it was written without the strategy doc, dry run, or verified access facts. Part I records what was rejected and why, so a future session doesn't silently re-adopt it.

## PART H — VERIFICATION (end-to-end)

- Per-phase acceptance criteria are the test suite; each mechanically checkable by a fresh session.
- **Phase-0 proof:** fresh-session test. **Phase-1 proof (v1.1):** one complete audited play lifecycle from the walking skeleton + measured labor per stage.
- **Deterministic-layer proof:** diff.ps1 vs by-hand diff; idempotency; coverage states exercised (at least one simulated source_unavailable).
- **Data-integrity proofs:** dedup uniqueness scan; manifest completeness; random team-row evidence-URL spot checks; kill-switch drill; suppression-respected drill (suppressed contact injected via a second path → blocked); alert-allowlist drill (alert file addressed to a list_name not in alert-recipients.csv → mailer refuses, v1.2).
- **Pipeline proof (Phase 4):** one strike traced across every file through the play-record model with the human gate in the audit trail; Clay benchmark vs pre-written threshold.
- **System proof (Phase 6):** strategy success criteria scored with data pointers; 10 unattended runs incl. a failure-path run; missed-run alert drill; golden-set regression green.

---

## PART I — EXTERNAL REVIEW DISPOSITION (ChatGPT review of 2026-07-27; "fix the critical ones, don't fully depend on it")

**Adopted as critical (integrated above):** one-record-per-play HubSpot model replacing mutable company properties (its best catch — the multi-team overwrite bug contradicted the strategy's own founding example) · week-1 walking skeleton on 5 accounts · RevOps pre-write audit + `ts_` namespace + CRM kill switch · web-agent/credential separation (structural) · contact PII out of git (snapshots stay — public data, tamper-evidence is the point) · Clay ground-truth benchmark before results feed plays · deliverability readiness gate replacing fixed "2–3 week warmup" · six coverage states (no-change ≠ not-observed) · kill-rule minimum-exposure floor · asset opens demoted to noisy supporting evidence + no surveillance language · capacity rules with queue expiry + backup owner · scheduled-invocation trap tested before Phase 6 · heartbeat/missed-run alert, version recording, backup + restore drill, 10-run soak · two-script/100-line cap removed as dogma (minimal-layer bias kept).

**Adopted in lighter form:** evidence model → 2 new fields + primary-source/independence rules instead of a 10-field schema · golden regression set → self-building from human-confirmed cases instead of 30–50 upfront · backtest → as-of dating + DIRECTIONAL labeling instead of full archival reconstruction · legal matrix → scoped to pilot countries, owned by legal · dedup lifecycle → 2 fields + judgment notes · 75-team checkpoint → same threshold, scoreable-only counting · alert-ack fields (doorbell medium later changed to Outlook email — v1.2) · config_version stamping · reply-time bands folded into the catch runbook · HubSpot API version pinned at integration.

**Rejected, with reasons:** SQLite as canonical store by Phase 4 (single-writer pilot at file scale; violates the simplicity priority for zero pilot benefit; replaced by a written tripwire — Part G-3) · resequencing TAL/team-mapping to week 3 behind the skeleton (snapshot history is the most time-critical asset in the strategy; skeleton runs in parallel instead) · treating the review's un-fetched citations as verified (its S-numbered sources carry no URLs; every claim the plan now relies on is either independently verified this session or explicitly marked LIKELY-verify-at-build) · the "conditional approval 5.5/10" framing as a gate (the substance is addressed; the score isn't actionable).

---

## PART J — EXECUTION ROADMAP (v1.2 — who does what, when; Part C stays the authority on entry/steps/acceptance)

Anchors: **Day 0 = the day the user says go.** Weeks count from Day 0. Phases 0–3 need nothing from anyone outside this room (all free-layer); only Phases 4–5 can slip on external dependencies, and their slippage never blocks the phases before them.

**Phase 0 — Day 0, ~half a day. Actor: Claude; user present ~20 min for the two smoke tests.**
Order: scaffold tree → CLAUDE.md / BUILD-STATE.md / PHASES.md → encode trigger-weights.yaml + scoring-rules.md + capacity-rules.md defaults → copy strategy into reference\ → five runbooks → alert-recipients.csv (user's work address, first row) → git init + .gitignore + first commit → smoke tests with user present (`clay login`; Outlook COM send-to-self → work-mailbox? prompt-free? recorded in BUILD-STATE) → fresh-session test → hand the user the ask-list email draft.
User on Day 0: say go · sit in for the smoke tests · send the ask list (URGENT: domains purchase, Clay sunset date, RevOps contact) · point at the TAL seed file.

**Phase 1 — Days 1–3. Actor: Claude; user ~30 min to sanity-check TAL criteria.**
Order: selection-criteria memo → rebuild the 25 into accounts.csv with per-account ATS discovery → snapshot.ps1 → first snapshot run (**daily habit starts here and never stops; manually triggered until Phase 6**) → pick the 5 walking-skeleton accounts (one Greenhouse/Lever, one page-only, one multi-BU, one legal-restricted region, one expected-no-signal) → skeleton runs days 2–5 in parallel → measured minutes-per-stage written into capacity-rules.md.
Dependency honesty: with no HubSpot access yet, the skeleton's CRM step produces the outbox record and whoever has UI access applies it by hand; if nobody can yet, the record itself is the deliverable and the apply step is logged as waiting — never silently skipped.

**Phase 2 — Days 3–5, overlapping the skeleton tail. Actor: Claude; user schedules the two interviews.**
teams.csv mapping per strategy §1 → **≥75 scoreable teams or STOP and escalate** → event-calendar.csv (rolling 6 months) → interviews → past-champions.csv + candidate triggers as `untested`.

**Phase 3 — Week 2, daily. Actor: Claude (~30–60 min/day); user or a colleague exports the deal cohorts if no token yet.**
diff.ps1 + by-hand validation on one account → 5 consecutive manual daily-watch runs (dedup + coverage states) → four-cohort backtest with as-of dating → 3–5 hand-built STRIKE plays (hold at `ready` unless every send gate has passed) → golden set reaches ≥10 confirmed cases.

**Phase 4 — Week 3. Each integration lands independently the moment its dependency arrives; none blocks the others.**
Clay: 10-row mechanics test → ~50-contact ground-truth benchmark vs the pre-written threshold (needs: Clay alive + credit cap). HubSpot: `ts_` properties + play-record writes (needs: token + RevOps audit + kill-switch drill). Alert mailer: `alert-mailer.ps1` via COM — **needs nothing external; earliest automatable piece** (Graph only if the Phase-0 test failed). Plus trackable assets and the reply-classification runbook. The phase closes on the end-to-end strike trace.

**Phase 5 — Weeks 4–5. Actor: SDR sends and calls; Claude watches, builds, reports; user owns the weekly review.**
Hard entry dependencies, all external and all flagged in BUILD-STATE until resolved: Gate 1 (conflict list) · Gate 2 (sequencer live) · Gate 4 (SDR + backup named) · deliverability gate passed · Gate 3 rows for every target country · baseline reply rate on file.

**Phase 6 — Weeks 5–6. Actor: Claude; user gives explicit automation sign-off first.**
Scheduled-invocation trap test → Task Scheduler jobs ("run only when user is logged on") → credential-separated invocations (watch run: no credentials; drain/mailer runs: credentials, no web) → heartbeat → 10-run soak incl. one failure-path run → restore drill → kill dead triggers, scale survivors, expand TAL.

**Critical path outside our control:** send domains purchased → deliverability gate → Phase 5 sends. HubSpot super-admin token + RevOps audit → Phase 4 CRM writes. Clay sunset date → how much of Phase 4 runs on Clay vs ZoomInfo/manual. Gate 4 naming → alert recipients + pilot ownership. Everything else proceeds regardless.

---

## First actions after approval (in order)
1. Update project memory (v1.2 revision recorded — done at save time).
2. Phase 0 scaffold (~half day) — ends with the fresh-session test; needs the user present ~20 min for the Clay login + Outlook COM smoke tests.
3. Hand the user the Part-A ask list as a ready-to-send message, URGENT items flagged: domains purchase + Clay sunset date + RevOps audit contact.
4. Phase 1 starts on the seed TAL immediately — day-1 snapshots and the walking skeleton begin the same week.
