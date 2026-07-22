SET DEFINE OFF
SET SERVEROUTPUT ON

PROMPT Seeding validation rules FR-008 through FR-014

MERGE INTO validation_rules r
USING (
    SELECT 'FR-008' rule_code, 'Missing UOM' rule_name, 'CRITICAL' severity,
           'Create a finding when a component relationship required UOM is null, empty, or whitespace.' description,
           'UOM_CODE must be populated after trimming whitespace.' threshold_or_configuration
      FROM dual
    UNION ALL
    SELECT 'FR-009', 'Invalid Quantity', 'HIGH',
           'Create a finding when component quantity is null, zero, or negative.',
           'QUANTITY must be greater than zero.'
      FROM dual
    UNION ALL
    SELECT 'FR-010', 'Exact Duplicate', 'WARNING',
           'Create a finding when duplicate parent/component/operation/effectivity relationship rows exist.',
           'Normalized parent, component, operation sequence including null, and effectivity dates including null must be unique.'
      FROM dual
    UNION ALL
    SELECT 'FR-011', 'Obsolete Component', 'HIGH',
           'Create a finding when a component lifecycle status is obsolete while the parent BOM remains current.',
           'Configured obsolete statuses: OBSOLETE, INACTIVE, END_OF_LIFE.'
      FROM dual
    UNION ALL
    SELECT 'FR-012', 'Invalid Effectivity', 'HIGH',
           'Create a finding when effectivity end is earlier than effectivity start.',
           'EFFECTIVITY_END must be greater than or equal to EFFECTIVITY_START when both are provided.'
      FROM dual
    UNION ALL
    SELECT 'FR-013', 'Circular Reference', 'CRITICAL',
           'Create a finding when traversal of the staged BOM graph returns to an item already present in the path.',
           'Component graph must be acyclic within each latest BOM structure.'
      FROM dual
    UNION ALL
    SELECT 'FR-014', 'Quantity Anomaly', 'WARNING',
           'Create a finding when a positive quantity violates the configured lower or upper threshold.',
           'ANOMALY_MIN_QUANTITY and ANOMALY_MAX_QUANTITY define prototype bounds.'
      FROM dual
) s
ON (r.rule_code = s.rule_code)
WHEN MATCHED THEN UPDATE SET
    r.rule_name = s.rule_name,
    r.severity = s.severity,
    r.description = s.description,
    r.threshold_or_configuration = s.threshold_or_configuration,
    r.enabled_flag = 'Y',
    r.updated_at = SYSTIMESTAMP AT TIME ZONE 'UTC'
WHEN NOT MATCHED THEN INSERT (
    rule_code,
    rule_name,
    severity,
    description,
    threshold_or_configuration,
    enabled_flag,
    created_at
) VALUES (
    s.rule_code,
    s.rule_name,
    s.severity,
    s.description,
    s.threshold_or_configuration,
    'Y',
    SYSTIMESTAMP AT TIME ZONE 'UTC'
);

COMMIT;

PROMPT Generating mock PLM BOM data with deterministic validation defects

