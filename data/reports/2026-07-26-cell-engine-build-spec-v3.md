# THE CELL ENGINE
## TAL → cells → signals → HubSpot → multi-threaded outbound → meetings
**Unbound IA · Build Spec v3 · 2026-07-26** · supersedes v1 and v2

---

## WHAT YOU CORRECTED, AND WHAT IT CHANGED

| Your correction | Verdict | Result |
|---|---|---|
| Slack communities are paid ($35–100+), Reddit is baseless chatter | **Right.** Textbook advice that dies on contact with enterprise B2B. | **Deleted entirely.** No community listening anywhere in v3. |
| Demand gen managers may not be the ICP; the ICP is vast | **Right, and it exposed a design flaw.** Fixing a persona list is the wrong abstraction. | Persona is now **derived from the cell**, not pre-declared. Whoever owns that cell's budget is the target, whatever their title. |
| Where does data come from? We already have a TAL | **Right.** v2's list-generation was solving a problem you don't have. | TAL is now the **input**. The system's job is to make it 10x more productive. |
| Big companies have sub-departments, sub-companies, acquisitions — each with own budget and team. You worked with **AWS OpenSearch**, not AWS. ServiceNow acquired Armis. Targeting "the account" is false practice. | **This is the whole thing.** It invalidates most account-based tooling, including both my previous versions. | **The entire architecture is rebuilt around it.** See below. |
| System B and C were incomprehensible | **Right.** Abstract names for things that should be described by what they do. | Nine modules, each named for its function. No metaphors. |

---

## THE CENTRAL IDEA

**The account is not the unit. The cell is.**

> **A CELL is the smallest organisational unit that (a) controls a marketing budget, (b) has a named leader, and (c) can initiate or influence an agency engagement.**

ServiceNow is not one target. It is a *portfolio* of cells: Security & Risk product marketing, ITOM, ITSM, the newly-acquired Armis org, EMEA field marketing, APJ field marketing, public sector vertical marketing, partner marketing, developer marketing. Each has its own leader, its own budget, its own campaign calendar, its own pain, and its own agencies.

You already know this because you lived it: **you didn't work for AWS. You worked for AWS OpenSearch.** One cell inside a company with hundreds.

