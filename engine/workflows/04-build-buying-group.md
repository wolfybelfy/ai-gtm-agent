# WORKFLOW 04 — BUYING GROUP BUILDER (HOT cells only)
# The one credit-spending workflow. Estimate cost first; obey config/limits.yaml; test at 10.

## Input
Registry rows with `tier = HOT` and no buying group yet.

## Output
- `data/cells/<CELL_ID>-contacts.csv`: `name, title, linkedin, role(champion|economic|influencer|blocker), angle, email, email_status, phone, suppression_check, source`
- Run log with credits spent vs estimate.

## Procedure (per HOT cell)
1. **Derive the persona from the cell — do not use a fixed title list.** Target: whoever sits in that cell, marketing family, manager+. 5–8 people:
   - Champion (1–2): the cell's demand gen / campaign lead — angle: execution relief, capacity
   - Economic (1–2): the cell's VP/Director — angle: pipeline number, cost-per-opportunity
   - Influencer (2–4): PMM, marketing ops, field marketing in that cell — angle: fit with their stack and calendar
   - Blocker: identify procurement/vendor mgmt but DO NOT contact until there is a live deal
2. **Find people:** Clay plugin people-search scoped to the account + cell tokens (BU/product/region in title or headline). Cross-check each person actually belongs to the cell — wrong-cell contact = worse than no contact.
3. **Enrich:** waterfall email → validate (aim: verified only) → phone for champion/economic. Use BYO-key providers first (per limits.yaml), Clay credits second.
4. **Suppress:** check HubSpot for existing contact/deal/client-domain + 90-day contact history + conflict rules. Any hit → drop and log.
5. Write the CSV. **Send nothing.**

## Rules
- Max 8 contacts per cell (limits.yaml). More people ≠ more meetings; multi-threading works by role coverage, not headcount.
- If fewer than 3 cell-verified contacts can be found, flag the cell `thin_buying_group` — an SDR decides whether to work it, not the engine.
