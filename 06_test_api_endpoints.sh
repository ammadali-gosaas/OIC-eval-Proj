#!/usr/bin/env bash
set -u

BASE_URL="${BASE_URL:-http://localhost:8080/ords/bom}"
OUT_DIR="${OUT_DIR:-/tmp/bom_api_tests}"

mkdir -p "$OUT_DIR"

print_section() {
  printf '\n\n===== %s =====\n' "$1"
}

run_curl() {
  local name="$1"
  shift
  local body_file="$OUT_DIR/${name}.json"
  local status_file="$OUT_DIR/${name}.status"

  printf '\n--- %s ---\n' "$name"
  "$@" -sS -o "$body_file" -w '%{http_code}' > "$status_file"
  printf 'HTTP %s\n' "$(cat "$status_file")"
  if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$body_file" 2>/dev/null || cat "$body_file"
  else
    cat "$body_file"
  fi
  printf '\n'
}

json_pick() {
  local file="$1"
  local key="$2"

  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$file" "$key" <<'PY'
import json
import sys

path, wanted = sys.argv[1], sys.argv[2].lower()
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

def walk(value):
    if isinstance(value, dict):
        for k, v in value.items():
            if k.lower() == wanted and v is not None:
                print(v)
                return True
        for v in value.values():
            if walk(v):
                return True
    elif isinstance(value, list):
        for v in value:
            if walk(v):
                return True
    return False

walk(data)
PY
}

print_section "BOM Validation ORDS API Tests"
printf 'Base URL: %s\n' "$BASE_URL"
printf 'Output directory: %s\n' "$OUT_DIR"

print_section "Read Endpoints"

# Expected HTTP 200.
# Expected JSON behavior: dashboard summary object is returned, including total/healthy/risky BOM counts, open finding count, severity counts, and item-class summary.
run_curl "01_get_dashboard" \
  curl -X GET "$BASE_URL/dashboard" \
  -H "Accept: application/json"

# Expected HTTP 200.
# Expected JSON behavior: paginated ORDS response with an items array of BOM summaries including bom_id, item_number, health_score, status_label, component_count, and open_finding_count.
run_curl "02_get_boms" \
  curl -X GET "$BASE_URL/boms" \
  -H "Accept: application/json"

BOM_ID="$(json_pick "$OUT_DIR/02_get_boms.json" "bom_id")"
BOM_ID="${BOM_ID:-1}"
printf '\nUsing BOM_ID=%s for dependent tests.\n' "$BOM_ID"

# Expected HTTP 200.
# Expected JSON behavior: filtered paginated BOM response; items should match ORG1 when matching data exists, or be empty without server error.
run_curl "03_get_boms_filtered" \
  curl -X GET "$BASE_URL/boms?organization_code=ORG1&q=ASM" \
  -H "Accept: application/json"

# Expected HTTP 200 when BOM_ID exists.
# Expected JSON behavior: detail payload contains a bom object, components array, and findings array.
run_curl "04_get_bom_detail" \
  curl -X GET "$BASE_URL/boms/$BOM_ID" \
  -H "Accept: application/json"

# Expected HTTP 200.
# Expected JSON behavior: paginated ORDS response with run history items for the selected BOM; may be empty before validation is triggered.
run_curl "05_get_bom_runs" \
  curl -X GET "$BASE_URL/boms/$BOM_ID/runs" \
  -H "Accept: application/json"

# Expected HTTP 200.
# Expected JSON behavior: paginated ORDS response with rule catalog rows for FR-008 through FR-014, including names, severity, enabled flag, and threshold/configuration text.
run_curl "06_get_rules" \
  curl -X GET "$BASE_URL/rules" \
  -H "Accept: application/json"

print_section "Validation Run Endpoint"

# Expected HTTP 201.
# Expected JSON behavior: response includes message "Validation completed", bomId, runId, and requestedBy. This exercises selected-BOM validation and persists BOM_RUNS/VALIDATION_FINDINGS.
run_curl "07_post_validation_run_happy" \
  curl -X POST "$BASE_URL/validation-runs" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{\"bom_id\": $BOM_ID, \"requested_by\": \"api-test-admin\"}"

RUN_ID="$(json_pick "$OUT_DIR/07_post_validation_run_happy.json" "runId")"
RUN_ID="${RUN_ID:-$(json_pick "$OUT_DIR/07_post_validation_run_happy.json" "run_id")}"
RUN_ID="${RUN_ID:-1}"
printf '\nUsing RUN_ID=%s for dependent tests.\n' "$RUN_ID"

# Expected HTTP 400.
# Expected JSON behavior: error object with VALIDATION_RUN_FAILED or equivalent failure message because the BOM ID does not exist.
run_curl "08_post_validation_run_invalid_bom" \
  curl -X POST "$BASE_URL/validation-runs" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"bom_id": 999999999, "requested_by": "api-test-admin"}'

# Expected HTTP 400.
# Expected JSON behavior: error object because required bom_id is missing/null and cannot be converted to a selected BOM.
run_curl "09_post_validation_run_missing_payload" \
  curl -X POST "$BASE_URL/validation-runs" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{}'

# Expected HTTP 200 when RUN_ID exists.
# Expected JSON behavior: run summary includes run_id, bom_id, status, correlation_id, counts, health_score, and any safe error fields.
run_curl "10_get_validation_run" \
  curl -X GET "$BASE_URL/validation-runs/$RUN_ID" \
  -H "Accept: application/json"

