"""Validate AI-authored play candidates before provider payload generation."""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date
from typing import Any, Iterable

from .claims import blocked_phrases, eligible_proof
from .domains import normalize_domain
from .models import Decision


US_COUNTRIES = {"united states", "united states of america", "us", "usa", "u.s.", "u.s.a."}
VALID_PAIN_GRADES = {"observed", "corpus_supported_hypothesis", "unknown"}
SUBJECT_PATTERN = re.compile(r"^[a-z0-9]+(?: [a-z0-9]+){0,2}$")
MEETING_PATTERNS = ("book a meeting", "schedule a call", "15 minutes", "meet next week")
SURVEILLANCE_PATTERNS = ("i saw you", "i noticed you", "been tracking", "been monitoring")
EVIDENCE_LABELS = {
    "new_marketing_leader": "marketing leadership change",
    "hiring_surge": "marketing hiring activity",
    "stale_reposted_role": "a persistently open marketing role",
    "acquisition_integration": "post-acquisition integration",
    "jd_vendor_language": "specialist vendor language in current hiring",
    "past_champion_landed": "a past champion joining the team",
    "closed_lost_cluster": "renewed activity around a prior evaluation",
    "conference": "an upcoming conference program",
    "product_launch": "a recent product launch",
    "regional_expansion": "regional expansion",
    "analyst_placement": "recent analyst recognition",
    "rebrand": "a recent rebrand",
    "funding": "a recent funding event",
}


class PolicyError(ValueError):
    """Raised when a candidate violates a non-negotiable policy."""


@dataclass(frozen=True)
class Contact:
    contact_id: str
    full_name: str
    title: str
    company_domain: str
    work_country: str
    current_employer_verified: bool
    email: str
    email_verified: bool
    role_relevance_verified: bool


@dataclass(frozen=True)
class CommitteeMember:
    contact_id: str
    functional_labels: tuple[str, ...]
    reason: str
    role_hypothesis: str
    selected_for_outreach: bool


@dataclass(frozen=True)
class CandidateDraft:
    contact_id: str
    subject: str
    template_id: str
    proof_id: str | None = None


@dataclass(frozen=True)
class PlayCandidate:
    play_id: str
    account_domain: str
    verdict: str
    signal_types: tuple[str, ...]
    evidence_signal_ids: tuple[str, ...]
    pain_statement: str
    pain_grade: str
    capability_id: str
    committee: tuple[CommitteeMember, ...]
    drafts: tuple[CandidateDraft, ...]


@dataclass(frozen=True)
class ValidatedDraft:
    contact_id: str
    recipient: str
    subject: str
    body: str
    proof_id: str | None


@dataclass(frozen=True)
class Hold:
    contact_id: str
    reason: str


@dataclass(frozen=True)
class ValidatedPlay:
    play_id: str
    account_domain: str
    committee: tuple[CommitteeMember, ...]
    drafts: tuple[ValidatedDraft, ...]
    holds: tuple[Hold, ...]
    omitted_claims: tuple[str, ...]
    pain_grade: str
    capability_id: str


def _validate_subject(subject: str) -> None:
    if not SUBJECT_PATTERN.fullmatch(subject.strip()):
        raise PolicyError("subject must be 1-3 lowercase words without punctuation")


def _validate_body(body: str, truth: dict[str, Any]) -> str:
    normalized = " ".join(body.split())
    lowered = normalized.lower()
    if "—" in normalized:
        raise PolicyError("email body contains an em dash")
    for phrase in blocked_phrases(truth) + MEETING_PATTERNS + SURVEILLANCE_PATTERNS:
        if phrase in lowered:
            raise PolicyError(f"email body contains blocked phrase: {phrase}")
    words = re.findall(r"\b[\w'-]+\b", normalized)
    if not 50 <= len(words) <= 100:
        raise PolicyError(f"email body must remain concise; found {len(words)} words")
    return normalized


def _evidence_sentence(evidence: tuple[Any, ...]) -> str:
    labels = list(
        dict.fromkeys(
            EVIDENCE_LABELS.get(item.signal_type, item.signal_type.replace("_", " "))
            for item in evidence
        )
    )
    if len(labels) == 1:
        context = labels[0]
    else:
        context = ", ".join(labels[:-1]) + f" and {labels[-1]}"
    return f"Recent {context} suggests the affected team is navigating change."


