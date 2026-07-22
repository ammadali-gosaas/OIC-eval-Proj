SET DEFINE OFF
SET SERVEROUTPUT ON

PROMPT Re-enabling BOM_APP_USER schema and redefining BOM validation ORDS endpoints

BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'BOM_APP_USER',
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

    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'bom_api',
        p_pattern     => 'dashboard',
        p_comments    => 'Dashboard health, risk, severity, and item-class summaries'
    );

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
               'openFindings' VALUE (
                   SELECT COUNT(*)
                     FROM validation_findings
                    WHERE issue_status IN ('OPEN', 'REVIEWED')
               )
           ),
           'severityCounts' VALUE (
               SELECT JSON_ARRAYAGG(
                          JSON_OBJECT(
                              'severity' VALUE severity,
                              'findingCount' VALUE finding_count
                          )
                          ORDER BY severity
                          RETURNING CLOB
                      )
                 FROM (
                       SELECT r.severity, COUNT(*) finding_count
                         FROM validation_findings f
                         JOIN validation_rules r ON r.rule_id = f.rule_id
                        WHERE f.issue_status IN ('OPEN', 'REVIEWED')
                        GROUP BY r.severity
                      )
           ),
           'itemClassSummary' VALUE (
               SELECT JSON_ARRAYAGG(
                          JSON_OBJECT(
                              'itemClass' VALUE item_class,
                              'bomCount' VALUE bom_count,
                              'averageHealthScore' VALUE average_health_score
                          )
                          ORDER BY item_class
                          RETURNING CLOB
                      )
                 FROM (
                       SELECT NVL(item_class, 'UNCLASSIFIED') item_class,
                              COUNT(*) bom_count,
                              ROUND(AVG(health_score), 2) average_health_score
                         FROM boms
                        GROUP BY NVL(item_class, 'UNCLASSIFIED')
                      )
           )
           RETURNING CLOB
       ) dashboard_json
  FROM dual
        ]'
    );

    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'bom_api',
        p_pattern     => 'boms',
        p_comments    => 'Searchable BOM summaries'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'boms',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'[
SELECT b.bom_id,
       b.organization_code,
       b.item_number,
       b.structure_name,
       b.description,
       b.item_class,
       b.health_score,
       b.status_label,
       b.imported_at,
       COUNT(c.bom_component_id) component_count,
       (
           SELECT COUNT(*)
             FROM bom_runs br
             JOIN validation_findings vf ON vf.run_id = br.run_id
            WHERE br.bom_id = b.bom_id
              AND vf.issue_status IN ('OPEN', 'REVIEWED')
       ) open_finding_count
  FROM boms b
  LEFT JOIN bom_components c ON c.bom_id = b.bom_id
 WHERE (:q IS NULL OR UPPER(b.item_number || ' ' || b.organization_code || ' ' || NVL(b.description, '')) LIKE '%' || UPPER(:q) || '%')
   AND (:organization_code IS NULL OR b.organization_code = :organization_code)
   AND (:status_label IS NULL OR b.status_label = :status_label)
 GROUP BY b.bom_id,
          b.organization_code,
          b.item_number,
          b.structure_name,
          b.description,
          b.item_class,
          b.health_score,
          b.status_label,
          b.imported_at
 ORDER BY b.health_score ASC, b.item_number
        ]'
    );

    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'bom_api',
        p_pattern     => 'boms/:bom_id',
        p_comments    => 'BOM detail with components and findings'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'boms/:bom_id',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 0,
        p_source         => q'[
