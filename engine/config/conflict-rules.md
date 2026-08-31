# Client-conflict veto list — BLOCKING GATE

**Status: NOT SIGNED. Until sales leadership fills this in and signs it, no outbound leaves the system.**
This is a live commercial risk, not paperwork: we serve Dell, Cisco, Bugcrowd, Aqua Security, Rubrik, AWS (OpenSearch cell), ServiceNow. Prospecting their direct competitors can cost an existing multi-cell logo.

## To be completed by sales leadership (one line each)

| Client (cell we serve) | Named competitors we must NOT prospect | Competitors we MAY prospect | Decided by | Date |
|---|---|---|---|---|
| AWS OpenSearch | ? (Elastic? Splunk? Datadog?) | ? | | |
| ServiceNow (+Armis) | ? | ? | | |
| Cisco | ? | ? | | |
| Dell | ? | ? | | |
| Rubrik | ? | ? | | |
| Bugcrowd | ? (HackerOne? Synack?) | ? | | |
| Aqua Security | ? (Wiz? Sysdig?) | ? | | |
| Todyl | ? | ? | | |

## Enforcement (automated once table is filled)

- Fit-veto step in `workflows/03-score-and-tier.md` checks every cell's parent against column 2. Match → SKIP, permanent, logged.
- Ambiguous case → HUMAN_LOOP, never a guess.
- Review quarterly; competitors change.
