# Explainer brief for an AI agent — help me understand how our outbound "plays" land in HubSpot

## Instructions for you, the AI agent reading this

Your only job is to help the reader UNDERSTAND the system described below. Explain it in plain
language, use analogies, answer follow-up questions, and re-explain from different angles until
it clicks. Important: the design decisions described here are already made and verified against
the real HubSpot portal. Do NOT propose a different architecture, do NOT suggest new tools, and
do NOT question the decisions. This document is accurate and self-contained; if something is not
stated here, say "that is outside this document" instead of guessing.

## 1. Minimal project background (all factual)

- The reader leads marketing/AI at Unbound IA, a B2B brand-and-demand agency. They have built
  (with an AI assistant) an automated "trigger-based outbound" system that runs every Monday.
- The system scans 36 named target companies (examples: Snowflake, Adobe, ServiceNow, Veeam)
  for hard evidence of buying intent: acquisitions in SEC filings, sudden clusters of marketing
  job openings, job descriptions that explicitly mention hiring outside vendors, product
  launches, new leaders.
- When evidence is strong enough it produces a "play": a package containing (a) the proof with
  links, (b) the specific TEAM inside the company that the evidence points at (for example
  "Snowflake, Observability marketing team, US region" — the system maintains its own org maps
  of teams per company, about 1,300 teams total), (c) a buying group of 6-9 named people
  (champion, approver, influencers) with their titles and LinkedIn profiles, (d) personalized
  email drafts per person, and (e) call talking points per person.
- Human SDRs (sales development reps, e.g. one named Saylee) then do the outreach by hand from
  a separate sending tool. The system NEVER sends emails itself. A human approves all copy.
- Missing piece until now: the plays live in files on the reader's laptop. The SDRs work in
  HubSpot (the company CRM). The current project step is pushing each play INTO HubSpot so SDRs
  receive it where they already work.
- Enrichment (finding a person's verified work email) is done by a tool called Clay, called via
  its API from the reader's system, roughly 3 credits per person, only after a play fires.
  ZoomInfo may replace Clay later. Enrichment does NOT happen inside HubSpot, by design (cost
  control: only the 6-9 justified people get enriched, never the whole database).
- The company's real HubSpot portal was audited read-only. Facts found: about 29,000 company
  records and 120,000 contact records exist; at least 14 of the 36 target companies exist as
  DUPLICATE company records (Veeam exists 3 times, Databricks 3 times, Adobe, SAP, Stripe,
  Braze, PayPal twice each); the integration's namespace is clean (nothing collides).

## 2. What the reader is trying to understand (their actual open confusions)

1. "In Clay you can create a separate workspace/workbook just for one project. What is the
   equivalent in HubSpot? I don't want our stuff merging with the existing CRM, HubSpot is wide."
2. "What does 'pin each of our 36 accounts to one official company record' mean?"
3. "When a play fires for, say, Snowflake US: lots of things matter — region-wise team, which
   function (demand gen, field, events), maybe a subsidiary. Then the right people must be
   enriched. Does enrichment happen in Clay or in HubSpot? Could ZoomInfo be integrated into
   HubSpot to enrich there?"
4. "After enrichment we have 6-9 people, each with their OWN page in HubSpot. The play has
   per-person emails, pain points, talking points. Physically, practically, where does all of
   that go so an SDR can actually work it?"
5. Smaller one: "Why does a 'task queue' need the SDR manager to click something in the UI —
   why can't the system create it?"

## 3. What the assistant has been explaining (the concepts)

- HubSpot has NO equivalent of a Clay workspace. One HubSpot account (called a "portal") is one
  single shared database. Features that sound like workspaces are not: "Brands" organizes
  marketing assets only; "Sandboxes" are Enterprise-only test copies; "Teams/permissions"
  control who sees what, not where data lives.
- Instead of separation, the design uses a "clean corner": everything the system writes is
  namespaced (its own field group with 3 fields prefixed ts_), additive-only (it creates notes,
  tasks, contacts; it never edits or deletes anything that already exists), tagged with a play
  id (so everything it ever wrote can be found and bulk-deleted, making it fully reversible),
  and its access token has no permission to send email or touch automation.
- Every company in HubSpot is a "company record" — a profile page for that company showing its
  people, notes, tasks, deals. Because employees created some companies more than once over the
  years, duplicates exist and HubSpot does not know they are the same company.
- "Pinning" solves the duplicate problem: for each of the 36 targets, choose ONE of its
  duplicate records as the official one (once), save that choice in a config list the system
  keeps (account -> HubSpot record id), and always write to that exact record forever. Analogy:
  three phone-contact entries for the same person — pick one and always text that one so the
  history stays in one thread. Merging the duplicates is a separate, optional cleanup that the
  SDR manager can do with HubSpot's built-in "merge companies" feature; if she merges, the pin
  list is updated. The system itself never merges or deletes.
- Division of labor per play: the reader's SYSTEM decides everything (which team, which people,
  what to say — HubSpot has no concept of teams inside a prospect company, the system's own org
  maps carry that); CLAY finds the verified emails (via API, results come back as a file);
  HUBSPOT only DISPLAYS the finished result. Slogan: HubSpot is the shelf, not the factory.
  ZoomInfo-inside-HubSpot enrichment exists as a product feature but is deliberately not used
  (it enriches broadly and uncontrolled; the pipeline way spends only on 6-9 people per
  verified play, and swapping Clay for ZoomInfo later changes one pipeline step, nothing else).

