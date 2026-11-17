
-- ---------------------------------------------------------------------
-- P2-011  hrms_esi_wage_limit (C-085): the ESI wage limit is the top of
--         the ESI slabs: the slabs of the components that apply only when
--         ESI_APPLICABLE (no component codes in the code any more).
--         21000 only when no such slab exists (the statutory limit).
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS hrms_esi_wage_limit$$
CREATE FUNCTION hrms_esi_wage_limit() RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_limit DECIMAL(12,2);
    SELECT MAX(s.slab_max_value) INTO v_limit
      FROM salary_component_slab s
      JOIN salary_component_master m ON m.component_id = s.component_id
     WHERE UPPER(m.eligibility_parameter) IN ('ESI_APPLICABLE', 'EMPLOYEE_ESI_ELIGIBLE')
       AND m.is_active = 1
       AND s.is_active = 1
       AND s.result_value > 0
       AND s.slab_max_value IS NOT NULL
       AND (s.effective_from IS NULL OR s.effective_from <= CURDATE())
       AND (s.effective_to IS NULL OR s.effective_to >= CURDATE());
    RETURN COALESCE(v_limit, 21000.00);
END$$

-- ---------------------------------------------------------------------
-- P2-012  hrms_formula_names (P1-005): the variables now come from
--         payroll_variables. A TOTAL variable is listed only when no
--         component has its code (the component is listed instead).
--         auto_total: phase 3 sets it for totals built from the
--         "counts in total" ticks.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_formula_names$$
CREATE PROCEDURE hrms_formula_names(IN p_emp_id VARCHAR(20))
fn: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can manage salary components.' AS remarks;
        LEAVE fn;
    END IF;
    SELECT 'Y' AS status, '' AS remarks, x.*
      FROM (
            SELECT 'VARIABLE' AS kind, v.var_code AS code, v.var_name AS label, v.data_type,
                   NULL AS component_type, NULL AS component_id, 0 AS calculation_order, 1 AS is_active,
                   v.sort_order, v.var_kind, v.description, 0 AS auto_total
              FROM payroll_variables v
             WHERE v.is_active = 1
               AND NOT (v.var_kind = 'TOTAL'
                        AND EXISTS (SELECT 1 FROM salary_component_master m WHERE UPPER(m.component_code) = v.var_code))
            UNION ALL
            SELECT IF(m.calculation_scope = 'AGGREGATE', 'TOTAL', 'COMPONENT'), UPPER(m.component_code), m.component_name,
                   'NUMBER', m.component_type, m.component_id, m.calculation_order, m.is_active,
                   1000 + m.calculation_order, NULL, NULL, 0
              FROM salary_component_master m
           ) x
     ORDER BY FIELD(x.kind, 'VARIABLE', 'COMPONENT', 'TOTAL'), x.sort_order, x.code;
END$$

-- ---------------------------------------------------------------------
-- P2-013  hrms_payroll_variable_list : the Payroll variables page.
--         Every variable with what uses it (components: formula, "% of",
--         slabs, "applies only when") and how many employees have their
--         own value. Who may call: active ADMIN or HR.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_variable_list$$
CREATE PROCEDURE hrms_payroll_variable_list(IN p_emp_id VARCHAR(20))
vl: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view payroll variables.' AS remarks;
        LEAVE vl;
    END IF;
    SET SESSION group_concat_max_len = 100000;
    SELECT 'Y' AS status, '' AS remarks,
           v.var_code, v.var_name, v.description, v.var_kind, v.data_type, v.default_value, v.is_active, v.sort_order,
           (SELECT GROUP_CONCAT(DISTINCT m.component_code ORDER BY m.calculation_order SEPARATOR ', ')
              FROM salary_component_master m
             WHERE m.is_active = 1
               AND (CONCAT(' ', REGEXP_REPLACE(UPPER(COALESCE(m.formula_expression, '')), '[^A-Z0-9_]', ' '), ' ')
                        LIKE CONCAT('% ', v.var_code, ' %')
                    OR UPPER(m.percentage_base) = v.var_code
                    OR UPPER(m.eligibility_parameter) = v.var_code
                    OR EXISTS (SELECT 1 FROM salary_component_slab s
                                WHERE s.component_id = m.component_id AND s.is_active = 1
                                  AND (UPPER(s.slab_based_on) = v.var_code OR UPPER(s.percentage_base) = v.var_code)))) AS used_by,
           (SELECT COUNT(*) FROM employee_payroll_variables e WHERE e.var_code = v.var_code) AS employees_set
      FROM payroll_variables v
     ORDER BY FIELD(v.var_kind, 'EMPLOYEE', 'SYSTEM', 'TOTAL'), v.sort_order, v.var_code;