SELECT JSON_OBJECT(
           'bom' VALUE JSON_OBJECT(
               'bomId' VALUE b.bom_id,
               'billSequenceId' VALUE b.bill_sequence_id,
               'organizationCode' VALUE b.organization_code,
               'itemNumber' VALUE b.item_number,
               'structureName' VALUE b.structure_name,
               'description' VALUE b.description,
               'effectivityControl' VALUE b.effectivity_control,
               'sourceUpdatedAt' VALUE TO_CHAR(b.source_updated_at, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM'),
               'importBatchId' VALUE b.import_batch_id,
               'importedAt' VALUE TO_CHAR(b.imported_at, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM'),
               'itemClass' VALUE b.item_class,
               'healthScore' VALUE b.health_score,
               'statusLabel' VALUE b.status_label
           ),
           'components' VALUE (
               SELECT JSON_ARRAYAGG(
                          JSON_OBJECT(
                              'bomComponentId' VALUE c.bom_component_id,
                              'componentSequenceId' VALUE c.component_sequence_id,
                              'parentItemNumber' VALUE c.parent_item_number,
                              'componentItemNumber' VALUE c.component_item_number,
                              'componentItemClass' VALUE c.component_item_class,
                              'quantity' VALUE c.quantity,
                              'uomCode' VALUE c.uom_code,
                              'itemSequenceNumber' VALUE c.item_sequence_number,
                              'operationSequence' VALUE c.operation_sequence,
                              'itemStatus' VALUE c.item_status,
                              'bomLevel' VALUE c.bom_level,
                              'componentPath' VALUE c.component_path,
                              'anomalyMinQuantity' VALUE c.anomaly_min_quantity,
                              'anomalyMaxQuantity' VALUE c.anomaly_max_quantity
                          )
                          ORDER BY c.bom_level, c.item_sequence_number, c.bom_component_id
                          RETURNING CLOB
                      )
                 FROM bom_components c
                WHERE c.bom_id = b.bom_id
           ),
           'findings' VALUE (
               SELECT JSON_ARRAYAGG(
                          JSON_OBJECT(
                              'findingId' VALUE vf.finding_id,
                              'runId' VALUE vf.run_id,
                              'bomComponentId' VALUE vf.bom_component_id,
                              'ruleCode' VALUE vr.rule_code,
                              'ruleName' VALUE vr.rule_name,
                              'severity' VALUE vr.severity,
                              'findingKey' VALUE vf.finding_key,
                              'issueStatus' VALUE vf.issue_status,
                              'actualValue' VALUE vf.actual_value,
                              'expectedValue' VALUE vf.expected_value,
                              'evidence' VALUE vf.evidence_json FORMAT JSON,
                              'createdAt' VALUE TO_CHAR(vf.created_at, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')
                          )
                          ORDER BY vf.created_at DESC, vf.finding_id DESC
                          RETURNING CLOB
                      )
                 FROM bom_runs br
                 JOIN validation_findings vf ON vf.run_id = br.run_id
                 JOIN validation_rules vr ON vr.rule_id = vf.rule_id
                WHERE br.bom_id = b.bom_id
           )
           RETURNING CLOB
       ) bom_detail_json
  FROM boms b
 WHERE b.bom_id = :bom_id
        ]'
    );

    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'bom_api',
        p_pattern     => 'boms/:bom_id/runs',
        p_comments    => 'BOM validation, refresh, import, and advisory run history'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'boms/:bom_id/runs',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'[
SELECT run_id,
       bom_id,
       run_kind,
       trigger_type,
       status,
       source_mode,
       idempotency_key,
       correlation_id,
       requested_by,
       started_at,
       completed_at,
       input_count,
       finding_count,
       health_score,
       error_code,
       error_message
  FROM bom_runs
 WHERE bom_id = :bom_id
 ORDER BY started_at DESC, run_id DESC
        ]'
    );

    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'bom_api',
        p_pattern     => 'validation-runs',
        p_comments    => 'Start a selected-BOM validation run'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'bom_api',
        p_pattern     => 'validation-runs',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
DECLARE
    v_bom_id       NUMBER := TO_NUMBER(:bom_id);
    v_requested_by VARCHAR2(200) := NVL(:requested_by, 'ords-local-user');
    v_run_id       NUMBER;
    v_err_msg      VARCHAR2(4000);
BEGIN
    BOM_VALIDATION_PKG.run_full_validation(v_bom_id, v_requested_by);

    SELECT MAX(run_id)
      INTO v_run_id
      FROM bom_runs
     WHERE bom_id = v_bom_id
       AND run_kind = 'VALIDATION'
       AND requested_by = v_requested_by;

    :status_code := 201;
    OWA_UTIL.mime_header('application/json', FALSE);
    HTP.P('Cache-Control: no-cache');
    OWA_UTIL.http_header_close;
    HTP.P(JSON_OBJECT(
        'message' VALUE 'Validation completed',
        'bomId' VALUE v_bom_id,
        'runId' VALUE v_run_id,
        'requestedBy' VALUE v_requested_by
        RETURNING CLOB
    ));
EXCEPTION
    WHEN OTHERS THEN
        v_err_msg := SUBSTR(SQLERRM, 1, 4000);
        :status_code := 400;
        OWA_UTIL.mime_header('application/json', FALSE);
        OWA_UTIL.http_header_close;
        HTP.P(JSON_OBJECT(
            'error' VALUE 'VALIDATION_RUN_FAILED',
            'message' VALUE SUBSTR(v_err_msg, 1, 1000)
            RETURNING CLOB
        ));
