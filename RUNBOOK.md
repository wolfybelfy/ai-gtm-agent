# CELL ENGINE — OPERATOR RUNBOOK
**Unbound IA · 2026-07-26 · companion to `data/reports/2026-07-26-cell-engine-build-spec-v3.md` (strategy) and `engine/` (the executable system)**

The spec is the *why*. This is the *do*. Test: could a team run this tomorrow without another strategy document? Everything below is a command, a checklist, or a decision with an owner.

---

## THE SHAPE OF IT (30 seconds)

Meetings come from three motions, in order of speed:

1. **Manual plays that need zero build** — run THIS WEEK by hand: the ServiceNow/Armis integration window (open now, closes as redirects go live) and lateral expansion from AWS OpenSearch into sibling AWS cells. First meeting can come from these before the engine exists.
2. **The engine** — `engine/` in this repo. Claude Code runs seven workflow files: map cells → watch signals daily → score → build buying groups → write briefs → write HubSpot → daily loop. Free where possible, Clay only where it pays, HubSpot as system of record, Slack as the SDR surface.
3. **The learning loop** — weekly precision scorecards, monthly backtest + holdout. Converts every weight from hypothesis to our own evidence.

Division of labour (three independent operators in the research converged on this): **cheap/at-scale work runs free in Claude Code; anything a prospect reads goes through Clay/HubSpot with visible human QA.** The engine never auto-sends to Tier 1. Ever.

---

## DAY 0 — SETUP (~2 hours, one person)

