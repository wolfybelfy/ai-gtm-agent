# HubSpot platform reference — official docs deep-dive, 2026-07-30

_Companion to `hubspot-playbook.md` (our doc-verified API facts, 2026-07-28) and
`hubspot-community-intel-2026-07-30.md` (practitioner strategies). All OBSERVED facts below were
read from officially fetched pages 2026-07-30 (knowledge.hubspot.com, developers.hubspot.com,
hubspot.com, legal.hubspot.com product catalog). INFERRED/UNVERIFIED labeled. Full source list
at bottom of the run-log entry for this session._

## 1. Platform map — THE RENAMES (docs read with old names are stale)

| Current name | Former name | Contains |
|---|---|---|
| Marketing Hub | — | email, pages, forms, social, AI content |
| Sales Hub | — | pipelines, SEQUENCES, forecasting, calling |
| Service Hub | — | tickets, KB, feedback |
| Content Hub | CMS Hub | website, blog, memberships |
| **Data Hub** | **Operations Hub** | data sync/quality, datasets, automation |
| **Revenue Hub** | **Commerce Hub** | CPQ: quotes, invoices, payments |
| **Agent Hub (BETA)** | new 2026 | AI agents: Prospecting, Customer, Data, AEO, Deal progression |
| Smart CRM | — | free baseline (official: 2 users, 1,000 contacts) |

**"Lists" are now "Segments"** (CRM > Segments). Key UI paths: Tasks = CRM > Tasks; Sequences =
Sales > Sequences; Workflows = Automation > Workflows; Pipelines = Settings > Data Management >
Objects > Deals; Service keys = **Development > Keys > Service keys**; credits usage = Account &
Billing > Usage & Limits > HubSpot Credits; audit logs = Settings > Account Management > Audit Logs.

## 2. Pricing & seats (post-March-2024 seats model; legacy accounts keep old pricing until migrated)

- Seat types: View-Only (free, unlimited) / Core / **Sales seat** (Sales Hub Pro/Ent) / Service
  seat / Revenue seat. Seat reductions only at renewal.
- Sales Hub: Starter $9-15/seat/mo; **Professional $90-100/seat/mo + $1,500 mandatory onboarding**
  (sequences live here); Enterprise $150/seat + $3,500 (adds custom objects, predictive scoring,
  deal/revenue sequence reporting).
- Marketing Hub: Pro $800/mo (2,000 marketing contacts, 3 core seats, $3,000 onboarding); Ent $3,600/mo.
- **HubSpot Credits** (the credit system; replaced Breeze credits June 2025): included monthly
  Starter 500 / Pro 3,000 / Ent 5,000; extra $0.010/credit; NO rollover; pause controls exist.
  Burn rates (official catalog): **Prospecting agent 100 credits per lead recommendation (~$1)**;
  Customer agent 50/resolution; Data agent 10/prompt/record; **buyer-intent 50/company/signal/month**.
- **Breeze Intelligence ENRICHMENT is now credit-FREE on all paid (Starter+) accounts** (Clearbit-
  based, 40+ properties, ~200M profiles; manual + automatic + continuous monthly refresh modes,
  Super Admin toggles). Intent costs credits; enrichment does not.
- Marketing-contacts billing: snapshots 1st of month; auto-UPgrade never auto-downgrade
  (downgrade only at renewal, ≥5 business days notice). Overage bands in catalog.
- Transactional email add-on $600/mo (Marketing Pro/Ent, requires Dedicated IP add-on too).

## 3. SEQUENCES — the Gate-2 facts (all OBSERVED from official KB)

- **Requires: Sales Hub Pro/Ent OR Service Hub Pro/Ent, PLUS an assigned Sales or Service seat**,
  plus sequences permissions. Starter/Core seats cannot use sequences.
- **Sends from the USER'S CONNECTED PERSONAL INBOX** (Gmail/Workspace/O365/Exchange/IMAP) — the
  sending domain is the mailbox's domain, never a HubSpot server; dedicated-IP add-on does NOT
  apply. → Lookalike-domain sending = real per-rep mailboxes ON the lookalike domain, connected
  to HubSpot as personal inboxes, SPF/DKIM/DMARC + warm-up handled outside HubSpot (no native warm-up).
- Limits: **500 sequence emails/user/day on Pro seat, 1,000 Ent** (rolling 24h; custom lower
  limits settable); provider caps (Workspace/O365 1,000/day, free Gmail 350); bulk enroll
  **max 50 contacts at once** (permission-gated), sends throttle 3/min.
- Enrollment: manual only (sequence tool, record, index, Segments, Gmail/Outlook extensions) —
  auto-enrollment only via workflows (Sales Pro/Ent or Service Ent). Can only enroll from YOUR
  connected inbox; prior-bounce contacts can't enroll.
- Steps: automated email, manual-email task, call task, general task, LinkedIn SalesNav tasks.
  Max 10 email templates/sequence, unlimited tasks, delays to 90 business days, business-days
  default. Auto-unenroll on reply or meeting; option to unenroll ALL contacts at same company.
