import csv
import tempfile
import unittest
from pathlib import Path

from agent.domains import (
    load_domains_from_csv,
    normalize_domain,
    suppression_set,
    write_suppression_csv,
)
from agent.cli import prepare_suppression


TEST_TMP = Path(__file__).parent / ".tmp"
TEST_TMP.mkdir(exist_ok=True)


class DomainTests(unittest.TestCase):
    def test_normalizes_urls_and_www(self):
        self.assertEqual(
            normalize_domain("HTTPS://www.Example.com/path?q=1"), "example.com"
        )

    def test_rejects_values_without_a_valid_hostname(self):
        self.assertEqual(normalize_domain("not a company"), "")
        self.assertEqual(normalize_domain(""), "")

    def test_suppression_is_unique(self):
        self.assertEqual(
            suppression_set(["www.a.com", "https://a.com", "b.com"]),
            {"a.com", "b.com"},
        )

    def test_detects_domain_column_without_assuming_its_position(self):
        with tempfile.TemporaryDirectory(dir=TEST_TMP) as folder:
            source = Path(folder) / "tal.csv"
            with source.open("w", newline="", encoding="utf-8") as handle:
                writer = csv.DictWriter(handle, fieldnames=["Account", "Website"])
                writer.writeheader()
                writer.writerow({"Account": "A", "Website": "https://www.a.com/"})
                writer.writerow({"Account": "B", "Website": "b.com"})

            self.assertEqual(load_domains_from_csv(source), {"a.com", "b.com"})

    def test_writes_sorted_unique_baseline(self):
        with tempfile.TemporaryDirectory(dir=TEST_TMP) as folder:
            target = Path(folder) / "suppression.csv"
            count = write_suppression_csv(target, ["b.com", "www.a.com", "a.com"])
            self.assertEqual(count, 2)
            self.assertEqual(
                target.read_text(encoding="utf-8").splitlines(),
                ["domain", "a.com", "b.com"],
            )

    def test_prepare_suppression_merges_tal_and_extra_domains(self):
        with tempfile.TemporaryDirectory(dir=TEST_TMP) as folder:
            root = Path(folder)
            tal = root / "tal.csv"
            tal.write_text("Domain\na.com\nwww.b.com\n", encoding="utf-8")
            extra = root / "extra.txt"
            extra.write_text("b.com\nc.com\n", encoding="utf-8")
            output = root / "baseline.csv"

            count = prepare_suppression(tal, extra, output)

            self.assertEqual(count, 3)
            self.assertEqual(
                output.read_text(encoding="utf-8").splitlines(),
                ["domain", "a.com", "b.com", "c.com"],
            )


if __name__ == "__main__":
    unittest.main()
