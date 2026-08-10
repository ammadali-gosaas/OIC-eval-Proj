SET DEFINE OFF
SET SERVEROUTPUT ON

PROMPT Re-enabling ZA_SCHEMA schema and defining complete BOM validation ORDS API module

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
        p_source         => q'#
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
        #'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'dashboard/refresh');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'dashboard/refresh',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'#
BEGIN
    :status_code := 202;
END;
        #'
    );

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'bom_api',
        p_pattern            => 'dashboard/refresh',
        p_method             => 'POST',
        p_name               => 'X-ORDS-STATUS-CODE',
        p_bind_variable_name => 'status_code',
        p_source_type        => 'HEADER',
        p_param_type         => 'INT',
        p_access_method      => 'OUT'
    );

    --------------------------------------------------------------------
    -- 2. BOM SUMMARY & DETAIL ENDPOINTS
    --------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'boms');
    
    -- UNPAGINATED ALL-RECORDS HANDLER
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'boms',
        p_method        => 'GET',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'#
DECLARE
    v_arr    CLOB;
    v_len    NUMBER;
    v_offset NUMBER := 1;
    v_amount NUMBER := 8000;
BEGIN
    SELECT JSON_ARRAYAGG(
               JSON_OBJECT(
                   'bom_id'             VALUE b.bom_id,
                   'organization_code'  VALUE b.organization_code,
                   'item_number'        VALUE b.item_number,
                   'structure_name'     VALUE b.structure_name,
                   'description'        VALUE b.description,
                   'item_class'         VALUE b.item_class,
                   'health_score'       VALUE b.health_score,
                   'status_label'       VALUE b.status_label,
                   'imported_at'        VALUE TO_CHAR(b.imported_at, 'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'),
                   'component_count'    VALUE b.component_count,
                   'open_finding_count' VALUE b.open_finding_count,
                   'finding_severities' VALUE b.finding_severities
               ) ORDER BY b.health_score ASC, b.item_number RETURNING CLOB
           )
      INTO v_arr
      FROM (
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
      ) b;

    owa_util.mime_header('application/json', TRUE);
    HTP.PRN('{"items":');
    
    IF v_arr IS NOT NULL AND DBMS_LOB.GETLENGTH(v_arr) > 0 THEN
        v_len := DBMS_LOB.GETLENGTH(v_arr);
        WHILE v_offset <= v_len LOOP
            HTP.PRN(DBMS_LOB.SUBSTR(v_arr, v_amount, v_offset));
            v_offset := v_offset + v_amount;
        END LOOP;
    ELSE
        HTP.PRN('[]');
    END IF;
    
    HTP.PRN('}');
EXCEPTION
    WHEN OTHERS THEN
        owa_util.mime_header('application/json', TRUE);
        HTP.PRN('{"error":"' || REPLACE(SQLERRM, '"', '\"') || '","items":[]}');
END;
        #'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'boms',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'#
DECLARE
    v_clob          CLOB := :body_text;
    v_element       JSON_ELEMENT_T;
    v_root          JSON_OBJECT_T;
    v_items         JSON_ARRAY_T;
    v_item          JSON_OBJECT_T;
    v_bom_id        NUMBER;

    v_org_code      VARCHAR2(10);
    v_assembly_item VARCHAR2(100);
    v_bill_seq_id   VARCHAR2(100);
    v_struct_name   VARCHAR2(100);
    v_bom_desc      VARCHAR2(500);
    v_comp_item     VARCHAR2(100);
    v_qty           NUMBER;
    v_uom           VARCHAR2(10);
    v_op_seq        NUMBER;
    v_item_class    VARCHAR2(100);
    v_bom_level     NUMBER;
    v_effectivity   VARCHAR2(100);
    v_import_batch  VARCHAR2(100);
    v_count         NUMBER := 0;

    FUNCTION get_str(p_obj JSON_OBJECT_T, p_key VARCHAR2) RETURN VARCHAR2 IS
        v_elem JSON_ELEMENT_T;
    BEGIN
        IF p_obj IS NOT NULL AND p_obj.has(p_key) THEN
            v_elem := p_obj.get(p_key);
            IF v_elem IS NOT NULL AND NOT v_elem.is_null THEN
                IF v_elem.is_string THEN
                    RETURN p_obj.get_string(p_key);
                ELSIF v_elem.is_number THEN
                    RETURN TO_CHAR(p_obj.get_number(p_key));
                ELSIF v_elem.is_boolean THEN
                    RETURN CASE WHEN p_obj.get_boolean(p_key) THEN 'TRUE' ELSE 'FALSE' END;
                END IF;
            END IF;
        END IF;
        RETURN NULL;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END get_str;

    FUNCTION get_num(p_obj JSON_OBJECT_T, p_key VARCHAR2) RETURN NUMBER IS
        v_elem JSON_ELEMENT_T;
    BEGIN
        IF p_obj IS NOT NULL AND p_obj.has(p_key) THEN
            v_elem := p_obj.get(p_key);
            IF v_elem IS NOT NULL AND NOT v_elem.is_null THEN
                IF v_elem.is_number THEN
                    RETURN p_obj.get_number(p_key);
                ELSIF v_elem.is_string THEN
                    RETURN TO_NUMBER(p_obj.get_string(p_key));
                END IF;
            END IF;
        END IF;
        RETURN NULL;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END get_num;
