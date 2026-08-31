# WORKFLOW 05 — BRIEF WRITER (one brief per HOT cell — the SDR-facing product)

## Input
HOT cell registry row + its signals + contacts CSV + `context/company-profile.md` + `templates/copy-rules.md`

## Output
`data/briefs/<YYYY-MM-DD>-<CELL_ID>.md` in exactly this shape:

```yaml
cell:               <parent> — <cell name>
tier:               HOT
why_now:            # 2–3 sentences, plain speech, every claim traceable to a dated source below
timing_window:      # what closes and when — real urgency only; if the window is soft, say so
signals:
  - {type: ..., date: ..., evidence_url: ..., quote: "..."}
pain_hypothesis:    # what we think is breaking + confidence (HIGH/MED/LOW) — labeled as hypothesis
peer_proof:         # which of Aqua Security / Bugcrowd / Rubrik / AWS OpenSearch / Todyl, and why this one
lateral_reference:  # sibling cell where we're already engaged, if parent is a client — LEAD WITH THIS
buying_group:
  - {name: ..., title: ..., role: ..., angle: ...}
message_variants:   # one per role, written per templates/copy-rules.md, AI-tells stripped
disqualifiers:      # what would make this brief wrong — always filled in
```

## Rules
- Every factual claim in `why_now` and `message_variants` must appear in `signals` with a URL that resolved today.
- `lateral_reference`, when present, outranks every other angle. "We already work with your OpenSearch team" beats any case study.
- No invented metrics anywhere (we publish none). Peer names carry the proof.
- `disqualifiers` is mandatory. A brief that can't say what would falsify it is marketing, not intelligence.
- Draft copy is SDR raw material, not send-ready. Tier-1 sends are always human-edited.