END$$

-- ---------------------------------------------------------------------
-- P2-014  hrms_payroll_variable_save : add or change an EMPLOYEE variable.
--         SYSTEM and TOTAL variables cannot be changed. A variable in use
--         cannot be switched off, and one used in "applies only when"
--         must stay Yes/No. When the default or the on/off state of a
--         variable in use changes, every salary is recalculated (and
--         calculated payroll cycles go back, as for a component change).
--         Who may call: active ADMIN or HR.
--         Returns: status, remarks.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_variable_save$$
CREATE PROCEDURE hrms_payroll_variable_save(
    IN p_emp_id      VARCHAR(20),
    IN p_code        VARCHAR(40),
    IN p_name        VARCHAR(100),
    IN p_description VARCHAR(500),
    IN p_data_type   VARCHAR(10),
    IN p_default     DECIMAL(18,4),
    IN p_is_active   TINYINT
)
vs: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;
    DECLARE v_code    VARCHAR(40);
    DECLARE v_type    VARCHAR(10);
    DECLARE v_default DECIMAL(18,4);
    DECLARE v_active  TINYINT;
    DECLARE v_kind    VARCHAR(10) DEFAULT NULL;
    DECLARE v_old_default DECIMAL(18,4);
    DECLARE v_old_active  TINYINT;
    DECLARE v_old_type    VARCHAR(10);
    DECLARE v_used    TEXT DEFAULT NULL;
    DECLARE v_elig    TEXT DEFAULT NULL;
    DECLARE v_msg     VARCHAR(500) DEFAULT NULL;
    DECLARE v_structures INT DEFAULT 0;
    DECLARE v_changed INT DEFAULT 0;
    DECLARE v_errors  INT DEFAULT 0;
    DECLARE v_text    VARCHAR(500);
    DECLARE v_notice  VARCHAR(500);
    DECLARE v_err     VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'The variable could not be saved. Nothing was changed.') AS remarks;
    END;

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_code    = UPPER(TRIM(COALESCE(p_code, '')));
    SET v_type    = UPPER(TRIM(COALESCE(NULLIF(TRIM(p_data_type), ''), 'NUMBER')));
    SET v_default = COALESCE(p_default, 0);
    SET v_active  = IF(COALESCE(p_is_active, 1) = 1, 1, 0);
    SET SESSION group_concat_max_len = 100000;

    SELECT MAX(var_kind), MAX(default_value), MAX(is_active), MAX(data_type)
      INTO v_kind, v_old_default, v_old_active, v_old_type
      FROM payroll_variables WHERE var_code = v_code;

    -- what uses it (active components)
    SELECT GROUP_CONCAT(DISTINCT m.component_code ORDER BY m.component_code SEPARATOR ', ') INTO v_used
      FROM salary_component_master m
     WHERE m.is_active = 1
       AND (CONCAT(' ', REGEXP_REPLACE(UPPER(COALESCE(m.formula_expression, '')), '[^A-Z0-9_]', ' '), ' ')
                LIKE CONCAT('% ', v_code, ' %')
            OR UPPER(m.percentage_base) = v_code
            OR UPPER(m.eligibility_parameter) = v_code
            OR EXISTS (SELECT 1 FROM salary_component_slab s
                        WHERE s.component_id = m.component_id AND s.is_active = 1
                          AND (UPPER(s.slab_based_on) = v_code OR UPPER(s.percentage_base) = v_code)));
    SELECT GROUP_CONCAT(m.component_code ORDER BY m.component_code SEPARATOR ', ') INTO v_elig
      FROM salary_component_master m
     WHERE m.is_active = 1 AND UPPER(m.eligibility_parameter) = v_code;

    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can change payroll variables.';
    ELSEIF v_code NOT REGEXP '^[A-Z][A-Z0-9_]{1,39}$' THEN
        SET v_msg = 'Code must start with a letter and use only letters, numbers and _ (2 to 40 characters).';
    ELSEIF v_kind IN ('SYSTEM', 'TOTAL') THEN
        SET v_msg = CONCAT(v_code, ' is a built-in variable and cannot be changed.');
    ELSEIF v_kind IS NULL AND EXISTS (SELECT 1 FROM salary_component_master WHERE UPPER(component_code) = v_code) THEN
        SET v_msg = CONCAT(v_code, ' is already a component code.');
    ELSEIF v_code IN ('ROUND','LEAST','GREATEST','IF','CEIL','FLOOR','ABS','AND','OR','NOT','NONE') THEN
        SET v_msg = CONCAT(v_code, ' is a formula word and cannot be a variable.');
    ELSEIF NULLIF(TRIM(COALESCE(p_name, '')), '') IS NULL THEN
        SET v_msg = 'Name is required.';
    ELSEIF v_type NOT IN ('NUMBER', 'FLAG') THEN
        SET v_msg = 'Type must be Number or Yes/No.';
    ELSEIF v_type = 'FLAG' AND v_default NOT IN (0, 1) THEN
        SET v_msg = 'The default of a Yes/No variable must be Yes (1) or No (0).';
    ELSEIF v_active = 0 AND v_used IS NOT NULL THEN
        SET v_msg = LEFT(CONCAT('Cannot switch off ', v_code, ': used by ', v_used, '.'), 500);
    ELSEIF v_type = 'NUMBER' AND v_elig IS NOT NULL THEN
        SET v_msg = LEFT(CONCAT(v_code, ' must stay Yes/No: ', v_elig, ' apply only when it is Yes.'), 500);
    ELSEIF v_type = 'FLAG' AND EXISTS (SELECT 1 FROM employee_payroll_variables
                                        WHERE var_code = v_code AND var_value NOT IN (0, 1)) THEN
        SET v_msg = CONCAT('Some employees have a value other than 0 / 1 for ', v_code, '. Correct them first.');
    END IF;
    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks;
        LEAVE vs;
    END IF;

    START TRANSACTION;
    INSERT INTO payroll_variables (var_code, var_name, description, var_kind, data_type, default_value, is_active, sort_order, created_by)
    VALUES (v_code, TRIM(p_name), NULLIF(TRIM(COALESCE(p_description, '')), ''), 'EMPLOYEE', v_type, v_default, v_active, 300, p_emp_id)
    ON DUPLICATE KEY UPDATE var_name = VALUES(var_name), description = VALUES(description), data_type = VALUES(data_type),
                            default_value = VALUES(default_value), is_active = VALUES(is_active);

    -- a variable in use with a new default or on/off state: recalculate everyone
    IF v_used IS NOT NULL AND (v_kind IS NULL OR v_old_default <> v_default OR v_old_active <> v_active) THEN
        CALL hrms_recalculate_all_structures(v_structures, v_changed, v_errors, v_text);
        IF v_errors > 0 THEN
            ROLLBACK;
            SELECT 'N' AS status, LEFT(CONCAT('Not saved: ', COALESCE(v_text, 'a salary could not be calculated.')), 500) AS remarks;
            LEAVE vs;
        END IF;
        IF v_changed > 0 THEN
            CALL hrms_component_cycle_guard(p_emp_id, CONCAT('Payroll variable ', v_code, ' changed'), v_notice);
        END IF;
    END IF;

    CALL hrms_payroll_audit_add('COMPONENT', IF(v_kind IS NULL, 'VARIABLE_CREATE', 'VARIABLE_UPDATE'), 'payroll_variables', v_code,
         NULL, NULL, NULL, NULL,
         IF(v_kind IS NULL, NULL, JSON_OBJECT('code', v_code, 'type', v_old_type, 'default', v_old_default, 'active', v_old_active)),
         JSON_OBJECT('code', v_code, 'type', v_type, 'default', v_default, 'active', v_active),
         CONCAT('Payroll variable ', v_code, IF(v_kind IS NULL, ' added', ' changed'),
                IF(v_changed > 0, CONCAT('. Employee amounts changed: ', v_changed), ''), '.'), p_emp_id);
    COMMIT;

    SELECT 'Y' AS status,
           CONCAT('Variable ', v_code, IF(v_kind IS NULL, ' added.', ' saved.'),
                  IF(v_structures > 0, CONCAT(' Salaries recalculated; amounts changed: ', v_changed, '.'), ''),
                  IF(v_notice IS NULL, '', CONCAT(' ', v_notice))) AS remarks;
