"""Validate account maps, generate readable briefs, and roll up the cross-account graph.

The verified-only rule (user directive 2026-07-29) is enforced HERE, mechanically:
a node without source_url + fetched + verification + confidence is a hard failure, not a warning.
That is what stops an unsourced ServiceNow-style box from ever entering a map.

Usage:
    python scripts/account-map.py validate            # all accounts, exit 1 on any violation
    python scripts/account-map.py brief               # regenerate every account.md
    python scripts/account-map.py rollup              # rebuild data/graph/{nodes,edges}.csv
    python scripts/account-map.py all                 # all three
"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ACCOUNTS_DIR = REPO / "data" / "accounts"
GRAPH_DIR = REPO / "data" / "graph"

REQUIRED_NODE_FIELDS = ("id", "type", "label", "source_url", "fetched", "verification", "confidence")
VALID_VERIFICATION = {"live_fetch", "captured_snapshot", "internal_research"}
VALID_CONFIDENCE = {"HIGH", "MED", "MED-HIGH", "LOW"}
VALID_NODE_TYPES = {
    "company", "business_unit", "team", "person", "product", "acquisition",
    "geography", "segment", "tech_stack", "event", "signal", "commercial", "partner",
}


def load_maps() -> list[tuple[Path, dict]]:
    out = []
    if not ACCOUNTS_DIR.exists():
        return out
    for p in sorted(ACCOUNTS_DIR.glob("*/account.json")):
        out.append((p, json.loads(p.read_text(encoding="utf-8-sig"))))
    return out


def validate(path: Path, m: dict) -> list[str]:
    errs: list[str] = []
    aid = m.get("account_id", "?")
    if m.get("evidence_rule") != "verified_only":
        errs.append(f"{aid}: evidence_rule must be 'verified_only'")

    seen: set[str] = set()
    for n in m.get("nodes", []):
        nid = n.get("id", "<no id>")
        for f in REQUIRED_NODE_FIELDS:
            if not str(n.get(f, "")).strip():
                errs.append(f"{aid}/{nid}: missing required field '{f}' (verified-only rule)")
        if nid in seen:
            errs.append(f"{aid}/{nid}: duplicate node id")
        seen.add(nid)
        if n.get("type") not in VALID_NODE_TYPES:
            errs.append(f"{aid}/{nid}: unknown node type '{n.get('type')}'")
        if n.get("verification") not in VALID_VERIFICATION:
            errs.append(f"{aid}/{nid}: verification must be one of {sorted(VALID_VERIFICATION)}")
        if n.get("confidence") not in VALID_CONFIDENCE:
            errs.append(f"{aid}/{nid}: confidence must be one of {sorted(VALID_CONFIDENCE)}")

    for e in m.get("edges", []):
        for side in ("from", "to"):
            if e.get(side) not in seen:
                errs.append(f"{aid}: edge {e.get('from')} -{e.get('rel')}-> {e.get('to')} references unknown node '{e.get(side)}'")
        if not str(e.get("rel", "")).strip():
            errs.append(f"{aid}: edge {e.get('from')} -> {e.get('to')} has no relationship label")

    # a map that claims nothing is missing is almost certainly lying
    if "not_collected" not in m:
        errs.append(f"{aid}: missing 'not_collected' list - every map must state what it does NOT have")
    return errs


def brief(path: Path, m: dict) -> Path:
    aid = m["account_id"]
    nodes = m.get("nodes", [])
    by_type: dict[str, list[dict]] = {}
    for n in nodes:
        by_type.setdefault(n["type"], []).append(n)
    by_id = {n["id"]: n for n in nodes}

    L: list[str] = []
    company = (by_type.get("company") or [{}])[0]
    L.append(f"# {company.get('label', aid)} - account map")
    L.append("")
    L.append(f"_Built {m.get('map_built')} under the verified-only rule: every line below carries a source. "
             f"{len(nodes)} nodes, {len(m.get('edges', []))} relationships._")
    L.append("")

    ORDER = [
        ("company", "Identity"), ("business_unit", "Business units"), ("team", "Teams (marketing mapped deep)"),
        ("person", "Named people"), ("product", "Products"), ("acquisition", "Acquisitions"),
        ("geography", "Geography"), ("segment", "Segments served"), ("tech_stack", "Martech stack observed"),
        ("event", "Events"), ("signal", "Live signals"), ("partner", "Partners"), ("commercial", "Commercial state"),
    ]
    for tname, heading in ORDER:
        rows = by_type.get(tname, [])
        if not rows:
            continue
        L.append(f"## {heading}")
        L.append("")
        for n in rows:
            attrs = n.get("attrs") or {}
            detail = "; ".join(f"{k}: {v}" for k, v in attrs.items() if str(v).strip())
            L.append(f"- **{n['label']}**" + (f" — {detail}" if detail else ""))
            L.append(f"  - source: {n['source_url']} (fetched {n['fetched']}, {n['verification']}, confidence {n['confidence']})")
            if n.get("note"):
                L.append(f"  - note: {n['note']}")
        L.append("")

    edges = m.get("edges", [])
    if edges:
        L.append("## How it connects")
        L.append("")
        for e in edges:
            a = by_id.get(e["from"], {}).get("label", e["from"])
            b = by_id.get(e["to"], {}).get("label", e["to"])
            L.append(f"- {a} — *{e['rel']}* → {b}")
        L.append("")

    gaps = m.get("not_collected", [])
    L.append("## Not collected (stated, never hidden)")
    L.append("")
    if gaps:
        for g in gaps:
            L.append(f"- **{g.get('layer')}** — {g.get('why')}")
    else:
        L.append("- nothing outstanding recorded")
    L.append("")

    out = path.parent / "account.md"
    out.write_text("\n".join(L), encoding="utf-8")
    return out


def rollup(maps: list[tuple[Path, dict]]) -> tuple[Path, Path]:
    GRAPH_DIR.mkdir(parents=True, exist_ok=True)
    nrows, erows = [], []
    for _, m in maps:
        aid = m["account_id"]
        for n in m.get("nodes", []):
            nrows.append({
                "account_id": aid, "node_id": n["id"], "type": n["type"], "label": n["label"],
                "confidence": n["confidence"], "verification": n["verification"],
                "fetched": n["fetched"], "source_url": n["source_url"],
                "attrs": json.dumps(n.get("attrs") or {}, ensure_ascii=True),
                "note": n.get("note", ""),
            })
        for e in m.get("edges", []):
            erows.append({"account_id": aid, "from": e["from"], "rel": e["rel"], "to": e["to"]})

    npath, epath = GRAPH_DIR / "nodes.csv", GRAPH_DIR / "edges.csv"
    for path, rows, cols in (
        (npath, nrows, ["account_id", "node_id", "type", "label", "confidence", "verification", "fetched", "source_url", "attrs", "note"]),
        (epath, erows, ["account_id", "from", "rel", "to"]),
    ):
        with path.open("w", encoding="utf-8", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=cols)
            w.writeheader()
            w.writerows(rows)
    return npath, epath


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    maps = load_maps()
    if not maps:
        print("no account maps found under data/accounts/*/account.json")
        return 1
    rc = 0

    if cmd in ("validate", "all"):
        all_errs = []
        for path, m in maps:
            all_errs += validate(path, m)
        if all_errs:
            print(f"VALIDATION FAILED - {len(all_errs)} violation(s):")
            for e in all_errs:
                print("  " + e)
            rc = 1
        else:
            total = sum(len(m.get("nodes", [])) for _, m in maps)
            print(f"VALIDATE OK: {len(maps)} account map(s), {total} nodes, every node sourced.")

    if cmd in ("brief", "all") and rc == 0:
        for path, m in maps:
            out = brief(path, m)
            print(f"BRIEF: {out.relative_to(REPO)}")

    if cmd in ("rollup", "all") and rc == 0:
        npath, epath = rollup(maps)
        print(f"ROLLUP: {npath.relative_to(REPO)} + {epath.relative_to(REPO)}")

    return rc


if __name__ == "__main__":
    raise SystemExit(main())
