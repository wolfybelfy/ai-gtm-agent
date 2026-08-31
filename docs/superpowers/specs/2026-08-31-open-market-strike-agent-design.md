# Open-Market STRIKE Agent Design

**Date:** 2026-08-31  
**Project:** AI GTM Agent  
**Status:** Approved design, pending implementation plan

## Purpose

Build a separate, local-first GTM agent that discovers companies outside the existing TAL, identifies time-sensitive buying signals, builds evidence-backed plays, finds the relevant buying committee through ZoomInfo, and creates unsent Outlook drafts for the user to review and send.

The original `ICP Converstion Intelligence` project remains unchanged and continues operating against the existing TAL. This repository is an independent system with its own data, configuration, state, credentials, and Git history.

## V1 Operating Boundaries

- Run as a Monday weekly batch with resumable checkpoints.
- Discover companies headquartered in the US, UK, Canada, and UAE.
- Suppress every company in the supplied master TAL plus the original project's additional suppression domains.
- Research eligible companies in all four markets, but draft outreach only for contacts verified as US-based.
- Use public sources for discovery and corroboration. SEC/EDGAR is a primary source, not the entire discovery universe.
- Use ZoomInfo only after a company earns a STRIKE verdict.
- Use Outlook only to create unsent drafts and one consolidated internal Monday digest.
- Do not connect HubSpot, Teams, OneDrive/Graph, Clay, JustCall, or Serper at runtime.
- Do not monitor replies, create follow-up sequences, or generate one-pagers.
- Do not add DeepSeek Harness, AlphaEvolve, a vector database, or an optimization loop to v1. The core contracts remain provider-neutral so experiments can be added later without changing evidence or safety rules.

## Architecture

The weekly flow is:

`market registry -> signal collection -> suppression -> fit and heat scoring -> evidence verification -> STRIKE verdict -> play generation -> ZoomInfo enrichment -> Outlook drafts -> Monday digest`

Seven bounded components own the flow:

1. **Market Registry** maintains candidate companies, normalized domains, headquarters, source provenance, and suppression status.
2. **Signal Collectors** gather public evidence for leadership changes, hiring patterns, acquisitions, launches, expansion, analyst events, and other configured signals.
3. **Evidence Ledger** stores source URLs, dates, excerpts, confidence, independence, observed company/team, and signal-window status.
4. **Decision Engine** calculates independent ICP-fit and signal-heat scores and applies the STRIKE evidence gates.
5. **Play Builder** converts verified evidence into a business hypothesis, dynamic buying committee, outreach subset, and role-specific message angles.
6. **ZoomInfo Enrichment** runs only for STRIKE accounts and verifies current employment, work contact data, location, and relevant role.
7. **Outlook Publisher** creates unsent drafts and a consolidated internal digest. It never sends mail automatically.

Each component reads a defined input file and writes a defined output file. A failed stage can resume without repeating completed paid enrichment or creating duplicate drafts.

## Discovery and Suppression

The master TAL is an exclusion list and an ICP reference set, not the new system's discovery universe. V1 imports its 637 normalized domains and adds the 11 original-only domains, producing 648 suppression domains before any later manual additions.

Suppression occurs before scoring, paid enrichment, or play generation. Domain matching is case-insensitive and strips schemes, paths, `www`, and trailing dots. Subsidiary or alternate-domain relationships that cannot be proved are marked for review rather than guessed.

The market registry can contain public and private companies. SEC/EDGAR provides strong public-company coverage; ATS/job pages, corporate newsrooms, leadership pages, reputable reporting, and other public sources extend discovery beyond SEC filers.

## Signal Model

The duplicate preserves the original signal catalogue and time windows.

### Tier A

- New CMO, VP Marketing, Head of Marketing, or equivalent: 30-90 days in role.
- Hiring surge: at least 2-3 simultaneously open roles in the same relevant team.
- Stale or reposted role: 60+ days open or observed within 0-30 days of repost.
- Acquisition integration: 0-9 months after close, not merely announcement.
- Agency or third-party vendor language in an open job description.
- Past champion joining a new company: 30-120 days.
- Fresh cluster of relevant closed-lost history, when a lawful local data source exists.

### Tier B

- Conference or event: 8-14 weeks before the event.
- Product launch: 6 weeks before through 12 weeks after launch.
- Regional expansion: 0-6 months.
- Analyst placement: 0-8 weeks.
- Rebrand: 0-6 months.
- Funding: 0-90 days, with low standalone weight.

### Evidence-only and experimental

Capability gaps support a hypothesis but do not independently create a STRIKE. Martech replatforming, review-platform intent, and executive content about rebuilding are experimental until validated. Retired Clay/LinkedIn engagement signals and tracked-asset/reply signals are not used in v1.

A STRIKE normally requires at least two independent, in-window signals affecting the same business or team. A primary source can establish a fact, but it does not remove the need for a coherent commercial hypothesis. Fit and heat remain separate: a low-fit/high-heat company may surface as an explicitly labelled outlier rather than being silently rejected.

## Field-Intelligence Layer

V1 uses a small, auditable knowledge stack rather than model training or raw-transcript retrieval.

### Raw vault

Raw AE recordings, meeting transcripts, JustCall JSON, names, phone numbers, and emails remain read-only in their existing local locations. They are never committed to this repository or loaded wholesale into a weekly model prompt.

### Distilled field intelligence

A sanitized, versioned document combines:

- the May JustCall corpus covering 72 analyzed calls;
- the Q2 revenue and sales findings;
- the July-August corpus covering 123 analyzed calls;
- the AE discovery/demo meeting analysis;
- persona-specific openers and discovery questions;
- buying-committee and consensus-selling research.

