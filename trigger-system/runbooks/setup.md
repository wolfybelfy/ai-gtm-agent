# Setup

## Requirements

- Windows PowerShell 5.1 or newer.
- Python 3 with the standard library. No package install is required.
- ZoomInfo environment variables only when running live enrichment:
  - `ZOOMINFO_CLIENT_ID`
  - `ZOOMINFO_CLIENT_SECRET`
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

## Optional attended provider checks

ZoomInfo remains dry-run unless `-Execute` is supplied to its adapter. Keep `-MaxCredits` low on the first attended run.

Outlook remains dry-run unless `-Execute` is supplied:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\publish-outlook-drafts.ps1 -InputPath staging\runtime\runs\YYYY-MM-DD\drafts.json -DryRun
```

After reviewing the payload, replace `-DryRun` with `-Execute` to save unsent drafts. The script has no send path.
