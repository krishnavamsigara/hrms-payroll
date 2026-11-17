-- Payroll audit trail (C-126 .. C-134): rollback file.
-- The 11 procedures exactly as they were before the audit calls were added (script.sql before C-131..C-134),
-- and the new audit routines removed. The table hrms_payroll_audit and its rows are kept on purpose;
-- drop it by hand only if the audit history is no longer wanted.
-- Run with: mysql --default-character-set=utf8mb4 production_hrms_db < script_backup_before_audit.sql

DELIMITER $$

-- ---------------------------------------------------------------------
-- hrms_update_component_master (before C-131..C-134)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_update_component_master$$
CREATE PROCEDURE hrms_update_component_master(
    IN p_emp_id                     VARCHAR(20),
    IN p_action                     VARCHAR(20),
    IN p_component_id               BIGINT,
    IN p_component_code             VARCHAR(30),
    IN p_component_name             VARCHAR(100),
    IN p_component_type             VARCHAR(30),
    IN p_calculation_type           VARCHAR(30),
    IN p_percentage_base            VARCHAR(30),
    IN p_percentage_value           DECIMAL(12,2),
    IN p_is_taxable                 TINYINT,
    IN p_is_active                  TINYINT,
    IN p_formula_expression         TEXT,
    IN p_minimum_amount             DECIMAL(12,2),
    IN p_maximum_amount             DECIMAL(12,2),
    IN p_calculation_scope          VARCHAR(20),
    IN p_calculation_order          INT,
    IN p_eligibility_parameter      VARCHAR(50),
    IN p_eligibility_required_value VARCHAR(10),
    IN p_is_slab                    TINYINT,
    IN p_rounding_precision         INT,
    IN p_is_manual                  TINYINT,
    IN p_slab_json                  LONGTEXT,
    IN p_dry_run                    TINYINT,
    IN p_add_to_total               TINYINT
)
main: BEGIN
    DECLARE v_role       VARCHAR(30);
    DECLARE v_ustat      VARCHAR(20);
    DECLARE v_action     VARCHAR(20);
    DECLARE v_id         BIGINT;
    DECLARE v_code       VARCHAR(40);
    DECLARE v_old_code   VARCHAR(40);
    DECLARE v_name       VARCHAR(100);
    DECLARE v_type       VARCHAR(30);
    DECLARE v_calc       VARCHAR(30);
    DECLARE v_base       VARCHAR(40);
    DECLARE v_value      DECIMAL(12,2);
    DECLARE v_formula    TEXT;
    DECLARE v_scope      VARCHAR(20);
    DECLARE v_order      INT;
    DECLARE v_old_order  INT;
    DECLARE v_eparam     VARCHAR(50);
    DECLARE v_evalue     VARCHAR(10);
    DECLARE v_rounding   INT;
    DECLARE v_taxable    TINYINT;
    DECLARE v_active     TINYINT;
    DECLARE v_manual     TINYINT;
    DECLARE v_dry        TINYINT;
    DECLARE v_exists     INT DEFAULT 0;
    DECLARE v_n          INT DEFAULT 0;
    DECLARE v_msg        VARCHAR(500) DEFAULT NULL;
    DECLARE v_list       VARCHAR(500);
    DECLARE v_st         CHAR(1);
    DECLARE v_rm         VARCHAR(500);
    DECLARE v_sample     DECIMAL(18,4);
    DECLARE v_slab_count INT DEFAULT 0;
    DECLARE v_attached   INT DEFAULT 0;
    DECLARE v_structures INT DEFAULT 0;
    DECLARE v_changed    INT DEFAULT 0;
    DECLARE v_errors     INT DEFAULT 0;
    DECLARE v_err        VARCHAR(500);
    DECLARE v_findings   LONGTEXT DEFAULT NULL;
    DECLARE v_impact     LONGTEXT DEFAULT NULL;
    DECLARE v_notice     VARCHAR(500) DEFAULT NULL;
    DECLARE v_total      VARCHAR(40) DEFAULT NULL;
    DECLARE v_tformula   TEXT DEFAULT NULL;
    DECLARE v_total_note VARCHAR(300) DEFAULT NULL;
    DECLARE v_dep_max    INT DEFAULT NULL;
    DECLARE v_after      INT DEFAULT 0;
    DECLARE v_before     INT DEFAULT NULL;
    DECLARE v_t_order    INT DEFAULT NULL;
    DECLARE v_prev       INT DEFAULT NULL;
    DECLARE v_auto       INT DEFAULT NULL;
    DECLARE v_order_note VARCHAR(120) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status,
               COALESCE(v_err, 'Component could not be saved. Nothing was changed.') AS remarks,
               p_component_id AS component_id, 0 AS attached_structures, 0 AS employee_rows_changed,
               NULL AS findings, NULL AS impact;
    END;

    SET v_action = UPPER(TRIM(COALESCE(p_action, '')));
    SET v_id     = IF(p_component_id IS NULL OR p_component_id <= 0, NULL, p_component_id);
    SET v_dry    = IF(COALESCE(p_dry_run, 0) = 1, 1, 0);

    SELECT MAX(user_category), MAX(status) INTO v_role, v_ustat
      FROM user_login_details WHERE emp_id = p_emp_id;
    IF v_role IS NULL OR LOWER(COALESCE(v_ustat, '')) <> 'active' OR UPPER(v_role) NOT IN ('ADMIN', 'HR') THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can manage components.';
    ELSEIF v_action NOT IN ('INSERT', 'UPDATE', 'ACTIVE') THEN
        SET v_msg = 'Invalid action. Use INSERT, UPDATE, or ACTIVE.';
    END IF;

    IF v_msg IS NULL AND v_action IN ('UPDATE', 'ACTIVE') THEN
        SELECT COUNT(*), MAX(UPPER(component_code)), MAX(calculation_order)
          INTO v_exists, v_old_code, v_old_order
          FROM salary_component_master WHERE component_id = v_id;
        IF v_id IS NULL OR v_exists = 0 THEN
            SET v_msg = 'Component not found.';
        END IF;
    END IF;

    -- ================= ACTIVE =================
    IF v_msg IS NULL AND v_action = 'ACTIVE' THEN
        IF p_is_active IS NULL OR p_is_active NOT IN (0, 1) THEN
            SET v_msg = 'For ACTIVE, provide component_id and is_active (0 or 1).';
        ELSEIF p_is_active = 0 THEN
            CALL hrms_component_dependents(v_old_code, v_id, NULL, 1, v_list);
            IF v_list IS NOT NULL THEN
                SET v_msg = LEFT(CONCAT('Cannot deactivate ', v_old_code, ': it is used by ', v_list, '.'), 500);
            END IF;
        END IF;

        IF v_msg IS NULL THEN
            START TRANSACTION;
            UPDATE salary_component_master
               SET is_active = p_is_active, updated_at = CURRENT_TIMESTAMP
             WHERE component_id = v_id;
            IF p_is_active = 1 THEN
                CALL hrms_attach_component(v_id, v_attached);
            END IF;
            CALL hrms_component_change_finish(v_id, v_msg, v_findings, v_impact, v_structures, v_changed);
            IF v_msg IS NULL THEN
                CALL hrms_component_cycle_guard(p_emp_id,
                     CONCAT('Component ', v_old_code, IF(p_is_active = 1, ' activated', ' deactivated')), v_notice);
                COMMIT;
                SELECT 'Y' AS status,
                       CONCAT('Component ', IF(p_is_active = 1, 'activated', 'deactivated'),
                              '. Employee amounts changed: ', v_changed, '.',
                              IF(v_notice IS NULL, '', CONCAT(' ', v_notice))) AS remarks,
                       v_id AS component_id, v_attached AS attached_structures, v_changed AS employee_rows_changed,
                       v_findings AS findings, v_impact AS impact;
                LEAVE main;
            END IF;
            ROLLBACK;
        END IF;
    END IF;

    -- ================= INSERT / UPDATE : clean the input =================
    IF v_msg IS NULL THEN
        SET v_code    = UPPER(TRIM(COALESCE(p_component_code, '')));
        SET v_name    = TRIM(COALESCE(p_component_name, ''));
        SET v_type    = UPPER(TRIM(COALESCE(p_component_type, '')));
        SET v_calc    = UPPER(TRIM(COALESCE(p_calculation_type, '')));
        SET v_base    = UPPER(TRIM(COALESCE(NULLIF(TRIM(p_percentage_base), ''), 'NONE')));
        SET v_value   = COALESCE(p_percentage_value, 0);
        SET v_formula = NULLIF(UPPER(TRIM(COALESCE(p_formula_expression, ''))), '');
        SET v_scope   = UPPER(TRIM(COALESCE(NULLIF(TRIM(p_calculation_scope), ''), 'COMPONENT')));
        SET v_eparam  = NULLIF(UPPER(TRIM(COALESCE(p_eligibility_parameter, ''))), '');
        SET v_evalue  = NULLIF(UPPER(TRIM(COALESCE(p_eligibility_required_value, ''))), '');
        SET v_taxable = COALESCE(p_is_taxable, 1);
        SET v_active  = COALESCE(p_is_active, 1);

        IF v_action = 'INSERT' THEN
            SET v_id = NULL;
            SET v_order = p_calculation_order;
            IF v_order IS NULL THEN
                SELECT COALESCE(MAX(calculation_order), 0) + 10 INTO v_order
                  FROM salary_component_master WHERE calculation_order < 900;
            END IF;
            SET v_rounding = COALESCE(p_rounding_precision, 2);
            SET v_manual   = COALESCE(p_is_manual, 0);
        ELSE
            SET v_order = COALESCE(p_calculation_order, v_old_order);
            SELECT COALESCE(p_rounding_precision, MAX(rounding_precision)), COALESCE(p_is_manual, MAX(is_manual))
              INTO v_rounding, v_manual
              FROM salary_component_master WHERE component_id = v_id;
        END IF;
        IF v_calc = 'MANUAL' THEN
            SET v_manual = 1;
        END IF;
    END IF;

    -- ================= INSERT / UPDATE : validation =================
    IF v_msg IS NULL AND v_code NOT REGEXP '^[A-Z][A-Z0-9_]{1,29}$' THEN
        SET v_msg = 'Component code must start with a letter and use only letters, numbers and _ (2 to 30 characters).';
    END IF;
    IF v_msg IS NULL AND v_code IN ('CTC','CTC1','ANNUAL_CTC','ESI_APPLICABLE','PAY_DAYS','PAYABLE_DAYS','LOP_DAYS',
                                   'MANUAL_AMOUNT','ESI_WAGE','STANDARD_ESI_WAGE',
                                   'ROUND','LEAST','GREATEST','IF','CEIL','FLOOR','ABS','AND','OR','NOT','NONE') THEN
        SET v_msg = CONCAT(v_code, ' is a reserved name and cannot be used as a component code.');
    END IF;
    IF v_msg IS NULL AND v_name = '' THEN
        SET v_msg = 'Component name is required.';
    END IF;
    IF v_msg IS NULL AND v_type NOT IN ('EARNING', 'DEDUCTION', 'EMPLOYER_CONTRIBUTION') THEN
        SET v_msg = 'Type must be EARNING, DEDUCTION or EMPLOYER_CONTRIBUTION.';
    END IF;
    IF v_msg IS NULL AND v_calc NOT IN ('FIXED', 'PERCENTAGE', 'FORMULA', 'MANUAL', 'STATUTORY') THEN
        SET v_msg = 'Calculation type must be FIXED, PERCENTAGE, FORMULA, MANUAL or STATUTORY.';
    END IF;
    IF v_msg IS NULL AND v_scope NOT IN ('COMPONENT', 'AGGREGATE') THEN
        SET v_msg = 'Scope must be COMPONENT or AGGREGATE (total).';
    END IF;
    IF v_msg IS NULL AND v_scope = 'AGGREGATE' AND (v_calc <> 'FORMULA' OR v_formula IS NULL) THEN
        SET v_msg = 'A total (AGGREGATE) component must be a FORMULA, for example BASIC + HRA.';
    END IF;
    IF v_msg IS NULL AND v_scope = 'AGGREGATE' AND (v_manual = 1 OR COALESCE(JSON_LENGTH(p_slab_json), 0) > 0) THEN
        SET v_msg = 'A total (AGGREGATE) component cannot be manual or have slabs.';
    END IF;
    IF v_msg IS NULL AND v_action = 'UPDATE' THEN
        SELECT COUNT(*) INTO v_n FROM salary_component_master
         WHERE component_id = v_id AND calculation_scope <> v_scope;
        IF v_n > 0 THEN
            SET v_msg = 'The scope of an existing component cannot be changed. Create a new component instead.';
        END IF;
    END IF;
    IF v_msg IS NULL AND (v_taxable NOT IN (0, 1) OR v_active NOT IN (0, 1) OR v_manual NOT IN (0, 1)) THEN
        SET v_msg = 'Statutory, Status and Manual must be 0 or 1.';
    END IF;
    IF v_msg IS NULL AND (v_order < 1 OR v_order > 9999) THEN
        SET v_msg = 'Calculation order must be between 1 and 9999.';
    END IF;
    IF v_msg IS NULL AND (v_rounding < 0 OR v_rounding > 2) THEN
        SET v_msg = 'Rounding must be 0, 1 or 2 decimal places.';
    END IF;
    IF v_msg IS NULL AND v_value < 0 THEN
        SET v_msg = 'Default value cannot be negative.';
    END IF;
    IF v_msg IS NULL AND (COALESCE(p_minimum_amount, 0) < 0 OR COALESCE(p_maximum_amount, 0) < 0) THEN
        SET v_msg = 'Minimum and maximum amount cannot be negative.';
    END IF;
    IF v_msg IS NULL AND p_minimum_amount IS NOT NULL AND p_maximum_amount IS NOT NULL
       AND p_minimum_amount > p_maximum_amount THEN
        SET v_msg = 'Minimum amount cannot be above maximum amount.';
    END IF;
    IF v_msg IS NULL AND v_eparam IS NOT NULL AND v_eparam NOT IN ('EMPLOYEE_ESI_ELIGIBLE') THEN
        SET v_msg = 'Eligibility must be empty or EMPLOYEE_ESI_ELIGIBLE.';
    END IF;
    IF v_msg IS NULL AND v_eparam IS NOT NULL AND COALESCE(v_evalue, '') NOT IN ('Y', 'N') THEN
        SET v_msg = 'Eligibility value must be Y or N.';
    END IF;
    IF v_eparam IS NULL THEN
        SET v_evalue = NULL;
    END IF;

    IF v_msg IS NULL THEN
        SELECT COUNT(*) INTO v_n FROM salary_component_master
         WHERE UPPER(component_code) = v_code AND (v_id IS NULL OR component_id <> v_id);
        IF v_n > 0 THEN
            SET v_msg = CONCAT('Component code already exists: ', v_code);
        END IF;
    END IF;
    IF v_msg IS NULL AND v_action = 'UPDATE' AND v_code <> v_old_code THEN
        CALL hrms_component_dependents(v_old_code, v_id, NULL, 0, v_list);
        IF v_list IS NOT NULL THEN
            SET v_msg = LEFT(CONCAT('The code ', v_old_code, ' cannot be changed: it is used by ', v_list, '.'), 500);
        END IF;
    END IF;

    -- PERCENTAGE needs a known "based on" name (unless slabs or manual decide the amount)
    IF v_msg IS NULL AND v_calc = 'PERCENTAGE' AND v_manual = 0 THEN
        IF p_percentage_value IS NULL THEN
            SET v_msg = 'A percentage value is required for PERCENTAGE.';
        ELSEIF v_base = 'NONE' THEN
            SET v_msg = 'Choose what the percentage is based on.';
        ELSEIF v_base NOT IN ('CTC','CTC1','ANNUAL_CTC','GROSS','TOTAL_DEDUCTIONS','TOTAL_EMPLOYER_CONTRIBUTION','ESI_WAGE','STANDARD_ESI_WAGE') THEN
            SELECT COUNT(*) INTO v_n FROM salary_component_master
             WHERE UPPER(component_code) = v_base AND (v_id IS NULL OR component_id <> v_id);
            IF v_n = 0 THEN
                SET v_msg = CONCAT('Based On "', v_base, '" is not CTC, CTC1, GROSS or another component code.');
            ELSE
                -- C-097: the base must be an active component
                SELECT COUNT(*) INTO v_n FROM salary_component_master
                 WHERE UPPER(component_code) = v_base AND is_active = 1 AND (v_id IS NULL OR component_id <> v_id);
                IF v_n = 0 THEN
                    SET v_msg = CONCAT('Based On "', v_base, '" is inactive, so it is always 0. Activate it or choose another base.');
                END IF;
            END IF;
        END IF;
    END IF;
    IF v_msg IS NULL AND v_calc = 'FIXED' AND p_percentage_value IS NULL THEN
        SET v_msg = 'An amount is required for FIXED.';
    END IF;
    IF v_msg IS NULL AND v_calc = 'FORMULA' AND v_formula IS NULL THEN
        SET v_msg = 'A formula is required for FORMULA.';
    END IF;
    IF v_msg IS NULL AND v_formula IS NOT NULL AND v_formula <> 'MANUAL_AMOUNT' THEN
        CALL hrms_formula_check(v_id, v_code, v_order, v_formula, v_st, v_rm, v_sample);
        IF v_st <> 'Y' THEN
            SET v_msg = v_rm;
        END IF;
    END IF;
    IF v_msg IS NULL AND COALESCE(p_is_slab, 0) = 1 AND p_slab_json IS NOT NULL
       AND COALESCE(JSON_LENGTH(p_slab_json), 0) = 0 THEN
        SET v_msg = 'A slab component needs at least one slab.';
    END IF;

    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks, v_id AS component_id,
               0 AS attached_structures, 0 AS employee_rows_changed,
               v_findings AS findings, v_impact AS impact;
        LEAVE main;
    END IF;

    -- ================= INSERT / UPDATE : save =================
    START TRANSACTION;

    IF v_action = 'INSERT' THEN
        INSERT INTO salary_component_master
            (component_code, component_name, component_type, calculation_type, percentage_base, percentage_value,
             formula_expression, minimum_amount, maximum_amount, calculation_scope, calculation_order,
             eligibility_parameter, eligibility_required_value, is_manual, is_slab, rounding_precision, is_taxable, is_active)
        VALUES
            (v_code, v_name, v_type, v_calc, v_base, v_value,
             v_formula, p_minimum_amount, p_maximum_amount, v_scope, v_order,
             v_eparam, v_evalue, v_manual, 0, v_rounding, v_taxable, v_active);
        SET v_id = LAST_INSERT_ID();
    ELSE
        UPDATE salary_component_master
           SET component_code = v_code,
               component_name = v_name,
               component_type = v_type,
               calculation_type = v_calc,
               percentage_base = v_base,
               percentage_value = v_value,
               formula_expression = v_formula,
               minimum_amount = p_minimum_amount,
               maximum_amount = p_maximum_amount,
               calculation_order = v_order,
               eligibility_parameter = v_eparam,
               eligibility_required_value = v_evalue,
               is_manual = v_manual,
               rounding_precision = v_rounding,
               is_taxable = v_taxable,
               is_active = v_active,
               updated_at = CURRENT_TIMESTAMP
         WHERE component_id = v_id;

        UPDATE employee_salary_structure ess
           SET ess.calculation_type   = CASE WHEN v_calc = 'STATUTORY' THEN 'MANUAL' ELSE v_calc END,
               ess.component_value    = v_value,
               ess.percentage_base    = v_base,
               ess.formula_expression = v_formula,
               ess.updated_at         = CURRENT_TIMESTAMP
         WHERE ess.component_id = v_id
           AND ess.is_overridden = 0;
    END IF;

    -- slabs entered on the same form
    IF p_slab_json IS NOT NULL THEN
        CALL hrms_component_slab_apply(p_emp_id, v_id, p_slab_json, v_slab_count, v_msg);
    END IF;

    -- C-104: put the pay component into the total of its type (plain sums only)
    IF v_msg IS NULL AND v_active = 1 AND v_scope = 'COMPONENT' AND COALESCE(p_add_to_total, 0) = 1 THEN
        SET v_total = CASE v_type WHEN 'EARNING' THEN 'GROSS' WHEN 'DEDUCTION' THEN 'TOTAL_DEDUCTIONS'
                                  ELSE 'TOTAL_EMPLOYER_CONTRIBUTION' END;
        SELECT MAX(formula_expression) INTO v_tformula FROM salary_component_master
         WHERE UPPER(component_code) = v_total AND is_active = 1 AND calculation_scope = 'AGGREGATE';
        IF v_tformula IS NOT NULL
           AND LOCATE(CONCAT(' ', v_code, ' '),
                      CONCAT(' ', REGEXP_REPLACE(UPPER(v_tformula), '[^A-Z0-9_]', ' '), ' ')) = 0 THEN
            IF UPPER(TRIM(v_tformula)) REGEXP '^[A-Z0-9_ +]+$' THEN
                UPDATE salary_component_master
                   SET formula_expression = CONCAT(TRIM(v_tformula), ' + ', v_code), updated_at = CURRENT_TIMESTAMP
                 WHERE UPPER(component_code) = v_total AND calculation_scope = 'AGGREGATE';
                SET v_total_note = CONCAT('Added to ', v_total, '.');
            ELSE
                SET v_total_note = CONCAT(v_total, ' is not a plain sum, so ', v_code, ' was not added to it automatically.');
            END IF;
        END IF;
    END IF;

    -- C-106: automatic calculation order for a new active component left on Auto
    IF v_msg IS NULL AND v_action = 'INSERT' AND p_calculation_order IS NULL AND v_active = 1 THEN
        CALL hrms_component_rules_check(NULL, 3);          -- who uses whom, nothing returned
        SELECT MAX(m.calculation_order) INTO v_dep_max
          FROM tmp_hrms_dep d
          JOIN salary_component_master m ON UPPER(m.component_code) = d.uses AND m.is_active = 1 AND m.component_id <> v_id
         WHERE d.code = v_code;
        SET v_after = COALESCE(v_dep_max, 0);
        SET v_before = NULL;
        IF v_scope = 'COMPONENT' AND v_total IS NOT NULL THEN
            SELECT MAX(calculation_order) INTO v_t_order FROM salary_component_master
             WHERE UPPER(component_code) = v_total AND is_active = 1 AND calculation_scope = 'AGGREGATE';
            IF v_t_order IS NOT NULL AND v_after < v_t_order THEN
                SELECT MAX(calculation_order) INTO v_prev FROM salary_component_master
                 WHERE is_active = 1 AND calculation_order < v_t_order AND component_id <> v_id;
                SET v_after = GREATEST(v_after, COALESCE(v_prev, 0));
                SET v_before = v_t_order;
            END IF;
        END IF;
        SET v_auto = hrms_free_order(v_after, v_before, v_id);
        IF v_auto IS NULL THEN
            SET v_msg = CONCAT('No free calculation order between ', v_after, ' and ', COALESCE(v_before, v_after + 1),
                               '. Enter a calculation order.');
        ELSE
            UPDATE salary_component_master SET calculation_order = v_auto WHERE component_id = v_id;
            SET v_order = v_auto;
            SET v_order_note = CONCAT('Calculation order ', v_auto, ' (automatic).');
        END IF;
    END IF;

    IF v_msg IS NULL THEN
        IF v_active = 1 AND v_scope = 'COMPONENT' THEN
            CALL hrms_attach_component(v_id, v_attached);
        END IF;
        CALL hrms_component_change_finish(v_id, v_msg, v_findings, v_impact, v_structures, v_changed);
    END IF;

    IF v_msg IS NOT NULL THEN
        ROLLBACK;
        SELECT 'N' AS status, v_msg AS remarks, IF(v_action = 'INSERT', NULL, v_id) AS component_id,
               0 AS attached_structures, 0 AS employee_rows_changed,
               v_findings AS findings, v_impact AS impact;
        LEAVE main;
    END IF;

    IF v_dry = 1 THEN
        ROLLBACK;
        SELECT 'Y' AS status,
               CONCAT('Check passed. ', v_structures, ' employees calculated without errors. Saving will change ',
                      v_changed, ' employee amounts',
                      IF(v_attached > 0, CONCAT(' and add the component to ', v_attached, ' salary structures'), ''), '.',
                      IF(v_total_note IS NULL, '', CONCAT(' ', v_total_note)),
                      IF(v_order_note IS NULL, '', CONCAT(' ', v_order_note))) AS remarks,
               IF(v_action = 'INSERT', NULL, v_id) AS component_id,
               v_attached AS attached_structures, v_changed AS employee_rows_changed,
               v_findings AS findings, v_impact AS impact;
        LEAVE main;
    END IF;

    CALL hrms_component_cycle_guard(p_emp_id, CONCAT('Component ', v_code, IF(v_action = 'INSERT', ' added', ' changed')), v_notice);
    COMMIT;

    SELECT 'Y' AS status,
           CONCAT(CASE
               WHEN v_action = 'INSERT' AND v_scope = 'AGGREGATE'
                   THEN CONCAT('Total ', v_code, ' created. Employee amounts changed: ', v_changed, '.')
               WHEN v_action = 'INSERT' AND v_active = 1
                   THEN CONCAT('Component ', v_code, ' created and added to ', v_attached,
                               ' employee salary structures. Employee amounts changed: ', v_changed, '.')
               WHEN v_action = 'INSERT'
                   THEN CONCAT('Component ', v_code, ' created as inactive. It is added to employees when activated.')
               ELSE CONCAT('Component ', v_code, ' updated. Employee amounts changed: ', v_changed,
                           IF(v_attached > 0, CONCAT('. Added to ', v_attached, ' more salary structures.'), '.'))
           END,
           IF(v_total_note IS NULL, '', CONCAT(' ', v_total_note)),
           IF(v_order_note IS NULL, '', CONCAT(' ', v_order_note)),
           IF(v_notice IS NULL, '', CONCAT(' ', v_notice))) AS remarks,
           v_id AS component_id, v_attached AS attached_structures, v_changed AS employee_rows_changed,
           v_findings AS findings, v_impact AS impact;
