# Open-Market STRIKE Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a safe, fixture-verifiable Monday pipeline that suppresses the existing TAL, evaluates public buying signals, builds evidence-graded plays, prepares ZoomInfo requests, and creates unsent Outlook drafts.

**Architecture:** Keep the active implementation under `trigger-system` and use a small Python standard-library package for deterministic policy, state, and payload generation. Preserve AI judgment in a sharply bounded Play Director instruction set and sanitized field-intelligence files. Keep ZoomInfo and Outlook behind PowerShell adapters that default to dry-run and never send mail.

**Tech Stack:** Python 3 standard library, `unittest`, PowerShell 5.1+, JSON/JSONL/CSV/Markdown, Outlook COM for optional local draft creation.

---

## File Structure

- `trigger-system/agent/`: deterministic Python package.
- `trigger-system/tests/`: unit and end-to-end fixture tests.
- `trigger-system/config/`: signal policy, claim register, suppression inputs, and environment allowlist.
- `trigger-system/context/`: sanitized field intelligence and play rules.
- `trigger-system/fixtures/monday/`: synthetic end-to-end inputs.
- `trigger-system/scripts/ai-gtm.ps1`: operator entry point.
- `trigger-system/scripts/publish-outlook-drafts.ps1`: draft-only Outlook boundary.
- `trigger-system/staging/runtime/`: ignored run checkpoints and outputs.
- `trigger-system/runbooks/`: setup and Monday operation.

### Task 1: Repository safety and suppression baseline

**Files:**
- Modify: `.gitignore`
- Create: `trigger-system/config/suppression-extra.txt`
- Create: `trigger-system/agent/domains.py`
- Create: `trigger-system/tests/test_domains.py`

- [ ] **Step 1: Write the failing domain tests**

```python
import unittest
from agent.domains import normalize_domain, suppression_set

class DomainTests(unittest.TestCase):
    def test_normalizes_urls_and_www(self):
        self.assertEqual(normalize_domain("HTTPS://www.Example.com/path"), "example.com")

    def test_suppression_is_unique(self):
        self.assertEqual(suppression_set(["www.a.com", "https://a.com", "b.com"]), {"a.com", "b.com"})
```

- [ ] **Step 2: Run the test and verify it fails because `agent.domains` is missing**

Run: `python -m unittest tests.test_domains -v` from `trigger-system`  
Expected: `ModuleNotFoundError: No module named 'agent.domains'`

- [ ] **Step 3: Implement normalization and CSV extraction**

```python
def normalize_domain(value: str) -> str:
    text = (value or "").strip().lower()
    parsed = urlsplit(text if "://" in text else "//" + text)
    host = (parsed.hostname or "").rstrip(".")
    return host[4:] if host.startswith("www.") else host

def suppression_set(values: Iterable[str]) -> set[str]:
    return {domain for value in values if (domain := normalize_domain(value))}
```

- [ ] **Step 4: Generate `suppression-baseline.csv` from the supplied TAL plus 11 documented extra domains**

Run: `python -m agent.cli prepare-suppression --tal "C:\Users\admin\Downloads\Final Master TAL for Paid & Marketing(Assigned).csv"`  
Expected: `648 suppression domains written`

- [ ] **Step 5: Run the tests and validate count/uniqueness**

Run: `python -m unittest tests.test_domains -v`  
Expected: all domain tests pass.

### Task 2: Signal windows and STRIKE decision core

**Files:**
- Create: `trigger-system/config/signal-policy.json`
- Create: `trigger-system/agent/models.py`
- Create: `trigger-system/agent/signals.py`
- Create: `trigger-system/agent/decision.py`
- Create: `trigger-system/tests/test_decision.py`

- [ ] **Step 1: Write failing tests for window edges, source independence, and separate fit/heat scores**

```python
def test_two_independent_in_window_signals_strike(self):
    result = decide(self.account, [self.leader_signal, self.hiring_signal], as_of=date(2026, 8, 31))
    self.assertEqual(result.verdict, "STRIKE")
    self.assertGreater(result.heat_score, 0)
    self.assertGreaterEqual(result.independent_signal_count, 2)

def test_duplicate_source_does_not_create_strike(self):
    result = decide(self.account, [self.leader_signal, replace(self.leader_signal, signal_type="hiring_surge")], as_of=date(2026, 8, 31))
    self.assertNotEqual(result.verdict, "STRIKE")
```

- [ ] **Step 2: Run the tests and verify missing-module failures**

Run: `python -m unittest tests.test_decision -v`  
Expected: import failure for the new decision modules.

- [ ] **Step 3: Implement immutable account, evidence, signal, and decision records**

