"""Immutable records shared by the deterministic policy modules."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from typing import Any


@dataclass(frozen=True)
class Account:
    account_id: str
    name: str
    domain: str
    hq_country: str
    fit_score: int
    suppressed: bool = False
    attributes: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class Signal:
    signal_id: str
    account_domain: str
    signal_type: str
    team: str
    observed_date: date
    source_url: str
    source_key: str
    evidence_quote: str
    confidence: str = "verified"
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class SignalEvaluation:
    signal: Signal
    tier: str
    weight: int
    age_days: int
    window_state: str
    reason: str
    evidence_only: bool = False


@dataclass(frozen=True)
class Decision:
    account: Account
    verdict: str
    fit_score: int
    heat_score: int
    independent_signal_count: int
    primary_team: str | None
    low_fit_outlier: bool
    evaluations: tuple[SignalEvaluation, ...]
    reason: str
