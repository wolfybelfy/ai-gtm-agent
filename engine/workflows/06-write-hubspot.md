# WORKFLOW 06 — HUBSPOT WRITER
# Models cells as parent/child companies (native association, no Enterprise tier needed).
# Auth: HubSpot private app token in engine/.env (HUBSPOT_TOKEN=...). Never commit .env. Scopes: crm.objects.companies + contacts + deals read/write, tasks write.
# First run: verify token + tier by fetching one company. If a HubSpot MCP server is preferred later, verify its auth/scopes then — the plain API is the safe default and works today.

## Structure written
```
Company (parent)  = ServiceNow                      ← roll-up/reporting only
  └─ Company (child) = "ServiceNow — Security & Risk EMEA"   ← THE CELL. The working record.
       └─ Contacts (buying group, associated to the child)
       └─ Deals (always on the child, never the parent)
```

## Properties to create once (setup step; idempotent)
Child company: `cell_id, cell_type, cell_confidence, cell_leader, budget_evidence, uses_agencies, signal_tier, pressure_score, signals_fired, why_now, timing_window_closes(date), retrigger_date(date), lateral_reference_cell, existing_relationship`
Contact: `cell_id, buying_group_role, role_angle, sequence_variant, thread_position`

## Per HOT cell (idempotent — match on cell_id; update, never duplicate)
1. Upsert parent company (match on domain).
2. Upsert child company with all cell properties; associate child→parent.
3. Upsert buying-group contacts; associate to CHILD.
4. Create a task on the child: owner = queue owner, **due same day**, body = link/path to the brief.
5. Post to Slack (free incoming webhook, `SLACK_WEBHOOK_URL` in .env): cell name, tier, why_now (2 lines), timing window, brief path. The payload is a brief, not an alert.

## Workflow automations to configure in HubSpot UI (one-time, listed here so nothing is forgotten)
- [ ] Task unaccepted after 24h → escalate to manager (the 24-hour acceptance clock — the step every system in the research skipped, and where pipeline silently dies)
- [ ] `timing_window_closes` within 14 days → priority flag on the record
- [ ] Any contact in a cell replies → notification to pause siblings (enforced by workflow 07 + the sequencer owner)

## Rules
- Test at 10: first run writes 10 cells max, human eyeballs them in HubSpot before the cap lifts.
- Never write a deal. Deals are created by humans when a meeting books.
