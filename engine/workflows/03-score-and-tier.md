# WORKFLOW 03 — SCORER (runs after 02, same session or same day)

## Input
`data/signals/signals.csv` + `data/cells/registry.csv` + `config/signal-weights.yaml` + `config/conflict-rules.md`

## Output
- Update registry rows: `tier, pressure_score, signals_fired, timing_window_closes, retrigger_date, tier_changed_date`
- `data/runlog/<date>-scoring.md`: tier changes, vetoes applied, WATCH promotions

## Procedure (deterministic — no judgment calls in this step)
1. **Fit veto first** (hard binaries from signal-weights.yaml `fit_veto`). Any hit → SKIP, logged with reason. If `config/conflict-rules.md` is unsigned, EVERYTHING stops at this gate — say so and halt.
2. **Window check.** For each live signal: outside its action window → score 0 (keep the row; it may re-enter, e.g. conference at T-12w).
3. **Pressure** = Σ(weight × recency_decay) over in-window signals.
4. **Corroboration** = count of in-window signals with different source AND different mechanism (two job-feed signals ≠ corroborating).
5. **Tier** per signal-weights.yaml: HOT (≥2 corroborating, veto pass) / WARM (1 strong) / WATCH (else, with `retrigger_date` computed from window math — e.g., conference signal parked out-of-window auto-promotes at T-12w) / SKIP.
6. **WATCH recycle**: any WATCH row whose `retrigger_date` ≤ today → re-score now. This is the mechanism that stops the pipeline rotting.

## Rules
- Show the math for every HOT cell in the run log (signals, weights, decay, window state). SDR trust is the scarce resource; the scorecard is how it's earned.
- A day with zero HOT cells is a valid, correct output. Do not lower the bar to produce activity.
