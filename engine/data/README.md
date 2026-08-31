# data/ — working store (local, free; no external DB required)

- `tal/accounts.csv` — INPUT. From the data team. Columns: account_name, domain, priority, existing_relationship, relationship_notes
- `cells/` — registry.csv + one YAML per cell + <CELL_ID>-contacts.csv
- `snapshots/<account>/<date>.json` — daily job-posting snapshots (the diff baseline — starts Day 1, value compounds daily)
- `signals/signals.csv`, `signals/event-calendar.csv`
- `briefs/<date>-<cell_id>.md` — the SDR-facing product
- `runlog/` — one file per run; scorecard.md updated weekly

Nothing in here is prospect-facing. Everything prospect-facing exits via Clay/HubSpot with human QA.
