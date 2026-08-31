# TRADESTATION — MANUAL DRY-RUN of the Trigger-to-Meeting System
**2026-07-27 · No Clay, no ZoomInfo — 100% free web research, ~35 minutes of live work in this session.**
**Every URL below was fetched and verified live today unless explicitly marked [UNVERIFIED]. Nothing is from memory.**

This walks one account through the strategy (`2026-07-26-trigger-outbound-meeting-system.md`) step by step, exactly as the daily system would do it — just by hand.

---

## STEP 0 — Disqualifiers + fit check (before any effort is spent)

| Check | Result |
|---|---|
| Client-competitor conflict | **PASS** — TradeStation is an online brokerage; no overlap with Dell/Cisco/AWS/Rubrik/Aqua/Bugcrowd/ServiceNow/Todyl relationships |
| Active client / suppression | Needs a HubSpot lookup on your side — assumed PASS for this dry run |
| Lawful contact region | Primary targets are US-based (Plantation FL / remote); the Europe entity's leadership may sit in Amsterdam → **Gate 3 applies to any EU-based contact** |
| ICP fit | **FLAG, not fail:** TradeStation is fintech, and its retail brokerage marketing is B2C — outside the stated tech/SaaS/B2B ICP. The fit is real but narrower: (a) the **institutional/API/B2B segment**, and (b) a **brand-new European entity that needs full-funnel demand building** — which is an agency-shaped problem regardless of B2C/B2B. Employee count not verified this session [verify in Week-1 mapping]. |

Verdict: proceed, with the ICP flag carried into the brief so nobody pretends this is a core-ICP account.

---

## STEP 1 — Team mapping (logos → budget-owning marketing teams)

Built from the fetched leadership page and careers page + verified press. Without ZoomInfo, this is title-clustering from public sources only — confidence marked per row.

| # | Team | Named leader (verified) | Evidence | Confidence |
|---|---|---|---|---|
| 1 | **US retail / active-trader marketing** (Group marketing, Plantation FL) | Tom Hammergren, Chief Growth Officer (Group + Securities) → Marco Carrucciu, VP Marketing (self-described focus: "luxury segment of trading" — experienced, high-net-worth traders) | Leadership page; Authority Magazine interview (Aug 14, 2025) | HIGH |
| 2 | **TradeStation Europe B.V.** (Amsterdam, launched June 10, 2026, 30 EEA countries, retail + institutional) | Peter Comstock, President, TradeStation Europe | Traders Magazine launch coverage (fetched) | HIGH for entity/leader; **no marketing hire under him is publicly visible yet** |
| 3 | **Institutional / API & platform** (TradeStation Securities institutional; API engineering hiring) | No marketing owner identified publicly; product side: Trent Vukich, VP Head of Customer Experience Product Management | TITAN X release (fetched); careers page ("Sr. Manager, Software Engineering – API") | LOW — do not score until a marketing owner is attributed |
| 4 | TradeStation Technologies (platform subsidiary) | Michael Fisch, CTO/President | Leadership page | LOW — unclear it owns any marketing budget; parked |

Structural facts that shape everything: **there is no CMO** — marketing reports through a Chief Growth Officer (an org that thinks in acquisition metrics, not brand language). Crypto was sold in 2024. Parent is Monex Group (Japan), which pairs TradeStation with its Monex Securities US-equity renewal [that pairing: UNVERIFIED — from search snippet of Monex IR PDF dated May 12, 2026; the PDF itself blocked fetch with 403].

The explosion ratio holds even here: one "TradeStation" TAL row became four candidate teams, two of them actionable.

---

## STEP 2 — Trigger log (what the daily watcher would have appended today)

