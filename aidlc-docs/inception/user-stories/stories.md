# User Stories - Three-Week MVP

## About This File

- **Project**: BOM Validation and Anomaly Detection
- **Version**: 1.6 - Final UI-Aligned Candidate
- **Date**: 2026-07-21
- **Scope**: Three-week prototype
- **Priorities**: Must Have, Should Have, and Could Have
- **Resiliency extension**: Not included

The Must Have stories form the smallest complete prototype represented by the
evaluator-approved `final.html`. Should Have and Could Have stories can be deferred if
time is short. The FR and NFR identifiers link each story to the approved requirements.

## Must Have

### US-001 - Ingest BOM Data Through OIC

**Story**: As an Integration Administrator, I want OIC to ingest live Fusion PLM
data or an approved PLM-shaped mock payload, so that the prototype uses realistic
multi-level BOM data through the intended integration boundary.

**Requirements**: FR-001, FR-002, FR-003, FR-004, FR-039, NFR-001, NFR-005, NFR-009

**Acceptance Criteria**:

- [ ] OIC processes live Fusion PLM data or an approved mock payload through the same canonical ingestion contract.
- [ ] ATP stores every supplied BOM header, parent-child relationship, BOM level, and required validation attribute.
- [ ] Each ingestion run records a unique identifier, source mode, timestamps, status, counts, and actionable errors.
- [ ] An Administrator can click Refresh beside Run Validation to pull refreshed BOM data from PLM through OIC.
- [ ] After a successful refresh, the dashboard and BOM detail data reload from ATP using the refreshed latest BOM structure.
- [ ] If refresh fails, prior dashboard data remains usable and the failure is logged with a correlation ID.
- [ ] The prototype processes a few hundred BOMs without a hardcoded ten-record limit.
- [ ] Invalid or incomplete input fails safely and does not start validation on an incomplete dataset.
- [ ] External calls use configured timeouts and bounded retry behavior.
- [ ] Errors and logs do not expose passwords, access keys, tokens, or other secrets.
- [ ] Arbitrary direct file upload is not required; mock data follows the OIC-processed PLM-shaped payload boundary.

### US-002 - Detect Deterministic BOM Problems

**Story**: As a Business Reviewer, I want the system to detect known BOM data-quality and
structural problems, so that I can correct risky data before release.

**Requirements**: FR-007, FR-008, FR-009, FR-010, FR-011, FR-012, FR-013

**Acceptance Criteria**:

- [ ] A blank UOM produces a Critical Missing UOM finding with BOM, parent, component, and field evidence.
- [ ] A null, zero, or negative quantity produces a High Invalid Quantity finding showing the received value.
- [ ] An exact duplicate relationship produces a Warning finding identifying the duplicate rows.
- [ ] A configured obsolete component in an active or released BOM produces a High finding showing both lifecycle states.
- [ ] An effectivity end date earlier than its start date produces a High finding showing both dates.
- [ ] A loop such as A contains B, B contains C, and C contains A produces a Critical finding showing the complete cycle path.
- [ ] Validation evaluates the complete staged multi-level structure and never changes Oracle Fusion PLM data.
- [ ] Rule findings remain review aids and do not claim that every flagged relationship is automatically wrong.

### US-003 - Identify Quantity Anomalies and Explain Health

**Story**: As a Business Reviewer, I want to see unusual quantities and a transparent BOM
health score, so that I can understand why a BOM may be risky.

**Requirements**: FR-014, FR-015, FR-016

**Acceptance Criteria**:

- [ ] A positive quantity outside its configured threshold produces an anomaly showing the observed value, threshold, and comparison source.
- [ ] A positive quantity inside its configured threshold does not produce a quantity anomaly.
- [ ] Each BOM health score remains between 0 and 100.
- [ ] The score view exposes every unresolved finding and deduction contributing to the current score.
- [ ] Users can distinguish deterministic findings from the score derived from them.

### US-004 - Run On-Demand Validation for One BOM

**Story**: As an Administrator, I want to validate one
selected BOM on demand, so that I can check it before release.

**Requirements**: FR-006

**Acceptance Criteria**:

- [ ] An Administrator can select one BOM and start validation only for that BOM.
- [ ] The system persists the results as a new validation run.
- [ ] Results identify the selected BOM, initiating user, trigger type, and execution time.
- [ ] The system rejects requests from users who lack the required permission.

### US-005 - Find and Inspect Risky Multi-Level BOMs