END$$

-- ---------------------------------------------------------------------
-- hrms_component_slab_save (before C-131..C-134)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_slab_save$$
CREATE PROCEDURE hrms_component_slab_save(
    IN p_emp_id       VARCHAR(20),
    IN p_component_id BIGINT,
    IN p_slab_json    LONGTEXT
)
sv: BEGIN
    DECLARE v_role       VARCHAR(30);
    DECLARE v_ustat      VARCHAR(20);
    DECLARE v_count      INT DEFAULT 0;
    DECLARE v_msg        VARCHAR(500) DEFAULT NULL;
    DECLARE v_structures INT DEFAULT 0;
    DECLARE v_changed    INT DEFAULT 0;
    DECLARE v_errors     INT DEFAULT 0;
    DECLARE v_err        VARCHAR(500);
    DECLARE v_findings   LONGTEXT DEFAULT NULL;
    DECLARE v_impact     LONGTEXT DEFAULT NULL;
    DECLARE v_notice     VARCHAR(500) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'Slabs could not be saved. Nothing was changed.') AS remarks,
               p_component_id AS component_id, 0 AS slab_count, 0 AS employee_rows_changed,
               NULL AS findings, NULL AS impact;
    END;

    SELECT MAX(user_category), MAX(status) INTO v_role, v_ustat
      FROM user_login_details WHERE emp_id = p_emp_id;
    IF v_role IS NULL OR LOWER(COALESCE(v_ustat, '')) <> 'active' OR UPPER(v_role) NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can manage slabs.' AS remarks,
               p_component_id AS component_id, 0 AS slab_count, 0 AS employee_rows_changed,
               NULL AS findings, NULL AS impact;
        LEAVE sv;
    END IF;

    START TRANSACTION;
    CALL hrms_component_slab_apply(p_emp_id, p_component_id, p_slab_json, v_count, v_msg);
    IF v_msg IS NULL THEN
        CALL hrms_component_change_finish(p_component_id, v_msg, v_findings, v_impact, v_structures, v_changed);
    END IF;
    IF v_msg IS NOT NULL THEN
        ROLLBACK;
        SELECT 'N' AS status, v_msg AS remarks, p_component_id AS component_id,
               0 AS slab_count, 0 AS employee_rows_changed,
               v_findings AS findings, v_impact AS impact;
        LEAVE sv;
    END IF;
    CALL hrms_component_cycle_guard(p_emp_id, 'Slabs changed', v_notice);
    COMMIT;
    SELECT 'Y' AS status,
           CONCAT(v_count, ' slab(s) saved. Employee amounts changed: ', v_changed, '.',
                  IF(v_notice IS NULL, '', CONCAT(' ', v_notice))) AS remarks,
           p_component_id AS component_id, v_count AS slab_count, v_changed AS employee_rows_changed,
           v_findings AS findings, v_impact AS impact;
