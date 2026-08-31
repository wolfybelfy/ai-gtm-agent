# Enrichment policy — when paid credits may be spent (USER RULE, 2026-07-29)

**The rule, in one line: free sources map the world; paid credits are spent ONLY on a team that has already earned a verdict.**

User directive (2026-07-29, verbatim intent, originally about Clay — Clay was REMOVED entirely
2026-08-24 by user order, but the principle stands provider-independent): do not enrich all
LinkedIn-related signals across the master map — "that will cost a lot, a lot of credits
repeatedly". Paid enrichment is reserved for "the verdict teams/dept/acquisition that you are
sure will work, only high-intent cells and profiles".

## Two tiers, hard boundary

### Tier 1 — MASTER MAP (free sources only, zero credits, runs on every account in accounts.csv — 65 as of 2026-08-14; count-free wording set 2026-08-15)
Sources: company sites, ATS feeds, SEC/EDGAR, newsrooms + press releases, leadership pages,
conference/exhibitor lists, speaker bios, webinar and podcast listings, public web search,
and the user's own signed-in browser for pages that block scripts.
Produces: org spine, teams, products, launches, acquisitions, geography, segments, martech stack,
events, and any leader whose name appears in a public source.
**Spends: nothing. Ever.** No paid-provider call is permitted from the mapping run — not one row.

### Tier 2 — VERDICT ENRICHMENT (credit-spending; SOLE provider: ZoomInfo [re-adopted 2026-08-20 by user order — the automated verified-email step, `scripts\zoominfo-enrich.ps1`, Monday stage 2c, hard per-run credit cap, `requiredFields:["email"]` so no credit is spent on a contact without an email]. Clay REMOVED entirely 2026-08-24 by user order — GO-1 is dead; there is no parallel enrichment path.)
**AMENDED 2026-08-04 (user decision): a STRIKE verdict IS the spend authorization — no per-run
human approval exists on this path anymore.** User's stated reasoning: the verdict gate already
limits enrichment to a few people per team; a few thousand credits are acceptable; and per-run
approval is operationally impossible (single-operator system).
Triggered by: **ANY play with a verdict — STRIKE or SEQUENCE — automatically (USER RULE
2026-08-21, verbatim: "Any play generated, wether sequence or strike - make sure they are
enriched through zoominfo! Dont worry about spend!" — supersedes the old SEQUENCE-needs-
explicit-request condition).** The per-run credit cap in `zoominfo-enrich.ps1` remains as an
anomaly guard (runaway-loop protection), not a spend gate.
Scope is the buying group for THAT ONE TEAM (the Champion / Decision-maker / Influencer triad; "Approver" role renamed 2026-08-16, no approval framing), not
the account, and never the whole map.
Preconditions, all required:
1. A verdict exists in `data/triggers.jsonl` with its evidence.
2. Disqualifiers already cleared (conflict list, suppression where checkable, country gate) —
   never spend credits on a team we are not allowed to contact.
3. The request is written to `staging/enrich/enrich-requests.csv` by `strike-build.md`,
   never by the mapper.
4. One-time 1-person canary verifies mechanics + measured price before the first full run
   (a smoke test, not an approval).

## Consequence, stated honestly (do not paper over)
Many team nodes in the master map will carry NO named leader at Day 1, because mid-level
marketing leads are rarely nameable from free sources. Under `scoring-rules.md` such a team is
`not_scoreable`. That is now intentional: **a team gets named when it gets hot, not before.**
This deviates from the plan's Phase-2 acceptance (">=75 scoreable teams"), which assumed leaders
would be mapped up front. Revised reading, logged as a deviation: Phase 2 counts *identified
teams with structural evidence*; leader-naming moves to the verdict step. Senior leaders (CMO,
VP-level) are frequently public and WILL be named for free where a source exists.

## Credit ledger
Every credit-spending run records: date, play_id, team, rows requested, credits consumed,
and what came back. No untracked spend. ZoomInfo runs log per-run credit counts in the
enrichment summary alert and `staging/enrich/enrich-results.csv`. (Historical Clay balance
notes removed with Clay 2026-08-24.)