**Accounts & access**
- [ ] Claude Code installed and signed in (already true if you're reading this there)
- [ ] Clay: install the official Claude Code plugin. In the Claude Code **terminal** (marketplace add doesn't work from the desktop app/VS Code extension — per transcript #3): `/plugin` → marketplace → add → `github.com/clay-run/agent-plugins` (URL as verified on-screen in transcript #1 — **verify it live before install**; beta name "Terracotta" = shipped name "Workflows"). Then: "help me authenticate my Clay account" → OAuth link → choose workspace → authorize. If the terminal mangles the link, copy-paste it manually.
- [ ] HubSpot: create a **private app** (Settings → Integrations → Private apps), scopes: companies/contacts/deals read-write + tasks write. Put token in `engine/.env` as `HUBSPOT_TOKEN=`. Note the portal's tier while you're in there.
- [ ] Slack: create a free **incoming webhook** for an `#icp-signals` channel → `SLACK_WEBHOOK_URL=` in `engine/.env`.
- [ ] `engine/.env` is never committed anywhere.

**Free stack (no new vendors needed)**
Claude Code web search = the research layer ("free Claygent" — transcript #5). ATS job feeds, newsrooms, exhibitor lists = free signal sources. Local CSV/JSON in `engine/data/` = the store (no Supabase needed at this scale). Slack webhook = free routing. Paid usage is confined to: Clay credits in workflow 04 (capped in `engine/config/limits.yaml`), ZoomInfo if useful, and whatever sending tool is chosen at Gate 2.

**Smoke test**
- [ ] In Claude Code from `engine/`: "Confirm you can see the Clay plugin, then fetch one company from HubSpot using the token in .env, then post a test message to the Slack webhook." All three green before Day 1.

---

## DECISION GATES — these block sends, not builds. Get owners on them Day 0.

| # | Gate | Owner | Why it blocks |
|---|---|---|---|
| 1 | **Conflict rules signed** — fill `engine/config/conflict-rules.md` | Sales leadership | We serve Cisco/Dell/AWS/Rubrik/Bugcrowd/Aqua/ServiceNow. One email to a client's competitor can cost a multi-cell logo. Nothing sends until signed. |
| 2 | **Sending infrastructure** | You + whoever owns domains | Unknown today: domains, ESP, warmup state. Options: HubSpot sequences (needs Sales Hub paid seats — check tier from Day 0), or a dedicated sequencer (SmartLead/Instantly-class, paid, used across the research). Never cold-send from the main unboundia.com domain. If new domains are bought: 2–3 weeks warmup before real volume — buy them Day 0 so the clock runs during the build. |
| 3 | **GDPR / lawful basis for EMEA+APJ cells** | Legal | Documented lawful basis per region before first EMEA send. Non-negotiable. |
| 4 | **TAL access** — or 25 representative accounts | Data team | The engine's input. Without it, Week 1 runs on the priority + existing-client accounts you can name yourself. |
| 5 | **Queue ownership** — who accepts HOT-cell tasks, how many SDRs | Sales ops | The 24h acceptance clock needs a human on the other end. |

Gates 1–3 can all be worked in parallel with Week 1. None of them blocks building.

---

## THIS WEEK — MEETINGS BEFORE THE ENGINE (manual, ~2 days of focused work)

**Play A — ServiceNow/Armis window (open now).**
1. In Claude Code: map the Armis-related cells by hand using `engine/workflows/01-map-cells.md` method on just ServiceNow — the spec's worked example already names five cells (Armis marketing · SNOW Security & Risk PMM · Security demand gen · EMEA/APJ field · Armis verticals).
2. For the 2 most reachable cells: find 5–8 buying-group contacts (Clay, small spend), write the brief per `engine/workflows/05-write-brief.md`, human-write the emails per `engine/templates/copy-rules.md` (migration-risk angle, soft CTA: offer a demand-continuity checklist).
3. **Gate 1 check** (is Armis/ServiceNow conflict-clear? — they're a client; this is an *expansion* play, so route it through the account owner as internal referral first, not cold email).

**Play B — AWS OpenSearch lateral expansion.**
1. List sibling AWS product-marketing cells adjacent to OpenSearch (search + LinkedIn clustering, free).
2. Ask the OpenSearch account lead for the internal-referral path FIRST. Cold email is the fallback, and it opens with "we work with your OpenSearch team."
3. Same brief + human-written copy flow.

These two produce real pipeline AND serve as the manual reps required before automating anything (CLAUDE.md rule 10).

---

## WEEK 1 — PROVE THE THESIS

- [ ] Put 25 accounts in `engine/data/tal/accounts.csv` (priority accounts + every existing/past relationship first)
- [ ] Run: `execute workflows/01-map-cells.md` → **measure the explosion ratio.** 25 accounts → 150+ cells proves it; <75 means stop and re-examine, not massage.
- [ ] Start the daily snapshot immediately: `execute workflows/02-watch-signals.md` every morning (staleness detection needs a baseline — every day not snapshotting is edge lost)
- [ ] Tag every existing-client cell (`existing_relationship`) — this lights up `lateral_reference` for all siblings

## WEEK 2 — SIGNALS LIVE
- [ ] Daily 02+03 runs; build `event-calendar.csv` (conference clock, rolling 6 months)
- [ ] M&A sweep across the TAL (announce = watch, close = clock)
- [ ] Hand-review 50 scored cells against the run-log math before trusting the scorer

## WEEK 3 — CRM + PEOPLE
- [ ] One-time HubSpot property setup + parent/child model (`workflows/06`, test at 10, eyeball in HubSpot)
- [ ] Configure the three HubSpot UI automations listed in workflow 06 (24h acceptance clock above all)
- [ ] Buying groups for current HOT cells (`workflows/04`, credit cap enforced)

## WEEK 4 — PILOT: 25 HOT CELLS, HUMAN-GATED
- [ ] Every send human-reviewed. Sequencing per `templates/copy-rules.md` through the Gate-2 tool
- [ ] Measure: signal precision (which signals produced accepted briefs), reply rate, meetings
- [ ] Daily reply sweep per workflow 07 step 6 (speed-to-lead: positive reply → human touch within 5 minutes, four touchpoints within the hour — email reply, LinkedIn connect, call, tracked asset)

## WEEKS 5–8 — SCALE THE SURVIVORS
- [ ] Kill signals below precision threshold (weekly scorecard) · automate Tier 2/3 sends within caps · stand up the 10–15% holdout · run the closed-won backtest (the highest-value two days in the build — it converts every weight from the videos' claims into our evidence)
- [ ] Only now: schedule `07-daily-run.md` on cron/routines

---

## SCOREBOARD (the only numbers that matter, posted weekly to Slack)

1. **Meetings booked** (the goal — everything else is instrumentation)
2. HOT cells surfaced · briefs accepted by SDR within 24h (trust metric)
3. Reply rate on engine sequences vs. current baseline
4. Signal precision by type (fired → meeting) · explosion ratio of the TAL
5. Credits + spend per meeting

## HONESTY BOX (what this system does not do)

- It will not book meetings without an SDR accepting tasks — the 24h clock needs a human on the end (Gate 5).
- Every performance number in the source videos is self-reported by someone selling something. The mechanics are adopted; the numbers are not. Ours come from the pilot.
- Weights in `signal-weights.yaml` are hypotheses until the backtest. The Learner exists precisely because some of them are wrong.
- A day with zero HOT cells is correct behavior, not failure. The engine's job is fewer, better-aimed sends at the funded moment.