BEGIN
    IF v_clob IS NULL OR dbms_lob.getlength(v_clob) = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Request payload body is empty.');
    END IF;

    v_element := JSON_ELEMENT_T.parse(v_clob);

    IF v_element.is_array THEN
        v_items := TREAT(v_element AS JSON_ARRAY_T);
    ELSIF v_element.is_object THEN
        v_root := TREAT(v_element AS JSON_OBJECT_T);
        IF v_root.has('items') AND v_root.get('items').is_array THEN
            v_items := v_root.get_array('items');
        ELSE
            v_items := NEW JSON_ARRAY_T();
            v_items.append(v_root);
        END IF;
    END IF;

    IF v_items IS NULL OR v_items.get_size = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'No items array found in JSON payload.');
    END IF;

    FOR i IN 0 .. v_items.get_size - 1 LOOP
        v_item := TREAT(v_items.get(i) AS JSON_OBJECT_T);

        v_org_code      := UPPER(TRIM(get_str(v_item, 'organization_code')));
        v_assembly_item := TRIM(NVL(get_str(v_item, 'assembly_item_number'), get_str(v_item, 'item_number')));
        v_bill_seq_id   := TRIM(get_str(v_item, 'bill_sequence_id'));
        v_struct_name   := NVL(TRIM(get_str(v_item, 'structure_name')), 'PRIMARY');
        v_bom_desc      := NVL(get_str(v_item, 'bom_description'), get_str(v_item, 'description'));
        v_comp_item     := TRIM(get_str(v_item, 'component_item_number'));
        v_qty           := get_num(v_item, 'quantity');
        v_uom           := get_str(v_item, 'uom_code');
        v_op_seq        := NVL(get_num(v_item, 'operation_seq_num'), get_num(v_item, 'operation_sequence'));
        v_item_class    := get_str(v_item, 'item_class');
        v_bom_level     := NVL(get_num(v_item, 'bom_level'), 1);
        v_effectivity   := NVL(get_str(v_item, 'effectivity_control'), 'DATE_EFFECTIVE');
        v_import_batch  := NVL(get_str(v_item, 'import_batch_id'), 'REST_IMPORT_BATCH');

        IF v_org_code IS NULL OR v_assembly_item IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003, 'Missing organization_code or assembly_item_number in JSON item.');
        END IF;

        -- 1. Insert or fetch parent BOM
        BEGIN
            SELECT bom_id INTO v_bom_id
              FROM boms
             WHERE organization_code = v_org_code
               AND item_number = v_assembly_item
               AND structure_name = v_struct_name;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO boms (
                    organization_code, item_number, structure_name,
                    description, item_class, health_score, status_label, 
                    imported_at, bill_sequence_id, effectivity_control,
                    import_batch_id, source_updated_at
                ) VALUES (
                    v_org_code, v_assembly_item, v_struct_name,
                    v_bom_desc, v_item_class, 100, 'HEALTHY', 
                    SYSTIMESTAMP AT TIME ZONE 'UTC', v_bill_seq_id, v_effectivity,
                    v_import_batch, SYSTIMESTAMP AT TIME ZONE 'UTC'
                ) RETURNING bom_id INTO v_bom_id;
        END;

        -- 2. Insert component details if component item exists
        IF v_comp_item IS NOT NULL THEN
            INSERT INTO bom_components (
                bom_id, parent_item_number, component_item_number,
                quantity, uom_code, operation_sequence, bom_level, 
                component_item_class, imported_at
            ) VALUES (
                v_bom_id, v_assembly_item, v_comp_item,
                v_qty, v_uom, v_op_seq, v_bom_level, 
                v_item_class, SYSTIMESTAMP AT TIME ZONE 'UTC'
            );
        END IF;

        v_count := v_count + 1;
    END LOOP;

    COMMIT;
    :status_code := 201;
    
    -- Explicitly output application/json HTTP header
    owa_util.mime_header('application/json', TRUE);
    htp.p('{"status":"success","inserted_count":' || v_count || '}');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        :status_code := 400;
        owa_util.mime_header('application/json', TRUE);
        htp.p('{"error":"' || REPLACE(SQLERRM, '"', '\"') || '"}');
