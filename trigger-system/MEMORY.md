# MEMORY — catch up here, any time
_The plain-English story of the trigger-based outbound system, for a human catching up cold.
**BUILD-STATE.md is the operational truth; on any conflict, it wins.** Rewritten in full
2026-08-15 (the previous version had frozen at 2026-07-28 and gone badly stale — a full-repo
sweep caught it). Update at session close only when the human-facing story materially changed._

## What this is, in one paragraph
Unbound IA stops blasting cold lists and instead watches **65 chosen accounts weekly** (Monday,
unattended) for public **buying triggers** — a new marketing leader, a hiring surge on one team,
an acquisition being integrated, a product launch, an upcoming flagship event. Triggers attach to
specific **marketing teams**, not whole companies. When 2+ independent triggers stack on one team
inside their time windows, the system builds a full play — evidence with fresh URLs, a buying
group, drafted emails — and then **the play's OWNER picks it up and runs it; a human sends,
always** (no approval workflow exists — user directive 2026-08-16). Results
are judged on **meetings booked, not replies**. Claude Code is the watching-and-thinking layer;
HubSpot is the system of record; the system itself has no code path to email a prospect, ever.

## Where things stand right now (2026-08-15)
- **65 accounts** in `config\accounts.csv` (26 → 36 on 08-02/03, → 65 on 08-14 from the Q2 Master
  TAL). The newest 29 are **watch-only until the user signs Gate-1 for that batch** (linkedin
  needs an individual ruling). Ownership follows the SD-owned model (AI-agentic-master sheet,
  HubSpot-verified 08-13); 10 accounts still point at ARCHIVED ex-staff owners — user decision.
- **The Monday watch is live and unattended** (Task Scheduler, Mon 08:30): deterministic capture
  of all 65 job boards + SEC filings (51 CIKs) + news RSS + stack tells, then a headless Claude
  triage writes the brief and queues human-readable alerts, then the Outlook mailer sends them to
  the internal team. First 65-account run: **2026-08-17**.
- **4 plays are built and READY — each belongs to its owner, none picked up yet** —
  thomson-reuters (Josh Dietert; strongest, 3 legs; SYNERGY angle dies 2026-09-21), servicenow
  (Navid; freshness re-check due 08-19), snowflake (Navid; owner picks the recipient at pickup:
  verify Bhat or re-target Leong), veeam (Kumar; window to 09-27). Braze is a SEQUENCE with no
  living owner (Rushab archived). **Pickup is the single bottleneck: 0 of 4 run.** Verified
  emails now flow automatically: ZoomInfo enrichment (stage 2c) fills eligible buying-group
  rows on every Monday run (live since 2026-08-21; every-play rule). LinkedIn connects need
  no addresses and can go the day a play is picked up.
- **One real CRM write happened** (2026-08-13, veeam play, user-authorized one-time exception):
  note + task on the company record, read-back verified. All further CRM writes wait on the
  RevOps audit. Sends additionally wait on deliverability evidence + a sequencer decision.
- **Clay REMOVED ENTIRELY 2026-08-24 (user order)** after its API started returning 402
  Payment Required (renewal was due 08-22, cancel-vs-renew had been open). Every live surface
  de-referenced; `CLAY_API_KEY` deleted; person-data staging renamed staging\clay\ ->
  staging\enrich\ (contents preserved). **ZoomInfo = the SOLE people-data + enrichment path**
  (direct GTM API, live since 2026-08-21, Monday stage 2c, every-play rule). Never re-adopt
  Clay without a new user decision.
- **What a meeting still needs, in order:** the owner picks up their play (addresses already
  ZoomInfo-verified by stage 2c) → deliverability evidence + sequencer (Gate 2, user side) → a human sends
  → replies land in human inboxes (the system has no reply-detection yet — known gap) → the SDR
  books; the booking is recorded manually for now (`data\metrics-weekly.csv` is still empty).

## The rails that never move
Humans send, always — each play run by its OWNER, and the run is recorded in the play's
status.md (RUN_BY/RUN_DATE — a log, not a gate; no approval workflow exists). No URLs from
memory — fresh fetch or it doesn't ship. Facts vs hypotheses always labeled. Web-reading
processes hold no credentials; credentialed processes read only local staging files. Suppression
is checked before any person enters a play. "No change" and "couldn't look" are different results.