It preserves useful patterns, representative language, coverage limits, and provenance while removing contact-level PII. Newer evidence does not silently erase older contradictory evidence; conflicts are recorded.

### Commercial truth register

A separate register owns approved positioning, capabilities, proof points, terminology, prohibited claims, source, approval status, and review date. The latest explicit commercial ruling wins. If a claim is stale, contradictory, unverified, or outside the matched use case, the Play Builder omits it.

Permanently blocked prospect-copy claims include audience-size figures, unsupported GDPR language, delivery guarantees, comparative benchmarks, and unapproved client references. Event proof and rebrand/pipeline proof are not interchangeable.

### Play rules

The play rules apply field evidence without turning it into a script. They prioritize:

- discovery and relevance before a broad pitch;
- the problem implied by the verified trigger;
- one relevant capability;
- one matched, verified proof point or no proof point;
- language that can be forwarded internally;
- a low-friction question rather than a first-touch meeting request.

The system must not promise a one-pager, audit, sample, or other artifact unless that artifact already exists and is approved for use.

## Dynamic Buying Committee

The AI determines the buying committee from the play, company structure, observed change, and likely ownership. There is no fixed number of contacts and no mandatory role triad.

Possible functional labels include champion, decision-maker, influencer, blocker, connector, and insider, but only labels supported by the specific play are used. The Play Builder separately selects the smaller outreach subset. A committee member is not automatically an email target.

ZoomInfo runs after that role hypothesis exists. Each enriched contact must pass current-employment, company, work-location, and role-relevance checks. Only verified US-based contacts are eligible for Outlook drafts in v1.

## Play and Email Contract

Every STRIKE account receives a complete internal play containing:

- verified trigger evidence and sources;
- signal-window calculations;
- fit score, heat score, confidence, and why-now explanation;
- business pain hypothesis and its evidence grade;
- dynamic committee and outreach-subset reasoning;
- one role-specific angle per selected contact;
- omitted or conflicting claims;
- resulting draft status.

Every pain statement is labelled internally as:

- `observed`: directly supported by company-specific evidence;
- `corpus_supported_hypothesis`: supported by field patterns but not confirmed for this company;
- `unknown`: insufficient evidence and therefore not stated as fact.

The initial email is plain text, normally 60-90 words and 3-5 sentences. It uses context followed by implication, avoids surveillance language, contains at most one verified numerical proof point, and does not expose filings, requisition IDs, or research mechanics. Subjects are short, lowercase, and natural. There is no automatic follow-up sequence.

## Outlook Safety

Outlook integration creates drafts only. It does not call Send, schedule Send, or simulate keystrokes that could send a message. A deterministic idempotency key based on run, account, contact, and play version prevents duplicate drafts after a restart.

The internal Monday digest contains STRIKE accounts, evidence summaries, selected contacts, draft status, held non-US contacts, review warnings, and failures. It is also created as an unsent draft unless the user later makes a separate decision to automate internal delivery.

## Credentials and Data Handling

Secrets are loaded from an explicit environment-variable allowlist and are never copied from the original repository, written to logs, included in snapshots, or committed. The repository contains an example environment file with variable names only.

Generated runtime data, contact data, draft payloads, logs, checkpoints, and raw evidence excerpts are Git-ignored. Version control contains code, configuration, sanitized knowledge, schemas, tests, and runbooks only.

## Failure Handling

- Network and source failures are recorded per source and do not convert missing evidence into a negative fact.
- A collector can be retried without changing an already verified record.
- Ambiguous domains, identities, locations, dates, or employment are held for review.
- Missing or stale commercial claims produce an email without that claim, not an invented substitute.
- ZoomInfo failures stop contact enrichment for the affected account without spending repeated credits on restart.
- Outlook failures leave a recoverable payload and do not mark a draft as created.
- A weekly run can finish partially; the digest distinguishes completed, held, and failed accounts.

## Testing Strategy

Automated tests cover domain normalization and suppression, signal-window boundaries, source independence, STRIKE gating, separate fit/heat scoring, dynamic committee output, US-contact eligibility, claim blocking, PII-safe knowledge files, email constraints, idempotency, and checkpoint recovery.

ZoomInfo and Outlook boundaries use local fakes in automated tests. A separate manual smoke test may validate the user's real connections, but it cannot send email. Fixture accounts are synthetic and contain no real prospect contact data.

The original project is protected by a before/after read-only fingerprint check. Shipping verification must show no changed files in `ICP Converstion Intelligence`.

## Shipping Definition

V1 is shipped when:

1. The duplicate has an independent Git history and no remote pointing to the original repository.
2. The 648-domain suppression baseline is reproducibly generated and validated.
3. A fixture-driven Monday run completes from discovery input through STRIKE play and draft payload.
4. All automated tests pass.
5. A dry run creates no external side effects and consumes no ZoomInfo credits.
6. An optional explicit live smoke test can verify ZoomInfo and Outlook draft creation without sending email.
7. Documentation explains setup, Monday operation, restart behavior, review workflow, and how to add future collectors or model providers.
8. A final fingerprint confirms the original project was not modified.

## Explicitly Deferred

- Automatic sending and reply monitoring.
- Follow-up sequences.
- One-pager generation.
- HubSpot, Teams, Clay, OneDrive/Graph, JustCall, and Serper integrations.
- DeepSeek Harness or AlphaEvolve orchestration.
- Embeddings, vector search, self-optimizing weights, and autonomous claim creation.
- Outreach to non-US contacts.

