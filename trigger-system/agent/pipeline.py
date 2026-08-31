"""Checkpointed local pipeline from normalized evidence to draft payloads."""

from __future__ import annotations

import csv
import hashlib
import json
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path
from typing import Any

from .claims import load_commercial_truth
from .decision import decide
from .domains import load_domains_from_csv, normalize_domain
from .models import Account, Signal
from .play import CandidateDraft, CommitteeMember, Contact, PlayCandidate, build_play
from .providers import draft_payload
from .signals import load_signal_policy


ROOT = Path(__file__).resolve().parents[1]
REQUIRED_INPUTS = (
    "candidates.jsonl",
    "signals.jsonl",
    "contacts.jsonl",
    "play-candidates.jsonl",
)


@dataclass(frozen=True)
class PipelineResult:
    run_id: str
    strike_count: int
    suppressed_count: int
    play_count: int
    draft_count: int
    hold_count: int
    output_dir: Path
    reused: bool


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    rows = []
    for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError as error:
            raise ValueError(f"Invalid JSON at {path}:{number}: {error.msg}") from error
    return rows


def _json_default(value: Any) -> Any:
    if isinstance(value, (date, Path)):
        return str(value)
    raise TypeError(f"Cannot serialize {type(value).__name__}")


def _atomic_json(path: Path, value: Any) -> None:
    _atomic_text(path, json.dumps(value, indent=2, default=_json_default) + "\n")


def _atomic_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(value, encoding="utf-8", newline="")
    temporary.replace(path)


