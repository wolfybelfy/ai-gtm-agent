import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
TRIGGER = REPO / "trigger-system"


class ShippingContractTests(unittest.TestCase):
    def test_excluded_integration_scripts_are_absent(self):
        excluded = [
            "alert-mailer.ps1",
            "alert-teams.ps1",
            "hubspot-export-deals.ps1",
            "hubspot-setup.ps1",
            "hubspot-write-play.ps1",
            "onedrive-share-link.ps1",
            "onedrive-signin.ps1",
            "extract-sdr-sheet.ps1",
            "extract-sdr-signals.ps1",
            "smoke-outlook-com.ps1",
        ]
        for name in excluded:
            self.assertFalse((TRIGGER / "scripts" / name).exists(), name)

    def test_active_scripts_contain_no_send_method(self):
        active = [
            TRIGGER / "scripts" / "ai-gtm.ps1",
            TRIGGER / "scripts" / "publish-outlook-drafts.ps1",
            TRIGGER / "scripts" / "zoominfo-enrich.ps1",
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
            ["ZOOMINFO_CLIENT_ID=", "ZOOMINFO_CLIENT_SECRET="],
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
        ]:
            self.assertIn(marker, text)


if __name__ == "__main__":
    unittest.main()
