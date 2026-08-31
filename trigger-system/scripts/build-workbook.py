"""Build the human-readable 26-accounts master workbook (.xlsx).

Reads data/accounts/*/account.json + data/event-calendar.csv and writes one
evenly-organized Excel workbook to the shared OneDrive folder (SDR-facing copy).
Rerun after any map merge:  python scripts\\build-workbook.py [optional-out-path]

Sheets: Overview | Teams & Leaders | Executives | Acquisitions |
        Business Units & Subsidiaries | Products | Events | Signals | About
"""
import csv, json, os, sys, datetime
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ACC_DIR = os.path.join(ROOT, "data", "accounts")
EVENTS_CSV = os.path.join(ROOT, "data", "event-calendar.csv")
# TAL expansion tier (added 2026-08-26, user order "add 30 more from the TAL"): the next-30
# by the documented 07-28 TAL score that are NOT among the mapped accounts. These rows are
# the TAL team's own research (revenue/size/demand-gen ratings/spend) - NOT independently
# verified, NOT mapped, NOT watched. They get their own clearly-labeled sheet, never mixed
# into the verified-evidence sheets.
TAL_EXPANSION_CSV = os.path.join(ROOT, "data", "imports", "2026-08-26-tal-expansion-30.csv")
DEFAULT_OUT = r"C:\Users\admin\OneDrive - Unbound IA Corp\Account Intelligence\26-Accounts-Master.xlsx"

NAMES = {
    "adobe": "Adobe", "alteryx": "Alteryx", "asana": "Asana", "autodesk": "Autodesk",
    "aws": "AWS", "blackline": "BlackLine", "bloomreach": "Bloomreach", "braze": "Braze",
    "databricks": "Databricks", "datadog": "Datadog", "g42": "G42",
    "insightsoftware": "insightsoftware", "odoo": "Odoo", "okta": "Okta",
    "paypal": "PayPal", "redhat": "Red Hat", "ringcentral": "RingCentral",
    "samsara": "Samsara", "sap": "SAP", "servicenow": "ServiceNow",
    "smartsheet": "Smartsheet", "snowflake": "Snowflake", "solarwinds": "SolarWinds",
    "stripe": "Stripe", "thomson-reuters": "Thomson Reuters", "twilio": "Twilio",
    # +10 expansion 2026-08-02 (gate-1 signed 2026-08-03)
    "workday": "Workday", "jamf": "Jamf", "upwork": "Upwork", "mongodb": "MongoDB",
    "veeam": "Veeam Software", "rubrik": "Rubrik", "xero": "Xero", "taboola": "Taboola",
    "genesys": "Genesys", "connectwise": "ConnectWise",
    # TAL expansion 2026-08-14 (Gate-1 sign-off PENDING for this batch - watch-only)
    "thryv": "Thryv", "cisco": "Cisco", "cornerstone": "Cornerstone OnDemand",
    "microsoft": "Microsoft", "paycom": "Paycom", "paylocity": "Paylocity",
    "salesforce": "Salesforce", "cloudera": "Cloudera", "epicor": "Epicor",
    "godaddy": "GoDaddy", "intuit": "Intuit", "linkedin": "LinkedIn",
    "logicmonitor": "LogicMonitor", "vanta": "Vanta", "zendesk": "Zendesk",
    "atlassian": "Atlassian", "docusign": "DocuSign", "grammarly": "Grammarly (Superhuman)",
    "trimble": "Trimble", "dell": "Dell Technologies", "newrelic": "New Relic",
    "nextiva": "Nextiva", "siemens": "Siemens PLM Software", "splunk": "Splunk",
    "zoho": "Zoho", "checkpoint": "Check Point", "xerox": "Xerox",
    "temenos": "Temenos", "qualtrics": "Qualtrics",
    # TAL expansion batch 3, 2026-08-26 (next-30 by the 07-28 TAL score; Gate-1 sign-off
    # PENDING - watch-only, no outreach)
    "akamai": "Akamai Technologies", "avalara": "Avalara", "netsuite": "NetSuite",
    "indeed": "Indeed", "dynatrace": "Dynatrace", "hexagon": "Hexagon",
    "procore": "Procore Technologies", "nutanix": "Nutanix", "bandwidth": "Bandwidth Inc.",
    "infor": "Infor", "netapp": "NetApp", "opentext": "OpenText", "teradata": "Teradata",
    "paycor": "Paycor", "wolterskluwer": "Wolters Kluwer", "slack": "Slack", "miro": "Miro",
    "beyondtrust": "BeyondTrust", "powerschool": "PowerSchool", "vertex": "Vertex Inc.",
    "meltwater": "Meltwater", "rippling": "Rippling", "squarespace": "Squarespace",
    "ninjaone": "NinjaOne", "gusto": "Gusto", "wrike": "Wrike", "checkr": "Checkr, Inc.",
    "avaya": "Avaya", "plaid": "Plaid", "icims": "ICIMS",
}

def person_name(node):
    lbl, title = node.get("label", ""), (node.get("attrs") or {}).get("title", "")
    if title and lbl.endswith(" - " + title):
        return lbl[: -len(" - " + title)]
    return lbl.split(" - ")[0] if " - " in lbl else lbl

