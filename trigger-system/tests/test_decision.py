import unittest
from dataclasses import replace
from datetime import date

from agent.decision import decide
from agent.models import Account, Signal
from agent.signals import evaluate_signal, load_signal_policy


AS_OF = date(2026, 8, 31)


class DecisionTests(unittest.TestCase):
    def setUp(self):
        self.policy = load_signal_policy()
        self.account = Account(
            account_id="acme",
            name="Acme",
            domain="acme.example",
            hq_country="United States",
            fit_score=74,
        )
        self.leader = Signal(
            signal_id="leader-1",
            account_domain="acme.example",
            signal_type="new_marketing_leader",
            team="marketing",
            observed_date=date(2026, 7, 15),
            source_url="https://acme.example/leadership",
            source_key="acme-leadership",
            evidence_quote="Acme appointed a new chief marketing officer.",
        )
        self.hiring = Signal(
            signal_id="hiring-1",
            account_domain="acme.example",
            signal_type="hiring_surge",
            team="marketing",
            observed_date=date(2026, 8, 20),
            source_url="https://boards.greenhouse.io/acme",
            source_key="acme-ats",
            evidence_quote="Three marketing roles are currently open.",
            metadata={"open_role_count": 3},
        )

    def test_new_leader_window_includes_day_30_and_day_90(self):
        day_30 = replace(self.leader, observed_date=date(2026, 8, 1))
        day_90 = replace(self.leader, observed_date=date(2026, 6, 2))
        self.assertEqual(evaluate_signal(day_30, AS_OF, self.policy).window_state, "in_window")
        self.assertEqual(evaluate_signal(day_90, AS_OF, self.policy).window_state, "in_window")

    def test_new_leader_before_day_30_is_out_of_window(self):
        day_29 = replace(self.leader, observed_date=date(2026, 8, 2))
        self.assertEqual(
            evaluate_signal(day_29, AS_OF, self.policy).window_state,
            "out_of_window",
        )

    def test_hiring_surge_requires_three_open_roles(self):
        weak = replace(self.hiring, metadata={"open_role_count": 2})
        self.assertEqual(
            evaluate_signal(weak, AS_OF, self.policy).window_state,
            "manual_review",
        )

    def test_stale_role_requires_verified_repost_and_sixty_days_open(self):
        signal = replace(
            self.hiring,
            signal_type="stale_reposted_role",
            metadata={"days_open": 59, "repost_verified": True},
        )
        self.assertEqual(evaluate_signal(signal, AS_OF, self.policy).window_state, "manual_review")
        valid = replace(signal, metadata={"days_open": 60, "repost_verified": True})
        self.assertEqual(evaluate_signal(valid, AS_OF, self.policy).window_state, "in_window")

    def test_acquisition_integration_requires_a_closed_transaction(self):
        announced = replace(
            self.hiring,
            signal_type="acquisition_integration",
            metadata={"transaction_status": "announced"},
        )
        self.assertEqual(evaluate_signal(announced, AS_OF, self.policy).window_state, "manual_review")
        closed = replace(announced, metadata={"transaction_status": "closed"})
        self.assertEqual(evaluate_signal(closed, AS_OF, self.policy).window_state, "in_window")

    def test_two_independent_in_window_signals_strike(self):
        result = decide(self.account, [self.leader, self.hiring], AS_OF, self.policy)
        self.assertEqual(result.verdict, "STRIKE")
        self.assertGreater(result.heat_score, 0)
        self.assertEqual(result.independent_signal_count, 2)

    def test_duplicate_source_does_not_create_strike(self):
        duplicate_source = replace(self.hiring, source_key=self.leader.source_key)
        result = decide(self.account, [self.leader, duplicate_source], AS_OF, self.policy)
        self.assertNotEqual(result.verdict, "STRIKE")
        self.assertEqual(result.independent_signal_count, 1)

    def test_same_url_with_different_caller_keys_is_not_independent(self):
        same_publisher = replace(
            self.hiring,
            source_url=self.leader.source_url,
            source_key="a-different-caller-key",
        )
        result = decide(self.account, [self.leader, same_publisher], AS_OF, self.policy)
        self.assertNotEqual(result.verdict, "STRIKE")
        self.assertEqual(result.independent_signal_count, 1)

    def test_different_teams_do_not_form_a_strike(self):
        other_team = replace(self.hiring, team="sales")
        result = decide(self.account, [self.leader, other_team], AS_OF, self.policy)
        self.assertNotEqual(result.verdict, "STRIKE")

    def test_blank_team_does_not_form_a_strike(self):
        result = decide(
            self.account,
            [replace(self.leader, team=""), replace(self.hiring, team="")],
            AS_OF,
            self.policy,
        )
        self.assertNotEqual(result.verdict, "STRIKE")

    def test_signal_bound_to_another_company_does_not_form_a_strike(self):
        foreign = replace(self.hiring, account_domain="other.example")
        result = decide(self.account, [self.leader, foreign], AS_OF, self.policy)
        self.assertNotEqual(result.verdict, "STRIKE")

    def test_suppressed_account_is_never_scored_for_outreach(self):
        suppressed = replace(self.account, suppressed=True)
        result = decide(suppressed, [self.leader, self.hiring], AS_OF, self.policy)
        self.assertEqual(result.verdict, "SUPPRESSED")
        self.assertEqual(result.heat_score, 0)

    def test_suppression_happens_before_malformed_signal_evaluation(self):
        suppressed = replace(self.account, suppressed=True)
        malformed = replace(self.hiring, metadata={"open_role_count": "not-a-number"})
        result = decide(suppressed, [malformed], AS_OF, self.policy)
        self.assertEqual(result.verdict, "SUPPRESSED")
        self.assertEqual(result.evaluations, ())

    def test_low_fit_high_heat_strike_is_labelled_outlier(self):
        low_fit = replace(self.account, fit_score=20)
        result = decide(low_fit, [self.leader, self.hiring], AS_OF, self.policy)
        self.assertEqual(result.verdict, "STRIKE")
        self.assertTrue(result.low_fit_outlier)
        self.assertEqual(result.fit_score, 20)

    def test_market_scope_is_enforced_before_signal_evaluation(self):
        india = replace(self.account, hq_country="India")
        malformed = replace(self.hiring, metadata={"open_role_count": "not-a-number"})
        result = decide(india, [malformed], AS_OF, self.policy)
        self.assertEqual(result.verdict, "OUT_OF_MARKET")
        self.assertEqual(result.evaluations, ())

    def test_primary_team_case_does_not_break_play_evidence_binding(self):
        result = decide(
            self.account,
            [replace(self.leader, team=" Marketing "), replace(self.hiring, team="MARKETING")],
            AS_OF,
            self.policy,
        )
        self.assertEqual(result.verdict, "STRIKE")
        self.assertEqual(result.primary_team, "marketing")


if __name__ == "__main__":
    unittest.main()
