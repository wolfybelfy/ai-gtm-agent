# Claude Code + Clay GTM stack — learnings from 7 videos (2026-07-26)

**Evidence basis.** 7 unique YouTube videos (one URL was duplicated in the request). Video 1 studied at full fidelity: complete captions + all 64 extracted frames read. Videos 2–7: **complete captions read, no frames** — user directed transcript-only mode for speed. So for videos 2–7 every claim below is *what the presenter said*, not what I saw on screen. No frames were observed for those six.

All 7 had native captions; none required Whisper. Video 2's *video* download failed on the first attempt (yt-dlp exit 1); transcript mode bypassed the problem.

## The videos

| # | Title | Channel | Len |
|---|---|---|---|
| 1 | Clay + Claude Code Now Builds Your Whole Outbound Workflow From One Chat | Tim Yakubson | 22:32 |
| 2 | Claude + Clay = Endless Lead Generation! | Brendan Jowett | 8:23 |
| 3 | Claude Code + Clay Makes Lead Generation Actually Fun | Nate Herk \| AI Automation | 18:02 |
| 4 | Claude Code + Clay.com Destroys Any Marketing Team | Eric Nowoslawski | 11:53 |
| 5 | Use Claude Code for (Almost) Free Unlimited Web Searches (Like Claygent but Free) | Jordan Crawford (Blueprint) | 14:35 |
| 6 | Claude Code + SignalBase + Clay: The ABM Play That Replaced 10 Hours of SDR Work | Tanay Mishra | 16:40 |
| 7 | GTM Engineering With Claude Code (FULL GUIDE) | Michael Saruggia | 13:57 |

## 1. The core fact: Clay shipped an official Claude Code plugin

- Marketplace repo **`github.com/clay-run/agent-plugins`** — *verified on screen*, video 1 frames at 07:15–07:23.
- Install = `/plugin marketplace add` → `/plugin install` → restart. Video 3 adds a constraint: the **marketplace must be added from the Claude Code terminal**, not the desktop app or VS Code extension. Once added, it's usable from any surface.
- Auth is OAuth-style: ask Claude to help authenticate → it loads Clay's own setup skill → returns a link → choose workspace → authorize. (Video 3. Terminal line-wrapping mangles the link; copy-paste manually.)
- Surfaces as a **Clay MCP server** + a set of skills. Exposes a `clay` CLI — *"A JSON-first command-line interface for working with Clay"* (verified on screen, video 1 @18:21). Actions: find email, enrich person/company, phone lookup, read/edit table nodes, validate workflow, workflows (agents, triggers, scheduled runs), plus credit-optimization skills.

**Naming trap:** beta name was **Terracotta**; shipped name is **Workflows**. Videos 1, 2 and 4 all say "terracotta" throughout — 1 and 2 insert explicit corrections. Substitute when copying any prompt.

## 2. The division of labour that actually matters (video 4 — Eric Nowoslawski)

Nowoslawski is the most operationally credible source here: claims his agency is Clay's largest user, worked at Clay in 2023, runs 200–300 positive replies/day across clients. **All self-asserted, unverified.**

His rule, which is the single most transferable idea across all 7 videos:

> **Anything cheap/free and scaled across the whole list → Claude Code. Anything prospect-facing → orchestrate through Clay.**

Rationale, verbatim: *"every time you vibe code an orchestration layer, one, it breaks and you have to figure out why or two, sometimes there will be logic built in and then there will be an edge case that you didn't think about and then that turns into a mistake in the campaign and we just can't have that."*