# ---------- collect ----------
overview, teams, execs, acqs, units, products, signals = [], [], [], [], [], [], []
for slug in sorted(os.listdir(ACC_DIR)):
    path = os.path.join(ACC_DIR, slug, "account.json")
    if not os.path.isfile(path):
        continue
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    acct = NAMES.get(slug, slug.title())
    byid = {n["id"]: n for n in d["nodes"]}
    led_by = {}            # team id -> person node
    exec_ids = []
    for e in d.get("edges", []):
        if e["rel"] == "led_by" and e["to"] in byid:
            led_by[e["from"]] = byid[e["to"]]
        elif e["rel"] == "has_executive" and e["to"] in byid:
            exec_ids.append(e["to"])

    root_id = None
    for n in d["nodes"]:
        if n["type"] == "company" and (root_id is None or n["id"] == slug or n["id"] == d.get("account_id")):
            if root_id is None or n["id"] in (slug, d.get("account_id")):
                root_id = n["id"]
    root = byid.get(root_id) or {}
    ra = root.get("attrs") or {}
    comm = next((n for n in d["nodes"] if n["type"] == "commercial"), {})
    ca = comm.get("attrs") or {}

    n_subs = 0
    for n in d["nodes"]:
        a = n.get("attrs") or {}
        t = n["type"]
        if t == "team":
            p = led_by.get(n["id"]) or {}
            pa = p.get("attrs") or {}
            teams.append([acct, n["label"], a.get("function", ""), a.get("region", ""),
                          a.get("leader_name", ""), a.get("leader_title", ""),
                          pa.get("in_role_since", ""), p.get("source_url", ""),
                          n.get("confidence", "")])
        elif t == "acquisition":
            acqs.append([acct, n["label"], a.get("price", ""),
                         a.get("when", "") or a.get("closed", "") or a.get("announced", ""),
                         a.get("brings", "") or a.get("rationale", ""),
                         a.get("absorbed_into", ""), n.get("source_url", "")])
        elif t == "business_unit":
            units.append([acct, n["label"], "Business unit", a.get("kind", ""),
                          a.get("serves", "")])
        elif t == "company" and n["id"] != root_id:
            n_subs += 1
            units.append([acct, n["label"], "Subsidiary",
                          a.get("jurisdiction", "") or a.get("state_of_incorporation", ""), ""])
        elif t == "product":
            products.append([acct, n["label"], a.get("status", ""), a.get("segment", "")])
        elif t == "signal":
            signals.append([acct, n["label"], a.get("class", ""), a.get("lane", ""),
                            a.get("window", ""), a.get("team_id", "")])
    for pid in exec_ids:
        p = byid[pid]; pa = p.get("attrs") or {}
        execs.append([acct, person_name(p), pa.get("title", ""), pa.get("location", ""),
                      p.get("source_url", "")])

    counts = {}
    for n in d["nodes"]:
        counts[n["type"]] = counts.get(n["type"], 0) + 1
    n_led = sum(1 for n in d["nodes"] if n["type"] == "team" and (n.get("attrs") or {}).get("leader_name"))
    overview.append([acct, ra.get("domain", ""), ra.get("ticker", ""),
                     ca.get("sdr_owner", ""), ca.get("outreach_allowed", ""),
                     counts.get("team", 0), n_led, len(exec_ids),
                     counts.get("business_unit", 0), n_subs,
                     counts.get("acquisition", 0), counts.get("product", 0),
                     counts.get("event", 0), counts.get("signal", 0)])

events = []
if os.path.isfile(EVENTS_CSV):
    with open(EVENTS_CSV, encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            name = r.get("event_name", "")
            acct, _, ev = name.partition(": ")
            events.append([NAMES.get(acct.strip(), acct.strip()), ev or name,
                           r.get("event_date", ""), r.get("location", ""),
                           r.get("window_open", ""), r.get("window_close", ""),
                           r.get("status", ""), r.get("notes", "")])

# ---------- write ----------
wb = Workbook(); wb.remove(wb.active)
HDR_FONT = Font(bold=True, color="FFFFFF", size=11)
HDR_FILL = PatternFill("solid", fgColor="26293A")
ZEBRA = PatternFill("solid", fgColor="F2F3F7")

def sheet(title, tab_color, headers, rows, widths):
    ws = wb.create_sheet(title)
    ws.sheet_properties.tabColor = tab_color
    ws.append(headers)
    for c in ws[1]:
        c.font, c.fill = HDR_FONT, HDR_FILL
        c.alignment = Alignment(vertical="center")
    for i, row in enumerate(rows):
        ws.append(row)
        if i % 2:
            for c in ws[ws.max_row]:
                c.fill = ZEBRA
    for ci, w in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(ci)].width = w
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = ws.dimensions
    return ws

sheet("Overview", "E8C268",
      ["Account", "Domain", "Ticker", "SDR owner", "Outreach allowed", "Teams",
       "Teams w/ named leader", "Executives", "Business units", "Subsidiaries",
       "Acquisitions", "Products", "Events", "Signals"],
      overview, [18, 22, 9, 12, 15, 8, 18, 11, 13, 12, 12, 10, 8, 8])
