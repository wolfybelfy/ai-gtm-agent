# MASTER PROMPT — ICP Conversion System (Unbound IA)
> Paste everything below into a new session. Last updated 2026-07-26.

---

You are helping me build an **ICP conversion system** — an AI-driven signal engine that ends in HubSpot with SDRs booking meetings. Read this whole brief before proposing anything.

## WHO I AM

Agentic marketing lead at **Unbound IA**, a B2B marketing agency. I own the AI/marketing side. I am **not** a sales-ops person — I do not know operationally how SDRs, SDR managers, AEs or account directors qualify accounts, score leads, or run HubSpot/Clay day to day. Teach me that where it matters; don't assume I know it.

I want deep, evidence-backed, **real-world practical** work — not textbook theory. I prize out-of-the-box, cross-domain thinking. Be terse and action-oriented. If something won't survive contact with a real office, say so.

## THE COMPANY (verified from unboundia.com, 2026-07-26)

- Positioning: *"brand-to-revenue partner for full-funnel growth"* · *"AI-powered, full-funnel marketing that links brand to demand"*
- Methodology: **Assess → Create → Activate → Convert**
- Services: GTM strategy & consulting · marketing & revenue ops · brand & content · **demand generation** · **ABM** · channel & partner GTM · media/PR/webinars · CRO & sales enablement
- The "Convert" phase explicitly includes *"CRO, lifecycle nurture, SDR enablement, lead scoring models"*
- Public clients: **Dell, Cisco, Bugcrowd, Aqua Security, Rubrik, AWS**; named testimonial from **Todyl** (CMO Polina Kazakova)
- **No quantified case studies or metrics are published anywhere on the site**
- Buyer stats they cite: 67% of B2B decision makers are digitally native millennials; 81% had already chosen a preferred supplier before engaging vendors

## OUR ICP

Tech · SaaS · B2B IT · computer/network security. Employee count 500–10,000. Series A/B/C. Titles: marketing manager and above, up to VP Marketing / VP Demand Gen. **The ICP is vast** — do not narrow to a fixed persona list. I'm not certain demand gen managers are even in it; most other marketing leadership titles are.

**Known contradiction, unresolved:** "500–10k employees" and "Series A/B/C" rarely co-occur (Series C is typically 150–500 people; nothing at Series C is 10k). Flag it if it matters to a recommendation.

**How our accounts are actually structured — important:** many targets are very large, multi-billion companies with separate departments, sub-companies and acquired entities, each with **its own marketing budget and team**. We did not work for AWS — we worked for **AWS OpenSearch**. Our priority account is **ServiceNow**, which completed its **$7.75B acquisition of Armis** (announced 2025, completed 2026, both press-released). Treating a company like this as one undifferentiated target is false practice.

## TOOLS WE ACTUALLY HAVE AND USE

**Clay** (team uses it for enrichment) · **HubSpot** (CRM/system of record) · **ZoomInfo** · **Claude Code**. Teams are already live on Clay and HubSpot. The goal is to connect these autonomously and go several levels up.

## THE GOAL

TAL → custom industry signals → HubSpot → automated multi-threaded outbound → **booked meetings.** Everything evidence-based. Signal-driven, high-intent, not volume.

---

## HARD CONSTRAINTS — already rejected. Do not propose these.

1. **No Reddit / Slack community / RSS listening.** Slack communities are paid ($35–100+). Reddit is baseless discussion with no enterprise signal. Textbook advice that dies on contact with enterprise B2B.
2. **No AEO/GEO or LLM-citation-teardown play.** Different service line, different buyer conversation. It does not sell demand gen.
3. **No first-party website intent** (ZoomInfo WebSights, visitor de-anonymisation). Our website is new — almost no ICP traffic. Anything built on our own visitors is dead.
4. **We already have a TAL.** Do not design list-generation. The TAL is the input.
5. **No abstract system names.** Name things for what they literally do.
6. **Don't hold back and don't be theoretical.** I want extraordinary, not competent.

---

## THE 14 VIDEO TRANSCRIPTS — full text, on disk

All captured 2026-07-26 via the `/watch` skill from native captions. **Read the ones relevant to what you're working on — don't work from summaries.**

Path: `data/research/transcripts/`

