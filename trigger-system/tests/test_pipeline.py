import json
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
