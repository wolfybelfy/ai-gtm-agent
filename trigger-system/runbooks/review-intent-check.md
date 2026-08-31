# Runbook: review-platform intent check (weekly, HUMAN-PACED, browser)
_Candidate trigger `review_platform_intent` (untested, added 2026-07-28). Evidence-only until the weekly review promotes it._

## Why this runbook exists in this form
The SignalForce repo's method for this signal was a scraper driven by a copied G2 session cookie, explicitly to "bypass IP blocks". **That method is rejected permanently** (circumvents a site's access controls / ToS; risks the account and produces evidence we could not cite anyway). The user approved the SIGNAL, and this runbook is the sanctioned way to get it — the same path already proven on NetSuite: the user's real signed-in Chrome (AI Agent profile), human-scale reading of specific public pages, no automation against bot walls.

## What we are actually looking for
Public, observable facts on review platforms that indicate a marketing team is EVALUATING or has recently changed tooling:
- new reviews (last ~90d) written by employees of a TAL account on a martech category page (marketing automation, ABM, CDP, marketing analytics);
- a review that says, in the reviewer's own words, that they migrated / are replacing / are comparing tools;
- category comparison pages where a TAL account's tool is being compared (public content only).

## Steps (weekly, ~15 min, max 10 page reads per session)
1. Open the AI Agent Chrome profile (the one paired for automation). Confirm the user is signed in as themselves. **Read only. Never copy a session cookie into a file or script. Never automate against a block page.**
2. For each account with an OPEN candidate window (or the current STRIKE/SEQUENCE queue), open the relevant category page and the account's tool page. 3-5 second pauses; stop at 10 reads.
3. If a page shows a block/CAPTCHA: STOP for that account, record coverage `source_unavailable`. No retry loops, no evasion. Ever.
4. Record findings to `data\review-intent\<date>.csv` with: account_id, platform, page_url (fetched this session), observed_fact (verbatim quote or "no new reviews in window"), review_date, coverage_state.
5. Negative results are results: "no evaluation activity observed, coverage = public review pages only" goes in the file exactly like a positive.

## Rules that never bend
- Evidence class = **secondary** unless the reviewer's employer is stated on the page itself.
- A review is a PERSON's public statement: never quote a named individual's review at that individual in outreach, and never imply surveillance ("saw you comparing vendors" is banned by copy-rules). The signal ranks priority and informs the hypothesis; the email cites the company-level fact, not the person.
- If the account's own newsroom/JD evidence contradicts the review, the primary source wins.
- Official G2 Buyer Intent (paid product) is the ONLY route to buyer-intent data beyond public pages. If the company ever buys it, it plugs in here as a primary source and this manual step retires.