| # | File | Source | Covers |
|---|---|---|---|
| 1 | `01-clay-claude-code-outbound-workflow.md` | Tim Yakubson · 22:32 | Clay's official Claude Code plugin (`github.com/clay-run/agent-plugins`); beta name *Terracotta* → shipped as **Workflows**; install/auth; prompting discipline; credit control. *(only video where frames were also read — all 64)* |
| 2 | `02-claude-clay-endless-lead-generation.md` | Brendan Jowett · 8:23 | Clay plugin as an MCP-like surface in Claude Code; sourcing + enrichment in one chat; "find thought leadership" data point |
| 3 | `03-claude-code-clay-lead-gen-fun.md` | Nate Herk · 18:02 | `/goal` prompts; sub-agents fanned out by geography; verification passes and agents debating copy quality; context files; Clay credit costs; CSV → Clay campaign |
| 4 | `04-claude-code-clay-destroys-marketing-team.md` | Eric Nowoslawski · 11:53 | Where to run cheap/free enrichment vs. what goes through Clay; Blitz API, `html-to-text`, local Gemma; Supabase as TAM store; nightly batch → Clay → SmartLead |
| 5 | `05-claude-code-free-web-search-claygent.md` | Jordan Crawford · 14:35 | Measuring a signal's density in the market before building on it; Claude sub-agents as free web research; Exa websets; observability limits |
| 6 | `06-claude-code-signalbase-clay-abm-play.md` | Tanay Mishra · 16:40 | `workflow.md` + cron + signal API → parallel Exa research → qualify/disqualify → Clay → Slack to SDRs. End-to-end ABM automation |
| 7 | `07-gtm-engineering-with-claude-code.md` | Michael Saruggia · 13:57 | Data-provider routing (Forager/Serper); HubSpot MCP; RevOps automation; CRM data hygiene and enrichment at scale |
| 8 | `08-gtm-alpha-signal-machine.md` | Josh Whitfield · 9:49 | "GTM Alpha" (term credited to Clay's founder); combining and weighting signals mathematically; prompting for non-obvious signals; lead scoring and routing |
| 9 | `09-signal-based-abm-workflow-b2b-saas.md` | Rebecca Akparanta · 8:12 | Working qualification engine: cron → ICP defined before scoring → weighted signals → tiering → routing → Slack + HubSpot, with a human review step |
| 10 | `10-custom-buying-signals-nobody-uses.md` | Tom Grainger + White Whale · **40:54** | **Richest one.** Custom signal design; why multiple simultaneous signals matter; "why reach out now" narratives; deriving signals from closed-won deals; soft CTA and friction mechanics; multi-channel air cover; ABM + ads on tracked accounts |
| 11 | `11-clay-signals-capture-hot-leads.md` | hapily · 4:12 | Clay Signals product; custom signals; keyword catch → AI relevance filter → Slack |
| 12 | `12-clay-outreach-765-meetings.md` | Oskar Moen · 11:10 | Clay's cookie-free LinkedIn post-interaction source; filtering engagers to ICP; export to LinkedIn sequencer |
| 13 | `13-clay-auto-reply-books-meetings.md` | Xavier Caffrey · 19:58 | Case against bought intent data; trackable lead-magnet links; reply classification with a human fallback label; speed-to-lead with four touchpoints in ~an hour; engagement + internal forwarding as signals |
| 14 | `14-claude-clay-workflow-books-meetings.md` | Nishil Prasad · 13:27 | Claude-written personalised pitches from LinkedIn data; enrichment cost arbitrage; stripping AI formatting tells; subject-line variants; suppression lookups; email validation |

**Evidence warning on all 14:** every performance number in these videos is self-reported by someone selling a course, an agency, or an affiliate link. Use their **mechanics**, never their **numbers**. Videos 2–14 are transcript-only (no frames), so anything visual in them is unobserved.

## OTHER RESEARCH ON DISK

| File | What it is |
|---|---|
| `data/research/2026-07-25-gtm-knowledge-and-gems-synthesis.md` | Deep GTM research — signal quality, CRM embeddedness, buying groups, HubSpot lifecycle mechanics, sourced quotes with provenance |
| `data/research/2026-07-25-gtm-leadership-field-notes.md` | Field notes from the same research pass |
| `data/research/2026-07-25-servicenow-portfolio-worked-example.md` | ServiceNow account worked example |
| `data/research/2026-07-25-tradestation-worked-example.md` | Second worked example |

## WHAT I STILL DON'T HAVE

1. The actual TAL — how it's built, refreshed and owned (data team; I'm grey on this)
2. Which accounts we have existing or past relationships with, and at what level
3. Client-conflict rules — we serve Cisco/Dell/AWS/Rubrik/Bugcrowd/Aqua/ServiceNow, so prospecting their competitors is a live commercial risk
4. Closed-won history, 12–24 months
5. Clay plan and credit budget · HubSpot tier · who owns the queue · how many SDRs
6. Sending infrastructure: domains, ESP, warmup state, current deliverability
7. GDPR/regional constraints on who we may contact

## HOW TO WORK WITH ME

**Evidence discipline is non-negotiable** (see `C:\Users\admin\Documents\CLAUDE.md`):
- Never assume, infer or fill gaps without evidence. Label inference explicitly as inference.
- **Never output an external URL from memory.** Live-search it, then WebFetch-verify HTTP 200 before it goes in any deliverable.
- If a task produces N pieces of evidence, examine all N before describing them. Never present inferred content as observed.
- "Complete/full/all/every" are claims requiring you to have actually checked every item.
- If evidence is incomplete, say so plainly and ask.
- Verify statistics by fetching the source — search snippets misreport. (A "6x multi-threading" stat did not survive fetching; the real figure was 40–75%.)

Do not launch subagents unless I ask. Research freely — web, Substack, Medium (extract if paywalled) — when you're stuck or need grounding.

---

**Start by telling me what you'd build first and why, then ask me only the questions that would change your answer.**