END;
        #'
    );

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'bom_api',
        p_pattern            => 'boms',
        p_method             => 'POST',
        p_name               => 'X-ORDS-STATUS-CODE',
        p_bind_variable_name => 'status_code',
        p_source_type        => 'HEADER',
        p_param_type         => 'INT',
        p_access_method      => 'OUT'
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
               SELECT JSON_ARRAYAGG(JSON_OBJECT(
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
               ) ORDER BY c.bom_level, c.item_sequence_number, c.bom_component_id RETURNING CLOB) 
               FROM bom_components c 
               WHERE c.bom_id = b.bom_id
           ),
           'findings' VALUE (
               SELECT JSON_ARRAYAGG(JSON_OBJECT(
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
               ) ORDER BY vf.created_at DESC, vf.finding_id DESC RETURNING CLOB) 
               FROM bom_runs br 
               JOIN validation_findings vf ON vf.run_id = br.run_id 
               JOIN validation_rules vr ON vr.rule_id = vf.rule_id 
               WHERE br.bom_id = b.bom_id
                 AND br.run_id = (SELECT MAX(run_id) FROM bom_runs WHERE bom_id = b.bom_id AND run_kind = 'VALIDATION')
                 AND vf.issue_status IN ('OPEN', 'REVIEWED')
           ),
           'auditTrail' VALUE (
               SELECT JSON_ARRAYAGG(JSON_OBJECT(
                   'findingId'     VALUE fr.finding_id,
                   'ruleName'      VALUE vr.rule_name,
                   'ruleCode'      VALUE vr.rule_code,
                   'oldStatus'     VALUE fr.old_status,
                   'newStatus'     VALUE fr.new_status,
                   'reviewComment' VALUE fr.review_comment,
                   'reviewedBy'    VALUE fr.reviewed_by,
                   'reviewedAt'    VALUE TO_CHAR(fr.reviewed_at, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')
               ) ORDER BY fr.reviewed_at DESC RETURNING CLOB)
               FROM finding_reviews fr
               JOIN validation_findings vf ON vf.finding_id = fr.finding_id
               JOIN validation_rules vr ON vr.rule_id = vf.rule_id
               JOIN bom_runs br ON br.run_id = vf.run_id
               WHERE br.bom_id = b.bom_id
           )
           RETURNING CLOB
       ) bom_detail_json FROM boms b WHERE b.bom_id = TO_NUMBER(:bom_id DEFAULT NULL ON CONVERSION ERROR)
        ]'
    );
    -- 2. Fix the Findings List endpoint (Used by VBCS UI & potentially OIC)
    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'boms/:bom_id/findings');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'boms/:bom_id/findings',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'#
SELECT vf.finding_id, vf.run_id, vf.bom_component_id, b.bom_id, b.item_number, 
       vr.rule_code, vr.rule_name, vr.severity, vf.issue_status, 
       vf.actual_value, vf.expected_value, vf.evidence_json, vf.created_at
  FROM validation_findings vf
  JOIN validation_rules vr ON vr.rule_id = vf.rule_id
  JOIN bom_runs br ON br.run_id = vf.run_id
  JOIN boms b ON b.bom_id = br.bom_id
 WHERE b.bom_id = TO_NUMBER(:bom_id DEFAULT NULL ON CONVERSION ERROR)
   AND br.run_id = (SELECT MAX(run_id) FROM bom_runs WHERE bom_id = b.bom_id AND run_kind = 'VALIDATION')
 ORDER BY vf.created_at DESC
        #'
    );
    
 

 
    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'boms/:bom_id/refresh');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'boms/:bom_id/refresh',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'#
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
        #'
    );

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'bom_api',
        p_pattern            => 'boms/:bom_id/refresh',
        p_method             => 'POST',
        p_name               => 'X-ORDS-STATUS-CODE',
        p_bind_variable_name => 'status_code',
        p_source_type        => 'HEADER',
        p_param_type         => 'INT',
        p_access_method      => 'OUT'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'boms/:bom_id/runs');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'boms/:bom_id/runs',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'#
