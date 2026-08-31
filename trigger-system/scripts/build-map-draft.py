"""Pre-fill an account map from evidence ALREADY ON DISK. Zero credits, zero guesses.

What this does NOT do is as important as what it does. It fills only the layers that a file we
already hold can prove: identity, headquarters, where they actually hire, martech tells, fired
signals, mapped teams, and SDR ownership. Business units, products, segments, named people and
acquisitions are NOT derivable from anything on disk - the generator writes them into the
not_collected block instead of inventing them. Filling those is live research (plan Part 4).

Every emitted node carries source_url + fetched + verification + confidence, so the output passes
`python scripts/account-map.py validate` unchanged. Internal sources use a repo-relative path with
verification=captured_snapshot, matching the hand-built Thomson Reuters map.

SAFETY, in two layers:
  1. An existing map is never overwritten without --force.
  2. A HAND-BUILT map (one with no "map_origin: generated draft" marker) is not overwritten even
     WITH --force. It takes --force --overwrite-handbuilt together. This exists because --force
     did destroy Thomson Reuters' 27 hand-researched nodes on 2026-07-29 - recovered from git,
     then made structurally impossible rather than left to care.

Usage:
    python scripts/build-map-draft.py --date 2026-07-29              # all accounts, skip existing
    python scripts/build-map-draft.py --date 2026-07-29 --only braze
    python scripts/build-map-draft.py --date 2026-07-29 --force      # refresh generated drafts
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ACCOUNTS_CSV = REPO / "config" / "accounts.csv"
SDR_CSV = REPO / "config" / "sdr-assignments.csv"
TEAMS_CSV = REPO / "data" / "teams.csv"
TRIGGERS = REPO / "data" / "triggers.jsonl"
ACCOUNTS_DIR = REPO / "data" / "accounts"

EVIDENCE_NOTE = (
    "Every node carries source_url + fetched + verification. No source, no node. verification is "
    "one of: live_fetch (a URL fetched in-session and returning content), captured_snapshot (our "
    "own dated raw capture on disk), internal_research (company-supplied research; NOT "
    "independently verified - always flagged)."
)

# Layers this generator structurally cannot fill, and why. Written into not_collected so a map
# never implies completeness it does not have.
RESEARCH_LAYERS = {
    "business_unit": "no file on disk names their business units - requires reading the company's own about/company page (core-depth research pass)",
    "product": "no file on disk names their products - requires reading the company's own product pages",
    "segment": "who they sell to is not derivable from job feeds - requires the company's own positioning pages",
    "person": "named leaders are not on disk. Free public sources only (leadership page, press releases, speaker bios); paid enrichment (ZoomInfo) is verdict-gated by config/enrichment-policy.md and may NOT be called from a mapping run",
    "acquisition": "requires the company's own press releases (and SEC 8-K item 2.01 for filers)",
    "event": "events are not derivable from job feeds - check data/event-calendar.csv and the company's own events pages (research pass)",
    "partner": "no partner-ecosystem source has been read",
}


def read_csv(path: Path) -> list[dict]:
    """utf-8-sig throughout: several repo CSVs carry a BOM written by PowerShell, and a stray BOM
    corrupts the FIRST column name, which silently breaks every lookup against it."""
    if not path.exists():
        return []
    with path.open(encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


def slug(s: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", (s or "").lower()).strip("-")
    return s or "unknown"


def txt(v) -> str:
    return ("" if v is None else str(v)).strip()


class MapBuilder:
    def __init__(self, aid: str, date: str):
        self.aid = aid
        self.date = date
        self.nodes: list[dict] = []
        self.edges: list[dict] = []
        self.types_present: set[str] = set()

    def node(self, nid, ntype, label, source_url, fetched, verification, confidence, attrs=None, note=None):
        n = {
            "id": nid, "type": ntype, "label": label,
            "attrs": {k: txt(v) for k, v in (attrs or {}).items() if txt(v)},
            "source_url": source_url, "fetched": fetched,
            "verification": verification, "confidence": confidence,
        }
        if note:
            n["note"] = note
        self.nodes.append(n)
        self.types_present.add(ntype)
        return nid

    def edge(self, a, b, rel):
        self.edges.append({"from": a, "to": b, "rel": rel})


def load_sec(day_dir: Path, aid: str):
    p = day_dir / "sec" / f"{aid}.json"
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8-sig"))
    except Exception:
        return None


def job_locations(day_dir: Path, aid: str, ats_type: str) -> Counter:
    """Where they are ACTUALLY hiring, straight out of our own captures. The Thomson Reuters map
    set the precedent: geography evidenced by hiring, not by a generic corporate map."""
    ats_dir = day_dir / "ats"
    if not ats_dir.exists():
        return Counter()
    files = sorted(ats_dir.glob(f"{aid}.json")) + sorted(ats_dir.glob(f"{aid}.p*.json"))
    locs: Counter = Counter()
    for f in files:
        try:
            obj = json.loads(f.read_text(encoding="utf-8-sig"))
        except Exception:
            continue
        rows = []
        if ats_type == "greenhouse":
            rows = [(j.get("location") or {}).get("name") for j in (obj.get("jobs") or [])]
        elif ats_type == "ashby":
            rows = [j.get("location") or j.get("address") for j in (obj.get("jobs") or [])]
        elif ats_type == "workday":
            rows = [j.get("locationsText") for j in (obj.get("jobPostings") or [])]
        elif ats_type == "smartrecruiters":
            for j in (obj.get("content") or []):
                lo = j.get("location") or {}
                bits = [lo.get("city"), lo.get("region"), lo.get("country")]
                rows.append(", ".join(b for b in bits if b))
        elif ats_type == "lever":
            rows = [((j.get("categories") or {}).get("location")) for j in (obj if isinstance(obj, list) else [])]
        elif ats_type == "recruitee":
            rows = [j.get("location") for j in (obj.get("offers") or [])]
        for r in rows:
            r = txt(r)
            if r and r.lower() not in ("remote", "n/a"):
                locs[r] += 1
    return locs


def build(acc: dict, date: str, day_dir: Path, sdr_by_id: dict, teams_by_id: dict,
          triggers_by_id: dict, stack_by_id: dict) -> dict:
    aid = txt(acc.get("account_id"))
    b = MapBuilder(aid, date)
    ats_type = txt(acc.get("ats_type")).lower()
    domain = txt(acc.get("domain"))
    cik = txt(acc.get("sec_edgar"))

    sec = load_sec(day_dir, aid)
    sec_url = f"https://data.sec.gov/submissions/CIK{cik}.json" if cik else ""

    # ---- company (always present; the root every other node hangs off)
    if sec:
        attrs = {
            "domain": domain,
            "legal_name": sec.get("name"),
            "ticker": ", ".join(sec.get("tickers") or []) or txt(acc.get("ticker")),
            "exchanges": ", ".join(sec.get("exchanges") or []),
            "sec_cik": cik,
            "sic": f"{txt(sec.get('sic'))} {txt(sec.get('sicDescription'))}".strip(),
            "entity_type": sec.get("entityType"),
            "state_of_incorporation": sec.get("stateOfIncorporationDescription"),
            "fiscal_year_end": sec.get("fiscalYearEnd"),
        }
        former = [txt(f.get("name")) for f in (sec.get("formerNames") or []) if txt(f.get("name"))]
        note = None
        if former:
            attrs["former_names"] = " | ".join(former)
            note = ("Former registered name(s) on file at the SEC. A legal name change is direct "
                    "rebrand_repositioning evidence - confirm the date from the filing before using it.")
        b.node(aid, "company", txt(sec.get("name")) or txt(acc.get("account_name")),
               sec_url, date, "live_fetch", "HIGH", attrs, note)
    else:
        # No CIK (private company or subsidiary). The only thing we have actually fetched for this
        # company is its job feed, so that is the source and the attrs stay narrow.
        src = txt(acc.get("ats_feed_url")) or txt(acc.get("careers_url"))
        ver, conf = ("captured_snapshot", "MED") if src else ("internal_research", "LOW")
        b.node(aid, "company", txt(acc.get("account_name")),
               src or "config/accounts.csv", date, ver, conf,
               {"domain": domain, "ticker": txt(acc.get("ticker"))},
               "No SEC CIK (private company or subsidiary), so identity is evidenced only by the "
               "careers surface we fetched. Legal name, HQ and industry are NOT verified.")

    # ---- geography: HQ from SEC, operating footprint from where they hire
    if sec:
        biz = (sec.get("addresses") or {}).get("business") or {}
        city, st = txt(biz.get("city")), txt(biz.get("stateOrCountry"))
        if city:
            nid = b.node(f"{aid}:geo:hq", "geography", f"HQ: {city}, {st}".strip(", "),
                         sec_url, date, "live_fetch", "HIGH",
                         {"street": biz.get("street1"), "city": city, "state_or_country": st,
                          "zip": biz.get("zipCode")})
            b.edge(aid, nid, "located_in")

    locs = job_locations(day_dir, aid, ats_type)
    if locs:
        top = locs.most_common(12)
        snap = f"data/snapshots/{date}/ats/{aid}.json"
        nid = b.node(f"{aid}:geo:hiring", "geography",
                     f"Hiring footprint: {len(locs)} distinct locations across {sum(locs.values())} postings",
                     snap, date, "captured_snapshot", "HIGH",
                     {"top_locations": "; ".join(f"{k} ({v})" for k, v in top)},
                     "Geography evidenced by where they are actually hiring, not by a generic "
                     "corporate map. Marketing-only breakdown needs the semantic JD read.")
        b.edge(aid, nid, "operates_in")

    # ---- teams already mapped
    for t in teams_by_id.get(aid, []):
        tid = f"{aid}:team:{slug(txt(t.get('team_name')))}"
        conf = txt(t.get("confidence")).upper() or "MED"
        if conf not in ("HIGH", "MED", "MED-HIGH", "LOW"):
            conf = "MED"
        ev = txt(t.get("evidence_urls")).split(";")[0].strip() or "data/teams.csv"
        leader = txt(t.get("leader_name"))
        b.node(tid, "team", txt(t.get("team_name")), ev, txt(t.get("last_verified")) or date,
               "live_fetch" if ev.startswith("http") else "captured_snapshot", conf,
               {"bu_or_brand": t.get("bu_or_brand"), "region": t.get("region"),
                "leader_name": leader, "leader_title": t.get("leader_title"),
                "status": t.get("status"),
                "scoreable": "yes" if leader else "structural only - no named leader yet"},
               None if leader else "No named leader. Per config/enrichment-policy.md, naming is "
                                   "verdict-gated Tier-2 work - a team gets named when it gets hot.")
        b.edge(aid, tid, "has_team")

    # ---- martech tells
    for s in stack_by_id.get(aid, []):
        if txt(s.get("classification")) != "stack_fact":
            continue   # vendor_noise is the account's own product vocabulary, not their stack
        tell = txt(s.get("tell"))
        nid = b.node(f"{aid}:stack:{slug(tell)}", "tech_stack", tell,
                     txt(s.get("source_file")) or f"data/stack-tells/{date}.csv", date,
                     "captured_snapshot", "MED-HIGH",
                     {"hit_count": s.get("hit_count"), "context": s.get("context_snippet")},
                     "Candidate martech_replatform evidence. Evidence only - never a fired trigger "
                     "on its own.")
        b.edge(aid, nid, "uses_tool")

    # ---- fired signals
    for tr in triggers_by_id.get(aid, []):
        sid = f"{aid}:signal:{slug(txt(tr.get('trigger_id')))}-{txt(tr.get('fired_date')).replace('-', '')}"
        b.node(sid, "signal", f"{txt(tr.get('trigger_id'))} (Tier {txt(tr.get('tier'))})",
               "data/triggers.jsonl", txt(tr.get("fired_date")) or date, "captured_snapshot", "HIGH",
               {"lane": tr.get("lane"), "window": tr.get("window"),
                "team_id": tr.get("team_id"), "play_id": tr.get("play_id")})
        team_nid = f"{aid}:team:{slug(txt(tr.get('team_id')))}"
        b.edge(aid, sid, "triggered")
        if any(n["id"] == team_nid for n in b.nodes):
            b.edge(team_nid, sid, "triggered")

    # ---- commercial: who owns it and whether we may contact anyone at all
    sdr = sdr_by_id.get(aid)
    if sdr:
        nid = b.node(f"{aid}:commercial:ownership", "commercial",
                     f"SDR owner: {txt(sdr.get('sdr_owner'))}",
                     "config/sdr-assignments.csv", txt(sdr.get("assigned_date")) or date,
                     "captured_snapshot", "HIGH",
                     {"sdr_owner": sdr.get("sdr_owner"), "assignment_basis": sdr.get("match_source"),
                      "conflict_marker": txt(sdr.get("sheet_comment")) or "none on file",
                      "gate_status": "See config/gates.md + this account's accounts.csv note. Gate 1 re-opens per newly added account (scoring-rules 0.1) - a map never asserts gate state itself (stale-boilerplate lesson 2026-08-15). Sends need suppression check + the OWNER running the play + sequencer (owner-run model 2026-08-16).",
                      "outreach_allowed": "NO"})
        b.edge(aid, nid, "owned_by")

    # ---- state the gaps rather than implying completeness
    not_collected = [{"layer": layer, "why": why}
                     for layer, why in RESEARCH_LAYERS.items() if layer not in b.types_present]
    if "team" not in b.types_present:
        not_collected.append({"layer": "team", "why": "no rows in data/teams.csv for this account - team mapping has not reached it yet"})
    if "tech_stack" not in b.types_present:
        not_collected.append({"layer": "tech_stack", "why": "no stack tells detected in the captured job feeds; absence of a tell is not absence of a stack"})
    if "geography" not in b.types_present:
        not_collected.append({"layer": "geography", "why": "no SEC address and no parseable job locations (page_only careers surface)"})
    if not cik:
        not_collected.append({"layer": "sec_filings", "why": "no SEC CIK on file, so the filings lane cannot cover this account at all"})

    return {
        "account_id": aid,
        "schema_version": "1.0",
        "map_built": date,
        "map_origin": "generated draft (scripts/build-map-draft.py) from on-disk evidence only - core-depth research layers still outstanding",
        "evidence_rule": "verified_only",
        "evidence_rule_note": EVIDENCE_NOTE,
        "nodes": b.nodes,
        "edges": b.edges,
        "not_collected": not_collected,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", required=True, help="snapshot day to build from, yyyy-mm-dd")
    ap.add_argument("--only", default="", help="comma-separated account_ids")
    ap.add_argument("--force", action="store_true",
                    help="overwrite existing GENERATED drafts (hand-built maps are still protected)")
    ap.add_argument("--overwrite-handbuilt", action="store_true",
                    help="DANGEROUS: also overwrite hand-built maps. Requires --force.")
    ap.add_argument("--overwrite-enriched", action="store_true",
                    help="DANGEROUS: also overwrite generated maps that carry enrichment layers "
                         "(people/BU/product/acquisition/event/partner/segment nodes) the generator "
                         "cannot rebuild. Requires --force. Added 2026-08-15 after --force alone "
                         "destroyed 3,862->291 nodes on 2026-08-14 (recovered from git).")
    args = ap.parse_args()

    day_dir = REPO / "data" / "snapshots" / args.date
    if not day_dir.exists():
        print(f"ABORT - no snapshot day at {day_dir}. Run watch-monday.ps1 first.")
        return 1

    accounts = read_csv(ACCOUNTS_CSV)
    if not accounts:
        print("ABORT - config/accounts.csv unreadable or empty.")
        return 1

    sdr_by_id = {txt(r.get("account_id")): r for r in read_csv(SDR_CSV)}
    teams_by_id: dict[str, list] = {}
    for r in read_csv(TEAMS_CSV):
        teams_by_id.setdefault(txt(r.get("account_id")), []).append(r)
    stack_by_id: dict[str, list] = {}
    stack_file = REPO / "data" / "stack-tells" / f"{args.date}.csv"
    for r in read_csv(stack_file):
        stack_by_id.setdefault(txt(r.get("account_id")), []).append(r)

    triggers_by_id: dict[str, list] = {}
    if TRIGGERS.exists():
        raw = [l.strip().lstrip("\ufeff") for l in TRIGGERS.read_text(encoding="utf-8-sig").splitlines()]
        expected = len([l for l in raw if l])
        parsed = 0
        for line in raw:
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            parsed += 1
            triggers_by_id.setdefault(txt(obj.get("account_id")), []).append(obj)
        if parsed != expected:
            # a silently dropped trigger row would understate an account's heat in its own map
            print(f"ABORT - {expected - parsed} of {expected} trigger row(s) failed to parse.")
            return 1

    only = {s.strip() for s in args.only.split(",") if s.strip()}
    # Node types the generator structurally cannot produce (RESEARCH_LAYERS). A generated map
    # carrying any of them was enriched AFTER generation; regenerating it destroys those layers.
    enriched_types = set(RESEARCH_LAYERS.keys())
    written, skipped, protected, enriched_kept = [], [], [], []
    for acc in accounts:
        aid = txt(acc.get("account_id"))
        if not aid or (only and aid not in only):
            continue
        out = ACCOUNTS_DIR / aid / "account.json"
        if out.exists():
            # A map WITHOUT a map_origin marker was hand-built from live research. --force alone
            # must never destroy one. (Learned the hard way 2026-07-29: --force replaced Thomson
            # Reuters' 27 hand-researched nodes with a 9-node draft; recovered from git.)
            try:
                existing = json.loads(out.read_text(encoding="utf-8-sig"))
            except Exception:
                existing = {}
            handbuilt = not txt(existing.get("map_origin")).startswith("generated draft")
            if handbuilt and not (args.force and args.overwrite_handbuilt):
                protected.append(aid)
                continue
            # Generated-but-ENRICHED maps: --force alone must not destroy them either.
            # (Learned the hard way 2026-08-14: --force on 31 enriched maps collapsed the
            # repo from 3,862 to 291 nodes; recovered from git. Guard added 2026-08-15.)
            if not handbuilt:
                existing_types = {txt(n.get("type")) for n in existing.get("nodes", [])
                                  if isinstance(n, dict)}
                if (existing_types & enriched_types) and not (args.force and args.overwrite_enriched):
                    enriched_kept.append(aid)
                    continue
            if not args.force:
                skipped.append(aid)
                continue
        m = build(acc, args.date, day_dir, sdr_by_id, teams_by_id, triggers_by_id, stack_by_id)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(m, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
        written.append((aid, len(m["nodes"]), len(m["edges"]), len(m["not_collected"])))

    print(f"WROTE {len(written)} draft map(s):")
    for aid, n, e, g in sorted(written):
        print(f"  {aid:<18} {n:>3} nodes  {e:>3} edges  {g:>2} declared gaps")
    if skipped:
        print(f"SKIPPED {len(skipped)} existing draft(s) (use --force to overwrite): {', '.join(sorted(skipped))}")
    if protected:
        print(f"PROTECTED {len(protected)} HAND-BUILT map(s) - not touched: {', '.join(sorted(protected))}")
        print("  These were researched live, not generated. --force alone will not overwrite them.")
    if enriched_kept:
        print(f"PROTECTED {len(enriched_kept)} ENRICHED generated map(s) - not touched: {', '.join(sorted(enriched_kept))}")
        print("  They carry research layers (people/BU/products/...) this generator cannot rebuild.")
        print("  --force alone will not overwrite them; that needs --force --overwrite-enriched.")
    print("\nNext: python scripts/account-map.py validate")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
