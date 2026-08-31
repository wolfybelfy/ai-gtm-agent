# Staging file schemas (the contract — exact columns)

The data files below are **gitignored** (contact PII / plan Part F data classes). This file preserves their exact schemas in git so the contract survives even though the data never enters history. Consumers read files and never know the writer (plan Part D — staging is the interface, permanently).

## staging\hubspot\ (inbound; writer: colleague UI export → later token/MCP refresh script)
- `closed-won.csv` / `closed-lost.csv`: `deal_id, account_name, domain, team_hint, event_date, amount, reason_or_source, as_of_date, notes`
  (`event_date` = close/lost date; `as_of_date` supports the backtest's point-in-time discipline. If HubSpot's UI export emits different columns, the importer maps to THESE canonical columns at the staging boundary — the canonical schema never chases the export format.)
- `suppression.csv`: `email, person, company_domain, reason(active_client|open_opp|90d_suppression|opt_out|other), suppressed_until, source, added_date` — GLOBAL: consulted by every path before any person enters a play.

## staging\hubspot\outbox\ (outbound; committed to git — play records carry no personal contact data)
- `*.jsonl`, one object per line (v1.2 play-record model):
  `{"object":"note_per_play|task","play_id":"...","match_key":"domain|id","note_body_md":"<full play: tier, triggers, why-now, evidence URLs, window — immutable once applied>","task":{"due":"...","owner":"..."},"company_summary_props":{"ts_last_tier":"...","ts_last_window_close":"...","ts_suppression_until":"..."},"idempotency_key":"<play_id>","created":"...","applied_date":"...","applied_by":"...","response_ref":"..."}`
- Kill switch: if `staging\hubspot\WRITES-PAUSED` exists, NO CRM write happens; research continues.

## staging\enrich\ (gitignored — person data; renamed from staging\clay\ 2026-08-24 when Clay was removed entirely by user order — all prior contents moved here intact)
- `enrich-requests.csv`: `request_id, play_id, team_id, account_domain, person_name, person_title_hint, linkedin_url, requested_date, status`
- `enrich-results.csv`: `request_id, play_id, email, email_verified, phone, provider_or_method(manual|clay|zoominfo), resolved_date, notes` — the provider column is the swap point if the provider ever changes; `clay` survives as a historical value on old rows only. Written by `scripts\zoominfo-enrich.ps1` (ZoomInfo = the sole live provider).
- `people-*.csv`: historical roster pulls (Clay-era search results, kept because live plays cite them for provenance) — read-only legacy; new rosters come from ZoomInfo results and play buying-group updates.
- `zoominfo-raw-*.json`: raw API responses captured on anomaly / for the verification ladder.

## staging\alerts\ (gitignored — hot-reply alerts can carry prospect phone numbers)
- `YYYY-MM-DD-HHmm-<type>-<slug>.md` — header block = leading non-blank lines, then a blank
  line, then the body. Core headers (required):
  `TYPE: DIGEST|STRIKE|HOT-REPLY|ESCALATION|SYSTEM`
  `SUBJECT: [DIGEST]|[STRIKE]|[HOT REPLY]|[ESCALATION]|[SYSTEM] ...`
  `TO: <list_name>`  (resolved ONLY via `config\alert-recipients.csv`; never a raw address)
  `STATUS: pending|sent`
  Optional header (added 2026-08-24, STRIKE owner routing):
  `CC: <list_name>`  (resolved via the same CSV; **allowed on TYPE STRIKE only** — the mailer
  refuses it on any other type)
  ROUTING RAIL (user rule 2026-08-24, mailer-enforced): [STRIKE] emails go `TO: owner-<sdr>`
  with `CC: strike-cc` (Gracie + Ameena, always); every NON-STRIKE type may address ONLY
  `default` (the operator) — SEQUENCE plays get no email at all (Teams card only), and
  system/digest/fail mail never reaches the SDR/leadership roster.
  Optional headers (added 2026-08-20, play-scorecard emails):
  `FORMAT: text|html`  (default text; html = body is Outlook-safe HTML, sent via HTMLBody, no auto-footer)
  `ATTACH: <repo-relative path>`  (repeatable; must exist, `..` refused; e.g. `plays\<id>\scorecard.html`)
  Optional headers (added 2026-08-20 late, Teams trigger-brief cards; MAILER IGNORES BOTH):
  `LINK: <url>`  (alert-teams.ps1 renders it as an Action.OpenUrl button on the card; use the
  HubSpot record URL `https://app.hubspot.com/contacts/4747973/record/0-2/<companyId>`)
  `LINK-TEXT: <button label>`  (default "Open the play in HubSpot")
  Body: markdown (text) or inline-styled HTML (html). On send: file moves to `sent\` with a
  `SENT: <utc> BY: <human|com-mailer|graph-mailer>` receipt line appended.
  `TEAMS: yes`  (gate, added 2026-08-21 by user rule: the channel carries ONLY play-ready
  cards — alert-teams.ps1 posts NOTHING without this header; the mailer ignores it. Fails,
  digests and system updates therefore never reach Teams.)
  TEAMS-ONLY files: `STATUS: sent` from birth (mailer skips silently) + `TEAMS: yes`;
  alert-teams.ps1 posts any TEAMS: yes file lacking a `TEAMS-POSTED:` stamp and appends the
  stamp after posting. Card format =
  the user-confirmed 2026-08-20 "trigger brief": bold subject, 2-line why-now, one
  buying-group pointer line, one dates/owner line, LINK button — NO metadata line, no repo
  paths, no system jargon in the card body.
