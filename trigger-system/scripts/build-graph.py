"""Build viz/account-graph.html — the interactive account-intelligence graph.

Reads every data/accounts/*/account.json, compacts nodes+edges, injects them into
viz/graph-template.html at the __GRAPH_DATA__ placeholder. Re-run after any map merge.
Pure read -> single HTML artifact; no network, no credentials.
"""
import json, os, sys, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ACC_DIR = os.path.join(ROOT, "data", "accounts")
TEMPLATE = os.path.join(ROOT, "viz", "graph-template.html")
OUT = os.path.join(ROOT, "viz", "account-graph.html")

NAMES = {
    "adobe": "Adobe", "alteryx": "Alteryx", "asana": "Asana", "autodesk": "Autodesk",
    "aws": "AWS", "blackline": "BlackLine", "bloomreach": "Bloomreach", "braze": "Braze",
    "databricks": "Databricks", "datadog": "Datadog", "g42": "G42",
    "insightsoftware": "insightsoftware", "odoo": "Odoo", "okta": "Okta",
    "paypal": "PayPal", "redhat": "Red Hat", "ringcentral": "RingCentral",
    "samsara": "Samsara", "sap": "SAP", "servicenow": "ServiceNow",
    "smartsheet": "Smartsheet", "snowflake": "Snowflake", "solarwinds": "SolarWinds",
    "stripe": "Stripe", "thomson-reuters": "Thomson Reuters", "twilio": "Twilio",
}
# One hex accent per account (UI color identity; shown in the account list + top bar).
COLORS = {
    "adobe": "#ED2224", "alteryx": "#1CA8DD", "asana": "#E9598C", "autodesk": "#0FBBAA",
    "aws": "#FF9900", "blackline": "#F2C230", "bloomreach": "#8B5CF6", "braze": "#FF6A3D",
    "databricks": "#D64550", "datadog": "#966BD6", "g42": "#6EE7B7",
    "insightsoftware": "#4ADE80", "odoo": "#A855F7", "okta": "#3B82F6",
    "paypal": "#009CDE", "redhat": "#F87171", "ringcentral": "#FFB454",
    "samsara": "#22D3EE", "sap": "#4F8FF7", "servicenow": "#62D84E",
    "smartsheet": "#3E6FD9", "snowflake": "#29B5E8", "solarwinds": "#FCA311",
    "stripe": "#635BFF", "thomson-reuters": "#FF8000", "twilio": "#F22F46",
}

accounts = []
tot_nodes = tot_edges = tot_skipped = 0
for slug in sorted(os.listdir(ACC_DIR)):
    path = os.path.join(ACC_DIR, slug, "account.json")
    if not os.path.isfile(path):
        continue
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    idx, nodes = {}, []
    for i, n in enumerate(d["nodes"]):
        idx[n["id"]] = i
        # compact layout consumed by the template: [type,label,attrs,src,ver,conf,note,fetched]
        nodes.append([
            n["type"], n.get("label", ""), n.get("attrs") or {},
            n.get("source_url", ""), n.get("verification", ""),
            n.get("confidence", ""), n.get("note", ""), n.get("fetched", ""),
        ])
    edges, skipped = [], 0
    for e in d.get("edges", []):
        a, b = idx.get(e.get("from")), idx.get(e.get("to"))
        if a is None or b is None:
            skipped += 1
            continue
        edges.append([a, b, e.get("rel", "")])
    deg = [0] * len(nodes)
    for a, b, _ in edges:
        deg[a] += 1
        deg[b] += 1
    company_ix = [i for i, n in enumerate(nodes) if n[0] == "company"]
    root = max(company_ix, key=lambda i: deg[i]) if company_ix else 0
    counts = {}
    for n in nodes:
        counts[n[0]] = counts.get(n[0], 0) + 1
    accounts.append({
        "id": slug, "name": NAMES.get(slug, slug.title()),
        "color": COLORS.get(slug, "#8b90a0"), "root": root,
        "counts": counts, "nodes": nodes, "edges": edges,
    })
    tot_nodes += len(nodes)
    tot_edges += len(edges)
    tot_skipped += skipped
    if skipped:
        print(f"WARN {slug}: {skipped} edge(s) skipped - endpoint id not found")

data = {"generated": str(datetime.date.today()), "accounts": accounts}
payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
payload = payload.replace("</", "<\\/")  # keep the inline <script> unbreakable

with open(TEMPLATE, encoding="utf-8") as f:
    tpl = f.read()
if "__GRAPH_DATA__" not in tpl:
    sys.exit("template missing __GRAPH_DATA__ placeholder")
html = tpl.replace("__GRAPH_DATA__", payload)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(html)
print(f"OK {OUT}")
print(f"{len(accounts)} accounts, {tot_nodes} nodes, {tot_edges} edges "
      f"({tot_skipped} skipped), {len(html)/1e6:.2f} MB")