## 4. The absolute solution — what physically lands in HubSpot when a play fires

Use the running example: play = "Snowflake, Observability marketing team, US, 7 people."

1. The system consults its pin list and finds the one official Snowflake company record.
2. ON THAT COMPANY RECORD it writes ONE pinned note = the master play brief: why now, evidence
   links, the 7 people in recommended reach-out order. It also fills 3 small fields on the
   company (play tier e.g. STRIKE, window-close date, suppression status). Fields make plays
   filterable; notes alone are not filterable.
3. It creates the 7 people as CONTACT RECORDS (each person's own page: name, title, verified
   email from Clay), sets their owner to the assigned SDR, and ASSOCIATES each contact with the
   Snowflake company. "Association" is HubSpot's link between records; physically it means the
   7 people appear in a side panel on Snowflake's company page, one click away.
4. ON EACH PERSON'S CONTACT PAGE it writes one short note with that person's piece of the play:
   their role (champion / approver / influencer), THEIR personalized email drafts, THEIR
   talking points and pain points. So: team-level story on the company page, per-person
   material on each person's page, linked both ways. This directly answers confusion #4 — each
   guy having his own page is not a problem, it is exactly where his personal material goes.
5. It creates ONE TASK ("Work the Snowflake play — brief in pinned note") assigned to the SDR,
   due in 24h, dropped into a shared task queue named "Trigger Strikes". The task triggers
   HubSpot's normal notification to that SDR.
6. The SDR's physical flow: notification -> open task -> open Snowflake company page -> read
   the pinned brief -> click each associated contact -> each page already holds that person's
   approved emails -> copy into the sending tool -> send. Never leaves HubSpot, never
   reassembles anything from files or chat messages.
7. Guard rails around all of it: before anyone enters a play the system checks a suppression
   list (existing customers, open deals, opted-out people); a human records approval before any
   email is sent; one kill-switch file stops all HubSpot writing instantly; deleting the
   system's notes, tasks and 3 fields restores the CRM to exactly its prior state.
8. One shared saved view ("Trigger System — active plays": companies filtered on the ts_
   fields) acts as the team's board answering "what is live right now".

## 5. Why the task queue needs a human (confusion #5)

HubSpot task queues and saved views are UI-only features: HubSpot's API provides no endpoint to
create them, verified against HubSpot's documentation. Also, whoever creates a queue owns it
(only creator or super admins can edit/share it), so the SDR manager SHOULD be the creator —
she keeps control of her team's queue. It is about 2 minutes: CRM > Tasks > Manage queues >
Create task queue > name it "Trigger Strikes" > shared > pick her SDRs > Save. The integration
then only drops tasks INTO the queue, which the API does allow.

## 6. Glossary (googleable terms)

- Portal / account: one company's entire HubSpot instance. One shared database.
- Company record: a company's profile page in the CRM.
- Contact record: a person's profile page.
- Association: the link between records (contact <-> company); shows as a side-panel listing.
- Note: a free-text entry on a record's timeline; can be pinned to stay on top.
- Task: a to-do with an owner and due date; drives notifications.
- Task queue: a shared label/bucket grouping tasks for a team. UI-only to create.
- Saved view: a saved, shareable filtered list on an index page (e.g. all companies where a
  field has a value). UI-only to create.
- Property / field: a data column on records; custom ones can be created via API.
- Property group: a labeled section grouping fields on a record page (ours: "Trigger System").
- Private app token: the API key the integration uses; its scopes limit what it can ever do.
- Duplicates / merge: same real-world company existing as multiple records; HubSpot has a
  built-in merge feature; merging is optional cleanup done by humans.
- Pinning (project term, not a HubSpot term): our config mapping account -> the one official
  company record id the system always writes to.