```python
@dataclass(frozen=True)
class Signal:
    signal_type: str
    team: str
    observed_date: date
    source_url: str
    source_key: str
    evidence_quote: str
    confidence: str = "verified"
```

- [ ] **Step 4: Implement configured date windows and deterministic scoring**

`evaluate_signal()` must return explicit `in_window`, `out_of_window`, or `manual_review`. `decide()` must suppress first, count independent source keys, keep fit separate from heat, and require two coherent in-window signals for STRIKE.

- [ ] **Step 5: Run decision tests**

Run: `python -m unittest tests.test_decision -v`  
Expected: all decision tests pass.

### Task 3: Sanitized intelligence and commercial truth

**Files:**
- Create: `trigger-system/context/field-intelligence.md`
- Create: `trigger-system/context/play-rules.md`
- Create: `trigger-system/config/commercial-truth.json`
- Modify: `.claude/agents/play-director.md`
- Create: `trigger-system/tests/test_knowledge.py`

- [ ] **Step 1: Write failing safety tests**

```python
def test_blocked_claims_are_explicit(self):
    truth = json.loads(TRUTH.read_text(encoding="utf-8"))
    self.assertIn("audience_size", truth["blocked_claim_categories"])

def test_play_director_has_no_fixed_committee_size(self):
    text = DIRECTOR.read_text(encoding="utf-8").lower()
    self.assertNotIn("5-8", text)
    self.assertNotIn("3-email", text)
```

- [ ] **Step 2: Run tests and verify they fail on the copied fixed-triad/sequence rules**

Run: `python -m unittest tests.test_knowledge -v`  
Expected: failures for fixed committee/sequence language and missing truth register.

- [ ] **Step 3: Distill corpus-backed guidance without contact PII**

The field-intelligence document must include coverage counts and limitations for May (72 calls), July-August (123 calls), Q2, and AE meetings; real objection/pain patterns; what advances conversations; and source provenance. It must not contain phone numbers or personal email addresses.

- [ ] **Step 4: Create the canonical claim register**

Each proof entry must have `id`, `use_cases`, `claim`, `source`, `status`, and `review_after`. Blocked categories and terminology rulings live at the top level. Ambiguous or expired claims are omitted from drafts.

- [ ] **Step 5: Replace copied Play Director constraints with the dynamic v1 contract**

The director must load field intelligence, commercial truth, play rules, and account evidence; infer an unconstrained committee; select an outreach subset; generate one initial draft per eligible contact; label pain certainty; and never promise a missing artifact.

- [ ] **Step 6: Run knowledge safety tests**

Run: `python -m unittest tests.test_knowledge -v`  
Expected: all knowledge tests pass.

### Task 4: Play compiler and draft policy

**Files:**
- Create: `trigger-system/agent/claims.py`
- Create: `trigger-system/agent/play.py`
- Create: `trigger-system/tests/test_play.py`

- [ ] **Step 1: Write failing tests for evidence grades, dynamic committee, US eligibility, and blocked claims**

```python
def test_only_selected_verified_us_contacts_receive_drafts(self):
    play = build_play(self.strike, self.contacts, self.truth, as_of=date(2026, 8, 31))
    self.assertEqual([draft.contact_id for draft in play.drafts], ["us-champion"])

def test_stale_or_mismatched_claim_is_omitted(self):
    play = build_play(self.strike, self.contacts, self.stale_truth, as_of=date(2026, 8, 31))
    self.assertNotIn("3x", play.drafts[0].body)
```

- [ ] **Step 2: Run tests and verify missing implementation**

Run: `python -m unittest tests.test_play -v`  
Expected: import failure for `agent.play`.

- [ ] **Step 3: Implement the minimal compiler**

The deterministic compiler validates an AI-authored play candidate rather than inventing company facts. It enforces contact eligibility, evidence grades, proof matching/expiry, 60-90-word guidance, no banned phrases, and stable draft idempotency keys.

- [ ] **Step 4: Run play tests**

Run: `python -m unittest tests.test_play -v`  
Expected: all play tests pass.

### Task 5: Safe provider boundaries

**Files:**
- Create: `trigger-system/agent/providers.py`
- Create: `trigger-system/scripts/publish-outlook-drafts.ps1`
- Modify: `trigger-system/scripts/zoominfo-enrich.ps1`
- Create: `trigger-system/tests/test_providers.py`

- [ ] **Step 1: Write failing provider-contract tests**

```python
def test_outlook_payload_contains_save_not_send_contract(self):
    payload = draft_payload(self.play)
    self.assertEqual(payload["action"], "save_draft")
    self.assertNotIn("send", payload)

def test_zoominfo_request_requires_strike_and_unsuppressed_domain(self):
    with self.assertRaises(PolicyError):
        zoominfo_request(self.watch_account)
```

