import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
TRIGGER = REPO / "trigger-system"


class ShippingContractTests(unittest.TestCase):
    def test_active_script_directory_is_an_explicit_allowlist(self):
        names = {path.name for path in (TRIGGER / "scripts").iterdir() if path.is_file()}
        self.assertEqual(
            names,
            {".gitkeep", "ai-gtm.ps1", "publish-outlook-drafts.ps1", "verify-v1.ps1"},
        )

    def test_active_scripts_contain_no_send_method(self):
        active = [
            TRIGGER / "scripts" / "ai-gtm.ps1",
            TRIGGER / "scripts" / "publish-outlook-drafts.ps1",
        ]
        for path in active:
            self.assertNotIn(".Send(", path.read_text(encoding="utf-8"), path.name)

    def test_environment_example_is_an_allowlist(self):
        lines = [
            line.strip()
            for line in (REPO / ".env.example").read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.startswith("#")
        ]
        self.assertEqual(
            lines,
            ["AI_GTM_OPERATOR_EMAIL=", "ZOOMINFO_CLIENT_ID=", "ZOOMINFO_CLIENT_SECRET="],
        )

    def test_verification_script_checks_core_shipping_rails(self):
        text = (TRIGGER / "scripts" / "verify-v1.ps1").read_text(encoding="utf-8")
        for marker in [
            "unittest discover",
            "648",
            ".Send(",
            "suppression-baseline.csv",
            "ICP Converstion Intelligence",
            "reused run",
            "Get-FileHash",
            "AllowedVolatilePrefixes",
            "ls-files",
        ]:
            self.assertIn(marker, text)

    def test_docs_do_not_claim_a_live_zoominfo_connection(self):
        setup = (TRIGGER / "runbooks" / "setup.md").read_text(encoding="utf-8")
        monday = (TRIGGER / "runbooks" / "monday-run.md").read_text(encoding="utf-8")
        self.assertNotIn("zoominfo-enrich.ps1", (setup + monday).lower())
        self.assertIn("not enabled", (setup + monday).lower())


if __name__ == "__main__":
    unittest.main()