END;
        ]'
    );

    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'bom_api',
        p_pattern     => 'validation-runs/:run_id',
        p_comments    => 'Poll validation run status and summary'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'validation-runs/:run_id',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 0,
        p_source         => q'[
SELECT br.run_id,
       br.bom_id,
       b.organization_code,
       b.item_number,
       br.run_kind,
       br.trigger_type,
       br.status,
       br.source_mode,
       br.correlation_id,
       br.requested_by,
       br.started_at,
       br.completed_at,
       br.input_count,
       br.finding_count,
       br.health_score,
       br.error_code,
       br.error_message
  FROM bom_runs br
  JOIN boms b ON b.bom_id = br.bom_id
 WHERE br.run_id = :run_id
        ]'
    );

    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'bom_api',
        p_pattern     => 'findings/:finding_id/status',
        p_comments    => 'Update finding status and record review history'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'bom_api',
        p_pattern     => 'findings/:finding_id/status',
        p_method      => 'PATCH',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
DECLARE
    v_finding_id   NUMBER := TO_NUMBER(:finding_id);
    v_new_status   VARCHAR2(20) := UPPER(TRIM(:status));
    v_comment      VARCHAR2(4000) := :comment;
    v_reviewed_by  VARCHAR2(200) := NVL(:reviewed_by, 'ords-local-user');
    v_old_status   validation_findings.issue_status%TYPE;
    v_bom_id       boms.bom_id%TYPE;
    v_health_score boms.health_score%TYPE;
    v_err_msg      VARCHAR2(4000);
BEGIN
    IF v_new_status NOT IN ('OPEN', 'REVIEWED', 'IGNORED') THEN
        RAISE_APPLICATION_ERROR(-20010, 'Status must be OPEN, REVIEWED, or IGNORED.');
    END IF;

    IF v_new_status = 'IGNORED' AND TRIM(v_comment) IS NULL THEN
        RAISE_APPLICATION_ERROR(-20011, 'Comment is required when status is IGNORED.');
    END IF;

    SELECT vf.issue_status, br.bom_id
      INTO v_old_status, v_bom_id
      FROM validation_findings vf
      JOIN bom_runs br ON br.run_id = vf.run_id
     WHERE vf.finding_id = v_finding_id
     FOR UPDATE OF vf.issue_status;

    UPDATE validation_findings
       SET issue_status = v_new_status
     WHERE finding_id = v_finding_id;

    INSERT INTO finding_reviews (
        finding_id,
        old_status,
        new_status,
        review_comment,
        reviewed_by,
        reviewed_at
    ) VALUES (
        v_finding_id,
        v_old_status,
        v_new_status,
        v_comment,
        v_reviewed_by,
        SYSTIMESTAMP AT TIME ZONE 'UTC'
    );

    SELECT GREATEST(0, 100 - NVL(SUM(
               CASE vr.severity
                   WHEN 'CRITICAL' THEN 25
                   WHEN 'HIGH' THEN 10
                   WHEN 'WARNING' THEN 5
                   ELSE 0
               END
           ), 0))
      INTO v_health_score
      FROM validation_findings vf
      JOIN validation_rules vr ON vr.rule_id = vf.rule_id
      JOIN bom_runs br ON br.run_id = vf.run_id
     WHERE br.bom_id = v_bom_id
       AND vf.issue_status IN ('OPEN', 'REVIEWED');

    UPDATE boms
       SET health_score = v_health_score,
           status_label = CASE WHEN v_health_score = 100 THEN 'HEALTHY' ELSE 'RISKY' END
     WHERE bom_id = v_bom_id;

    COMMIT;

    :status_code := 200;
    OWA_UTIL.mime_header('application/json', FALSE);
    OWA_UTIL.http_header_close;
    HTP.P(JSON_OBJECT(
        'findingId' VALUE v_finding_id,
        'oldStatus' VALUE v_old_status,
        'newStatus' VALUE v_new_status,
        'reviewedBy' VALUE v_reviewed_by,
        'bomId' VALUE v_bom_id,
        'healthScore' VALUE v_health_score
        RETURNING CLOB
    ));
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        :status_code := 404;
        OWA_UTIL.mime_header('application/json', FALSE);
        OWA_UTIL.http_header_close;
        HTP.P(JSON_OBJECT('error' VALUE 'FINDING_NOT_FOUND', 'findingId' VALUE v_finding_id RETURNING CLOB));
    WHEN OTHERS THEN
        ROLLBACK;
        v_err_msg := SUBSTR(SQLERRM, 1, 4000);
        :status_code := 400;
        OWA_UTIL.mime_header('application/json', FALSE);
        OWA_UTIL.http_header_close;
        HTP.P(JSON_OBJECT('error' VALUE 'FINDING_STATUS_UPDATE_FAILED', 'message' VALUE SUBSTR(v_err_msg, 1, 1000) RETURNING CLOB));