END$$

-- ---------------------------------------------------------------------
-- hrms_component_slab_delete (before C-131..C-134)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_slab_delete$$
CREATE PROCEDURE hrms_component_slab_delete(
    IN p_emp_id  VARCHAR(20),
    IN p_slab_id BIGINT
)
dl: BEGIN
    DECLARE v_role       VARCHAR(30);
    DECLARE v_ustat      VARCHAR(20);
    DECLARE v_component  BIGINT DEFAULT NULL;
    DECLARE v_left       INT DEFAULT 0;
    DECLARE v_structures INT DEFAULT 0;
    DECLARE v_changed    INT DEFAULT 0;
    DECLARE v_errors     INT DEFAULT 0;
    DECLARE v_msg        VARCHAR(500) DEFAULT NULL;
    DECLARE v_err        VARCHAR(500);
    DECLARE v_findings   LONGTEXT DEFAULT NULL;
    DECLARE v_impact     LONGTEXT DEFAULT NULL;
    DECLARE v_notice     VARCHAR(500) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'Slab could not be deleted.') AS remarks,
               v_component AS component_id, 0 AS slab_count, 0 AS employee_rows_changed,
               NULL AS findings, NULL AS impact;
    END;

    SELECT MAX(user_category), MAX(status) INTO v_role, v_ustat
      FROM user_login_details WHERE emp_id = p_emp_id;
    SELECT MAX(component_id) INTO v_component FROM salary_component_slab WHERE slab_id = p_slab_id;

    IF v_role IS NULL OR LOWER(COALESCE(v_ustat, '')) <> 'active' OR UPPER(v_role) NOT IN ('ADMIN', 'HR') THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can manage slabs.';
    ELSEIF v_component IS NULL THEN
        SET v_msg = 'Slab not found.';
    END IF;
    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks, v_component AS component_id, 0 AS slab_count, 0 AS employee_rows_changed,
               NULL AS findings, NULL AS impact;
        LEAVE dl;
    END IF;

    START TRANSACTION;
    DELETE FROM salary_component_slab WHERE slab_id = p_slab_id;
    SELECT COUNT(*) INTO v_left FROM salary_component_slab WHERE component_id = v_component;
    UPDATE salary_component_master
       SET is_slab = IF(v_left > 0, 1, 0), updated_at = CURRENT_TIMESTAMP
     WHERE component_id = v_component;
    CALL hrms_component_change_finish(v_component, v_msg, v_findings, v_impact, v_structures, v_changed);
    IF v_msg IS NOT NULL THEN
        ROLLBACK;
        SELECT 'N' AS status, v_msg AS remarks, v_component AS component_id, 0 AS slab_count, 0 AS employee_rows_changed,
               v_findings AS findings, v_impact AS impact;
        LEAVE dl;
    END IF;
    CALL hrms_component_cycle_guard(p_emp_id, 'A slab was deleted', v_notice);
    COMMIT;
    SELECT 'Y' AS status,
           CONCAT('Slab deleted. Slabs left: ', v_left, '. Employee amounts changed: ', v_changed, '.',
                  IF(v_notice IS NULL, '', CONCAT(' ', v_notice))) AS remarks,
           v_component AS component_id, v_left AS slab_count, v_changed AS employee_rows_changed,
           v_findings AS findings, v_impact AS impact;
END$$

