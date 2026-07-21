# User Personas

## Purpose

This document defines the human user archetypes for the three-week BOM Validation
and Anomaly Detection MVP. The evaluator-approved `final.html` defines two runtime
application roles: Administrator and Business Reviewer.

Engineers, PLM managers, product data governance users, and IT support remain
stakeholder viewpoints. In the final prototype UI, their operational capabilities are
represented through the two runtime roles below rather than separate login roles.

## P-001 - Business Reviewer

### Profile

A product-data reviewer, engineer, or approver who inspects BOM health, reviews
validation findings, and records whether findings have been examined or ignored.

### Goals

- Identify risky BOMs before downstream release.
- Inspect multi-level BOM components and highlighted issues.
- Understand rule evidence in plain language.
- Review findings without treating every flag as proof of a source-data error.
- Request Advisory AI explanations while keeping human judgment authoritative.
- Compare validation and review history.

### Pain Points

- Multi-level structures make issues hard to find manually.
- Duplicates or anomalies may be legitimate and need review context.
- AI suggestions can be confused with approved business decisions.
- A health score is not useful unless the deductions are visible.

### MVP Capabilities

- View the landing dashboard, BOM detail, component view, findings, score, and history.
- Filter BOMs and findings by supported values such as status, severity, rule, and item class.
- Change finding status to Open, Reviewed, or Ignored.
- Provide a mandatory comment when setting a finding to Ignored.
- View Resolved findings when they arrive as source/current data, without manually
  setting Resolved in the UI.
- Request and view Advisory AI explanations for selected findings.
- Request and view BOM-level Advisory AI summaries from BOM Detail.
- View readable rule metadata.

### Story Mapping

- US-002 - Detect Deterministic BOM Problems
- US-003 - Identify Quantity Anomalies and Explain Health
- US-005 - Find and Inspect Risky Multi-Level BOMs
- US-006 - Review Findings and Retain History
- US-007 - Explain Findings with Advisory AI
- US-011 - Filter and Sort Results
- US-012 - Apply the Configurable Health-Score Formula
- US-013 - Show the BOM as a Tree

## P-002 - Administrator

### Profile

An Oracle integration or application administrator responsible for operating the
prototype, running validation, viewing redacted logs, and demonstrating controlled
rule administration behavior.

### Goals

- Ingest and refresh Fusion PLM or approved mock data through OIC.
- Run on-demand validation and support daily scheduled validation.
- Monitor import, validation, and AI execution history.
- Diagnose failures using correlation identifiers and redacted logs.
- View and demonstrate readable rule metadata and prototype rule controls.
- Preserve the no-write-back boundary to Fusion PLM.

### Pain Points

- Integration failures may span OIC, ATP, ORDS, VBCS, and AI.
- Missing correlation identifiers make troubleshooting slow.
- Secrets or sensitive payloads must not appear in logs or UI errors.
- Rule behavior needs to be visible without creating a full production rule-governance system.

### MVP Capabilities

- Access everything available to a Business Reviewer.
- Click Refresh beside Run Validation to pull refreshed BOM data through OIC.
- Run on-demand validation for a selected BOM.
- View run history and redacted integration logs.
- Configure or demonstrate scheduled validation behavior at prototype depth.
- Open the Add New Logic Rule modal represented in the final UI.
- Diagnose failed import, validation, or AI activity without unrestricted database access.

### Story Mapping

- US-001 - Ingest BOM Data Through OIC
- US-004 - Run On-Demand Validation for One BOM
- US-006 - Review Findings and Retain History
- US-007 - Explain Findings with Advisory AI
- US-008 - Administer and Support the Prototype Safely
- US-010 - Run Daily Scheduled Validation
- US-014 - Add Prototype Rule Logic in the UI

## Project Stakeholder Profile

The Project Stakeholder or Product Owner reviews the acceptance dataset and
end-to-end demonstration represented by US-009. This is an approval stakeholder, not a
routine application role.

## Persona-to-Role Boundary

- Business Reviewer represents reviewer, approver, and engineer-style inspection needs.
- Administrator represents integration administration and support-style troubleshooting needs.
- A single real person may hold both runtime roles, but permissions remain explicit.
- `Resolved` is a data state that may be displayed when supplied by PLM/current data or
  system reconciliation; it is not a manual Business Reviewer action in the final UI.
