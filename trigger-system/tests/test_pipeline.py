import json
import shutil
import tempfile
import unittest
from datetime import date
from pathlib import Path

from agent.pipeline import run_pipeline
from agent.cli import main


TRIGGER = Path(__file__).resolve().parents[1]
FIXTURES = TRIGGER / "fixtures" / "monday"
TEST_TMP = Path(__file__).parent / ".tmp"
TEST_TMP.mkdir(exist_ok=True)


class PipelineTests(unittest.TestCase):
    def test_fixture_run_builds_one_strike_and_one_draft_payload(self):
        with tempfile.TemporaryDirectory(dir=TEST_TMP) as folder:
            output = Path(folder)
            result = run_pipeline(FIXTURES, output, as_of=date(2026, 8, 31))
            self.assertEqual(result.strike_count, 1)
            self.assertEqual(result.draft_count, 1)
            self.assertEqual(result.suppressed_count, 1)
            self.assertTrue((output / "digest.md").exists())
            payload = json.loads((output / "drafts.json").read_text(encoding="utf-8"))
            self.assertEqual(payload["action"], "save_draft")
            self.assertEqual(payload["internal_digest"]["action"], "save_draft")
            self.assertEqual(payload["internal_digest"]["to_env"], "AI_GTM_OPERATOR_EMAIL")
            requests = json.loads((output / "zoominfo-requests.json").read_text(encoding="utf-8"))
            self.assertEqual(len(requests["requests"]), 1)
            self.assertEqual(requests["requests"][0]["action"], "enrich_contacts")
            self.assertIn("VP Demand Generation", requests["requests"][0]["role_hypotheses"])

    def test_identical_second_run_reuses_checkpoint_and_does_not_duplicate(self):
        with tempfile.TemporaryDirectory(dir=TEST_TMP) as folder:
            output = Path(folder)
            first = run_pipeline(FIXTURES, output, as_of=date(2026, 8, 31))
            first_payload = (output / "drafts.json").read_bytes()
            second = run_pipeline(FIXTURES, output, as_of=date(2026, 8, 31))
            self.assertFalse(first.reused)
            self.assertTrue(second.reused)
            self.assertEqual(second.draft_count, 1)
            self.assertEqual(first_payload, (output / "drafts.json").read_bytes())

    def test_receipts_record_input_hash_and_stage_counts(self):
        with tempfile.TemporaryDirectory(dir=TEST_TMP) as folder:
            output = Path(folder)
            run_pipeline(FIXTURES, output, as_of=date(2026, 8, 31))
            receipts = sorted((output / "receipts").glob("*.json"))
            self.assertEqual([path.stem for path in receipts], ["decisions", "drafts", "plays"])
            for path in receipts:
                receipt = json.loads(path.read_text(encoding="utf-8"))
                self.assertEqual(len(receipt["input_hash"]), 64)
                self.assertEqual(receipt["status"], "complete")
                self.assertEqual(receipt["run_id"], receipt["run_id"].strip())
                self.assertTrue(receipt["output_path"])

    def test_contacts_are_an_optional_second_pass_handoff(self):
        with tempfile.TemporaryDirectory(dir=TEST_TMP) as folder:
            root = Path(folder)
            inputs = root / "inputs"
            output = root / "output"
            inputs.mkdir()
            for name in ("candidates.jsonl", "signals.jsonl", "play-candidates.jsonl"):
                shutil.copy2(FIXTURES / name, inputs / name)
            result = run_pipeline(inputs, output, as_of=date(2026, 8, 31))
            self.assertEqual(result.strike_count, 1)
            self.assertEqual(result.draft_count, 0)
            requests = json.loads((output / "zoominfo-requests.json").read_text(encoding="utf-8"))
            self.assertEqual(len(requests["requests"]), 1)
            plays = [json.loads(line) for line in (output / "plays.jsonl").read_text(encoding="utf-8").splitlines()]
            self.assertEqual(len(plays), 1)
            self.assertTrue(all("no ZoomInfo result" in hold["reason"] for hold in plays[0]["holds"]))

    def test_cli_dry_run_uses_the_same_pipeline(self):
        with tempfile.TemporaryDirectory(dir=TEST_TMP) as folder:
            exit_code = main(
                [
                    "dry-run",
                    "--input",
                    str(FIXTURES),
                    "--output",
                    folder,
                    "--as-of",
                    "2026-08-31",
                ]
            )
            self.assertEqual(exit_code, 0)
            self.assertTrue((Path(folder) / "drafts.json").exists())


if __name__ == "__main__":
    unittest.main()
