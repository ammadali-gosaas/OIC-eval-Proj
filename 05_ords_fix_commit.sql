SET DEFINE OFF
SET SERVEROUTPUT ON

PROMPT Re-enabling BOM_APP_USER schema and defining complete BOM validation ORDS API module

BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'ZA_SCHEMA',
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'bom',
        p_auto_rest_auth      => FALSE
    );
END;
/

BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'bom_api');
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/

BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'bom_api',
        p_base_path      => '/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED',
        p_comments       => 'BOM Validation and Anomaly Detection Prototype API'
    );

    --------------------------------------------------------------------
    -- 1. DASHBOARD ENDPOINTS
    --------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'dashboard');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'dashboard',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 0,
        p_source         => q'[
SELECT JSON_OBJECT(
           'summary' VALUE JSON_OBJECT(
               'totalBoms' VALUE (SELECT COUNT(*) FROM boms),
               'healthyBoms' VALUE (SELECT COUNT(*) FROM boms WHERE status_label = 'HEALTHY'),
               'riskyBoms' VALUE (SELECT COUNT(*) FROM boms WHERE status_label = 'RISKY'),
               'averageHealthScore' VALUE (SELECT ROUND(NVL(AVG(health_score), 0), 2) FROM boms),
               'openFindings' VALUE (SELECT COUNT(*) FROM validation_findings WHERE issue_status IN ('OPEN', 'REVIEWED'))
           ),
           'severityCounts' VALUE (
               SELECT JSON_ARRAYAGG(JSON_OBJECT('severity' VALUE severity, 'findingCount' VALUE finding_count) ORDER BY severity RETURNING CLOB)
                 FROM (SELECT r.severity, COUNT(*) finding_count FROM validation_findings f JOIN validation_rules r ON r.rule_id = f.rule_id WHERE f.issue_status IN ('OPEN', 'REVIEWED') GROUP BY r.severity)
           ),
           'itemClassSummary' VALUE (
               SELECT JSON_ARRAYAGG(JSON_OBJECT('itemClass' VALUE item_class, 'bomCount' VALUE bom_count, 'riskyCount' VALUE risky_count, 'averageHealthScore' VALUE average_health_score) ORDER BY item_class RETURNING CLOB)
                 FROM (SELECT NVL(item_class, 'UNCLASSIFIED') item_class, 
                              COUNT(*) bom_count, 
                              COUNT(CASE WHEN health_score < 100 THEN 1 END) risky_count, 
                              ROUND(AVG(health_score), 2) average_health_score 
                         FROM boms 
                        GROUP BY NVL(item_class, 'UNCLASSIFIED'))
           )
           RETURNING CLOB
       ) dashboard_json FROM dual
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'dashboard/refresh');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'dashboard/refresh',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'[
BEGIN
    :status_code := 202;
END;
        ]'
    );

    --------------------------------------------------------------------
    -- 2. BOM SUMMARY & DETAIL ENDPOINTS
    --------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'boms');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'boms',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'[
SELECT b.bom_id, b.organization_code, b.item_number, b.structure_name, b.description, b.item_class, b.health_score, b.status_label, b.imported_at,
       COUNT(c.bom_component_id) component_count,
       (SELECT COUNT(*) FROM bom_runs br JOIN validation_findings vf ON vf.run_id = br.run_id WHERE br.bom_id = b.bom_id AND vf.issue_status IN ('OPEN', 'REVIEWED')) open_finding_count,
       (SELECT LISTAGG(DISTINCT vr.severity, ',') WITHIN GROUP (ORDER BY vr.severity)
          FROM bom_runs br
          JOIN validation_findings vf ON vf.run_id = br.run_id
          JOIN validation_rules vr ON vr.rule_id = vf.rule_id
         WHERE br.bom_id = b.bom_id
           AND vf.issue_status IN ('OPEN', 'REVIEWED')) finding_severities
  FROM boms b LEFT JOIN bom_components c ON c.bom_id = b.bom_id
 WHERE (:search_text IS NULL OR UPPER(b.item_number) LIKE '%' || UPPER(:search_text) || '%' OR UPPER(NVL(b.description, '')) LIKE '%' || UPPER(:search_text) || '%')
   AND (:status_label IS NULL OR b.status_label = :status_label)
   AND (:item_class IS NULL OR b.item_class = :item_class)
   AND (:severity IS NULL OR EXISTS (SELECT 1 FROM bom_runs br JOIN validation_findings vf ON vf.run_id = br.run_id JOIN validation_rules vr ON vr.rule_id = vf.rule_id WHERE br.bom_id = b.bom_id AND vr.severity = :severity AND vf.issue_status IN ('OPEN', 'REVIEWED')))
 GROUP BY b.bom_id, b.organization_code, b.item_number, b.structure_name, b.description, b.item_class, b.health_score, b.status_label, b.imported_at
 ORDER BY b.health_score ASC, b.item_number
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'boms/:bom_id');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'boms/:bom_id',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 0,
        p_source         => q'[
