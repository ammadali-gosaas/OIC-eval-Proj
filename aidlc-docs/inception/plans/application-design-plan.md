# Application Design Plan - Two-Pass Technical Design

## Purpose

Maintain the single evaluator-facing `aidlc-docs/inception/application-design/technical-design.md` through controlled design passes. Part I, Architectural Design, was approved. Part II, Data Models, was generated and then simplified after the evaluator-approved `final.html` became the latest product truth.

## Approved Inputs

- `aidlc-docs/inception/requirements/requirements.md`
- `aidlc-docs/inception/user-stories/stories.md`
- `aidlc-docs/inception/user-stories/personas.md`
- `aidlc-docs/inception/plans/execution-plan.md`
- `final.html`
- `Customer Requirement Discovery Call Transcript.pdf`

## Artifact Consolidation

The user-approved execution plan consolidates the default AIDLC Application Design outputs into Part I of one Technical Design document. Part I will contain the equivalents of:

- Component definitions and responsibilities
- Component interface and high-level operation catalog
- Service definitions and orchestration patterns
- Component dependency and communication mapping
- Consolidated application and deployment architecture
- Unit or responsibility boundaries needed to understand later implementation
- NFR and infrastructure concerns appropriate at architectural depth

## Verified Oracle Capabilities

- Oracle Fusion Cloud SCM provides REST endpoints for Item Structures, including retrieval of structure data.
- Oracle Integration 3's Oracle Database Adapter can invoke stored procedures, execute SQL, and perform supported table operations.
- OCI Generative AI provides managed inference capabilities and governed endpoint options, but its use remains a project decision rather than an assumed requirement.

## Architecture Questions

Complete every `[Answer]:` tag with the selected letter. Use `X` with an explanation when none of the listed options fits.

### Question 1
Where should deterministic validation, cycle detection, and health-score calculation execute for the prototype?

A) ATP PL/SQL packages invoked through controlled OIC or ORDS operations; keep OIC focused on integration orchestration (recommended for the Oracle-native three-week prototype)

B) A separately deployed custom validation service that reads and writes ATP

C) Primarily inside OIC integration mappings and orchestration logic

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

### Question 2
Which AI integration boundary should the architecture use?

A) Directly design for OCI Generative AI as the fixed provider

B) Define a provider-neutral Advisory AI Adapter, use OCI Generative AI as the preferred deployment, and permit a controlled mock when access is unavailable (recommended)

C) Use only mocked advisory responses in the three-week prototype

D) Use an evaluator-provided or company-approved external AI provider

X) Other (please describe after the `[Answer]:` tag)

[Answer]: B

### Question 3
How should application identity and role enforcement be represented?

A) Use the company's existing enterprise identity provider for VBCS sign-in, propagate authenticated identity to ORDS, and map application roles for Engineer, Reviewer, Administrator, and Support (recommended)

B) Use an OCI IAM Identity Domain as the explicit identity provider and map the four application roles

C) Use prototype-only local or test accounts with application-managed role mappings

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

### Question 4
What BOM ingestion pattern should Part I design?

A) OIC performs a scheduled snapshot or incremental synchronization and also supports an authorized selected-BOM refresh using the same canonical payload (recommended)

B) OIC performs only a daily full snapshot of the prototype BOM population

C) OIC retrieves BOM data only when a user requests validation for a selected BOM

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

### Question 5
How should validation runs behave from the UI and scheduler perspective?

A) All runs execute asynchronously with a run identifier; VBCS polls ORDS for status and results (recommended)

B) Selected-BOM runs wait synchronously for completion, while daily runs execute asynchronously

C) All runs execute synchronously and return final findings in the initiating request

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

### Question 6
What deployment-environment depth should the prototype architecture show?

A) One logical prototype environment using existing company Oracle services, with clear trust boundaries and no production-readiness claim (recommended)

B) Separate development and test environments with promotion between them

C) A provider-level conceptual architecture without committing to environment topology

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

## Architecture Generation Checklist

### Planning and Decisions

- [x] Load approved requirements, stories, personas, and execution plan.
- [x] Confirm the single-document, two-pass consolidation approach.
- [x] Identify architecture decisions not settled by approved requirements.
- [x] Collect answers to all architecture questions.
- [x] Validate answers for completeness, contradictions, and ambiguity.
- [x] Confirm that no follow-up questions are required.
- [x] Present the resolved architecture approach for explicit approval; the answers do not materially change the approved plan.

### Part I Generation

