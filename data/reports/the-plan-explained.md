# The plan, explained simply

*A walkthrough of the trigger-based outbound system. Written to be read out loud and discussed, not filed away.*

---

## 1. What's broken today

Outbound as most teams run it: build a big list, write a decent template, send a lot of email, hope. Reply rates keep falling because every inbox on earth gets the same thing, often written by the same AI tools.

The uncomfortable math behind it: at any moment, only about 3% of a market is actually ready to buy. Blasting the other 97% doesn't just waste effort, it burns the domain and the brand for the day they *are* ready.

So the whole game is: find the 3% inside the accounts we already picked, and get there while the door is open. That's it. Everything below is machinery for that one sentence.

---

## 2. The two ideas everything sits on

**Idea one: we target teams, not companies.**
Our accounts are big. At a company with thousands of people, "VP Marketing" exists many times: one per product line, per region, per acquired brand. Each one has their own budget and their own problems. An email aimed at "ServiceNow" lands nowhere. An email aimed at the Armis marketing team, eight months after the acquisition closed, about the exact problem acquisitions create, lands. So step one of everything: break each account into its real marketing teams, with a named leader per team. 25 accounts becomes 100+ real targets. That's not extra work, that's the actual market becoming visible.

**Idea two: timing beats everything, and timing is detectable.**
People hire an agency when something just changed: a new boss, a market launch, a merger, a big event coming up, goals that outgrew the team. Almost all of these changes leave public traces, and most traces are free to watch. If we watch them daily, we don't guess who's ready. We know, with a date on it.

---

## 3. What we watch (and why each one means money)

Every trigger is a plain question: "why would this team pay an agency *right now*?" Each has a time window. Outside the window it's worth nothing, and the system treats it as nothing.

**The strong ones — one of these can start a play:**
- **A new marketing leader took over a team.** New leaders don't trust what they inherited and need wins fast, before their plans lock in. Window: their day 30 to day 90.
- **The team is hiring several marketers at once.** Goals just outran the team. An agency is capacity without the politics of headcount. Window: while the jobs are open.
- **A marketing job has sat open 60+ days, or got reposted.** Budget exists, the work isn't happening. Window: while it stays open.
- **Their company acquired someone (or got acquired).** Two marketing teams, one brand mess, campaigns that can't stop running. Window: up to 9 months after the deal closes.
- **A job post literally says "manage agencies and vendors."** They wrote down that they'll pay external partners. Hard to get a clearer invitation.
- **Someone we worked with before just landed at a target account.** Warm beats cold, always. We keep a list of past contacts and watch where they go.
- **An old lost deal's account just lit up with new triggers.** We know why it died last time. New leader plus new hiring means the reason may be gone.

**The timing ones — we can be early on purpose:**
- **They're exhibiting at a big conference.** Event money gets spent 2 to 3 months before the event. Reach out then. Two weeks before, it's worthless.
- **Product launch, new region, rebrand, analyst report placement.** Each opens a spend window with a date we can compute.

**The ones we make ourselves:**
- We track who at target accounts engages with demand-gen content on LinkedIn (there's a clean, no-login way to pull this through Clay).
- Everything we send offers a useful piece of work behind a link that tells us who opened it, how long they read, and whether they forwarded it internally. A forward means a new person in the buying group just raised their hand. This is intent data we own, instead of the bought kind, which is overpriced and mostly stale.

**What we deliberately don't use:** bought "intent" feeds (everyone has them, they point at the company not the team), Reddit and community listening, and visitor tracking on our own site (we don't have the traffic for it to mean anything).

---

## 4. The honesty rules

Three rules keep this from becoming spam with extra steps:

1. **One trigger alone rarely sends an email.** Two independent triggers on the same team, both inside their windows, is the bar for a real play. One trigger means we sequence it quietly or just watch with a reminder date.
2. **Every claim in an email traces to evidence we can show.** A quote from their job post, a date from their press release. If the "why now" paragraph reads generic, the play gets downgraded, not decorated.
3. **A human approves every send.** The machine researches, drafts, and queues. A person reads and clicks. Nothing goes to a prospect on autopilot.

---

## 5. A real example, run by hand yesterday

To prove this isn't a slide fantasy, we ran one account through the whole thing manually, with zero paid tools, in about 35 minutes: **TradeStation**.

