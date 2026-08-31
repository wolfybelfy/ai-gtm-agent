# Monday Run

## 1. Build the evidence handoff

Create `staging\runtime\inbox\` with four schema-compatible JSONL files:

- `candidates.jsonl`: normalized company, domain, headquarters, and fit score.
- `signals.jsonl`: signal type, affected team, observed date, source URL/key, verbatim evidence, confidence, and metadata.
- `play-candidates.jsonl`: Play Director output for STRIKE accounts.
- `contacts.jsonl`: ZoomInfo-verified contact results for the AI-selected roles.

Public research and semantic play building must run without ZoomInfo credentials or Outlook objects. Do not reuse the synthetic fixture as live evidence.

## 2. Run deterministic validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ai-gtm.ps1 -DryRun
```

The run writes decisions, validated plays, a draft-only payload, a digest, and stage receipts under `staging\runtime\runs\<date>\`.

## 3. Review holds and claims

Open `digest.md`. Resolve only with evidence. Common holds are missing AI candidate, unverified employment, domain mismatch, non-US location, unavailable work email, unknown pain, and stale proof. Never guess through a hold.

## 4. Run ZoomInfo only when needed

The AI must first name the role hypotheses. Run the ZoomInfo adapter in plan mode, inspect the count, and use `-Execute` only with a deliberate credit cap. Re-run deterministic validation after importing verified results.

## 5. Save Outlook drafts

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\publish-outlook-drafts.ps1 -InputPath staging\runtime\runs\<date>\drafts.json -DryRun
```

Review recipients, subjects, bodies, proof omissions, and hold states. Use `-Execute` only to save drafts. The user presses Send manually in Outlook.

## Recovery

Re-run the same command after a failure. If the input and policy hash is unchanged, completed receipts are reused and draft idempotency keys remain stable. If evidence or policy changes, the pipeline creates a new run identity.
