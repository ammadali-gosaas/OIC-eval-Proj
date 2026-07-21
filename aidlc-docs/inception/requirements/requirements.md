# Functional Requirements Document

## Document Control

- **Project**: BOM Validation and Anomaly Detection
- **Document ID**: FRD-BOM-001
- **Version**: 1.1 Final UI-Aligned Draft
- **Date**: 2026-07-21
- **AI-DLC Phase**: INCEPTION
- **AI-DLC Stage**: Requirements Analysis - Requirements Elaboration
- **Requirements Depth**: Comprehensive
- **Approval Status**: Requirements Gate Passed - Unblocked and Ready
- **Primary Sources**: `final.html`, `Customer Requirement Discovery Call Transcript.pdf`,
  `requirement-verification-questions.md`, and project decisions recorded in
  `aidlc-docs/audit.md`

## 1. Purpose

This document defines the functional scope for a three-week MVP that identifies
data-quality, structural, and quantity-anomaly risks in engineering bills of
material before release. It also defines the human-review and advisory-AI
boundaries required to help engineers understand and act on findings without
automatically modifying Oracle Fusion PLM.

## 2. Intent Analysis

- **Request type**: New greenfield project
- **Scope estimate**: Cross-system MVP spanning integration, persistence, REST
  services, validation, anomaly detection, user interface, and advisory AI
- **Complexity estimate**: Moderate to complex
- **Delivery constraint**: Approximately three weeks
- **Primary business goal**: Detect risky engineering BOMs before they create
  downstream planning, costing, procurement, or manufacturing problems.
- **Verified MVP decision**: Deliver an end-to-end Oracle-pattern prototype using
  OIC, ATP, ORDS, and VBCS. Live Fusion PLM data is preferred, but realistic mock
  PLM payloads are an accepted fallback if access is blocked.

## 3. Stakeholders and Source Catalog

| Source ID | Stakeholder | Role | Relevant authority or evidence |
| --- | --- | --- | --- |
| SRC-01 | Sarah Khan | Customer PLM Manager | Phase-one scope, pre-release validation, dashboard, severity, scoring, scheduling, roles, demo, and delivery expectations |
| SRC-02 | David Lee | Customer Manufacturing Systems Lead | Downstream impact, quantity anomalies, multi-level display, circular references, manual validation, and review needs |
| SRC-03 | Rohit Mehta | Customer IT Integration Lead | OIC, ATP, ORDS, VBCS, integration pattern, logging, roles, scale, and mock-data fallback |
| SRC-04 | Maria Gomez | Customer Product Data Governance Lead | Validation examples, history, issue governance, AI explanations, recommendations, and explainability |
| SRC-05 | Amjad | Solution Architect | Discovery framing and consolidated solution summary endorsed by Sarah Khan |

## 4. Actors

- **Business Reviewer**: Views BOM health and issues, reviews findings, changes
  allowed review statuses, and requests Advisory AI explanations.
- **Administrator**: Runs validation, views logs, manages readable rule metadata and
  prototype rule controls available in the MVP, refreshes PLM data through OIC,
  reviews findings, and requests Advisory AI explanations.
- **OIC Integration**: Retrieves or receives PLM-shaped BOM data and loads it into
  ATP.
- **Scheduler**: Initiates the daily validation run.
- **Advisory AI Service**: Produces labeled BOM-level summaries, selected-finding
  explanations, and suggested corrective actions; it is never authoritative.

## 5. Scope

### 5.1 In Scope

- Engineering BOMs before approval or downstream release
- Multi-level parent-child structures
- Fusion PLM-shaped ingestion orchestrated by OIC
- ATP staging, reporting, result, history, AI-output, and log persistence
- ORDS REST APIs consumed by VBCS
- Daily and selected-BOM validation triggers
- Six deterministic validation rules and one explainable quantity anomaly rule shown
  in the final UI rule catalog
- Transparent BOM health scoring
- Dashboard, BOM detail, issue review, run history, and integration diagnostics
- Advisory AI BOM-level summaries, selected-finding explanations, and suggested actions
- Basic Administrator and Business Reviewer role separation
- Customer-reviewed MVP demo and acceptance dataset

### 5.2 Out of Scope for the MVP

