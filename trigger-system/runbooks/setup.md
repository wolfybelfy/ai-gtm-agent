# Setup

## Requirements

- Windows PowerShell 5.1 or newer.
- Python 3 with the standard library. No package install is required.
- `AI_GTM_OPERATOR_EMAIL` only when saving the internal Monday digest as an Outlook draft.
- Desktop Outlook signed into the user's mailbox only when saving real drafts.

No other credential is allowed in the runtime environment. Never copy an `.env`, token, credential file, browser profile, or local agent settings from the original project.

## Validate the suppression baseline

From `trigger-system`:

```powershell
python -m agent.cli prepare-suppression --tal "C:\Users\admin\Downloads\Final Master TAL for Paid & Marketing(Assigned).csv"
```

The expected result is 648 unique domains. Review any count change before continuing.

## Prove the local path

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ai-gtm.ps1 -DryRun -Fixture
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-v1.ps1
```

These commands consume no provider credits and create no Outlook items.

## Provider boundary

Live ZoomInfo execution is not enabled in v1. The pipeline writes `zoominfo-requests.json`; export or connector work must return schema-compatible `contacts.jsonl` before the second pass. The environment file retains empty ZoomInfo credential names for a future attended adapter, but this release does not consume them.

Outlook remains dry-run unless `-Execute` is supplied:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\publish-outlook-drafts.ps1 -InputPath staging\runtime\runs\YYYY-MM-DD\drafts.json -DryRun
```

After reviewing the payload, set `AI_GTM_OPERATOR_EMAIL` (or pass `-OperatorEmail`) and replace `-DryRun` with `-Execute` to save unsent prospect and internal-digest drafts. The script has no send path.