| Trigger | Team | Type / Tier | Date | Window math | Status **today (2026-07-27)** |
|---|---|---|---|---|---|
| **TradeStation Europe B.V. launched** — Amsterdam, AFM-regulated, 30 EEA countries, retail + institutional | Europe | Regional expansion / **Tier B** | 2026-06-10 | 0–6 months → open until ~2026-12-10 | **IN WINDOW, week 7 of 26** |
| **Peter Comstock = President of a 7-week-old entity** | Europe | New leader / **Tier A** | role public 2026-06-10 | days 30–90 of tenure | **LIKELY IN WINDOW** — tenure in role ≈ ≥7 weeks; exact start date needs one LinkedIn check [verify task] |
| **Zero marketing roles among all 24 open positions** while launching a 30-country entity and migrating flagship platform | Europe + US | Capability-gap evidence / **Tier D — ammunition only** | fetched 2026-07-27 | n/a | Observed on careers page today. Phrase honestly: *no marketing openings are posted*, not "they have no marketers" |
| **TITAN X platform** — announced Jan 6, 2026; beta → "broader rollout in the coming months" → intended to become THE primary client platform | US retail | Product launch / Tier B | 2026-01-06 announce | −6 to +12 weeks around GA | **Announce is out of window (~29 weeks old).** But GA/primary-platform cutover hasn't been announced yet → **WATCH with retrigger: "TITAN X general availability"** — that announcement reopens the window the day it drops |
| Heavy AI/data hiring (Principal AI Platform/Solutions Engineers, Principal Data Scientist, Enterprise Data Products Director, Sr. Product Owner CRM Platform) | US | Context / Tier D | fetched 2026-07-27 | n/a | A CRM-platform product owner + AI investment = a growth org rebuilding its data spine — receptive to data-driven marketing conversation |
| TradeOff sponsorship (gamified trading) | US retail | Context / Tier D | 2026 (search result) | n/a | Shows active sponsorship/partnership marketing appetite [UNVERIFIED — search snippet only] |
| #1 Innovation broker, StockBrokers.com 2026 review | US retail | Analyst-adjacent / Tier B | Jan 2026 | 0–8 weeks | **OUT OF WINDOW** — logged for narrative color only |
| Monex FY26: record TradeStation revenue; TITAN X + "MCP" named in results | Parent | Context | 2026-05-12 | n/a | [UNVERIFIED — IR PDF 403-blocked; do not use as a claim in copy] |
| Conference/exhibitor presence 2026 | US retail | Tier B | — | 8–14 weeks pre-event | **GAP:** no exhibitor evidence found in this session's searches (MoneyShow/TradersExpo lists not surfaced). Week-1 task: scrape exhibitor pages directly |

Discards: none needed — everything found attributed cleanly to a team. (The system logs discards; today there were none.)

---

## STEP 3 — Scoring

**Team 2, TradeStation Europe → STRIKE.**
Two triggers, different mechanisms and sources, both in window: *regional expansion* (launch, June 10) + *new leader in seat* (Comstock, pending one start-date check). Corroborated by Tier-D ammunition: a 30-country go-to-market with zero posted marketing hires, and no visible marketing bench under the new president. This is the textbook agency window: mandate exists, entity is live, team isn't built, and the leader is inside the 30–90-day prove-it phase.
*One honest caveat carried from Step 0: if Comstock's seat check shows he's EU-based, Gate 3 (lawful basis) blocks the send until legal signs off — the build can proceed, the send can't.*

**Team 1, US retail marketing → WATCH, two dated retriggers.**
(1) TITAN X GA announcement — reopens the launch window instantly; a platform migration touching every client is a demand/lifecycle-marketing surge. (2) Exhibitor lists for H2-2026 / H1-2027 trading events — check at T-14 weeks. One strong trigger today would upgrade this to SEQUENCE; it isn't there yet. This discipline — *not* mailing Carrucciu today with something generic — is the system working, not the system failing.

**Team 3, Institutional/API → not scoreable.** No attributed marketing owner. Task: identify who owns institutional marketing before any trigger can count. (Rule 1: no team attribution, no signal.)

**Team 4 → parked.**

---

## STEP 4 — Strike build for TradeStation Europe (the part Clay would normally polish)

### 4a. Buying group — manual method, no fabrication
Verified people (public sources only):
1. **Peter Comstock** — President, TradeStation Europe *(the buyer)*
2. **Tom Hammergren** — Chief Growth Officer, Group + Securities *(budget gravity; Europe growth rolls up somewhere near him)*
3. **Marco Carrucciu** — VP Marketing, Group *(whoever markets Europe initially likely borrows his team)*
4. **John Bartleman** — President & CEO *(air-cover audience only, never the outreach target)*

Manual completion steps (30–45 min, free): LinkedIn people-search "TradeStation Europe" for any marketing/growth title hired since June; LinkedIn search "TradeStation" + "international" OR "EMEA" marketing titles; company page follower-post check for launch-related posts (who posted = who owns comms).
**Emails: none are asserted here.** Manual path: press-release media contact (press releases carry a real @tradestation.com contact — establishes the domain pattern), then verify candidate patterns with a free verifier before any send. The strategy's rule stands: an unverified email is not a contact, it's a bounce that damages the domain.

### 4b. The "why now" narrative (goes in the brief and drives every touch)
> TradeStation launched TradeStation Europe B.V. on June 10 — an AFM-regulated Amsterdam entity serving retail *and institutional* investors across 30 EEA countries — under a newly appointed president, Peter Comstock. Seven weeks post-launch, the company lists 24 open roles and not one is marketing. CME Group's Head of EMEA publicly welcomed the launch, so the institutional side expects volume. Someone has to build European demand — brand-new market, no installed audience, GDPR-constrained channels — and right now there is no public evidence of an in-house team to do it. The president is inside his first 90 days: the window where external help is a fast win, not an admission.