| Exclusion ID | Testable boundary | Source | Classification |
| --- | --- | --- | --- |
| EX-001 | The solution must not automatically update BOM structures, revisions, substitutes, lifecycle state, or other authoritative PLM data. | SRC-01, SRC-04 | Won't |
| EX-002 | AI output must not be written to Fusion PLM during the MVP. | SRC-04 | Won't |
| EX-003 | Email notifications, workflow notifications, and approval workflow automation are not delivered. | SRC-01, SRC-03 | Won't |
| EX-004 | Enterprise-grade production readiness or a production SLA is not claimed by this prototype. | SRC-01, SRC-03 | Won't |
| EX-005 | Complex or black-box machine-learning models are not used. | SRC-01, SRC-04 | Won't |

### 5.3 Deferred

| Deferred ID | Capability | Source | Target |
| --- | --- | --- | --- |
| DEF-001 | Manufacturing BOM support | SRC-01 | Post-MVP |
| DEF-002 | File upload or arbitrary external extract ingestion beyond an OIC-processed PLM-shaped payload | SRC-03 | Post-MVP |
| DEF-003 | Tree-style BOM visualization beyond a usable multi-level parent-child representation | SRC-02 | If time permits or post-MVP |
| DEF-004 | Full rule authoring and configuration UI | SRC-01, SRC-04 | Post-MVP unless it does not delay core scope |
| DEF-005 | Numeric production-scale performance, availability, RTO, and RPO commitments | SRC-01, SRC-03 | Production planning |
| DEF-006 | Generic Missing Required Field rule beyond UOM and quantity | Prior requirements recovery, superseded by `final.html` | Future UI revision if reintroduced |

## 6. MoSCoW Baseline

- **Must**: Required for the verified end-to-end MVP and its acceptance journey.
- **Should**: Valuable for usability or support but may be simplified without
  invalidating the MVP.
- **Could**: Included only if it does not threaten the three-week Must scope.
- **Won't**: Explicitly excluded from this MVP; see Section 5.2.

The Must baseline is justified by the stakeholder-endorsed solution summary and
recorded project decisions. Feasibility remains conditional on timely platform access,
customer-reviewed sample data, and availability of the selected AI service. The
accepted fallback is an OIC-processed realistic mock PLM payload.

## 7. Functional Requirements and Traceability

### 7.1 Integration and Staging

| ID | Requirement | Priority | Source | Validation status |
| --- | --- | --- | --- | --- |
| FR-001 | OIC must ingest engineering BOM structures from Fusion PLM or, when live access is blocked, process realistic mock payloads with the same canonical contract. | Must | SRC-01, SRC-03 | Verified |
| FR-002 | The ingestion flow must persist BOM headers, multi-level component relationships, item attributes needed by validation, and ingestion metadata in ATP before validation. | Must | SRC-03, SRC-05 | Verified |
| FR-003 | The persisted representation must preserve parent-child relationships across all supplied BOM levels and must not impose a one-level-only limit. | Must | SRC-01, SRC-02, SRC-03 | Verified |
| FR-004 | Each integration run must have a unique run identifier, start and end timestamps, status, source mode, record counts, and actionable error details. | Must | SRC-03 | Verified |
| FR-039 | The BOM Detail or dashboard action area must provide an Administrator refresh action next to Run Validation. The action must call OIC to pull refreshed BOM data from Fusion PLM or the approved mock source, persist the refreshed latest BOM structure in ATP, record an integration run, and refresh dashboard/detail data from ATP. | Must | User clarification, final UI update | Approved |

### 7.2 Validation Execution

| ID | Requirement | Priority | Source | Validation status |
| --- | --- | --- | --- | --- |
| FR-005 | The system must start one scheduled validation run each day; the exact execution time is `TBD` configuration. | Must | SRC-01 | Verified |
| FR-006 | An Administrator must be able to start validation on demand for one selected BOM. | Must | SRC-01, SRC-02, final UI | Verified |
| FR-007 | Every validation run must evaluate the complete staged multi-level structure in scope and persist its outcome without changing PLM. | Must | SRC-01, SRC-02, SRC-04 | Verified |

### 7.3 Deterministic Validation Rules

The MVP uses the transcript-backed and user-confirmed deterministic rule set. Rule
results are authoritative application findings; AI output is not part of rule
evaluation.

