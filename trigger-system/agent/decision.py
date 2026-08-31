"""Suppression-first STRIKE verdict policy."""

from __future__ import annotations

from collections import defaultdict
from datetime import date
from typing import Any, Iterable

from .models import Account, Decision, Signal
from .signals import evaluate_signal


def decide(
    account: Account,
    signals: Iterable[Signal],
    as_of: date,
    policy: dict[str, Any],
) -> Decision:
    evaluations = tuple(evaluate_signal(signal, as_of, policy) for signal in signals)
    if account.suppressed:
        return Decision(
            account=account,
            verdict="SUPPRESSED",
            fit_score=account.fit_score,
            heat_score=0,
            independent_signal_count=0,
            primary_team=None,
            low_fit_outlier=False,
            evaluations=evaluations,
            reason="account domain is on the suppression baseline",
        )

    eligible = [
        item
        for item in evaluations
        if item.window_state == "in_window" and not item.evidence_only and item.weight > 0
    ]
    teams: dict[str, dict[str, list]] = defaultdict(lambda: defaultdict(list))
    for item in eligible:
        teams[item.signal.team.strip().lower()][item.signal.source_key].append(item)

    primary_team = None
    independent_count = 0
    for team, by_source in teams.items():
        count = len(by_source)
        if count > independent_count:
            primary_team = team
            independent_count = count

    best_weight_by_source: dict[str, int] = {}
    for item in eligible:
        current = best_weight_by_source.get(item.signal.source_key, 0)
        best_weight_by_source[item.signal.source_key] = max(current, item.weight)
    heat_score = sum(best_weight_by_source.values())

    strike_min = int(policy.get("strike_min_independent_signals", 2))
    if independent_count >= strike_min:
        verdict = "STRIKE"
        reason = f"{independent_count} independent in-window signals affect {primary_team}"
    elif any(item.tier == "A" for item in eligible):
        verdict = "SEQUENCE"
        reason = "one verified Tier A signal; more corroboration is required for STRIKE"
    else:
        verdict = "WATCH"
        reason = "STRIKE evidence gate is not met"

    outlier_threshold = int(policy.get("low_fit_outlier_below", 45))
    return Decision(
        account=account,
        verdict=verdict,
        fit_score=account.fit_score,
        heat_score=heat_score,
        independent_signal_count=independent_count,
        primary_team=primary_team,
        low_fit_outlier=verdict == "STRIKE" and account.fit_score < outlier_threshold,
        evaluations=evaluations,
        reason=reason,
    )