This is confirmed by how enterprise tech actually budgets: decentralised structures give product teams and regional units autonomy to run their own campaigns, with enterprise tech running a hybrid of centralised strategy and **decentralised budget authority at the business-unit and product-team level — specifically for ABM and product marketing.** ([source](https://monday.com/blog/marketing/enterprise-marketing/), [source](https://hginsights.com/blog/enterprise-account-based-marketing-the-complete-guide-to-strategy-execution-and-best-practices/))

### Three consequences, and they are the whole strategy

**1. Your TAL is 5–15x bigger than it looks.**
A TAL of 400 enterprise accounts is not 400 opportunities. It's potentially 2,000–4,000 addressable cells. You do not need to buy more data. **You need to explode the list you already have.** This is the cheapest pipeline expansion available to you and it requires zero new vendors.

**2. Cell-level knowledge is unfakeable credibility.**
Anyone can write "I saw ServiceNow raised…" Nobody can write *"your Security & Risk EMEA team has had a Demand Gen Manager req open since May, and Knowledge is in nine weeks"* unless they actually did the work. That isn't personalisation — it's **operational awareness**, and it reads like an insider rather than a tool. Your buyer, who is a marketer, can tell the difference instantly.

**3. Your existing logos are lateral expansion assets, not just logos.**
AWS OpenSearch is not "we worked with AWS." It is a **referenceable win inside one cell of a company with hundreds of sibling cells** — every one of which has a marketing leader who trusts an internal reference more than any case study. Same for Cisco, Dell, ServiceNow. Land-and-expand across cells inside a logo you already have is the highest-probability pipeline in your business, and it's currently invisible because your CRM models the account, not the cell.

---

## THE PIPELINE

```
TAL (accounts, from data team)
   │
   ▼
[1] CELL MAPPER ─────────► CELL REGISTRY (5–15x rows)
   │                        each cell: leader, region, product, budget evidence
   ▼
[2] SIGNAL WATCHER ──────► dated signals, ATTRIBUTED TO A CELL
   │                        job diff · M&A clock · launches · analyst · events · ads · leader change
   ▼
[3] SCORER ──────────────► fit veto → pressure → TIMING WINDOW → tier
   │                        ⚠ window is the differentiator: signals expire
   ▼
[4] BUYING GROUP BUILDER ► 5–8 humans per hot cell, by ROLE
   │                        Clay: waterfall email · phone · validate · suppress
   ▼
[5] BRIEF WRITER ────────► cell narrative + per-role angle + evidence links
   │
   ▼
[6] HUBSPOT WRITER ──────► parent company ▸ child company (cell) ▸ contacts ▸ task
   │
   ▼
[7] SEQUENCER ───────────► multi-threaded, role-differentiated, email + LinkedIn
   │
   ▼
[8] REPLY HANDLER ───────► classify → speed-to-lead → SDR → MEETING
   │
   ▼
[9] LEARNER ─────────────► outcomes rewrite signal weights
```

---

# MODULE 1 — CELL MAPPER
### the unlock. build this first, it is the whole system.

**Input:** your TAL. **Output:** a cell registry where every row is an addressable marketing unit.

### How to discover cells — five methods, ranked by yield

**Method A — Job posting archaeology (highest yield by far).**
Pull 12–24 months of *all* marketing job postings for each TAL account. Job titles in enterprise tech are structurally self-documenting:

> "Demand Generation Manager, **Security & Risk**, **EMEA**"
> "Product Marketing Manager, **Observability**"
> "Field Marketing Manager, **APJ**, **Public Sector**"

Each title emits three tokens: **function · business unit · region.** Parse and cluster them and you have reverse-engineered the marketing org chart of a company that never published one.

The JD body gives you more: reporting line ("reports to the Senior Director of Demand Gen, Security"), the martech stack, team size, and whether they use agencies. **This is the single richest and most under-used data source in B2B, and it is free.**

**Method B — LinkedIn people clustering (via Clay).**
Pull all current employees with marketing-family titles. Parse headline and title for BU/product/region tokens. Cluster. Cross-validate against Method A. This gives you the **living** org (Method A gives you the *hiring* org — you need both).

**Method C — Website and content architecture.**
Product pages, solution pages, regional domains, resource-library taxonomy. Product lines with their own landing pages, gated assets, and webinar tracks almost always have their own marketing owner.

**Method D — M&A registry.**
Every acquisition in the last 36 months is a candidate cell, and acquired entities retain separate marketing operations for a long time. (See the Armis play below — this is the highest-value cell type in the system.)

**Method E — Event and analyst footprint.**
Which product lines have their own booths, their own analyst submissions, their own user conferences. A product with its own MQ/Wave entry has its own marketing budget, essentially without exception.

### Cell registry schema

```yaml
cell_id:              SNOW-SECRISK-EMEA
parent_account:       ServiceNow
cell_name:            "Security & Risk — EMEA"
cell_type:            product_line | acquired_entity | region | vertical | function | segment
evidence:             [job_post_urls, linkedin_profiles, product_urls, press_releases]
confidence:           HIGH | MED | LOW      ← how sure are we this cell exists independently
leader:               name · title · linkedin · tenure_months
budget_evidence:      own_events | own_ads | own_agency | own_reqs | own_analyst_submission
team_size_est:        n
martech_observed:     [from JDs]
uses_agencies:        bool                  ← from JD language
sibling_cells:        [ids]                 ← powers lateral expansion
existing_relationship: none | prospect | client | past_client
```

**`existing_relationship` is the money field.** The moment AWS OpenSearch is tagged as a client cell, every sibling AWS cell becomes a warm-referenced target rather than a cold account. Your CRM cannot express that today. This is why the pipeline hiding inside your existing logos is invisible.

**Confidence gate:** only cells at HIGH or MED confidence enter the signal pipeline. A cell you inferred from one ambiguous job title is a guess, and guessing is how SDRs stop trusting the system.

---

# MODULE 2 — SIGNAL WATCHER
### every signal attaches to a cell_id or it is discarded

This is the discipline that makes the whole thing work. *"ServiceNow posted a demand gen job"* is noise. *"ServiceNow Security & Risk EMEA has had a Demand Gen Manager req open 74 days"* is a call you can make today.

### The signal library — researched for B2B SaaS / tech / security specifically

**CLASS 1 — Budget proven, pain written down, self-service failed** *(highest value)*

| Signal | Weight | Why it's strong |
|---|---|---|
| **Stale marketing req in cell, 60+ days** | 10 | Budget approved · pain documented **in their own words** · hiring failed · an agency is the direct substitute |
| **Req reposted / relisted** | 10 | They failed twice |
| **3+ marketing reqs open in one cell** | 8 | Scaling faster than they can staff |
| **JD contains agency-management language** | 8 | They already buy agencies — no category education needed |
| **JD names a martech migration** (Marketo→HubSpot, 6sense rollout) | 7 | Systems in flux = campaigns paused = pipeline gap |
| **Cell leader departed, no backfill 45+ days** | 8 | Capacity vacuum with budget still allocated |

The stale requisition is the strongest company-side signal available to anyone, and almost nobody tracks it because it requires **diffing job boards over time** — a daily snapshot and a comparison. Trivial in Claude Code. Impossible by hand. This is your cheapest durable edge and it should be built in week one.

**CLASS 2 — Predictable workload spikes** *(these are dateable in advance — see Timing Windows)*

| Signal | Weight | Action window |
|---|---|---|
| **Acquisition closed** | 10 | 0–9 months post-close |
| **New cell leader in seat** | 9 | days 30–90 of tenure |
| **Analyst inclusion** (Gartner MQ / Forrester Wave) for that product | 8 | 0–8 weeks after publication |
| **Major conference exhibit** (RSA, Black Hat, re:Invent, Knowledge, .conf, KubeCon) | 8 | **8–14 weeks BEFORE the event** |
| **Product launch / GA** | 7 | −6 to +12 weeks |
| **Regional expansion announced** | 7 | 0–6 months |
| **Rebrand / repositioning** | 7 | 0–6 months |
| **Funding** (smaller segment only) | 5 | 0–90 days |

**CLASS 3 — Observable capability gaps** *(evidence for the message, weak as triggers)*

Running paid ads with no gated asset behind them (5) · product page with no demand capture (4) · content cadence decay 90+ days for that product line (4) · competitor outspending them in the category (4) · webinar cadence gap (3).

Use these to make the *message* specific. Never fire on them alone.

**CLASS 4 — Deliberately excluded**
Bought intent topics. Every agency in your category buys the same feed and emails the same surging accounts the same week. It cannot differentiate you, and at cell level it is useless — it resolves to the parent domain, not the business unit that holds the budget.

---

# THE TWO PLAYS THAT MAKE THIS EXTRAORDINARY

Everything above is infrastructure. These two are why it books meetings.

## PLAY 1 — THE ACQUISITION INTEGRATION WINDOW

When a company in your TAL closes an acquisition, the acquired entity becomes a cell in acute, predictable, well-documented distress — and the parent's product marketing org inherits a workload spike it did not staff for.

**What actually happens, evidence-backed:**
- Marketing must integrate a new web, email and social presence on a **tight, high-visibility timeline** ([MarTech](https://martech.org/5-steps-to-a-seamless-post-ma-brand-integration/))
- **65% of companies complete brand changes within 12 months** — so the window is real but closes
- Website migration is the danger zone: a study of **892 domain migrations found 42% of migrated sites never recovered to pre-migration traffic levels**, and those that did took an **average of 229 days** (Search Engine Journal, via [Tendo/CMSWire](https://www2.cmswire.com/cp-tendo-communications-2026-01-cx.html))
- Rushed migrations lose **30–40% of organic traffic**
- Integration decisions cascade into "messaging, information architecture, SEO, governance, migration and content operations" — precisely your service surface
- Internal comms and joint campaigns run through the **first 24 months**

**Why this is the single best trigger available to you:**
1. **Publicly dated.** Announcement date and close date are both press-released. You know the clock exactly.
2. **Guaranteed workload spike** with no proportional headcount increase.
3. **The acquired team is losing people** — post-acquisition attrition in marketing is routine — right as workload peaks.
4. **You can open with a specific, verifiable, alarming statistic** rather than a compliment.
5. **Two cells become reachable at once** — the acquired entity and the parent's product marketing team absorbing it.
6. Almost nobody times outreach to integration milestones. Agencies pitch at announcement, when nothing is decided, then go quiet exactly when the work starts.

### Worked example — ServiceNow / Armis (your priority account)

**Verified facts:** ServiceNow agreed to acquire Armis for **$7.75B**, announced 2025 ([ServiceNow IR](https://investor.servicenow.com/news/news-details/2025/ServiceNow-to-acquire-Armis-to-expand-cyber-exposure-and-security-across-the-full-attack-surface-in-IT-OT-and-medical-devices-for-companies-governments-and-critical-infrastructure-worldwide/default.aspx)), and **ServiceNow has completed the acquisition** ([ServiceNow Newsroom, 2026](https://newsroom.servicenow.com/press-releases/details/2026/ServiceNow-completes-Armis-acquisition-closing-the-gap-between-asset-visibility-and-cyber-risk/default.aspx)).

**Cells this creates or activates:**

| Cell | Situation | Angle |
|---|---|---|
| Armis marketing (acquired) | Brand migration, campaign continuity risk, likely attrition | Migration risk + demand continuity |
| ServiceNow Security & Risk PMM | Portfolio just expanded massively; must position IT+OT+medical | Category expansion + new messaging architecture |
| ServiceNow Security demand gen | Cross-sell campaigns needed both directions into two installed bases | Net-new campaign build, no added headcount |
| ServiceNow field/regional (EMEA, APJ) | Must localise the combined story | Regional campaign rollout |
| Armis vertical teams (healthcare/OT/critical infra) | Specialised segments at risk of dilution | Vertical demand preservation |

**One event. Five addressable cells. Your CRM currently shows it as one account with one owner.**

Opening line that writes itself — and note it contains no flattery, no "congrats on the acquisition," and a fact they can verify in 30 seconds:

> Armis just closed. The part that usually hurts isn't the branding — it's the migration. In a study of 892 domain migrations, 42% never got back to pre-migration traffic, and the ones that recovered took about 229 days.
>
> We handle demand continuity through exactly this window. We already run demand gen for Aqua Security and Bugcrowd.
>
> Worth 15 minutes before the redirects go live?

**Operationalise it:** monitor every TAL account for M&A announcements and closes. Announcement starts a watch. **Close starts the clock.** Highest priority: weeks 2–16 post-close.

## PLAY 2 — THE CONFERENCE CLOCK

Tech and security run on a **fixed, published, annual event calendar**: RSA Conference, Black Hat, AWS re:Invent, ServiceNow Knowledge, Cisco Live, KubeCon, Splunk .conf, Gartner summits, and dozens of vertical shows.

A cell exhibiting at a major event has a **non-negotiable, dated demand-generation obligation**: pre-event awareness and meeting-booking, on-site capture, post-event follow-up. The pre-event demand push runs roughly **8–14 weeks out.**

**This means you can know, three months in advance, exactly which cells will have acute, funded, deadline-driven demand gen need — and reach them before they've decided how to cover it.**

Nobody does this, because everyone pitches *during* the event, when the buyer is on a plane and the budget is already committed.

**Build:** a rolling 6-month calendar of relevant events × which TAL cells exhibit (sponsor pages and exhibitor lists are public) → auto-trigger outreach at T-minus 12 weeks.

> You're exhibiting at RSA in 11 weeks. The booth is the easy part — the pre-show meeting pipeline is what decides whether it paid for itself.
>
> We build pre-event demand programmes for security vendors. Aqua Security and Bugcrowd are references.
>
> Want the pre-RSA pipeline framework we use? No call needed.

**Why this is structurally excellent:** it's recurring (every year, forever), predictable, budget is already committed, the deadline is immovable, the pain is universally acknowledged, and it produces a natural, non-pushy reason to reach out on a specific date.

---

# MODULE 3 — SCORER

```
1. FIT VETO (cell level, hard binary)
   ✗ parent account not in TAL
   ✗ cell confidence = LOW
   ✗ no budget evidence
   ✗ competitor-of-client conflict            ← get this in writing before first send
   ✗ active opportunity / current client cell / suppression window
   ✗ not lawfully contactable in that region

2. PRESSURE = Σ(signal_weight × recency_decay)     recency: ≤14d 1.0 | ≤30d 0.8 | ≤60d 0.5 | ≤90d 0.25 | >90d 0

3. TIMING WINDOW  ← the differentiator
   Every signal carries an action window. Outside the window, the signal scores ZERO
   regardless of strength. A conference signal at T-2 weeks is worthless; at T-12 weeks
   it is the strongest thing you have. Most systems ignore this and email everyone
   at the wrong moment.

4. CORROBORATION = independent signals (different source AND different mechanism)

5. TIER
   HOT   ≥2 corroborating signals, in-window, fit pass       → SDR today
   WARM  1 strong signal in-window                            → sequence, no SDR time yet
   WATCH in-window signal but weak, OR strong but out-of-window → monitor + dated re-trigger
   SKIP  fit fail                                             → permanent
```

**On WATCH:** most cells will sit here, and that's correct. WATCH carries a `retrigger_date` computed from the signal's window — a conference signal parked in WATCH auto-promotes at T-12 weeks. This is also your HubSpot recycle path; lifecycle stages only move forward, so without an explicit promotion mechanism your reporting rots within two quarters.

---

# MODULE 4 — BUYING GROUP BUILDER

**Do not target one person per cell.** Evidence: B2B buying committees have grown from 5.4 stakeholders (2014) to 8.2 (2024) to 11+ (2026), with 29% of enterprise buying groups now at 10+. Enterprise deals at $250K–$1M carry 10–15 stakeholders. *(Attribution note: these figures are aggregated by a vendor blog citing Gartner and INFUSE Voice of the Buyer 2026 secondhand — directionally reliable, not primary research. [source](https://www.growthspreeofficial.com/blogs/b2b-saas-buying-committee-size-benchmarks-2026-stakeholders-by-acv-vertical-region-role-composition))*

The orchestration finding is the one that matters operationally: **without orchestration, 10–12 stakeholder deals close at 20–32%; with full buying-group orchestration, the same committee size closes at 28–44%.** Same caveat on sourcing — but a ~40–75% relative lift from coordinated engagement is consistent with everything else in the field.

**Per HOT cell, build 5–8 contacts by role:**

| Role | Who, at cell level | Angle |
|---|---|---|
| **Champion** (1–2) | Cell's demand gen / campaign lead | Execution relief, capacity |
| **Economic** (1–2) | Cell's VP/Director Marketing | Pipeline number, cost-per-opp |
| **Influencer** (2–5) | Product marketing, marketing ops, field marketing | Fit with their stack and calendar |
| **Blocker** (1–3) | Procurement, vendor management | Only engage once there's a deal |

Because the ICP is vast and titles vary wildly across companies, **do not pre-declare personas.** Derive them: whoever sits in that cell, in marketing, at manager level and above. The cell defines the persona. That resolves the "are demand gen managers even our ICP" question structurally — sometimes they will be, sometimes it'll be a product marketing director or a regional field marketing lead, and the system doesn't need to care.

Then Clay: waterfall email → validate → waterfall phone → 90-day suppression lookup against everything already contacted.

---

# MODULE 5 — BRIEF WRITER

One brief per HOT cell. Not per company.

```yaml
cell:               ServiceNow — Security & Risk, EMEA
why_now:            2–3 sentences, plain speech, every claim traceable to a dated source
signals:            [{type, date, evidence_url, verbatim_quote}]
timing_window:      what closes, and when      ← creates real urgency, not manufactured
pain_hypothesis:    what we think is breaking + CONFIDENCE
peer_proof:         which of Aqua Security / Bugcrowd / Rubrik / AWS OpenSearch / Todyl, and why
lateral_reference:  sibling cell where we're already in ← if parent is an existing client
buying_group:       [{name, title, role, angle}]
message_variants:   one per role
disqualifiers:      what would make this wrong
```

**`lateral_reference` is the highest-converting field in the system.** *"We're already working with your OpenSearch team"* outperforms every case study, every stat, and every clever subject line — because it converts a cold email into an internal referral.

---

# MODULE 6 — HUBSPOT WRITER
### how to model cells in HubSpot without custom objects

Use **parent/child company associations** — native, no Enterprise tier required:

```
Company (parent)  = ServiceNow                    [account roll-up, exec reporting]
  └─ Company (child) = ServiceNow — Security & Risk EMEA   ← THE CELL. This is the working record.
       └─ Contacts   = the buying group
       └─ Deal       = attached to the CELL, never the parent
```

*(If you're on a tier with custom objects, a dedicated Cell object is cleaner. Verify your tier — parent/child works everywhere and ships this week.)*

**Cell (child company) properties**
```
cell_type · cell_confidence · cell_leader · budget_evidence · uses_agencies
signal_tier · pressure_score · signals_fired (dated, sourced) · why_now
timing_window_closes (date)   ← drives urgency and SDR prioritisation
retrigger_date (date)         ← the WATCH recycle mechanism
lateral_reference_cell        ← sibling cell where we're already engaged
existing_relationship
```

**Contact properties**
```
cell_id · buying_group_role · role_angle · sequence_variant · thread_position
```

**Automation**
- HOT cell created → owner assigned → **task due same day** → Slack with the brief
- **24-hour acceptance clock.** Unaccepted → escalate. This is the most-skipped step in every system in those 14 videos, and it's where pipeline silently dies.
- `timing_window_closes` within 14 days → priority flag
- `retrigger_date` reached → re-score, auto-promote if warranted
- Any reply on a cell → **pause sequences for all other contacts in that cell** (nothing looks worse than three of your reps emailing one team in parallel with the same idea)

Write via HubSpot API from Claude Code. *(A HubSpot MCP server is an option — verify current auth and scope support before designing around it. The API path is the safe default and it ships now.)*

---

# MODULE 7 — SEQUENCER

**Multi-threaded from the start.** 3–5 contacts per cell, staggered 48h apart, differentiated by role. Same cell narrative, different angle per person — never the same email to five people at one company.

**Cadence per contact:** Day 0 email → Day 2 LinkedIn connect (no message) → Day 5 email 2 (new evidence, not a bump) → Day 9 call → Day 14 breakup.

**Copy rules for a buyer who writes this copy for a living:**
- Open with the **cell-specific fact**, never a compliment. No "congrats on the acquisition."
- **No biographical personalisation.** Alma mater, hometown, hobbies — to this buyer these signal a tool, not a human.
- Name the peer: Aqua Security, Bugcrowd, Rubrik. For security marketers these are the benchmark set, not "logos."
- **Lead with the lateral reference** when it exists. It beats everything else in this list.
- Soft CTA. Ask for the artifact, not the meeting.
- Strip AI tells before send: em-dashes, "delve," "in today's landscape," bolded summary lines, tri-colon rhythm. One practitioner in the video set framed this well — people tolerate AI-assisted outreach; they do not tolerate *carelessly formatted* AI outreach, because it signals you didn't read it either.
- **3 subject-line variants per campaign** — deliverability (breaks ESP pattern detection) plus a real A/B read.

**Automation boundary — be honest about this.** You asked for automated cold email. At enterprise ACV with expert buyers:
- **Tier 1 cells (priority accounts, existing-logo siblings): human reviews every send.** The downside of one bad automated email to a ServiceNow VP is losing a multi-cell account permanently. Not worth the saved minute.
- **Tier 2/3: fully automated**, with the volume cap enforced.
- **Volume cap is a feature.** If this system increases your send volume, it has been built wrong. It should send *fewer*, better-aimed emails.

---

# MODULE 8 — REPLY HANDLER

| Class | Action |
|---|---|
| `MEETING` | Calendar link instantly + SDR alert |
| `ASSET_REQUEST` | Auto-deliver on a **tracked link** · 5-minute clock starts |
| `QUESTION` | Draft → **human approves** → send |
| `OBJECTION` | Human only. Never auto-answer. |
| `REFERRAL` ("talk to X") | **Auto-create the new contact in the same cell** and re-sequence |
| `NOT_NOW` | Capture the timing, set WATCH + dated re-trigger |
| `NOT_INTERESTED` | Suppress the contact; **keep the cell alive** — one person's no is not a cell's no |
| `HUMAN_LOOP` | Classifier unsure → Slack a human |

`HUMAN_LOOP` is mandatory. An AI that confidently mis-replies to a VP at a priority account costs you every cell in that logo.

**Speed:** first human touch within 5 minutes of a positive reply. This is unglamorous and almost nobody does it.

---

# MODULE 9 — LEARNER

- **Precision scorecard per signal type**: fired N → meetings M. Review monthly. **Kill anything below threshold.** Signals rot and competitors copy them.
- **Precision per cell type**: do acquired-entity cells outperform regional cells? Do product-line cells outperform vertical cells? You will learn things here that change your whole targeting model, and nobody in your market has this data.
- **Backtest**: reconstruct what was observably true about each closed-won *cell* in the 90 days before it engaged. **This converts every weight in this document from my hypothesis into your evidence.** It is the highest-value two days in the build.
- **Holdout**: 10–15% of qualifying cells deliberately untouched. Without it you cannot distinguish "the engine works" from "Q3 was good."

---

# BUILD ORDER

**Week 1 — Cell Mapper on 25 accounts.** Start with your priority accounts and every account where you have an existing or past relationship. Job-post archaeology + LinkedIn clustering. **Measure the explosion ratio.** If 25 accounts yield 150+ cells, the thesis is proven and everything else follows. Simultaneously start the daily job-board snapshot — you need a baseline before you can detect staleness.

**Week 2 — Signal Watcher.** Job diff (the stale-req detector), M&A monitor, conference calendar. These three carry most of the value; the rest is refinement.

**Week 3 — Scorer + Buying Group + HubSpot.** Parent/child model, properties, workflows, Slack. Hand-review 50 scored cells before automating anything.

**Week 4 — Pilot: 25 HOT cells, human-gated.** Every send reviewed. Measure precision, reply rate, meetings.

**Weeks 5–8 — Scale the survivors.** Kill dead signals. Automate Tier 2/3. Stand up the holdout. Run the backtest.

**Rule:** never automate a step you haven't run manually ten times. Test at 10 before running at scale.

**Fastest path to a first meeting:** the Armis window is open now, and every sibling cell of AWS OpenSearch is warm-referenceable today. Neither needs the full system built — you can run both by hand next week while the engine gets built behind them.

---

# WHAT WILL BREAK

| Risk | Guardrail |
|---|---|
| **Cell map is wrong** — you invent cells that don't exist | Confidence gate. Two independent evidence sources required for HIGH. Cite evidence in every brief so SDRs can sanity-check. |
| **Cells go stale** — reorgs are constant in enterprise tech | Re-run the mapper quarterly. Any cell with no signal in 180 days → re-verify before use. |
| **Wrong cell attribution** — signal assigned to the wrong unit | Require an explicit BU/region token; if absent, attribute to parent and mark LOW confidence rather than guessing. |
| **Multiple reps hit one logo simultaneously** | Parent-level visibility on every cell record; auto-pause siblings on any reply. |
| **Client conflict** — prospecting a competitor of Cisco/Dell/AWS/Rubrik/Bugcrowd/Aqua/ServiceNow | Hard veto, agreed in writing, **before first send.** Your logo list makes this a live commercial risk. |
| **GDPR / lawful basis** | EMEA/APJ cells need documented lawful basis. Legal review before launch. Non-negotiable. |
| **Deliverability** | Separate domains, warmup, suppression, volume caps, weekly bounce/spam monitoring. |
| **Automated email damages a priority account** | Human gate on Tier 1. The saved minute is not worth the account. |
| **Prompt injection via scraped JDs and profiles** | Scraped text is untrusted **DATA**, never concatenated into instructions. Strip and flag injection-class strings; human-review anything that trips it. |
| **SDRs don't trust it** | Every brief carries dated evidence with clickable sources. Publish precision scorecards. Trust is the scarce resource that decides whether this survives month three. |

---

# WHAT I NEED FROM YOU

1. **The TAL** — or 25 representative accounts to prove the explosion ratio
2. **Which accounts you have existing or past relationships with, at cell level** — this is the warmest pipeline in the business and it's currently invisible
3. **Client-conflict rules in writing**
4. **Closed-won history, 12–24 months** — converts every weight here from hypothesis to evidence
5. **Clay plan + credit budget** — sets the enrichment ceiling
6. **HubSpot tier** — determines custom objects vs parent/child
7. **Who owns the queue**, and how many SDRs work it

---

## ONE PARAGRAPH

*We stop treating accounts as targets. Using job-posting archaeology and LinkedIn clustering, we reverse-engineer the internal marketing org of every account in the TAL and explode it into cells — the smallest units that hold their own budget and leader. A TAL of 400 enterprise accounts becomes several thousand addressable cells without buying a single new record. Every signal is then attributed to a specific cell, not a company: a stale demand gen req in Security & Risk EMEA, an acquisition that just closed, a conference eleven weeks out. Signals score only inside their action window, so we reach cells at the moment the need is funded and urgent rather than whenever the data refreshed. Qualified cells get a 5–8 person buying group mapped by role, a brief with dated evidence, and a HubSpot child-company record with a same-day SDR task and a 24-hour acceptance clock. Outreach is multi-threaded and role-differentiated, and where we already serve a sibling cell it leads with that internal reference — which converts a cold email into an internal referral. The two fastest plays are live right now: the ServiceNow-Armis integration window, and lateral expansion from AWS OpenSearch into its sibling cells.*