END$$

-- ---------------------------------------------------------------------
-- P2-015  hrms_employee_variables : the variables of one employee
--         (employee salary page): every active EMPLOYEE variable with the
--         employee's own value (NULL = uses the default).
--         Who may call: active ADMIN or HR.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_employee_variables$$
CREATE PROCEDURE hrms_employee_variables(IN p_emp_id VARCHAR(20), IN p_target_emp_id VARCHAR(20))
ev: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view salaries.' AS remarks;
        LEAVE ev;
    END IF;
    SELECT 'Y' AS status, '' AS remarks,
           v.var_code, v.var_name, v.description, v.data_type, v.default_value,
           e.var_value AS employee_value,
           COALESCE(e.var_value, v.default_value) AS value_used
      FROM payroll_variables v
      LEFT JOIN employee_payroll_variables e ON e.var_code = v.var_code AND e.emp_id = p_target_emp_id
     WHERE v.var_kind = 'EMPLOYEE' AND v.is_active = 1
     ORDER BY v.sort_order, v.var_code;
END$$

-- ---------------------------------------------------------------------
-- P2-016  hrms_employee_variables_save : an employee's own values.
--   p_values  JSON array [{"var_code": "X", "value": 1}, ...]
--             value null or "" = use the default (own value removed)
--   Every salary period of the employee is recalculated, each on its own
--   date; if one cannot be calculated nothing is saved.
--   Who may call: active ADMIN or HR.  Returns: status, remarks.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_employee_variables_save$$
CREATE PROCEDURE hrms_employee_variables_save(
    IN p_emp_id        VARCHAR(20),
    IN p_target_emp_id VARCHAR(20),
    IN p_values        LONGTEXT
)
es: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;
    DECLARE v_msg    VARCHAR(500) DEFAULT NULL;
    DECLARE v_count  INT DEFAULT 0;
    DECLARE v_i      INT DEFAULT 0;
    DECLARE v_code   VARCHAR(40);
    DECLARE v_raw    VARCHAR(40);
    DECLARE v_type   VARCHAR(10);
    DECLARE v_sid    BIGINT DEFAULT 0;
    DECLARE v_date   DATE;
    DECLARE v_changed INT DEFAULT 0;
    DECLARE v_total_changed INT DEFAULT 0;
    DECLARE v_errs   INT DEFAULT 0;
    DECLARE v_text   VARCHAR(500);
    DECLARE v_old    LONGTEXT;
    DECLARE v_new    LONGTEXT;
    DECLARE v_err    VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'The values could not be saved. Nothing was changed.') AS remarks;
    END;

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can change salaries.';
    ELSEIF NOT EXISTS (SELECT 1 FROM user_details WHERE emp_id = p_target_emp_id)
       AND NOT EXISTS (SELECT 1 FROM salary_structure WHERE emp_id = p_target_emp_id) THEN
        SET v_msg = CONCAT('Employee ', COALESCE(p_target_emp_id, ''), ' not found.');
    ELSEIF NULLIF(TRIM(COALESCE(p_values, '')), '') IS NULL OR JSON_VALID(p_values) = 0
        OR LEFT(TRIM(p_values), 1) <> '[' THEN
        SET v_msg = 'Values must be a JSON array.';
    END IF;

    SET v_count = IF(v_msg IS NULL, JSON_LENGTH(p_values), 0);
    WHILE v_msg IS NULL AND v_i < v_count DO
        SET v_code = UPPER(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_values, CONCAT('$[', v_i, '].var_code'))), '')));
        SET v_raw  = NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_values, CONCAT('$[', v_i, '].value'))), '')), ''), 'null');
        SET v_type = NULL;
        SELECT MAX(data_type) INTO v_type FROM payroll_variables
         WHERE var_code = v_code AND var_kind = 'EMPLOYEE' AND is_active = 1;
        IF v_type IS NULL THEN
            SET v_msg = CONCAT(v_code, ' is not an active employee variable.');
        ELSEIF v_raw IS NOT NULL AND v_raw NOT REGEXP '^-?[0-9]+(\\.[0-9]+)?$' THEN
            SET v_msg = CONCAT(v_code, ': enter a number.');
        ELSEIF v_raw IS NOT NULL AND v_type = 'FLAG' AND v_raw NOT IN ('0', '1') THEN
            SET v_msg = CONCAT(v_code, ': choose Yes or No.');
        END IF;
        SET v_i = v_i + 1;
    END WHILE;

    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks;
        LEAVE es;
    END IF;

    SELECT CONCAT('{', COALESCE(GROUP_CONCAT(CONCAT(JSON_QUOTE(var_code), ':', var_value) SEPARATOR ','), ''), '}') INTO v_old
      FROM employee_payroll_variables WHERE emp_id = p_target_emp_id;

    START TRANSACTION;
    SET v_i = 0;
    WHILE v_i < v_count DO
        SET v_code = UPPER(TRIM(JSON_UNQUOTE(JSON_EXTRACT(p_values, CONCAT('$[', v_i, '].var_code')))));
        SET v_raw  = NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_values, CONCAT('$[', v_i, '].value'))), '')), ''), 'null');
        IF v_raw IS NULL THEN
            DELETE FROM employee_payroll_variables WHERE emp_id = p_target_emp_id AND var_code = v_code;
        ELSE
            INSERT INTO employee_payroll_variables (emp_id, var_code, var_value, updated_by)
            VALUES (p_target_emp_id, v_code, CAST(v_raw AS DECIMAL(18,4)), p_emp_id)
            ON DUPLICATE KEY UPDATE var_value = VALUES(var_value), updated_by = VALUES(updated_by);
        END IF;
        SET v_i = v_i + 1;
    END WHILE;

    -- every salary period of the employee, each on its own date
    -- (a loop on the next id, not a cursor: the engine's temporary tables
    --  cannot be reopened while a cursor of the caller is open)
    rd: LOOP
        SET v_sid = (SELECT MIN(structure_id) FROM salary_structure
                      WHERE emp_id = p_target_emp_id AND structure_status = 'ACTIVE' AND structure_id > v_sid);
        IF v_sid IS NULL THEN LEAVE rd; END IF;
        -- the date goes through a variable: a stored function inside CALL (...) makes MySQL
        -- lock the engine's temporary tables for the whole call ("Can't reopen table")
        SET v_date = hrms_structure_calc_date(v_sid);
        CALL hrms_calculate_structure(v_sid, v_date, v_changed, v_errs, v_text);
        IF v_errs > 0 THEN
            ROLLBACK;
            SELECT 'N' AS status, LEFT(CONCAT('Not saved: ', COALESCE(v_text, 'the salary could not be calculated.')), 500) AS remarks;
            LEAVE es;
        END IF;
        SET v_total_changed = v_total_changed + v_changed;
    END LOOP;

    SELECT CONCAT('{', COALESCE(GROUP_CONCAT(CONCAT(JSON_QUOTE(var_code), ':', var_value) SEPARATOR ','), ''), '}') INTO v_new
      FROM employee_payroll_variables WHERE emp_id = p_target_emp_id;
    CALL hrms_payroll_audit_add('SALARY', 'VARIABLES', 'employee_payroll_variables', p_target_emp_id, p_target_emp_id,
         NULL, NULL, NULL, v_old, v_new,
         CONCAT('Payroll variables of ', p_target_emp_id, ' saved. Salary amounts changed: ', v_total_changed, '.'), p_emp_id);
    COMMIT;

    SELECT 'Y' AS status,
           CONCAT('Variables saved and the salary recalculated (amounts changed: ', v_total_changed, ').',
                  IF(v_total_changed > 0, ' If a payroll cycle is already calculated, recalculate this employee there.', '')) AS remarks;
