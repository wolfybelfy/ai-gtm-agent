"""Signal-window evaluation backed by an explicit JSON policy."""

from __future__ import annotations

import json
from datetime import date
from pathlib import Path
from typing import Any

from .models import Signal, SignalEvaluation


DEFAULT_POLICY = Path(__file__).resolve().parents[1] / "config" / "signal-policy.json"


def load_signal_policy(path: Path = DEFAULT_POLICY) -> dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def evaluate_signal(
    signal: Signal, as_of: date, policy: dict[str, Any]
) -> SignalEvaluation:
    rule = policy.get("signals", {}).get(signal.signal_type)
    if rule is None:
        return SignalEvaluation(
            signal=signal,
            tier="unknown",
            weight=0,
            age_days=(as_of - signal.observed_date).days,
            window_state="manual_review",
            reason="signal type is not configured",
            evidence_only=True,
        )
    age_days = (as_of - signal.observed_date).days
    evidence_only = bool(rule.get("evidence_only", False))
    if signal.confidence != "verified":
        state = "manual_review"
        reason = "signal is not verified"
    elif signal.signal_type == "hiring_surge":
        role_count = signal.metadata.get("open_role_count")
        if type(role_count) is not int:
            state = "manual_review"
            reason = "hiring count is not a verified integer"
        elif role_count < int(rule["minimum_open_roles"]):
            state = "manual_review"
            reason = "hiring count is below the configured surge threshold"
        elif int(rule["min_age_days"]) <= age_days <= int(rule["max_age_days"]):
            state = "in_window"
            reason = "signal date is inside the configured window"
        else:
            state = "out_of_window"
            reason = "signal date is outside the configured window"
    elif signal.signal_type == "stale_reposted_role" and (
        type(signal.metadata.get("days_open")) is not int
        or signal.metadata["days_open"] < int(rule["minimum_days_open"])
        or (bool(rule["requires_repost_verified"]) and signal.metadata.get("repost_verified") is not True)
    ):
        state = "manual_review"
        reason = "stale role requires 60 days open and a verified repost"
    elif signal.signal_type == "acquisition_integration" and str(
        signal.metadata.get("transaction_status", "")
    ).strip().lower() != str(rule["required_transaction_status"]).strip().lower():
        state = "manual_review"
        reason = "acquisition integration requires a closed transaction"
    elif int(rule["min_age_days"]) <= age_days <= int(rule["max_age_days"]):
        state = "in_window"
        reason = "signal date is inside the configured window"
    else:
        state = "out_of_window"
        reason = "signal date is outside the configured window"
    return SignalEvaluation(
        signal=signal,
        tier=str(rule["tier"]),
        weight=int(rule["weight"]),
        age_days=age_days,
        window_state=state,
        reason=reason,
        evidence_only=evidence_only,
    )
