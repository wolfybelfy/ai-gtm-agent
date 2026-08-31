# TRIGGER-TO-MEETING SYSTEM — Strategy for Approval
**Unbound IA · 2026-07-26 · Fresh build (no prior internal work referenced)**
**Sources: 14 YT transcripts read in full this session + live Substack/newsletter research run this session (section 4). Every mechanic below traces to one of those two; video performance numbers are self-reported and used for mechanics only.**

---

## 0. THE ONE-PARAGRAPH VERSION

We stop targeting companies and start targeting **the specific marketing team that owns a budget** inside each TAL account. A daily watcher (free, in Claude Code) catches **trigger events** that predict an agency purchase — new marketing leader, marketing hiring surges, acquisition integrations, launch/event/expansion windows, and marketing leaders at TAL accounts engaging with demand-gen content on LinkedIn. When **two or more triggers stack on the same team inside their time window**, Claude Code + Clay build the buying group, write a "why now" narrative and sequence from the actual evidence, a human approves it, it sends with a **soft CTA to a trackable asset**, and every positive reply gets **four touchpoints within the hour**. HubSpot records everything; a weekly loop kills signals that don't produce meetings. Nothing prospect-facing ever auto-sends.

Why this wins: 3% of any market is in-market at a time (transcript #10). Everyone else sprays the other 97% or buys the same commodity intent feeds. This system's only job is to find the 3% *inside accounts we already chose*, at the team level, with evidence — and get there in the window.

---

## 1. THE TARGETING UNIT — marketing teams, not logos

At 500–10,000 employees (and far beyond, for the multi-billion accounts on the TAL), "VP Marketing" exists many times per logo. Budgets live with product lines, regions, and acquired brands. ServiceNow post-Armis is the pattern, not the exception: the Armis marketing team, the security product-marketing team, and regional field marketing are **three different buyers with three different "why nows."** Treating them as one target is how outreach dies in a generic inbox.

**Rule 1: every row in this system is a *marketing team*, identified by account + business unit/brand/region + named leader.** A trigger that can't be attributed to a specific team gets logged and discarded, because the message it would produce is generic by construction.

**How teams get mapped (Day 1–5, mostly free):**
1. For each TAL account: pull marketing-titled people via ZoomInfo/Clay once, cluster titles by BU/product/region tokens ("Security PMM," "EMEA field marketing," "Armis demand gen").
2. Cross-check against the account's public job postings (which org is hiring marketers tells you which team has budget and headroom).
3. Newsroom/structure check for acquired brands still operating under their own name.
4. Output: `data/teams.csv` — one row per team: account, team name, leader, size estimate, region, relationship flag (existing/past client team? sibling of one?).

Expect 25 accounts to explode into 75–150 teams. That explosion *is* the addressable market — and each existing client team makes every sibling team a warm lateral path ("we already work with your X team" beats any cold opener in the transcripts or research).

---

## 2. THE TRIGGER LIBRARY — what we watch, and the window in which it's worth anything

A trigger is a question about what makes a marketing leader buy agency services **now** (transcript #10: signals are questions; derive them from why past deals actually closed). Each has a detection method that runs in our stack and an action window — outside the window it scores zero.

### Tier A — "budget + urgency proven" (strike on these)
| Trigger | Why it predicts a deal | Detect (tool) | Window |
|---|---|---|---|
| **New marketing leader at the team** (VP/head/CMO of the BU) | New leaders distrust inherited agencies and want fast wins they didn't have to build headcount for | ZoomInfo alerts + weekly LinkedIn check via Clay (sparingly) + press | Days 30–90 of tenure — before 30 they're listening, after 90 plans are set |
| **Marketing hiring surge at the team** (≥2–3 open demand-gen/ABM/field/PMM reqs) | Goals outrun team capacity; agency = capacity without headcount politics | Daily public ATS feed diff (Greenhouse/Lever JSON — free) | While reqs open |
| **Marketing req stale (60d+) or reposted** | They can't hire it; budget exists, work isn't happening | Same ATS diff vs. history | While open / 0–30d from repost |
| **Acquisition affecting the team** (close date, not announcement) | Two marketing orgs merging = demand continuity risk, rebrand work, integration campaigns | News sweep + press releases; log announce AND close dates | 0–9 months post-close |
| **JD language: "manage agencies/vendors" in a marketing req** | They are literally budgeting for external partners | Semantic JD read in ATS diff (§4.1) | While req open |
| **Past champion lands at a TAL account** | A warm relationship beats every cold signal; agencies live on alumni networks | Named past-champion list (Week 1 interviews) + periodic Clay job-change check | Days 30–120 of new tenure |
| **Closed-lost account shows a fresh trigger cluster** | Timing killed the last conversation; a new-leader-plus-hiring cluster reopens it — and we know the original objection | HubSpot closed-lost sweep joined against the daily trigger log | While cluster in-window |

### Tier B — "dateable spend windows" (the timing edge — we can be early on purpose)
| Trigger | Why | Detect | Window |
|---|---|---|---|
| **Conference exhibit/sponsorship** (RSA, Black Hat, re:Invent, KubeCon, Gartner summits, vertical events) | Event demand-gen budget is committed and spent 2–3 months out | Weekly exhibitor-list scrape per event (free) + `data/event-calendar.csv` | 8–14 weeks BEFORE event; worthless at T-2w |
| **Product launch / GA** | Launch = demand gen surge, gaps show immediately | Newsroom + news sweep | −6 to +12 weeks |
| **Regional expansion / new market entry** | New region, no field marketing muscle there yet | News + hiring location shift | 0–6 months |
| **Analyst placement (Gartner MQ, Forrester Wave, GigaOm)** | Marketing must capitalize fast or the moment is wasted | Vendor newsrooms + analyst calendars | 0–8 weeks post-publication |
| **Rebrand / repositioning** | Everything downstream of brand gets rebuilt | News + site change | 0–6 months |
| **Funding round** (only for the smaller half of the TAL) | Growth mandate + investor pressure — but it's the most commoditized signal in existence; everyone sees Crunchbase | News sweep | 0–90d, low weight |

### Tier C — "self-made intent" (we create the engagement, then track it — never bought)
| Trigger | Mechanic | Source |
|---|---|---|
| **TAL marketing leader engages with demand-gen content on LinkedIn** | Clay's cookie-free post-interaction source: scrape likers/commenters of high-signal demand-gen posts (top voices + Unbound's own posts), filter to TAL accounts + ICP titles | Transcript #12 (mechanic), #13 (philosophy: make your own intent) |
| **Prospect opens/spends time on our tracked asset, or forwards it internally** | Gated trackable link (name+email) on every lead magnet; view → Slack alert → warm call; a forward = a new buying-group member self-identified | Transcript #13 |
| **Reply of any kind** | Classified within minutes (see §5) | Transcript #13 |

### Tier D — "message ammunition only" (never triggers outreach alone)
Observable capability gaps that make the email specific: running paid ads with no gated asset behind them; product launch with no webinar/campaign visible; content/blog cadence dead ≥90 days; exhibiting at an event with no pre-event campaign. Collected during strike research, cited as evidence in copy ("you're exhibiting at Black Hat in 11 weeks and there's no pre-event capture running").

**Excluded on purpose:** bought intent-topic feeds (commodity, resolves to the logo not the team — and the strongest practitioner voice in the transcripts calls it garbage outright), Reddit/community listening, our own website visitor de-anonymisation (no traffic, dead input).

---

## 3. SCORING — arithmetic, not vibes

Per team, daily (transcript #8: combining and weighting mathematically is what turns data into alpha; #9: define ICP fit *before* scoring):

**Disqualifiers first (binary, checked before any score):**
- Team belongs to a current client's direct competitor (conflict list signed by sales leadership — an agency serving Cisco/AWS/Rubrik-class logos can lose a multi-team relationship with one bad email)
- Team is an active client or in an open opportunity / 90-day suppression (HubSpot lookup — transcript #14's suppression discipline)
- Region we can't lawfully cold-contact yet (GDPR gate, §7)

**Then:**
- **STRIKE:** ≥2 triggers from Tiers A–C on the same team, both in-window, from different sources. → Full build within 24h, SDR owns it same week.
- **SEQUENCE:** 1 Tier-A trigger in-window. → Buying group + sequence, no SDR call time until engagement.
- **WATCH:** 1 Tier-B trigger, or anything strong but out-of-window. → Log a re-check date computed from the window (e.g., exhibitor confirmed for May event → resurface in February). This calendar of *future* strikes is the compounding asset.
- **NOTHING:** log it, move on. Volume is not the goal.

All weights start as hypotheses. The weekly loop (§6) replaces them with our own reply/meeting data — the single highest-leverage discipline in transcript #10 (they derive signals from closed-won deals, not from content).

---

## 4. WHAT THE LIVE RESEARCH ADDED (Substack sweep, this session — 14 fetch-verified sources, appendix at end)

Five findings changed this plan; the rest confirmed it.

**4.1 Read job posts semantically, not by keyword (Crawford, Blueprint).** Keyword alerts on job postings are commoditized — everyone gets the same "they're hiring" ping. The non-commoditized version: read the full JD text and extract *what problem the company is publicly funding a salary to fix*, with verbatim quotes as evidence. "A job post is a company describing, in public, a problem it will pay a salary to fix." This runs free in Claude Code over the same ATS feeds we're already diffing. → Upgrades the entire hiring-trigger tier in §2: the watcher doesn't just count reqs, it quotes them ("the JD says 'build our first ABM motion from scratch'" is copy ammunition no tool sells).

**4.2 Backtest every signal against four cohorts before trusting it (Edmondson, DemandLoops; Maniar via The Signal).** Test each trigger against Closed Won, Closed Lost, disqualified, and stalled deals: keep only what's present in Won and absent elsewhere. Her client's G2-review-spike signal — widely sold as intent — appeared in under 30% of closed-won deals and got killed. And validate on *revenue outcomes, not reply rates* (replies flatter signals that book nothing). → §6 now includes a one-time backtest against Unbound's own HubSpot closed-won/lost history in Week 2. Sarah Bedell's 9-month retrospective adds the humility: her initial signal assumptions were "99% wrong" until iterated — which is exactly why weights start as hypotheses here.

**4.3 Two triggers the videos didn't have, both free for us:**
- **Closed-lost / past-prospect reactivation clusters (Poyar & Short, Growth Unhinged):** watch old closed-lost and gone-cold accounts in HubSpot for *clusters* of new triggers (new leader + hiring + launch), and reference the original reason the conversation died. Timing becomes dynamic instead of "quarterly re-engagement cadence." Unbound has years of these records sitting in HubSpot — this is a Day-1 input, zero new data needed.
- **Champion job-change (Poyar & Short):** every past client contact and warm relationship who lands at a TAL account is a warm path that beats any signal. For an agency with Dell/Cisco/AWS/Rubrik-class alumni networks this may be the single highest-conversion trigger in the system. Detect via periodic Clay job-change checks on a named list of past champions (build the list in Week 1 — it's an interview task, not a data purchase).

**4.4 Cost-ladder + verification discipline (Crawford's "Crawford" agent architecture, Blueprint).** Order every enrichment/research step by cost floor: free public sources → cheap structured lookups → small/cheap model processing → a full Claude agent only on stubborn rows, with a hard tool-call cap. Two independent sources must agree before a fact ships (aggregators can't corroborate each other); uncertain rows route to a human with a decision packet. His warning is the operating principle for our rollout pace: *"Scaling this to a thousand companies without doing the hard thinking first is like pointing a thousand cars off a cliff."* → Encoded in §5.1 (free layer first), §5.2 (Clay only for final-mile), and §8 (manual reps before automation).

**4.5 Where the reasoning lives (Sachin Jha, OneGTM; Everett Berry, Clay, via GTM Council).** The converged 2026 pattern: Clay stays as data plumbing (list building, waterfall enrichment, sequencer export) and the *reasoning* — ICP logic, signal interpretation, narrative writing — moves into Claude with MCP connectors to HubSpot/Clay. Jha's cost driver: Clay credits punish iteration (self-reported 800–1,200 credits per 500-account campaign when reasoning lives in Clay). Berry's frame from inside Clay itself: winners "build highly customized stacks on top of flexible infrastructure." → This is exactly the §5 division of labour; treat it as settled.

**4.6 One more discovery method, free (Maniar; Berry):** the best custom signals are already inside the org — interview the people who close deals about what they manually look for before they call an account, then encode that. → Added to Week 1: a 45-minute interview with Unbound's account directors ("what did you notice about the last three clients right before they signed?") feeds the trigger library before any code runs.

**Also confirmed by research (no change needed):** generic AI personalization is "easily spotted from a mile away" and signal-rich outreach needs signal-rich personalization (Bedell) — §5.2's evidence-quoting narrative rule; "a signal on a new contact at a known account is intelligence, not a lead" and not every signal routes to sales (Full-Funnel) — §3's WATCH tier and Tier-D ammunition class; random-timing list blasts are dead (AI Product Bytes) — the whole premise. For public TAL accounts, SEC 8-K/10-K monitoring (leadership changes, acquisitions, new risk factors) is a free corroborating source (Visualping pipeline pattern) — added to the §5.1 news sweep for US-listed accounts.

---

## 5. THE MACHINE — who does what (division of labour is the whole game)

The strongest operators in the transcripts converge on the same split (explicit in #4, implicit everywhere): **anything cheap and internal runs free in Claude Code; anything a prospect will ever read goes through Clay with visible human QA; a vibe-coded pipeline never touches a send.**

### 5.1 Daily watcher — Claude Code, ~$0/day
A `watch.md` playbook executed daily (manually first, cron/routines only after Week 4 — transcript #6's cron pattern):
1. ATS feed diff per account → hiring triggers, read **semantically** (§4.1): count reqs AND extract the funded problem with a verbatim JD quote (needs a baseline: **start snapshotting Day 1**, staleness detection is impossible without history)
2. News/newsroom sweep → M&A, launches, analyst, expansion, rebrand, funding; for US-listed TAL accounts add SEC 8-K/10-K checks (free EDGAR, corroborates M&A and leadership changes from the primary source)
3. Event calendar check → teams crossing the T-14-week line
4. HubSpot joins: closed-lost accounts × today's triggers (reactivation clusters, §4.3); past-champion job-change check (weekly)
5. Weekly: LinkedIn engagement harvest via Clay post-interaction source; leader-in-seat checks on top teams
6. Output: append `data/triggers.csv` (team, trigger, evidence URL that resolved today, verbatim quote, window open/close) + scored tier + Slack digest to `#trigger-alerts`

Cost-ladder rule for every research step (§4.4): free public source first → cheap structured lookup → Claude subagent only on stubborn rows, capped. Two independent sources must agree before a "fact" enters a brief; aggregators don't corroborate each other; anything uncertain ships to a human as a question, not to a prospect as a claim.

Claude Code's built-in web search + subagents = the free research layer ("free Claygent," transcript #5 — and #5's discipline applies: before building on any new signal, measure its density across the TAL first; a signal that fires twice a year isn't a system input, it's luck).

### 5.2 Strike builder — Clay (paid, metered), triggered only by STRIKE/SEQUENCE
Via the Clay plugin for Claude Code (install once from the terminal: `/plugin` → marketplace → `github.com/clay-run/agent-plugins`, then OAuth — transcripts #1–3; verify the URL live at install time):
1. **Buying group:** 5–8 people per team — leader, demand gen, marketing ops, events/field, PMM as relevant. Waterfall email enrichment + validation + HubSpot suppression lookup. Test on 10 rows before any full run; pin our own provider API keys (ZoomInfo) so Clay credits only cover what we can't get elsewhere (transcript #1's two credit rules; #14's Apify-class cost arbitrage where it fits).
2. **Why-now narrative:** Claude writes one paragraph per team from the actual trigger evidence — quotes the JD, names the event, dates the acquisition. If the narrative reads generic, the strike is downgraded, not "improved with adjectives."
3. **Copy:** 3-email sequence + LinkedIn connect note + 3 short subject variants (deliverability + testing, transcript #14). Structure per #10: *researched insight → problem we typically see in exactly this situation → one-line proof → soft CTA.* The CTA offers a specific artifact, never a meeting: a pre-event pipeline checklist, a post-acquisition demand-continuity teardown, a launch-window benchmark. Strip every AI formatting tell (em dashes, headers, bullet symmetry) mechanically before it reaches a human reviewer.
4. **Human gate:** reviewer sees team, triggers, evidence links, full copy in one Clay view. Approve / edit / kill. **Nothing sends without this click.** (Transcript #4 is blunt about why: vibe-coded logic hits an edge case exactly once, in front of a prospect.)

Context pack prerequisite (transcript #3): before any copy is written, `context/` holds Unbound's offer, proof points, client logos usable per the conflict rules, ICP pains by trigger type, and copy rules. Claude writing without this produces the generic slop this whole system exists to beat.

### 5.3 Send + air cover
- **Email:** through the sequencer chosen at Gate 2 (§7) — HubSpot sequences if Sales Hub seats exist, else a SmartLead/Instantly-class tool. Fresh secondary domains, 2–3 week warmup, ~30/day/inbox ceiling. Never from the main domain.
- **LinkedIn:** connection request (no pitch in the note — bare connects converted best in #13) from the SDR + one leader, timed with email 1.
- **Air cover (we're an agency — we should eat our own cooking):** LinkedIn matched audience of STRIKE teams only, running Unbound proof content for the 3–4 weeks the strike is live (transcript #10's ABM-ads-on-tracked-accounts play). Small budget, only on STRIKE tier.

### 5.4 Catch — where meetings actually get booked
Speed-to-lead is the most under-engineered part of every outbound stack in the research, and the cheapest edge (transcript #13, verbatim mechanics):
1. Sequencer reply webhook → classify: `meeting` / `send-the-asset` / `question` / `not-now` / `human-review` (anything ambiguous defaults to human-review, never auto-replied)
2. `send-the-asset` → pre-drafted reply with the gated trackable link, human approves, out in ≤5 minutes
3. Any positive: **four touchpoints inside the hour** — email reply, LinkedIn connect(s), SDR call, the asset itself
4. Asset viewed → Slack alert with phone + context → warm call ("you asked for the checklist yesterday" is not a cold call)
5. Asset forwarded → new person auto-added to the buying group, SDR notified: multithreading that the prospect did for us
6. `not-now` → HubSpot task at +90d, team stays on WATCH

### 5.5 System of record — HubSpot
- Companies: parent account + child records per marketing team (or team-name property if object model gets heavy — decide at 10-team test, not in a doc)
- Properties: `trigger_types`, `trigger_evidence_url`, `why_now`, `tier`, `window_close_date`, `suppression_until`
- Tasks: STRIKE acceptance task with a 24h clock; unaccepted strikes escalate in Slack
- Meetings/deals: standard pipeline; source = trigger type (this is what makes §6 possible)

---

## 6. THE LEARNING LOOP — kill what doesn't book

**One-time, Week 2 — the backtest (§4.2):** run every Tier A–C trigger against Unbound's own HubSpot history in four cohorts — closed-won, closed-lost, disqualified, went-dark. A trigger that shows up in won deals and not the others earns its weight; one that shows up everywhere (or nowhere) gets cut before it ever costs a send. This is the cheapest two days in the whole build and converts the library from borrowed hypotheses into our evidence.

Weekly, 30 minutes, in Claude Code against HubSpot + the CSVs:
- Per trigger type: fired → sent → replied → **meeting** (judge on meetings and pipeline, never on reply rate alone — replies flatter signals that book nothing, §4.2). Two weeks of sends with zero engagement on a trigger type = halve its weight; four = kill it.
- Per CTA artifact: request rate and view-to-call rate. Rotate losers out.
- Any meeting booked → 15-minute reverse-engineering note: which triggers, what timing, what copy angle. New trigger hypotheses come from here, nowhere else (transcript #10's closed-won discipline).
- Monthly: does STRIKE tier outperform SEQUENCE tier enough to justify SDR time allocation? If not, thresholds are wrong — fix the math, not the narrative.

---

## 7. GATES — things that block sends (not builds), with owners

| # | Gate | Owner | Detail |
|---|---|---|---|
| 1 | **Client-conflict rules signed** | Sales leadership | Named list: which competitor teams are untouchable while Cisco/Dell/AWS/Rubrik/Aqua/Bugcrowd/ServiceNow relationships stand. One email can cost a logo. |
| 2 | **Sending infrastructure** | Marketing ops | HubSpot-tier check; if no Sales Hub seats → SmartLead/Instantly-class. Buy 2–3 secondary domains **Day 0** so warmup runs during the build. |
| 3 | **Lawful basis for EMEA/APJ** | Legal | Documented per region before the first non-US send. |
| 4 | **SDR queue ownership** | Sales ops | Who accepts STRIKE tasks, who owns the 5-minute reply clock and the warm-call alerts. A system that alerts an empty room books nothing. |

All four run in parallel with Week 1. None blocks building.

---

## 8. ROLLOUT — six weeks, meetings before full automation

**Week 0 (2 hours):** Clay plugin installed + authed · HubSpot private app token · Slack webhooks (`#trigger-alerts`, `#hot-replies`) · buy + start warming send domains · smoke-test all three from one Claude Code session.

**Week 1 — map + baseline:** 25 TAL accounts → team mapping (§1). Start daily ATS snapshots immediately. Build event calendar for the rolling 6 months. Tag existing-client teams. **Two interviews (45 min each):** account directors — "what did you notice about the last three clients right before they signed?" (feeds the trigger library, §4.6) — and "name every past champion we'd want to follow" (feeds the champion job-change list, §4.3). **Checkpoint: if 25 accounts don't yield ≥75 teams, the thesis is off — stop and inspect before building more.**

**Week 2 — triggers live, backtest, first manual strikes:** Daily watcher running (manually executed). Run the four-cohort backtest against HubSpot history (§6). First 3–5 STRIKE teams built and sent **fully hand-driven** — Claude assists, human does every step. These manual reps are what we later automate; automating an unproven motion just ships mistakes faster ("a thousand cars off a cliff," §4.4).

**Week 3 — machine assembly:** Clay strike-builder table live (10-row tests first) · reply webhook + classifier · trackable assets built (one per top trigger type: pre-event checklist, post-acquisition demand-continuity teardown, launch-window benchmark) · HubSpot properties + tasks.

**Week 4 — pilot at 25 strikes:** Every send human-gated. Measure per §6. Air-cover ads on STRIKE teams if budget approved.

**Weeks 5–6 — scale the survivors:** Kill dead triggers · automate the daily watcher on cron/routines · loosen human gate to spot-check only for SEQUENCE tier (STRIKE stays fully reviewed) · expand from 25 accounts to the next TAL tranche.

**Success criteria for the pilot (honest numbers, not video numbers):** ≥75 teams mapped · ≥15 in-window multi-trigger strikes found in 4 weeks · reply rate on STRIKE tier ≥3× whatever the team's current outbound baseline is · ≥3 meetings from strikes by end of Week 6. If strikes can't beat baseline by 3×, the trigger library is wrong and §6 tells us which part.

---

## 9. COST ENVELOPE

| Item | Cost | Notes |
|---|---|---|
| Claude Code | existing subscription | watcher, research, copy, orchestration |
| Clay credits | metered — cap at a fixed monthly number Day 0 | only buying groups + final-mile enrichment; ~50 enriched contacts ran ≈$12 in transcript #3 (self-reported; treat as order of magnitude) |
| ZoomInfo | existing | pinned as own-key provider inside Clay |
| HubSpot | existing | tier check at Gate 2 |
| Sequencer + domains | ~$100–200/mo class + domain costs | Gate 2 decision |
| Trackable-link tool | ~$0–50/mo | or HubSpot tracked pages + gated form if tier allows |
| ATS feeds, news, exhibitor lists, Slack webhooks | $0 | the entire watch layer is free |

---

## APPENDIX A — verified external sources (live-searched AND fetch-verified in this session)

All URLs below were found by live web search and fetched successfully during this session. Two are partially paywalled (marked); claims cited from them come from the accessible portions. Every performance number in these sources is self-reported by the author — mechanics used, numbers not.

1. Jordan Crawford — On the Edge by Blueprint — https://edge.blueprintgtm.com/p/turn-a-million-job-posts-into-buying — semantic job-post pain reading over ~947K postings, evidence-quoting, liveness verification (§4.1)
2. Jordan Crawford — On the Edge by Blueprint — https://edge.blueprintgtm.com/p/introducing-crawford-a-claude-code — cost-ladder research agent, double-source verification, human review queue (§4.4) *(partial paywall)*
3. Jordan Crawford — On the Edge by Blueprint — https://edge.blueprintgtm.com/p/316-free-datasets-build-every-list — catalog of 316 free public datasets for list/signal building *(partial paywall)*
4. Kyle Poyar & Maja Voje — Growth Unhinged — https://www.growthunhinged.com/p/2026-claude-code-gtm-report — survey of 200 GTM operators: CLAUDE.md context + skills + MCP as the minimum viable setup; Clay/HubSpot integrated, not replaced
5. Kyle Poyar & Brendan Short — Growth Unhinged — https://www.growthunhinged.com/p/the-best-ai-native-gtm-plays-you-re-not-running — closed-lost reactivation clusters; champion job-change graph (§4.3) *(partial paywall)*
6. Brendan Short w/ Soham Maniar — The Signal — https://www.thesignal.club/p/automating-signals-in-your-market — generic-vs-alpha signal split; interview-your-sellers discovery method; backtest on revenue outcomes (§4.2, §4.6)
7. Maja Voje — GTM Strategist — https://knowledge.gtmstrategist.com/p/how-to-build-gtm-campaigns-with-claude-code — live Crawford demo: context files, plan-before-execute, human override of AI pitch angle
8. Sachin Jha — OneGTM — https://sachcode.substack.com/p/im-moving-my-entire-gtm-workflow — Clay as plumbing, Claude as reasoning; credit-cost driver (§4.5)
9. Sarah Krasnik Bedell — Sarah's Newsletter — https://sarahsnewsletter.substack.com/p/building-a-repeatable-signal-based — 9-month signal-outbound retrospective; "signal-rich outreach needs signal-rich personalization"; initial assumptions 99% wrong
10. Andrei Zinkevich & Vladimir Blagojevic — Full-Funnel — https://fullfunnel.substack.com/p/signal-based-strategy — signal-to-journey-stage mapping; "intelligence, not a lead"; don't route every signal to sales
11. Kaylee Edmondson — DemandLoops — https://demandloops.substack.com/p/more-signal-data-wont-fix-this — four-cohort signal backtesting; G2-spike signal failing the test (§4.2)
12. Andy Mowat w/ Everett Berry (Clay) — GTM Council — https://gtmcouncil.substack.com/p/everett-berry-head-of-gtm-eng-clay — Clay-as-infrastructure; signals discovered from rep behavior (Canva story)
13. Ash — AI Product Bytes — https://productstudio.substack.com/p/everyones-doing-outbound-wrong-in — random-timing outbound is dead; signal-stack framing
14. Eric Do Couto — Visualping — https://visualping.io/blog/corporate-filings-intelligence-pipeline — SEC EDGAR (8-K/10-K) monitoring → webhook → CRM pipeline (vendor source)

**Known gaps, stated plainly:** Growth Unhinged play #4 (competitor tech-stack displacement) sits behind the paywall — mechanics unretrieved, so competitor-uninstall triggers are NOT in this plan's library. Claims that "free signals now rival paid intent data" circulated in search snippets but were not fetch-verified and are not relied on anywhere above. Nothing from Elena Verna / MKT1 / GTMnow was reached in this sweep; no claims are attributed to them.

## APPENDIX B — the 14 video transcripts (read in full this session)

On disk at `data/research/transcripts/01–14`. Mechanics drawn from: #1–3 (Clay plugin install/auth, clarifying-questions + 10-row-test credit discipline, /goal prompts, context packs), #4 (free-vs-Clay division of labour, observability, nightly batching), #5 (free web research via subagents, signal-density check), #6 (workflow.md + cron + signal API → qualify → Slack), #7 (provider routing, HubSpot MCP, RevOps hygiene), #8 (mathematical signal combination, non-obvious signals), #9 (ICP-before-scoring, tiering, human review), #10 (multi-signal "why now" stories, closed-won derivation, soft-CTA friction mechanics, air cover, integrated sales+marketing), #11 (keyword catch → AI relevance filter → Slack routing pattern), #12 (cookie-free LinkedIn post-engagement harvesting), #13 (anti-bought-intent, trackable lead magnets, reply classification, 4-touchpoint speed-to-lead), #14 (personalized offers from profile data, AI-tell stripping, subject variants, suppression + validation).