END$$

-- ---------------------------------------------------------------------
-- P2-017  data
--   - "applies only when": EMPLOYEE_ESI_ELIGIBLE is the variable ESI_APPLICABLE
--   - ESI slabs: whether ESI applies is decided on the full-month wage
--     (STANDARD_ESI_WAGE), not on the GROSS of a month with loss of pay
-- ---------------------------------------------------------------------
UPDATE salary_component_master
   SET eligibility_parameter = 'ESI_APPLICABLE'
 WHERE UPPER(eligibility_parameter) = 'EMPLOYEE_ESI_ELIGIBLE'$$

UPDATE salary_component_slab s
  JOIN salary_component_master m ON m.component_id = s.component_id
   SET s.slab_based_on = 'STANDARD_ESI_WAGE'
 WHERE UPPER(m.eligibility_parameter) = 'ESI_APPLICABLE'
   AND UPPER(s.slab_based_on) = 'GROSS'$$

-- ---------------------------------------------------------------------
-- P2-018  every salary recalculated
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_phase_recalc$$
CREATE PROCEDURE hrms_phase_recalc()
BEGIN
    DECLARE v_structures INT DEFAULT 0;
    DECLARE v_changed    INT DEFAULT 0;
    DECLARE v_errors     INT DEFAULT 0;
    DECLARE v_text       VARCHAR(500);
    DECLARE v_signal     VARCHAR(128);
    CALL hrms_recalculate_all_structures(v_structures, v_changed, v_errors, v_text);
    IF v_errors > 0 THEN
        SET v_signal = LEFT(CONCAT('Recalculation failed: ', COALESCE(v_text, '?')), 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_signal;
    END IF;
    SELECT v_structures AS salaries_recalculated, v_changed AS amounts_changed;
END$$
CALL hrms_phase_recalc()$$
DROP PROCEDURE IF EXISTS hrms_phase_recalc$$

DELIMITER ;
