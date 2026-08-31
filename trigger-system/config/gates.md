# Gates — block SENDS, never builds (strategy §7 + plan v1.1/v1.2)

| # | Gate | Owner | Status | Blocks |
|---|---|---|---|---|
| 1 | **Client-conflict rules signed** — named untouchable-competitor-team list into `conflict-list.csv` | Sales leadership | **SIGNED-EMPTY 2026-07-29 (user) for the original 26; EXTENDED 2026-08-03 to the +10 expansion (user); RE-OPENED 2026-08-14 for the 29 TAL-expansion accounts — sign-off PENDING** | Nothing for the signed 36. EVERYTHING for the 29 pending accounts (watch-only). See the sign-off records below. |
| 2 | **Sending infrastructure** — HubSpot Sequences (needs Sales Hub Pro/Ent + Sales seat) vs SmartLead/Instantly-class; **2–3 secondary domains bought DAY 0** | Marketing ops | UNSIGNED (asked 2026-07-27; domains NOT purchased) | Any send. Never from the main domain. |
| 3 | **Lawful basis, per country AND channel** — decision matrix: country × channel (email/call/LinkedIn/tracking) × recipient type → allowed/conditions/unsubscribe. Owned by legal — their document, not ours to invent. | Legal | **WAIVED FOR THE US PILOT (user, 2026-07-28: "no legal issue"). UNSIGNED for everywhere else.** | Nothing for US targets. Still blocks any non-US send. Non-US region rows at 65 accounts (verified vs accounts.csv 2026-08-15): g42 (AE, watch-only), checkpoint (IL), siemens (DE) — 62 rows are US. Foreign-parent accounts tracked as US rows (temenos, zoho US arms) are fine for US targeting; any non-US individual still needs the matrix (per-play judgment, recorded in the play). |
| 4 | **SDR queue owner + backup named** — accepts STRIKE tasks in 24h, owns the fast-reply clock | Sales ops | **PARTIALLY RESOLVED 2026-08-13**: SD-owned model mapped per "AI agentic master" + HubSpot-verified (config\hubspot-owners.csv; BUILD-STATE Q8). STILL OPEN: named BACKUP owner; whether SDs run the strike queue themselves or SDRs execute under them; 10 accounts carry ARCHIVED owners. | Pilot start (Phase 5). Alerts into an empty room book nothing. |

## Gate 1 sign-off record (2026-07-29)

**Signed EMPTY by the user, directly.** Their words: the accounts on the current TAL "are verified"
and "none of them are in conflict".

What this means, precisely, so a later session does not misread it:
- `config\conflict-list.csv` is **intentionally empty**, and empty now means **verified-no-conflicts**,
  not "nobody has looked". The distinction matters because the previous rule treated a header-only
  file as an unsigned gate that blocked every send.
- Scope: the **26 accounts currently in `config\accounts.csv`**. It is not a blanket future waiver.
  Any account ADDED later re-opens this gate for that account until the user confirms it.
- The `sheet_comment` markers carried from the SDR master sheet (`Q1 cool off`, `Q1 Master cool off`,
  `Inbound`, `Priority List`) are **retained as context only** and are NOT treated as disqualifiers.
  User decision 2026-07-29: do not gate on them.
- Unchanged by this: CLAUDE.md rule 9 (owner-run form, 2026-08-16) — every send is a human
  action by the play's owner and the run is recorded in the play's `status.md`. Gate 1 was never
  the only thing standing between a draft and a send.

## Gate 1 sign-off record — expansion accounts (2026-08-03)

**Signed by the user, directly**, for the 10 accounts added 2026-08-02: workday, jamf, upwork,
mongodb, veeam, rubrik, xero, taboola, genesys, connectwise. Their words: **"None of them is
competitor, they are good to go!"**
- Scope: exactly these 10. The rule stands: any account added after this date re-opens the gate
  for that account until the user confirms it.