-- ---------------------------------------------------------------------
-- hrms_create_employee_salary (before C-131..C-134)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_create_employee_salary$$
CREATE PROCEDURE hrms_create_employee_salary(
    IN p_emp_id         VARCHAR(20),
    IN p_target_emp_id  VARCHAR(20),
    IN p_monthly_ctc    DECIMAL(12,2),
    IN p_effective_from DATE,
    IN p_esi            VARCHAR(1)
)
cs: BEGIN
    DECLARE v_ok        TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_msg       VARCHAR(500) DEFAULT NULL;
    DECLARE v_cover     VARCHAR(200);
    DECLARE v_next      DATE;
    DECLARE v_to        DATE;
    DECLARE v_structure BIGINT;
    DECLARE v_attached  INT DEFAULT 0;
    DECLARE v_changed   INT DEFAULT 0;
    DECLARE v_errs      INT DEFAULT 0;
    DECLARE v_text      VARCHAR(500);
    DECLARE v_err       VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'The salary could not be created. Nothing was changed.') AS remarks, NULL AS structure_id;
    END;

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can create salaries.';
    ELSEIF NOT EXISTS (SELECT 1 FROM user_login_details WHERE emp_id = p_target_emp_id AND LOWER(status) = 'active') THEN
        SET v_msg = CONCAT('Employee ', COALESCE(p_target_emp_id, ''), ' does not exist or is not active.');
    ELSEIF p_monthly_ctc IS NULL OR p_monthly_ctc <= 0 THEN
        SET v_msg = 'Monthly CTC must be more than 0.';
    ELSEIF p_effective_from IS NULL THEN
        SET v_msg = 'The date the salary applies from is required.';
    ELSEIF UPPER(COALESCE(p_esi, '')) NOT IN ('Y', 'N') THEN
        SET v_msg = 'Choose whether ESI is applicable.';
    END IF;
    IF v_msg IS NULL THEN
        SELECT MIN(CONCAT(DATE_FORMAT(effective_from, '%d %b %Y'), ' to ', COALESCE(DATE_FORMAT(effective_to, '%d %b %Y'), 'onwards')))
          INTO v_cover
          FROM salary_structure
         WHERE emp_id = p_target_emp_id AND structure_status = 'ACTIVE'
           AND effective_from <= p_effective_from AND (effective_to IS NULL OR effective_to >= p_effective_from);
        IF v_cover IS NOT NULL THEN
            SET v_msg = CONCAT('This employee already has a salary for ', DATE_FORMAT(p_effective_from, '%d %b %Y'),
                               ' (', v_cover, '). Use Edit to change it.');
        END IF;
    END IF;
    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks, NULL AS structure_id;
        LEAVE cs;
    END IF;

    -- a later salary already exists: the new one fills the gap up to the day before it
    SELECT MIN(effective_from) INTO v_next FROM salary_structure
     WHERE emp_id = p_target_emp_id AND structure_status = 'ACTIVE' AND effective_from > p_effective_from;
    SET v_to = IF(v_next IS NULL, NULL, DATE_SUB(v_next, INTERVAL 1 DAY));

    START TRANSACTION;
    INSERT INTO salary_structure (emp_id, monthly_ctc, annual_ctc, effective_from, effective_to, structure_status, esi_applicable, created_by)
    VALUES (p_target_emp_id, p_monthly_ctc, p_monthly_ctc * 12, p_effective_from, v_to, 'ACTIVE', UPPER(p_esi), p_emp_id);
    SET v_structure = LAST_INSERT_ID();
    CALL hrms_salary_attach_all(v_structure, v_attached);
    CALL hrms_calculate_structure(v_structure, GREATEST(p_effective_from, LEAST(CURDATE(), COALESCE(v_to, CURDATE()))),
                                  v_changed, v_errs, v_text);
    IF v_errs > 0 THEN
        ROLLBACK;
        SELECT 'N' AS status, LEFT(CONCAT('Not created: ', COALESCE(v_text, 'the salary could not be calculated.')), 500) AS remarks,
               NULL AS structure_id;
        LEAVE cs;
    END IF;
    COMMIT;

    SELECT 'Y' AS status,
           CONCAT('Salary created from ', DATE_FORMAT(p_effective_from, '%d %b %Y'),
                  IF(v_to IS NULL, '', CONCAT(' to ', DATE_FORMAT(v_to, '%d %b %Y'))),
                  ' with ', v_attached, ' components.') AS remarks,
           v_structure AS structure_id;
END$$

-- ---------------------------------------------------------------------
-- hrms_save_employee_salary (before C-131..C-134)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_save_employee_salary$$
CREATE PROCEDURE hrms_save_employee_salary(
    IN p_emp_id         VARCHAR(20),
    IN p_target_emp_id  VARCHAR(20),
    IN p_structure_id   BIGINT,
    IN p_monthly_ctc    DECIMAL(12,2),
    IN p_effective_from DATE,
    IN p_changes        LONGTEXT
)
sv: BEGIN
    DECLARE v_ok        TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_from      DATE;
    DECLARE v_to        DATE;
    DECLARE v_esi       VARCHAR(5);
    DECLARE v_target    BIGINT;
    DECLARE v_new       TINYINT DEFAULT 0;
    DECLARE v_msg       VARCHAR(500) DEFAULT NULL;
    DECLARE v_count     INT DEFAULT 0;
    DECLARE v_i         INT DEFAULT 0;
    DECLARE v_path      VARCHAR(30);
    DECLARE v_cid       BIGINT;
    DECLARE v_calc      VARCHAR(20);
    DECLARE v_value     VARCHAR(40);
    DECLARE v_base      VARCHAR(40);
    DECLARE v_formula   TEXT;
    DECLARE v_code      VARCHAR(40);
    DECLARE v_order     INT;
    DECLARE v_scope     VARCHAR(20);
    DECLARE v_n         INT DEFAULT 0;
    DECLARE v_st        CHAR(1);
    DECLARE v_rm        VARCHAR(500);
    DECLARE v_sample    DECIMAL(18,4);
    DECLARE v_attached  INT DEFAULT 0;
    DECLARE v_changed   INT DEFAULT 0;
    DECLARE v_errs      INT DEFAULT 0;
    DECLARE v_text      VARCHAR(500);
    DECLARE v_calc_date DATE;
    DECLARE v_err       VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'The salary could not be saved. Nothing was changed.') AS remarks,
               p_structure_id AS structure_id, 0 AS new_period;
    END;

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    SELECT MAX(effective_from), MAX(effective_to), MAX(esi_applicable) INTO v_from, v_to, v_esi
      FROM salary_structure
     WHERE structure_id = p_structure_id AND emp_id = p_target_emp_id AND structure_status = 'ACTIVE';

    IF v_ok = 0 THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can change salaries.';
    ELSEIF v_from IS NULL THEN
        SET v_msg = 'Salary period not found for this employee.';
    ELSEIF p_monthly_ctc IS NULL OR p_monthly_ctc <= 0 THEN
        SET v_msg = 'Monthly CTC must be more than 0.';
    ELSEIF p_effective_from IS NULL THEN
        SET v_msg = 'The date the salary applies from is required.';
    ELSEIF p_effective_from < v_from THEN
        SET v_msg = CONCAT('This salary period starts on ', DATE_FORMAT(v_from, '%d %b %Y'),
                           '. To change an earlier date, open the salary period that covers it.');
    ELSEIF v_to IS NOT NULL AND p_effective_from > v_to THEN
        SET v_msg = CONCAT('This salary period ends on ', DATE_FORMAT(v_to, '%d %b %Y'),
                           '. To change a later date, open the salary period that covers it.');
    ELSEIF NULLIF(TRIM(COALESCE(p_changes, '')), '') IS NOT NULL
       AND (JSON_VALID(p_changes) = 0 OR LEFT(TRIM(p_changes), 1) <> '[') THEN
        SET v_msg = 'Changes must be a JSON array.';
    END IF;
    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks, p_structure_id AS structure_id, 0 AS new_period;
        LEAVE sv;
    END IF;

    START TRANSACTION;
    SET v_target = p_structure_id;

    -- a later date = a new salary period; the old one ends the day before
    IF p_effective_from > v_from THEN
        INSERT INTO salary_structure
            (emp_id, monthly_ctc, annual_ctc, effective_from, effective_to, structure_status, esi_applicable, created_by)
        VALUES (p_target_emp_id, p_monthly_ctc, p_monthly_ctc * 12, p_effective_from, v_to, 'ACTIVE', v_esi, p_emp_id);
        SET v_target = LAST_INSERT_ID();
        INSERT INTO employee_salary_structure
            (structure_id, component_id, calculation_type, component_value, percentage_base, formula_expression,
             monthly_amount, is_overridden)
        SELECT v_target, component_id, calculation_type, component_value, percentage_base, formula_expression,
               monthly_amount, is_overridden
          FROM employee_salary_structure WHERE structure_id = p_structure_id;
        UPDATE salary_structure SET effective_to = DATE_SUB(p_effective_from, INTERVAL 1 DAY)
         WHERE structure_id = p_structure_id;
        SET v_new = 1;
    ELSE
        UPDATE salary_structure SET monthly_ctc = p_monthly_ctc, annual_ctc = p_monthly_ctc * 12
         WHERE structure_id = v_target;
    END IF;

    -- changed components
    SET v_count = COALESCE(JSON_LENGTH(NULLIF(TRIM(COALESCE(p_changes, '')), '')), 0);
    WHILE v_msg IS NULL AND v_i < v_count DO
        SET v_path    = CONCAT('$[', v_i, ']');
        SET v_cid     = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_changes, CONCAT(v_path, '.component_id'))), 'null') AS UNSIGNED);
        SET v_calc    = UPPER(TRIM(COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_changes, CONCAT(v_path, '.calculation_type'))), 'null'), '')));
        SET v_value   = NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_changes, CONCAT(v_path, '.component_value'))), '')), 'null');
        SET v_base    = UPPER(TRIM(COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_changes, CONCAT(v_path, '.percentage_base'))), 'null'), 'NONE')));
        SET v_formula = NULLIF(UPPER(TRIM(COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_changes, CONCAT(v_path, '.formula_expression'))), 'null'), ''))), '');
        SET v_code = NULL;
        SELECT MAX(UPPER(m.component_code)), MAX(m.calculation_order), MAX(m.calculation_scope), COUNT(e.employee_component_id)
          INTO v_code, v_order, v_scope, v_n
          FROM salary_component_master m
          LEFT JOIN employee_salary_structure e ON e.component_id = m.component_id AND e.structure_id = v_target
         WHERE m.component_id = v_cid AND m.is_active = 1;

        IF v_code IS NULL THEN
            SET v_msg = CONCAT('Change ', v_i + 1, ': component not found or inactive.');
        ELSEIF v_scope = 'AGGREGATE' THEN
            SET v_msg = CONCAT(v_code, ' is a total and is calculated from the other components.');
        ELSEIF v_n = 0 THEN
            SET v_msg = CONCAT(v_code, ' is not part of this salary.');
        ELSEIF v_calc NOT IN ('DEFAULT', 'FIXED', 'PERCENTAGE', 'FORMULA', 'MANUAL') THEN
            SET v_msg = CONCAT(v_code, ': choose Default, Fixed, Percentage, Formula or Manual.');
        ELSEIF v_calc IN ('FIXED', 'PERCENTAGE', 'MANUAL')
           AND (v_value IS NULL OR v_value NOT REGEXP '^[0-9]+(\\.[0-9]+)?$') THEN
            SET v_msg = CONCAT(v_code, ': enter a number of 0 or more.');
        ELSEIF v_calc = 'PERCENTAGE' AND (v_base = 'NONE' OR v_base = v_code) THEN
            SET v_msg = CONCAT(v_code, ': choose what the percentage is taken of (not the component itself).');
        ELSEIF v_calc = 'PERCENTAGE'
           AND v_base NOT IN ('CTC','CTC1','ANNUAL_CTC','GROSS','TOTAL_DEDUCTIONS','TOTAL_EMPLOYER_CONTRIBUTION','ESI_WAGE','STANDARD_ESI_WAGE')
           AND NOT EXISTS (SELECT 1 FROM salary_component_master WHERE UPPER(component_code) = v_base) THEN
            SET v_msg = CONCAT(v_code, ': "', v_base, '" is not CTC, CTC1, GROSS or a component code.');
        ELSEIF v_calc = 'FORMULA' AND v_formula IS NULL THEN
            SET v_msg = CONCAT(v_code, ': a formula is required.');
        END IF;
        IF v_msg IS NULL AND v_calc = 'FORMULA' THEN
            CALL hrms_formula_check(v_cid, v_code, v_order, v_formula, v_st, v_rm, v_sample);
            IF v_st <> 'Y' THEN
                SET v_msg = LEFT(CONCAT(v_code, ': ', v_rm), 500);
            END IF;
        END IF;

        IF v_msg IS NULL THEN
            IF v_calc = 'DEFAULT' THEN
                UPDATE employee_salary_structure e
                  JOIN salary_component_master m ON m.component_id = e.component_id
                   SET e.calculation_type = CASE WHEN m.calculation_type = 'STATUTORY' THEN 'MANUAL' ELSE m.calculation_type END,
                       e.component_value = COALESCE(m.percentage_value, 0), e.percentage_base = COALESCE(m.percentage_base, 'NONE'),
                       e.formula_expression = m.formula_expression, e.is_overridden = 0
                 WHERE e.structure_id = v_target AND e.component_id = v_cid;
            ELSE
                UPDATE employee_salary_structure
                   SET calculation_type = v_calc,
                       component_value = IF(v_calc = 'FORMULA', 0, CAST(v_value AS DECIMAL(12,2))),
                       percentage_base = IF(v_calc = 'PERCENTAGE', v_base, 'NONE'),
                       formula_expression = IF(v_calc = 'FORMULA', v_formula, NULL),
                       monthly_amount = IF(v_calc = 'MANUAL', CAST(v_value AS DECIMAL(12,2)), monthly_amount),
                       is_overridden = 1
                 WHERE structure_id = v_target AND component_id = v_cid;
            END IF;
        END IF;
        SET v_i = v_i + 1;
    END WHILE;

    IF v_msg IS NULL THEN
        CALL hrms_attach_component(NULL, v_attached);
        SET v_calc_date = GREATEST(p_effective_from, LEAST(CURDATE(), COALESCE(v_to, CURDATE())));
        CALL hrms_calculate_structure(v_target, v_calc_date, v_changed, v_errs, v_text);
        IF v_errs > 0 THEN
            SET v_msg = LEFT(CONCAT('Not saved: ', COALESCE(v_text, 'the salary could not be calculated.')), 500);
        END IF;
    END IF;

    IF v_msg IS NOT NULL THEN
        ROLLBACK;
        SELECT 'N' AS status, v_msg AS remarks, p_structure_id AS structure_id, 0 AS new_period;
        LEAVE sv;
    END IF;
    COMMIT;

    SELECT 'Y' AS status,
           IF(v_new = 1,
              CONCAT('Saved as a new salary from ', DATE_FORMAT(p_effective_from, '%d %b %Y'),
                     '. The previous salary now ends on ', DATE_FORMAT(DATE_SUB(p_effective_from, INTERVAL 1 DAY), '%d %b %Y'), '.'),
              CONCAT('Salary saved and recalculated', IF(v_count > 0, CONCAT(' (', v_count, ' component change(s))'), ''), '.')) AS remarks,
           v_target AS structure_id, v_new AS new_period;
