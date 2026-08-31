"""Suppression-first STRIKE verdict policy."""

from __future__ import annotations

from collections import defaultdict
from datetime import date
from typing import Any, Iterable
from urllib.parse import urlsplit

from .domains import normalize_domain
from .models import Account, Decision, Signal
from .signals import evaluate_signal


MULTI_LABEL_SUFFIXES = {"co.uk", "com.au", "co.in", "co.jp", "com.br", "com.mx"}


def _publisher_identity(source_url: str) -> str:
    try:
        host = normalize_domain(urlsplit(source_url).hostname or "")
    except ValueError:
        return ""
    if not host:
        return ""
    labels = host.split(".")
    if len(labels) <= 2:
        return host
    suffix = ".".join(labels[-2:])
    return ".".join(labels[-3:]) if suffix in MULTI_LABEL_SUFFIXES else suffix


def decide(
    account: Account,
    signals: Iterable[Signal],
    as_of: date,
    policy: dict[str, Any],
) -> Decision:
    if account.suppressed:
        return Decision(
            account=account,
            verdict="SUPPRESSED",
            fit_score=account.fit_score,
            heat_score=0,
            independent_signal_count=0,
            primary_team=None,
            low_fit_outlier=False,
            evaluations=(),
            reason="account domain is on the suppression baseline",
        )

    evaluations = tuple(evaluate_signal(signal, as_of, policy) for signal in signals)
    account_domain = normalize_domain(account.domain)

    eligible = [
        item
        for item in evaluations
        if item.window_state == "in_window"
        and not item.evidence_only
        and item.weight > 0
        and normalize_domain(item.signal.account_domain) == account_domain
        and bool(item.signal.team.strip())
        and bool(item.signal.source_key.strip())
        and bool(_publisher_identity(item.signal.source_url))
    ]
    teams: dict[str, list] = defaultdict(list)
    for item in eligible:
        teams[item.signal.team.strip().lower()].append(item)

    primary_team = None
    independent_count = 0
    for team, team_signals in teams.items():
        publishers = {_publisher_identity(item.signal.source_url) for item in team_signals}
        source_keys = {item.signal.source_key.strip().lower() for item in team_signals}
        count = min(len(publishers), len(source_keys))
        if count > independent_count:
            primary_team = team
            independent_count = count

    best_weight_by_publisher: dict[str, int] = {}
    best_weight_by_key: dict[str, int] = {}
    for item in eligible:
        publisher = _publisher_identity(item.signal.source_url)
        source_key = item.signal.source_key.strip().lower()
        best_weight_by_publisher[publisher] = max(best_weight_by_publisher.get(publisher, 0), item.weight)
        best_weight_by_key[source_key] = max(best_weight_by_key.get(source_key, 0), item.weight)
    heat_score = min(sum(best_weight_by_publisher.values()), sum(best_weight_by_key.values()))

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