END;
        ]'
    );

    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'bom_api',
        p_pattern     => 'rules',
        p_comments    => 'Validation rule catalog'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'rules',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'[
SELECT rule_id,
       rule_code,
       rule_name,
       severity,
       description,
       threshold_or_configuration,
       enabled_flag,
       created_at,
       updated_at
  FROM validation_rules
 ORDER BY rule_code
        ]'
    );

    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'bom_api',
        p_pattern     => 'boms/:bom_id/advisories',
        p_comments    => 'Create a mock BOM-level advisory record'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'bom_api',
        p_pattern     => 'boms/:bom_id/advisories',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
DECLARE
    v_bom_id       NUMBER := TO_NUMBER(:bom_id);
    v_requested_by VARCHAR2(200) := NVL(:requested_by, 'ords-local-user');
    v_prompt       VARCHAR2(4000) := :summary_prompt;
    v_run_id       NUMBER;
    v_advisory_id  NUMBER;
    v_finding_cnt  NUMBER;
    v_score        NUMBER;
    v_corr_id      VARCHAR2(100);
    v_now          TIMESTAMP(6) WITH TIME ZONE;
    v_err_msg      VARCHAR2(4000);
BEGIN
    SELECT SYSTIMESTAMP AT TIME ZONE 'UTC'
      INTO v_now
      FROM dual;

    SELECT health_score
      INTO v_score
      FROM boms
     WHERE bom_id = v_bom_id;

    SELECT COUNT(*)
      INTO v_finding_cnt
      FROM bom_runs br
      JOIN validation_findings vf ON vf.run_id = br.run_id
     WHERE br.bom_id = v_bom_id
       AND vf.issue_status IN ('OPEN', 'REVIEWED');

    v_corr_id := 'AI-BOM-' || TO_CHAR(v_now, 'YYYYMMDDHH24MISSFF3') || '-' || RAWTOHEX(SYS_GUID());

    INSERT INTO bom_runs (
        bom_id,
        run_kind,
        trigger_type,
        status,
        source_mode,
        idempotency_key,
        correlation_id,
        requested_by,
        started_at,
        completed_at,
        input_count,
        finding_count,
        health_score
    ) VALUES (
        v_bom_id,
        'ADVISORY_AI',
        'USER_AI',
        'COMPLETED',
        'N/A',
        'BOM_ADVISORY:' || v_bom_id || ':' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF6'),
        v_corr_id,
        v_requested_by,
        v_now,
        v_now,
        v_finding_cnt,
        v_finding_cnt,
        v_score
    )
    RETURNING run_id INTO v_run_id;

    INSERT INTO ai_advisories (
        run_id,
        finding_id,
        advisory_scope,
        ai_status,
        ai_summary,
        ai_suggested_action,
        ai_provider,
        requested_by,
        generated_at
    ) VALUES (
        v_run_id,
        NULL,
        'BOM',
        'COMPLETED',
        'Mock Advisory AI summary for BOM ' || v_bom_id || '. Current health score is ' || v_score ||
            ' with ' || v_finding_cnt || ' open/reviewed findings.',
        NVL(v_prompt, 'Review critical and high-severity findings first, then validate source PLM corrections.'),
        'LOCAL_MOCK',
        v_requested_by,
        v_now
    )
    RETURNING advisory_id INTO v_advisory_id;

    COMMIT;

    :status_code := 201;
    OWA_UTIL.mime_header('application/json', FALSE);
    OWA_UTIL.http_header_close;
    HTP.P(JSON_OBJECT(
        'advisoryId' VALUE v_advisory_id,
        'runId' VALUE v_run_id,
        'bomId' VALUE v_bom_id,
        'scope' VALUE 'BOM',
        'status' VALUE 'COMPLETED'
        RETURNING CLOB
    ));
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        :status_code := 404;
        OWA_UTIL.mime_header('application/json', FALSE);
        OWA_UTIL.http_header_close;
        HTP.P(JSON_OBJECT('error' VALUE 'BOM_NOT_FOUND', 'bomId' VALUE v_bom_id RETURNING CLOB));
    WHEN OTHERS THEN
        ROLLBACK;
        v_err_msg := SUBSTR(SQLERRM, 1, 4000);
        :status_code := 400;
        OWA_UTIL.mime_header('application/json', FALSE);
        OWA_UTIL.http_header_close;
        HTP.P(JSON_OBJECT('error' VALUE 'BOM_ADVISORY_FAILED', 'message' VALUE SUBSTR(v_err_msg, 1, 1000) RETURNING CLOB));
