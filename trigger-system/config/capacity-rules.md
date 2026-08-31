# Capacity rules (v1.1 — plan Part B)

**Every number below is a DEFAULT GUESS until the Phase-1 walking skeleton writes measured minutes-per-stage here, and the weekly review re-checks them at pilot volume.**

- Max **5 STRIKE reviews per SDR per business day**.
- STRIKE unacknowledged **24h** → `[ESCALATION]` email + BUILD-STATE entry.
- Play older than **3 business days** at `ready` → back to `building` for evidence + contact revalidation (windows move; contacts change jobs).
- Excess plays are **RANKED (window-close ascending)** — never silently queued. Expiries are executed, not ignored.
- Queue length is reported in every daily brief.

## Measured minutes per stage (walking skeleton, Phase 1 — TO BE FILLED)
| Stage | Minutes (measured) | Date | Account used |
|---|---|---|---|
| source → trigger + evidence | ~10 (coarse, from session tool-call clock) | 2026-07-28 | braze (skeleton) |
| team attribution | ~5 (coarse; incl. 2 dead URL paths before Adweek verification) | 2026-07-28 | braze (skeleton) |
| buying group (manual method) | ~5 role-spec only — contact RESOLUTION now timed via ZoomInfo stage 2c (~6s/play observed 2026-08-24; historical note said Clay benchmark-gated — Clay removed 2026-08-24) | 2026-07-28 | braze (skeleton) |
| why-now + draft | why-now ~included above; DRAFT BLOCKED (offer.md skeleton) — cannot be timed until filled | 2026-07-28 | braze (skeleton) |
| owner pickup + run | — | — | — |
| outbox record + apply in UI | — | — | — |
| simulated send walkthrough | — | — | — |
| reply-handling walkthrough | — | — | — |
| source → trigger + evidence | ~8 | 2026-07-28 | thomson-reuters (skeleton) |
| team attribution (JD-named team + exec verify) | ~7 | 2026-07-28 | thomson-reuters (skeleton) |
| page_only evidence audit (count refuted) | ~5 | 2026-07-28 | odoo (skeleton) |
| disqualifier-stop path (gates end play before scoring) | ~3 | 2026-07-28 | g42 (skeleton) |
| expected-quiet evaluation (honest NOTHING lane) | ~3 | 2026-07-28 | redhat (skeleton) |
