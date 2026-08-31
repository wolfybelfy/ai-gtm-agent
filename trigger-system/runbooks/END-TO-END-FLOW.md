# THE LINEAR FLOW — signal to sent email, every step, verified against code 2026-08-03

_One line per step. Executor tags: [SCHED]=Task Scheduler, [SCRIPT]=deterministic ps1,
[HEADLESS]=claude -p (scheduled, no human), [CLAUDE]=attended session, [HUMAN]=a person.
Every step names the file that implements it — if a file is not named, the step does not exist._

## Weekly, fully unattended (live since 2026-08-03; scheduled task `trigger-system-monday-watch`)
1.  [SCHED]    Monday 08:30 -> `scripts\run-monday-unattended.ps1`
2.  [SCRIPT]   `watch-monday.ps1` -> validate accounts -> snapshot 65 job boards (count updated
               2026-08-15; was 36) -> diff vs last week -> `extract-mktg-postings.ps1`
               (marketing-candidate shortlist) -> stack tells
               -> SEC (51 CIKs incl. Form D/S-1/Form 15 + parent-CIK riders) + news RSS
               -> `edgar-battery.ps1` (full-text query battery, MEASUREMENT mode until Phase 3
               promotion) -> coverage ledger
3.  [HEADLESS] `claude -p` per `runbooks\monday-headless-prompt.md` (credentials stripped):
               triage signals + shortlist, fetch primaries where needed, score per
               `config\scoring-rules.md`, record triggers/watches/verdicts, write `briefs\<date>.md`,
               commit+push, queue alert FILES for anything hot
4.  [SCRIPT]   `alert-mailer.ps1` (separate credential-clean process) mails queued alerts to the
               INTERNAL team from `config\alert-recipients.csv`. Any stage failure -> a
               TYPE: SYSTEM "[SYSTEM] FAIL: ..." alert (bare FAIL type was mailer-rejected; fixed 2026-08-15).

## When a verdict fires (attended — money and outreach never run headless)
5.  [CLAUDE]   `runbooks\strike-build.md`: play folder, brief w/ evidence URLs, buying group
               (5-8 people from the maps + on-disk rosters, dated + staleness-flagged;
               Clay removed 2026-08-24), drafted emails w/ cited claims
6.  [SCRIPT]   `scripts\zoominfo-enrich.ps1`: verified work emails via ZoomInfo — the SOLE
               enrichment path (runs automatically as Monday stage 2c over the play queue, or
               attended per-play with -PlayId; verdict = spend authorization per the
               2026-08-04 amendment + the 2026-08-21 every-play rule; suppression-gated,
               credit-capped; results only into gitignored staging + buying groups)
7.  [HUMAN]    The play's OWNER picks it up: runs / edits-then-runs / kills (no approval
               workflow exists — user directive 2026-08-16). The action is recorded:
               `RUN_BY:`/`RUN_DATE:` (or `KILLED_BY:`) in status.md + `plays\index.csv` —
               a log for suppression/dedup/metrics, not a gate.
8.  [SCRIPT]   `hubspot-write-play.ps1 -Execute -AuditConfirmed -AppliedBy <name>`: company note +
               24h SDR task + ts_ fields (kill switch `staging\hubspot\WRITES-PAUSED` honored;
               requires token + recorded RevOps audit; live-fire still pending token day)
9.  [HUMAN]    The owner (or their SDR) copies the play's emails + buying group into the sequencer and CLICKS SEND —
               by design the system has no code path to send to a prospect, ever
               (`strike-build.md` step 7; CLAUDE.md rule 1).
10. [CLAUDE]   Post-send: index updated, decision archived to `reference\golden-set\`.

## Standing dependencies that gate steps 8/9 (owner: user; GO-2 director authority DELETED 2026-08-04; GO-1 CLOSED 2026-08-24 — Clay removed, ZoomInfo live since 2026-08-21 makes step 6 self-serve)
RevOps audit recorded (step 8 — token already HAVE since 2026-08-10) ·
warmed lookalike domain evidence + per-rep mailboxes + sequencer decision (step 9).

## Failure doctrine
Every stage that fails must fail LOUDLY (runner verdicts, [FAIL] alerts, coverage ledger states).
"No change" and "couldn't look" are never the same output. Secondary evidence never fires a
trigger. Every send is a human action by the play's owner and the run is recorded (RUN_BY/RUN_DATE). Enrichment never runs unattended.