def _input_hash(input_dir: Path, policy_paths: list[Path]) -> str:
    digest = hashlib.sha256()
    for path in [*(input_dir / name for name in REQUIRED_INPUTS), *policy_paths]:
        if not path.exists():
            raise FileNotFoundError(f"Required pipeline input is missing: {path}")
        digest.update(path.name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def _write_receipt(output_dir: Path, stage: str, input_hash: str, counts: dict[str, int]) -> None:
    _atomic_json(
        output_dir / "receipts" / f"{stage}.json",
        {"stage": stage, "status": "complete", "input_hash": input_hash, "counts": counts},
    )


def _candidate_from_dict(row: dict[str, Any]) -> PlayCandidate:
    return PlayCandidate(
        play_id=row["play_id"],
        account_domain=row["account_domain"],
        verdict=row["verdict"],
        signal_types=tuple(row["signal_types"]),
        pain_statement=row["pain_statement"],
        pain_grade=row["pain_grade"],
        capability_id=row["capability_id"],
        committee=tuple(
            CommitteeMember(
                contact_id=item["contact_id"],
                functional_labels=tuple(item.get("functional_labels", [])),
                reason=item["reason"],
                selected_for_outreach=bool(item["selected_for_outreach"]),
            )
            for item in row["committee"]
        ),
        drafts=tuple(
            CandidateDraft(
                contact_id=item["contact_id"],
                subject=item["subject"],
                body_template=item["body_template"],
                proof_id=item.get("proof_id"),
            )
            for item in row["drafts"]
        ),
    )


def _contact_from_dict(row: dict[str, Any]) -> Contact:
    return Contact(
        contact_id=row["contact_id"],
        full_name=row["full_name"],
        title=row["title"],
        company_domain=row["company_domain"],
        work_country=row["work_country"],
        current_employer_verified=bool(row["current_employer_verified"]),
        email=row.get("email", ""),
        email_verified=bool(row.get("email_verified", False)),
    )


def run_pipeline(input_dir: Path, output_dir: Path, as_of: date) -> PipelineResult:
    input_dir = Path(input_dir)
    output_dir = Path(output_dir)
    policy_path = ROOT / "config" / "signal-policy.json"
    truth_path = ROOT / "config" / "commercial-truth.json"
    suppression_path = ROOT / "config" / "suppression-baseline.csv"
    fingerprint = _input_hash(input_dir, [policy_path, truth_path, suppression_path])
    run_id = f"{as_of.isoformat()}-{fingerprint[:8]}"
    draft_receipt = output_dir / "receipts" / "drafts.json"
    if draft_receipt.exists() and (output_dir / "drafts.json").exists() and (output_dir / "digest.md").exists():
        receipt = json.loads(draft_receipt.read_text(encoding="utf-8"))
        if receipt.get("input_hash") == fingerprint and receipt.get("status") == "complete":
            decision_receipt = json.loads((output_dir / "receipts" / "decisions.json").read_text(encoding="utf-8"))
            play_receipt = json.loads((output_dir / "receipts" / "plays.json").read_text(encoding="utf-8"))
            return PipelineResult(
                run_id,
                decision_receipt["counts"]["strikes"],
                decision_receipt["counts"]["suppressed"],
                play_receipt["counts"]["plays"],
                receipt["counts"]["drafts"],
                play_receipt["counts"]["holds"],
                output_dir,
                True,
            )

    suppression = load_domains_from_csv(suppression_path)
    policy = load_signal_policy(policy_path)
    truth = load_commercial_truth(truth_path)
    signal_rows = _read_jsonl(input_dir / "signals.jsonl")
    signals_by_account: dict[str, list[Signal]] = {}
    for row in signal_rows:
        signals_by_account.setdefault(row["account_id"], []).append(
            Signal(
                signal_id=row["signal_id"],
                signal_type=row["signal_type"],
                team=row["team"],
                observed_date=date.fromisoformat(row["observed_date"]),
                source_url=row["source_url"],
                source_key=row["source_key"],
                evidence_quote=row["evidence_quote"],
                confidence=row.get("confidence", "verified"),
                metadata=row.get("metadata", {}),
            )
        )

    decisions = []
    for row in _read_jsonl(input_dir / "candidates.jsonl"):
        domain = normalize_domain(row["domain"])
        account = Account(
            account_id=row["account_id"],
            name=row["name"],
            domain=domain,
            hq_country=row["hq_country"],
            fit_score=int(row["fit_score"]),
            suppressed=domain in suppression,
            attributes=row.get("attributes", {}),
        )
        decisions.append(decide(account, signals_by_account.get(account.account_id, []), as_of, policy))

    decision_lines = "".join(json.dumps(asdict(item), default=_json_default) + "\n" for item in decisions)
    _atomic_text(output_dir / "decisions.jsonl", decision_lines)
    strike_count = sum(item.verdict == "STRIKE" for item in decisions)
    suppressed_count = sum(item.verdict == "SUPPRESSED" for item in decisions)
    _write_receipt(output_dir, "decisions", fingerprint, {"strikes": strike_count, "suppressed": suppressed_count})

    candidate_by_domain = {
        normalize_domain(row["account_domain"]): _candidate_from_dict(row)
        for row in _read_jsonl(input_dir / "play-candidates.jsonl")
    }
    contact_rows = _read_jsonl(input_dir / "contacts.jsonl")
    contacts_by_domain: dict[str, list[Contact]] = {}
    for row in contact_rows:
        contacts_by_domain.setdefault(normalize_domain(row["account_domain"]), []).append(_contact_from_dict(row))

    plays = []
    missing_candidates = []
    for decision in decisions:
        if decision.verdict != "STRIKE":
            continue
        domain = normalize_domain(decision.account.domain)
        candidate = candidate_by_domain.get(domain)
        if candidate is None:
            missing_candidates.append(domain)
            continue
        plays.append(build_play(candidate, contacts_by_domain.get(domain, []), truth, as_of))

    play_lines = "".join(json.dumps(asdict(item), default=_json_default) + "\n" for item in plays)
    _atomic_text(output_dir / "plays.jsonl", play_lines)
    hold_count = sum(len(play.holds) for play in plays) + len(missing_candidates)
    _write_receipt(output_dir, "plays", fingerprint, {"plays": len(plays), "holds": hold_count})

    combined_drafts = []
    for play in plays:
        combined_drafts.extend(draft_payload(play, run_id)["drafts"])
    combined_payload = {"action": "save_draft", "run_id": run_id, "drafts": combined_drafts}
    _atomic_json(output_dir / "drafts.json", combined_payload)

    digest = [
        f"# Monday STRIKE Digest - {as_of.isoformat()}",
        "",
        f"- STRIKE accounts: {strike_count}",
        f"- Suppressed accounts: {suppressed_count}",
        f"- Validated plays: {len(plays)}",
        f"- Outlook draft payloads: {len(combined_drafts)}",
        f"- Holds: {hold_count}",
        "",
    ]
    for play in plays:
        digest.extend(
            [
                f"## {play.account_domain}",
                f"- Pain grade: {play.pain_grade}",
                f"- Capability: {play.capability_id}",
                f"- Drafts: {len(play.drafts)}",
                f"- Holds: {len(play.holds)}",
                "",
            ]
        )
    for domain in missing_candidates:
        digest.append(f"- HOLD {domain}: STRIKE has no AI-authored play candidate")
    _atomic_text(output_dir / "digest.md", "\n".join(digest).rstrip() + "\n")
    _write_receipt(output_dir, "drafts", fingerprint, {"drafts": len(combined_drafts)})
    return PipelineResult(run_id, strike_count, suppressed_count, len(plays), len(combined_drafts), hold_count, output_dir, False)