SELECT JSON_OBJECT(
           'bom' VALUE JSON_OBJECT('bomId' VALUE b.bom_id, 'billSequenceId' VALUE b.bill_sequence_id, 'organizationCode' VALUE b.organization_code, 'itemNumber' VALUE b.item_number, 'structureName' VALUE b.structure_name, 'description' VALUE b.description, 'effectivityControl' VALUE b.effectivity_control, 'sourceUpdatedAt' VALUE TO_CHAR(b.source_updated_at, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM'), 'importBatchId' VALUE b.import_batch_id, 'importedAt' VALUE TO_CHAR(b.imported_at, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM'), 'itemClass' VALUE b.item_class, 'healthScore' VALUE b.health_score, 'statusLabel' VALUE b.status_label),
           'components' VALUE (SELECT JSON_ARRAYAGG(JSON_OBJECT('bomComponentId' VALUE c.bom_component_id, 'componentSequenceId' VALUE c.component_sequence_id, 'parentItemNumber' VALUE c.parent_item_number, 'componentItemNumber' VALUE c.component_item_number, 'componentItemClass' VALUE c.component_item_class, 'quantity' VALUE c.quantity, 'uomCode' VALUE c.uom_code, 'itemSequenceNumber' VALUE c.item_sequence_number, 'operationSequence' VALUE c.operation_sequence, 'itemStatus' VALUE c.item_status, 'bomLevel' VALUE c.bom_level, 'componentPath' VALUE c.component_path, 'anomalyMinQuantity' VALUE c.anomaly_min_quantity, 'anomalyMaxQuantity' VALUE c.anomaly_max_quantity) ORDER BY c.bom_level, c.item_sequence_number, c.bom_component_id RETURNING CLOB) FROM bom_components c WHERE c.bom_id = b.bom_id),
           'findings' VALUE (SELECT JSON_ARRAYAGG(JSON_OBJECT('findingId' VALUE vf.finding_id, 'runId' VALUE vf.run_id, 'bomComponentId' VALUE vf.bom_component_id, 'ruleCode' VALUE vr.rule_code, 'ruleName' VALUE vr.rule_name, 'severity' VALUE vr.severity, 'findingKey' VALUE vf.finding_key, 'issueStatus' VALUE vf.issue_status, 'actualValue' VALUE vf.actual_value, 'expectedValue' VALUE vf.expected_value, 'evidence' VALUE vf.evidence_json FORMAT JSON, 'createdAt' VALUE TO_CHAR(vf.created_at, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')) ORDER BY vf.created_at DESC, vf.finding_id DESC RETURNING CLOB) FROM bom_runs br JOIN validation_findings vf ON vf.run_id = br.run_id JOIN validation_rules vr ON vr.rule_id = vf.rule_id WHERE br.bom_id = b.bom_id)
           RETURNING CLOB
       ) bom_detail_json FROM boms b WHERE b.bom_id = TO_NUMBER(:bom_id DEFAULT NULL ON CONVERSION ERROR)
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'boms/:bom_id/refresh');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'boms/:bom_id/refresh',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'[
DECLARE
    v_bom_id       NUMBER := TO_NUMBER(:bom_id DEFAULT NULL ON CONVERSION ERROR);
    v_requested_by VARCHAR2(200) := NVL(:requested_by, 'ords-local-user');
    v_run_id       NUMBER;
    v_corr_id      VARCHAR2(100);
    v_now          TIMESTAMP(6) WITH TIME ZONE;
BEGIN
    SELECT SYSTIMESTAMP AT TIME ZONE 'UTC' INTO v_now FROM dual;
    v_corr_id := 'REFRESH-' || TO_CHAR(v_now, 'YYYYMMDDHH24MISSFF3') || '-' || RAWTOHEX(SYS_GUID());
    INSERT INTO bom_runs (bom_id, run_kind, trigger_type, status, source_mode, correlation_id, requested_by, started_at, completed_at, input_count, finding_count)
    VALUES (v_bom_id, 'REFRESH', 'UI_REFRESH', 'COMPLETED', 'MOCK', v_corr_id, v_requested_by, v_now, v_now, 1, 0)
    RETURNING run_id INTO v_run_id;
    COMMIT;
    :status_code := 201;
EXCEPTION WHEN OTHERS THEN ROLLBACK; :status_code := 400;
END;
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'boms/:bom_id/runs');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'boms/:bom_id/runs',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'[
SELECT run_id, bom_id, run_kind, trigger_type, status, source_mode, idempotency_key, correlation_id, requested_by, started_at, completed_at, input_count, finding_count, health_score, error_code, error_message
  FROM bom_runs WHERE bom_id = TO_NUMBER(:bom_id DEFAULT NULL ON CONVERSION ERROR) ORDER BY started_at DESC, run_id DESC
        ]'
    );

    --------------------------------------------------------------------
    -- 3. VALIDATION EXECUTION ENDPOINTS
    --------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'bom_api',
        p_pattern     => 'validation-runs'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'validation-runs',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'[
