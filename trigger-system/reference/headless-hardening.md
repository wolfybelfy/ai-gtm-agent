# Headless hardening — known failure modes and the defense for each
_Researched live 2026-07-27 (official docs fetched + GitHub issue tracker). Built BEFORE Phase 6 so no failure mode is met for the first time in production. Task Scheduler registration itself still happens only at Phase 6 with explicit user sign-off._

## Failure modes observed in the wild (Claude Code issue tracker, live-searched 2026-07-27)
| # | Failure | Source | Our defense |
|---|---|---|---|
| 1 | Headless run hangs on a permission prompt it cannot display (no TTY → silent infinite hang) | issue #51927 | `--permission-mode dontAsk` + explicit `--allowedTools` allowlist — nothing is ever able to prompt |
| 2 | Process completes the work, emits the final result, then never exits | issue #25629 | Wrapper enforces a HARD wall-clock timeout and kills the process tree; a run that produced its output before the kill still counts as success (output parsed from the log, not from process exit) |
| 3 | Scheduled runs hang/time out where the same prompt works interactively (scheduler env ≠ interactive env: PATH, env vars) | issue #69173 (launchd = macOS Task Scheduler analog) | Wrapper resolves the absolute `claude` path itself, sets its own working dir + env vars, and fails LOUDLY (alert file) if resolution fails — no inherited-environment assumptions |
| 4 | Generic indefinite hangs needing SIGKILL, incl. Windows-specific | issues #24478, #38258, #50616 | Same hard timeout + `taskkill /T /F` (whole tree); single-instance lock file so a hung run can never overlap the next day's run |
| 5 | MCP servers delaying/blocking startup or dying mid-run | docs (mcp.md) + our own Clay finding (an MCP server that can't even spawn on Windows) | Watch run launches with `--bare` + `--strict-mcp-config` + an EMPTY mcp config: ZERO servers, ever — which is also exactly what credential separation (rail E-2) already required |

## Documented facts the wrapper relies on (official CLI docs, fetched 2026-07-27)
- `--max-turns N` exists (print mode; non-zero exit when hit) → bounds runaway agent loops.
- **No built-in wall-clock timeout flag exists** → the wrapper MUST own the clock. Belt-and-braces: Task Scheduler's own "Stop the task if it runs longer than…" is set too.
- `--output-format json` → machine-parseable result; exit codes: 0 success, 1 error, 143 SIGTERM.
- `--bare` recommended for CI/scripts: skips MCP/hook auto-discovery (faster, reproducible).
- `--no-session-persistence` → each daily run is a throwaway fresh session (no `--continue`/`--resume`).
- `--permission-mode dontAsk` is the documented unattended mode (NOT `bypassPermissions` — docs reserve that for isolated containers; this PC is not that).
- Relevant env vars: `API_TIMEOUT_MS` (default 600000), `BASH_DEFAULT_TIMEOUT_MS` / `BASH_MAX_TIMEOUT_MS`, `MCP_TIMEOUT`, `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS` (cap on waiting for background subagents in `-p`).
- `/loop` and cloud Routines are NOT suitable here (session-scoped / no local file access). Local Task Scheduler + `claude -p` is the right shape; docs have no Windows-specific page, hence this spec.

## The wrapper: `scripts\run-daily-watch.ps1` — **RETIRED 2026-08-15 (git rm; recover from history if Phase 6 wants daily)**
_The cadence has been Monday-only since 2026-07-29, this wrapper was never scheduled, and it
carried the exact Start-Process arg-quoting bug the Monday wrapper fixed after a verified smoke
failure. The PROVEN pattern to clone for any future daily run is `scripts\run-monday-unattended.ps1`.
The hardening findings below (flags, timeouts, lock, verdict parsing) remain valid as design
reference — they describe behavior, not a currently-existing file:_
Behavior, in order:
1. **Lock**: refuses to start if a healthy lock exists (single instance); removes stale locks (dead PID).
2. **Environment pinning**: resolves the absolute `claude` path, `Set-Location` to the repo, sets timeout env vars explicitly.
3. **Launch**: `claude -p` with `--bare --strict-mcp-config --mcp-config config\empty-mcp.json --permission-mode dontAsk --allowedTools <DRAFT list below> --max-turns 80 --output-format json --no-session-persistence`, stdout/stderr redirected to `logs\headless\<date>.out.json` / `.err.txt`.
4. **The clock**: hard wall-clock timeout (default 45 min) → `taskkill /T /F` on the whole tree.
5. **Verdict**: parse exit code AND the output log (a completed JSON result before a timeout-kill = success with a note). Append one line to `logs\run-log.md`.
6. **Failure path**: one bounded retry; if the retry also fails → write a `[SYSTEM]` alert file to `staging\alerts\` (loud, never silent).
7. **Release lock.**

**DRAFT tool allowlist for the watch run** (finalized at the Phase-6 trap test, before any scheduling):
`Read, Glob, Grep, Write, Edit, WebFetch, WebSearch, Bash(powershell -File scripts/*), Bash(git *)` — no MCP, no mail, no credentials (rail E-2). The drain/mailer steps are SEPARATE invocations and are NOT covered by this wrapper.

## Phase-6 acceptance drills this spec adds (beyond the plan's 10-run soak)
1. **Kill-path drill**: force a hang (e.g. absurdly low timeout) → verify the wrapper kills the tree, logs TIMEOUT, writes the alert file.
2. **Lock drill**: start a second run while one is live → verify refusal.
3. **Env drill**: run once FROM Task Scheduler (not a terminal) before trusting it — issue #69173's exact trap.
4. Scheduled-invocation skill trap test (already in the plan) runs alongside these.
