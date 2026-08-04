# Comprehensive API Testing Plan: BOM Validation and Anomaly Detection

Base URL: http://172.105.152.7:8181/ords/bom

### Global Testing Instructions
* Headers: For all POST, PUT, and PATCH requests, ensure the header "Content-Type: application/json" is included.
* Path Variables: Replace any variables starting with ":" (e.g., :bom_id, :rule_id, :requestId) with valid data from the database before execution.
* Execution Order: Always execute POST or PUT creation endpoints to generate data before attempting to fetch (GET), modify (PATCH), or remove (DELETE) specific records by their IDs.

---

## 1. Advisories (1 Handler)

GET http://172.105.152.7:8181/ords/bom/advisories/:requestId
* Prerequisite: Run a POST advisory endpoint first to generate a Request ID.
* Happy Path: 200 OK (Returns the AI advisory response).
* Unhappy Path: 404 Not Found (If :requestId does not exist or is invalid).

---

## 2. BOMs (Bill of Materials) (6 Handlers)

GET http://172.105.152.7:8181/ords/bom/boms
* Happy Path: 200 OK (Returns a JSON array of BOM records).

GET http://172.105.152.7:8181/ords/bom/boms/:bom_id
* Happy Path: 200 OK (Returns details for the specific BOM).
* Unhappy Path: 404 Not Found (If :bom_id does not exist).

GET http://172.105.152.7:8181/ords/bom/boms/:bom_id/advisories
* Happy Path: 200 OK (Returns a list of advisories linked to this BOM).
* Unhappy Path: 404 Not Found (If BOM doesn't exist).

POST http://172.105.152.7:8181/ords/bom/boms/:bom_id/advisories
Payload:
{
  "prompt": "Analyze BOM health and identify risks"
}
* Happy Path: 200 OK or 201 Created (Returns a Request ID for the advisory generation).
* Unhappy Path: 400 Bad Request (If the prompt is missing); 404 Not Found (If :bom_id doesn't exist).

POST http://172.105.152.7:8181/ords/bom/boms/:bom_id/refresh
* Happy Path: 200 OK or 202 Accepted (Triggers a data sync).
* Unhappy Path: 404 Not Found (If :bom_id is invalid).

GET http://172.105.152.7:8181/ords/bom/boms/:bom_id/runs
* Happy Path: 200 OK (Returns historical runs for this specific BOM).
* Unhappy Path: 404 Not Found (If :bom_id doesn't exist).

---

## 3. Dashboard (2 Handlers)

GET http://172.105.152.7:8181/ords/bom/dashboard
* Happy Path: 200 OK (Returns aggregate counts for executive KPIs).

POST http://172.105.152.7:8181/ords/bom/dashboard/refresh
* Happy Path: 200 OK (Forces a recalculation of metrics).

---

## 4. Diagnostics (1 Handler)

GET http://172.105.152.7:8181/ords/bom/diagnostics/runs
* Happy Path: 200 OK (Returns system-level logs and execution traces).

---

## 5. Findings (3 Handlers)

GET http://172.105.152.7:8181/ords/bom/findings
* Happy Path: 200 OK (Returns a JSON array of all detected anomalies).

POST http://172.105.152.7:8181/ords/bom/findings/:finding_id/advisories
Payload:
{
  "prompt": "Explain this anomaly and suggest a resolution"
}
* Happy Path: 200 OK or 201 Created (Initiates AI resolution suggestions).
* Unhappy Path: 400 Bad Request (Missing JSON body); 404 Not Found (Invalid :finding_id).

PATCH http://172.105.152.7:8181/ords/bom/findings/:finding_id/status
Payload:
{
  "status": "REVIEWED",
  "notes": "Reviewed with engineering team"
}
* Happy Path: 200 OK (Successfully updates the status).
* Unhappy Path: 400 Bad Request (Invalid status string format); 404 Not Found.

---

## 6. Rules (4 Handlers)

GET http://172.105.152.7:8181/ords/bom/rules
* Happy Path: 200 OK (Returns all validation logic rules).

POST http://172.105.152.7:8181/ords/bom/rules
Payload:
{
  "rule_code": "TEST-01",
  "rule_name": "Postman Test Rule",
  "severity": "INFO",
  "description": "Created from Postman",
  "threshold_or_configuration": "N/A"
}
* Happy Path: 201 Created or 200 OK (Rule is successfully added to the DB).
* Unhappy Path: 400 Bad Request (If rule_code or rule_name is null/missing).

PUT http://172.105.152.7:8181/ords/bom/rules/:rule_id
Payload:
{
  "rule_name": "Updated via Postman",
  "severity": "WARNING",
  "description": "Updated rule",
  "threshold_or_configuration": "UOM IS NOT NULL",
  "enabled_flag": "Y"
}
* Note: Supports both numeric ID or string Code for :rule_id.
* Happy Path: 200 OK (Rule is successfully updated).
* Unhappy Path: 400 Bad Request (Missing required payload fields); 404 Not Found (Rule doesn't exist).

DELETE http://172.105.152.7:8181/ords/bom/rules/:rule_id
* Note: Supports both numeric ID or string Code for :rule_id.
* Happy Path: 200 OK (Rule is removed).
* Unhappy Path: 404 Not Found (If the rule was already deleted or doesn't exist).

---

## 7. Schedules (1 Handler)

POST http://172.105.152.7:8181/ords/bom/schedules
Payload:
{
  "time": "07:00",
  "interval": "Daily"
}
* Happy Path: 200 OK or 201 Created.
* Unhappy Path: 400 Bad Request (If time format is invalid).

---

## 8. Validation Runs (3 Handlers)

GET http://172.105.152.7:8181/ords/bom/validation-runs
* Happy Path: 200 OK (Returns history of all execution runs).

POST http://172.105.152.7:8181/ords/bom/validation-runs
Payload:
{
  "bom_id": 101,
  "run_type": "MANUAL"
}
* Happy Path: 201 Created or 202 Accepted (Kicks off the engine and returns a new run_id).
* Unhappy Path: 400 Bad Request (If :bom_id is missing in the payload).

GET http://172.105.152.7:8181/ords/bom/validation-runs/:run_id
* Happy Path: 200 OK (Returns the results and summary of a specific run).
* Unhappy Path: 404 Not Found (If :run_id doesn't exist).