- `conflict-list.csv` remains intentionally empty = verified-no-conflicts for the 36 accounts
  signed as of 2026-08-03 (the original 26 + this 10).

## Gate 1 RE-OPENED — TAL-expansion accounts (2026-08-14) — SIGN-OFF PENDING

29 accounts admitted 2026-08-14 from the Q2 Master SD+SDR TAL (list in
`briefs\2026-08-14-tal-expansion.md` and in their `accounts.csv` rows, each carrying a
"GATE-1 PENDING" note): thryv, cisco, cornerstone, microsoft, paycom, paylocity, salesforce,
cloudera, epicor, godaddy, intuit, linkedin, logicmonitor, vanta, zendesk, atlassian, docusign,
grammarly, trimble, dell, newrelic, nextiva, siemens, splunk, zoho, checkpoint, xerox, temenos,
qualtrics.
- **Status: NOT signed. All 29 are WATCH-ONLY** — verdicts and evidence are recorded, but no
  play is built and no alert implies outreach until the user signs this batch off.
- **linkedin needs an explicit individual ruling** (TAL comment "Inbound"; it is a marketing-
  platform vendor — the user must rule on conflict-of-interest before it is ever more than watch).
- The headless Monday prompt enforces the watch-only rule mechanically (step 5, added 2026-08-15).

## Deliverability gate (v1.1 — replaces "domains warmed 2–3 weeks"; entry condition for Phase 5)
Sending starts only when ALL of:
- SPF / DKIM / DMARC configured and verified on the send domains
- Seed-list test passed across Gmail/Outlook/Yahoo-class providers
- Bounce + complaint thresholds, ramp policy, and an emergency-pause rule agreed with the Gate-2 owner

_Status: NOT STARTED (domains not purchased)._

---

## Deliverability gate - operational checklist (added 2026-07-28; adapted from the SignalForce deliverability method, vendor-neutral)
_For the Gate-2 owner. The gate is PASSED only when every line below is evidenced. Phase-5 entry depends on it._

**Domains + capacity (decide before buying anything)**
- Never send cold from the primary company domain. Use 3-5 secondary/lookalike domains (user reports some exist - unverified, Gate-2 Q6).
- 2-3 sending accounts per domain; hard cap 25-30 emails/day/account at FULL warmup. 15 accounts = ~450/day theoretical ceiling. Our pilot needs ~25 STRIKES total, so capacity is a non-issue - this is about reputation, not volume.

**DNS - all three verified before a single send**
- SPF (softfail `~all` is the safer default), DKIM (generated in the mail platform, published as TXT), DMARC (`p=quarantine` first; move to `p=reject` only after ~30 days of clean reports).
- If link tracking is used at all, use a custom tracking subdomain (CNAME), never the vendor's shared default.
- Verify each record with an external checker before ramping (MXToolbox-class tool).

**Warmup ramp (never skipped, never switched off)**
| Week | Emails/day/account | Allowed |
|---|---|---|
| 1-2 | ~5 | warmup pool only, NO prospects |
| 3-4 | ~15 | limited prospect sends |
| 5+ | 25-30 | full capacity |

**Monitoring + pause thresholds (weekly)**
- Blacklist check per sending domain; Google Postmaster reputation (target High), spam rate < 0.1%.
- Bounce rate: <2% healthy | 2-5% PAUSE and clean the list | >5% STOP the campaign and audit where the list came from.
- Emergency-pause rule and who may pull it must be named BEFORE the first send (plan requirement, not optional).

**Our additions (rails, not from the source method)**
- Seed-list test across Gmail/Outlook/Yahoo-class providers before real sends.
- No open-tracking-based intent claims (approved deviation (c)); tracking, if enabled, informs priority only.
- Every send is still a human action by the play's owner, recorded per CLAUDE.md rule 9 (owner-run, 2026-08-16) - deliverability health never converts into an automated send.