SELECT br.run_id, br.bom_id, b.item_number, br.run_kind, br.trigger_type, br.status, br.source_mode, br.correlation_id, br.requested_by, br.started_at, br.completed_at, br.input_count, br.finding_count
  FROM bom_runs br JOIN boms b ON b.bom_id = br.bom_id
 ORDER BY br.started_at DESC, br.run_id DESC
        ]'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'validation-runs',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'[
DECLARE
    v_bom_id       NUMBER := :bom_id;
    v_requested_by VARCHAR2(200) := NVL(:requested_by, 'ords-local-user');
BEGIN
    IF v_bom_id IS NULL THEN 
        RAISE_APPLICATION_ERROR(-20020, 'JSON payload must include numeric bom_id.'); 
    END IF;
    
    BOM_VALIDATION_PKG.run_full_validation(v_bom_id, v_requested_by);
    :status_code := 201;
EXCEPTION 
    WHEN OTHERS THEN 
        :status_code := 400;
END;
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'validation-runs/:run_id');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'validation-runs/:run_id',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 0,
        p_source         => q'[
SELECT br.run_id, br.bom_id, b.organization_code, b.item_number, br.run_kind, br.trigger_type, br.status, br.source_mode, br.correlation_id, br.requested_by, br.started_at, br.completed_at, br.input_count, br.finding_count, br.health_score, br.error_code, br.error_message
  FROM bom_runs br JOIN boms b ON b.bom_id = br.bom_id WHERE br.run_id = TO_NUMBER(:run_id DEFAULT NULL ON CONVERSION ERROR)
        ]'
    );

    --------------------------------------------------------------------
    -- 4. FINDING REVIEW & ADVISORY ENDPOINTS
    --------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'findings/:finding_id/status');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'findings/:finding_id/status',
        p_method        => 'PATCH',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'[
DECLARE
    v_finding_id   NUMBER := TO_NUMBER(:finding_id DEFAULT NULL ON CONVERSION ERROR);
    v_new_status   VARCHAR2(20) := UPPER(TRIM(:status));
    v_comment      VARCHAR2(4000) := :comment;
    v_reviewed_by  VARCHAR2(200) := NVL(:reviewed_by, 'ords-local-user');
    v_old_status   validation_findings.issue_status%TYPE;
    v_bom_id       boms.bom_id%TYPE;
    v_health_score boms.health_score%TYPE;
