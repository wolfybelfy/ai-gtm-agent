"""Canonical commercial-truth loading and proof eligibility."""

from __future__ import annotations

import json
from datetime import date
from pathlib import Path
from typing import Any, Iterable


DEFAULT_TRUTH = Path(__file__).resolve().parents[1] / "config" / "commercial-truth.json"


def load_commercial_truth(path: Path = DEFAULT_TRUTH) -> dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def eligible_proof(
    truth: dict[str, Any],
    proof_id: str | None,
    use_cases: Iterable[str],
    as_of: date,
) -> dict[str, Any] | None:
    if not proof_id:
        return None
    proof = next(
        (item for item in truth.get("proof_points", []) if item.get("id") == proof_id),
        None,
    )
    if not proof or proof.get("status") != "approved" or not proof.get("source"):
        return None
    try:
        review_after = date.fromisoformat(str(proof["review_after"]))
    except (KeyError, TypeError, ValueError):
        return None
    if review_after < as_of:
        return None
    requested = {item.strip().lower() for item in use_cases}
    approved = {str(item).strip().lower() for item in proof.get("use_cases", [])}
    if not requested.intersection(approved):
        return None
    return proof


def blocked_phrases(truth: dict[str, Any]) -> tuple[str, ...]:
    values = list(truth.get("blocked_phrases", []))
    values.extend(truth.get("terminology", {}).get("blocked", []))
    return tuple(str(value).strip().lower() for value in values if str(value).strip())