SELECT run_id, bom_id, run_kind, trigger_type, status, source_mode, idempotency_key, correlation_id, requested_by, started_at, completed_at, input_count, finding_count, health_score, error_code, error_message
  FROM bom_runs WHERE bom_id = TO_NUMBER(:bom_id DEFAULT NULL ON CONVERSION ERROR) ORDER BY started_at DESC, run_id DESC
        #'
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
        p_source         => q'#
SELECT br.run_id, br.bom_id, b.item_number, br.run_kind, br.trigger_type, br.status, br.source_mode, br.correlation_id, br.requested_by, br.started_at, br.completed_at, br.input_count, br.finding_count
  FROM bom_runs br JOIN boms b ON b.bom_id = br.bom_id
 ORDER BY br.started_at DESC, br.run_id DESC
        #'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'validation-runs',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'#
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
        #'
    );

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'bom_api',
        p_pattern            => 'validation-runs',
        p_method             => 'POST',
        p_name               => 'X-ORDS-STATUS-CODE',
        p_bind_variable_name => 'status_code',
        p_source_type        => 'HEADER',
        p_param_type         => 'INT',
        p_access_method      => 'OUT'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'validation-runs/:run_id');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'validation-runs/:run_id',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 0,
        p_source         => q'#
SELECT br.run_id, br.bom_id, b.organization_code, b.item_number, br.run_kind, br.trigger_type, br.status, br.source_mode, br.correlation_id, br.requested_by, br.started_at, br.completed_at, br.input_count, br.finding_count, br.health_score, br.error_code, br.error_message
  FROM bom_runs br JOIN boms b ON b.bom_id = br.bom_id WHERE br.run_id = TO_NUMBER(:run_id DEFAULT NULL ON CONVERSION ERROR)
        #'
    );

    --------------------------------------------------------------------
    -- 4. FINDING REVIEW & ADVISORY ENDPOINTS
    --------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'findings/:finding_id');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'findings/:finding_id',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 0,
        p_source         => q'#
SELECT vf.finding_id, vf.run_id, vf.bom_component_id, b.bom_id, b.item_number, 
       vr.rule_code, vr.rule_name, vr.severity, vf.issue_status, 
       vf.actual_value, vf.expected_value, vf.evidence_json, vf.created_at
  FROM validation_findings vf
  JOIN validation_rules vr ON vr.rule_id = vf.rule_id
  JOIN bom_runs br ON br.run_id = vf.run_id
  JOIN boms b ON b.bom_id = br.bom_id
 WHERE vf.finding_id = TO_NUMBER(:finding_id DEFAULT NULL ON CONVERSION ERROR)
        #'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'findings/:finding_id/status');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'findings/:finding_id/status',
        p_method        => 'PATCH',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'#
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
        #'
    );

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'bom_api',
        p_pattern            => 'findings/:finding_id/status',
        p_method             => 'PATCH',
        p_name               => 'X-ORDS-STATUS-CODE',
        p_bind_variable_name => 'status_code',
        p_source_type        => 'HEADER',
        p_param_type         => 'INT',
        p_access_method      => 'OUT'
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
    v_bom_id          NUMBER := TO_NUMBER(:bom_id DEFAULT NULL ON CONVERSION ERROR);
    v_requested_by    VARCHAR2(200) := NVL(:requested_by, 'ords-local-user');
    
    v_raw_payload     CLOB := :ai_summary;
    v_ai_summary      CLOB;
    v_ai_suggested    CLOB;
    v_ai_provider     VARCHAR2(100) := NVL(:ai_provider, 'GEMINI-FLASH-LATEST');
    
    v_run_id          NUMBER;
    v_advisory_id     NUMBER;
    v_finding_cnt     NUMBER;
    v_score           NUMBER;
    v_corr_id         VARCHAR2(100);
    v_now             TIMESTAMP(6) WITH TIME ZONE;
