# measure-batch — measuring NOT-YET-ADMITTED accounts (mandatory checklist)

_Created 2026-08-15 after a real failure: the first 30-account measurement pass SKIPPED the
EDGAR lane until the user asked. This runbook exists so no lane ever depends on memory again.
Scope: MEASUREMENT ONLY — nothing here admits an account, touches accounts.csv, opens Gate-1,
or builds a play. Admission is a separate, user-ordered step._

## Inputs
- A candidate list with a DOCUMENTED, deterministic selection rule (write the rule into the
  brief: what ordered the list, what was excluded, why). Save as
  `data\imports\<date>-measure<N>-candidates.csv` (columns: name, domain + provenance columns).

## The lanes — ALL SIX, every batch, no exceptions

1. **Discovery** — `scripts\discover-ats.ps1` over the candidates CSV. Output to
   `data\imports\<date>-measure<N>-discovery.csv`.
2. **Feed identity + marketing-role counts** — for EVERY structured feed found: fetch the board
   meta/organization name and a sample job URL before believing it (2026-08-14 catches:
   greenhouse `cornerstone` = a child-development center; `linkedin` = "LI Test Company").
   Count marketing titles with the canonical MktgPattern regex. (count-marketing-roles.ps1 has
   a known StrictMode crash on a workday edge — until the TESTED fix lands, compute counts
   directly and say so.)
3. **News RSS** — Google News RSS per account, ~120-day window, 3s delays, items archived
   verbatim to `data\verify\<date>-measure<N>\`. These are SECONDARY sources always — say so in
   every verdict that leans on them.
4. **Leadership (free public sources; Clay removed 2026-08-24)** — per account: leadership
   page + newsroom + press-release sweep for marketing c-suite and recent senior arrivals.
   ZoomInfo contact search is available ONLY at verdict time (Tier-2, verdict-gated per
   `config\enrichment-policy.md`) — never as a batch-measurement lane. STANDING LESSON kept
   from the Clay era: third-party people-index start dates are MONTH-precision at best —
   every date-dependent verdict carries a verify flag until an own-domain primary names the
   date (the veeam lesson: the index was ~4 weeks early on the CMO date).
5. **EDGAR — never optional again.** (a) ticker-file lookup for every candidate; (b) submissions
   JSON for every CIK found (recent forms, SIC, identity); (c) targeted full-text searches
   where a filing could change a verdict (restructuring/severance language, acquisition
   completions, Item 5.02 officer changes); (d) fetch the 1-3 decisive documents and quote them
   verbatim. Failed ticker lookups are recorded as GAPS, not silently dropped. Why this lane
   pays twice (2026-08-15 proof): it UPGRADES legs to primary (Cimpress 8-K close, exact date +
   segment attribution) and it DEFLATES news hype (NIQ's "Flywheel acquisition" = $4.9M tuck-in
   per the 10-Q; CDW's reported layoffs had NO filing footprint).
6. **Verdict assembly** — score per `config\scoring-rules.md`: STRIKE needs ≥2 independent
   in-window Tier A–C legs on the same org (and stays "(pending primary verify)" until
   primaries exist); SEQUENCE = 1 solid in-window leg; WATCH = real activity, nothing
   in-window; NOTHING = checked and empty — with the coverage limitation stated (page-only
   accounts, dead entities, unmeasured lanes). Window arithmetic shown per leg.

## Outputs (all committed)
- `briefs\<date>-measure<N>.md` — verdict table with dates/quotes verbatim, cross-account
  catches for already-admitted accounts (check every batch: the 08-15 pass found epicor's
  probable new CRO and xerox's Lexmark-integration signals for free), coverage limitations,
  tool lessons.
- `data\verify\<date>-measure<N>\` — raw news JSON + any fetched filing docs.
- run-log entry + commit + push (rule 11).

## Standing reminders
- Dead/absorbed entities are a finding, not a failure (Bull, Akka→Akkodis, Change
  Healthcare→Optum, Linode→Akamai on 08-15) — flag the TAL row for remap.
- Non-US HQs get a Gate-3 note at measurement time so nobody discovers it at draft time.
- Owner names from the TAL may be ARCHIVED staff — record, flag, never reassign unilaterally.
