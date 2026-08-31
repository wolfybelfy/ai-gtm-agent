"""Command-line entry points for deterministic AI GTM Agent stages."""

from __future__ import annotations

import argparse
from datetime import date
from pathlib import Path

from .domains import load_domains_from_csv, load_domains_from_text, write_suppression_csv
from .pipeline import run_pipeline


ROOT = Path(__file__).resolve().parents[1]


def prepare_suppression(tal_path: Path, extra_path: Path, output_path: Path) -> int:
    domains = load_domains_from_csv(Path(tal_path))
    domains.update(load_domains_from_text(Path(extra_path)))
    return write_suppression_csv(Path(output_path), domains)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ai-gtm")
    commands = parser.add_subparsers(dest="command", required=True)
    prepare = commands.add_parser("prepare-suppression")
    prepare.add_argument("--tal", type=Path, required=True)
    prepare.add_argument(
        "--extra", type=Path, default=ROOT / "config" / "suppression-extra.txt"
    )
    prepare.add_argument(
        "--output", type=Path, default=ROOT / "config" / "suppression-baseline.csv"
    )
    dry_run = commands.add_parser("dry-run")
    dry_run.add_argument("--input", type=Path, required=True)
    dry_run.add_argument("--output", type=Path, required=True)
    dry_run.add_argument("--as-of", type=date.fromisoformat, default=date.today())
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "prepare-suppression":
        count = prepare_suppression(args.tal, args.extra, args.output)
        print(f"{count} suppression domains written to {args.output}")
        return 0
    if args.command == "dry-run":
        result = run_pipeline(args.input, args.output, args.as_of)
        state = "reused" if result.reused else "built"
        print(
            f"{state} run {result.run_id}: {result.strike_count} STRIKE, "
            f"{result.draft_count} draft payload(s), {result.hold_count} hold(s)"
        )
        return 0
    raise AssertionError(f"Unhandled command: {args.command}")



if __name__ == "__main__":
    raise SystemExit(main())