BEGIN
    IF v_bom_id IS NULL THEN 
        RAISE_APPLICATION_ERROR(-20021, 'Path parameter bom_id must be numeric.'); 
    END IF;

    BEGIN
        v_ai_summary   := JSON_VALUE(v_raw_payload, '$.ai_summary');
        v_ai_suggested := JSON_VALUE(v_raw_payload, '$.ai_suggested_action');
    EXCEPTION
        WHEN OTHERS THEN
            v_ai_summary   := v_raw_payload;
            v_ai_suggested := NULL;
    END;

    IF v_ai_summary IS NULL THEN
        v_ai_summary := v_raw_payload;
    END IF;

    SELECT SYSTIMESTAMP AT TIME ZONE 'UTC' INTO v_now FROM dual;
    SELECT health_score INTO v_score FROM boms WHERE bom_id = v_bom_id;
    
    -- UPDATED: Only count findings from the most recent run
    SELECT COUNT(*) INTO v_finding_cnt 
      FROM validation_findings vf 
     WHERE vf.run_id = (SELECT MAX(run_id) FROM bom_runs WHERE bom_id = v_bom_id)
       AND vf.issue_status IN ('OPEN', 'REVIEWED');

    v_corr_id := 'AI-BOM-' || TO_CHAR(v_now, 'YYYYMMDDHH24MISSFF3') || '-' || RAWTOHEX(SYS_GUID());

    INSERT INTO bom_runs (bom_id, run_kind, trigger_type, status, source_mode, correlation_id, requested_by, started_at, completed_at, input_count, finding_count, health_score)
    VALUES (v_bom_id, 'ADVISORY_AI', 'USER_AI', 'COMPLETED', 'N/A', v_corr_id, v_requested_by, v_now, v_now, v_finding_cnt, v_finding_cnt, v_score)
    RETURNING run_id INTO v_run_id;

    INSERT INTO ai_advisories (run_id, finding_id, advisory_scope, ai_status, ai_summary, ai_suggested_action, ai_provider, requested_by, generated_at)
    VALUES (v_run_id, NULL, 'BOM', 'COMPLETED', v_ai_summary, v_ai_suggested, v_ai_provider, v_requested_by, v_now)
    RETURNING advisory_id INTO v_advisory_id;

    COMMIT;
    :status_code := 201;
EXCEPTION 
    WHEN NO_DATA_FOUND THEN :status_code := 404; 
    WHEN OTHERS THEN ROLLBACK; :status_code := 400;
END;
        ]'
    );
 

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'bom_api',
        p_pattern            => 'boms/:bom_id/advisories',
        p_method             => 'POST',
        p_name               => 'X-ORDS-STATUS-CODE',
        p_bind_variable_name => 'status_code',
        p_source_type        => 'HEADER',
        p_param_type         => 'INT',
        p_access_method      => 'OUT'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'boms/:bom_id/advisories',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 0,
        p_source         => q'#
SELECT a.advisory_id,
       r.bom_id,
       r.run_id,
       a.advisory_scope,
       a.ai_status,
       a.ai_summary,
       a.ai_suggested_action,
       a.ai_provider,
       a.requested_by,
       a.generated_at
  FROM ai_advisories a
  JOIN bom_runs r ON r.run_id = a.run_id
 WHERE r.bom_id = TO_NUMBER(:bom_id DEFAULT NULL ON CONVERSION ERROR)
 ORDER BY a.generated_at DESC
        #'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'findings/:finding_id/advisories');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'findings/:finding_id/advisories',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'#
DECLARE
    v_finding_id NUMBER := TO_NUMBER(:finding_id DEFAULT NULL ON CONVERSION ERROR);
    v_requested_by VARCHAR2(200) := NVL(:requested_by, 'OIC-Integration');
    
    v_raw_payload     CLOB := :ai_summary;
    v_ai_summary      CLOB;
    v_ai_suggested    CLOB;
    v_ai_provider     VARCHAR2(100) := NVL(:ai_provider, 'GEMINI');
    
    v_bom_id NUMBER; v_run_id NUMBER; v_advisory_id NUMBER; v_corr_id VARCHAR2(100); v_now TIMESTAMP(6) WITH TIME ZONE;