| ID | Requirement and evaluation semantics | Default severity | Priority | Source | Validation status |
| --- | --- | --- | --- | --- | --- |
| FR-008 | The system must create a Missing UOM finding when a component relationship's required UOM value is null, empty, or whitespace. Evidence must identify the BOM, parent, component, and missing field. | Critical | Must | SRC-01, SRC-04 | Verified |
| FR-009 | The system must create an Invalid Quantity finding when the component quantity is null, zero, or negative. Evidence must show the received quantity. | High | Must | SRC-01, SRC-04 | Approved at Requirements Gate |
| FR-010 | The system must create an Exact Duplicate finding when more than one relationship has the same normalized parent item, component item, operation sequence including null, and effectivity start and end values including null. Evidence must identify the duplicate rows. | Warning | Must | SRC-01, SRC-02, SRC-04 | Approved at Requirements Gate |
| FR-011 | The system must create an Obsolete Component finding when a component's staged lifecycle status matches a configured obsolete-status value while the parent BOM is active or released. Evidence must show both statuses. | High | Must | SRC-01, SRC-04 | Approved; status configuration remains implementation input |
| FR-012 | The system must create an Invalid Effectivity finding when both dates exist and the relationship end date is earlier than its start date. Evidence must show both dates. | High | Must | SRC-01, SRC-04 | Approved at Requirements Gate |
| FR-013 | The system must traverse the staged BOM graph and create a Circular Reference finding when a path returns to an item already present in that path. Evidence must show the complete cycle path. | Critical | Must | SRC-02, SRC-03 | Verified |
Default severities and the normalized duplicate key were implementation-team
proposals confirmed by the user for the MVP during Requirements Analysis.

### 7.4 Explainable Anomaly Detection and Health Score

| ID | Requirement | Priority | Source | Validation status |
| --- | --- | --- | --- | --- |
| FR-014 | The system must flag a Quantity Anomaly when a positive component quantity violates the configured lower or upper threshold for its component or item class. | Must | SRC-01, SRC-02, SRC-04 | Verified |
| FR-015 | Each anomaly must show the observed quantity, applicable threshold, comparison group or configuration source, and reason it was flagged. | Must | SRC-02, SRC-04 | Verified |
| FR-016 | The system must calculate a transparent health score from 0 to 100 using unresolved issue severities and must expose every deduction contributing to the score. | Must | SRC-01, SRC-04 | Verified |
| FR-017 | The score formula should start at 100, subtract configurable points per Open or Reviewed finding, and floor the result at 0; approved defaults are 25 per Critical, 10 per High, and 5 per Warning finding. Ignored and Resolved findings do not reduce the current score. | Should | SRC-01, SRC-04 | Approved at Requirements Gate |

### 7.5 Results, History, and Human Review

| ID | Requirement | Priority | Source | Validation status |
| --- | --- | --- | --- | --- |
| FR-018 | The system must persist validation runs, findings, severity, evidence, score details, review history, and timestamps so users can compare historical and current BOM health. The prototype stores the latest BOM structure, but retains run/finding/review history for comparison. | Must | SRC-03, SRC-04, final UI | Verified |
| FR-019 | Findings must support Open, Reviewed, Ignored, and Resolved as data states, but the final UI only allows manual review changes to Open, Reviewed, and Ignored. Resolved may appear from PLM/current data or system reconciliation and is not manually selectable by reviewers in this prototype. | Must | SRC-01, final UI | Verified |
| FR-020 | A user must provide a non-empty comment before changing a finding to Ignored; the system must store the user and timestamp for every status change. | Must | SRC-04 | Verified |
| FR-021 | A finding must remain a review aid and must not be treated as proof that the underlying BOM relationship is wrong. | Must | SRC-02, SRC-04 | Verified |

### 7.6 Dashboard and APIs