What the free research found:
- On June 10 they launched a whole European company: Amsterdam entity, licensed for 30 countries, brand-new president (Peter Comstock).
- Their careers page, checked live: 24 open jobs, **not one in marketing**. They're launching in 30 countries with no visible demand team.
- Comstock is roughly 7 weeks into the job, right inside the new-leader window.

That's two live triggers plus supporting evidence on one team. The system's verdict: strike now, on the Europe team specifically. Meanwhile the US marketing team got a "watch" with a reminder: their new trading platform's full launch hasn't been announced yet, and the day it is, that window opens too. We even drafted the three emails, built around offering them a short playbook on how US trading firms built European demand in year one. Soft ask, useful thing, tracked link.

One account, one sitting, no tools. The daily system does this across every account, every morning.

---

## 6. How it actually runs, and what the SDR sees

The stack is what we already have: **Claude Code** does the daily watching and writing (the research layer is essentially free), **Clay** is used only for what it's genuinely good at, finding and verifying the right people's contact info, and **HubSpot** is where everything lands. No new tools for the sales side to learn.

An SDR's morning looks like this:
- A Slack alert: "Strike: TradeStation Europe. New market launch plus new president, window closes in December. Accept within 24 hours."
- In HubSpot, the account record already holds everything: the why-now paragraph, the evidence links, the 5 to 8 right people, and the drafted emails as a note. Review, tweak, approve, go.
- When someone replies or opens the tracked asset, another alert: "call this person now, here's the number, here's what they just read." Four touches inside the hour on anything warm: email reply, LinkedIn connect, call, asset.

The SDR does none of the research and all of the selling.

The system also keeps memory in two places. HubSpot holds the account's story forever (every trigger, send, reply). A small set of local files holds the system's own memory: yesterday's job-posting snapshots (so we can spot stale and reposted roles), a log of every trigger already fired (so nothing fires twice), and a reminder calendar of windows that open later.

---

## 7. How we'll know it's working

We hold it to numbers, judged on **meetings, not replies** (replies flatter tactics that book nothing):

- 25 accounts should map to at least 75 real teams. Fewer means the core idea is off and we stop and look.
- At least 15 strike-worthy timing windows found in the first month.
- Reply rate on strikes at least 3x our current outbound baseline.
- First meetings from strikes by week 6.

And a standing kill rule: any trigger type that sends for two weeks with nothing back gets its weight cut in half; four weeks, it's dead. Before trusting any of the trigger list, we also backtest it against our own history: which of these were actually present before deals we won, and absent before deals we lost. Borrowed theory becomes our evidence in about two days of work.

---

## 8. What it costs

Almost the whole watching-and-thinking layer is free: public job feeds, press releases, event exhibitor lists, Claude Code we already pay for, Slack webhooks. Paid parts, all capped: Clay credits only for contact finding on active plays (rough order: tens of dollars per batch of plays, not hundreds), a sending tool in the $100 to 200 a month range plus a few extra domains, and optionally a small LinkedIn ads budget aimed only at accounts we're actively striking.

---

## 9. What we need decided (four things, none of them slow the build)

1. **Conflict lines.** Which companies are off-limits because of current client relationships. Needs a sign-off before anything sends.
2. **Sending setup.** Whether our HubSpot tier includes sequences, or we buy a sender. Either way, new domains get bought day one because warming them takes 2 to 3 weeks.
3. **Europe.** Legal basis per region before we email anyone in the EU. (The TradeStation play may literally depend on this.)
4. **Who owns the alerts.** A named person on the strike queue and the fast-reply clock. Alerts into an empty room book nothing.

---

## 10. What could go wrong, said out loud

- **The triggers could be wrong for our market.** That's why weights start as guesses, get backtested against our own wins and losses in week 2, and get killed by the weekly numbers. The system is built to be wrong quickly and cheaply.
- **Every number from the videos and newsletters this was researched from is self-reported by someone selling something.** We copied their mechanics, not their claims. Our success bar is our own baseline times three, not somebody's YouTube number.
- **Volume will feel low at first.** That's the design. Ten sharp plays a week beat a thousand sprays, and the watch list compounds: every window we spot with a future date is a meeting attempt already scheduled.
- **It needs the manual reps first.** Weeks 1 and 2 are deliberately hands-on. Automating an unproven motion just ships mistakes faster.

---

*Six weeks from a yes to a running system: map the teams and start the daily snapshots (week 1), triggers live and first hand-run plays plus the backtest (week 2), the HubSpot plumbing and reply handling (week 3), a 25-play pilot with every send human-approved (week 4), then scale what survived the numbers (weeks 5 and 6).*