**Story**: As a Business Reviewer, I want a dashboard and multi-level BOM detail view, so
that I can find risky BOMs and inspect their nested components and findings.

**Requirements**: FR-022, FR-023, FR-024, NFR-002, NFR-003

**Acceptance Criteria**:

- [ ] VBCS obtains dashboard and detail data through authenticated ORDS APIs over ATP.
- [ ] The dashboard distinguishes healthy and risky BOMs.
- [ ] The dashboard shows top risky BOMs, open findings, counts by severity, and available health by item class.
- [ ] Rule metadata and rule filtering are available through the Rules and Finding Review views.
- [ ] Selecting a BOM opens a parent-child view containing every supplied level and associated finding.
- [ ] Each row identifies its parent item, component item, BOM level, and supporting finding evidence.
- [ ] Dashboard lists use pagination or incremental retrieval rather than an unrestricted full-data load.
- [ ] Labels and evidence use plain language and support the dashboard-to-detail journey.
- [ ] Dashboard requests do not repeatedly call Oracle Fusion PLM.

### US-006 - Review Findings and Retain History

**Story**: As a Business Reviewer, I want to review findings and compare validation
history, so that I can track what was examined or ignored.

**Requirements**: FR-018, FR-019, FR-020, FR-021, NFR-004

**Acceptance Criteria**:

- [ ] A Business Reviewer can manually set a finding to Open, Reviewed, or Ignored.
- [ ] Resolved may appear as a loaded/current data state, but is not a manual review option in the final UI.
- [ ] The system rejects a change to Ignored unless the reviewer provides a non-empty comment.
- [ ] Every status change stores the previous status, new status, user, comment, and timestamp.
- [ ] A reviewer can compare at least two validation runs for the same BOM and distinguish historical findings, score, review activity, and run metadata from the current state.
- [ ] The MVP retains enough run and finding history to demonstrate a previously failing BOM becoming clean.
- [ ] The interface states that findings require human review.

### US-007 - Explain Findings with Advisory AI

**Story**: As a Business Reviewer, I want plain-language AI
explanations and suggested actions, so that I can understand findings without
treating AI as the decision-maker.

**Requirements**: FR-027, FR-028, FR-029, FR-030, FR-031, NFR-003, NFR-007, NFR-009

**Acceptance Criteria**:

- [ ] A user can request a plain-language explanation for a saved deterministic finding.
- [ ] A user can request a BOM-level Advisory AI summary from the BOM Detail page using stored findings and health-score evidence.
- [ ] AI may suggest a corrective action but does not select an authoritative substitute or make a business decision.
- [ ] Every AI output is labeled `Advisory AI`, linked to its source evidence, and visually separated from validation rules.
- [ ] AI output is treated as untrusted, reviewable content and cannot execute commands or alter authoritative data.
- [ ] Deterministic results, scores, history, and review remain usable when the AI service is unavailable.
- [ ] AI calls use configured timeouts and bounded retry behavior, and failures are logged with a correlation identifier.
- [ ] No AI explanation, summary, suggestion, or generated comment is written to Oracle Fusion PLM.

### US-008 - Administer and Support the Prototype Safely

**Story**: As an Administrator, I want controlled
access, readable rule details, and useful diagnostics, so that I can safely operate
and troubleshoot the prototype.

**Requirements**: FR-032, FR-033, FR-035, NFR-005, NFR-006, NFR-008, NFR-009

**Acceptance Criteria**:

- [ ] Administrator and Business Reviewer permissions expose only their approved actions.
- [ ] User, OIC, ORDS, ATP, and AI interfaces authenticate and enforce least privilege.
- [ ] Rule details show stable identifiers, names, descriptions, severity, enabled status, and applicable thresholds.
- [ ] Inputs are validated, outputs are safely encoded, and users cannot access unauthorized BOMs or administrative actions.
- [ ] Correlated logs identify the failed integration, validation, API, or AI operation, processing stage, timestamp, terminal status, and safe diagnostic detail.
- [ ] Logs capture applicable latency, error-rate, throughput, and saturation metrics.
- [ ] External operations use explicit timeouts and bounded retries.
- [ ] Logs and screen errors redact passwords, access keys, tokens, and sensitive payload content.
- [ ] An Administrator can diagnose a failed run without direct unrestricted database access.

### US-009 - Demonstrate the Complete Prototype

**Story**: As a Project Stakeholder, I want a customer-reviewed dataset and
end-to-end demonstration, so that I can confirm the prototype delivers the agreed
value.