| ID | Requirement | Priority | Source | Validation status |
| --- | --- | --- | --- | --- |
| FR-022 | ORDS must expose authenticated REST APIs over ATP data for the VBCS application; VBCS must not query Fusion PLM directly for dashboard use. | Must | SRC-03 | Verified |
| FR-023 | The VBCS landing dashboard must distinguish healthy and risky BOMs and show top risky BOMs, issue counts by severity, open issues, and available health-by-item-class information. Rule visibility and rule-based filtering are provided through the Rules and Finding Review views. | Must | SRC-01, SRC-04, final UI | Verified |
| FR-024 | From the dashboard, a user must be able to open a BOM detail view showing its multi-level parent-child relationships and associated findings. | Must | SRC-02 | Verified |
| FR-025 | The user should be able to filter or sort BOMs and findings by health, severity, rule, status, and item class when the underlying value is available. | Should | SRC-01, SRC-04 | Approved at Requirements Gate |
| FR-026 | A tree-style BOM view may be delivered if it does not delay the Must scope; a usable multi-level parent-child table satisfies the MVP. | Could | SRC-02 | Verified |

### 7.7 Advisory AI

| ID | Requirement | Priority | Source | Validation status |
| --- | --- | --- | --- | --- |
| FR-027 | On request, AI must explain a selected finding in plain business language and may suggest a corrective action without selecting an authoritative substitute or making a business decision. | Must | SRC-01, SRC-04 | Verified |
| FR-028 | From the BOM Detail page, AI must be able to summarize the overall risk of the selected BOM using its deterministic findings and health-score evidence. | Must | SRC-02, SRC-04, final UI | Verified |
| FR-029 | Every AI output must be labeled `Advisory AI`, stored only in ATP, linked to its input finding or run, and visually separated from approved validation rules. | Must | SRC-03, SRC-04 | Verified |
| FR-030 | If AI is unavailable, deterministic rule results, score evidence, history, and review functions must remain usable; the failure must be logged without failing the completed rule run. | Must | SRC-01, SRC-04 | Verified clarification |
| FR-031 | No AI explanation, summary, recommendation, or generated comment may be written to Fusion PLM in the MVP. | Must | SRC-01, SRC-04 | Verified |

### 7.8 Access, Rules, and Supportability

| ID | Requirement | Priority | Source | Validation status |
| --- | --- | --- | --- | --- |
| FR-032 | The application must distinguish Administrator and Business Reviewer permissions. Administrators may run validation and manage supported rule configuration; Business Reviewers may view BOMs and review findings. | Must | SRC-03 | Verified |
| FR-033 | The system must expose readable rule names, descriptions, severity, enabled status, and threshold values where applicable. | Must | SRC-01, SRC-04 | Verified |
| FR-034 | The Rules view may include prototype-level Administrator rule creation or configuration controls, but full enterprise-grade rule authoring may still be omitted. | Could | SRC-01, SRC-04, final UI | Verified |
| FR-035 | Integration, validation, API, and AI logs must let an Administrator identify the failed run or request, processing stage, time, source mode where applicable, correlation ID, terminal status, and actionable error while avoiding secrets and sensitive payload leakage. | Must | SRC-03, final UI | Verified |

### 7.9 MVP Acceptance

| ID | Requirement | Priority | Source | Validation status |
| --- | --- | --- | --- | --- |
| FR-036 | The MVP must be evaluated with a customer-reviewed dataset containing at least one healthy BOM, one multi-level BOM, one example for each deterministic rule, one circular BOM, and one threshold-based quantity anomaly. | Must | SRC-01, SRC-02, SRC-04 | Verified |
| FR-037 | The acceptance demonstration must complete the journey from ingestion through dashboard, risky-BOM detail, finding evidence, issue review, history, integration logs, and at least one advisory-AI explanation. | Must | SRC-01, SRC-03, SRC-04 | Verified |

## 8. Major Capability Flows

### UC-01 - Ingest BOM Data

- **Actor**: OIC Integration
- **Trigger**: Scheduled or authorized integration invocation
- **Preconditions**: ATP is reachable; a live Fusion PLM response or realistic
  mock payload conforms to the canonical contract.
- **Normal flow**: Create run ID, retrieve or receive data, validate the envelope,
  persist all supplied levels and metadata, record counts, and mark ingestion
  successful.
- **Alternate flow**: If live access is unavailable, process the approved mock
  payload through the same OIC-to-ATP pattern.
- **Failure behavior**: Mark ingestion failed, preserve actionable diagnostics, and
  do not start validation on an incomplete dataset.
- **Output and persisted state**: Staged BOM snapshot and integration-run record.

### UC-01A - Refresh BOM Data from the UI

- **Actor**: Administrator
- **Trigger**: User clicks the Refresh action beside Run Validation.
- **Preconditions**: The user is authorized; OIC and ATP are reachable; Fusion PLM or
  the approved mock source is available.
