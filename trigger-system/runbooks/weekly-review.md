# Runbook: weekly-review (strategy §6; 30 minutes, weekly, from Phase 5)

1. Per trigger type, compute fired → sent → replied → **meetings** from `plays\index.csv` + sequencer/HubSpot staging exports → append `data\metrics-weekly.csv` (include `exposure_count` = cumulative delivered sends for that trigger type).
2. **Kill rule (with the v1.1 floor):** at ≥ `min_exposure_sends` delivered — 2 weeks zero engagement → halve weight; 4 weeks → kill. Below the floor → verdict "insufficient data", trigger keeps running. Kill IMMEDIATELY regardless of exposure on factual/reputational risk or high reviewer-rejection rate. **Every evaluation is recorded, including "keep" and "insufficient data", with its exposure count.**
3. Update `config\trigger-weights.yaml` (kill_status / weight) — this is a config change: commit carries the reason; config_version moves.
4. Per CTA artifact: request rate + view-to-call rate; rotate losers out.
5. Any meeting booked → 15-minute reverse-engineering note into `reference\` (which triggers, what timing, what copy angle). New trigger hypotheses come from here, nowhere else.
6. Capacity check: queue lengths vs capacity-rules.md; expiries executed? ack times within 24h? Update capacity numbers if the measured reality disagrees.
7. Monthly: does STRIKE outperform SEQUENCE enough to justify SDR allocation? If not — fix the math, not the narrative.
8. Session close per `runbooks\session-close.md`.
