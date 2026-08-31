# EDGAR extraction & routing — the semantic layer of the filings lane
_From EDGAR_MODULE_SPEC.md sections 3 + 5, implemented 2026-08-06. Used by the Monday triage
(headless or attended) on every `sec_filings` signal row. Ground rules apply always: no invented
facts (every signal carries entity, CIK, form, file_date, accession, URL, and a VERBATIM quote —
no quotable passage = no signal); never invent people; one filing hit by multiple queries = ONE
source; anything unverifiable gets `NEEDS_VERIFICATION` written into the row, never a guess._

## Form routing (what to do per form type)
| Form | Route |
|---|---|
| 8-K | Triage NOW (the real-time form). Classify per prompt 5.2 below. |
| S-1 | Triage NOW: use-of-proceeds + Risk Factors extraction. Also a TAL promotion candidate (see runbooks\edgar-discovery.md). |
| 10-K / 10-Q / 20-F / 40-F | Phrase extraction per prompt 5.1. Tags the account for the year; not day-urgent. |
| 6-K | Triage if it carries earnings/strategy content (foreign filers put material news here). |
| DEF 14A | **Record update ONLY — NEVER an alert** (proxy-season CMO-comp mentions are a verified false-positive class). Prompt 5.4. |
| D / D-A | funding_round primary source (ours, kept beyond the spec) — typically 2-4 weeks pre-press. |
| 15-12B / 15-12G / 15-15D / 25 / 25-NSE | Deregistration/delisting. Decide: company going private (annual reporting also stopping) -> PE-lane reclassification: SYSTEM alert + re-run `scripts\edgar-classify.ps1` + wc row per spec section 6. OR a single security class being retired -> benign, note only. **Verified benign examples 2026-08-06: thomson-reuters 25-NSE (2026-05-14) and taboola 25-NSE (2026-06-29, likely its TBLAW warrants) — both still active annual filers.** Verified real example: jamf 15-12G (2026-02-09) = went private = PE lane (wc-011). |
| 4, 144, S-8, 13F, SCHEDULE 13G/A, everything else | Ignore. 13F "acquires shares" headlines are known noise. |

## Window arithmetic reminder
Windows use the ACCOUNT'S OWN fiscal calendar — `config\edgar-classification.csv` carries each
filer's `fiscal_year_end` (MMDD from its own submissions JSON; 5 TAL filers end Jan 31, Adobe
late Nov). Acquisition integration 0-9mo post-CLOSE (the close date comes from the 8-K item 2.01
or the 10-K, never the announcement date); new-leader ~90d; event pre-window 8-14 weeks.

## 5.1 — 10-K / 10-Q / 20-F / 40-F extraction prompt
> From the following filing text, extract every statement about: (a) planned or increased sales &
> marketing investment; (b) geographic expansion (region named); (c) enterprise/upmarket shift;
> (d) marketing capability gaps admitted in Risk Factors; (e) product launch cadence or
> acquisitions being integrated; (f) partner/agency programs. For each: quote VERBATIM (<=40
> words), name the section it came from, and classify as FORWARD-LOOKING-INTENT vs BOILERPLATE vs
> HISTORICAL. Discard boilerplate. Return null if nothing qualifies. Never paraphrase into
> stronger language than the filing uses.

## 5.2 — 8-K classification prompt
> Classify this 8-K: [EXEC_CHANGE_MARKETING | EXEC_CHANGE_OTHER | MA_ANNOUNCED | MA_CLOSED |
> RESTRUCTURING | EARNINGS_RELEASE | GOING_PRIVATE | OTHER]. If EXEC_CHANGE_MARKETING: extract
> person name (verbatim), role, effective date, incoming/outgoing. If MA_CLOSED: extract target,
> close date (starts the 0-9mo window). If EARNINGS_RELEASE: run prompt 5.1 on the release text.
> If GOING_PRIVATE: emit reclassification event.

## 5.3 — Earnings-call transcript prompt (Phase 5 — NOT ACTIVE)
Held until the transcript source is chosen: third-party APIs are commercial and their
pricing/coverage is NEEDS_VERIFICATION per spec section 9 — a user budget decision, not built.
> Extract every statement by a named executive about marketing spend, brand investment, demand
> generation, GTM hiring, or geographic expansion. Verbatim quote + speaker + role. Flag any
> statement mentioning EMEA/Europe/UK/international explicitly.
Rule when active: a call statement + a filing statement from the same company = ONE company
narrative; call + job posting = two independent sources.

## 5.4 — DEF 14A prompt (record update only)
> List the named executive officers and roles. For any marketing/revenue-titled officer: note
> tenure evidence (partial-year comp, new-hire grants, footnotes on start date). Output updates
> the account's people record. Emit a signal ONLY if tenure evidence indicates the officer joined
> within ~12 months (route as possible new-leader window, tier down-weighted, NEEDS_VERIFICATION
> on exact start date).

## Signal row shape (spec Phase 2)
`{account, cik, form, file_date, adsh, url, event_class, verbatim_quote, extracted_fields,
window_status, tier}` — recorded via the existing triggers.jsonl/brief conventions; the verdict
layer's rules are UNCHANGED (STRIKE needs >=2 independent in-window sources; a lone 10-K
statement is a SEQUENCE ceiling; scoring rubric: config\edgar-scoring.md).