- Reporting: reply rate, meeting rate (≤7d after finish), step-level; deal/revenue metrics
  Enterprise-only. **Sender score** after 100 ended enrollments (good reply 7-13%, bounce <3%).
- Sequences (1:1 sales email, connected inbox) vs Workflow email (marketing email via HubSpot
  infra, needs Marketing Pro/Ent, no reply-tracking/auto-unenroll).

## 4. Tasks & queues (SDR surface)

Task types Call/Email/To-do; reminder = email to owner; repeating tasks. Queues: CRM > Tasks >
Manage queues (private/shared), **20 queues/user limit**, shared queues editable by creator or
added super admins; queue = label (no enforced order); savable as view. Workflow-created queue
assignment needs Sales/Service Pro/Ent. Queue-assignment-emails-owner remains UNVERIFIED (test
at Phase 4 as planned).

## 5. CRM data model

- Custom objects: **Enterprise only** (any hub's Ent unlocks portal-wide).
- Lifecycle defaults: Subscriber→Lead→MQL→SQL→Opportunity→Customer→Evangelist→Other (auto-moves
  only forward). Lead status: 8 defaults.
- Pipelines: default 7 stages; **"Closed lost" = any stage flagged probability-type Lost, not a
  fixed name** → our closed_lost filters must select on stage TYPE Lost, not stage name.
  Pipeline counts: Starter 2 / Pro 15 / Ent 100.
- Segments: active (auto) vs static (snapshot), 250 filters max, all tiers.
- Suppression surface: "Unsubscribed from all email" blocks ALL HubSpot email tools including
  the prospecting agent; self-service unsubscribes irreversible by workflows/users. Suppression
  pull = hs_email_optout family + Lost-type deal stages + lifecycle.

## 6. Automation danger zone (the audit's core)

- Workflows: Pro/Ent of any major hub; triggers filter/event/schedule/webhook-based. **API-written
  property changes ARE trigger-eligible — no source-based exemption exists.** Documented fences:
  (1) contacts we create stay **non-marketing** (marketing tools can't email non-marketing
  contacts); (2) unsubscribed-from-all; (3) audit of existing workflows pre-go-live; plus our own
  rails (ts_ namespace no workflow references, ready-flag-last write order).
- **NEW: Agent Hub Prospecting Agent** can auto-enroll via rulesets and send FULLY AUTONOMOUSLY
  (mode "Send automatically"; 1,000 emails/day agent cap; max 3 emails/contact/90d; sender = a
  connected inbox). Available even on Starter. **RevOps audit item #1: confirm OFF, and that no
  ruleset could sweep accounts our system touches.**

## 7. API platform

- Rate limits: private apps Free/Starter 100 req/10s + 250k/day; Pro 190/10s + 625k/day; Ent
  190/10s + 1M/day. Add-on: 250/10s +1M/day (max 2).
- **Service Keys: still PUBLIC BETA** (subject to change); created at Development > Keys >
  Service keys by super admin/dev-tools users; `Authorization: Bearer pat-na1-...`; rotation w/
  7-day overlap; REST only (no webhooks). Legacy private apps still work.
- Versioning: first date-based version /2026-03/; breaking changes March+September; each version
  18 months support — confirms our date-form pin decision.
- **HubSpot remote MCP server now GA** (read campaigns/pages, write CRM objects) — future
  alternative channel; our token-guide fallback strengthened.

## 8. Breeze/AI summary

Breeze Assistant free on all plans (30 req/min cap). Agent Hub (beta) = Pro/Ent + credits.
Prospecting agent: researches leads (10 contacts/min), drafts outreach, semi- or fully-auto
send; 100 credits/lead recommendation. Enrichment free on paid tiers; intent 50 credits/company/
signal/month. Sandboxes: standard sandbox **Enterprise only**; legacy sandboxes unsupported
since 2026-04-30; new model has one-way Deploy to Production for new assets.

## 9. Admin / audit surfaces

Permissions: per-object view/edit/delete scoping (All/Team/Owned); Sales tab has Sequences +
Bulk-enroll toggles; Automation tab has workflow Enroll/Publish; Super Admin + Developer-tools
access (service keys, sandboxes). Permission sets = Enterprise, 100 max. Audit logs: Enterprise
for centralized log; 30-day UI windows; logins export 90d, security 1yr; **API/form property
changes are NOT in the audit log** (user-initiated actions only).

## Corrections applied to our local files (2026-07-30)

1. token-guide: primary Service-Keys path corrected to **Development > Keys > Service keys**;
   beta status noted; unverified "last-used timestamps" claim removed.
2. hubspot-playbook: sequences unlock extended — Service Hub Pro/Ent + Service seat also works.
3. Playbook's endpoint table, 2026-03 versioning, associationTypeId 190: nothing fetched
   contradicted them.

## Standing [GAP]s

Content/Data/Revenue Hub list prices; sequence A/B testing (third-party only); max sequences
per account; API add-on price; free-tier seat count (official says 2 users, third parties say
5 core seats); exact marketing-tools-requiring-marketing-contacts list; audit-log API details.
**In-portal checks when token lands: company's tier + seats (decides sequences), Prospecting
Agent status, Starter-sequences entitlement question from community intel.**
