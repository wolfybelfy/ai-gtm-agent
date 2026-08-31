# Monday Agent Prompt

Read `CLAUDE.md` and the active `trigger-system` rules first.

For the current Monday batch:

1. Discover candidate companies headquartered in the US, UK, Canada, or UAE from public sources.
2. Normalize and suppress domains before research spend. The TAL is an exclusion and ICP-reference set, never the discovery universe.
3. Capture fresh evidence with source URL, observed date, verbatim excerpt, team, confidence, and source independence.
4. Apply `config/signal-policy.json`. Keep fit separate from heat and require the STRIKE evidence gate.
5. For each STRIKE, invoke the Play Director to write an AI candidate. Do not force a committee size.
6. Use ZoomInfo only after the committee hypothesis exists. Draft only for verified US-based contacts.
7. Run the deterministic pipeline and review the digest. Outlook may save drafts only after explicit operator execution; never send.

Do not state corpus patterns as company facts. Omit expired, conflicting, or unverified commercial claims. Do not promise a one-pager or follow-up sequence.