- **Normal flow**: VBCS sends a refresh request to ORDS, ORDS invokes the OIC refresh
  integration, OIC retrieves refreshed PLM-shaped data, ATP updates the latest BOM
  header and component structure, records an integration run, and the UI reloads
  dashboard/detail data from ATP.
- **Failure behavior**: Preserve the prior usable dashboard data, show a non-sensitive
  failure message, and record correlated diagnostics.
- **Output and persisted state**: Refreshed latest BOM data, integration-run history,
  and redacted diagnostic logs.

### UC-02 - Run Daily Validation

- **Actor**: Scheduler
- **Trigger**: Configured daily schedule
- **Preconditions**: A complete staged dataset exists and validation rules are
  readable and enabled.
- **Normal flow**: Create validation run, traverse each BOM, execute deterministic
  rules and anomaly threshold, persist findings and evidence, calculate scores,
  and complete the run.
- **Failure behavior**: Mark the affected run or BOM failed with diagnostics while
  preserving prior successful results.
- **Output and persisted state**: Validation-run history, findings, evidence, and
  health scores.

### UC-03 - Validate a Selected BOM

- **Actor**: Administrator
- **Trigger**: User selects on-demand validation for one BOM.
- **Preconditions**: The BOM exists in ATP and the user is authorized.
- **Normal flow**: Run all enabled MVP rules against that BOM, persist a new run,
  and refresh its detail and score.
- **Failure behavior**: Show a non-sensitive error and record diagnostic context.
- **Output and persisted state**: A new selected-BOM validation run and results.

### UC-04 - Review a Finding

- **Actor**: Business Reviewer or Administrator
- **Trigger**: User opens a finding and selects a new status.
- **Preconditions**: Finding exists and user is authorized.
- **Normal flow**: Display rule evidence and AI content separately; accept the
  transition; require a comment for Ignored; store user, comment, and timestamp;
  recalculate score if applicable.
- **Failure behavior**: Reject an Ignored transition without a comment and retain
  the prior state.
- **Output and persisted state**: Status-history entry and updated current status.

### UC-05 - Request an AI Explanation

- **Actor**: Business Reviewer
- **Trigger**: User requests a BOM risk summary or an explanation for a selected finding.
- **Preconditions**: Deterministic finding evidence exists.
- **Normal flow**: Send only approved input fields, receive a BOM-level summary or
  selected-finding explanation and suggestion, label it advisory, persist it in ATP,
  and display it separately.
- **Failure behavior**: Retain all deterministic functionality, show that advisory
  content is unavailable, and log the AI failure.
- **Output and persisted state**: Advisory AI record or AI failure event; never a
  PLM update.

## 9. Non-Functional Requirements

| ID | Requirement | Priority | Status |
| --- | --- | --- | --- |
| NFR-001 | The prototype must support a few hundred BOMs and must not contain a hardcoded ten-record processing or display limit. Exact component volume is `TBD`. | Must | Verified from SRC-03 |
| NFR-002 | Dashboard lists must use pagination or incremental retrieval. Numeric response-time targets are `TBD` and observed results must be documented. | Must | Approved at Requirements Gate |
| NFR-003 | The UI must use plain-language labels, expose actionable evidence, and support the dashboard-to-detail-to-review journey without requiring direct database access. | Must | Verified from SRC-01, SRC-02, SRC-04 |
| NFR-004 | Data and log retention periods are `TBD`; the MVP must retain enough history to demonstrate a previously failing BOM becoming clean. | Must | Partially verified from SRC-04 |
| NFR-005 | All user and service interfaces must authenticate; authorization must apply least privilege; traffic and ATP data must be encrypted; secrets must use an approved secret store and must not appear in code or logs. | Must | Mandatory custom security rule |
| NFR-006 | Inputs from OIC, ORDS clients, and AI must be validated; outputs must be encoded; object-level authorization must prevent access to unauthorized BOMs or administrative actions. | Must | Mandatory custom security rule |
| NFR-007 | AI output must be treated as untrusted, labeled, reviewable content and must never execute commands or alter authoritative data. | Must | Mandatory custom security rule and SRC-03, SRC-04 |
| NFR-008 | Integration, validation, API, and AI activity must use correlation identifiers and structured, redacted logs; metrics must cover latency, error rate, throughput, and saturation. | Must | SRC-03 and mandatory custom observability criteria |
| NFR-009 | External calls must have explicit timeouts and bounded retry behavior; non-critical AI failure must degrade gracefully as defined in FR-030. Exact values are `TBD` for design. | Must | Mandatory custom reliability criteria |