DECLARE
    c_batch_id        CONSTANT VARCHAR2(100 CHAR) := 'MOCK-VALIDATION-ENGINE-V1';
    c_bom_count       CONSTANT PLS_INTEGER := 240;
    v_bom_id          boms.bom_id%TYPE;
    v_org             boms.organization_code%TYPE;
    v_root_item       boms.item_number%TYPE;
    v_sub_item        bom_components.component_item_number%TYPE;
    v_comp_item       bom_components.component_item_number%TYPE;
    v_raw_item        bom_components.component_item_number%TYPE;
    v_rel_no          PLS_INTEGER := 0;
    v_flaw_slot       PLS_INTEGER;
    v_qty             bom_components.quantity%TYPE;
    v_uom             bom_components.uom_code%TYPE;
    v_status          bom_components.item_status%TYPE;
    v_eff_start       bom_components.effectivity_start%TYPE;
    v_eff_end         bom_components.effectivity_end%TYPE;
    v_min_qty         bom_components.anomaly_min_quantity%TYPE;
    v_max_qty         bom_components.anomaly_max_quantity%TYPE;
    v_component_id    bom_components.bom_component_id%TYPE;

    PROCEDURE add_component (
        p_bom_id       IN boms.bom_id%TYPE,
        p_parent       IN bom_components.parent_item_number%TYPE,
        p_component    IN bom_components.component_item_number%TYPE,
        p_class        IN bom_components.component_item_class%TYPE,
        p_level        IN bom_components.bom_level%TYPE,
        p_path         IN bom_components.component_path%TYPE,
        p_duplicate    IN BOOLEAN DEFAULT FALSE
    ) IS
    BEGIN
        v_rel_no := v_rel_no + 1;
        v_flaw_slot := MOD(v_rel_no, 42);
        v_qty := CASE WHEN p_class = 'FASTENER' THEN 4 ELSE 1 END;
        v_uom := 'EA';
        v_status := 'ACTIVE';
        v_eff_start := SYSTIMESTAMP AT TIME ZONE 'UTC' - INTERVAL '30' DAY;
        v_eff_end := NULL;
        v_min_qty := CASE WHEN p_class = 'FASTENER' THEN 1 ELSE 0.1 END;
        v_max_qty := CASE WHEN p_class = 'FASTENER' THEN 100 ELSE 10 END;

        IF NOT p_duplicate THEN
            CASE
                WHEN v_flaw_slot = 0 THEN
                    v_uom := CASE WHEN MOD(v_rel_no, 84) = 0 THEN NULL ELSE '   ' END;
                WHEN v_flaw_slot = 6 THEN
                    v_qty := CASE WHEN MOD(v_rel_no, 84) = 6 THEN 0 ELSE NULL END;
                WHEN v_flaw_slot = 12 THEN
                    v_status := 'OBSOLETE';
                WHEN v_flaw_slot = 18 THEN
                    v_eff_end := v_eff_start - INTERVAL '5' DAY;
                WHEN v_flaw_slot = 24 THEN
                    v_qty := v_max_qty * 50;
                ELSE
                    NULL;
            END CASE;
        END IF;

        INSERT INTO bom_components (
            bom_id,
            component_sequence_id,
            parent_item_number,
            component_item_number,
            component_item_class,
            quantity,
            uom_code,
            item_sequence_number,
            operation_sequence,
            item_status,
            effectivity_start,
            effectivity_end,
            bom_level,
            component_path,
            anomaly_min_quantity,
            anomaly_max_quantity,
            imported_at
        ) VALUES (
            p_bom_id,
            'MOCK-CSEQ-' || TO_CHAR(v_rel_no),
            p_parent,
            p_component,
            p_class,
            v_qty,
            v_uom,
            MOD(v_rel_no, 9999) + 1,
            CASE WHEN MOD(v_rel_no, 3) = 0 THEN NULL ELSE '10' END,
            v_status,
            v_eff_start,
            v_eff_end,
            p_level,
            p_path,
            v_min_qty,
            v_max_qty,
            SYSTIMESTAMP AT TIME ZONE 'UTC'
        )
        RETURNING bom_component_id INTO v_component_id;

        IF v_flaw_slot = 30 AND NOT p_duplicate THEN
            INSERT INTO bom_components (
                bom_id,
                component_sequence_id,
                parent_item_number,
                component_item_number,
                component_item_class,
                quantity,
                uom_code,
                item_sequence_number,
                operation_sequence,
                item_status,
                effectivity_start,
                effectivity_end,
                bom_level,
                component_path,
                anomaly_min_quantity,
                anomaly_max_quantity,
                imported_at
            )
            SELECT
                bom_id,
                component_sequence_id || '-DUP',
                parent_item_number,
                component_item_number,
                component_item_class,
                quantity,
                uom_code,
                item_sequence_number + 50000,
                operation_sequence,
                item_status,
                effectivity_start,
                effectivity_end,
                bom_level,
                component_path || '/DUP',
                anomaly_min_quantity,
                anomaly_max_quantity,
                imported_at
              FROM bom_components
             WHERE bom_component_id = v_component_id;
        END IF;
    END add_component;
