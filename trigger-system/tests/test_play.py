import unittest
from dataclasses import replace
from datetime import date

from agent.claims import load_commercial_truth
from agent.play import (
    CandidateDraft,
    CommitteeMember,
    Contact,
    PlayCandidate,
    PolicyError,
    build_play,
)


AS_OF = date(2026, 8, 31)
BASE_BODY = (
    "Your marketing leadership change and three open roles point to a team rebuilding "
    "plans while execution is still moving. That can create a difficult choice between "
    "getting the new operating model right and keeping near-term pipeline work on schedule. "
    "{proof} We support B2B teams when that planning and execution gap appears. I may be "
    "off, but is the bigger priority currently team capacity or audience quality?"
)


class PlayTests(unittest.TestCase):
    def setUp(self):
        self.truth = load_commercial_truth()
        self.contacts = [
            Contact(
                contact_id="us-champion",
                full_name="Alex Morgan",
                title="VP Demand Generation",
                company_domain="acme.example",
                work_country="United States",
                current_employer_verified=True,
                email="alex@acme.example",
                email_verified=True,
            ),
            Contact(
                contact_id="uk-influencer",
                full_name="Sam Taylor",
                title="Marketing Operations Director",
                company_domain="acme.example",
                work_country="United Kingdom",
                current_employer_verified=True,
                email="sam@acme.example",
                email_verified=True,
            ),
        ]
        self.candidate = PlayCandidate(
            play_id="2026-08-31-acme-marketing",
            account_domain="acme.example",
            verdict="STRIKE",
            signal_types=("new_marketing_leader", "hiring_surge"),
            pain_statement="The team may be balancing a rebuild with current pipeline work.",
            pain_grade="corpus_supported_hypothesis",
            capability_id="gtm_strategy",
            committee=(
                CommitteeMember(
                    contact_id="us-champion",
                    functional_labels=("champion",),
                    reason="Owns the affected demand work.",
                    selected_for_outreach=True,
                ),
                CommitteeMember(
                    contact_id="uk-influencer",
                    functional_labels=("influencer",),
                    reason="Owns adjacent systems.",
                    selected_for_outreach=True,
                ),
            ),
            drafts=(
                CandidateDraft(
                    contact_id="us-champion",
                    subject="planning gap",
                    body_template=BASE_BODY,
                    proof_id="aws_event_program",
                ),
                CandidateDraft(
                    contact_id="uk-influencer",
                    subject="planning gap",
                    body_template=BASE_BODY,
                    proof_id=None,
                ),
            ),
        )

    def test_only_selected_verified_us_contacts_receive_drafts(self):
        play = build_play(self.candidate, self.contacts, self.truth, AS_OF)
        self.assertEqual([draft.contact_id for draft in play.drafts], ["us-champion"])
        self.assertEqual(play.holds[0].contact_id, "uk-influencer")
        self.assertIn("US-based", play.holds[0].reason)

    def test_stale_or_mismatched_claim_is_omitted(self):
        play = build_play(self.candidate, self.contacts, self.truth, AS_OF)
        self.assertNotIn("three times", play.drafts[0].body.lower())
        self.assertIn("aws_event_program", play.omitted_claims)

    def test_employment_mismatch_is_held(self):
        contacts = [replace(self.contacts[0], current_employer_verified=False)]
        candidate = replace(
            self.candidate,
            committee=(self.candidate.committee[0],),
            drafts=(self.candidate.drafts[0],),
        )
        play = build_play(candidate, contacts, self.truth, AS_OF)
        self.assertEqual(play.drafts, ())
        self.assertIn("employment", play.holds[0].reason)

    def test_committee_size_is_not_artificially_bounded(self):
        extras = tuple(
            CommitteeMember(
                contact_id=f"research-{index}",
                functional_labels=("influencer",),
                reason="Research-only committee hypothesis.",
                selected_for_outreach=False,
            )
            for index in range(10)
        )
        candidate = replace(
            self.candidate,
            committee=self.candidate.committee + extras,
        )
        play = build_play(candidate, self.contacts, self.truth, AS_OF)
        self.assertEqual(len(play.committee), 12)

    def test_unknown_pain_cannot_create_drafts(self):
        candidate = replace(self.candidate, pain_grade="unknown")
        play = build_play(candidate, self.contacts, self.truth, AS_OF)
        self.assertEqual(play.drafts, ())
        self.assertTrue(all("unknown" in hold.reason for hold in play.holds))

    def test_blocked_phrase_rejects_candidate(self):
        bad_draft = replace(
            self.candidate.drafts[0],
            body_template=BASE_BODY.replace("We support", "Our platform can support"),
        )
        candidate = replace(self.candidate, drafts=(bad_draft,))
        with self.assertRaises(PolicyError):
            build_play(candidate, [self.contacts[0]], self.truth, AS_OF)

    def test_non_strike_candidate_is_rejected(self):
        with self.assertRaises(PolicyError):
            build_play(replace(self.candidate, verdict="WATCH"), self.contacts, self.truth, AS_OF)


if __name__ == "__main__":
    unittest.main()