BEGIN
    IF v_finding_id IS NULL THEN RAISE_APPLICATION_ERROR(-20022, 'Path parameter finding_id must be numeric.'); END IF;
    
    BEGIN
        v_ai_summary   := JSON_VALUE(v_raw_payload, '$.ai_summary');
        v_ai_suggested := JSON_VALUE(v_raw_payload, '$.ai_suggested_action');
    EXCEPTION
        WHEN OTHERS THEN
            v_ai_summary   := v_raw_payload;
            v_ai_suggested := NULL;
    END;

    IF v_ai_summary IS NULL THEN
        v_ai_summary := v_raw_payload;
    END IF;

    SELECT SYSTIMESTAMP AT TIME ZONE 'UTC' INTO v_now FROM dual;
    
    SELECT br.bom_id INTO v_bom_id 
      FROM validation_findings vf 
      JOIN bom_runs br ON br.run_id = vf.run_id 
     WHERE vf.finding_id = v_finding_id;
     
    v_corr_id := 'AI-FINDING-' || TO_CHAR(v_now, 'YYYYMMDDHH24MISSFF3') || '-' || RAWTOHEX(SYS_GUID());

    INSERT INTO bom_runs (bom_id, run_kind, trigger_type, status, source_mode, correlation_id, requested_by, started_at, completed_at, input_count, finding_count)
    VALUES (v_bom_id, 'ADVISORY_AI', 'USER_AI', 'COMPLETED', 'N/A', v_corr_id, v_requested_by, v_now, v_now, 1, 1) RETURNING run_id INTO v_run_id;

    INSERT INTO ai_advisories (run_id, finding_id, advisory_scope, ai_status, ai_summary, ai_suggested_action, ai_provider, requested_by, generated_at)
    VALUES (v_run_id, v_finding_id, 'FINDING', 'COMPLETED', v_ai_summary, v_ai_suggested, v_ai_provider, v_requested_by, v_now) RETURNING advisory_id INTO v_advisory_id;

    COMMIT;
    :status_code := 201;
EXCEPTION 
    WHEN NO_DATA_FOUND THEN :status_code := 404; 
    WHEN OTHERS THEN ROLLBACK; :status_code := 400;
END;
        #'
    );

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'bom_api',
        p_pattern            => 'findings/:finding_id/advisories',
        p_method             => 'POST',
        p_name               => 'X-ORDS-STATUS-CODE',
        p_bind_variable_name => 'status_code',
        p_source_type        => 'HEADER',
        p_param_type         => 'INT',
        p_access_method      => 'OUT'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'findings/:finding_id/advisories',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 0,
        p_source         => q'#
SELECT a.advisory_id,
       a.run_id,
       a.finding_id,
       a.advisory_scope,
       a.ai_status,
       a.ai_summary,
       a.ai_suggested_action,
       a.ai_provider,
       a.requested_by,
       a.generated_at
  FROM ai_advisories a
 WHERE a.finding_id = TO_NUMBER(:finding_id DEFAULT NULL ON CONVERSION ERROR)
 ORDER BY a.generated_at DESC
        #'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'advisories/:requestId');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'advisories/:requestId',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 0,
        p_source         => q'#
SELECT advisory_id, run_id, finding_id, advisory_scope, ai_status, ai_summary, ai_suggested_action, ai_provider, requested_by, generated_at
  FROM ai_advisories WHERE advisory_id = TO_NUMBER(:requestId DEFAULT NULL ON CONVERSION ERROR)
        #'
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
        p_source         => q'#
SELECT rule_id, rule_code, rule_name, severity, description, rule_config, enabled_flag, created_at, updated_at FROM validation_rules ORDER BY rule_code
        #'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'rules',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'#
DECLARE
    v_code VARCHAR2(50) := :rule_code; 
    v_name VARCHAR2(200) := :rule_name; 
    v_severity VARCHAR2(20) := UPPER(TRIM(:severity)); 
    v_desc VARCHAR2(1000) := :description; 
    v_config VARCHAR2(4000) := :rule_config; 
    v_rule_id NUMBER;
BEGIN
    INSERT INTO validation_rules (rule_code, rule_name, severity, description, rule_config, enabled_flag, created_at)
    VALUES (v_code, v_name, v_severity, NVL(v_desc, 'Custom Prototype Rule'), v_config, 'Y', SYSTIMESTAMP AT TIME ZONE 'UTC') RETURNING rule_id INTO v_rule_id;
    COMMIT;
    :status_code := 201;