**Requirements**: FR-036, FR-037

**Acceptance Criteria**:

- [ ] The acceptance dataset contains a healthy BOM and a multi-level BOM.
- [ ] It contains an example for every deterministic rule shown in the final UI rule catalog.
- [ ] It contains one circular-reference case and one threshold-based quantity anomaly.
- [ ] The prototype produces each expected finding with understandable evidence.
- [ ] The demonstration covers OIC ingestion, UI refresh through OIC, dashboard, BOM detail, BOM-level Advisory AI summary, findings, review, history, integration diagnostics, and at least one selected-finding Advisory AI explanation.
- [ ] The demonstration performs no automatic Oracle Fusion PLM update.

### US-010 - Run Daily Scheduled Validation

**Story**: As an Administrator, I want validation to run once each day,
so that BOM risks are checked regularly without manual initiation.

**Requirements**: FR-005

**Acceptance Criteria**:

- [ ] An approved configuration defines the daily validation time; a configuration UI is not required.
- [ ] The configured schedule creates one validation run each day without manual initiation.
- [ ] The system persists the results and trigger type for every daily run.
- [ ] The Administrator can determine whether each daily run completed or failed.
- [ ] Daily scheduled validation is part of the Must Have MVP acceptance scope.

## Should Have

### US-011 - Filter and Sort Results

**Story**: As a Business Reviewer, I want to filter and sort BOMs and
findings, so that I can focus on the most relevant results.

**Requirements**: FR-025

**Acceptance Criteria**:

- [ ] A user can filter supported results by health, severity, rule, status, and item class when those values are available.
- [ ] A user can sort supported columns in ascending or descending order.
- [ ] Active filters remain applied when the sort order changes.

### US-012 - Apply the Configurable Health-Score Formula

**Story**: As a Business Reviewer, I want the health score to use an agreed,
configurable severity formula, so that its result is consistent and explainable.

**Requirements**: FR-017

**Acceptance Criteria**:

- [ ] The formula starts at 100 and floors the result at 0.
- [ ] Approved defaults deduct 25 points per Critical, 10 per High, and 5 per Warning finding.
- [ ] Open and Reviewed findings reduce the current score.
- [ ] Ignored and Resolved findings do not reduce the current score; Resolved is stored or displayed only when supplied by source/current data or system reconciliation.
- [ ] The displayed calculation identifies the formula version, weights, findings, and deductions.

## Could Have

### US-013 - Show the BOM as a Tree

**Story**: As a Business Reviewer, I want to expand and collapse a BOM
tree, so that I can navigate nested parts more easily.

**Requirements**: FR-026

**Acceptance Criteria**:

- [ ] A user can expand and collapse each available BOM level.
- [ ] Components with findings remain clearly marked in the tree.
- [ ] The required parent-child representation remains available if the tree is not delivered.
- [ ] Tree visualization does not delay any Must Have story.

### US-014 - Add Prototype Rule Logic in the UI

**Story**: As an Administrator, I want a controlled prototype screen for adding logic
rule metadata, so that the evaluator can see how rules would be administered.

**Requirements**: FR-034

**Acceptance Criteria**:

- [ ] An Administrator can open the Add New Logic Rule modal.
- [ ] The prototype captures rule name, description, and severity fields at UI depth.
- [ ] Full persistence and production rule governance may remain future work unless implemented.
- [ ] A Business Reviewer cannot modify rule settings.
- [ ] Controlled ATP or deployment configuration remains acceptable if this optional screen is not delivered.

## Candidate Validation Summary

- **INVEST review**: Stories express user value, remain negotiable within the approved Oracle boundaries, are estimable at prototype depth, and contain testable acceptance criteria. Capability stories are independently reviewable; US-009 intentionally verifies the integrated acceptance journey.
- **Story count**: 14 total - 10 Must Have, 2 Should Have, and 2 Could Have.
- **Functional traceability**: Final UI-aligned active FRs are mapped; FR-038 is deferred unless reintroduced.
- **Non-functional traceability**: NFR-001 through NFR-009 are mapped.
- **MVP boundary**: Mock payloads use OIC; arbitrary file upload remains deferred.
- **Human control**: Findings and AI output remain advisory and reviewable.
- **Priority alignment**: Daily validation is Must; score-formula defaults are Should.
- **Review status**: Candidate corrected and ready for user review; not yet approved as the final AIDLC User Stories artifact.
