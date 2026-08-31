# ZoomInfo playbook - access path, tools, and how it slots into this system

> **DECOMMISSIONED 2026-08-20 (user order: "remove and delete zoominfo mcp, and whatever
> connection we have with zoominfo").** The MCP registration is gone (verified absent from
> every claude mcp scope), the stale needs-auth cache entry is cleaned, and every live
> instruction surface in the system now names Clay (GO-1) as the only enrichment path.
>
> **RE-ADOPTED later the same day 2026-08-20 (new user order: "set up zoominfo... works in
> automated way") — but via the DIRECT API, not MCP. This file stays historical (the old
> MCP/seat-era record). The live doc is `reference\zoominfo-api-playbook.md`; the live code
> is `scripts\zoominfo-enrich.ps1` + Monday stage 2c.**
> This file is kept as HISTORICAL REFERENCE only - do not re-register or re-integrate
> ZoomInfo without a new explicit user decision. Prior status for the record: account-level
> LOCK at ZoomInfo's login from before 2026-07-28; the unlock deferred to ~08-22 never
> happened; the seat was last proven alive 2026-07-14 by the previous project.
_Compiled 2026-07-28. The strongest evidence here is LOCAL: Unbound's previous project ("Fully-Automated System", `Documents\Website data\`) contains a working ZoomInfo MCP integration whose code comments record live verification on **2026-07-14**. That is real, dated, machine-local evidence — better than any blog. Supplemented by ZoomInfo's own pages fetched live today._

## What we know is true (from the previous project's code — VERIFIED 2026-07-14 by that project)
- **The official ZoomInfo MCP server exists at `https://mcp.zoominfo.com/mcp`** (streamable HTTP).
- **Third-party MCP clients are BLOCKED by ZoomInfo policy.** Its `/oauth/register` accepts only an allowlist of approved vendors; a custom Python client got `400 invalid_client_metadata: "Vendor ... was not found in approved vendors"`. This is policy, not a bug.
- **The Claude CLI is an approved vendor** — the working route on this exact machine was:
  1. `claude mcp add --transport http zoominfo https://mcp.zoominfo.com/mcp`
  2. inside a `claude` session run `/mcp` → authenticate zoominfo in the browser (one-time OAuth as the ZoomInfo user)
  3. the token persists locally for headless reuse; refresh is automatic.
- **The org's ZoomInfo subscription was alive on 2026-07-14** (a real `enrich_contacts` FULL_MATCH was captured live), and the org also has **WebSights** (visitor-identification xlsx exports exist in that project). Q11 ("ZoomInfo live? who holds the key?") is therefore PARTIALLY ANSWERED: seat alive as of Jul 14; current status confirmed the moment the user re-authenticates.
- **Live-captured `enrich_contacts` response quirks** (handle these when parsing):
  - the whole payload can arrive as a JSON **string** (double-encoded) → parse twice if needed;
  - shape: `{"contact_1": {"success": true, "data": {"matchStatus": "FULL_MATCH", firstName, lastName, email, phone, jobTitle, jobFunction{department,name}, managementLevel[list], contactAccuracyScore("50.0" — a STRING), externalUrls[{type,url}] (LinkedIn nested by type), companyName, zoominfoCompanyId, withinEu, withinCalifornia}}, "totalErrors": 0, "totalEnriched": 1}`;
  - clean no-match returns are a matched:false situation — **never fabricate a record from a miss**;
  - **verified-email rule carried over: `contactAccuracyScore >= 85` counts as verified; below that the email lands in results with `email_verified=false`.**
- Accepted match inputs: `email` alone, or `firstName+lastName+companyName`; `externalURL` accepts a LinkedIn URL.

## Current MCP toolset (ZoomInfo's own pages via live search/fetch 2026-07-28 — VERIFY the exact list on first connect)
- `search_companies`, `search_contacts` — filtered search, free preview records.
- `enrich_company`, `enrich_contact` — full profiles (contact enrich = the one the old project used).
- `search_intent` — accounts showing buying intent on chosen topics.
- `enrich_company_signals` — **intent topics + news + Scoops for up to 10 companies per call.** For this system that is not enrichment, that is a TRIGGER SOURCE (Scoops = leadership changes, projects, funding events...).
- `find_recommended_contacts` — AI-ranked contacts at a target account (three modes).
- Licensing per ZoomInfo's connector guide: "API access is included in relevant ZoomInfo plans, no separate SKU" — but confirm with the account team if anything 401s.

## How it slots into THIS system (rails-compliant by construction)
Two distinct uses, both **credentialed drain steps** that read schema-validated staging files and never touch web content (CLAUDE.md rule 7). The WATCH run holds no credentials and never calls ZoomInfo — the Monday wrapper (`run-monday-unattended.ps1`) strips credentials from the headless session; the old `run-daily-watch.ps1` was retired 2026-08-15 (never scheduled; Monday-only cadence).
1. **Contact enrichment (Phase 4, and the Clay-sunset successor):** a drain invocation reads `staging\clay\enrich-requests.csv`, calls `enrich_contact` per row (via a `claude -p` bridge allowing ONLY `mcp__zoominfo__enrich_contact`, system-prompted as a pass-through proxy — the previous project's proven pattern, including "never invent contact fields"), normalizes with the quirks above, writes `staging\clay\enrich-results.csv` with `provider_or_method=zoominfo`. Zero schema change at Clay sunset — that was the whole design.
2. **Signals sweep (optional, Phase 4+, needs its own decision):** periodic `enrich_company_signals` over the 25 TAL accounts → `staging\zoominfo\signals.csv` → the SCORING session treats each scoop/intent row as a **secondary source** under the v1.1 evidence rules (a scoop is an aggregator echo — it still needs primary evidence fetched fresh before any claim reaches a draft, per rule 5). Never wired into the watch run.

## Setup status on this machine
- `claude mcp add --transport http zoominfo https://mcp.zoominfo.com/mcp` — run at **local scope inside `trigger-system\`** on 2026-07-28 (see BUILD-STATE access table for the verification result).
- Remaining step (USER, one-time, ~60 seconds): open a `claude` session in `trigger-system\`, run `/mcp`, pick zoominfo, approve in the browser with the ZoomInfo account. After that the drain scripts can run headless.
- Token lives in Claude CLI's own user-scoped storage — outside this repo, consistent with the secrets rail (no secrets in files here).

## Don'ts
- Don't call ZoomInfo tools from any session that also reads web pages (rule 7 — one process never does both).
- Don't let search/preview tools write anything into plays directly — everything passes through staging CSVs + human review.
- Don't treat a Scoop as primary evidence. It's a pointer; the primary source gets fetched fresh and quoted.
- Contact PII from ZoomInfo goes ONLY into gitignored staging files (rule: PII never enters git).