## 10. Major Data Objects

Detailed schemas belong in the TDD. The FRD requires at least these logical objects:

- **BOM Header**: Parent item, revision, lifecycle, item class, source identifiers
- **BOM Relationship**: Parent, component, quantity, UOM, operation sequence,
  effectivity dates, lifecycle attributes, level or path
- **Integration Run**: Correlation ID, source mode, status, counts, times, errors
- **Validation Run**: Scope, trigger, status, times, counts, errors
- **Rule Definition**: Stable rule ID, name, description, severity, enabled status,
  and threshold configuration
- **Finding**: Rule ID, BOM, relationship or path, severity, evidence, status
- **Finding Status History**: Prior and new status, user, comment, timestamp
- **Health Score**: Score, formula version, severity counts, deductions
- **Advisory AI Output**: Linked finding or run, approved inputs reference, labeled
  output, model metadata, timestamp, failure state
- **Audit Event**: Actor, action, object, result, correlation ID, timestamp

## 11. Acceptance Criteria

Every Must and Should functional requirement is covered below. Could requirements
are not necessary for MVP acceptance.

| AC ID | Requirement | Acceptance criterion |
| --- | --- | --- |
| AC-001 | FR-001 | Given live access or an approved mock payload, OIC loads a PLM-shaped engineering BOM dataset through the same canonical ingestion boundary. |
| AC-002 | FR-002, FR-003 | ATP contains the supplied headers and every supplied relationship level with reconstructable parent-child paths. |
| AC-003 | FR-004 | A successful and a failed integration run each show a unique ID, timestamps, status, source mode, counts, and redacted diagnostics. |
| AC-003A | FR-039 | An Administrator clicks Refresh beside Run Validation and the dashboard/detail data reloads from ATP after OIC pulls refreshed PLM-shaped data; failures preserve prior data and are diagnosable by correlation ID. |
| AC-004 | FR-005 | The configured daily trigger creates a validation run without manual initiation. |
| AC-005 | FR-006 | An Administrator selects one BOM and receives a new persisted run scoped only to that BOM. |
| AC-006 | FR-007 | No test fixture causes the application to update Fusion PLM during validation. |
| AC-007 | FR-008 | A blank UOM fixture produces one Critical finding with the parent, component, and missing-field evidence. |
| AC-008 | FR-009 | Null, zero, and negative quantities are flagged; a positive in-threshold quantity is not flagged by this rule. |
| AC-009 | FR-010 | Two rows with the same normalized duplicate key are linked in one duplicate finding; a differing operation sequence or effectivity value does not form an exact duplicate. |
| AC-010 | FR-011 | A component with a configured obsolete status in an active or released parent produces a finding showing both statuses. |
| AC-011 | FR-012 | An end date before its start date is flagged and the two dates are shown as evidence. |
| AC-012 | FR-013 | The A-to-B-to-C-to-A fixture produces one Critical finding whose evidence displays the full cycle path. |
| AC-013 | FR-014, FR-015 | A quantity beyond a configured threshold is flagged with observed value, threshold, and configuration source; an in-threshold value is not. |
| AC-014 | FR-016, FR-017 | The displayed score is reproducible from displayed unresolved findings, weights, and deductions and never falls below 0 or exceeds 100. |
| AC-015 | FR-018 | Users can open at least two runs for the same BOM and distinguish historical findings, score, review activity, and run metadata from the current clean state. |
| AC-016 | FR-019, FR-020 | Open, Reviewed, and Ignored are selectable by an authorized reviewer; Ignored is rejected without a comment and accepted with a stored comment, user, and timestamp. Resolved can appear as data but is not manually selectable in the final UI. |
| AC-017 | FR-021 | The UI labels findings as requiring review and does not claim that every flag proves source data is wrong. |
| AC-018 | FR-022 | VBCS retrieves dashboard and detail data through authenticated ORDS endpoints without a direct Fusion PLM dashboard call. |
| AC-019 | FR-023 | The dashboard displays healthy and risky BOMs, severity counts, open issues, and available health-by-item-class data; rule metadata and rule filtering remain available outside the dashboard cards. |
| AC-020 | FR-024, FR-025 | A user opens a risky BOM, views all supplied levels in a parent-child representation, sees findings, and can use the supported filters or sorting. |
| AC-021 | FR-027, FR-028 | The demo produces a plain-language Advisory AI explanation for a selected finding and a BOM-level risk summary from the BOM Detail page, both with non-authoritative wording. |
| AC-022 | FR-029 | AI content is visibly labeled, stored in ATP, linked to its source evidence, and visually distinct from the rule result. |
| AC-023 | FR-030 | With the AI service unavailable, rule results and review remain usable and a correlated AI error is logged. |
| AC-024 | FR-031 | Inspection of OIC and PLM interactions finds no AI-output or BOM write-back operation. |
| AC-025 | FR-032 | Administrator and Business Reviewer test accounts receive only their documented capabilities. |
| AC-026 | FR-033 | A reviewer can see each active rule's stable name, description, severity, enabled state, and applicable threshold. |
| AC-027 | FR-035 | A failed ingestion, validation, API, or AI operation is diagnosable from redacted logs using its correlation ID, processing stage, timestamp, terminal status, and safe diagnostic detail. |
| AC-028 | FR-036, FR-037 | The customer-reviewed dataset yields every expected final UI deterministic and anomaly finding and completes the full approved demo journey. |

