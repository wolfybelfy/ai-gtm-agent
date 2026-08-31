# PHASES — static copy from implementation-plan v1.2 (Parts C + J). Authority: reference\implementation-plan-v1.2.md
_Extracted verbatim 2026-07-27. If this file and the plan ever disagree, the plan wins and this file gets re-extracted._

> ### CLAY OVERRIDE — 2026-08-24 (read before any acceptance check below)
> The user REMOVED Clay entirely (all integration, scripts, Monday-run usage; the API had
> begun returning 402 after the lapsed 08-22 renewal). Every "Clay" step below is left
> verbatim (faithful copy) but is superseded: read Clay enrichment/benchmark steps as their
> **ZoomInfo equivalents** (`scripts\zoominfo-enrich.ps1`, Monday stage 2c, verdict-gated per
> `config\enrichment-policy.md`); Clay search/mapping steps run on free public sources only.

> ### CADENCE OVERRIDE — 2026-07-29 (read before any acceptance check below)
> The user set the watch cadence to **MONDAY ONLY, end to end**. The text below was extracted before
> that decision and still says "daily" in five places (Phase 1 steps, Phase 3 acceptance and roadmap,
> Phase 6 acceptance, Part J). It is left **verbatim** because the plan is the authority and this file
> is a faithful copy — but read every "daily run" below as **"scheduled run"**:
>
> - Phase 1 "daily snapshot habit starts here and never stops" -> the habit is **every scheduled run,
>   never skipped**. Weekly, not daily.
> - Phase 3 "5 consecutive **daily** runs logged" -> **5 consecutive SCHEDULED runs** (5 Mondays).
> - Phase 6 "10 consecutive unattended **daily** runs" -> **10 consecutive unattended scheduled runs**.
>
> Accepted and logged blind spot: a job posting that opens **and** closes inside the same week is never
> observed. Feeds carry posted dates, so anything opened mid-week and still open is seen on Monday.
> The runbook is `runbooks\monday-watch.md`; `runbooks\daily-watch.md` is SUPERSEDED.
> Full reasoning: `BUILD-STATE.md` decision log, 2026-07-29 "CADENCE RECONCILIATION".

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