END$$

-- ---------------------------------------------------------------------
-- hrms_update_salary_structure (before C-131..C-134)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_update_salary_structure$$
CREATE PROCEDURE hrms_update_salary_structure(
    IN p_emp_id         VARCHAR(20),
    IN p_target_emp_id  VARCHAR(20),
    IN p_monthly_ctc    DECIMAL(12,2),
    IN p_effective_from DATE
)
us: BEGIN
    DECLARE v_ok        TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_structure BIGINT;
    DECLARE v_msg       VARCHAR(500) DEFAULT NULL;
    DECLARE v_changed   INT DEFAULT 0;
    DECLARE v_errs      INT DEFAULT 0;
    DECLARE v_text      VARCHAR(500);
    DECLARE v_err       VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'Salary structure could not be updated.') AS remarks;
    END;

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can revise salary.';
    ELSEIF p_target_emp_id IS NULL OR TRIM(p_target_emp_id) = '' OR p_monthly_ctc IS NULL OR p_monthly_ctc <= 0 THEN
        SET v_msg = 'Provide a valid employee ID and positive monthly CTC.';
    ELSEIF p_effective_from IS NULL THEN
        SET v_msg = 'Effective from date is required.';
    ELSEIF NOT EXISTS (SELECT 1 FROM user_login_details WHERE emp_id = p_target_emp_id AND LOWER(status) = 'active') THEN
        SET v_msg = 'Target employee does not exist or is inactive.';
    END IF;
    IF v_msg IS NULL THEN
        SELECT ss.structure_id INTO v_structure
          FROM salary_structure ss
         WHERE ss.emp_id = p_target_emp_id AND ss.structure_status = 'ACTIVE'
           AND (ss.effective_to IS NULL OR ss.effective_to >= p_effective_from)
         ORDER BY ss.effective_from DESC, ss.structure_id DESC LIMIT 1;
        IF v_structure IS NULL THEN
            SET v_msg = 'No active salary structure exists for the selected effective date.';
        END IF;
    END IF;
    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks;
        LEAVE us;
    END IF;

    START TRANSACTION;
    UPDATE salary_structure
       SET monthly_ctc = p_monthly_ctc, annual_ctc = p_monthly_ctc * 12, effective_from = p_effective_from
     WHERE structure_id = v_structure;
    CALL hrms_attach_component(NULL, v_changed);
    SET @hrms_calc_date = hrms_structure_calc_date(v_structure);
    CALL hrms_calculate_structure(v_structure, @hrms_calc_date, v_changed, v_errs, v_text);   -- C-096
    IF v_errs > 0 THEN
        ROLLBACK;
        SELECT 'N' AS status, LEFT(CONCAT('Not saved: ', COALESCE(v_text, 'the salary could not be calculated.')), 500) AS remarks;
        LEAVE us;
    END IF;
    COMMIT;

    SELECT 'Y' AS status, 'Salary structure updated and salary recalculated.' AS remarks,
           p_target_emp_id AS emp_id, v_structure AS structure_id, p_monthly_ctc AS monthly_ctc,
           p_monthly_ctc * 12 AS annual_ctc, p_effective_from AS effective_from;
END$$

-- ---------------------------------------------------------------------
-- hrms_update_employee_salary_component (before C-131..C-134)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_update_employee_salary_component$$
CREATE PROCEDURE hrms_update_employee_salary_component(
    IN p_emp_id             VARCHAR(20),
    IN p_target_emp_id      VARCHAR(20),
    IN p_component_id       BIGINT,
    IN p_calculation_type   VARCHAR(20),
    IN p_component_value    DECIMAL(12,2),
    IN p_percentage_base    VARCHAR(30),
    IN p_formula_expression TEXT
)
uc: BEGIN
    DECLARE v_ok        TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_structure BIGINT;
    DECLARE v_calc      VARCHAR(20);
    DECLARE v_base      VARCHAR(40);
    DECLARE v_formula   TEXT;
    DECLARE v_code      VARCHAR(40);
    DECLARE v_order     INT;
    DECLARE v_scope     VARCHAR(20);
    DECLARE v_n         INT DEFAULT 0;
    DECLARE v_msg       VARCHAR(500) DEFAULT NULL;
    DECLARE v_st        CHAR(1);
    DECLARE v_rm        VARCHAR(500);
    DECLARE v_sample    DECIMAL(18,4);
    DECLARE v_changed   INT DEFAULT 0;
    DECLARE v_errs      INT DEFAULT 0;
    DECLARE v_text      VARCHAR(500);
    DECLARE v_amount    DECIMAL(14,2);
    DECLARE v_err       VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'Employee component could not be saved.') AS remarks;
    END;

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    SET v_calc    = UPPER(TRIM(COALESCE(p_calculation_type, '')));
    SET v_base    = UPPER(TRIM(COALESCE(NULLIF(TRIM(p_percentage_base), ''), 'NONE')));
    SET v_formula = NULLIF(UPPER(TRIM(COALESCE(p_formula_expression, ''))), '');
    SELECT MAX(UPPER(component_code)), MAX(calculation_order), MAX(calculation_scope) INTO v_code, v_order, v_scope
      FROM salary_component_master WHERE component_id = p_component_id AND is_active = 1;
    SELECT ss.structure_id INTO v_structure
      FROM salary_structure ss
     WHERE ss.emp_id = p_target_emp_id AND ss.structure_status = 'ACTIVE'
       AND ss.effective_from <= CURDATE() AND (ss.effective_to IS NULL OR ss.effective_to >= CURDATE())
     ORDER BY ss.effective_from DESC, ss.structure_id DESC LIMIT 1;

    IF v_ok = 0 THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can update employee salary components.';
    ELSEIF NOT EXISTS (SELECT 1 FROM user_login_details WHERE emp_id = p_target_emp_id AND LOWER(status) = 'active') THEN
        SET v_msg = 'Target employee does not exist or is inactive.';
    ELSEIF v_code IS NULL THEN
        SET v_msg = 'Component not found or inactive.';
    ELSEIF v_scope = 'AGGREGATE' THEN
        SET v_msg = 'Totals are calculated from the other components and cannot be set per employee.';
    ELSEIF v_structure IS NULL THEN
        SET v_msg = 'Employee has no active salary structure.';
    ELSEIF v_calc NOT IN ('DEFAULT', 'FIXED', 'PERCENTAGE', 'FORMULA', 'MANUAL') THEN
        SET v_msg = 'Calculation type must be FIXED, PERCENTAGE, FORMULA, MANUAL or DEFAULT.';
    ELSEIF v_calc IN ('FIXED', 'MANUAL', 'PERCENTAGE') AND (p_component_value IS NULL OR p_component_value < 0) THEN
        SET v_msg = 'Enter a value of 0 or more.';
    ELSEIF v_calc = 'PERCENTAGE' AND v_base = 'NONE' THEN
        SET v_msg = 'Choose what the percentage is based on.';
    ELSEIF v_calc = 'PERCENTAGE' AND v_base = v_code THEN
        SET v_msg = 'A component cannot be a percentage of itself.';
    ELSEIF v_calc = 'FORMULA' AND v_formula IS NULL THEN
        SET v_msg = 'A formula is required for FORMULA.';
    END IF;
    IF v_msg IS NULL AND v_calc = 'PERCENTAGE'
       AND v_base NOT IN ('CTC','CTC1','ANNUAL_CTC','GROSS','TOTAL_DEDUCTIONS','TOTAL_EMPLOYER_CONTRIBUTION','ESI_WAGE','STANDARD_ESI_WAGE') THEN
        SELECT COUNT(*) INTO v_n FROM salary_component_master WHERE UPPER(component_code) = v_base;
        IF v_n = 0 THEN
            SET v_msg = CONCAT('Based On "', v_base, '" is not CTC, CTC1, GROSS or a component code.');
        END IF;
    END IF;
    IF v_msg IS NULL AND v_calc = 'FORMULA' THEN
        CALL hrms_formula_check(p_component_id, v_code, v_order, v_formula, v_st, v_rm, v_sample);
        IF v_st <> 'Y' THEN
            SET v_msg = v_rm;
        END IF;
    END IF;
    IF v_msg IS NULL THEN
        SELECT COUNT(*) INTO v_n FROM employee_salary_structure WHERE structure_id = v_structure AND component_id = p_component_id;
        IF v_n = 0 THEN
            SET v_msg = 'Component is not assigned to this employee structure.';
        END IF;
    END IF;
    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks;
        LEAVE uc;
    END IF;

    START TRANSACTION;
    IF v_calc = 'DEFAULT' THEN
        UPDATE employee_salary_structure e
          JOIN salary_component_master m ON m.component_id = e.component_id
           SET e.calculation_type = CASE WHEN m.calculation_type = 'STATUTORY' THEN 'MANUAL' ELSE m.calculation_type END,
               e.component_value = COALESCE(m.percentage_value, 0),
               e.percentage_base = COALESCE(m.percentage_base, 'NONE'),
               e.formula_expression = m.formula_expression,
               e.is_overridden = 0
         WHERE e.structure_id = v_structure AND e.component_id = p_component_id;
    ELSE
        UPDATE employee_salary_structure
           SET calculation_type = v_calc,
               component_value = COALESCE(p_component_value, 0),
               percentage_base = IF(v_calc = 'PERCENTAGE', v_base, 'NONE'),
               formula_expression = IF(v_calc = 'FORMULA', v_formula, NULL),
               monthly_amount = IF(v_calc = 'MANUAL', COALESCE(p_component_value, 0), monthly_amount),
               is_overridden = 1
         WHERE structure_id = v_structure AND component_id = p_component_id;
    END IF;

    SET @hrms_calc_date = hrms_structure_calc_date(v_structure);
    CALL hrms_calculate_structure(v_structure, @hrms_calc_date, v_changed, v_errs, v_text);   -- C-096
    IF v_errs > 0 THEN
        ROLLBACK;
        SELECT 'N' AS status, LEFT(CONCAT('Not saved: ', COALESCE(v_text, 'the salary could not be calculated.')), 500) AS remarks;
        LEAVE uc;
    END IF;
    COMMIT;

    SELECT monthly_amount INTO v_amount FROM employee_salary_structure
     WHERE structure_id = v_structure AND component_id = p_component_id;
    SELECT 'Y' AS status,
           IF(v_calc = 'DEFAULT', 'Component follows the component master again. Salary recalculated.',
              'Employee component updated and salary recalculated.') AS remarks,
           p_target_emp_id AS emp_id, v_structure AS structure_id, p_component_id AS component_id,
           v_amount AS monthly_amount, IF(v_calc = 'DEFAULT', 0, 1) AS is_overridden, v_changed AS amounts_changed;
