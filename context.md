Here is the updated **`context.md`** file reflecting the latest cloud environment setup, database connection parameters, master ORDS endpoints script, test verification results, and repository status.

---

# Context Handoff: BOM Validation & Anomaly Detection Prototype

## 1. Project Overview

This project is an end-to-end **BOM Validation and Anomaly Detection Prototype** designed to identify data-quality defects, structural flaws (such as circular reference loops), and quantity anomalies in multi-level engineering Bills of Materials (BOMs) prior to production release.

The application architecture follows an Oracle-native design:

* **Ingestion:** Oracle Integration Cloud (OIC) processes PLM-shaped engineering BOM structures.


* **Storage & Logic:** Oracle Autonomous Transaction Processing (ATP) / Oracle DB Free stores staged data across **8 normalized tables** and executes a PL/SQL validation package (`BOM_VALIDATION_PKG`).


* **API Bridge:** Oracle REST Data Services (ORDS) exposes versioned RESTful APIs over the database.


* **User Interface:** Visual Builder (VBCS) / `final.html` presents landing dashboards, multi-level BOM trees, finding review workspaces, and advisory AI insights.


* **Advisory AI:** Provides plain-language explanations and suggestions without modifying authoritative PLM data.



---

## 2. Environment & Credentials

### Active Cloud Environment (Target)

* **Cloud Host IP:** `172.105.152.7`
* **Database Port:** `1521`
* **Database Service Name:** `CLIENT2PDB`
* **App Schema / Username:** `za_schema`
* **App Schema Password:** `NewPassword111`
* **ORDS HTTP Port:** `8181`
* **ORDS Schema Mapping Alias:** `bom` (maps to `ZA_SCHEMA`)


* **ORDS Base REST URL:** `[http://172.105.152.7:8181/ords/bom/](http://172.105.152.7:8181/ords/bom/)`

* **Database Actions (Web SQL):** `[http://172.105.152.7:8181/ords/_/landing](http://172.105.152.7:8181/ords/_/landing)` *(Login Path: `bom`, Username: `za_schema`)*


### Local Docker Environment (Fallback / Dev)



* **Docker Containers:** `local-oracle` (Oracle DB 23ai Free) & `local-ords` (ORDS sidecar)


* **Database Port:** `1521` (`FREEPDB1`)


* **App Schema:** `BOM_APP_USER` / `BomPrototype123`

* **Local ORDS Base URL:** `http://localhost:8080/ords/freepdb1/bom/`


---

## 3. Database Schema & Core Logic Layer

The `ZA_SCHEMA` database contains **8 normalized tables**:

1. **`BOMS`**: Latest BOM headers, organization codes, health scores (0–100), and status labels (`HEALTHY` / `RISKY`).


2. **`BOM_COMPONENTS`**: Multi-level parent-child hierarchy rows, sequence numbers, lifecycle statuses, quantities, UOMs, and threshold bounds.


3. **`BOM_RUNS`**: Execution history tracking for `IMPORT`, `REFRESH`, `VALIDATION`, and `ADVISORY_AI` runs with correlation IDs and timestamps.


4. **`VALIDATION_RULES`**: Catalog of active rules (`FR-008` to `FR-014`), descriptions, severities, and threshold configurations.


5. **`VALIDATION_FINDINGS`**: Rule violation findings containing evidence JSON, actual/expected values, and issue statuses (`OPEN`, `REVIEWED`, `IGNORED`, `RESOLVED`).


6. **`FINDING_REVIEWS`**: Audit trail of human status transitions, reviewer IDs, comments, and timestamps.


7. **`AI_ADVISORIES`**: Labeled Advisory AI plain-language summaries and suggested actions.


8. **`DIAGNOSTIC_LOGS`**: Redacted operational diagnostics, processing stages, duration metrics, and correlation IDs.



### PL/SQL Engine

* **`BOM_VALIDATION_PKG.run_full_validation(p_bom_id, p_requested_by)`**: Traverses the staged multi-level BOM graph, evaluates all 7 deterministic/anomaly rules (`FR-008` through `FR-014`), populates `VALIDATION_FINDINGS`, calculates deductions, updates `BOMS.HEALTH_SCORE`, and logs execution diagnostics.



---

## 4. Master ORDS REST API Catalog

All 14 endpoints are defined in the master consolidation script `05_ords_fix_commit.sql` and deployed to `ZA_SCHEMA`:

| Method | Endpoint | Purpose | Target Tables / Logic |
| --- | --- | --- | --- |
| `GET` | `/dashboard` | Landing dashboard health, severity, & item-class metrics.

 | `BOMS`, `VALIDATION_FINDINGS`, `VALIDATION_RULES`<br> |
| `POST` | `/dashboard/refresh` | Trigger dataset-wide dashboard refresh.

 | Logs refresh event

 |