BEGIN
    DELETE FROM diagnostic_logs
     WHERE related_run_id IN (
           SELECT run_id
             FROM bom_runs
            WHERE bom_id IN (SELECT bom_id FROM boms WHERE import_batch_id = c_batch_id)
     );

    DELETE FROM ai_advisories
     WHERE run_id IN (
           SELECT run_id
             FROM bom_runs
            WHERE bom_id IN (SELECT bom_id FROM boms WHERE import_batch_id = c_batch_id)
     );

    DELETE FROM finding_reviews
     WHERE finding_id IN (
           SELECT finding_id
             FROM validation_findings
            WHERE run_id IN (
                  SELECT run_id
                    FROM bom_runs
                   WHERE bom_id IN (SELECT bom_id FROM boms WHERE import_batch_id = c_batch_id)
            )
     );

    DELETE FROM validation_findings
     WHERE run_id IN (
           SELECT run_id
             FROM bom_runs
            WHERE bom_id IN (SELECT bom_id FROM boms WHERE import_batch_id = c_batch_id)
     );

    DELETE FROM bom_runs
     WHERE bom_id IN (SELECT bom_id FROM boms WHERE import_batch_id = c_batch_id);

    DELETE FROM bom_components
     WHERE bom_id IN (SELECT bom_id FROM boms WHERE import_batch_id = c_batch_id);

    DELETE FROM boms
     WHERE import_batch_id = c_batch_id;

    FOR i IN 1..c_bom_count LOOP
        v_org := CASE WHEN MOD(i, 2) = 0 THEN 'ORG2' ELSE 'ORG1' END;
        v_root_item := 'ASM-' || v_org || '-' || LPAD(i, 4, '0');

        INSERT INTO boms (
            bill_sequence_id,
            organization_code,
            item_number,
            structure_name,
            description,
            effectivity_control,
            source_updated_at,
            import_batch_id,
            imported_at,
            item_class,
            health_score,
            status_label
        ) VALUES (
            'MOCK-BILL-' || v_org || '-' || LPAD(i, 4, '0'),
            v_org,
            v_root_item,
            'PRIMARY',
            'Mock PLM assembly ' || v_root_item,
            'DATE_EFFECTIVE',
            SYSTIMESTAMP AT TIME ZONE 'UTC' - NUMTODSINTERVAL(MOD(i, 12), 'HOUR'),
            c_batch_id,
            SYSTIMESTAMP AT TIME ZONE 'UTC',
            CASE WHEN MOD(i, 3) = 0 THEN 'ELECTRONICS' WHEN MOD(i, 3) = 1 THEN 'MECHANICAL' ELSE 'HYDRAULIC' END,
            100,
            'HEALTHY'
        )
        RETURNING bom_id INTO v_bom_id;

        FOR s IN 1..2 LOOP
            v_sub_item := 'SUB-' || v_org || '-' || LPAD(i, 4, '0') || '-' || s;
            add_component(v_bom_id, v_root_item, v_sub_item, 'SUBASSEMBLY', 1, v_root_item || '/' || v_sub_item);

            FOR c IN 1..4 LOOP
                v_comp_item := 'CMP-' || v_org || '-' || LPAD(i, 4, '0') || '-' || s || '-' || c;
                add_component(
                    v_bom_id,
                    v_sub_item,
                    v_comp_item,
                    CASE WHEN c = 1 THEN 'FASTENER' WHEN c = 2 THEN 'ELECTRICAL' WHEN c = 3 THEN 'MECHANICAL' ELSE 'PACKAGING' END,
                    2,
                    v_root_item || '/' || v_sub_item || '/' || v_comp_item
                );

                IF c IN (1, 2) THEN
                    v_raw_item := 'RAW-' || v_org || '-' || LPAD(i, 4, '0') || '-' || s || '-' || c;
                    add_component(
                        v_bom_id,
                        v_comp_item,
                        v_raw_item,
                        CASE WHEN c = 1 THEN 'RAW_MATERIAL' ELSE 'ELECTRICAL' END,
                        3,
                        v_root_item || '/' || v_sub_item || '/' || v_comp_item || '/' || v_raw_item
                    );
                END IF;
            END LOOP;
        END LOOP;

        IF MOD(i, 12) IN (0, 1) THEN
            INSERT INTO bom_components (
                bom_id,
                component_sequence_id,
                parent_item_number,
                component_item_number,
                component_item_class,
                quantity,
                uom_code,
                item_sequence_number,
                operation_sequence,
                item_status,
                effectivity_start,
                effectivity_end,
                bom_level,
                component_path,
                anomaly_min_quantity,
                anomaly_max_quantity,
                imported_at
            ) VALUES (
                v_bom_id,
                'MOCK-CYCLE-' || TO_CHAR(i),
                'RAW-' || v_org || '-' || LPAD(i, 4, '0') || '-1-1',
                v_root_item,
                'SUBASSEMBLY',
                1,
                'EA',
                90000 + i,
                '10',
                'ACTIVE',
                SYSTIMESTAMP AT TIME ZONE 'UTC' - INTERVAL '30' DAY,
                NULL,
                4,
                v_root_item || '/SUB-' || v_org || '-' || LPAD(i, 4, '0') || '-1/CMP-' ||
                    v_org || '-' || LPAD(i, 4, '0') || '-1-1/RAW-' || v_org || '-' || LPAD(i, 4, '0') ||
                    '-1-1/' || v_root_item,
                0.1,
                10,
                SYSTIMESTAMP AT TIME ZONE 'UTC'
            );
        END IF;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Generated ' || c_bom_count || ' mock BOMs in ORG1 and ORG2 using batch ' || c_batch_id || '.');
END;
/

PROMPT Creating BOM_VALIDATION_PKG

CREATE OR REPLACE PACKAGE bom_validation_pkg AS
    PROCEDURE run_full_validation(
        p_bom_id       NUMBER,
        p_requested_by VARCHAR2
    );