END$$

-- ---------------------------------------------------------------------
-- hrms_save_payroll_manual_input (before C-131..C-134)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_save_payroll_manual_input$$
CREATE PROCEDURE hrms_save_payroll_manual_input(
    IN p_emp_id        VARCHAR(20),
    IN p_target_emp_id VARCHAR(20),
    IN p_month         INT,
    IN p_year          INT,
    IN p_component_id  BIGINT,
    IN p_amount        DECIMAL(12,2),
    IN p_remarks       VARCHAR(255)
)
BEGIN
    DECLARE v_ok     TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_manual INT DEFAULT 0;
    DECLARE v_cstat  VARCHAR(30);
    DECLARE v_detail BIGINT;

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    SELECT COUNT(*) INTO v_manual FROM salary_component_master
     WHERE component_id = p_component_id AND is_active = 1 AND (is_manual = 1 OR calculation_type = 'MANUAL');
    SELECT MAX(cycle_status) INTO v_cstat FROM payroll_cycles WHERE payroll_month = p_month AND payroll_year = p_year;
    SELECT MAX(d.payroll_detail_id) INTO v_detail
      FROM employee_payroll_details d
      JOIN payroll_runs pr ON pr.payroll_run_id = d.payroll_run_id
      JOIN payroll_cycles pc ON pc.payroll_cycle_id = pr.payroll_cycle_id
     WHERE pc.payroll_month = p_month AND pc.payroll_year = p_year AND d.emp_id = p_target_emp_id;

    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can enter manual amounts.' AS remarks, NULL AS payroll_detail_id;
    ELSEIF v_manual = 0 THEN
        SELECT 'N' AS status, 'This is not an active manual component.' AS remarks, NULL AS payroll_detail_id;
    ELSEIF p_month IS NULL OR p_month NOT BETWEEN 1 AND 12 OR p_year IS NULL OR p_year NOT BETWEEN 2000 AND 2100 THEN
        SELECT 'N' AS status, 'Invalid payroll month or year.' AS remarks, NULL AS payroll_detail_id;
    ELSEIF v_cstat IN ('APPROVED', 'FINALIZED', 'PARTIALLY_PAID', 'PAID', 'CLOSED') THEN
        SELECT 'N' AS status, CONCAT('The payroll of this month is ', v_cstat, '. Manual amounts can no longer change.') AS remarks,
               NULL AS payroll_detail_id;
    ELSEIF p_amount IS NULL OR p_amount < 0 THEN
        SELECT 'N' AS status, 'Amount must be 0 or more.' AS remarks, NULL AS payroll_detail_id;
    ELSEIF p_amount = 0 THEN
        DELETE FROM payroll_manual_inputs
         WHERE emp_id = p_target_emp_id AND payroll_month = p_month AND payroll_year = p_year AND component_id = p_component_id;
        SELECT 'Y' AS status, 'Manual amount removed.' AS remarks, v_detail AS payroll_detail_id;
    ELSE
        INSERT INTO payroll_manual_inputs (emp_id, payroll_month, payroll_year, component_id, amount, remarks, created_by)
        VALUES (p_target_emp_id, p_month, p_year, p_component_id, p_amount, NULLIF(TRIM(p_remarks), ''), p_emp_id)
        ON DUPLICATE KEY UPDATE amount = VALUES(amount), remarks = VALUES(remarks), created_by = VALUES(created_by);
        SELECT 'Y' AS status, 'Manual amount saved.' AS remarks, v_detail AS payroll_detail_id;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- sp_generate_payroll_attendance (before C-131..C-134)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_generate_payroll_attendance$$
CREATE PROCEDURE `sp_generate_payroll_attendance`(
    IN p_month INT,
    IN p_year INT,
    IN p_admin_emp_id VARCHAR(20)
)
main_block: BEGIN

    DECLARE done INT DEFAULT FALSE;

    DECLARE v_emp_id VARCHAR(20);
    DECLARE v_admin_category VARCHAR(20);

    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;
    DECLARE v_month_start DATE;
    DECLARE v_previous_month DATE;

    DECLARE v_start_day INT;
    DECLARE v_end_day INT;

    DECLARE v_finalized_count INT DEFAULT 0;
    DECLARE v_generated_count INT DEFAULT 0;

    DECLARE v_total_days DECIMAL(5,2) DEFAULT 0;
    DECLARE v_working_days DECIMAL(5,2) DEFAULT 0;

    DECLARE v_present DECIMAL(5,2) DEFAULT 0;
    DECLARE v_wfh DECIMAL(5,2) DEFAULT 0;
    DECLARE v_leave DECIMAL(5,2) DEFAULT 0;
    DECLARE v_holiday DECIMAL(5,2) DEFAULT 0;
    DECLARE v_weekoff DECIMAL(5,2) DEFAULT 0;
    DECLARE v_absent DECIMAL(5,2) DEFAULT 0;

    DECLARE v_late INT DEFAULT 0;
    DECLARE v_half_days DECIMAL(5,2) DEFAULT 0;
    DECLARE v_overtime DECIMAL(6,2) DEFAULT 0;

    DECLARE v_paid DECIMAL(5,2) DEFAULT 0;
    DECLARE v_unpaid DECIMAL(5,2) DEFAULT 0;

    DECLARE v_error_no INT DEFAULT 0;
    DECLARE v_error_message TEXT;

    
    DECLARE emp_cursor CURSOR FOR
        SELECT DISTINCT TRIM(emp_id)
        FROM user_login_details
        WHERE UPPER(TRIM(status)) = 'ACTIVE'
          AND emp_id IS NOT NULL
          AND TRIM(emp_id) <> ''
        ORDER BY TRIM(emp_id);

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET done = TRUE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            v_error_no = MYSQL_ERRNO,
            v_error_message = MESSAGE_TEXT;

        ROLLBACK;

        SELECT
            'N' AS status,
            CONCAT(
                'Database error [',
                COALESCE(v_error_no, 0),
                ']: ',
                COALESCE(v_error_message, 'Unknown error')
            ) AS message;

    END;

    SET time_zone = '+05:30';

    

    IF p_admin_emp_id IS NULL
       OR TRIM(p_admin_emp_id) = '' THEN

        SELECT
            'N' AS status,
            'Admin Employee ID is required.' AS message;

        LEAVE main_block;

    END IF;

    

    IF p_month IS NULL
       OR p_month NOT BETWEEN 1 AND 12
       OR p_year IS NULL
       OR p_year NOT BETWEEN 1900 AND 9999 THEN

        SELECT
            'N' AS status,
            'Invalid payroll month or year.' AS message;

        LEAVE main_block;

    END IF;

    

    SET v_admin_category = NULL;

    SELECT MAX(UPPER(TRIM(user_category)))
    INTO v_admin_category
    FROM user_login_details
    WHERE emp_id = TRIM(p_admin_emp_id)
      AND LOWER(TRIM(status)) = 'active';   -- C-119

    IF v_admin_category IS NULL
       OR v_admin_category NOT IN ('ADMIN', 'HR') THEN

        SELECT 'N' AS status,
               'Access denied: only active ADMIN or HR users can generate payroll attendance.' AS message;
        LEAVE main_block;

    END IF;

    

    SET v_start_day = NULL;
    SET v_end_day = NULL;

    SELECT
        payroll_cycle_start_day,
        payroll_cycle_end_day
    INTO
        v_start_day,
        v_end_day
    FROM company_settings
    ORDER BY id
    LIMIT 1;

    IF v_start_day IS NULL
       OR v_end_day IS NULL
       OR v_start_day NOT BETWEEN 1 AND 31
       OR v_end_day NOT BETWEEN 1 AND 31 THEN

        SELECT
            'N' AS status,
            'Invalid or missing payroll cycle settings in company_settings.'
                AS message;

        LEAVE main_block;

    END IF;

    

    SET v_month_start = STR_TO_DATE(
        CONCAT(p_year, '-', LPAD(p_month, 2, '0'), '-01'),
        '%Y-%m-%d'
    );

    SET v_previous_month =
        DATE_SUB(v_month_start, INTERVAL 1 MONTH);

    IF v_start_day > v_end_day THEN

        

        SET v_start_date = DATE_ADD(
            v_previous_month,
            INTERVAL (
                LEAST(
                    v_start_day,
                    DAY(LAST_DAY(v_previous_month))
                ) - 1
            ) DAY
        );

        SET v_end_date = DATE_ADD(
            v_month_start,
            INTERVAL (
                LEAST(
                    v_end_day,
                    DAY(LAST_DAY(v_month_start))
                ) - 1
            ) DAY
        );

    ELSE

        

        SET v_start_date = DATE_ADD(
            v_month_start,
            INTERVAL (
                LEAST(
                    v_start_day,
                    DAY(LAST_DAY(v_month_start))
                ) - 1
            ) DAY
        );

        SET v_end_date = DATE_ADD(
            v_month_start,
            INTERVAL (
                LEAST(
                    v_end_day,
                    DAY(LAST_DAY(v_month_start))
                ) - 1
            ) DAY
        );

    END IF;

    IF v_start_date > v_end_date THEN

        SELECT
            'N' AS status,
            'Calculated payroll start date is after the end date.'
                AS message;

        LEAVE main_block;

    END IF;

    SET v_total_days =
        DATEDIFF(v_end_date, v_start_date) + 1;

    

    SELECT COUNT(*)
    INTO v_finalized_count
    FROM payroll_attendance_summary
    WHERE payroll_month = p_month
      AND payroll_year = p_year
      AND is_finalized = 'Y';

    IF v_finalized_count > 0 THEN

        SELECT
            'N' AS status,
            'Attendance is already finalized for this month and cannot be regenerated.'
                AS message;

        LEAVE main_block;

    END IF;

    

    START TRANSACTION;

    

    DELETE FROM payroll_attendance_summary
    WHERE payroll_month = p_month
      AND payroll_year = p_year
      AND (
          is_finalized = 'N'
          OR is_finalized IS NULL
      );

    

    SET done = FALSE;
    SET v_generated_count = 0;

    OPEN emp_cursor;

    read_loop: LOOP

        FETCH emp_cursor INTO v_emp_id;

        IF done THEN
            LEAVE read_loop;
        END IF;

        

        SET v_present = 0;
        SET v_wfh = 0;
        SET v_leave = 0;
        SET v_holiday = 0;
        SET v_weekoff = 0;
        SET v_absent = 0;

        SET v_late = 0;
        SET v_half_days = 0;
        SET v_overtime = 0;

        SET v_paid = 0;
        SET v_unpaid = 0;

        

        SELECT
            

            COALESCE(SUM(
                CASE
                    WHEN UPPER(TRIM(status))
                         IN ('PRESENT', 'LATE')
                    THEN 1
                    ELSE 0
                END
            ), 0),

            COALESCE(SUM(
                CASE
                    WHEN UPPER(TRIM(status)) = 'WFH'
                    THEN 1
                    ELSE 0
                END
            ), 0),

            COALESCE(SUM(
                CASE
                    WHEN UPPER(TRIM(status))
                         IN ('LEAVE', 'PL', 'SL', 'CL', 'ML')
                    THEN 1
                    ELSE 0
                END
            ), 0),

            COALESCE(SUM(
                CASE
                    WHEN UPPER(TRIM(status)) = 'HOLIDAY'
                    THEN 1
                    ELSE 0
                END
            ), 0),

            COALESCE(SUM(
                CASE
                    WHEN UPPER(TRIM(status))
                         IN ('WEEKOFF', 'WEEKLY_OFF')
                    THEN 1
                    ELSE 0
                END
            ), 0),

            COALESCE(SUM(
                CASE
                    WHEN UPPER(TRIM(status))
                         IN ('ABSENT', 'A', 'LOP')
                    THEN 1
                    ELSE 0
                END
            ), 0),

            COALESCE(SUM(
                CASE
                    WHEN UPPER(TRIM(status)) = 'LATE'
                    THEN 1
                    ELSE 0
                END
            ), 0)

        INTO
            v_present,
            v_wfh,
            v_leave,
            v_holiday,
            v_weekoff,
            v_absent,
            v_late

        FROM attendance
        WHERE emp_id = v_emp_id
          AND attendance_date BETWEEN v_start_date AND v_end_date;

        

        SET v_working_days = GREATEST(
            v_total_days - v_holiday - v_weekoff,
            0
        );

        

        SET v_paid =
            v_present
            + v_wfh
            + v_leave
            + v_holiday
            + v_weekoff;

        SET v_unpaid = v_absent;

        

        SET v_half_days = 0;
        SET v_overtime = 0;

        

        INSERT INTO payroll_attendance_summary (
            emp_id,
            payroll_month,
            payroll_year,
            total_days,
            working_days,
            present_days,
            wfh_days,
            leave_days,
            holiday_days,
            weekly_off_days,
            absent_days,
            paid_days,
            unpaid_days,
            late_count,
            half_days,
            overtime_hours,
            is_finalized,
            created_at,
    updated_at
        )
        VALUES (
            v_emp_id,
            p_month,
            p_year,
            v_total_days,
            v_working_days,
            v_present,
            v_wfh,
            v_leave,
            v_holiday,
            v_weekoff,
            v_absent,
            v_paid,
            v_unpaid,
            v_late,
            v_half_days,
            v_overtime,
            'N',
            CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
        );

        SET v_generated_count = v_generated_count + 1;

    END LOOP;

    CLOSE emp_cursor;

    

    IF v_generated_count = 0 THEN

        ROLLBACK;

        SELECT
            'N' AS status,
            'No active employees found. No payroll attendance summaries were generated.'
                AS message;

        LEAVE main_block;

    END IF;

    

    COMMIT;

    SELECT
        'Y' AS status,
        CONCAT(
            'Payroll attendance generated successfully for period ',
            DATE_FORMAT(v_start_date, '%d-%b-%Y'),
            ' to ',
            DATE_FORMAT(v_end_date, '%d-%b-%Y'),
            '. Employees processed: ',
            v_generated_count,
            '. Status: NOT FINALIZED.'
        ) AS message,
        v_start_date AS period_start,
        v_end_date AS period_end,
        v_generated_count AS generated_employee_count;