BEGIN
    IF v_finding_id IS NULL THEN RAISE_APPLICATION_ERROR(-20012, 'Path parameter finding_id must be numeric.'); END IF;
    IF v_new_status NOT IN ('OPEN', 'REVIEWED', 'IGNORED') THEN RAISE_APPLICATION_ERROR(-20010, 'Status must be OPEN, REVIEWED, or IGNORED.'); END IF;
    IF v_new_status = 'IGNORED' AND TRIM(v_comment) IS NULL THEN RAISE_APPLICATION_ERROR(-20011, 'Comment is required when status is IGNORED.'); END IF;

    SELECT vf.issue_status, br.bom_id INTO v_old_status, v_bom_id FROM validation_findings vf JOIN bom_runs br ON br.run_id = vf.run_id WHERE vf.finding_id = v_finding_id FOR UPDATE OF vf.issue_status;
    UPDATE validation_findings SET issue_status = v_new_status WHERE finding_id = v_finding_id;
    INSERT INTO finding_reviews (finding_id, old_status, new_status, review_comment, reviewed_by, reviewed_at) VALUES (v_finding_id, v_old_status, v_new_status, v_comment, v_reviewed_by, SYSTIMESTAMP AT TIME ZONE 'UTC');

    SELECT GREATEST(0, 100 - NVL(SUM(CASE vr.severity WHEN 'CRITICAL' THEN 25 WHEN 'HIGH' THEN 10 WHEN 'WARNING' THEN 5 ELSE 0 END), 0))
      INTO v_health_score FROM validation_findings vf JOIN validation_rules vr ON vr.rule_id = vf.rule_id JOIN bom_runs br ON br.run_id = vf.run_id WHERE br.bom_id = v_bom_id AND vf.issue_status IN ('OPEN', 'REVIEWED');

    UPDATE boms SET health_score = v_health_score, status_label = CASE WHEN v_health_score = 100 THEN 'HEALTHY' ELSE 'RISKY' END WHERE bom_id = v_bom_id;
    COMMIT;
    :status_code := 200;
EXCEPTION WHEN NO_DATA_FOUND THEN :status_code := 404; WHEN OTHERS THEN ROLLBACK; :status_code := 400;
END;
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'boms/:bom_id/advisories');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'boms/:bom_id/advisories',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'[
DECLARE
    v_bom_id NUMBER := TO_NUMBER(:bom_id DEFAULT NULL ON CONVERSION ERROR);
    v_requested_by VARCHAR2(200) := NVL(:requested_by, 'ords-local-user');
    v_run_id NUMBER; v_advisory_id NUMBER; v_finding_cnt NUMBER; v_score NUMBER; v_corr_id VARCHAR2(100); v_now TIMESTAMP(6) WITH TIME ZONE;
BEGIN
    IF v_bom_id IS NULL THEN RAISE_APPLICATION_ERROR(-20021, 'Path parameter bom_id must be numeric.'); END IF;
    SELECT SYSTIMESTAMP AT TIME ZONE 'UTC' INTO v_now FROM dual;
    SELECT health_score INTO v_score FROM boms WHERE bom_id = v_bom_id;
    SELECT COUNT(*) INTO v_finding_cnt FROM bom_runs br JOIN validation_findings vf ON vf.run_id = br.run_id WHERE br.bom_id = v_bom_id AND vf.issue_status IN ('OPEN', 'REVIEWED');
    v_corr_id := 'AI-BOM-' || TO_CHAR(v_now, 'YYYYMMDDHH24MISSFF3') || '-' || RAWTOHEX(SYS_GUID());

    INSERT INTO bom_runs (bom_id, run_kind, trigger_type, status, source_mode, correlation_id, requested_by, started_at, completed_at, input_count, finding_count, health_score)
    VALUES (v_bom_id, 'ADVISORY_AI', 'USER_AI', 'COMPLETED', 'N/A', v_corr_id, v_requested_by, v_now, v_now, v_finding_cnt, v_finding_cnt, v_score)
    RETURNING run_id INTO v_run_id;

    INSERT INTO ai_advisories (run_id, finding_id, advisory_scope, ai_status, ai_summary, ai_suggested_action, ai_provider, requested_by, generated_at)
    VALUES (v_run_id, NULL, 'BOM', 'COMPLETED', 'Mock Advisory AI summary for BOM ' || v_bom_id || '. Health score: ' || v_score, 'Review critical and high severity findings.', 'LOCAL_MOCK', v_requested_by, v_now)
    RETURNING advisory_id INTO v_advisory_id;

    COMMIT;
    :status_code := 201;