| `GET` | `/boms` | Search, filter, and paginate BOM summaries.

 | `BOMS`, `BOM_COMPONENTS`<br> |
| `GET` | `/boms/:bom_id` | Multi-level BOM detail, components, & active findings.

 | `BOMS`, `BOM_COMPONENTS`, `VALIDATION_FINDINGS`<br> |
| `POST` | `/boms/:bom_id/refresh` | Trigger selected-BOM refresh via OIC.

 | `BOM_RUNS`<br> |
| `GET` | `/boms/:bom_id/runs` | Historical execution & validation run list.

 | `BOM_RUNS`<br> |
| `POST` | `/validation-runs` | Queue/run selected-BOM validation on-demand.

 | Invokes `BOM_VALIDATION_PKG.run_full_validation`<br> |
| `GET` | `/validation-runs/:run_id` | Poll asynchronous validation run status.

 | `BOM_RUNS`<br> |
| `PATCH` | `/findings/:finding_id/status` | Update issue status (`OPEN`, `REVIEWED`, `IGNORED`).

 | `VALIDATION_FINDINGS`, `FINDING_REVIEWS`, `BOMS`<br> |
| `POST` | `/boms/:bom_id/advisories` | Request BOM-level risk summary from Advisory AI.

 | `BOM_RUNS`, `AI_ADVISORIES`<br> |
| `POST` | `/findings/:finding_id/advisories` | Request finding-level Advisory AI explanation.

 | `BOM_RUNS`, `AI_ADVISORIES`<br> |
| `GET` | `/advisories/:requestId` | Fetch generated advisory text or status.

 | `AI_ADVISORIES`<br> |
| `GET` | `/rules` | Read-only validation rule dictionary.

 | `VALIDATION_RULES`<br> |
| `POST` | `/rules` | Add custom prototype validation rule.

 | `VALIDATION_RULES`<br> |
| `GET` | `/diagnostics/runs` | Retrieve redacted IT diagnostic logs.

 | `DIAGNOSTIC_LOGS`<br> |

### Patch 05b Additions (UI-Aligned Global Endpoints)

The following endpoints and filters were added to bridge the gap between the static HTML wireframes (`final.html`) and the dynamic ORDS API requirements:

| Method | Endpoint | Purpose | Target Tables / Logic |
| --- | --- | --- | --- |
| `GET` | `/boms` | **UPDATED:** Now accepts `:status_label`, `:item_class`, and `:severity` query parameters for dashboard UI chart filtering. | `BOMS`, `BOM_RUNS`, `VALIDATION_FINDINGS`, `VALIDATION_RULES` |
| `GET` | `/validation-runs` | **NEW:** Global run history list (returns runs across *all* BOMs). | `BOM_RUNS`, `BOMS` |
| `GET` | `/findings` | **NEW:** Global findings list for the Review Workspace. Accepts `:issue_status`, `:severity`, and `:rule_code` filters. | `VALIDATION_FINDINGS`, `VALIDATION_RULES`, `BOMS` |
| `POST` | `/schedules` | **NEW:** Mock endpoint to accept the payload from the UI's "Run Scheduled Validation" modal. | Returns `201 Created` |

---

## 5. Repository Files & Maintenance

* **`setup_schema.sql`**: Drops/creates the 8 tables and seeds `VALIDATION_RULES`.


* **`02_database_validation_engine.sql`**: Creates 240 sample BOM assemblies (`BOM_ID` 1 to 240) and compiles `BOM_VALIDATION_PKG`.


* **`05_ords_fix_commit.sql`**: Master script containing all 14 REST endpoints mapped to `ZA_SCHEMA`.


* **`final.html`**: Standalone, interactive HTML/JS prototype modeling the complete VBCS UI experience.


* **`requirements.md` & `technical-design.md**`: Master FRD and TDD documentation.



---

## 6. Verification Status & Next Steps

### Completed Accomplishments

1. **Cloud Database:** `setup_schema.sql` and `02_database_validation_engine.sql` compiled successfully on `CLIENT2PDB` (240 BOM assemblies populated).


2. **Cloud ORDS API Layer:** `05_ords_fix_commit.sql` applied to `ZA_SCHEMA` and verified live over port `8181`.


3. **End-to-End Test Completed:** Executed `POST /validation-runs` for `BOM_ID = 1`, triggering the PL/SQL validation package, generating 3 findings, updating the BOM health score to 55, and logging diagnostic traces in `DIAGNOSTIC_LOGS`.


4. **Git Sync:** Master file `05_ords_fix_commit.sql` committed and pushed to `origin/main`.



### Immediate Next Steps

* Integrate the Visual Builder (VBCS) web frontend / `final.html` with the live cloud REST APIs at `[http://172.105.152.7:8181/ords/bom/](http://172.105.152.7:8181/ords/bom/)`[cite: 2, 5, 6, 9].