END bom_validation_pkg;
/

CREATE OR REPLACE PACKAGE BODY bom_validation_pkg AS
    FUNCTION get_rule_id(p_rule_code IN validation_rules.rule_code%TYPE)
        RETURN validation_rules.rule_id%TYPE
    IS
        v_rule_id validation_rules.rule_id%TYPE;
    BEGIN
        SELECT rule_id
          INTO v_rule_id
          FROM validation_rules
         WHERE rule_code = p_rule_code
           AND enabled_flag = 'Y';

        RETURN v_rule_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Validation rule ' || p_rule_code || ' is not enabled or is missing.');
    END get_rule_id;

    FUNCTION utc_now
        RETURN TIMESTAMP WITH TIME ZONE
    IS
        v_now TIMESTAMP WITH TIME ZONE;
    BEGIN
        SELECT SYSTIMESTAMP AT TIME ZONE 'UTC'
          INTO v_now
          FROM dual;

        RETURN v_now;
    END utc_now;

    FUNCTION elapsed_ms(p_started_at IN TIMESTAMP WITH TIME ZONE)
        RETURN NUMBER
    IS
        v_elapsed INTERVAL DAY TO SECOND;
    BEGIN
        v_elapsed := utc_now() - p_started_at;

        RETURN EXTRACT(DAY FROM v_elapsed) * 86400000 +
               EXTRACT(HOUR FROM v_elapsed) * 3600000 +
               EXTRACT(MINUTE FROM v_elapsed) * 60000 +
               ROUND(EXTRACT(SECOND FROM v_elapsed) * 1000);
    END elapsed_ms;

    PROCEDURE log_event(
        p_correlation_id     IN diagnostic_logs.correlation_id%TYPE,
        p_run_id             IN diagnostic_logs.related_run_id%TYPE,
        p_finding_id         IN diagnostic_logs.related_finding_id%TYPE,
        p_stage              IN diagnostic_logs.stage%TYPE,
        p_status             IN diagnostic_logs.status%TYPE,
        p_event_level        IN diagnostic_logs.event_level%TYPE,
        p_details            IN diagnostic_logs.details%TYPE,
        p_error_code         IN diagnostic_logs.error_code%TYPE DEFAULT NULL,
        p_duration_ms        IN diagnostic_logs.duration_ms%TYPE DEFAULT NULL
    ) IS
        v_occurred_at TIMESTAMP(6) WITH TIME ZONE;
    BEGIN
        v_occurred_at := utc_now();

        INSERT INTO diagnostic_logs (
            correlation_id,
            related_run_id,
            related_finding_id,
            component_code,
            stage,
            source_mode,
            status,
            occurred_at,
            duration_ms,
            event_level,
            error_code,
            details
        ) VALUES (
            p_correlation_id,
            p_run_id,
            p_finding_id,
            'VALIDATION_ENGINE',
            p_stage,
            'N/A',
            p_status,
            v_occurred_at,
            p_duration_ms,
            p_event_level,
            p_error_code,
            SUBSTR(p_details, 1, 4000)
        );
    END log_event;

    PROCEDURE run_full_validation(
        p_bom_id       NUMBER,
        p_requested_by VARCHAR2
    ) IS
        v_run_id          bom_runs.run_id%TYPE;
        v_correlation_id  bom_runs.correlation_id%TYPE;
        v_started_at      TIMESTAMP(6) WITH TIME ZONE;
        v_component_count NUMBER(19);
        v_finding_count   NUMBER(19);
        v_penalty         NUMBER(19);
        v_health_score    boms.health_score%TYPE;
        v_bom_item        boms.item_number%TYPE;
        v_rule_fr008      validation_rules.rule_id%TYPE;
        v_rule_fr009      validation_rules.rule_id%TYPE;
        v_rule_fr010      validation_rules.rule_id%TYPE;
        v_rule_fr011      validation_rules.rule_id%TYPE;
        v_rule_fr012      validation_rules.rule_id%TYPE;
        v_rule_fr013      validation_rules.rule_id%TYPE;
        v_rule_fr014      validation_rules.rule_id%TYPE;
        v_created_at      TIMESTAMP(6) WITH TIME ZONE;
        v_completed_at    TIMESTAMP(6) WITH TIME ZONE;
        v_err_msg         VARCHAR2(4000);
    BEGIN
        v_started_at := utc_now();

        SELECT item_number
          INTO v_bom_item
          FROM boms
         WHERE bom_id = p_bom_id;

        SELECT COUNT(*)
          INTO v_component_count
          FROM bom_components
         WHERE bom_id = p_bom_id;

        v_rule_fr008 := get_rule_id('FR-008');
        v_rule_fr009 := get_rule_id('FR-009');
        v_rule_fr010 := get_rule_id('FR-010');
        v_rule_fr011 := get_rule_id('FR-011');
        v_rule_fr012 := get_rule_id('FR-012');
        v_rule_fr013 := get_rule_id('FR-013');
        v_rule_fr014 := get_rule_id('FR-014');

        v_correlation_id := 'VAL-' || TO_CHAR(utc_now(), 'YYYYMMDDHH24MISSFF3') || '-' ||
                            RAWTOHEX(SYS_GUID());

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
            input_count,
            finding_count
        ) VALUES (
            p_bom_id,
            'VALIDATION',
            'ON_DEMAND',
            'RUNNING',
            'N/A',
            'RUN_FULL_VALIDATION:' || p_bom_id || ':' || TO_CHAR(v_started_at, 'YYYYMMDDHH24MISSFF6'),
            v_correlation_id,
            p_requested_by,
            v_started_at,
            v_component_count,
            0
        )
        RETURNING run_id INTO v_run_id;

        log_event(v_correlation_id, v_run_id, NULL, 'VALIDATION_START', 'RUNNING', 'INFO',
                  'Started deterministic validation for BOM_ID=' || p_bom_id || ', ITEM_NUMBER=' || v_bom_item || '.');

        FOR rec IN (
            SELECT b.organization_code,
                   b.item_number bom_item_number,
                   c.bom_component_id,
                   c.parent_item_number,
                   c.component_item_number,
                   c.uom_code
              FROM boms b
              JOIN bom_components c ON c.bom_id = b.bom_id
             WHERE b.bom_id = p_bom_id
               AND TRIM(c.uom_code) IS NULL
        ) LOOP
            v_created_at := utc_now();

            INSERT INTO validation_findings (
                run_id,
                bom_component_id,
                rule_id,
                finding_key,
                issue_status,
                actual_value,
                expected_value,
                evidence_json,
                created_at
            ) VALUES (
                v_run_id,
                rec.bom_component_id,
                v_rule_fr008,
                'FR-008|' || rec.bom_component_id,
                'OPEN',
                NVL2(rec.uom_code, '"' || rec.uom_code || '"', 'NULL'),
                'Non-empty UOM_CODE',
                JSON_OBJECT(
                    'ruleCode' VALUE 'FR-008',
                    'bomId' VALUE p_bom_id,
                    'organizationCode' VALUE rec.organization_code,
                    'bomItemNumber' VALUE rec.bom_item_number,
                    'parentItemNumber' VALUE rec.parent_item_number,
                    'componentItemNumber' VALUE rec.component_item_number,
                    'missingField' VALUE 'UOM_CODE',
                    'rawUomCode' VALUE rec.uom_code
                    RETURNING CLOB
                ),
                v_created_at
            );
        END LOOP;

        FOR rec IN (
            SELECT b.organization_code,
                   b.item_number bom_item_number,
                   c.bom_component_id,
                   c.parent_item_number,
                   c.component_item_number,
                   c.quantity
              FROM boms b
              JOIN bom_components c ON c.bom_id = b.bom_id
             WHERE b.bom_id = p_bom_id
               AND (c.quantity IS NULL OR c.quantity <= 0)
        ) LOOP
            v_created_at := utc_now();

            INSERT INTO validation_findings (
                run_id,
                bom_component_id,
                rule_id,
                finding_key,
                issue_status,
                actual_value,
                expected_value,
                evidence_json,
                created_at
            ) VALUES (
                v_run_id,
                rec.bom_component_id,
                v_rule_fr009,
                'FR-009|' || rec.bom_component_id,
                'OPEN',
                NVL(TO_CHAR(rec.quantity), 'NULL'),
                'Quantity greater than 0',
                JSON_OBJECT(
                    'ruleCode' VALUE 'FR-009',
                    'bomId' VALUE p_bom_id,
                    'organizationCode' VALUE rec.organization_code,
                    'bomItemNumber' VALUE rec.bom_item_number,
                    'parentItemNumber' VALUE rec.parent_item_number,
                    'componentItemNumber' VALUE rec.component_item_number,
                    'receivedQuantity' VALUE rec.quantity
                    RETURNING CLOB
                ),
                v_created_at
            );
        END LOOP;

        FOR rec IN (
            WITH duplicate_groups AS (
                SELECT c.bom_id,
                       UPPER(TRIM(c.parent_item_number)) normalized_parent,
                       UPPER(TRIM(c.component_item_number)) normalized_component,
                       NVL(UPPER(TRIM(c.operation_sequence)), '<NULL>') normalized_operation,
                       c.effectivity_start,
                       c.effectivity_end,
                       MIN(c.bom_component_id) anchor_component_id,
                       COUNT(*) duplicate_count,
                       JSON_ARRAYAGG(
                           JSON_OBJECT(
                               'bomComponentId' VALUE c.bom_component_id,
                               'componentSequenceId' VALUE c.component_sequence_id,
                               'parentItemNumber' VALUE c.parent_item_number,
                               'componentItemNumber' VALUE c.component_item_number,
                               'operationSequence' VALUE c.operation_sequence,
                               'effectivityStart' VALUE TO_CHAR(c.effectivity_start, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM'),
                               'effectivityEnd' VALUE TO_CHAR(c.effectivity_end, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')
                               RETURNING CLOB
                           )
                           RETURNING CLOB
                       ) duplicate_rows
                  FROM bom_components c
                 WHERE c.bom_id = p_bom_id
                 GROUP BY c.bom_id,
                          UPPER(TRIM(c.parent_item_number)),
                          UPPER(TRIM(c.component_item_number)),
                          NVL(UPPER(TRIM(c.operation_sequence)), '<NULL>'),
                          c.effectivity_start,
                          c.effectivity_end
                HAVING COUNT(*) > 1
            )
            SELECT b.organization_code,
                   b.item_number bom_item_number,
                   dg.normalized_parent,
                   dg.normalized_component,
                   dg.normalized_operation,
                   dg.effectivity_start,
                   dg.effectivity_end,
                   dg.anchor_component_id,
                   dg.duplicate_count,
                   dg.duplicate_rows
              FROM duplicate_groups dg
              JOIN boms b ON b.bom_id = dg.bom_id
        ) LOOP
            v_created_at := utc_now();

            INSERT INTO validation_findings (
                run_id,
                bom_component_id,
                rule_id,
                finding_key,
                issue_status,
                actual_value,
                expected_value,
                evidence_json,
                created_at
            ) VALUES (
                v_run_id,
                rec.anchor_component_id,
                v_rule_fr010,
                'FR-010|' || rec.normalized_parent || '|' || rec.normalized_component || '|' ||
                    rec.normalized_operation || '|' ||
                    NVL(TO_CHAR(rec.effectivity_start, 'YYYYMMDDHH24MISSFF6TZH:TZM'), '<NULL>') || '|' ||
                    NVL(TO_CHAR(rec.effectivity_end, 'YYYYMMDDHH24MISSFF6TZH:TZM'), '<NULL>'),
                'OPEN',
                'Duplicate row count=' || rec.duplicate_count,
                'Exactly one relationship for normalized parent/component/operation/effectivity key',
                JSON_OBJECT(
                    'ruleCode' VALUE 'FR-010',
                    'bomId' VALUE p_bom_id,
                    'organizationCode' VALUE rec.organization_code,
                    'bomItemNumber' VALUE rec.bom_item_number,
                    'normalizedParentItemNumber' VALUE rec.normalized_parent,
                    'normalizedComponentItemNumber' VALUE rec.normalized_component,
                    'normalizedOperationSequence' VALUE rec.normalized_operation,
                    'effectivityStart' VALUE TO_CHAR(rec.effectivity_start, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM'),
                    'effectivityEnd' VALUE TO_CHAR(rec.effectivity_end, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM'),
                    'duplicateRows' VALUE rec.duplicate_rows FORMAT JSON
                    RETURNING CLOB
                ),
                v_created_at
            );
        END LOOP;

        FOR rec IN (
            SELECT b.organization_code,
                   b.item_number bom_item_number,
                   c.bom_component_id,
                   c.parent_item_number,
                   c.component_item_number,
                   c.item_status
              FROM boms b
              JOIN bom_components c ON c.bom_id = b.bom_id
             WHERE b.bom_id = p_bom_id
               AND UPPER(TRIM(c.item_status)) IN ('OBSOLETE', 'INACTIVE', 'END_OF_LIFE')
        ) LOOP
            v_created_at := utc_now();

            INSERT INTO validation_findings (
                run_id,
                bom_component_id,
                rule_id,
                finding_key,
                issue_status,
                actual_value,
                expected_value,
                evidence_json,
                created_at
            ) VALUES (
                v_run_id,
                rec.bom_component_id,
                v_rule_fr011,
                'FR-011|' || rec.bom_component_id,
                'OPEN',
                rec.item_status,
                'Component status not in obsolete configuration for current BOM',
                JSON_OBJECT(
                    'ruleCode' VALUE 'FR-011',
                    'bomId' VALUE p_bom_id,
                    'organizationCode' VALUE rec.organization_code,
                    'bomItemNumber' VALUE rec.bom_item_number,
                    'parentBomState' VALUE 'CURRENT_ACTIVE_OR_RELEASED',
                    'parentItemNumber' VALUE rec.parent_item_number,
                    'componentItemNumber' VALUE rec.component_item_number,
                    'componentItemStatus' VALUE rec.item_status,
                    'obsoleteStatusConfiguration' VALUE 'OBSOLETE, INACTIVE, END_OF_LIFE'
                    RETURNING CLOB
                ),
                v_created_at
            );
        END LOOP;

        FOR rec IN (
            SELECT b.organization_code,
                   b.item_number bom_item_number,
                   c.bom_component_id,
                   c.parent_item_number,
                   c.component_item_number,
                   c.effectivity_start,
                   c.effectivity_end
              FROM boms b
              JOIN bom_components c ON c.bom_id = b.bom_id
             WHERE b.bom_id = p_bom_id
               AND c.effectivity_start IS NOT NULL
               AND c.effectivity_end IS NOT NULL
               AND c.effectivity_end < c.effectivity_start
        ) LOOP
            v_created_at := utc_now();

            INSERT INTO validation_findings (
                run_id,
                bom_component_id,
                rule_id,
                finding_key,
                issue_status,
                actual_value,
                expected_value,
                evidence_json,
                created_at
            ) VALUES (
                v_run_id,
                rec.bom_component_id,
                v_rule_fr012,
                'FR-012|' || rec.bom_component_id,
                'OPEN',
                'Start=' || TO_CHAR(rec.effectivity_start, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') ||
                    ', End=' || TO_CHAR(rec.effectivity_end, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM'),
                'Effectivity end greater than or equal to start',
                JSON_OBJECT(
                    'ruleCode' VALUE 'FR-012',
                    'bomId' VALUE p_bom_id,
                    'organizationCode' VALUE rec.organization_code,
                    'bomItemNumber' VALUE rec.bom_item_number,
                    'parentItemNumber' VALUE rec.parent_item_number,
                    'componentItemNumber' VALUE rec.component_item_number,
                    'effectivityStart' VALUE TO_CHAR(rec.effectivity_start, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM'),
                    'effectivityEnd' VALUE TO_CHAR(rec.effectivity_end, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')
                    RETURNING CLOB
                ),
                v_created_at
            );
        END LOOP;

        FOR rec IN (
            SELECT *
              FROM (
                    SELECT c.bom_component_id,
                           c.parent_item_number,
                           c.component_item_number,
                           c.component_path,
                           SYS_CONNECT_BY_PATH(c.parent_item_number, ' -> ') || ' -> ' || c.component_item_number cycle_path,
                           ROW_NUMBER() OVER (
                               PARTITION BY c.parent_item_number, c.component_item_number
                               ORDER BY c.bom_component_id
                           ) rn
                      FROM bom_components c
                     WHERE c.bom_id = p_bom_id
                       AND CONNECT_BY_ISCYCLE = 1
                     START WITH c.bom_id = p_bom_id
                            AND c.parent_item_number = v_bom_item
                   CONNECT BY NOCYCLE PRIOR c.component_item_number = c.parent_item_number
                          AND PRIOR c.bom_id = c.bom_id
              )
             WHERE rn = 1
        ) LOOP
            v_created_at := utc_now();

            INSERT INTO validation_findings (
                run_id,
                bom_component_id,
                rule_id,
                finding_key,
                issue_status,
                actual_value,
                expected_value,
                evidence_json,
                created_at
            ) VALUES (
                v_run_id,
                rec.bom_component_id,
                v_rule_fr013,
                'FR-013|' || rec.bom_component_id,
                'OPEN',
                rec.cycle_path,
                'Acyclic parent-child component graph',
                JSON_OBJECT(
                    'ruleCode' VALUE 'FR-013',
                    'bomId' VALUE p_bom_id,
                    'bomItemNumber' VALUE v_bom_item,
                    'cyclePath' VALUE rec.cycle_path,
                    'parentItemNumber' VALUE rec.parent_item_number,
                    'componentItemNumber' VALUE rec.component_item_number,
                    'componentPath' VALUE rec.component_path
                    RETURNING CLOB
                ),
                v_created_at
            );
        END LOOP;

        FOR rec IN (
            SELECT b.organization_code,
                   b.item_number bom_item_number,
                   c.bom_component_id,
                   c.parent_item_number,
                   c.component_item_number,
                   c.component_item_class,
                   c.quantity,
                   c.anomaly_min_quantity,
                   c.anomaly_max_quantity,
                   CASE
                       WHEN c.anomaly_min_quantity IS NOT NULL AND c.quantity < c.anomaly_min_quantity
                           THEN 'Quantity is below configured minimum.'
                       WHEN c.anomaly_max_quantity IS NOT NULL AND c.quantity > c.anomaly_max_quantity
                           THEN 'Quantity is above configured maximum.'
                       ELSE 'Quantity violates configured threshold.'
                   END reason
              FROM boms b
              JOIN bom_components c ON c.bom_id = b.bom_id
             WHERE b.bom_id = p_bom_id
               AND c.quantity > 0
               AND (
                    (c.anomaly_min_quantity IS NOT NULL AND c.quantity < c.anomaly_min_quantity)
                    OR
                    (c.anomaly_max_quantity IS NOT NULL AND c.quantity > c.anomaly_max_quantity)
               )
        ) LOOP
            v_created_at := utc_now();

            INSERT INTO validation_findings (
                run_id,
                bom_component_id,
                rule_id,
                finding_key,
                issue_status,
                actual_value,
                expected_value,
                evidence_json,
                created_at
            ) VALUES (
                v_run_id,
                rec.bom_component_id,
                v_rule_fr014,
                'FR-014|' || rec.bom_component_id,
                'OPEN',
                TO_CHAR(rec.quantity),
                'Quantity between ' || NVL(TO_CHAR(rec.anomaly_min_quantity), '-infinity') ||
                    ' and ' || NVL(TO_CHAR(rec.anomaly_max_quantity), '+infinity'),
                JSON_OBJECT(
                    'ruleCode' VALUE 'FR-014',
                    'bomId' VALUE p_bom_id,
                    'organizationCode' VALUE rec.organization_code,
                    'bomItemNumber' VALUE rec.bom_item_number,
                    'parentItemNumber' VALUE rec.parent_item_number,
                    'componentItemNumber' VALUE rec.component_item_number,
                    'componentItemClass' VALUE rec.component_item_class,
                    'observedQuantity' VALUE rec.quantity,
                    'anomalyMinQuantity' VALUE rec.anomaly_min_quantity,
                    'anomalyMaxQuantity' VALUE rec.anomaly_max_quantity,
                    'configurationSource' VALUE 'BOM_COMPONENTS item-class prototype thresholds',
                    'reason' VALUE rec.reason
                    RETURNING CLOB
                ),
                v_created_at
            );
        END LOOP;

        SELECT COUNT(*)
          INTO v_finding_count
          FROM validation_findings
         WHERE run_id = v_run_id;

        SELECT NVL(SUM(
                   CASE r.severity
                       WHEN 'CRITICAL' THEN 25
                       WHEN 'HIGH' THEN 10
                       WHEN 'WARNING' THEN 5
                       ELSE 0
                   END
               ), 0)
          INTO v_penalty
          FROM validation_findings f
          JOIN validation_rules r ON r.rule_id = f.rule_id
         WHERE f.run_id = v_run_id
           AND f.issue_status IN ('OPEN', 'REVIEWED');

        v_health_score := GREATEST(0, 100 - v_penalty);

        UPDATE boms
           SET health_score = v_health_score,
               status_label = CASE WHEN v_health_score = 100 THEN 'HEALTHY' ELSE 'RISKY' END
         WHERE bom_id = p_bom_id;

        v_completed_at := utc_now();

        UPDATE bom_runs
           SET status = 'COMPLETED',
               completed_at = v_completed_at,
               finding_count = v_finding_count,
               health_score = v_health_score
         WHERE run_id = v_run_id;

        log_event(v_correlation_id, v_run_id, NULL, 'VALIDATION_COMPLETE', 'COMPLETED', 'INFO',
                  'Completed validation. Components evaluated=' || v_component_count ||
                  ', findings=' || v_finding_count || ', healthScore=' || v_health_score || '.',
                  NULL,
                  elapsed_ms(v_started_at));

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'BOM_ID ' || p_bom_id || ' was not found.');
        WHEN OTHERS THEN
            v_err_msg := SUBSTR(SQLERRM, 1, 4000);

            IF v_run_id IS NOT NULL THEN
                v_completed_at := utc_now();

                UPDATE bom_runs
                   SET status = 'FAILED',
                       completed_at = v_completed_at,
                       error_code = 'VALIDATION_ENGINE_ERROR',
                       error_message = v_err_msg
                 WHERE run_id = v_run_id;

                log_event(v_correlation_id, v_run_id, NULL, 'VALIDATION_FAILED', 'FAILED', 'ERROR',
                          'Validation failed for BOM_ID=' || p_bom_id || '. Error=' || SUBSTR(v_err_msg, 1, 3500),
                          'VALIDATION_ENGINE_ERROR');
                COMMIT;
            END IF;

            RAISE;
    END run_full_validation;
END bom_validation_pkg;
/

SHOW ERRORS PACKAGE bom_validation_pkg
SHOW ERRORS PACKAGE BODY bom_validation_pkg

PROMPT 02_database_validation_engine.sql complete
