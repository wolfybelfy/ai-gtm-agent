# HubSpot playbook — access, verified API facts, and the clean-corner build
_Compiled 2026-07-28. API facts below were verified against HubSpot's official developer documentation (via the Context7 docs index of developers.hubspot.com) on 2026-07-28; each carries its status. The write model itself is fixed by plan v1.2 (one immutable record per play) — this file is about HOW, not WHAT._

## Access (unchanged asks, now with the setup procedure)
- **Private app token** (created by a **super admin**), scopes EXACTLY:
  `crm.objects.contacts.read` + `.write`, `crm.objects.companies.read` + `.write`, `crm.objects.deals.read`, `crm.schemas.companies.write`, `crm.schemas.contacts.write`.
  Notes/Tasks APIs ride on the contacts object scopes (plan A-1, VERIFIED — no separate task scope; the schemas scopes cover property/group creation, confirmed again today in the properties API docs).
- **Token handling on this machine (rail 3):** the user stores it as a user environment variable, never a file:
  `setx HUBSPOT_PRIVATE_APP_TOKEN "pat-xxx"` in their own terminal (takes effect in NEW shells). Scripts read `$env:HUBSPOT_PRIVATE_APP_TOKEN` and refuse to run without it. Never paste the token into chat, files, or logs; scripts never echo it.
- **Fallback if a token is refused:** HubSpot's official remote MCP server `mcp.hubspot.com` (OAuth, respects the signed-in user's own permissions). Read-heavy work functions; scripted idempotent writes prefer the token.

## API versioning (plan flag RESOLVED 2026-07-28)
- Date-based API versions are CONFIRMED live in official docs — current spec paths show `2026-03` (e.g. `POST /crm/properties/2026-03/{objectType}/groups`), with `2025-09` visible as a prior pin.
- **Decision:** the kit calls the classic **`/crm/v3/...`** paths (every endpoint we need is fully documented there today, stable since 2019) and keeps the date-form noted per endpoint as the future pin. One exception: the default-association PUT is only verified in date-form, so that call uses `2026-03` explicitly. Logged in BUILD-STATE.

## Verified endpoint facts (all checked 2026-07-28 unless marked)
| Operation | Call | Status |
|---|---|---|
| Create property group | `POST /crm/v3/properties/{objectType}/groups` body `{name, label, displayOrder?}` → 201 (also exists as `/crm/properties/2026-03/...`) | VERIFIED |
| Create property | `POST /crm/v3/properties/{objectType}` body `{name, label, type, fieldType, groupName, description?, options?}` → 201; scope `crm.schemas.companies.write` explicitly listed | VERIFIED |
| Create note | `POST /crm/v3/objects/notes` — properties: `hs_timestamp` (REQUIRED, ISO8601), `hs_note_body`, `hubspot_owner_id?`; inline `associations[{to:{id}, types:[{associationCategory:"HUBSPOT_DEFINED", associationTypeId:190}]}]` | VERIFIED — **190 = note→company** (official example associates a note to a company with 190 and a deal with 214) |
| Create task | `POST /crm/v3/objects/tasks` — properties: `hs_timestamp` (due, REQUIRED), `hs_task_subject`, `hs_task_body`, `hs_task_status` (e.g. NOT_STARTED), `hs_task_priority` (LOW/MEDIUM/HIGH), `hs_task_type` (TODO/CALL/EMAIL), `hubspot_owner_id?` | VERIFIED (endpoint + property names in official tasks guide) |
| Associate task→company without hardcoded IDs | `PUT /crm/objects/2026-03/tasks/{taskId}/associations/default/companies/{companyId}` — default unlabeled association; **plain object names allowed** (contact, company, deal, ticket, note) | VERIFIED (official associate-records guide) — the kit uses this instead of guessing type IDs |
| List objects w/ paging | `GET /crm/v3/objects/{type}?limit=100&after={cursor}&properties=a,b` → `results[] + paging.next.after` | VERIFIED for the v3 objects family (official example); deals is the same family |
| Search by property | `POST /crm/v3/objects/companies/search` (domain EQ lookup) / `.../deals/search` (closedate range + stage filters) | STANDARD v3 — exercise live at first token use before trusting in anger |
| Assign task to a queue | property `hs_task_queue_id` on task create | LIKELY (community-corroborated) — test at Phase 4 with the real queue's ID |

## What CANNOT be done via API (verified expectation-setting, 2026-07-28)
- **Saved views and task queues are NOT API-creatable** (UI-only; corroborated across HubSpot KB + community as of Jan 2026). The clean corner therefore has a small one-time UI setup done by the user or RevOps (below). Tasks CAN likely be dropped into an existing queue via `hs_task_queue_id` — that's the automation seam.

## The clean corner (user requirement 2026-07-27) — division of labor
**Scripts create (idempotent, after RevOps audit):**
- Property group `trigger_system` ("Trigger System") on companies.
- Three company properties in it: `ts_last_tier` (string), `ts_last_window_close` (date), `ts_suppression_until` (date). Nothing else. Every note body and task carries `play_id` → all our data is greppable and bulk-removable.

**One-time UI setup (5 minutes, user or RevOps — scripts cannot):**
1. Tasks home → create queue **"Trigger Strikes"** (shared with the named SDR + backup). Note its queue ID from the URL → goes into `config\` for `hs_task_queue_id`.
2. Companies index → filter `ts_last_tier` is known → save view **"Trigger System — active plays"** → share with the team. This view is the SDR's only required surface.
3. (If portal is Enterprise, Q1e) discuss the optional custom `Play` object at the RevOps audit — not required; notes+tasks work on every tier.

**Rails that stay in force:** first write only AFTER the RevOps audit is recorded in BUILD-STATE; `staging\hubspot\WRITES-PAUSED` kill switch stops all writes instantly; writes are limited to the play-record model (immutable note + task + the 3 `ts_` props); nothing that can fire a workflow email.

## Sequences (context for Gate 2)
- Requires **Sales Hub Pro/Enterprise + a Sales seat** (plan A-1, VERIFIED). Enrollment is HUMAN, always — the system never touches Sequences via API. Task-queue assignment natively emails the owner [LIKELY — verify when access lands]: that's the second doorbell.

## Backtest export (Phase 3 entry)
- With token: `hubspot-export-deals.ps1` pulls closed-won/closed-lost with `closedate`, `amount`, `dealstage`, `dealname` + associated company (for `domain`), maps to the canonical staging columns (`staging\SCHEMAS.md`), stamps `as_of_date`. Without token: a colleague's UI export lands in the same staging files — the canonical schema never chases the export format.

## Sequences unlock - AMENDED 2026-07-30 (official docs)
Sequences require Sales Hub Pro/Ent OR **Service Hub Pro/Ent**, PLUS an assigned Sales or Service
seat. A Service-side seat is an alternative unlock path if the company has Service Hub but not
Sales Hub at Pro+. Full platform facts: reference/hubspot-platform-reference-2026-07-30.md;
community/deliverability intel: reference/hubspot-community-intel-2026-07-30.md.
