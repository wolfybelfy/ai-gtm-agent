# Runbook: session-close (EVERY session, no exceptions)

1. Update `BUILD-STATE.md`: current phase/status, last-session bullets (≤3), next 3 actions, any blocking-question or access-table change, any new decision (dated).
1b. Update `MEMORY.md` (the root catch-up file) whenever anything material changed — status, proofs, constraints, asks — and bump its "Last updated" date. It must always read true for a human catching up cold.
2. Append `logs\run-log.md`: date/time, session type (build|daily-watch|strike|review), what ran, coverage summary, anomalies, model + Claude Code version if known.
3. `git add -A` → `git commit` (message says what actually happened) → `git push`.
4. If any gate/access status changed: update auto-memory too.

A session that skipped this is treated as UNVERIFIED by the next session — which re-runs the previous phase's acceptance checks anyway (CLAUDE.md read order, step 5).