### 4c. The copy (structure per copy rules: insight → problem we see in this exact situation → one proof line → soft CTA to an artifact)

**Artifact (the soft CTA object):** *"Year-One EEA Demand Playbook for US Trading Platforms"* — a 6–8 page teardown: how US brokers/fintechs that entered Europe built pipeline in year one; the 3 channel mistakes everyone makes under GDPR; a 90-day sequencing template. Behind a name+email trackable link.

**Email 1 (Comstock):**
> Subject options: `EEA demand` / `Amsterdam launch` / `year one in Europe`
>
> Peter — congrats on the June 10 launch. An AFM license covering 30 EEA markets on day one is a serious footprint, and I noticed CME's EMEA head publicly backing it.
>
> The pattern we see when US platforms enter Europe: the product and licensing land months before the demand engine does — careers pages show it (TradeStation's 24 open roles currently include zero marketing seats), and year one becomes brand-awareness spend that institutional sales can't use.
>
> We build demand programs for enterprise tech companies entering exactly this kind of cold-start market. We wrote up how the last wave of US trading platforms handled EEA year one — the three mistakes and the 90-day sequence that avoids them. Want me to send it over?

**Email 2 (+4 days, case-study angle):**
> Subject: `cold-start pipeline`
>
> Peter — one datapoint from the playbook I mentioned: the US platforms that won early EEA pipeline all sequenced institutional demand *before* retail brand spend — the reverse of what their US playbook said. It's a 10-minute read. Worth a look before the Q4 planning cycle locks?

**Email 3 (+5 days, breakup):**
> Subject: `timing`
>
> Peter — if building the European demand engine is already handled internally, ignore me with a clear conscience. If it's still on the "after we hire" list, the playbook is yours either way — it's the thinking we'd bring, free to steal. One word and I'll send it.

**LinkedIn:** bare connection request from the SDR + one Unbound leader, timed with Email 1. No pitch in the note.

*(Gate 1 note: the proof line stays generic — "enterprise tech companies" — until the conflict rules sign-off decides which client names are usable in copy.)*

### 4d. Human gate
This entire brief — teams, triggers, evidence links, copy — is what the reviewer would see in one screen. Approve / edit / kill. In this dry run: **it would ship pending two checks — Comstock tenure/location, and Gate 3 if he's EU-based.**

---

## STEP 5 — What happens after send (not demoable without infra, stated for completeness)
Reply webhook classifies; "send the playbook" gets the trackable link within 5 minutes; any positive = four touchpoints in the hour (reply, LinkedIn connects, call, asset); playbook viewed → Slack alert → warm call; forwarded internally → the forwardee joins the buying group. Everything logs to HubSpot under trigger type `regional_expansion + new_leader`, which is how Week 6 knows whether this trigger class books meetings.

---

## STEP 6 — What the paid stack would have added (the honest delta)

| Step | Manual today | With Clay/ZoomInfo |
|---|---|---|
| Team mapping | 4 teams, 2 leaders deep, ~40 min | Full marketing org per team with titles/locations in minutes |
| Buying group | 4 verified names, 0 emails | 5–8 contacts per team with waterfall-verified emails + phones |
| Comstock tenure check | Manual LinkedIn visit | Automatic job-change tracking across the whole TAL |
| LinkedIn engagement triggers | Not attempted manually | Post-interaction harvesting (who at TAL accounts engages with what) |
| Scale | 1 account ≈ 35–40 min of human time | The watcher does this for 25+ accounts daily, unattended |

What the paid stack would NOT have added: the triggers themselves, the window math, the narrative, or the copy quality. **Everything that decided "strike Europe now, watch US retail" came from free sources.** That's the point of the architecture — Clay buys reach and contact data, not judgment.

---

## SOURCES (fetched + verified today unless marked)
- https://www.tradestation.com/why-tradestation/leadership/ — leadership/org structure ✔ fetched
- https://careers.tradestation.com/jobs — all 24 open roles ✔ fetched
- https://www.tradersmagazine.com/xtra/tradestation-expands-into-europe/ — Europe launch, June 10, 2026; Comstock; CME quote ✔ fetched
- https://fxnewsgroup.com/forex-news/platforms/tradestation-securities-announces-upcoming-launch-of-titan-x-trading-platform/ — TITAN X, Jan 6, 2026; rollout plan; Vukich ✔ fetched
- https://medium.com/authority-magazine/marco-carrucciu-of-tradestation-on-how-to-lead-a-successful-marketing-management-team-f2e753da6aa3 — Carrucciu VP Marketing, Aug 14, 2025 ✔ fetched
- Monex Group FY2026 results PDF (monexgroup.jp, May 12, 2026) — [UNVERIFIED: 403 on fetch; claims from it excluded from copy]
- TradeOff sponsorship, StockBrokers.com award — [search snippets; used as color only, not in copy]