- [x] Create `aidlc-docs/inception/application-design/technical-design.md` with document control and scope.
- [x] Add the system context diagram and text alternative.
- [x] Add the Oracle component architecture diagram and text alternative.
- [x] Define component responsibilities, interfaces, and trust boundaries.
- [x] Define ingestion, validation, selected-BOM, daily-run, review, and Advisory AI flows.
- [x] Define the high-level API and operation catalog without detailed payload schemas.
- [x] Define security, logging, correlation, retry, failure, and graceful-degradation behavior.
- [x] Define logical deployment and environment boundaries at the approved depth.
- [x] Record architectural decisions, alternatives, assumptions, risks, and limitations.
- [x] Trace architecture sections to applicable FR, NFR, and story identifiers.
- [x] Add a locked Part II placeholder stating that Data Models require architecture approval.
- [x] Validate all Mermaid syntax, Markdown structure, and text alternatives.
- [x] Present Part I for explicit user review and approval.

## Architecture Boundaries

- No detailed table definitions, columns, data types, keys, indexes, or physical ER model will be generated in Part I.
- No code, DDL, OIC package, ORDS module, VBCS implementation, or infrastructure will be created.
- No automatic Fusion PLM write-back will be introduced.
- Unknown environment-specific details will be labeled as implementation inputs.
- The Data Model pass will not begin until Part I is explicitly approved.

## Completion Conditions

- All architecture questions are answered without ambiguity.
- Every Part I checklist item is marked `[x]` when completed.
- Architectural content is understandable, internally consistent, and traceable.
- The user explicitly approves Part I before any Data Model content is generated.

## Part II - Data Model Plan

### AIDLC Consolidation Boundary

Domain entities, relationships, constraints, and detailed data behavior normally form
part of per-unit Functional Design after formal Units Generation. The approved
execution plan consolidates the evaluator-required Data Models into Part II of the
single Technical Design document. This pass does not create code or replace any later
per-unit AIDLC artifacts required if implementation proceeds.

### Data Model Questions

Complete every `[Answer]:` tag with the selected letter. Use `X` with an explanation
when none of the listed options fits.

#### Question 7 - BOM Identity

How should the model uniquely identify a BOM while preserving Fusion identifiers?

A) Use an internal surrogate identifier for relationships and a business uniqueness
constraint based on source system, organization, parent item source identifier,
structure or alternate name, and revision or effective version when supplied
(recommended)

B) Use only the Fusion-provided structure identifier as the database key

C) Use parent item number and revision only, without organization or structure context

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

#### Question 8 - Snapshot and Incremental History

How should successful ingestion changes be retained?

A) Create an immutable BOM version for each successfully ingested BOM change and mark
one version current; failed or incomplete loads never become current (recommended)

B) Overwrite the current staged BOM and rely only on integration logs for history

C) Create one immutable snapshot of the entire BOM population for every scheduled run,
even when only a small subset changed

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

#### Question 9 - Multi-Level Hierarchy

How should the BOM graph be represented for traversal and cycle evidence?

A) Store versioned parent-component relationships as an adjacency graph, preserve
source level where supplied, and store derived path or cycle evidence with validation
results (recommended)

B) Store only a precomputed tree path for each component

C) Store each complete BOM primarily as one JSON document

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

#### Question 10 - Recurring Findings and Review Status

When the same problem appears in a later validation run, what should happen to its
review status?

A) Create an immutable finding occurrence for each run, link recurring occurrences by
a stable fingerprint, and start the new occurrence as Open without automatically
carrying Ignored or Resolved status (recommended)

B) Automatically copy the prior finding status and comment to the new occurrence

C) Maintain one finding record across all runs and update its status in place

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

#### Question 11 - Health-Score History

How should score changes caused by finding review be retained?

A) Store the calculated score and deduction evidence as a versioned snapshot; a status
change creates a new score version while preserving the original run calculation
(recommended)

B) Update one score record in place whenever a finding status changes

C) Store no score result and calculate the score only when a user opens a page

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

#### Question 12 - Advisory AI and Audit Retention

What should be persisted for AI explainability and audit without unnecessarily storing
sensitive prompt content?

A) Store approved source-evidence references or a redacted input snapshot, provider and
model metadata, request status, labeled output, correlation data, and append-only audit
events; keep retention periods configurable because they remain TBD (recommended)

B) Store the complete raw prompt and response indefinitely

C) Store only the AI response text without its source evidence or request metadata

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

#### Question 13 - ATP Physical Modeling Style

Which physical modeling approach should Part II use?

A) Use a conventional Oracle relational design with surrogate internal keys, explicit
business uniqueness constraints, UTC timestamps, and JSON only for flexible evidence
that does not justify fixed columns (recommended)

