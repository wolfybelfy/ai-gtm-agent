import unittest
from datetime import date
from pathlib import Path

from agent.claims import load_commercial_truth
from agent.decision import decide
from agent.models import Account, Signal
from agent.play import CandidateDraft, CommitteeMember, Contact, PlayCandidate, PolicyError, build_play
from agent.providers import draft_payload, zoominfo_request
from agent.signals import load_signal_policy


REPO = Path(__file__).resolve().parents[2]
OUTLOOK_SCRIPT = REPO / "trigger-system" / "scripts" / "publish-outlook-drafts.ps1"
ZOOMINFO_SCRIPT = REPO / "trigger-system" / "scripts" / "zoominfo-enrich.ps1"
AS_OF = date(2026, 8, 31)
BODY = (
    "Your marketing leadership change and three open roles point to a team rebuilding "
    "plans while execution is still moving. That can create a difficult choice between "
    "getting the operating model right and keeping near-term pipeline work on schedule. "
    "{proof} We support B2B teams when that gap appears. I may be off, but is the bigger "
    "priority currently team capacity or audience quality?"
)


class ProviderTests(unittest.TestCase):
    def _strike(self):
        account = Account("acme", "Acme", "acme.example", "United States", 70)
        signals = [
            Signal("a", "acme.example", "new_marketing_leader", "marketing", date(2026, 7, 15), "https://a.example", "a", "New leader"),
            Signal("b", "acme.example", "hiring_surge", "marketing", date(2026, 8, 20), "https://b.example", "b", "Three roles", metadata={"open_role_count": 3}),
        ]
        return decide(account, signals, AS_OF, load_signal_policy())

    def _play(self):
        candidate = PlayCandidate(
            "play-1",
            "acme.example",
            "STRIKE",
            ("new_marketing_leader", "hiring_surge"),
            ("a", "b"),
            "The team may be balancing a rebuild with pipeline execution.",
            "corpus_supported_hypothesis",
            "gtm_strategy",
            (CommitteeMember("c1", ("champion",), "Owns demand.", "VP Demand Generation", True),),
            (CandidateDraft("c1", "planning gap", BODY),),
        )
        contacts = [Contact("c1", "Alex Morgan", "VP Demand", "acme.example", "US", True, "alex@acme.example", True, True)]
        decision = self._strike()
        return build_play(candidate, contacts, load_commercial_truth(), AS_OF, decision)

    def test_zoominfo_request_requires_strike(self):
        watch = self._strike()
        watch = type(watch)(**{**watch.__dict__, "verdict": "WATCH"})
        with self.assertRaises(PolicyError):
            zoominfo_request(watch, ["VP Demand Generation"], set())

    def test_zoominfo_request_refuses_suppressed_domain(self):
        with self.assertRaises(PolicyError):
            zoominfo_request(self._strike(), ["VP Demand Generation"], {"acme.example"})

    def test_zoominfo_request_uses_ai_role_hypotheses(self):
        payload = zoominfo_request(
            self._strike(),
            ["VP Demand Generation", "Marketing Operations Director", "VP Demand Generation"],
            set(),
        )
        self.assertEqual(payload["action"], "enrich_contacts")
        self.assertEqual(payload["role_hypotheses"], ["VP Demand Generation", "Marketing Operations Director"])

    def test_outlook_payload_is_stable_and_draft_only(self):
        first = draft_payload(self._play(), "run-1")
        second = draft_payload(self._play(), "run-1")
        self.assertEqual(first, second)
        self.assertEqual(first["action"], "save_draft")
        self.assertEqual(first["drafts"][0]["action"], "save_draft")
        self.assertNotIn("send", first)

    def test_outlook_adapter_has_save_but_no_send_call(self):
        text = OUTLOOK_SCRIPT.read_text(encoding="utf-8")
        self.assertIn(".Save()", text)
        self.assertNotIn(".Send(", text)
        self.assertIn("[switch]$Execute", text)
        self.assertIn("AI_GTM_IDEMPOTENCY_KEY", text)
        self.assertIn("UserProperties.Find", text)
        self.assertIn("Move-Item", text)
        self.assertIn("internal_digest", text)
        self.assertIn("AI_GTM_OPERATOR_EMAIL", text)

    def test_unsafe_legacy_zoominfo_adapter_is_not_shipped(self):
        self.assertFalse(ZOOMINFO_SCRIPT.exists())


if __name__ == "__main__":
    unittest.main()