- [ ] **Step 2: Run tests and verify missing implementation**

Run: `python -m unittest tests.test_providers -v`  
Expected: import failure for `agent.providers`.

- [ ] **Step 3: Implement payload schemas and idempotency**

ZoomInfo requests contain company domain plus AI-selected role hypotheses and never run for suppressed/non-STRIKE accounts. Outlook payloads contain recipient, subject, body, evidence receipt, idempotency key, and `action: save_draft`.

- [ ] **Step 4: Implement PowerShell Outlook adapter**

Default mode validates and reports the drafts it would create. `-Execute` may call Outlook COM `CreateItem(0)`, assign `To`, `Subject`, and `Body`, and call `Save()`. The script must contain no `.Send()` call.

- [ ] **Step 5: Make ZoomInfo suppression provider-neutral**

Replace the copied dependency on `staging\hubspot\suppression.csv` with `config\suppression-baseline.csv` plus an optional ignored `staging\suppression-local.csv`. Preserve credit caps and the existing API credential boundary.

- [ ] **Step 6: Run provider tests and a PowerShell dry-run**

Run: `python -m unittest tests.test_providers -v`  
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\publish-outlook-drafts.ps1 -InputPath fixtures\monday\drafts.json -DryRun`  
Expected: tests pass; script reports draft count and creates no Outlook items.

### Task 6: Monday orchestration and fixture dry run

**Files:**
- Create: `trigger-system/agent/pipeline.py`
- Create: `trigger-system/agent/cli.py`
- Create: `trigger-system/scripts/ai-gtm.ps1`
- Create: `trigger-system/fixtures/monday/candidates.jsonl`
- Create: `trigger-system/fixtures/monday/signals.jsonl`
- Create: `trigger-system/fixtures/monday/contacts.jsonl`
- Create: `trigger-system/tests/test_pipeline.py`

- [ ] **Step 1: Write a failing fixture end-to-end test**

```python
def test_fixture_run_builds_one_strike_and_one_draft_payload(self):
    result = run_fixture(FIXTURES, self.temp_dir, as_of=date(2026, 8, 31))
    self.assertEqual(result.strike_count, 1)
    self.assertEqual(result.draft_count, 1)
    self.assertTrue((self.temp_dir / "digest.md").exists())
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `python -m unittest tests.test_pipeline -v`  
Expected: import failure for `agent.pipeline`.

- [ ] **Step 3: Implement checkpointed fixture orchestration**

Each stage writes an atomic receipt containing run ID, input hash, status, counts, and output path. A repeated run with the same inputs reuses completed stages and does not duplicate draft payloads.

- [ ] **Step 4: Implement the operator wrapper**

`scripts\ai-gtm.ps1 -DryRun -Fixture` runs the complete local path. Live provider flags remain separate and opt-in.

- [ ] **Step 5: Run the pipeline test and dry-run twice**

Run: `python -m unittest tests.test_pipeline -v`  
Run twice: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ai-gtm.ps1 -DryRun -Fixture`  
Expected: all tests pass; second run reports checkpoint reuse and no duplicate draft.

### Task 7: Operator documentation, cleanup, and shipping verification

**Files:**
- Modify: `README.md`
- Modify: `trigger-system/CLAUDE.md`
- Create: `trigger-system/runbooks/setup.md`
- Create: `trigger-system/runbooks/monday-run.md`
- Create: `trigger-system/scripts/verify-v1.ps1`

- [ ] **Step 1: Document setup and exact safe commands**

Document the environment-variable names, suppression regeneration, fixture dry run, live ZoomInfo enrichment, Outlook draft creation, checkpoints, holds, and recovery. State that no prospect mail is sent automatically.

- [ ] **Step 2: Remove active HubSpot, Teams, OneDrive, Clay, and reply-monitoring paths from the new CLAUDE operating rules**

Historical research may remain clearly labelled as non-runtime reference. Active scripts and runbooks must not call excluded services.

- [ ] **Step 3: Add a verification script**

The script runs the full Python suite, scans active files for excluded runtime dependencies and `.Send(`, runs the fixture twice, validates the 648 unique-domain baseline, verifies no Git remote points to the original, and compares the stored original-project fingerprint.

- [ ] **Step 4: Run fresh full verification**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-v1.ps1`  
Expected: zero failed tests; 648 unique suppression domains; idempotent fixture run; no send path; original fingerprint unchanged.

- [ ] **Step 5: Review the implementation against every shipping criterion in the design**

Record any live-only prerequisites separately. Do not call the system shipped if deterministic verification fails.

- [ ] **Step 6: Commit the implementation**

```powershell
git add -A
git commit -m "feat: ship open-market STRIKE agent v1"
```