# Expected HTTP 200 with an empty items array, or HTTP 404 depending on ORDS query behavior.
# Expected JSON behavior: no server error; invalid run ID should not return a valid run summary.
run_curl "11_get_validation_run_invalid" \
  curl -X GET "$BASE_URL/validation-runs/999999999" \
  -H "Accept: application/json"

print_section "Finding Review Endpoint"

# Refresh BOM detail after validation so a real finding ID can be discovered.
# Expected HTTP 200.
# Expected JSON behavior: detail payload should now include validation findings when the mock data has rule defects for this BOM.
run_curl "12_get_bom_detail_after_validation" \
  curl -X GET "$BASE_URL/boms/$BOM_ID" \
  -H "Accept: application/json"

FINDING_ID="$(json_pick "$OUT_DIR/12_get_bom_detail_after_validation.json" "findingId")"
FINDING_ID="${FINDING_ID:-$(json_pick "$OUT_DIR/12_get_bom_detail_after_validation.json" "finding_id")}"
FINDING_ID="${FINDING_ID:-1}"
printf '\nUsing FINDING_ID=%s for dependent tests.\n' "$FINDING_ID"

# Expected HTTP 200.
# Expected JSON behavior: response includes findingId, oldStatus, newStatus REVIEWED, reviewedBy, bomId, and recalculated healthScore; FINDING_REVIEWS receives a history row.
run_curl "13_patch_finding_reviewed_happy" \
  curl -X PATCH "$BASE_URL/findings/$FINDING_ID/status" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"status": "REVIEWED", "comment": "API test reviewed this finding.", "reviewed_by": "api-test-reviewer"}'

# Expected HTTP 200.
# Expected JSON behavior: response includes newStatus IGNORED and recalculated healthScore; comment and reviewer are persisted in FINDING_REVIEWS.
run_curl "14_patch_finding_ignored_happy" \
  curl -X PATCH "$BASE_URL/findings/$FINDING_ID/status" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"status": "IGNORED", "comment": "API test accepted this risk for demo purposes.", "reviewed_by": "api-test-reviewer"}'

# Expected HTTP 400.
# Expected JSON behavior: error object indicating status must be OPEN, REVIEWED, or IGNORED.
run_curl "15_patch_finding_invalid_status" \
  curl -X PATCH "$BASE_URL/findings/$FINDING_ID/status" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"status": "RESOLVED", "comment": "Resolved should not be manually selectable.", "reviewed_by": "api-test-reviewer"}'

# Expected HTTP 400.
# Expected JSON behavior: error object indicating a comment is required when setting status to IGNORED.
run_curl "16_patch_finding_ignored_missing_comment" \
  curl -X PATCH "$BASE_URL/findings/$FINDING_ID/status" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"status": "IGNORED", "reviewed_by": "api-test-reviewer"}'

# Expected HTTP 404.
# Expected JSON behavior: error object with FINDING_NOT_FOUND for an invalid finding ID.
run_curl "17_patch_finding_invalid_id" \
  curl -X PATCH "$BASE_URL/findings/999999999/status" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"status": "REVIEWED", "comment": "Invalid ID negative test.", "reviewed_by": "api-test-reviewer"}'

print_section "Advisory AI Endpoints"

# Expected HTTP 201.
# Expected JSON behavior: response includes advisoryId, runId, bomId, scope BOM, and status COMPLETED; AI_ADVISORIES stores a local mock advisory record linked to a BOM advisory run.
run_curl "18_post_bom_advisory_happy" \
  curl -X POST "$BASE_URL/boms/$BOM_ID/advisories" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"requested_by": "api-test-reviewer", "summary_prompt": "Summarize the highest-risk validation issues for release review."}'

# Expected HTTP 404.
# Expected JSON behavior: error object with BOM_NOT_FOUND for an invalid BOM ID.
run_curl "19_post_bom_advisory_invalid_bom" \
  curl -X POST "$BASE_URL/boms/999999999/advisories" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"requested_by": "api-test-reviewer", "summary_prompt": "Invalid BOM negative test."}'

# Expected HTTP 201.
# Expected JSON behavior: response includes advisoryId, runId, findingId, bomId, scope FINDING, and status COMPLETED; AI_ADVISORIES stores a local mock advisory record linked to the selected finding.
run_curl "20_post_finding_advisory_happy" \
  curl -X POST "$BASE_URL/findings/$FINDING_ID/advisories" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"requested_by": "api-test-reviewer", "question": "Explain this finding and suggest what the reviewer should inspect first."}'

# Expected HTTP 404.
# Expected JSON behavior: error object with FINDING_NOT_FOUND for an invalid finding ID.
run_curl "21_post_finding_advisory_invalid_finding" \
  curl -X POST "$BASE_URL/findings/999999999/advisories" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"requested_by": "api-test-reviewer", "question": "Invalid finding negative test."}'

print_section "Fresh Readback After Writes"

# Expected HTTP 200.
# Expected JSON behavior: BOM detail reflects the latest health score, finding statuses, and newly created advisory-related run history.
run_curl "22_get_bom_detail_final_readback" \
  curl -X GET "$BASE_URL/boms/$BOM_ID" \
  -H "Accept: application/json"

# Expected HTTP 200.
# Expected JSON behavior: run history includes validation and advisory runs created by this script.
run_curl "23_get_bom_runs_final_readback" \
  curl -X GET "$BASE_URL/boms/$BOM_ID/runs" \
  -H "Accept: application/json"

print_section "Done"
printf 'Responses saved in %s\n' "$OUT_DIR"
