# Monday Run

## 1. Build the evidence handoff

Create `staging\runtime\inbox\` with three schema-compatible JSONL files:

- `candidates.jsonl`: normalized company, domain, headquarters, and fit score.
- `signals.jsonl`: signal type, affected team, observed date, source URL/key, verbatim evidence, confidence, and metadata.
- `play-candidates.jsonl`: Play Director output for STRIKE accounts.

`contacts.jsonl` is optional on the first pass. It is the second-pass handoff for provider-verified contact results.

Public research and semantic play building must run without ZoomInfo credentials or Outlook objects. Do not reuse the synthetic fixture as live evidence.

## 2. Run deterministic validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ai-gtm.ps1 -DryRun
```

The run writes decisions, `zoominfo-requests.json`, validated plays, a draft-only payload, a digest, and stage receipts under `staging\runtime\runs\<date>\`.

## 3. Review holds and claims

Open `digest.md`. Resolve only with evidence. Common holds are missing AI candidate, unverified employment, domain mismatch, non-US location, unavailable work email, unknown pain, and stale proof. Never guess through a hold.

## 4. Complete the ZoomInfo handoff only when needed

Live ZoomInfo execution is not enabled in v1. Review `zoominfo-requests.json`, obtain results through an attended export or a future approved connector, and import only verified records as `contacts.jsonl`. Re-run deterministic validation; the changed input hash creates a new second-pass result.

## 5. Save Outlook drafts

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\publish-outlook-drafts.ps1 -InputPath staging\runtime\runs\<date>\drafts.json -DryRun
```

Review recipients, subjects, bodies, proof omissions, and hold states. Use `-Execute` only to save drafts. The user presses Send manually in Outlook.

## Recovery

Re-run the same command after a failure. An identical fully completed run is reused. If a failure happened before the final receipt, deterministic stages rebuild safely; no paid call or Outlook write exists inside the pipeline. Draft idempotency keys remain stable for unchanged inputs. If evidence or policy changes, the pipeline creates a new run identity.
