# EDGAR discovery promotion loop — how new accounts enter the TAL (monthly)
_From EDGAR_MODULE_SPEC.md Phase 4, implemented 2026-08-06. The discovery lanes' ONLY output is
TAL candidate rows for human review — NEVER direct outreach from a battery hit._

## Cadence
Monthly, attended (first attended session of each month):
1. `powershell -File scripts\edgar-battery.ps1 -Cadence monthly` (L5 discovery queries; L1-L3
   non-TAL entities from the weekly runs also feed this list — they are already in the weekly
   `edgar-battery-hits.csv` files with `tal_covered` blank).
2. Collect net-new entities (display_names + ciks) not on the TAL.
3. Screen each against `config\edgar-scoring.md` axes 5-6 (geo fit + ICP fit) plus the SIC on
   the hit. The SEC's SIC can lag reality — an LLM ICP check on the company's actual business is
   still required (spec section 9).
4. Candidates that pass -> a short memo (entity, CIK, the verbatim quote that surfaced them,
   axis scores) -> USER/sales review. **Gate 1 applies: a NEW account re-opens the conflict gate
   for that account** (config\gates.md).
5. On the user's Gate-1 go for that account (the conflict gate is real and stays; wording de-approvalized 2026-08-16): add to config\accounts.csv (identity-verified feed/newsroom per the standard
   admission discipline), run `scripts\edgar-classify.ps1` (Phase 0 columns), and the account
   inherits full CIK-lane coverage from its next Monday.

## Quarterly re-classification (spec section 1.1)
Re-run `scripts\edgar-classify.ps1` quarterly and after any Form 15/25 signal - companies go
private, get acquired, and IPO. The 2026-08-06 baseline run corrected the spec's own audit
(jamf: listed as US filer, actually 15-12G deregistered 2026-02-09 -> PE lane wc-011).

## First measurement baselines (2026-08-06, for the tightening loop)
All 22 queries alive after the phrase-in-parens syntax repair. Flagged >50-hits/window per the
spec's tightening rule: L3-02 (557 raw; tighten with an AND term next measurement run), L4-01
(806 raw; redundant-by-design TAL safety net, truncation logged honestly), L5-01 (661 raw;
review list by design). Silent-4-weeks rule: test a phrase variant before deleting any query.
