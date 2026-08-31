# Scoring rules — arithmetic, not vibes (strategy §3, encoded 2026-07-27)

Run per team, daily. The daily brief must SHOW the arithmetic (trigger list, windows, source classes) so a human can audit every tier decision.

## 0. Disqualifiers FIRST (binary, checked before any score)
1. Team belongs to a current client's direct competitor → `config\conflict-list.csv`. **Amended 2026-07-29:** Gate 1 is now **SIGNED-EMPTY** for the 26 accounts currently in `config\accounts.csv` — the user verified the TAL as conflict-free, so an empty file here means *verified no conflicts*, not *nobody looked*. The sign-off record is in `config\gates.md`. This disqualifier still fires for (a) any account added to accounts.csv after 2026-07-29, until confirmed, and (b) any entity later written into conflict-list.csv. SDR-sheet comment markers ("Q1 cool off", "Inbound", "Priority List") are context only and do NOT disqualify — user decision 2026-07-29.
2. Team is an active client, in an open opportunity, or inside 90-day suppression → `staging\hubspot\suppression.csv` (global — consulted by every path).
3. Region we can't lawfully cold-contact yet → Gate 3 matrix (country × channel). No row = no send into that country.

## 1. Decision table (strategy §3, verbatim logic)
| Lane | Condition | Action |
|---|---|---|
| **STRIKE** | ≥2 triggers from Tiers A–C on the same team, ALL in-window, from **different sources** | Full build within 24h; SDR owns it same week |
| **SEQUENCE** | exactly 1 Tier-A trigger in-window | Buying group + sequence; no SDR call time until engagement |
| **WATCH** | 1 Tier-B trigger, or anything strong but out-of-window | Log re-check date computed from the window into `data\watch-calendar.csv` |
| **NOTHING** | everything else | Log it, move on. Volume is not the goal. |

- "Different sources" means independent detection paths (e.g., ATS diff + press release), not two echoes of one press release. The ATS lane, the SEC lane and the newsroom are independent of each other; `news_broad` and `news_wire` carrying the same wire release are **one** source, not two.
- **Scoreable (amended 2026-07-29).** A team is scoreable when it has **structural evidence** — it is named verbatim in a public source we fetched (its own job ad, press release, leadership page or filing) and has an evidence URL with confidence HIGH or MED. A named leader is **not** required to enter this table.
  - *Why this changed:* the original rule made an unnamed leader `not_scoreable`, which contradicted `config\enrichment-policy.md` (naming is verdict-gated Tier-2 work, because enrichment credits are finite and are spent only after a verdict). It was also already being violated in practice: the system's first STRIKE — Thomson Reuters, Legal High Value Growth marketing — sits on a team named verbatim in TR's own job ad whose leader is deliberately unnamed. Two live documents disagreeing is worse than either rule alone, so the rule now follows the credit policy.
  - A team with neither a named leader **nor** structural evidence is still `not_scoreable` and never enters this table. Speculative subdivision does not create a team.
  - The leader gets named at the verdict step, scoped to that one team's buying group. A team gets named when it gets hot, not before.
- Tier-C windows are hypotheses (see yaml); a Tier-C leg inside STRIKE arithmetic must be flagged as such in the brief.
- Tier-D items are evidence/ammunition ONLY — they never count toward any lane.

## 2. Evidence rules (v1.1 — plan Part B)
- ONE **primary** source (SEC filing, the company's own newsroom/careers/leadership page) suffices alone.
- Two **secondary** sources count only if independent — two outlets echoing one press release are ONE source. `independence_note` in triggers.jsonl says why they're independent.
- Facts stated as facts; inferences written as hypotheses; negative evidence ("no marketing roles posted") always carries its coverage limitation.
- Every claim in every prospect-facing draft carries an evidence URL fetched fresh (CLAUDE.md hard rules 5–6).

## 3. Windows
- Event windows: `start_date − 98d … start_date − 56d` (Tier B, 8–14 weeks pre-event).
- `in_window` is computed at scoring time from `window_open`/`window_close`, never assumed from detection date.
- Out-of-window = scores zero; strong-but-early goes to WATCH with a computed `recheck_date`.

## 4. Dedup + lifecycle
- `dedup_key = team_id|trigger_type|window_open_anchor`, checked against `data\fired-log.csv` before every append. Nothing fires twice on unchanged evidence.
- A trigger MAY legitimately reopen on a material change: new window anchor → new dedup_key; old row marked `superseded_by`. Reopen is a recorded judgment call, never an automatic re-fire.

## 5. Coverage states (every account, every run)
`checked_unchanged | checked_changed | partial | source_unavailable | parse_failure | manual_review`
"Nothing changed" and "couldn't look" must NEVER produce the same output. The daily brief lists per-account coverage state.