def _contact_hold(contact: Contact, account_domain: str) -> str | None:
    if not contact.current_employer_verified:
        return "current employment is not verified"
    if normalize_domain(contact.company_domain) != normalize_domain(account_domain):
        return "verified employer domain does not match the STRIKE account"
    if contact.work_country.strip().lower() not in US_COUNTRIES:
        return "contact is not verified as US-based"
    if not contact.email_verified or not contact.email.strip():
        return "verified work email is unavailable"
    email_domain = normalize_domain(contact.email.rsplit("@", 1)[-1]) if "@" in contact.email else ""
    if email_domain != normalize_domain(account_domain):
        return "verified work email domain does not match the STRIKE account"
    if not contact.role_relevance_verified:
        return "contact role relevance is not verified"
    return None


def build_play(
    candidate: PlayCandidate,
    contacts: Iterable[Contact],
    truth: dict[str, Any],
    as_of: date,
    decision: Decision,
) -> ValidatedPlay:
    if candidate.verdict != "STRIKE" or decision.verdict != "STRIKE":
        raise PolicyError("only STRIKE candidates can produce a play")
    if normalize_domain(candidate.account_domain) != normalize_domain(decision.account.domain):
        raise PolicyError("play account does not match the STRIKE decision")
    evidence = tuple(
        item.signal
        for item in decision.evaluations
        if item.window_state == "in_window"
        and not item.evidence_only
        and item.signal.confidence == "verified"
        and item.signal.team.strip().lower() == decision.primary_team
        and normalize_domain(item.signal.account_domain) == normalize_domain(decision.account.domain)
    )
    if set(candidate.evidence_signal_ids) != {item.signal_id for item in evidence}:
        raise PolicyError("play evidence does not match the STRIKE decision")
    if set(candidate.signal_types) != {item.signal_type for item in evidence}:
        raise PolicyError("play signal types do not match the STRIKE decision")
    if candidate.pain_grade not in VALID_PAIN_GRADES:
        raise PolicyError(f"invalid pain grade: {candidate.pain_grade}")
    capabilities = {item.get("id"): item for item in truth.get("capabilities", [])}
    capability = capabilities.get(candidate.capability_id)
    if capability is None:
        raise PolicyError(f"unknown capability: {candidate.capability_id}")
    templates = {item.get("id"): item for item in truth.get("email_templates", [])}

    contacts_by_id = {contact.contact_id: contact for contact in contacts}
    drafts_by_id: dict[str, CandidateDraft] = {}
    for draft in candidate.drafts:
        if draft.contact_id in drafts_by_id:
            raise PolicyError(f"duplicate candidate draft for {draft.contact_id}")
        drafts_by_id[draft.contact_id] = draft

    validated: list[ValidatedDraft] = []
    holds: list[Hold] = []
    omitted: set[str] = set()
    for member in candidate.committee:
        if not member.selected_for_outreach:
            continue
        if candidate.pain_grade == "unknown":
            holds.append(Hold(member.contact_id, "pain grade is unknown"))
            continue
        contact = contacts_by_id.get(member.contact_id)
        if contact is None:
            holds.append(Hold(member.contact_id, "selected contact has no ZoomInfo result"))
            continue
        reason = _contact_hold(contact, candidate.account_domain)
        if reason:
            holds.append(Hold(member.contact_id, reason))
            continue
        draft = drafts_by_id.get(member.contact_id)
        if draft is None:
            holds.append(Hold(member.contact_id, "selected contact has no candidate email"))
            continue
        _validate_subject(draft.subject)
        template = templates.get(draft.template_id)
        if template is None:
            raise PolicyError(f"unknown email template: {draft.template_id}")
        if not set(template.get("signal_types", [])) & {item.signal_type for item in evidence}:
            raise PolicyError("email template does not match the STRIKE evidence")
        proof = eligible_proof(truth, draft.proof_id, tuple(item.signal_type for item in evidence), as_of)
        proof_text = ""
        accepted_proof_id = None
        if draft.proof_id:
            if proof is None:
                omitted.add(draft.proof_id)
            else:
                proof_text = str(proof["claim"])
                accepted_proof_id = str(proof["id"])
        body = " ".join(
            part
            for part in (
                _evidence_sentence(evidence),
                str(template["implication"]),
                proof_text,
                str(capability["email_line"]),
                str(template["question"]),
            )
            if part
        )
        body = _validate_body(body, truth)
        validated.append(
            ValidatedDraft(
                contact_id=contact.contact_id,
                recipient=contact.email.strip(),
                subject=draft.subject.strip(),
                body=body,
                proof_id=accepted_proof_id,
            )
        )

    return ValidatedPlay(
        play_id=candidate.play_id,
        account_domain=normalize_domain(candidate.account_domain),
        committee=candidate.committee,
        drafts=tuple(validated),
        holds=tuple(holds),
        omitted_claims=tuple(sorted(omitted)),
        pain_grade=candidate.pain_grade,
        capability_id=candidate.capability_id,
    )