END$$

-- ---------------------------------------------------------------------
-- finalize_payroll_attendance_proc (before C-131..C-134)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS finalize_payroll_attendance_proc$$
CREATE PROCEDURE `finalize_payroll_attendance_proc`(
    IN p_emp_id VARCHAR(20),
    IN p_month INT,
    IN p_year INT
)
main_block: BEGIN

    DECLARE v_user_category VARCHAR(20);

    DECLARE v_total_records INT DEFAULT 0;
    DECLARE v_finalized_records INT DEFAULT 0;
    DECLARE v_duplicate_groups INT DEFAULT 0;

    DECLARE v_error_no INT DEFAULT 0;
    DECLARE v_error_message TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            v_error_no = MYSQL_ERRNO,
            v_error_message = MESSAGE_TEXT;

        ROLLBACK;

        SELECT
            'N' AS status,
            CONCAT(
                'Database error [',
                COALESCE(v_error_no, 0),
                ']: ',
                COALESCE(v_error_message, 'Unknown error')
            ) AS remarks;

    END;

    SET time_zone = '+05:30';

    

    IF p_emp_id IS NULL OR TRIM(p_emp_id) = '' THEN

        SELECT
            'N' AS status,
            'Requester employee ID is required.' AS remarks;

        LEAVE main_block;

    END IF;

    

    IF p_month IS NULL
       OR p_month NOT BETWEEN 1 AND 12
       OR p_year IS NULL
       OR p_year NOT BETWEEN 1900 AND 9999 THEN

        SELECT
            'N' AS status,
            'Invalid month or year.' AS remarks;

        LEAVE main_block;

    END IF;

    

    SET v_user_category = NULL;

    SELECT MAX(UPPER(TRIM(user_category)))
    INTO v_user_category
    FROM user_login_details
    WHERE emp_id = TRIM(p_emp_id)
      AND LOWER(TRIM(status)) = 'active';   -- C-118

    IF v_user_category IS NULL
       OR v_user_category NOT IN ('ADMIN', 'HR') THEN

        SELECT
            'N' AS status,
            'Access denied: only active ADMIN or HR users can finalize attendance.'
                AS remarks;

        LEAVE main_block;

    END IF;

    

    SELECT
        COUNT(*),
        COALESCE(SUM(is_finalized = 'Y'), 0)
    INTO
        v_total_records,
        v_finalized_records
    FROM payroll_attendance_summary
    WHERE payroll_month = p_month
      AND payroll_year = p_year;

    IF v_total_records = 0 THEN

        SELECT
            'N' AS status,
            'Attendance not generated. No payroll attendance summaries exist for this month and year.'
                AS remarks;

        LEAVE main_block;

    END IF;

    

    SELECT COUNT(*)
    INTO v_duplicate_groups
    FROM (
        SELECT emp_id
        FROM payroll_attendance_summary
        WHERE payroll_month = p_month
          AND payroll_year = p_year
        GROUP BY emp_id
        HAVING COUNT(*) > 1
    ) AS duplicate_employees;

    IF v_duplicate_groups > 0 THEN

        SELECT
            'N' AS status,
            CONCAT(
                'Finalization blocked. ',
                v_duplicate_groups,
                ' employee(s) have duplicate attendance summaries. ',
                'Resolve the duplicates before finalizing.'
            ) AS remarks;

        LEAVE main_block;

    END IF;

    

    IF v_finalized_records = v_total_records THEN

        SELECT
            'N' AS status,
            'Attendance is already finalized for the selected month and year.'
                AS remarks;

        LEAVE main_block;

    END IF;

    

    START TRANSACTION;

    UPDATE payroll_attendance_summary
    SET
        is_finalized = 'Y',
        updated_at = NOW()
    WHERE payroll_month = p_month
      AND payroll_year = p_year
      AND (is_finalized IS NULL OR is_finalized <> 'Y');

    COMMIT;

    SELECT
        'Y' AS status,
        CONCAT(
            'Payroll attendance finalized successfully for ',
            LPAD(p_month, 2, '0'),
            '/',
            p_year,
            '. Total summary records: ',
            v_total_records,
            '.'
        ) AS remarks;

END$$

