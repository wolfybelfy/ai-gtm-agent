import unittest
from dataclasses import replace
from datetime import date

from agent.claims import load_commercial_truth
from agent.decision import decide
from agent.models import Account, Signal
from agent.signals import load_signal_policy
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
                role_relevance_verified=True,
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
                role_relevance_verified=True,
            ),
        ]
        account = Account("acme", "Acme", "acme.example", "United States", 74)
        self.decision = decide(
            account,
            [
                Signal(
                    "leader",
                    "acme.example",
                    "new_marketing_leader",
                    "marketing",
                    date(2026, 7, 15),
                    "https://acme.example/leadership",
                    "acme-leadership",
                    "New leader",
                ),
                Signal(
                    "hiring",
                    "acme.example",
                    "hiring_surge",
                    "marketing",
                    date(2026, 8, 20),
                    "https://boards.greenhouse.io/acme",
                    "acme-greenhouse",
                    "Three roles",
                    metadata={"open_role_count": 3},
                ),
            ],
            AS_OF,
            load_signal_policy(),
        )
        self.candidate = PlayCandidate(
            play_id="2026-08-31-acme-marketing",
            account_domain="acme.example",
            verdict="STRIKE",
            signal_types=("new_marketing_leader", "hiring_surge"),
            evidence_signal_ids=("leader", "hiring"),
            pain_statement="The team may be balancing a rebuild with current pipeline work.",
            pain_grade="corpus_supported_hypothesis",
            capability_id="gtm_strategy",
            committee=(
                CommitteeMember(
                    contact_id="us-champion",
                    functional_labels=("champion",),
                    reason="Owns the affected demand work.",
                    role_hypothesis="VP Demand Generation",
                    selected_for_outreach=True,
                ),
                CommitteeMember(
                    contact_id="uk-influencer",
                    functional_labels=("influencer",),
                    reason="Owns adjacent systems.",
                    role_hypothesis="Marketing Operations Director",
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
        play = build_play(self.candidate, self.contacts, self.truth, AS_OF, self.decision)
        self.assertEqual([draft.contact_id for draft in play.drafts], ["us-champion"])
        self.assertEqual(play.holds[0].contact_id, "uk-influencer")
        self.assertIn("US-based", play.holds[0].reason)

    def test_stale_or_mismatched_claim_is_omitted(self):
        play = build_play(self.candidate, self.contacts, self.truth, AS_OF, self.decision)
        self.assertNotIn("three times", play.drafts[0].body.lower())
        self.assertIn("aws_event_program", play.omitted_claims)

    def test_employment_mismatch_is_held(self):
        contacts = [replace(self.contacts[0], current_employer_verified=False)]
        candidate = replace(
            self.candidate,
            committee=(self.candidate.committee[0],),
            drafts=(self.candidate.drafts[0],),
        )
        play = build_play(candidate, contacts, self.truth, AS_OF, self.decision)
        self.assertEqual(play.drafts, ())
        self.assertIn("employment", play.holds[0].reason)

    def test_committee_size_is_not_artificially_bounded(self):
        extras = tuple(
            CommitteeMember(
                contact_id=f"research-{index}",
                functional_labels=("influencer",),
                reason="Research-only committee hypothesis.",
                role_hypothesis="Research role",
                selected_for_outreach=False,
            )
            for index in range(10)
        )
        candidate = replace(
            self.candidate,
            committee=self.candidate.committee + extras,
        )
        play = build_play(candidate, self.contacts, self.truth, AS_OF, self.decision)
        self.assertEqual(len(play.committee), 12)

    def test_unknown_pain_cannot_create_drafts(self):
        candidate = replace(self.candidate, pain_grade="unknown")
        play = build_play(candidate, self.contacts, self.truth, AS_OF, self.decision)
        self.assertEqual(play.drafts, ())
        self.assertTrue(all("unknown" in hold.reason for hold in play.holds))

    def test_blocked_phrase_rejects_candidate(self):
        bad_draft = replace(
            self.candidate.drafts[0],
            body_template=BASE_BODY.replace("We support", "Our platform can support"),
        )
        candidate = replace(self.candidate, drafts=(bad_draft,))
        with self.assertRaises(PolicyError):
            build_play(candidate, [self.contacts[0]], self.truth, AS_OF, self.decision)

    def test_non_strike_candidate_is_rejected(self):
        with self.assertRaises(PolicyError):
            build_play(replace(self.candidate, verdict="WATCH"), self.contacts, self.truth, AS_OF, self.decision)

    def test_candidate_evidence_must_match_the_actual_strike_decision(self):
        with self.assertRaises(PolicyError):
            build_play(
                replace(self.candidate, evidence_signal_ids=("leader", "invented")),
                self.contacts,
                self.truth,
                AS_OF,
                self.decision,
            )

    def test_stale_proof_cannot_be_pasted_directly_into_body(self):
        copied = BASE_BODY.replace(
            "{proof}",
            "A published technical-event program reported three times live attendance, more than 250 registrations.",
        )
        candidate = replace(
            self.candidate,
            committee=(self.candidate.committee[0],),
            drafts=(replace(self.candidate.drafts[0], body_template=copied, proof_id=None),),
        )
        with self.assertRaises(PolicyError):
            build_play(candidate, [self.contacts[0]], self.truth, AS_OF, self.decision)

    def test_personal_email_domain_is_held(self):
        contact = replace(self.contacts[0], email="alex@gmail.com")
        candidate = replace(
            self.candidate,
            committee=(self.candidate.committee[0],),
            drafts=(self.candidate.drafts[0],),
        )
        play = build_play(candidate, [contact], self.truth, AS_OF, self.decision)
        self.assertEqual(play.drafts, ())
        self.assertIn("work email domain", play.holds[0].reason)

    def test_unverified_role_relevance_is_held(self):
        contact = replace(self.contacts[0], role_relevance_verified=False)
        candidate = replace(
            self.candidate,
            committee=(self.candidate.committee[0],),
            drafts=(self.candidate.drafts[0],),
        )
        play = build_play(candidate, [contact], self.truth, AS_OF, self.decision)
        self.assertEqual(play.drafts, ())
        self.assertIn("role relevance", play.holds[0].reason)


if __name__ == "__main__":
    unittest.main()