EXCEPTION WHEN NO_DATA_FOUND THEN :status_code := 404; WHEN OTHERS THEN ROLLBACK; :status_code := 400;
END;
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'findings/:finding_id/advisories');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'findings/:finding_id/advisories',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'[
DECLARE
    v_finding_id NUMBER := TO_NUMBER(:finding_id DEFAULT NULL ON CONVERSION ERROR);
    v_requested_by VARCHAR2(200) := NVL(:requested_by, 'ords-local-user');
    v_bom_id NUMBER; v_run_id NUMBER; v_advisory_id NUMBER; v_corr_id VARCHAR2(100); v_rule_code VARCHAR2(50); v_actual VARCHAR2(1000); v_expected VARCHAR2(1000); v_now TIMESTAMP(6) WITH TIME ZONE;
BEGIN
    IF v_finding_id IS NULL THEN RAISE_APPLICATION_ERROR(-20022, 'Path parameter finding_id must be numeric.'); END IF;
    SELECT SYSTIMESTAMP AT TIME ZONE 'UTC' INTO v_now FROM dual;
    SELECT br.bom_id, vr.rule_code, vf.actual_value, vf.expected_value INTO v_bom_id, v_rule_code, v_actual, v_expected FROM validation_findings vf JOIN validation_rules vr ON vr.rule_id = vf.rule_id JOIN bom_runs br ON br.run_id = vf.run_id WHERE vf.finding_id = v_finding_id;
    v_corr_id := 'AI-FINDING-' || TO_CHAR(v_now, 'YYYYMMDDHH24MISSFF3') || '-' || RAWTOHEX(SYS_GUID());

    INSERT INTO bom_runs (bom_id, run_kind, trigger_type, status, source_mode, correlation_id, requested_by, started_at, completed_at, input_count, finding_count)
    VALUES (v_bom_id, 'ADVISORY_AI', 'USER_AI', 'COMPLETED', 'N/A', v_corr_id, v_requested_by, v_now, v_now, 1, 1) RETURNING run_id INTO v_run_id;

    INSERT INTO ai_advisories (run_id, finding_id, advisory_scope, ai_status, ai_summary, ai_suggested_action, ai_provider, requested_by, generated_at)
    VALUES (v_run_id, v_finding_id, 'FINDING', 'COMPLETED', 'Mock Advisory AI explanation for finding ' || v_finding_id || ' (' || v_rule_code || ').', 'Inspect component evidence before release.', 'LOCAL_MOCK', v_requested_by, v_now) RETURNING advisory_id INTO v_advisory_id;

    COMMIT;
    :status_code := 201;
EXCEPTION WHEN NO_DATA_FOUND THEN :status_code := 404; WHEN OTHERS THEN ROLLBACK; :status_code := 400;
END;
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'advisories/:requestId');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'advisories/:requestId',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 0,
        p_source         => q'[
SELECT advisory_id, run_id, finding_id, advisory_scope, ai_status, ai_summary, ai_suggested_action, ai_provider, requested_by, generated_at
  FROM ai_advisories WHERE advisory_id = TO_NUMBER(:requestId DEFAULT NULL ON CONVERSION ERROR)
        ]'
    );

    --------------------------------------------------------------------
    -- 5. RULES & DIAGNOSTICS ENDPOINTS
    --------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'rules');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'rules',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'[