EXCEPTION WHEN OTHERS THEN ROLLBACK; :status_code := 400;
END;
        #'
    );

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'bom_api',
        p_pattern            => 'rules',
        p_method             => 'POST',
        p_name               => 'X-ORDS-STATUS-CODE',
        p_bind_variable_name => 'status_code',
        p_source_type        => 'HEADER',
        p_param_type         => 'INT',
        p_access_method      => 'OUT'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'diagnostics/runs');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'diagnostics/runs',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'#
SELECT log_id, correlation_id, related_run_id, related_finding_id, component_code, stage, source_mode, status, occurred_at, duration_ms, event_level, error_code, details
  FROM diagnostic_logs ORDER BY occurred_at DESC, log_id DESC
        #'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'findings');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'findings',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 100,
        p_source         => q'#
SELECT vf.finding_id, vf.run_id, vf.bom_component_id, b.bom_id, b.item_number, vr.rule_code, vr.rule_name, vr.severity, vf.issue_status, vf.actual_value, vf.expected_value, vf.evidence_json, vf.created_at
  FROM validation_findings vf
  JOIN validation_rules vr ON vr.rule_id = vf.rule_id
  JOIN bom_runs br ON br.run_id = vf.run_id
  JOIN boms b ON b.bom_id = br.bom_id
 WHERE (:bom_id IS NULL OR b.bom_id = TO_NUMBER(:bom_id DEFAULT NULL ON CONVERSION ERROR))
     AND (:issue_status IS NULL OR vf.issue_status = :issue_status)
     AND (:severity IS NULL OR vr.severity = :severity)
     AND (:rule_code IS NULL OR vr.rule_code = :rule_code)
 ORDER BY vf.created_at DESC
        #'
    );

    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'schedules');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'schedules',
        p_method        => 'POST',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'#
DECLARE
    v_body     CLOB := :body_text;
    v_time     VARCHAR2(10) := :time;
    v_interval VARCHAR2(20) := :interval;
    v_job_name VARCHAR2(100);
    v_sql      VARCHAR2(4000);
    v_freq     VARCHAR2(50);
    v_hour_str VARCHAR2(10);
    v_min_str  VARCHAR2(10);
BEGIN
    -- Fallback JSON extraction if ORDS implicit parameter binding fails
    IF v_time IS NULL AND v_body IS NOT NULL THEN
        BEGIN
            v_time := JSON_VALUE(v_body, '$.time');
            v_interval := JSON_VALUE(v_body, '$.interval');
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END IF;

    IF v_time IS NULL OR LENGTH(v_time) < 5 THEN
        RAISE_APPLICATION_ERROR(-20001, 'JSON parameter "time" is required in HH:MI format (e.g. "02:10").');
    END IF;

    v_job_name := 'BOM_VAL_JOB_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS');

    IF UPPER(NVL(v_interval, 'DAILY')) = 'WEEKLY' THEN
        v_freq := 'FREQ=WEEKLY; ';
    ELSE
        v_freq := 'FREQ=DAILY; ';
    END IF;

    v_sql := 'BEGIN ' ||
            '  FOR b IN (SELECT bom_id FROM boms) LOOP ' ||
            '    BOM_VALIDATION_PKG.run_full_validation(b.bom_id, ''System Scheduler'', ''SCHEDULER''); ' ||
            '  END LOOP; ' ||
            'END;';

    v_hour_str := LPAD(REGEXP_SUBSTR(v_time, '^([0-9]{1,2})', 1, 1, NULL, 1), 2, '0');
    v_min_str  := LPAD(REGEXP_SUBSTR(v_time, ':([0-9]{1,2})', 1, 1, NULL, 1), 2, '0');

    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => v_job_name,
        job_type        => 'PLSQL_BLOCK',
        job_action      => v_sql,
        start_date      => SYSTIMESTAMP AT TIME ZONE '+05:00',
        repeat_interval => v_freq || 'BYHOUR=' || v_hour_str || '; BYMINUTE=' || v_min_str || ';',
        enabled         => TRUE,
        comments        => 'Scheduled via VBCS UI Dashboard'
    );

    :status_code := 201;
    owa_util.mime_header('application/json', TRUE);
    htp.p('{"status":"success","job_name":"' || v_job_name || '","scheduled_time":"' || v_time || '"}');
