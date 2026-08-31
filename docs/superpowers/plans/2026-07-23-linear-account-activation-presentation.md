# Linear Account Activation Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current sideways, email-centric presentation with a single vertical, evidence-based account activation strategy from LinkedIn signal to Clay, SDR activity, qualification, handoff and learning.

**Architecture:** Keep the static HTML, CSS and vanilla JavaScript stack. Replace the page structure and styles instead of incrementally patching the current grid-heavy layout. Preserve the three supplied screenshots and the useful query-copy interaction.

**Tech Stack:** HTML5, CSS3, vanilla JavaScript, PowerShell smoke tests and headless Chrome.

---

### Task 1: Write the new content contract

**Files:**
- Modify: `tests/presentation-smoke.ps1`

- [ ] **Step 1: Add failing assertions**

Require markers for:

```text
A comment is a signal, not a converted lead.
Clay prepares the record. The SDR works the account.
CRM ownership
work email and phone
SDR-ready brief
call opener
LinkedIn touch
account director
nurture
Northstar Cloud
Illustrative account
Research basis
```

Forbid:

```text
Databricks
What would make this strategy commercially useful
How a disclosed business problem could lead to
assumption-table
conflict-table
machine-flow
```

Assert that every main process component appears after the previous component in the HTML source and that all three supplied image paths remain present.

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\presentation-smoke.ps1
```

Expected: FAIL because the existing presentation contains Databricks and the removed table and does not include the SDR-ready, multi-touch account model.

### Task 2: Rebuild the HTML narrative

**Files:**
- Modify: `index.html`

- [ ] **Step 1: Replace the page shell**

Remove the fixed navigation rail and all wide grid/table structures. Add a compact top header and a centered `<main>` with sections ordered according to the design spec.

- [ ] **Step 2: Add the complete operating model**

Create one ordered vertical list covering:

```text
discussion → comment → account → CRM → Clay → SDR → multi-touch → qualification → handoff → outcome
```

Each item must state the owner, input, action and output in plain language.

- [ ] **Step 3: Add the evidence section**

Keep all three screenshots uncropped. Quote only wording visible in the images. Explain what each comment supports and what it does not establish.

- [ ] **Step 4: Add the Clay workflow**

Describe webhook or CSV intake, company and role resolution, CRM lookup, waterfall enrichment, research context, SDR brief generation, CRM upsert and sequence routing. Link to official Clay documentation.

- [ ] **Step 5: Add the SDR and sales workflow**

Show the SDR-ready brief, the proposed day-by-day email/call/LinkedIn cadence, reply qualification, account-director handoff and nurture/recycle outcomes.

- [ ] **Step 6: Add the illustrative worked example**

Use fictional Northstar Cloud. Show the raw signal, verification, Clay record, first email, call opener, proof follow-up, second stakeholder decision, qualification and outcome paths. Label every fictional field and outcome as illustrative.

- [ ] **Step 7: Add proof and research**

Retain the verified AWS and Todyl proof. Add a research appendix linking to Unbound IA, Clay, Gong and 6sense sources. Keep source claims narrow and attributable.

- [ ] **Step 8: Add the pilot**

Show a discovery-yield phase followed by controlled activation. Do not invent conversion targets. Include operational, engagement and pipeline measures in a vertical list.

### Task 3: Build the linear visual system

**Files:**
- Modify: `styles.css`

- [ ] **Step 1: Replace grid-heavy styles**

Create a centered single-column layout. Use one vertical `.signal-spine` with connected `.spine-step` cards. Avoid horizontal overflow and multi-column pathways.

- [ ] **Step 2: Style evidence and record states**

Use consistent visual states:

```text
Observed → neutral blue
Verified → green
Needs review → amber
Illustrative → dashed outline
```

- [ ] **Step 3: Preserve screenshots**

Use:

```css
.evidence-image img {
  width: 100%;
  height: auto;
  object-fit: contain;
}
```

- [ ] **Step 4: Add responsive and accessible behavior**

At widths below 760px, reduce spacing and type sizes without changing information order. Add visible focus states and reduced-motion behavior.

### Task 4: Keep interactions small and useful

**Files:**
- Modify: `script.js`

- [ ] **Step 1: Remove rail-navigation logic**

Delete code that depends on the removed side navigation.

- [ ] **Step 2: Preserve query copy**

Keep copy buttons for advanced Google queries with a fallback when `navigator.clipboard` is unavailable.

- [ ] **Step 3: Add reading progress**

Update a minimal progress indicator based on document scroll without changing content or navigation.

### Task 5: Verify GREEN

**Files:**
- Test: `tests/presentation-smoke.ps1`
- Inspect: `index.html`
- Inspect: `styles.css`
- Inspect: `script.js`

- [ ] **Step 1: Run the smoke test**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\presentation-smoke.ps1
```

Expected: PASS.

- [ ] **Step 2: Validate syntax and structure**

Run an HTML parser check for unique IDs, valid image paths and section order. Run:

```powershell
node --check .\script.js
```

Expected: exit code 0.

- [ ] **Step 3: Scan for forbidden content**

Search for Databricks, the removed headings, wide-table classes, product language, placeholder content and unsupported claims.

Expected: no matches except the explicit forbidden-marker strings inside the test file.

- [ ] **Step 4: Render desktop and mobile**

Render the page in headless Chrome at 1440px and 390px widths. Inspect the screenshots for horizontal scrolling, clipped screenshots, broken process lines, unreadable code and accidental multi-column pathways.

- [ ] **Step 5: Re-run every check**

Run the smoke test, parser check, CSS checks and JavaScript syntax check after visual fixes.

Expected: all pass with zero errors.