END;
        ]'
    );

    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'bom_api',
        p_pattern     => 'findings/:finding_id/advisories',
        p_comments    => 'Create a mock finding-level advisory record'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'bom_api',
        p_pattern     => 'findings/:finding_id/advisories',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
DECLARE
    v_finding_id   NUMBER := TO_NUMBER(:finding_id);
    v_requested_by VARCHAR2(200) := NVL(:requested_by, 'ords-local-user');
    v_prompt       VARCHAR2(4000) := :question;
    v_bom_id       NUMBER;
    v_run_id       NUMBER;
    v_advisory_id  NUMBER;
    v_corr_id      VARCHAR2(100);
    v_rule_code    VARCHAR2(50);
    v_actual       VARCHAR2(1000);
    v_expected     VARCHAR2(1000);
    v_now          TIMESTAMP(6) WITH TIME ZONE;
    v_err_msg      VARCHAR2(4000);
BEGIN
    SELECT SYSTIMESTAMP AT TIME ZONE 'UTC'
      INTO v_now
      FROM dual;

    SELECT br.bom_id, vr.rule_code, vf.actual_value, vf.expected_value
      INTO v_bom_id, v_rule_code, v_actual, v_expected
      FROM validation_findings vf
      JOIN validation_rules vr ON vr.rule_id = vf.rule_id
      JOIN bom_runs br ON br.run_id = vf.run_id
     WHERE vf.finding_id = v_finding_id;

    v_corr_id := 'AI-FINDING-' || TO_CHAR(v_now, 'YYYYMMDDHH24MISSFF3') || '-' || RAWTOHEX(SYS_GUID());

    INSERT INTO bom_runs (
        bom_id,
        run_kind,
        trigger_type,
        status,
        source_mode,
        idempotency_key,
        correlation_id,
        requested_by,
        started_at,
        completed_at,
        input_count,
        finding_count
    ) VALUES (
        v_bom_id,
        'ADVISORY_AI',
        'USER_AI',
        'COMPLETED',
        'N/A',
        'FINDING_ADVISORY:' || v_finding_id || ':' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF6'),
        v_corr_id,
        v_requested_by,
        v_now,
        v_now,
        1,
        1
    )
    RETURNING run_id INTO v_run_id;

    INSERT INTO ai_advisories (
        run_id,
        finding_id,
        advisory_scope,
        ai_status,
        ai_summary,
        ai_suggested_action,
        ai_provider,
        requested_by,
        generated_at
    ) VALUES (
        v_run_id,
        v_finding_id,
        'FINDING',
        'COMPLETED',
        'Mock Advisory AI explanation for finding ' || v_finding_id || ' classified by ' || v_rule_code ||
            '. Actual value: ' || NVL(v_actual, 'NULL') || '. Expected value: ' || NVL(v_expected, 'NULL') || '.',
        NVL(v_prompt, 'Inspect the component evidence and correct the source relationship before release.'),
        'LOCAL_MOCK',
        v_requested_by,
        v_now
    )
    RETURNING advisory_id INTO v_advisory_id;

    COMMIT;

    :status_code := 201;
    OWA_UTIL.mime_header('application/json', FALSE);
    OWA_UTIL.http_header_close;
    HTP.P(JSON_OBJECT(
        'advisoryId' VALUE v_advisory_id,
        'runId' VALUE v_run_id,
        'findingId' VALUE v_finding_id,
        'bomId' VALUE v_bom_id,
        'scope' VALUE 'FINDING',
        'status' VALUE 'COMPLETED'
        RETURNING CLOB
    ));
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        :status_code := 404;
        OWA_UTIL.mime_header('application/json', FALSE);
        OWA_UTIL.http_header_close;
        HTP.P(JSON_OBJECT('error' VALUE 'FINDING_NOT_FOUND', 'findingId' VALUE v_finding_id RETURNING CLOB));
    WHEN OTHERS THEN
        ROLLBACK;
        v_err_msg := SUBSTR(SQLERRM, 1, 4000);
        :status_code := 400;
        OWA_UTIL.mime_header('application/json', FALSE);
        OWA_UTIL.http_header_close;
        HTP.P(JSON_OBJECT('error' VALUE 'FINDING_ADVISORY_FAILED', 'message' VALUE SUBSTR(v_err_msg, 1, 1000) RETURNING CLOB));
END;
        ]'
    );

END;
/

COMMIT;

PROMPT 05_ords_fix_commit.sql complete

EXIT;
