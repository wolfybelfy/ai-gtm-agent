# AI GTM Agent

AI GTM Agent is an isolated open-market STRIKE validation system. It evaluates normalized public evidence for companies outside the existing TAL, validates evidence-backed play candidates, prepares ZoomInfo request handoffs only after STRIKE, and saves reviewable Outlook drafts without sending them.

The original `ICP Converstion Intelligence` project is a separate system and must not be edited from this repository.

## V1 flow

`normalized public evidence -> TAL suppression -> fit + heat -> STRIKE -> AI play candidate -> deterministic validation -> ZoomInfo request handoff -> verified-contact import -> unsent Outlook drafts + Monday digest`

The runtime connections are deliberately narrow:

- Public web and SEC/EDGAR research imported as normalized evidence.
- A post-STRIKE ZoomInfo request file and a separate verified-contact import.
- Local Outlook for unsent drafts.

Live web collectors and a live ZoomInfo connector are not enabled in v1. HubSpot, Teams, OneDrive/Graph, Clay, automatic sending, reply monitoring, sequences, and one-pagers are not runtime components. The distilled call and meeting corpus remains local play-writing context, not a runtime integration.

V1 account scope is the United States, United Kingdom, Canada, and UAE. Contact drafts remain limited to verified US-based people with company-domain work email and verified role relevance.

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
