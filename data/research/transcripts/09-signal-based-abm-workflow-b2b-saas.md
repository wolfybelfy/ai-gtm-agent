# 9. Signal-Based ABM Workflow for B2B SaaS

- **Channel:** Rebecca Akparanta
- **Duration:** 08:12
- **URL:** https://youtu.be/e76zA4IvJ2s
- **Captured:** 2026-07-26 via /watch skill (native captions)
- **Mode:** transcript-only (no frames)

---

# watch: video report

- **Source:** https://youtu.be/e76zA4IvJ2s
- **Title:** Signal-Based ABM Workflow for B2B SaaS
- **Uploader:** Rebecca Akparanta
- **Duration:** 08:12 (492.0s)
- **Detail:** transcript
- **Frames:** skipped (transcript detail)
- **Transcript:** 181 segments (via captions)

## Frames

_No frames extracted._

## Transcript

_Source: captions._

```
[00:04] Hello. Here is an ABM workflow I designed.
[00:06] designed. So, this workflow demonstrates how I
[00:08] So, this workflow demonstrates how I would design a signal-based
[00:10] would design a signal-based qualification engine for a B2B SaaS
[00:14] qualification engine for a B2B SaaS company.
[00:15] company. So, the aim is
[00:17] So, the aim is um to set up a decision system that
[00:20] um to set up a decision system that helps GTM teams spend their time on
[00:22] helps GTM teams spend their time on accounts most likely to convert and um
[00:27] accounts most likely to convert and um recommend next steps for them. So, first
[00:29] recommend next steps for them. So, first things
[00:30] things Let me first run this workflow.
[00:33] Let me first run this workflow. So, for this workflow, this is the first
[00:35] So, for this workflow, this is the first node.
[00:36] node. This first node is scheduled to run
[00:39] This first node is scheduled to run daily.
[00:40] daily. So, what it does is it automatically
[00:42] So, what it does is it automatically runs every morning 8:00 a.m. to trigger
[00:46] runs every morning 8:00 a.m. to trigger this workflow.
[00:47] this workflow. Now, in an actual production
[00:50] Now, in an actual production environment,
[00:51] environment, after the daily signal node is run,
[00:55] after the daily signal node is run, this should be
[00:56] this should be the node directly under this the the
[01:01] the node directly under this the the So, for this node, this is a Google
[01:03] So, for this node, this is a Google Sheet, and this Google Sheet contains,
[01:05] Sheet, and this Google Sheet contains, you know, leads that have been extracted
[01:08] you know, leads that have been extracted daily. Now, this can easily be replaced
[01:11] daily. Now, this can easily be replaced with like a CRM, your um HubSpot
[01:15] with like a CRM, your um HubSpot exports, or any data source at all. So,
[01:18] exports, or any data source at all. So, how the workflow would be would be daily
[01:20] how the workflow would be would be daily signal,
[01:22] signal, scan
[01:23] scan the then the data source, and then ICP,
[01:26] the then the data source, and then ICP, and then it runs
[01:27] and then it runs like that.
[01:29] like that. But, for the purpose of this sample,
[01:33] But, for the purpose of this sample, yeah, I'll be using embedded sample data
[01:36] yeah, I'll be using embedded sample data to run this workflow.
[01:38] to run this workflow. So, after the daily signal, the ICP,
[01:41] So, after the daily signal, the ICP, just for this sample.
[01:44] just for this sample. Um
[01:46] Um Before processing accounts, workflow
[01:49] Before processing accounts, workflow defines the ideal customer profile, and
[01:52] defines the ideal customer profile, and then it assigns score
[01:54] then it assigns score to different buying signals. For
[01:57] to different buying signals. For example, hiring a GTM engineer is
[01:59] example, hiring a GTM engineer is definitely a stronger buying signal,
[02:02] definitely a stronger buying signal, yeah?
[02:03] yeah? Than simply having
[02:05] Than simply having an active um founder on LinkedIn. So,
[02:08] an active um founder on LinkedIn. So, the scoring model
[02:10] the scoring model definitely um reflects that difference.
[02:14] definitely um reflects that difference. Then next is the
[02:16] Then next is the enrichments and um the scoring.
[02:20] enrichments and um the scoring. So, for this, each account is evaluated
[02:24] So, for this, each account is evaluated against those criteria that we already
[02:27] against those criteria that we already looked at. And then the workflow
[02:29] looked at. And then the workflow calculates an ABM score,
[02:32] calculates an ABM score, which is over here.
[02:39] Which is over here. It calculates an ABM score, then it
[02:42] It calculates an ABM score, then it records the signals that were found.
[02:47] records the signals that were found. You can see these are signals that were
[02:48] You can see these are signals that were detected.
[02:50] detected. Do they have um a GTM engineer? Do they
[02:52] Do they have um a GTM engineer? Do they have a growth manager?
[02:55] have a growth manager? Are they currently hiring a GTM
[02:57] Are they currently hiring a GTM engineer? What's the hiring growth and
[03:00] engineer? What's the hiring growth and all of that? You can see
[03:01] all of that? You can see those signals over there.
[03:04] those signals over there. And then
[03:06] And then it's going to assign it an outreach
[03:08] it's going to assign it an outreach angle.
[03:11] angle. One second. So, here.
[03:12] One second. So, here. Signals fired. And then it's going to
[03:15] Signals fired. And then it's going to assign it an outreach angle angle over
[03:17] assign it an outreach angle angle over here.
[03:19] here. For this tier,
[03:21] For this tier, it says it's urgent, timing urgent.
[03:24] it says it's urgent, timing urgent. Yeah, gap finding. You know, it just
[03:27] Yeah, gap finding. You know, it just goes ahead and scores them that way. And
[03:29] goes ahead and scores them that way. And then it puts them into various tiers.
[03:32] then it puts them into various tiers. You can see um
[03:34] You can see um this is the hot one, this one, watch,
[03:38] this is the hot one, this one, watch, and skip. And then it puts them into
[03:42] and skip. And then it puts them into those groups.
[03:44] those groups. Next, it's routes by um
[03:47] Next, it's routes by um it by the ABM tier.
[03:50] it by the ABM tier. So, here I did set up some rules on if
[03:54] So, here I did set up some rules on if it hits this criteria, then it should go
[03:56] it hits this criteria, then it should go to hot. If it hits this, then it should
[03:59] to hot. If it hits this, then it should go to this according to how it has been
[04:02] go to this according to how it has been scored. Yeah.
[04:04] scored. Yeah. Then hot accounts receives immediate
[04:07] Then hot accounts receives immediate attention.
[04:09] attention. It generates an AI research prompts and
[04:12] It generates an AI research prompts and then straight over here, it's notify
[04:14] then straight over here, it's notify Slack.
[04:16] Slack. Next, it's updates to HubSpot where it
[04:19] Next, it's updates to HubSpot where it goes in there and then creates the
[04:21] goes in there and then creates the company and all of that. Then
[04:23] company and all of that. Then later on, we can go ahead and enrich and
[04:26] later on, we can go ahead and enrich and find a contact at that company. But for
[04:28] find a contact at that company. But for now, record this is just account base.
[04:31] now, record this is just account base. Yeah.
[04:32] Yeah. Then
[04:34] Then over here, you can see I said reverse
[04:37] over here, you can see I said reverse engineer and draft. So, what's in a
[04:41] engineer and draft. So, what's in a normal production environment, what this
[04:43] normal production environment, what this would have done is it's going to reverse
[04:45] would have done is it's going to reverse engineer that company using the outreach
[04:48] engineer that company using the outreach angle, you know, find tips and open
[04:51] angle, you know, find tips and open opening topics for us and then it's
[04:53] opening topics for us and then it's going to draft the email and send
[04:56] going to draft the email and send automatically. But I intentionally kept
[05:00] automatically. But I intentionally kept a human review step here before any
[05:03] a human review step here before any outreach is created. So,
[05:05] outreach is created. So, they won't get any outreach. There will
[05:07] they won't get any outreach. There will be no draft done. Instead, it goes
[05:10] be no draft done. Instead, it goes directly to Slack over here. In 1
[05:13] directly to Slack over here. In 1 second, I'm going to show the message
[05:15] second, I'm going to show the message how it comes into Slack.
[05:17] how it comes into Slack. And then for warm accounts, warm
[05:18] And then for warm accounts, warm accounts are queued for
[05:20] accounts are queued for um additional research. Then for the
[05:24] um additional research. Then for the watch accounts,
[05:26] watch accounts, these ones are monitored for future
[05:28] these ones are monitored for future signals, you know, until we get stronger
[05:32] signals, you know, until we get stronger buying signals.
[05:33] buying signals. Yeah, until they appear for the watch
[05:36] Yeah, until they appear for the watch one. It's still under watch. Then for
[05:37] one. It's still under watch. Then for this one, we just skip totally.
[05:41] this one, we just skip totally. Yeah, we skip this one totally. So, over
[05:43] Yeah, we skip this one totally. So, over here,
[05:49] you can see this was the Let's Okay.
[05:51] Let's Okay. Let's run Let's come back here
[05:54] Let's run Let's come back here and run the workflow again.
[06:15] Just a monitor for the Slack notification we get.
[06:17] notification we get. So,
[06:23] as you can see, this just came in right now.
[06:26] right now. 12:13 a.m.
[06:29] 12:13 a.m. So, it's gives you
[06:31] So, it's gives you all the signals that it found,
[06:34] all the signals that it found, which is already uh hiring for a GTM
[06:37] which is already uh hiring for a GTM engineer.
[06:39] engineer. They because they don't have a GTM
[06:41] They because they don't have a GTM engineer. And then, you can see all the
[06:44] engineer. And then, you can see all the signals that they found. Then, the
[06:46] signals that they found. Then, the outreach angle, and then next step, what
[06:49] outreach angle, and then next step, what you need to do.
[06:50] you need to do. And then, for the warm channel, it also
[06:54] And then, for the warm channel, it also tells you the signals that was found,
[06:56] tells you the signals that was found, and tells you to go ahead and, you know,
[06:58] and tells you to go ahead and, you know, do additional research for this company,
[07:01] do additional research for this company, and then find a GTM gap,
[07:04] and then find a GTM gap, simply because the initial one we run
[07:08] simply because the initial one we run we had scores, you know, we had scores
[07:10] we had scores, you know, we had scores and we had criteria. So, this one would
[07:13] and we had criteria. So, this one would need a human in the loop to do an extra,
[07:15] need a human in the loop to do an extra, you know, search, and a human to okay
[07:18] you know, search, and a human to okay this, and then see if it's okay,
[07:21] this, and then see if it's okay, then move to the next step, or if we
[07:23] then move to the next step, or if we should keep this under
[07:26] should keep this under watch.
[07:27] watch. Yeah.
[07:30] Yeah. Then, uh we have the
[07:32] Then, uh we have the the campaign summary.
[07:34] the campaign summary. The workflow produces a campaign
[07:36] The workflow produces a campaign summary. Um what it does is just showing
[07:39] summary. Um what it does is just showing us the distribution of
[07:42] us the distribution of the accounts according to you know each
[07:45] the accounts according to you know each tier
[07:46] tier the average scoring the most common
[07:49] the average scoring the most common buying signal
[07:51] buying signal and all of that
[07:53] and all of that you can see it here to buy a signal
[07:56] you can see it here to buy a signal and then the average score over here
[08:03] and then the distribution according to all the tiers for all to go one for one
[08:06] all the tiers for all to go one for one we got one
[08:08] we got one and
[08:09] and that's it
```

---
_Work dir: `C:\Users\admin\AppData\Local\Temp\claude\C--Users-admin-Documents-ICP-Converstion-Intelligence\03221956-24c
e-4a13-bc0f-a3578636edd2\scratchpad\t9` — delete when done._