-- ---------------------------------------------------------------------
-- sp_admin_edit_absent_attendance (before C-131..C-134)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_admin_edit_absent_attendance$$
CREATE PROCEDURE `sp_admin_edit_absent_attendance`(
    IN  p_emp_id        VARCHAR(20),
    IN  p_att_date      DATE,
    IN  p_edit_type     VARCHAR(10),   
    IN  p_admin_emp_id  VARCHAR(20),
    IN  p_punch_in      DATETIME,
    IN  p_punch_out     DATETIME,
    OUT p_out_status    CHAR(1),
    OUT p_out_message   VARCHAR(500)
)
BEGIN
    main_block: BEGIN
    
    DECLARE v_leave_type_id     INT    DEFAULT NULL;
    DECLARE v_lop_type_id       INT    DEFAULT NULL;
    DECLARE v_balance_id        BIGINT DEFAULT NULL;
    DECLARE v_closing_balance   DECIMAL(5,2) DEFAULT 0;
    DECLARE v_att_exists        INT    DEFAULT 0;
    DECLARE v_att_status        VARCHAR(30) DEFAULT '';
    DECLARE v_leave_year        INT;
    DECLARE v_new_att_status    VARCHAR(20) DEFAULT 'ABSENT';
    DECLARE v_approved_days     DECIMAL(5,2) DEFAULT 1.00;
    DECLARE v_lop_days          DECIMAL(5,2) DEFAULT 0.00;
    DECLARE v_app_leave_type_id INT DEFAULT NULL;
    DECLARE v_app_id            BIGINT DEFAULT NULL;
    DECLARE v_reason_text       VARCHAR(500) DEFAULT '';
    DECLARE v_user_category     VARCHAR(20)  DEFAULT NULL;   -- C-120
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            @sq_errno = MYSQL_ERRNO,
            @sq_msg   = MESSAGE_TEXT;
        ROLLBACK;
        SET p_out_status  = 'N';
        SET p_out_message = CONCAT('DB Error [', IFNULL(@sq_errno,'?'), ']: ', IFNULL(@sq_msg, 'Unknown'));
    END;

    -- C-120: who is doing it - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_admin_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SET p_out_status  = 'N';
        SET p_out_message = 'Access denied: only active ADMIN or HR users can edit attendance.';
        LEAVE main_block;
    END IF;

    SET p_out_status  = 'N';
    SET p_out_message = 'Init';

    SET v_leave_year = YEAR(p_att_date);

    
    SELECT 1, UPPER(TRIM(status))
    INTO   v_att_exists, v_att_status
    FROM   attendance
    WHERE  emp_id = p_emp_id AND attendance_date = p_att_date
    LIMIT  1;

    IF v_att_exists = 0 THEN
        SET p_out_status  = 'N';
        SET p_out_message = CONCAT('No attendance record for ', p_emp_id, ' on ', p_att_date);
        LEAVE main_block;
    END IF;

    IF v_att_status NOT IN ('ABSENT', 'A') THEN
        SET p_out_status  = 'N';
        SET p_out_message = CONCAT('Day is not ABSENT (current: ', v_att_status, '). Only ABSENT days can be edited.');
        LEAVE main_block;
    END IF;

    
    SELECT leave_type_id INTO v_lop_type_id
    FROM   leave_type
    WHERE  UPPER(TRIM(leave_code)) = 'LOP'
      AND  year   = v_leave_year
      AND  status = 'A'
    ORDER  BY leave_type_id ASC
    LIMIT  1;

    START TRANSACTION;

    
    IF UPPER(p_edit_type) = 'WFH' THEN

        
        SELECT leave_type_id INTO v_leave_type_id
        FROM   leave_type
        WHERE  UPPER(TRIM(leave_code)) = 'WFH'
          AND  year   = v_leave_year
          AND  status = 'A'
        ORDER  BY leave_type_id ASC LIMIT 1;

        IF v_leave_type_id IS NULL THEN
            ROLLBACK;
            SET p_out_status  = 'N';
            SET p_out_message = CONCAT('WFH leave type not found for year ', v_leave_year);
            LEAVE main_block;
        END IF;

        
        SELECT balance_id, closing_balance
        INTO   v_balance_id, v_closing_balance
        FROM   emp_leave_balance
        WHERE  emp_id        = p_emp_id
          AND  leave_type_id = v_leave_type_id
          AND  year          = v_leave_year
        ORDER  BY balance_id ASC LIMIT 1;
        IF v_balance_id IS NULL THEN
            
            INSERT INTO emp_leave_balance (emp_id, leave_type_id, year, opening_balance, credited, availed, closing_balance)
            VALUES (p_emp_id, v_leave_type_id, v_leave_year, 0, 0, 0, 0);
            SET v_balance_id = LAST_INSERT_ID();
        END IF;

        
        UPDATE emp_leave_balance
        SET    availed          = availed + 1,
               closing_balance  = closing_balance - 1,
               updated_on       = NOW(),
               updated_at       = NOW()
        WHERE  balance_id = v_balance_id;

        SET v_approved_days = 1.00;
        SET v_lop_days      = 0.00;
        SET v_new_att_status = 'WFH';
        SET v_reason_text = CONCAT('Admin adjusted: Absent on ', DATE_FORMAT(p_att_date,'%d-%b-%Y'), ' changed to WFH.');

        
        SET v_app_leave_type_id = v_leave_type_id;
        INSERT INTO leave_application (
            emp_id, leave_type_id,
            from_date, to_date,
            total_days, applied_days, approved_leave_days, lop_days,
            reason, status,
            applied_on, approved_by, approved_on,
            received_on, updated_on
        ) VALUES (
            p_emp_id, v_app_leave_type_id,
            p_att_date, p_att_date,
            1.00, 1.00, v_approved_days, v_lop_days,
            v_reason_text, 'APPROVED',
            NOW(), p_admin_emp_id, NOW(),
            NOW(), NOW()
        );
        SET v_app_id = LAST_INSERT_ID();

        
        UPDATE attendance
        SET    status     = v_new_att_status,
               punch_in   = IF(v_new_att_status = 'WFH', p_punch_in, NULL),
               punch_out  = IF(v_new_att_status = 'WFH', p_punch_out, NULL),
               updated_at = NOW()
        WHERE  emp_id = p_emp_id AND attendance_date = p_att_date;

        COMMIT;

        IF v_new_att_status = 'WFH' THEN
            SET p_out_status  = 'Y';
            SET p_out_message = CONCAT('WFH applied for ', DATE_FORMAT(p_att_date,'%d %b %Y'), '. WFH balance deducted. Application #', v_app_id, ' created.');
        ELSE
            SET p_out_status  = 'Y';
            SET p_out_message = CONCAT('No WFH balance available. Marked as LOP for ', DATE_FORMAT(p_att_date,'%d %b %Y'), '. Application #', v_app_id, ' created.');
        END IF;

    
    ELSEIF UPPER(p_edit_type) IN ('PL','SL','ML') THEN

        
        SELECT leave_type_id INTO v_leave_type_id
        FROM   leave_type
        WHERE  UPPER(TRIM(leave_code)) = UPPER(TRIM(p_edit_type))
          AND  year   = v_leave_year
          AND  status = 'A'
        ORDER  BY leave_type_id ASC LIMIT 1;

        IF v_leave_type_id IS NULL THEN
            ROLLBACK;
            SET p_out_status  = 'N';
            SET p_out_message = CONCAT(UPPER(p_edit_type), ' leave type not found for year ', v_leave_year);
            LEAVE main_block;
        END IF;

        
        SELECT balance_id, closing_balance
        INTO   v_balance_id, v_closing_balance
        FROM   emp_leave_balance
        WHERE  emp_id        = p_emp_id
          AND  leave_type_id = v_leave_type_id
          AND  year          = v_leave_year
        ORDER  BY balance_id ASC LIMIT 1;

        IF v_balance_id IS NULL THEN
            ROLLBACK;
            SET p_out_status  = 'N';
            SET p_out_message = CONCAT('No balance record for ', UPPER(p_edit_type), ' in year ', v_leave_year, ' for employee ', p_emp_id);
            LEAVE main_block;
        END IF;

        IF v_closing_balance >= 1 THEN
            
            UPDATE emp_leave_balance
            SET    availed          = availed + 1,
                   closing_balance  = closing_balance - 1,
                   updated_on       = NOW(),
                   updated_at       = NOW()
            WHERE  balance_id = v_balance_id;

            SET v_approved_days  = 1.00;
            SET v_lop_days       = 0.00;
            SET v_new_att_status = 'LEAVE';
            SET v_app_leave_type_id = v_leave_type_id;
            SET v_reason_text = CONCAT('Admin adjusted: Absent on ', DATE_FORMAT(p_att_date,'%d-%b-%Y'), ' changed to ', UPPER(p_edit_type), ' leave. Balance deducted.');

            INSERT INTO leave_application (
                emp_id, leave_type_id,
                from_date, to_date,
                total_days, applied_days, approved_leave_days, lop_days,
                reason, status,
                applied_on, approved_by, approved_on,
                received_on, updated_on
            ) VALUES (
                p_emp_id, v_app_leave_type_id,
                p_att_date, p_att_date,
                1.00, 1.00, 1.00, 0.00,
                v_reason_text, 'APPROVED',
                NOW(), p_admin_emp_id, NOW(),
                NOW(), NOW()
            );
            SET v_app_id = LAST_INSERT_ID();

            UPDATE attendance
            SET    status     = 'LEAVE',
                   punch_in   = NULL,
                   punch_out  = NULL,
                   updated_at = NOW()
            WHERE  emp_id = p_emp_id AND attendance_date = p_att_date;

            COMMIT;
            SET p_out_status  = 'Y';
            SET p_out_message = CONCAT(UPPER(p_edit_type), ' leave applied for ', DATE_FORMAT(p_att_date,'%d %b %Y'), '. Balance deducted. Application #', v_app_id, ' created.');

        ELSE
            
            SET v_app_leave_type_id = IFNULL(v_lop_type_id, v_leave_type_id);
            SET v_reason_text = CONCAT('Admin adjusted: Absent on ', DATE_FORMAT(p_att_date,'%d-%b-%Y'), ' - no ', UPPER(p_edit_type), ' balance, marked as LOP.');

            INSERT INTO leave_application (
                emp_id, leave_type_id,
                from_date, to_date,
                total_days, applied_days, approved_leave_days, lop_days,
                reason, status,
                applied_on, approved_by, approved_on,
                received_on, updated_on
            ) VALUES (
                p_emp_id, v_app_leave_type_id,
                p_att_date, p_att_date,
                1.00, 1.00, 0.00, 1.00,
                v_reason_text, 'APPROVED',
                NOW(), p_admin_emp_id, NOW(),
                NOW(), NOW()
            );
            SET v_app_id = LAST_INSERT_ID();

            UPDATE attendance
            SET    status     = 'ABSENT',
                   punch_in   = NULL,
                   punch_out  = NULL,
                   updated_at = NOW()
            WHERE  emp_id = p_emp_id AND attendance_date = p_att_date;

            COMMIT;
            SET p_out_status  = 'Y';
            SET p_out_message = CONCAT('No ', UPPER(p_edit_type), ' balance. Marked as LOP for ', DATE_FORMAT(p_att_date,'%d %b %Y'), '. Application #', v_app_id, ' created.');
        END IF;

    
    ELSEIF UPPER(p_edit_type) = 'LOP' THEN

        SET v_app_leave_type_id = v_lop_type_id;

        IF v_app_leave_type_id IS NULL THEN
            ROLLBACK;
            SET p_out_status  = 'N';
            SET p_out_message = CONCAT('LOP leave type not found for year ', v_leave_year);
            LEAVE main_block;
        END IF;

        SET v_reason_text = CONCAT('Admin adjusted: Absent on ', DATE_FORMAT(p_att_date,'%d-%b-%Y'), ' marked as Loss of Pay (LOP).');

        INSERT INTO leave_application (
            emp_id, leave_type_id,
            from_date, to_date,
            total_days, applied_days, approved_leave_days, lop_days,
            reason, status,
            applied_on, approved_by, approved_on,
            received_on, updated_on
        ) VALUES (
            p_emp_id, v_app_leave_type_id,
            p_att_date, p_att_date,
            1.00, 1.00, 0.00, 1.00,
            v_reason_text, 'APPROVED',
            NOW(), p_admin_emp_id, NOW(),
            NOW(), NOW()
        );
        SET v_app_id = LAST_INSERT_ID();

        UPDATE attendance
        SET    status     = 'ABSENT',
               punch_in   = NULL,
               punch_out  = NULL,
               updated_at = NOW()
        WHERE  emp_id = p_emp_id AND attendance_date = p_att_date;

        COMMIT;
        SET p_out_status  = 'Y';
        SET p_out_message = CONCAT('Marked as Loss of Pay (LOP) for ', DATE_FORMAT(p_att_date,'%d %b %Y'), '. Application #', v_app_id, ' created.');

    ELSE
        ROLLBACK;
        SET p_out_status  = 'N';
        SET p_out_message = CONCAT('Invalid edit type: "', p_edit_type, '". Allowed: WFH, PL, SL, ML, LOP.');
    END IF;

    END main_block;

END$$

-- new routines of the audit trail
DROP PROCEDURE IF EXISTS hrms_payroll_audit_add$$
DROP PROCEDURE IF EXISTS hrms_payroll_audit_event$$
DROP PROCEDURE IF EXISTS hrms_payroll_audit_list$$
DROP FUNCTION IF EXISTS hrms_audit_component_json$$
DROP FUNCTION IF EXISTS hrms_audit_salary_json$$
DROP FUNCTION IF EXISTS hrms_audit_attendance_json$$

DELIMITER ;
