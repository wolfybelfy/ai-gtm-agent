# Runbook: backtest (strategy §4.2/§6 one-time Week-2 + v1.1 point-in-time discipline)

**Input:** `staging\hubspot\closed-won.csv`, `closed-lost.csv`, plus disqualified and stalled/went-dark cohorts (same schema; colleague UI export is fine — this runbook never needs a token).

## Steps
1. For each historical deal: establish the deal event date (`event_date`) and an `as_of_date` for every piece of trigger evidence found.
2. For each Tier A–C trigger type: was it present in the account/team's public record BEFORE the deal event?
   - **Point-in-time rule (v1.1):** only evidence dated before the deal event counts as backtest evidence. Anything reconstructed from today's state (current careers page, current leadership) is labeled **DIRECTIONAL**, and the memo says so per trigger.
3. Score per cohort: keep what appears in **Closed Won and not elsewhere**; cut what appears **everywhere** (no discrimination) or **nowhere** (no signal); label thin data **insufficient_data**.
4. Judge on revenue outcomes, never reply rates.
5. Output: `reference\backtest-memo-<date>.md` — explicit keep / cut / DIRECTIONAL verdict + evidence counts per trigger; update every trigger's `backtest_status` and `weight` in `config\trigger-weights.yaml` (commit with reasons).
6. Candidate triggers from the account-director interviews get backtested here too before earning weight.
