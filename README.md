# AI GTM Agent

AI GTM Agent is an isolated open-market STRIKE system. It discovers and evaluates companies outside the existing TAL, builds evidence-backed plays, prepares ZoomInfo enrichment requests only after STRIKE, and saves reviewable Outlook drafts without sending them.

The original `ICP Converstion Intelligence` project is a separate system and must not be edited from this repository.

## V1 flow

`public evidence -> TAL suppression -> fit + heat -> STRIKE -> AI play candidate -> deterministic validation -> ZoomInfo -> unsent Outlook drafts -> Monday digest`

The runtime connections are deliberately narrow:

- Public web and SEC/EDGAR sources for evidence.
- ZoomInfo for post-STRIKE people verification.
- Local Outlook for unsent drafts.

HubSpot, Teams, OneDrive/Graph, Clay, JustCall, Serper, automatic sending, reply monitoring, sequences, and one-pagers are not runtime components.

## First safe run

```powershell
cd "C:\Users\admin\Documents\AI GTM Agent\trigger-system"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ai-gtm.ps1 -DryRun -Fixture
```

This uses synthetic inputs, consumes no ZoomInfo credits, and creates no Outlook items. Review the generated `staging\runtime\runs\<date>\digest.md` and `drafts.json`.

Run all shipping checks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-v1.ps1
```

See [setup](trigger-system/runbooks/setup.md) and [Monday operation](trigger-system/runbooks/monday-run.md).