sheet("Teams & Leaders", "9ECE6A",
      ["Account", "Team", "Function", "Region", "Leader", "Leader title",
       "In role since", "LinkedIn", "Confidence"],
      teams, [16, 46, 18, 10, 24, 42, 13, 46, 11])
sheet("Executives", "F7768E",
      ["Account", "Name", "Title", "Location", "LinkedIn"],
      execs, [16, 26, 44, 30, 46])
sheet("Acquisitions", "FF9E64",
      ["Account", "Acquired company", "Price", "When", "What it brings",
       "Absorbed into", "Source"],
      acqs, [16, 34, 14, 12, 52, 18, 40])
sheet("Business Units & Subs", "7AA2F7",
      ["Account", "Name", "Type", "Kind / jurisdiction", "Serves"],
      units, [16, 48, 14, 22, 30])
sheet("Products", "BB9AF7",
      ["Account", "Product", "Status", "Segment"],
      products, [16, 44, 14, 22])
sheet("Events", "E0AF68",
      ["Account", "Event", "Date", "Location", "Outreach window opens",
       "Window closes", "Status", "Notes"],
      events, [16, 24, 12, 36, 20, 14, 13, 44])
sheet("Signals", "FF5555",
      ["Account", "Signal", "Class", "Lane", "Window", "Team"],
      signals, [16, 30, 16, 12, 18, 26])

tal_rows = []
mapped_domains = {row[1] for row in overview}  # a TAL row with a real map leaves this sheet
if os.path.isfile(TAL_EXPANSION_CSV):
    with open(TAL_EXPANSION_CSV, encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            if r.get("domain", "") in mapped_domains:
                continue
            spend = r.get("paid_spend_2025_usd", "")
            try:
                spend = f"${float(spend)/1e6:,.1f}M" if spend else ""
            except ValueError:
                pass
            tal_rows.append([r.get("name", ""), r.get("domain", ""), r.get("industry", ""),
                             r.get("size", ""), r.get("revenue_validated", ""),
                             r.get("ownership", ""), r.get("hq_location", ""),
                             r.get("country", ""), r.get("demand_gen_rating", ""),
                             r.get("demand_gen_research", ""), r.get("intent_topic", ""),
                             spend, r.get("paid_ads_running", ""),
                             r.get("parent_company", ""), r.get("tal_score", ""),
                             r.get("linkedin_url", "")])
if tal_rows:
    sheet("TAL Expansion (unmapped)", "8B90A0",
          ["Company", "Domain", "Industry", "Size", "Revenue (TAL-validated)",
           "Ownership", "HQ", "Country", "Demand-gen rating", "Demand-gen research (TAL team)",
           "Intent topic", "Paid spend 2025", "Ads running", "Parent company",
           "TAL score (max 9)", "LinkedIn"],
          tal_rows, [24, 20, 22, 18, 20, 16, 22, 14, 16, 70, 20, 14, 11, 18, 15, 46])

about = wb.create_sheet("About"); about.sheet_properties.tabColor = "8B90A0"
today = str(datetime.date.today())
for row in [
    [f"Accounts Master Workbook ({len(overview)} mapped accounts"
     + (f" + {len(tal_rows)} TAL expansion candidates)" if tal_rows else ")")],
    [f"Generated {today} from the trigger-system account maps (verified-evidence-only)."],
    [""],
    ["Overview", "One row per account - what exists and who owns it"],
    ["Teams & Leaders", "Every mapped marketing team (Sr-Manager+ bar, global) with its leader"],
    ["Executives", "C-suite / named executives per account"],
    ["Acquisitions", "Verified acquisitions with price, date and rationale"],
    ["Business Units & Subs", "Business units + legal subsidiaries (from SEC filings where public)"],
    ["Products", "Named products / sub-brands per account"],
    ["Events", "Company events with the outreach windows (T-98d to T-56d before event)"],
    ["Signals", "Trigger signals recorded to date"],
    ["TAL Expansion (unmapped)", "Next-30 TAL candidates by the 2026-07-28 deterministic score. "
     "TAL-team research only (revenue, demand-gen ratings, spend) - NOT independently verified, "
     "NOT org-mapped, NOT watched by the weekly system. Admission to the watched set needs "
     "discovery (live watch surface) + Gate-1 sign-off, same as every prior batch."],
    [""],
    ["Every fact carries a source in the underlying maps; interactive graph available - ask Shrikant."],
    ["Refresh: python scripts\\build-workbook.py (in the trigger-system repo)."],
]:
    about.append(row)
about["A1"].font = Font(bold=True, size=14)
about.column_dimensions["A"].width = 26; about.column_dimensions["B"].width = 80

out = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUT
os.makedirs(os.path.dirname(out), exist_ok=True)
wb.save(out)
print(f"OK {out}")
print(f"overview={len(overview)} teams={len(teams)} execs={len(execs)} acq={len(acqs)} "
      f"units={len(units)} products={len(products)} events={len(events)} signals={len(signals)}")