His actual architecture:
- Company list sourced from Clay (he rates Clay's **derived data points** — business type, growth stage, pattern tags, primary offerings, how they make money).
- Enrichment done free/local in Claude Code: **Blitz API** for team composition (sales vs marketing head count, leaders vs ICs), **`html-to-text`** (open-source) to pull homepage text and find CTA keywords / sitemap / pricing page, then **Gemma 12B running locally** to classify (has book-a-demo? pricing tiers? enterprise tier? free trial?).
- All of it lands in **Supabase** as the TAM store.
- Nightly at 02:00 he pushes Supabase → Clay via webhook (rate-limit respect), where **Claygent** writes the one prospect-facing custom line, QA'd, then into **SmartLead**.
- Named campaign result: **12,000 contacts → 37 positive replies** (~0.3%).

He also open-sourced a browser-automation repo (via "browser use harness") that builds Clay tables for you — and says it's obsolete within a month or two once Clay's native workflows ship. **I did not verify this repo exists; he never states the URL in the transcript.**

## 3. Jordan Crawford's angle (video 5) — the one that matters for our engine

Same Jordan Crawford already in `conversation-signal-engine-principles`. This video is an unpolished live work session, not a tutorial.

- Core observation: Claude Code sub-agents doing web search = **"free Claygent."** He pays $100–200/mo for Claude and gets parallel web research bundled.
- **His stated caveat, which is the important part:** *"there's no observability here, so I don't exactly know what's going on... I'm not replacing Clay with this."* Same conclusion as Nowoslawski, arrived at independently.
- The play he ran: 99 records of *past customers **and** who those customers invited* to events → two-sided marketplace understanding → match against a new list to find lookalike prospects for a Kentucky Derby side-event. He used **Exa** websets for the decision-maker search.
- **The gem, and it's ours:** he judged the signal by **signal density in the market** — "you have sort of an understanding what is the density of this signal in the market... knowing if they enjoy sports is going to be hard, but all these other things are great matches." He found the fill rate on "publicly into sports" too low to build on, and said so rather than shipping it. That is signal-quality discipline as a live practice, not a slogan.
- Strategic framing worth keeping: **"This is the Uber era of AI"** — providers are subsidising inference/web-search the way Uber subsidised rides; the arbitrage closes. Build the muscle while it's cheap.

## 4. The signal play (video 6 — Tanay Mishra)

Closest thing to our engine's shape. Claude Code + **SignalBase** (signal aggregator: funding, M&A, champion job changes) + Clay + Slack.

- `workflow.md` file holds the whole instruction set; run via `execute workflow.md`; schedulable by cron (he suggests 15-min to weekly cadence).
- Flow: SignalBase API → Indian companies funded in last 14 days → **parallel Exa deep-research per company** → classify service fit (outbound vs paid ads) with justification → push qualified only into Clay → Slack ping to SDRs.
- **Disqualified ~50% — 25 companies in, 11 qualified out.** The fact that his workflow *rejects* is the most valuable detail in the video.
- His own restraint on the generated pitch: *"we wouldn't rely on AI to do something as important as this"* — treats it as SDR enablement, not send-ready copy. That is exactly our champion-enablement-toolkit framing.
- Funding-as-signal reasoning is sound but generic: cash + investor pressure + risk appetite. It's a **public, third-party signal** — precisely the commoditising category Poyar warned about. Everyone with a SignalBase key sees the same funded companies the same morning.

## 5. Prompt/operating discipline worth stealing

- **Force clarifying questions before building.** Video 1, literal appended string: `ask clarifying questions before actioning`. His analogy: otherwise it's a new sales hire given six lines and made to guess every decision. Echoed by Nowoslawski, who ends his prompts with *"Would you have any questions for me?"*
- **Test at 10 before full scale** (video 1) — otherwise you burn credits on wrongly enriched/qualified data.
- **Bring your own API keys** for enrichments you already pay for (video 1 names Prospeo, FullEnrich, ZenRows) to route around Clay credits.
- **Goal prompts / `/goal`** (video 3): set an end condition, let it work until met. Nate's run spawned 6 sub-agents by city (Houston, San Antonio, Atlanta, Charlotte, Tampa, Las Vegas), 25 shops each, then aggregated, deduped, checked yield, and ran verification passes — including agents *debating* whether subject lines were good. Took ~1 hour vs 5 minutes for the naive version. **172 Clay credits ≈ $12 for 50 enriched leads with copy.**
- **Context files are the prerequisite** (video 3): business profile, case studies, FAQs, proof, offer, website copy. *"If Cloud Code currently knows nothing about you, it'll be pretty hard for it to write really good cold email copy."*
- Nate's honest framing: **Clay fixes the data problem, Claude Code fixes the tool problem.** Best one-line summary of the whole stack.

## 6. Where this stack is weak — read against our engine principles

1. **It is an execution layer, not a signal layer.** Every video compresses the *build* step. None improves signal quality. Our recorded principle stands: signal ≠ intent, and the moat is proprietary first-party signal + CRM embeddedness, not tooling. Cheaper Clay tables commoditise fastest.
2. **Most demos are exactly the spray motion we're designed to beat.** "All London recruitment agency decision makers, as many per company as possible" (v1); "furniture suppliers in Melbourne" (v2); "run it overnight, wake up to 500–2,000 leads" (v2, v3). No fit-VETO, no corroboration requirement, no buying-group logic. Volume × personalisation ≠ relevance.
3. **Three independent operators converge on: keep a deterministic, observable layer between the agent and the prospect.** Nowoslawski (edge cases become campaign mistakes), Crawford (no observability), Mishra (won't ship AI-written pitch). This is a genuine finding, not one person's opinion — and it argues our Clay/HubSpot layer should stay authoritative rather than being dissolved into agent calls.
4. **Everything prospect-facing needs QA you can see with your eyes.** Nowoslawski: *"I've had campaigns where I didn't really know exactly what was going on cuz I just tried to vibe code the entire thing and it always turned into a mess."*
5. **Ungrounded claim to pressure-test:** video 3's waterfall-enrichment figures (single vendor ~30% hit rate vs Clay waterfall 80–90%). Presenter's assertion; matches the "95% vs 30%" claim already flagged as unverified in `2026-07-25-gtm-knowledge-and-gems-synthesis.md`. **Test against our own match rates before repeating.**

## 7. Directly actionable for Unbound IA

- **Adopt the Nowoslawski split explicitly** as an engine design rule: free/cheap/at-scale enrichment in Claude Code → our own store; anything a prospect will read goes through the deterministic layer with visible QA. Add to engine principles.
- **Adopt Crawford's signal-density check** as a gate *before* building any signal into the engine: measure fill rate across the target market first; if the signal is sparse, say so and drop it. This operationalises "signal ≠ intent" — it's the missing measurement step in our current scoring design (proprietariness × fit-VETO × corroboration).
- **The `workflow.md` + cron pattern (v6)** is a clean implementation shape for our signal→brief pipeline, and it produces disqualifications, which our design requires.
- **Local small models (Gemma 12B) for classification** is a real cost lever for high-volume, non-prospect-facing judgement — relevant if we classify at TAM scale.
- **Security note, unchanged:** none of these videos treats scraped/third-party text as untrusted. Our LinkedIn prompt-injection defence (see `conversation-signal-engine-principles`) is not addressed by any of this tooling and remains ours to build.

---

# ADDENDUM — videos 8 & 9 (added same session)

Two further videos, transcript-only, complete captions read. These are **materially more relevant to our engine than videos 1–7**: both are about signal *scoring and qualification*, not Clay-table execution.

| # | Title | Channel | Len |
|---|---|---|---|
| 8 | Build a GTM Alpha Signal Machine with AI + Python (Next-Level Lead Gen) | Josh Whitfield | 9:49 |
| 9 | Signal-Based ABM Workflow for B2B SaaS | Rebecca Akparanta | 8:12 |

## Video 8 — "GTM Alpha" (Josh Whitfield)

Concept credited on-record to **Kareem, founder of Clay**, from a post ("I didn't coin the phrase"). Definition given: everyone pulls the same LinkedIn-derived lists and enriches them; **alpha is the signal you derive that is genuinely indicative that someone needs your product** — i.e. edge, in the investing sense.

The framing that matters, in his words:
> *"just imagine if you send 300 emails... to the exact people who need your service. You're going to get a lot of engagement. The other side of that is you send 3,000 emails to people who just happen to be in a role of someone that may or may not need your service, then you could get equal or much less engagement."*

He claims to have run this "to the tunes of millions" of sends and seen **small precise campaigns beat large imprecise ones outright**. Unverified, but it is the same bet our engine makes.

**Two transferable mechanics:**
1. **Signal *combination* and weighting is the alpha, not signal collection.** *"Anybody that does this at a professional level knows how to collect funding data, but combining data and weighting that data and scoring that data based off mathematical parameters — that really changes the value of the score."* His worked example: job-postings count >20 AND headcount growth >20 → "high growth hiring strategy"; then compound with new office, distributed team, acquisitions, leadership change. **This is corroboration-count scoring under a different name** — independent confirmation of a principle already in `conversation-signal-engine-principles`.
2. **Deliberately prompting for non-obvious signals.** He pushed the model with *"I want signals that nobody else has thought of"* and got back a category it labelled **"advanced non-obvious signals"** — e.g. office *downsizing* signals, geographic dispersion signals. Cheap, repeatable technique for signal ideation; directly usable for our micro-campaign pain hypotheses.
3. He calls out that **lead scoring and routing is the under-attended part**: *"this is the part I don't think a lot of people focus on, which is lead scoring and routing."*

**Honesty of the source:** unusually high. He says plainly *"we don't really know where we're going with this,"* *"we're not there, we've got a lot of work,"* and *"it's definitely not a final product."* Nothing is being sold in-video. Tooling is **Manus** (agent) + Apify + Clay + Python, not Claude Code — so the architecture, not the stack, is what transfers.

## Video 9 — Signal-based qualification engine (Rebecca Akparanta)

**This is the closest thing in all 9 videos to what we are building.** A working ABM qualification workflow, demoed end to end on sample data. Not a Clay/Claude Code video at all — looks like a visual workflow builder (n8n-class) + Google Sheet + Slack + HubSpot.

Architecture, in order:
1. **Daily cron node** — fires 08:00 every morning.
2. **Data source** — Google Sheet in the demo; she explicitly notes it *"can easily be replaced with a CRM, your HubSpot exports, or any data source."*
3. **ICP definition node runs *before* scoring** — defines the profile, then assigns weights to buying signals.
4. **Enrichment + scoring** → computes an **ABM score**, and critically **records which signals fired** alongside the number.
5. **Assigns an outreach angle** per account (e.g. "timing urgent," "gap finding").
6. **Tiering into HOT / WARM / WATCH / SKIP**, with explicit routing rules per tier.
7. **Routing by tier:** HOT → AI research prompt generated → Slack notify → HubSpot company record created. WARM → queued for additional research. WATCH → monitored until stronger signals appear. SKIP → dropped.
8. **Campaign summary** — tier distribution, average score, most common buying signal.

**Four points of independent convergence with our recorded principles:**
- **Signals are explicitly weighted by strength, not counted flat.** Her example: *"hiring a GTM engineer is definitely a stronger buying signal than simply having an active founder on LinkedIn."* That is our proprietariness-tier idea, arrived at independently — and note the LinkedIn-activity signal is ranked *weak*, exactly as Crawford argues.
- **Human-in-the-loop is a deliberate design choice, not a limitation.** *"I intentionally kept a human review step here before any outreach is created... there will be no draft done."* The production version could auto-draft and auto-send; she chose not to. WARM tier explicitly *"would need a human in the loop to do an extra search, and a human to okay this."*
- **The Slack payload is a brief, not an alert** — signals found, outreach angle, and next step. Champion-enablement toolkit shape, matching our SDR-brief design.
- **A WATCH tier exists.** Accounts that don't qualify aren't discarded, they're monitored until stronger signals appear. This is the missing state in most designs and it directly implements the "recycle workflow" our HubSpot lifecycle note demands (lifecycle only moves forward, so you must build recycle explicitly).

**Limits, stated plainly:** it runs on embedded sample data, not live production; account-level only, with contact enrichment deferred ("for now, this is just account base"); tier distribution in the demo was one account per tier, so nothing about yield or precision can be inferred. She is demonstrating a design, not reporting results. No product is sold in-video.

## What videos 8 & 9 change for us

- **Whitfield gives us the ideation method** (prompt explicitly for non-obvious signals; weight and combine rather than collect) and the **language for the pitch** — "GTM alpha," a Clay-founder-originated term, is a sharper frame for our differentiation than "signal discipline."
- **Akparanta gives us a reference architecture** for the qualification engine: ICP-first → weighted score → *record which signals fired* → tier → route by tier → human gate → Slack brief → CRM write, with WATCH as a first-class state. Worth diagramming against our current design to find gaps.
- **Both independently confirm the fit-VETO / corroboration model** without either citing our sources — Whitfield mathematically (combine + weight), Akparanta structurally (tiering + routing rules).
- **Neither addresses signal provenance or injection risk.** Still ours to build.

## Caveats on the sources themselves

Six of seven are monetised: Clay affiliate links (v1, v2, v3), paid communities/courses (v1 $49/mo, v3, v7), agency services (v1, v4, v7). Video 5 (Crawford) is the only one not selling something in-video, and he discloses an Exa deal. Videos 1 and 2 disclose Clay beta access. Treat performance numbers as marketing claims unless independently verified.

Unverified numeric claims collected here for later checking: 200–300 positive replies/day and "largest Clay user" (v4); 12,000→37 replies (v4); 172 credits ≈ $12 for 50 leads (v3); 30%→80-90% waterfall lift (v3); 70 clients (v1); Clay $100M Series C at $3.1B (v1 — *this one I did see on screen*, a Pulse 2.0 article dated Aug 6 2025); "50% of venture-backed companies now hire GTM engineers" (v7); "Anthropic's growth marketing team is one person" (v7, sourced to a Reddit post).