EXCEPTION 
    WHEN OTHERS THEN 
        :status_code := 400;
        owa_util.mime_header('application/json', TRUE);
        htp.p('{"error":"' || REPLACE(SQLERRM, '"', '\"') || '"}');
END;
        #'
    );

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'bom_api',
        p_pattern            => 'schedules',
        p_method             => 'POST',
        p_name               => 'X-ORDS-STATUS-CODE',
        p_bind_variable_name => 'status_code',
        p_source_type        => 'HEADER',
        p_param_type         => 'INT',
        p_access_method      => 'OUT'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'bom_api',
        p_pattern        => 'schedules',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_query,
        p_items_per_page => 10,
        p_source         => q'#
SELECT job_name,
       enabled,
       state,
       repeat_interval,
       TO_CHAR(start_date, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') AS start_date,
       TO_CHAR(next_run_date, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') AS next_run_date
  FROM user_scheduler_jobs
 WHERE job_name LIKE 'BOM_VAL_JOB_%'
 ORDER BY start_date DESC
        #'
    );


    ORDS.DEFINE_TEMPLATE(p_module_name => 'bom_api', p_pattern => 'rules/:rule_id');
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'rules/:rule_id',
        p_method        => 'PUT',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'#
DECLARE
    v_rule_code VARCHAR2(50) := UPPER(TRIM(:rule_id));
    v_name VARCHAR2(200) := :rule_name;
    v_severity VARCHAR2(20) := UPPER(TRIM(:severity));
    v_desc VARCHAR2(1000) := :description;
    v_config VARCHAR2(4000) := :rule_config;
    v_enabled CHAR(1) := NVL(UPPER(TRIM(:enabled_flag)), 'Y');
BEGIN
    IF v_rule_code IS NULL THEN RAISE_APPLICATION_ERROR(-20023, 'Path parameter rule_code must be provided.'); END IF;
    
    UPDATE validation_rules 
       SET rule_name = NVL(v_name, rule_name),
           severity = NVL(v_severity, severity),
           description = NVL(v_desc, description),
           rule_config = NVL(v_config, rule_config),
           enabled_flag = v_enabled,
           updated_at = SYSTIMESTAMP AT TIME ZONE 'UTC'
     WHERE UPPER(rule_code) = v_rule_code;
     
    IF SQL%ROWCOUNT = 0 THEN
        :status_code := 404;
    ELSE
        COMMIT;
        :status_code := 200;
    END IF;
EXCEPTION 
    WHEN OTHERS THEN ROLLBACK; :status_code := 400;
END;
        #'
    );

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'bom_api',
        p_pattern            => 'rules/:rule_id',
        p_method             => 'PUT',
        p_name               => 'X-ORDS-STATUS-CODE',
        p_bind_variable_name => 'status_code',
        p_source_type        => 'HEADER',
        p_param_type         => 'INT',
        p_access_method      => 'OUT'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'bom_api',
        p_pattern       => 'rules/:rule_id',
        p_method        => 'DELETE',
        p_source_type   => ORDS.source_type_plsql,
        p_mimes_allowed => 'application/json',
        p_source        => q'#
DECLARE
    v_rule_code VARCHAR2(50) := UPPER(TRIM(:rule_id));
BEGIN
    IF v_rule_code IS NULL THEN 
        RAISE_APPLICATION_ERROR(-20025, 'Rule code parameter is required.'); 
    END IF;

    DELETE FROM validation_rules 
    WHERE UPPER(rule_code) = v_rule_code;

    IF SQL%ROWCOUNT = 0 THEN
        :status_code := 404;
    ELSE
        COMMIT;
        :status_code := 200;
    END IF;
EXCEPTION 
    WHEN OTHERS THEN 
        ROLLBACK; 
        :status_code := 400;
END;
        #'
    );

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'bom_api',
        p_pattern            => 'rules/:rule_id',
        p_method             => 'DELETE',
        p_name               => 'X-ORDS-STATUS-CODE',
        p_bind_variable_name => 'status_code',
        p_source_type        => 'HEADER',
        p_param_type         => 'INT',
        p_access_method      => 'OUT'
    );

    COMMIT;
END;
/

PROMPT Master 05_ords_fix_commit.sql installation complete!