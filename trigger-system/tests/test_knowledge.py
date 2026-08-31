import json
import re
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
TRIGGER = REPO / "trigger-system"
TRUTH = TRIGGER / "config" / "commercial-truth.json"
FIELD = TRIGGER / "context" / "field-intelligence.md"
RULES = TRIGGER / "context" / "play-rules.md"
DIRECTOR = REPO / ".claude" / "agents" / "play-director.md"


class KnowledgeTests(unittest.TestCase):
    def test_blocked_claims_and_required_claim_fields_are_explicit(self):
        truth = json.loads(TRUTH.read_text(encoding="utf-8"))
        self.assertIn("audience_size", truth["blocked_claim_categories"])
        self.assertIn("unapproved_client_reference", truth["blocked_claim_categories"])
        for proof in truth["proof_points"]:
            self.assertTrue(
                {"id", "use_cases", "claim", "source", "status", "review_after"}
                <= proof.keys()
            )

    def test_field_intelligence_includes_newer_call_corpus_and_limitations(self):
        text = FIELD.read_text(encoding="utf-8").lower()
        self.assertIn("72 analyzed calls", text)
        self.assertIn("123 analyzed calls", text)
        self.assertIn("coverage limitations", text)
        self.assertIn("planning window", text)

    def test_sanitized_intelligence_contains_no_contact_pii(self):
        text = FIELD.read_text(encoding="utf-8")
        self.assertIsNone(re.search(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}", text))
        self.assertIsNone(re.search(r"\+?\d[\d ()-]{8,}\d", text))

    def test_play_director_has_no_fixed_committee_or_sequence(self):
        text = DIRECTOR.read_text(encoding="utf-8").lower()
        self.assertNotIn("5-8", text)
        self.assertNotIn("3-email", text)
        self.assertNotIn("triad, never", text)
        self.assertIn("dynamic buying committee", text)
        self.assertIn("one initial email", text)

    def test_rules_forbid_unbuilt_artifact_promises(self):
        text = RULES.read_text(encoding="utf-8").lower()
        self.assertIn("never promise", text)
        self.assertIn("observed", text)
        self.assertIn("corpus_supported_hypothesis", text)


if __name__ == "__main__":
    unittest.main()
