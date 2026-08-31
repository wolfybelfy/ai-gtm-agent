# Operator Runbook

The active runbooks live inside `trigger-system/runbooks/`:

- `setup.md` for prerequisites and local configuration.
- `monday-run.md` for the weekly evidence-to-draft process and recovery.

Safe verification from `trigger-system`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-v1.ps1
```

The command is local-only. It does not call ZoomInfo and does not create Outlook items.