SELECT rule_id, rule_code, rule_name, severity, description, threshold_or_configuration, enabled_flag, created_at, updated_at FROM validation_rules ORDER BY rule_code
        ]'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'rules',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'[
DECLARE
    v_code VARCHAR2(50) := :rule_code; v_name VARCHAR2(200) := :rule_name; v_severity VARCHAR2(20) := UPPER(TRIM(:severity)); v_desc VARCHAR2(1000) := :description; v_thresh VARCHAR2(1000) := :threshold_or_configuration; v_rule_id NUMBER;
BEGIN
    INSERT INTO validation_rules (rule_code, rule_name, severity, description, threshold_or_configuration, enabled_flag, created_at)
    VALUES (v_code, v_name, v_severity, NVL(v_desc, 'Custom Prototype Rule'), v_thresh, 'Y', SYSTIMESTAMP AT TIME ZONE 'UTC') RETURNING rule_id INTO v_rule_id;
    COMMIT;
    :status_code := 201;
EXCEPTION WHEN OTHERS THEN ROLLBACK; :status_code := 400;
END;
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'diagnostics/runs');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'diagnostics/runs',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'[
SELECT log_id, correlation_id, related_run_id, related_finding_id, component_code, stage, source_mode, status, occurred_at, duration_ms, event_level, error_code, details
  FROM diagnostic_logs ORDER BY occurred_at DESC, log_id DESC
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'findings');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'findings',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'[
SELECT vf.finding_id, vf.run_id, vf.bom_component_id, b.bom_id, b.item_number, vr.rule_code, vr.rule_name, vr.severity, vf.issue_status, vf.actual_value, vf.expected_value, vf.evidence_json, vf.created_at
  FROM validation_findings vf
  JOIN validation_rules vr ON vr.rule_id = vf.rule_id
  JOIN bom_runs br ON br.run_id = vf.run_id
  JOIN boms b ON b.bom_id = br.bom_id
 WHERE (:issue_status IS NULL OR vf.issue_status = :issue_status)
   AND (:severity IS NULL OR vr.severity = :severity)
   AND (:rule_code IS NULL OR vr.rule_code = :rule_code)
 ORDER BY vf.created_at DESC
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'schedules');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'schedules',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'[
    DECLARE
        v_time     VARCHAR2(10) := :time;
        v_interval VARCHAR2(20) := :interval;
        v_job_name VARCHAR2(100);
        v_sql      VARCHAR2(4000);
        v_freq     VARCHAR2(50);
    BEGIN
        v_job_name := 'BOM_VAL_JOB_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS');

        IF UPPER(v_interval) = 'WEEKLY' THEN
            v_freq := 'FREQ=WEEKLY; ';
        ELSE
            v_freq := 'FREQ=DAILY; ';
        END IF;

        v_sql := 'BEGIN ' ||
                '  FOR b IN (SELECT bom_id FROM boms) LOOP ' ||
                '    BOM_VALIDATION_PKG.run_full_validation(b.bom_id, ''System Scheduler''); ' ||
                '  END LOOP; ' ||
                'END;';

        DBMS_SCHEDULER.CREATE_JOB (
            job_name        => v_job_name,
            job_type        => 'PLSQL_BLOCK',
            job_action      => v_sql,
            start_date      => SYSTIMESTAMP,
            repeat_interval => v_freq || 'BYHOUR=' || SUBSTR(v_time, 1, 2) || '; BYMINUTE=' || SUBSTR(v_time, 4, 2) || ';',
            enabled         => TRUE,
            comments        => 'Scheduled via VBCS UI Dashboard'
        );

        :status_code := 201;
    EXCEPTION 
        WHEN OTHERS THEN 
            :status_code := 400;
    END;
        ]'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'rules/:rule_id');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'rules/:rule_id',
        p_method        => 'PUT',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'[
DECLARE
    v_rule_id NUMBER := TO_NUMBER(:rule_id DEFAULT NULL ON CONVERSION ERROR);
    v_name VARCHAR2(200) := :rule_name;
    v_severity VARCHAR2(20) := UPPER(TRIM(:severity));
    v_desc VARCHAR2(1000) := :description;
    v_thresh VARCHAR2(1000) := :threshold_or_configuration;
    v_enabled CHAR(1) := NVL(UPPER(TRIM(:enabled_flag)), 'Y');
BEGIN
    IF v_rule_id IS NULL THEN RAISE_APPLICATION_ERROR(-20023, 'Path parameter rule_id must be numeric.'); END IF;
    
    UPDATE validation_rules 
       SET rule_name = NVL(v_name, rule_name),
           severity = NVL(v_severity, severity),
           description = NVL(v_desc, description),
           threshold_or_configuration = NVL(v_thresh, threshold_or_configuration),
           enabled_flag = v_enabled,
           updated_at = SYSTIMESTAMP AT TIME ZONE 'UTC'
     WHERE rule_id = v_rule_id;
     
    IF SQL%ROWCOUNT = 0 THEN
        :status_code := 404;
    ELSE
        COMMIT;
        :status_code := 200;
    END IF;
EXCEPTION 
    WHEN OTHERS THEN ROLLBACK; :status_code := 400;
END;
        ]'
    );


    COMMIT;
END;
/

PROMPT Master 05_ords_fix_commit.sql installation complete!