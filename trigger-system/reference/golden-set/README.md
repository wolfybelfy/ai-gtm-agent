# Golden set — human-confirmed scoring cases (self-building, v1.1)

One file per confirmed case: the input evidence (verbatim quotes + URLs + dates) → the human-confirmed team, tier, and window. Every human-confirmed scoring decision from Phase 3 onward gets copied here (strike-build.md step 8).

Purpose: regression. **Before any prompt/model/tool change (Phase 6 rule): re-run scoring on every case here. Inconsistent tiers on identical evidence → scoring arithmetic moves into deterministic code; the model keeps extraction + narrative only.**

Acceptance floor: ≥10 cases by end of Phase 3.

File naming: `case-NNN-<account>-<team>-<tier>.md`
