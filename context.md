Here is the context file you can provide to Codex (or any AI coding assistant) to bring it up to speed on your architecture, database schema, and the exact REST endpoints you need to build with ORDS.

---

# Codex Context: ORDS Setup for BOM Validation Prototype

**Project Overview**
The project is a BOM Validation and Anomaly Detection Prototype. It identifies data-quality, structural, and quantity-anomaly risks in multi-level engineering BOMs. The database has been successfully set up locally using an Oracle Database Free Docker container. The current task is to configure Oracle REST Data Services (ORDS) to expose the database tables and PL/SQL validation engine as RESTful APIs.

**Current Environment & Credentials**

* **Container Name:** `local-oracle`
* **Port Mapping:** `1521:1521`
* **Pluggable Database:** `FREEPDB1`
* **Master Admin:** `sys` / `MySecretPassword123` (SYSDBA)
* **App Schema Username:** `BOM_APP_USER`
* **App Schema Password:** `BomPrototype123`

**Database Schema (Target for ORDS)**
The `BOM_APP_USER` schema contains eight normalized prototype tables:

* `BOMS`: Stores the latest BOM header, current health score, and status label.


* `BOM_COMPONENTS`: Stores multi-level parent-child relationship data, quantity, and thresholds.


* `BOM_RUNS`: Stores import, refresh, validation, and advisory execution metadata.


* `VALIDATION_RULES`: Stores readable deterministic rule definitions and severity.


* `VALIDATION_FINDINGS`: Stores deterministic results, evidence, and current issue status.


* `FINDING_REVIEWS`: Stores normalized review transition history, comments, and reviewer information.


* `AI_ADVISORIES`: Stores BOM-level summaries and selected-finding explanations.


* `DIAGNOSTIC_LOGS`: Stores redacted operational events with correlation IDs.



**PL/SQL Packages**

* `BOM_VALIDATION_PKG`: Contains the `run_full_validation(p_bom_id, p_requested_by)` procedure used to execute deterministic validation and health-score calculation asynchronously.



**Target REST APIs to Implement via ORDS**
The ORDS API layer must present versioned REST resources and invoke the approved database packages without exposing unrestricted SQL. The following endpoints are required based on the Technical Design Document:

* `GET /dashboard`: Returns health, risk, severity, open-finding, and item-class summaries.


* `GET /boms`: Searches, filters, and sorts authorized BOM summaries.


* `GET /boms/{bomId}`: Returns multi-level BOM detail, current score, findings, and evidence.


* `GET /boms/{bomId}/runs`: Returns comparable validation and refresh history.


* `POST /validation-runs`: Starts selected-BOM validation and maps to `BOM_VALIDATION_PKG.run_full_validation`.


* `GET /validation-runs/{runId}`: Polls run status and summary.


* `PATCH /findings/{findingId}/status`: Records Open, Reviewed, or Ignored status and comment in `FINDING_REVIEWS`.


* `GET /rules`: Reads rule names, descriptions, severity, state, and thresholds from `VALIDATION_RULES`.


* `POST /boms/{bomId}/advisories`: Requests a BOM-level advisory summary.


* `POST /findings/{findingId}/advisories`: Requests an advisory explanation.



**Immediate Tasks for Codex**

1. Provide the Linux/Docker commands required to install, configure, and start ORDS natively within the existing `local-oracle` container or as a sidecar container connected to it.
2. Provide the PL/SQL script using `ORDS.ENABLE_SCHEMA` to REST-enable the `BOM_APP_USER` schema.
3. Generate the PL/SQL `ORDS.DEFINE_MODULE`, `ORDS.DEFINE_TEMPLATE`, and `ORDS.DEFINE_HANDLER` blocks to create the endpoints listed above.
4. Supply example `curl` commands to test the newly created endpoints against `localhost`.