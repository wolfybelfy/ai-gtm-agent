"""Side-effect-free provider payload builders."""

from __future__ import annotations

import hashlib
from typing import Iterable

from .domains import normalize_domain, suppression_set
from .models import Decision
from .play import PolicyError, ValidatedPlay


def zoominfo_request(
    decision: Decision,
    role_hypotheses: Iterable[str],
    suppressed_domains: Iterable[str],
    max_credits: int = 25,
) -> dict:
    """Build, but do not execute, a paid enrichment request."""
    domain = normalize_domain(decision.account.domain)
    if decision.verdict != "STRIKE":
        raise PolicyError("ZoomInfo is allowed only after a STRIKE verdict")
    if decision.account.suppressed or domain in suppression_set(suppressed_domains):
        raise PolicyError("suppressed accounts cannot reach ZoomInfo")
    roles = list(dict.fromkeys(role.strip() for role in role_hypotheses if role.strip()))
    if not roles:
        raise PolicyError("ZoomInfo request requires AI-selected role hypotheses")
    if max_credits < 1:
        raise PolicyError("ZoomInfo credit cap must be positive")
    return {
        "action": "enrich_contacts",
        "account_id": decision.account.account_id,
        "account_domain": domain,
        "role_hypotheses": roles,
        "max_credits": max_credits,
        "verdict": decision.verdict,
    }


def draft_payload(play: ValidatedPlay, run_id: str) -> dict:
    """Build an Outlook draft-only payload with stable idempotency keys."""
    drafts = []
    for draft in play.drafts:
        material = "|".join(
            [run_id, play.play_id, play.account_domain, draft.contact_id, draft.subject, draft.body]
        )
        key = hashlib.sha256(material.encode("utf-8")).hexdigest()
        drafts.append(
            {
                "action": "save_draft",
                "contact_id": draft.contact_id,
                "to": draft.recipient,
                "subject": draft.subject,
                "body": draft.body,
                "proof_id": draft.proof_id,
                "idempotency_key": key,
            }
        )
    return {
        "action": "save_draft",
        "run_id": run_id,
        "play_id": play.play_id,
        "account_domain": play.account_domain,
        "drafts": drafts,
    }
