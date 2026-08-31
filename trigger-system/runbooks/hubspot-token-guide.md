# HubSpot access - plain-English guide for getting the key (hand this to the super admin)
_Written 2026-07-28; UI path re-verified 2026-07-29 against HubSpot's live docs and CORRECTED - see below._

> ## WHEN TO USE THIS SHEET
> **DONE — the token landed 2026-08-10** (super admin created the legacy private app per this
> guide; read scopes live-verified; owners scope added 2026-08-13). This sheet's purpose is
> spent; it stays as the reference for scope changes or token rotation. The paragraph below is
> historical.
>
> ~~**Not yet.**~~ As of 2026-07-29 nothing in the active work needed HubSpot: not the Monday watcher, not
> the map research pass, not building a play to `ready`. It buys three things and all three land later
> - suppression checking (needed before the FIRST SEND, which is blocked on sending domains anyway),
> the `closed_lost_reactivation` trigger (1 of 17), and writing plays back to the CRM (the Outlook
> alert already handles the SDR handoff).
>
> **Trigger to use this sheet:** the same trip where the sending-domain owner is available, i.e. when
> Gate 2 is being closed. One walk, both problems. Until then this file just sits here.

## WHAT CHANGED 2026-07-29 (important - the older wording is now wrong)
HubSpot renamed and reorganised this flow. The 2026-07-28 version of this guide said "private app",
which no longer matches the UI:
- What used to be **Private apps** now lives under **Development -> Legacy apps**.
- HubSpot has introduced **Service Keys** as the modern, purpose-built replacement for exactly our
  case: a data-only, server-to-server integration with no webhooks and no UI extensions.
- **Ask for a SERVICE KEY, not a legacy private app.** It is still sent as `Authorization: Bearer <key>`,
  so `Invoke-HubSpotApi` in `scripts\lib.ps1` needs no change at all. Service Keys rotate without
  downtime (rotate-and-expire-later gives a 7-day overlap window) and are account-level rather than
  tied to one person's login.
- **CAVEAT (verified against official docs 2026-07-30): Service Keys are still PUBLIC BETA** -
  "functionality is still under active development and subject to change". They are REST-only (no
  webhooks - fine for us). If the admin is beta-averse, a legacy private app is the stable choice
  and behaves identically for our scripts.
- Legacy private apps still work if the admin insists; the token behaves identically for us.

## What we are asking for, in one sentence
A **Service Key**: a password-like key that lets the scripts on Uday's PC read and write ONLY the seven
specific things listed below in our HubSpot - nothing more.

## Why it is safe
- **Scopes are a hard fence.** The token can only do what is ticked at creation. Nothing else works, even if asked.
- **Revocable in one click.** The super admin can delete the app any time; the token dies instantly.
- **Our side has two extra brakes:** a kill-switch file that halts all CRM writing the moment it exists, and a rule that NO write happens until a HubSpot admin has reviewed what we write (see "the RevOps person" below).
- **Storage:** the token lives only in a Windows environment variable on Uday's PC. Never in a file, never in git, never in chat. Scripts are built to never print it.
- **Writes are boring by design:** one note + one task per play, plus three custom fields namespaced `ts_`. Nothing that sends email, nothing that touches existing automations.

## Cost
- Creating and using a private app has **no separate fee** - it is a built-in feature of the HubSpot platform, and API usage sits inside the subscription's existing limits. Our volume (a few dozen calls on play days) is a rounding error against those limits.

## Steps for the SUPER ADMIN (about 3 minutes) - CORRECTED 2026-07-29
_Requires Super Admin OR Developer-tools access._

1. Log into HubSpot.
2. **Development -> Keys -> Service keys.** (This is the path the official docs show as of 2026-07-30;
   if a "Settings -> Integrations" route exists in your portal it lands on the same screen.)
3. Click **Create a service key**.
4. Name it **trigger-system**. A description helps whoever audits it later: "trigger-based outbound - notes, tasks, company fields".
5. Add exactly the seven scopes listed below - nothing more. Review them on the confirmation screen.
6. Click **Create**, then **copy the key immediately** - it is shown once.
7. Hand it to Uday directly (password manager or in person - not email if avoidable).

_If the admin cannot find Service Keys, the older path still works:_ **Development -> Legacy apps ->
Create legacy app -> Private**, then the **Auth** tab -> **Show token** -> **Copy**. The key behaves
identically for us; Service Keys are simply the better-supported option now.

### The seven scopes - tick exactly these:
   - `crm.objects.contacts.read` - see contacts
   - `crm.objects.contacts.write` - update contacts we work
   - `crm.objects.companies.read` - see companies
   - `crm.objects.companies.write` - write the play note/task/fields on companies
   - `crm.objects.deals.read` - READ deals only (for the won/lost history backtest; we never create or edit deals)
   - `crm.schemas.companies.write` - one-time creation of our three `ts_` company fields
   - `crm.schemas.contacts.write` - reserved for the same on contacts

## Two questions to ask the super admin WHILE you are there
1. **"Does our subscription include Sales Hub Professional or Enterprise, and do we have seats?"** - this decides the email-sending tool question: if yes, HubSpot **Sequences** (a tool we already own) is the sender and nothing new is needed; if no, the pilot's 25 sends can go manually from Outlook at zero cost, and only then would we evaluate anything new.
2. **"Who administers our HubSpot day to day?"** - the person who owns fields, workflows and data hygiene. That is the person I keep calling **RevOps** - plain English: **the HubSpot admin**. I need 30 minutes with them ONCE before the first write, so our notes/tasks/fields land in a corner agreed with them and cannot collide with any automation they run (e.g. a workflow that emails people when tasks appear). Until that conversation is recorded, the write scripts refuse to run - by design.

## Steps for UDAY once the token is in hand (60 seconds)
1. Open a **new** PowerShell window.
2. Run: `setx HUBSPOT_PRIVATE_APP_TOKEN "paste-key-here"` (with the quotes).
   _The variable keeps its original name even though the credential is now a Service Key - every
   script already reads `$env:HUBSPOT_PRIVATE_APP_TOKEN`, and renaming it would break them for no gain._
3. Close that window, open another new one (setx only affects NEW windows).
4. Tell the session "token is in" - it will run the connection test (which never prints the token) and set up the three fields in dry-run first.
5. Never paste the token into the chat.

## Fallback
If private apps are not available on the account for any reason, the fallback is HubSpot's official hosted connector (mcp.hubspot.com) - same read/write fence, OAuth login instead of a token. We only go there if the super admin hits a wall.
