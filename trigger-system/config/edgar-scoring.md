# EDGAR signal prioritization rubric — who has the highest need
_From EDGAR_MODULE_SPEC.md section 8, adopted 2026-08-06. This rubric PRIORITIZES filing-derived
signals for triage attention. It does NOT replace the verdict table in `config\scoring-rules.md`:
STRIKE still requires >=2 independent in-window sources on one team; a lone 10-K = SEQUENCE
ceiling; Tier-D never fires._

Score each signal-bearing account 0-2 per axis; act on the total.

| Axis | 0 | 1 | 2 |
|---|---|---|---|
| Stated intent | boilerplate only | general S&M investment language | named initiative: region (EMEA/UK), enterprise shift, or launch program, quoted verbatim |
| Money proof | none | S&M spend disclosed | S&M spend disclosed AND growing in absolute $ year-over-year |
| Change event | none in 12mo | one (filing-derived: exec change, M&A close, restructuring, IPO) | change event inside its window per window arithmetic |
| Capability gap | none visible | thin regional/marketing footprint inferable | gap admitted in Risk Factors, or intl revenue % far above intl headcount % |
| Geo fit | US-only story | international ambition stated | EMEA/UK named explicitly |
| ICP fit | outside tech SICs | adjacent | tech SIC + mid-market/enterprise SaaS/IT profile |

Totals: **9-12** -> verdict-layer candidate now (independent-sources rule still applies).
**5-8** -> SEQUENCE / nurture with the quoted context attached. **<=4** -> tag account, no action.

Highest-need archetypes (evidence classes seen in real filings): (1) fresh S-1 with
use-of-proceeds marketing spend + Risk-Factor marketing-gap confession; (2) filer whose intl
revenue share far exceeds intl headcount share + stated intl expansion; (3) filer mid
enterprise-shift (large-customer count growing much faster than total customers) with S&M >=
~35-45% of revenue and growing; (4) 8-K marketing-exec change at a tech filer (new-leader
window); (5) PE-lane account 1-3 quarters post-close (current live example: jamf, 15-12G
2026-02-09, wc-011).