B) Use a JSON-centric design with most domain objects stored as documents

C) Use source-system natural keys as all primary and foreign keys

X) Other (please describe after the `[Answer]:` tag)

[Answer]: A

### Part II Planning Checklist

- [x] Confirm explicit approval of Part I.
- [x] Explain the Data Model pass and obtain approval for its planning step.
- [x] Identify unresolved modeling decisions from requirements and architecture.
- [x] Add context-specific Data Model questions using `[Answer]:` tags.
- [x] Collect answers to Questions 7 through 13.
- [x] Validate every answer for completeness, consistency, and ambiguity.
- [x] Confirm that no follow-up questions are required.
- [x] Present the resolved Data Model approach for explicit generation approval.

### Part II Generation Checklist

- [x] Replace the Part II planning gate in `technical-design.md` with the approved Data Model content.
- [x] Define modeling scope, principles, and naming conventions.
- [x] Add a conceptual and logical entity model.
- [x] Add validated entity-relationship Mermaid diagrams and text alternatives.
- [x] Define entity purposes, relationships, cardinalities, ownership, and lifecycle.
- [x] Define the ATP table catalog with columns and Oracle data types.
- [x] Define primary keys, foreign keys, business unique constraints, required fields, and check constraints.
- [x] Define latest BOM hierarchy, traversal, and cycle-evidence representation.
- [x] Define integration runs, validation runs, findings, review history, score history, AI outputs, and audit events.
- [x] Define indexes, pagination support, retention controls, redaction, and data-access boundaries.
- [x] Map data structures to APIs, FRs, NFRs, user stories, and approved architecture components.
- [x] Record data assumptions, implementation inputs, risks, and limitations.
- [x] Validate Mermaid syntax, Markdown structure, table consistency, and complete traceability.
- [x] Present the complete Technical Design for final review and explicit approval.

### Part II Boundaries

- Do not generate Data Model content until Questions 7 through 13 are answered,
  validated, and separately approved for generation.
- Do not add DDL, application code, credentials, environment-specific secrets, or
  implementation scripts.
- Do not introduce Fusion PLM write-back, automatic AI decisions, or requirements not
  present in the approved baseline.
- Label unresolved Oracle-version or environment-specific details as implementation
  inputs rather than approved facts.

## UI-Aligned Simplification Revision

### Revision Trigger

After the first Data Model pass, the user provided `final.html` as the evaluator-approved
UI and approved treating it as the latest source of truth. This supersedes earlier
modeling answers where they conflict with the final UI.

### Superseded Modeling Choices

| Earlier choice | UI-aligned revision |
| --- | --- |
| Immutable BOM versions and item snapshots | Latest BOM structure only, with runs/findings/history retained. |
| Four runtime roles | Two final UI roles: Business Reviewer and Administrator. |
| Manual Open, Reviewed, Ignored, Resolved transitions | Manual Open, Reviewed, and Ignored only; Resolved may appear as imported/current data. |
| Separate AI request and audit tables | Reintroduced in normalized prototype form as `AI_ADVISORIES`, `FINDING_REVIEWS`, and `DIAGNOSTIC_LOGS` to reduce column bloat. |
| 21 physical ATP tables | Eight normalized prototype tables aligned to the final UI without returning to the larger enterprise-style model. |
| FR-038 active rule coverage | Deferred unless reintroduced in a later UI revision. |
| Distinct BOM-level AI risk summary | Active; represented by the BOM Detail Request Advisory AI action and persisted in `AI_ADVISORIES`. |
| Refresh button beside Run Validation | Active; Administrator-triggered refresh pulls latest PLM-shaped data through OIC and reloads dashboard/detail data from ATP. |

### UI-Aligned Revision Checklist

- [x] Treat `final.html` as the latest product truth.
- [x] Normalize Part II data model to eight final UI-aligned prototype tables.
- [x] Update role model to Business Reviewer and Administrator.
- [x] Preserve the Resolved nuance as a data state, not a manual review action.
- [x] Exclude FR-038 from the active final UI-aligned prototype scope.
- [x] Restore BOM-level Advisory AI summary as active after user clarification.
- [x] Add UI refresh action beside Run Validation and map it to OIC ingestion, run history, diagnostics, and dashboard/detail reload.
- [x] Split bloated run/finding columns into focused run, rule, review, AI, and diagnostic tables.
- [x] Update requirements, stories, personas, state, and audit trail.
- [x] Revalidate Markdown, Mermaid, and traceability after revision.
