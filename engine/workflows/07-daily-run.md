# WORKFLOW 07 — DAILY RUN (the orchestrator)
# Run each morning: "execute workflows/07-daily-run.md"
# Schedulable later via cron/routine once each step has been run manually 10 times (CLAUDE.md rule 10).

## Sequence
1. `02-watch-signals.md` — snapshot, diff, M&A clock, conference clock, leadership check
2. `03-score-and-tier.md` — veto → window → pressure → corroboration → tier; WATCH retrigger promotions
3. For each NEW HOT cell: `04-build-buying-group.md` (respect credit cap; if cap would be exceeded, rank HOT cells by `timing_window_closes` ascending and defer the rest to tomorrow)
4. For each new buying group: `05-write-brief.md`
5. `06-write-hubspot.md` — CRM write + same-day task + Slack brief
6. **Reply sweep (until a dedicated reply handler exists):** check the sending tool/inbox for replies to engine sequences. Classify: MEETING → Slack alert + calendar link now · ASSET_REQUEST → Slack with 5-minute clock · QUESTION/OBJECTION → draft for human, never auto-send · REFERRAL → add named person to the same cell's group · NOT_NOW → WATCH + retrigger date · NOT_INTERESTED → suppress contact, keep cell alive · unsure → HUMAN_LOOP to Slack. **Any reply pauses every other sequence in that cell today.**
7. Write `data/runlog/<date>-daily.md`: signals found/discarded, tier moves, credits spent, briefs produced, replies handled, and the three numbers that matter: **HOT cells today · briefs accepted by SDR within 24h · meetings booked this week.**

## Weekly (Fridays)
- Refresh conference exhibitor lists (rolling 6 months)
- Precision scorecard per signal type (fired N → meetings M) and per cell type → `data/runlog/scorecard.md`. Kill any signal whose precision stays under threshold for 4 weeks — signals rot.
- Re-verify 1/13th of the cell registry (≈ quarterly full refresh)

## Monthly
- Backtest check-in: for every meeting booked, reconstruct which signals were observably true 90 days prior; adjust `config/signal-weights.yaml` from OUR outcomes, not the videos' claims.
- Holdout review: 10–15% of qualifying cells stay untouched; compare meeting rate vs worked cells. Without this we cannot distinguish "the engine works" from "the quarter was good."