## 12. Assumptions, Dependencies, and Risks

### Assumptions

- Sample data contains enough multi-level and quantity variation to demonstrate the
  selected anomaly threshold.
- The customer will review the canonical mock payload if live PLM access is not
  available.
- Oracle service environments and credentials can be made available within the
  prototype schedule.
- One advisory AI provider can be accessed or substituted behind an interface;
  provider selection is a design decision.

### Dependencies

- Oracle Fusion PLM or customer-reviewed mock payload
- OIC, ATP, ORDS, VBCS, identity configuration, and an approved secret store
- Customer-provided lifecycle values for the configured obsolete-status rule
- Customer-reviewed acceptance dataset and expected results

### Risks

- Platform access delays may force use of the accepted mock-data fallback.
- Dirty or insufficient history may limit anomaly demonstration quality.
- Approved severities, duplicate key, and score weights must remain configurable so
  later customer evidence can refine them without changing the MVP boundary.
- The combined Must scope is ambitious for three weeks and requires strict control
  of Could and deferred items.

## 13. Extension Configuration

The user confirmed during Requirements Analysis that the optional Resiliency
Baseline, Property-Based Testing, and Security Baseline extensions are disabled for
this three-week prototype. The security, observability, schema, and reliability
requirements explicitly retained in this document remain in force downstream.

## 14. Requirements Gate Validation Report

| Rule group | Result | Evidence | Owner | Resolution status |
| --- | --- | --- | --- | --- |
| Speaker traceability | PASS | Active final UI-aligned FRs map to named transcript speakers, `final.html`, and recorded project decisions. | Product owner | Complete |
| MoSCoW assignment | PASS | Every functional requirement has exactly one priority; exclusions are classified Won't. | Product owner | Complete |
| Scope and exclusions | PASS | In Scope, Out of Scope, and Deferred sections define testable boundaries. | Product owner | Complete |
| Rule semantics | PASS | The Requirements Gate approval confirms severities, duplicate key, and score defaults for the MVP. | PLM and data governance | Complete |
| Functional testability | PASS | Major flows and AC-001 through AC-028 cover all Must and Should requirements in the final UI-aligned scope. | Product owner and QA | Complete |
| Security requirements | PASS | NFR-005 through NFR-007 and FR-029 through FR-031 define mandatory MVP boundaries. | IT and security | Complete at FRD level |
| Optional extensions | N/A | Resiliency Baseline, Property-Based Testing, and Security Baseline were disabled for this prototype. | Product owner | Closed |
| TDD Mermaid and schemas | N/A | No TDD is being evaluated; these remain mandatory downstream gates. | Solution architect | Deferred to TDD |

**Overall Requirements Gate result**: `PASS`. Requirements Analysis and
Elaboration are 100% complete. This final draft is unblocked and ready for
downstream AI-DLC stages.
