-- =====================================================================
-- component_phase2.sql : salary components, phase 2
--   Payroll variables come from a table instead of fixed lists in the
--   procedures, employees can have their own values for them, and
--   "applies only when" works for any Yes/No variable (not only ESI).
--   ESI's 21,000 limit is checked on the full-month wage.
--
-- Database : production_hrms_db (MySQL 8) and hrmstest (MariaDB 10.11)
-- Run with : mysql --default-character-set=utf8mb4 -u <user> -p <database> < component_phase2.sql
-- Order    : script.sql -> component_phase1.sql -> component_phase2.sql -> component_phase3.sql
--            (run script.sql again later? then run the phase files again too)
-- Re-run   : safe. Tables are created once, the built-in variables are
--            refreshed, procedures are recreated, the data changes only
--            touch rows not changed yet.
-- Built by : db_dumps/build/build_phase2.py (P2-004 .. P2-010 are copies
--            of the script.sql procedures with the fixed name lists
--            replaced; the build stops if a replacement does not match).
--
-- APPLICATION FILES (deploy with this phase)
--   new     app/Views/payroll/payroll_variables.php       Payroll variables page
--   changed app/Controllers/SalaryController.php          payroll_variables, payroll_variable_save,
--                                                         employee_variables_save; edit_salary_structure
--                                                         passes the employee's variables
--           app/Models/SalaryModel.php                    payroll_variables, payroll_variable_save,
--                                                         employee_variables, employee_variables_save
--           app/Config/Routes.php                         payroll/variables, /variables/save,
--                                                         payroll/salary_structure/variables
--           app/Views/payroll/salary_structure_edit.php   "Payroll variables" card
--           app/Views/payroll/salary_components.php       "Payroll Variables" button
--
-- CHANGE INDEX
--   P2-001  NEW TABLE   payroll_variables          every name a formula can use
--                                                 that is not a component
--           NEW TABLE   employee_payroll_variables an employee's own value
--   P2-002  DATA        the built-in variables (SYSTEM) and the three
--                       totals (TOTAL) that work without a component
--   P2-003  NEW FUNCTION hrms_is_variable, hrms_is_reserved_name
--           UPDATE PROCEDURE hrms_engine_load_vars: + every active employee
--                       variable (the employee's value, else the default)
--   P2-004  UPDATE PROCEDURE hrms_engine_run: generic "applies only when"
--   P2-005  UPDATE PROCEDURE hrms_formula_check
--   P2-006  UPDATE PROCEDURE hrms_component_slab_apply
--   P2-007  UPDATE PROCEDURE hrms_update_component_master
--   P2-008  UPDATE PROCEDURE hrms_update_employee_salary_component
--   P2-009  UPDATE PROCEDURE hrms_save_employee_salary
--   P2-010  UPDATE PROCEDURE hrms_component_rules_check
--           (P2-005 .. P2-010: the fixed name lists become hrms_is_variable)
--   P2-011  UPDATE FUNCTION  hrms_esi_wage_limit: from the slabs of the
--                       components that apply only when ESI_APPLICABLE
--                       (was: the codes EE_ESI and EMP_ESI)
--   P2-012  UPDATE PROCEDURE hrms_formula_names: variables from the table
--   P2-013  NEW PROCEDURE    hrms_payroll_variable_list  (Payroll variables page)
--   P2-014  NEW PROCEDURE    hrms_payroll_variable_save
--   P2-015  NEW PROCEDURE    hrms_employee_variables     (employee salary page)
--   P2-016  NEW PROCEDURE    hrms_employee_variables_save
--   P2-017  DATA        EMPLOYEE_ESI_ELIGIBLE -> ESI_APPLICABLE; ESI slabs
--                       "based on" GROSS -> STANDARD_ESI_WAGE (the
--                       full-month wage, so loss of pay cannot bring an
--                       employee under the ESI limit)
--   P2-018  DATA        every salary recalculated (full-month amounts do
--                       not change: STANDARD_ESI_WAGE equals GROSS there)
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- P2-001  tables
--   payroll_variables.var_kind
--     SYSTEM    calculated by the engine (CTC, CTC1, PAYABLE_DAYS ...);
--               cannot be edited or used as a component code
--     TOTAL     GROSS / TOTAL_DEDUCTIONS / TOTAL_EMPLOYER_CONTRIBUTION:
--               the sum of their type when no component has that code
--     EMPLOYEE  added by HR on the Payroll variables page; every employee
--               has the default value unless their own value is set
--   data_type   NUMBER, or FLAG (1 = yes, 0 = no; usable in
--               "applies only when")
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payroll_variables (
    var_code      VARCHAR(40)   NOT NULL,
    var_name      VARCHAR(100)  NOT NULL,
    description   VARCHAR(500)  NULL,
    var_kind      ENUM('SYSTEM', 'TOTAL', 'EMPLOYEE') NOT NULL DEFAULT 'EMPLOYEE',
    data_type     ENUM('NUMBER', 'FLAG') NOT NULL DEFAULT 'NUMBER',
    default_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    is_active     TINYINT(1)    NOT NULL DEFAULT 1,
    sort_order    INT           NOT NULL DEFAULT 100,
    created_by    VARCHAR(20)   NULL,
    created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (var_code),
    KEY idx_pv_kind (var_kind, is_active)
) ENGINE=InnoDB$$

CREATE TABLE IF NOT EXISTS employee_payroll_variables (
    emp_id     VARCHAR(20)   NOT NULL,
    var_code   VARCHAR(40)   NOT NULL,
    var_value  DECIMAL(18,4) NOT NULL DEFAULT 0,
    updated_by VARCHAR(20)   NULL,
    updated_at DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (emp_id, var_code),
    KEY idx_epv_code (var_code)
) ENGINE=InnoDB$$

-- ---------------------------------------------------------------------
-- P2-002  built-in variables (names and descriptions refreshed on re-run)
-- ---------------------------------------------------------------------
INSERT INTO payroll_variables (var_code, var_name, description, var_kind, data_type, default_value, is_active, sort_order, created_by)
VALUES
    ('CTC',               'Monthly CTC',            'Monthly CTC of the salary period.', 'SYSTEM', 'NUMBER', 0, 1, 10, 'SCRIPT'),
    ('CTC1',              'CTC earned in the month','Monthly CTC x payable days / 30 (equal to CTC for a full month).', 'SYSTEM', 'NUMBER', 0, 1, 20, 'SCRIPT'),
    ('ANNUAL_CTC',        'Annual CTC',             'Annual CTC of the salary period.', 'SYSTEM', 'NUMBER', 0, 1, 30, 'SCRIPT'),
    ('PAY_DAYS',          'Days of a month',        'Always 30.', 'SYSTEM', 'NUMBER', 30, 1, 40, 'SCRIPT'),
    ('PAYABLE_DAYS',      'Payable days',           '30 - unpaid (LOP) days of the month.', 'SYSTEM', 'NUMBER', 30, 1, 50, 'SCRIPT'),
    ('LOP_DAYS',          'Unpaid (LOP) days',      'Unpaid days of the month.', 'SYSTEM', 'NUMBER', 0, 1, 60, 'SCRIPT'),
    ('ESI_WAGE',          'ESI wage of the month',  'GROSS of the month being calculated.', 'SYSTEM', 'NUMBER', 0, 1, 70, 'SCRIPT'),
    ('STANDARD_ESI_WAGE', 'ESI wage of a full month','GROSS of a full month (no loss of pay): decides whether ESI applies.', 'SYSTEM', 'NUMBER', 0, 1, 80, 'SCRIPT'),
    ('MANUAL_AMOUNT',     'Amount entered for the month', 'The amount entered by hand for this component and month.', 'SYSTEM', 'NUMBER', 0, 1, 90, 'SCRIPT'),
    ('ESI_APPLICABLE',    'ESI applies',            '1 when ESI is applicable on the salary period (salary page), else 0.', 'SYSTEM', 'FLAG', 0, 1, 100, 'SCRIPT'),
    ('GROSS',             'Gross salary',           'Sum of the earnings, when no component has the code GROSS.', 'TOTAL', 'NUMBER', 0, 1, 200, 'SCRIPT'),
    ('TOTAL_DEDUCTIONS',  'Total deductions',       'Sum of the deductions, when no component has this code.', 'TOTAL', 'NUMBER', 0, 1, 210, 'SCRIPT'),
    ('TOTAL_EMPLOYER_CONTRIBUTION', 'Total employer contribution', 'Sum of the employer contributions, when no component has this code.', 'TOTAL', 'NUMBER', 0, 1, 220, 'SCRIPT')
ON DUPLICATE KEY UPDATE
    var_name = VALUES(var_name), description = VALUES(description), var_kind = VALUES(var_kind),
    data_type = VALUES(data_type), default_value = VALUES(default_value), is_active = 1, sort_order = VALUES(sort_order)$$

-- ---------------------------------------------------------------------
-- P2-003  name functions
--   hrms_is_variable(code)      1 = an active payroll variable (any kind)
--   hrms_is_reserved_name(code) 1 = a SYSTEM or EMPLOYEE variable: cannot
--                               be a component code (TOTAL names can: the
--                               GROSS component replaces the GROSS sum)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS hrms_is_variable$$
CREATE FUNCTION hrms_is_variable(p_code VARCHAR(64)) RETURNS TINYINT
READS SQL DATA
BEGIN
    RETURN IF(EXISTS (SELECT 1 FROM payroll_variables
                       WHERE var_code = UPPER(TRIM(p_code)) AND is_active = 1), 1, 0);
END$$

DROP FUNCTION IF EXISTS hrms_is_reserved_name$$
CREATE FUNCTION hrms_is_reserved_name(p_code VARCHAR(64)) RETURNS TINYINT
READS SQL DATA
BEGIN
    RETURN IF(EXISTS (SELECT 1 FROM payroll_variables
                       WHERE var_code = UPPER(TRIM(p_code)) AND var_kind IN ('SYSTEM', 'EMPLOYEE')), 1, 0);
END$$

-- ---------------------------------------------------------------------
-- P2-003  hrms_engine_load_vars (C-031) + employee variables
--        Unchanged except: every active EMPLOYEE variable is loaded with
--        the employee's own value, else its default.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_engine_load_vars$$
CREATE PROCEDURE hrms_engine_load_vars(
    IN p_structure_id BIGINT,
    IN p_ctc1         DECIMAL(14,2),
    IN p_payable_days DECIMAL(5,2)
)
BEGIN
    DECLARE v_found  INT DEFAULT 0;
    DECLARE v_ctc    DECIMAL(18,4) DEFAULT 50000;
    DECLARE v_annual DECIMAL(18,4) DEFAULT 600000;
    DECLARE v_esi    VARCHAR(5) DEFAULT 'N';
    DECLARE v_std    DECIMAL(18,4) DEFAULT 0;
    DECLARE v_days   DECIMAL(9,4) DEFAULT 30;
    DECLARE v_emp    VARCHAR(20) DEFAULT NULL;

    SELECT COUNT(*), COALESCE(MAX(monthly_ctc), 50000), COALESCE(MAX(annual_ctc), 600000), COALESCE(MAX(esi_applicable), 'N'),
           MAX(emp_id)
      INTO v_found, v_ctc, v_annual, v_esi, v_emp
      FROM salary_structure WHERE structure_id = p_structure_id;
    SET v_days = COALESCE(p_payable_days, 30);

    SELECT COALESCE(MAX(t.monthly_amount), 0) INTO v_std
      FROM employee_salary_structure_totals t
      JOIN salary_component_master m ON m.component_id = t.component_id
     WHERE t.structure_id = p_structure_id AND UPPER(m.component_code) = 'GROSS';
    IF v_std = 0 THEN
        SELECT COALESCE(SUM(e.monthly_amount), 0) INTO v_std
          FROM employee_salary_structure e
          JOIN salary_component_master m ON m.component_id = e.component_id
         WHERE e.structure_id = p_structure_id
           AND m.component_type = 'EARNING' AND m.is_active = 1 AND m.calculation_scope = 'COMPONENT';
    END IF;

    DELETE FROM tmp_hrms_formula_vars;

    -- every component code is a name; values are filled in by the calculation
    INSERT IGNORE INTO tmp_hrms_formula_vars (var_code, var_value, var_type, var_scope, var_order, component_id)
    SELECT UPPER(m.component_code), 0, m.component_type, m.calculation_scope, m.calculation_order, m.component_id
      FROM salary_component_master m;

    -- built-in names (ignored when a component already uses the code)
    INSERT IGNORE INTO tmp_hrms_formula_vars (var_code, var_value, var_type, var_scope, var_order, component_id) VALUES
        ('CTC',                         v_ctc,                   'BUILTIN', 'BUILTIN', 0, NULL),
        ('CTC1',                        COALESCE(p_ctc1, v_ctc), 'BUILTIN', 'BUILTIN', 0, NULL),
        ('ANNUAL_CTC',                  v_annual,                'BUILTIN', 'BUILTIN', 0, NULL),
        ('ESI_APPLICABLE',              IF(v_esi = 'Y', 1, 0),   'BUILTIN', 'BUILTIN', 0, NULL),
        ('PAY_DAYS',                    30,                      'BUILTIN', 'BUILTIN', 0, NULL),
        ('PAYABLE_DAYS',                v_days,                  'BUILTIN', 'BUILTIN', 0, NULL),
        ('LOP_DAYS',                    GREATEST(30 - v_days, 0),'BUILTIN', 'BUILTIN', 0, NULL),
        ('MANUAL_AMOUNT',               0,                       'BUILTIN', 'BUILTIN', 0, NULL),
        ('ESI_WAGE',                    0,                       'BUILTIN', 'BUILTIN', 0, NULL),
        ('STANDARD_ESI_WAGE',           IF(p_ctc1 IS NULL, 0, v_std), 'BUILTIN',
                                        IF(p_ctc1 IS NULL, 'FOLLOW_GROSS', 'BUILTIN'), 0, NULL),
        ('GROSS',                       0, 'BUILTIN_TOTAL', 'BUILTIN', 0, NULL),
        ('TOTAL_DEDUCTIONS',            0, 'BUILTIN_TOTAL', 'BUILTIN', 0, NULL),
        ('TOTAL_EMPLOYER_CONTRIBUTION', 0, 'BUILTIN_TOTAL', 'BUILTIN', 0, NULL);

    -- P2: variables added by HR: the employee's own value, else the default
    INSERT IGNORE INTO tmp_hrms_formula_vars (var_code, var_value, var_type, var_scope, var_order, component_id)
    SELECT v.var_code, COALESCE(e.var_value, v.default_value), 'BUILTIN', 'BUILTIN', 0, NULL
      FROM payroll_variables v
      LEFT JOIN employee_payroll_variables e ON e.var_code = v.var_code AND e.emp_id = v_emp
     WHERE v.var_kind = 'EMPLOYEE' AND v.is_active = 1;
END$$

-- ---------------------------------------------------------------------
-- P2-004  hrms_engine_run: "applies only when" works for every Yes/No variable
--        (copied from script.sql and patched by db_dumps/build/build_phase2.py)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_engine_run$$
CREATE PROCEDURE hrms_engine_run(
    IN  p_structure_id BIGINT,
    IN  p_ctc1         DECIMAL(14,2),
    IN  p_payable_days DECIMAL(5,2),
    IN  p_emp_id       VARCHAR(20),
    IN  p_month        INT,
    IN  p_year         INT,
    IN  p_on_date      DATE,
    OUT p_passes       INT,
    OUT p_errors       INT,
    OUT p_error_text   VARCHAR(500)
)
BEGIN
    DECLARE v_done       INT DEFAULT 0;
    DECLARE v_cid        BIGINT;
    DECLARE v_code       VARCHAR(40);
    DECLARE v_calc       VARCHAR(20);
    DECLARE v_value      DECIMAL(18,4);
    DECLARE v_base       VARCHAR(40);
    DECLARE v_formula    TEXT;
    DECLARE v_slab       TINYINT;
    DECLARE v_manual     TINYINT;
    DECLARE v_min        DECIMAL(12,2);
    DECLARE v_max        DECIMAL(12,2);
    DECLARE v_eparam     VARCHAR(50);
    DECLARE v_evalue     VARCHAR(10);
    DECLARE v_rounding   INT;
    DECLARE v_stored     DECIMAL(14,2);
    DECLARE v_manual_amt DECIMAL(14,2);
    DECLARE v_overridden TINYINT;
    DECLARE v_esi        VARCHAR(5) DEFAULT 'N';
    DECLARE v_new        DECIMAL(18,4);
    DECLARE v_prev       DECIMAL(18,4);
    DECLARE v_delta      DECIMAL(18,4);
    DECLARE v_delta_code VARCHAR(40);
    DECLARE v_limits     TINYINT;
    DECLARE v_bad        VARCHAR(500);
    DECLARE v_n          INT;
    DECLARE v_base_val   DECIMAL(18,4);
    DECLARE v_matched    TINYINT;
    DECLARE v_st         CHAR(1);
    DECLARE v_rm         VARCHAR(500);
    DECLARE v_date       DATE;
    DECLARE cur CURSOR FOR
        SELECT cid, code, eff_calc, eff_value, eff_base, eff_formula, eff_slab, eff_manual,
               min_amt, max_amt, elig_param, elig_value, rounding, stored_amt, manual_amt, overridden
          FROM tmp_hrms_calc
         ORDER BY calc_order, cid;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    SET p_passes = 0;
    SET p_errors = 0;
    SET p_error_text = NULL;
    SET v_date = COALESCE(p_on_date, CURDATE());

    CALL hrms_engine_prepare();
    CALL hrms_engine_load_vars(p_structure_id, p_ctc1, p_payable_days);
    SELECT COALESCE(MAX(esi_applicable), 'N') INTO v_esi FROM salary_structure WHERE structure_id = p_structure_id;

    DELETE FROM tmp_hrms_calc;
    DELETE FROM tmp_hrms_slab_gap;
    INSERT INTO tmp_hrms_calc
        (cid, ecid, code, ctype, scope, calc_order, eff_calc, eff_value, eff_base, eff_formula, eff_slab, eff_manual,
         min_amt, max_amt, elig_param, elig_value, rounding, stored_amt, manual_amt, overridden, new_amt)
    SELECT m.component_id, e.employee_component_id, UPPER(m.component_code), m.component_type,
           m.calculation_scope, m.calculation_order,
           CASE WHEN COALESCE(e.is_overridden, 0) = 1 THEN e.calculation_type ELSE m.calculation_type END,
           CASE WHEN COALESCE(e.is_overridden, 0) = 1 THEN COALESCE(e.component_value, 0) ELSE COALESCE(m.percentage_value, 0) END,
           UPPER(COALESCE(CASE WHEN COALESCE(e.is_overridden, 0) = 1 THEN e.percentage_base ELSE m.percentage_base END, 'NONE')),
           CASE WHEN COALESCE(e.is_overridden, 0) = 1 THEN e.formula_expression ELSE m.formula_expression END,
           CASE WHEN COALESCE(e.is_overridden, 0) = 1 THEN 0
                WHEN m.is_slab = 1 AND EXISTS (SELECT 1 FROM salary_component_slab s
                                                WHERE s.component_id = m.component_id AND s.is_active = 1) THEN 1
                ELSE 0 END,
           CASE WHEN COALESCE(e.is_overridden, 0) = 1 THEN IF(e.calculation_type = 'MANUAL', 1, 0)
                ELSE IF(m.is_manual = 1 OR m.calculation_type = 'MANUAL', 1, 0) END,
           m.minimum_amount, m.maximum_amount, m.eligibility_parameter, m.eligibility_required_value,
           COALESCE(m.rounding_precision, 2),
           COALESCE(e.monthly_amount, t.monthly_amount, 0),
           COALESCE(i.amount, e.monthly_amount, 0),
           COALESCE(e.is_overridden, 0),
           0
      FROM salary_component_master m
      LEFT JOIN employee_salary_structure e
             ON e.component_id = m.component_id AND e.structure_id = p_structure_id
      LEFT JOIN employee_salary_structure_totals t
             ON t.component_id = m.component_id AND t.structure_id = p_structure_id
      LEFT JOIN payroll_manual_inputs i
             ON i.component_id = m.component_id AND i.emp_id = p_emp_id
            AND i.payroll_month = p_month AND i.payroll_year = p_year
     WHERE m.is_active = 1
       AND (m.calculation_scope = 'AGGREGATE' OR e.employee_component_id IS NOT NULL);

    passes: LOOP
        SET p_passes = p_passes + 1;
        SET v_delta = 0;

        OPEN cur;
        comp: LOOP
            SET v_done = 0;
            FETCH cur INTO v_cid, v_code, v_calc, v_value, v_base, v_formula, v_slab, v_manual,
                           v_min, v_max, v_eparam, v_evalue, v_rounding, v_stored, v_manual_amt, v_overridden;
            IF v_done = 1 THEN
                LEAVE comp;
            END IF;

            CALL hrms_engine_refresh_totals(v_cid);
            SET v_new = NULL;
            SET v_bad = NULL;
            SET v_limits = 0;

            IF v_manual = 1 THEN
                SET v_new = v_manual_amt;
            -- P2: "applies only when" <Yes/No variable> = Y (or N); any variable, not only ESI
            ELSEIF TRIM(COALESCE(v_eparam, '')) <> ''
               AND (SELECT IF(UPPER(COALESCE(NULLIF(TRIM(v_evalue), ''), 'Y')) = 'N',
                              COALESCE(MAX(fv.var_value), 0) <> 0,
                              COALESCE(MAX(fv.var_value), 0) = 0)
                      FROM tmp_hrms_formula_vars fv
                     WHERE fv.var_code = IF(UPPER(TRIM(v_eparam)) = 'EMPLOYEE_ESI_ELIGIBLE', 'ESI_APPLICABLE',
                                            UPPER(TRIM(v_eparam)))) = 1 THEN
                SET v_new = 0;
            ELSEIF v_slab = 1 THEN
                CALL hrms_slab_resolve(v_cid, v_date, v_new, v_matched);
                -- C-095: no slab valid on the date stops the calculation (was a silent 0);
                --        a value in a gap between ranges gives 0 and is reported
                IF v_matched = 0 THEN
                    SET v_new = 0;
                    SET v_bad = CONCAT('no slab is valid on ', DATE_FORMAT(v_date, '%d %b %Y'),
                                       '. Add a slab that covers this date.');
                END IF;
                INSERT INTO tmp_hrms_slab_gap (cid, is_gap) VALUES (v_cid, IF(v_matched = 2, 1, 0))
                    ON DUPLICATE KEY UPDATE is_gap = IF(v_matched = 2, 1, 0);
                SET v_limits = 1;
            ELSEIF v_calc IN ('FORMULA', 'STATUTORY') AND TRIM(COALESCE(v_formula, '')) <> '' THEN
                UPDATE tmp_hrms_formula_vars SET var_value = v_manual_amt WHERE var_code = 'MANUAL_AMOUNT';
                CALL hrms_formula_evaluate(v_formula, 'EVAL', v_new, v_st, v_rm);
                IF v_st = 'Y' THEN
                    SET v_limits = 1;
                ELSEIF v_overridden = 1 THEN
                    SET v_new = v_stored;
                ELSE
                    SET v_new = 0;
                    SET v_bad = v_rm;
                END IF;
            ELSEIF v_calc = 'PERCENTAGE' THEN
                SELECT COUNT(*), COALESCE(MAX(var_value), 0) INTO v_n, v_base_val
                  FROM tmp_hrms_formula_vars WHERE var_code = v_base;
                IF v_n > 0 THEN
                    SET v_new = v_base_val * v_value / 100;
                    SET v_limits = 1;
                ELSEIF v_overridden = 1 THEN
                    SET v_new = v_stored;
                ELSE
                    SET v_new = 0;
                    SET v_bad = CONCAT('"Based On" name ', v_base, ' is not known.');
                END IF;
            ELSEIF v_calc = 'FIXED' THEN
                SET v_new = v_value;
                SET v_limits = 1;
            ELSE
                SET v_new = v_stored;
            END IF;

            IF v_limits = 1 THEN
                IF v_min IS NOT NULL AND v_new < v_min THEN SET v_new = v_min; END IF;
                IF v_max IS NOT NULL AND v_new > v_max THEN SET v_new = v_max; END IF;
            END IF;
            SET v_new = ROUND(COALESCE(v_new, 0), LEAST(GREATEST(COALESCE(v_rounding, 2), 0), 2));

            IF v_bad IS NOT NULL THEN
                SET p_errors = p_errors + 1;
                IF p_error_text IS NULL THEN
                    SET p_error_text = LEFT(CONCAT(v_code, ': ', v_bad), 500);
                END IF;
            END IF;

            SELECT COALESCE(MAX(var_value), 0) INTO v_prev FROM tmp_hrms_formula_vars WHERE var_code = v_code;
            IF ABS(v_new - v_prev) > v_delta THEN
                SET v_delta = ABS(v_new - v_prev);
                SET v_delta_code = v_code;
            END IF;
            UPDATE tmp_hrms_formula_vars SET var_value = v_new WHERE var_code = v_code;
        END LOOP comp;
        CLOSE cur;

        IF p_errors > 0 OR v_delta < 0.005 THEN
            LEAVE passes;
        END IF;
        -- Rounding inside a circle can leave an amount swapping one paisa for
        -- ever (no exact answer exists); a total built from it then moves by
        -- two or three paise. After 6 passes that is accepted as settled.
        IF p_passes >= 6 AND v_delta < 0.05 THEN
            LEAVE passes;
        END IF;
        IF p_passes >= 30 THEN
            SET p_errors = p_errors + 1;
            SET p_error_text = CONCAT('The amounts never settle: ', COALESCE(v_delta_code, '?'), ' still changes by ',
                                      ROUND(v_delta, 2), ' after 30 passes. Components refer to each other in a circle.');
            LEAVE passes;
        END IF;
    END LOOP passes;

    UPDATE tmp_hrms_calc c
      JOIN tmp_hrms_formula_vars v ON v.var_code = c.code
       SET c.new_amt = v.var_value;
END$$

-- ---------------------------------------------------------------------
-- P2-005  hrms_formula_check: names from payroll_variables (was a fixed list)
--        (copied from script.sql and patched by db_dumps/build/build_phase2.py)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_formula_check$$
CREATE PROCEDURE hrms_formula_check(
    IN  p_component_id      BIGINT,
    IN  p_component_code    VARCHAR(30),
    IN  p_calculation_order INT,
    IN  p_formula           TEXT,
    OUT p_status            CHAR(1),
    OUT p_remarks           VARCHAR(500),
    OUT p_sample            DECIMAL(18,4)
)
chk: BEGIN
    DECLARE v_code VARCHAR(40);
    DECLARE v_list TEXT;
    DECLARE v_st   CHAR(1);
    DECLARE v_rm   VARCHAR(500);
    DECLARE v_res  DECIMAL(18,4);
    DECLARE v_n    INT DEFAULT 0;

    SET p_status = 'N';
    SET p_remarks = '';
    SET p_sample = NULL;
    SET v_code = UPPER(TRIM(COALESCE(p_component_code, '')));

    CALL hrms_engine_prepare();
    CALL hrms_formula_evaluate(p_formula, 'TOKENS', v_res, v_st, v_rm);
    IF v_st <> 'Y' THEN
        SET p_remarks = v_rm;
        LEAVE chk;
    END IF;

    SELECT COUNT(*) INTO v_n FROM tmp_hrms_formula_tokens WHERE token = v_code;
    IF v_code <> '' AND v_n > 0 THEN
        SET p_remarks = CONCAT('A component cannot use itself in its own formula (', v_code, ').');
        LEAVE chk;
    END IF;

    SELECT GROUP_CONCAT(t.token ORDER BY t.token SEPARATOR ', ') INTO v_list
      FROM tmp_hrms_formula_tokens t
     WHERE hrms_is_variable(t.token) = 0
       AND NOT EXISTS (SELECT 1 FROM salary_component_master m WHERE UPPER(m.component_code) = t.token);
    IF v_list IS NOT NULL THEN
        SET p_remarks = LEFT(CONCAT('Unknown name in formula: ', v_list,
            '. Use a component code or a payroll variable (Payroll variables page).'), 500);
        LEAVE chk;
    END IF;

    -- C-097: an inactive component always counts as 0, so it cannot be used
    SELECT GROUP_CONCAT(t.token ORDER BY t.token SEPARATOR ', ') INTO v_list
      FROM tmp_hrms_formula_tokens t
     WHERE hrms_is_variable(t.token) = 0
       AND NOT EXISTS (SELECT 1 FROM salary_component_master m
                        WHERE UPPER(m.component_code) = t.token AND m.is_active = 1);
    IF v_list IS NOT NULL THEN
        SET p_remarks = LEFT(CONCAT('Inactive component in formula: ', v_list,
            '. An inactive component is always 0. Activate it or remove it from the formula.'), 500);
        LEAVE chk;
    END IF;

    -- syntax test with every name set to 1000
    CALL hrms_engine_load_vars(NULL, NULL, NULL);
    UPDATE tmp_hrms_formula_vars SET var_value = 1000;
    CALL hrms_formula_evaluate(p_formula, 'EVAL', v_res, v_st, v_rm);
    IF v_st <> 'Y' AND v_rm NOT LIKE 'Formula gives no result%' THEN
        SET p_remarks = v_rm;
        LEAVE chk;
    END IF;

    SET p_sample  = v_res;
    SET p_status  = 'Y';
    SET p_remarks = 'Formula is valid.';
END$$

-- ---------------------------------------------------------------------
-- P2-006  hrms_component_slab_apply: slab "based on" / "% of" from payroll_variables
--        (copied from script.sql and patched by db_dumps/build/build_phase2.py)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_slab_apply$$
CREATE PROCEDURE hrms_component_slab_apply(
    IN  p_emp_id       VARCHAR(20),
    IN  p_component_id BIGINT,
    IN  p_slab_json    LONGTEXT,
    OUT p_count        INT,
    OUT p_msg          VARCHAR(500)
)
ap: BEGIN
    DECLARE v_code   VARCHAR(40);
    DECLARE v_i      INT DEFAULT 0;
    DECLARE v_path   VARCHAR(30);
    DECLARE v_based  VARCHAR(100);
    DECLARE v_min    VARCHAR(100);
    DECLARE v_max    VARCHAR(100);
    DECLARE v_rtype  VARCHAR(100);
    DECLARE v_rvalue VARCHAR(100);
    DECLARE v_pbase  VARCHAR(100);
    DECLARE v_prio   VARCHAR(100);
    DECLARE v_from   VARCHAR(100);
    DECLARE v_to     VARCHAR(100);
    DECLARE v_act    VARCHAR(100);

    SET p_count = 0;
    SET p_msg = NULL;

    SELECT MAX(UPPER(component_code)) INTO v_code FROM salary_component_master WHERE component_id = p_component_id;
    IF v_code IS NULL THEN
        SET p_msg = 'Component not found.';
        LEAVE ap;
    END IF;
    IF p_slab_json IS NULL OR JSON_VALID(p_slab_json) = 0 OR LEFT(TRIM(p_slab_json), 1) <> '[' THEN
        SET p_msg = 'Slab data must be a JSON array.';
        LEAVE ap;
    END IF;
    SET p_count = JSON_LENGTH(p_slab_json);
    IF p_count > 50 THEN
        SET p_msg = 'A component can have at most 50 slabs.';
        LEAVE ap;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_hrms_slab_in;
    DROP TEMPORARY TABLE IF EXISTS tmp_hrms_slab_in2;
    CREATE TEMPORARY TABLE tmp_hrms_slab_in (
        row_no       INT NOT NULL PRIMARY KEY,
        based_on     VARCHAR(30) NOT NULL,
        min_v        DECIMAL(12,2) NOT NULL,
        max_v        DECIMAL(12,2) NULL,
        result_type  VARCHAR(20) NOT NULL,
        result_value DECIMAL(12,2) NOT NULL,
        pct_base     VARCHAR(30) NOT NULL,
        priority     INT NOT NULL,
        eff_from     DATE NOT NULL,
        eff_to       DATE NULL,
        is_active    TINYINT NOT NULL
    );

    WHILE p_msg IS NULL AND v_i < p_count DO
        SET v_path   = CONCAT('$[', v_i, ']');
        SET v_based  = UPPER(NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_slab_json, CONCAT(v_path, '.slab_based_on'))), '')), ''), 'null'));
        SET v_min    = NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_slab_json, CONCAT(v_path, '.slab_min_value'))), '')), ''), 'null');
        SET v_max    = NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_slab_json, CONCAT(v_path, '.slab_max_value'))), '')), ''), 'null');
        SET v_rtype  = UPPER(NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_slab_json, CONCAT(v_path, '.result_type'))), '')), ''), 'null'));
        SET v_rvalue = NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_slab_json, CONCAT(v_path, '.result_value'))), '')), ''), 'null');
        SET v_pbase  = UPPER(NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_slab_json, CONCAT(v_path, '.percentage_base'))), '')), ''), 'null'));
        SET v_prio   = NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_slab_json, CONCAT(v_path, '.priority'))), '')), ''), 'null');
        SET v_from   = NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_slab_json, CONCAT(v_path, '.effective_from'))), '')), ''), 'null');
        SET v_to     = NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_slab_json, CONCAT(v_path, '.effective_to'))), '')), ''), 'null');
        SET v_act    = NULLIF(NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_slab_json, CONCAT(v_path, '.is_active'))), '')), ''), 'null');

        SET v_min   = COALESCE(v_min, '0');
        SET v_prio  = COALESCE(v_prio, CAST(v_i + 1 AS CHAR));
        SET v_from  = COALESCE(v_from, DATE_FORMAT(CURDATE(), '%Y-%m-%d'));
        SET v_act   = CASE WHEN LOWER(COALESCE(v_act, '1')) IN ('0', 'false', 'n') THEN '0' ELSE '1' END;
        SET v_pbase = COALESCE(v_pbase, 'NONE');

        IF v_based IS NULL OR CHAR_LENGTH(v_based) > 30 THEN
            SET p_msg = CONCAT('Slab ', v_i + 1, ': choose what the slab is based on.');
        ELSEIF v_min NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN
            SET p_msg = CONCAT('Slab ', v_i + 1, ': "From" must be a number, 0 or more.');
        ELSEIF v_max IS NOT NULL AND v_max NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN
            SET p_msg = CONCAT('Slab ', v_i + 1, ': "To" must be a number, or empty for no upper limit.');
        ELSEIF v_max IS NOT NULL AND CAST(v_max AS DECIMAL(14,2)) < CAST(v_min AS DECIMAL(14,2)) THEN
            SET p_msg = CONCAT('Slab ', v_i + 1, ': "From" is above "To".');
        ELSEIF COALESCE(v_rtype, '') NOT IN ('FIXED', 'PERCENTAGE') THEN
            SET p_msg = CONCAT('Slab ', v_i + 1, ': result must be FIXED or PERCENTAGE.');
        ELSEIF v_rvalue IS NULL OR v_rvalue NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN
            SET p_msg = CONCAT('Slab ', v_i + 1, ': value must be a number, 0 or more.');
        ELSEIF v_rtype = 'PERCENTAGE' AND (v_pbase = 'NONE' OR CHAR_LENGTH(v_pbase) > 30) THEN
            SET p_msg = CONCAT('Slab ', v_i + 1, ': choose what the percentage is taken of.');
        ELSEIF v_prio NOT REGEXP '^[0-9]+$' OR CAST(v_prio AS UNSIGNED) < 1 OR CAST(v_prio AS UNSIGNED) > 999 THEN
            SET p_msg = CONCAT('Slab ', v_i + 1, ': priority must be a whole number from 1 to 999.');
        ELSEIF v_from NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' OR STR_TO_DATE(v_from, '%Y-%m-%d') IS NULL THEN
            SET p_msg = CONCAT('Slab ', v_i + 1, ': "Effective From" must be a date.');
        ELSEIF v_to IS NOT NULL AND (v_to NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' OR STR_TO_DATE(v_to, '%Y-%m-%d') IS NULL) THEN
            SET p_msg = CONCAT('Slab ', v_i + 1, ': "Effective To" must be a date or empty.');
        ELSEIF v_to IS NOT NULL AND v_to < v_from THEN
            SET p_msg = CONCAT('Slab ', v_i + 1, ': "Effective To" is before "Effective From".');
        ELSE
            INSERT INTO tmp_hrms_slab_in
                (row_no, based_on, min_v, max_v, result_type, result_value, pct_base, priority, eff_from, eff_to, is_active)
            VALUES
                (v_i + 1, v_based, CAST(v_min AS DECIMAL(12,2)),
                 IF(v_max IS NULL, NULL, CAST(v_max AS DECIMAL(12,2))),
                 v_rtype, CAST(v_rvalue AS DECIMAL(12,2)),
                 IF(v_rtype = 'PERCENTAGE', v_pbase, 'NONE'),
                 CAST(v_prio AS UNSIGNED), STR_TO_DATE(v_from, '%Y-%m-%d'),
                 IF(v_to IS NULL, NULL, STR_TO_DATE(v_to, '%Y-%m-%d')), CAST(v_act AS UNSIGNED));
        END IF;
        SET v_i = v_i + 1;
    END WHILE;

    IF p_msg IS NULL THEN
        SELECT MIN(CONCAT('Priority ', x.priority, ' is used by more than one slab. Each slab needs its own priority.'))
          INTO p_msg
          FROM (SELECT priority FROM tmp_hrms_slab_in GROUP BY priority HAVING COUNT(*) > 1) x;
    END IF;
    -- C-097: a base must be a built-in name or an ACTIVE component (an inactive one is always 0)
    IF p_msg IS NULL THEN
        SELECT MIN(CONCAT('Slab ', t.row_no, ': "', t.based_on, '" is not CTC, GROSS or an active component code.'))
          INTO p_msg
          FROM tmp_hrms_slab_in t
         WHERE hrms_is_variable(t.based_on) = 0
           AND NOT EXISTS (SELECT 1 FROM salary_component_master m
                            WHERE UPPER(m.component_code) = t.based_on AND m.component_id <> p_component_id
                              AND m.is_active = 1);
    END IF;
    IF p_msg IS NULL THEN
        SELECT MIN(CONCAT('Slab ', t.row_no, ': percentage of "', t.pct_base, '" is not CTC, GROSS or an active component code.'))
          INTO p_msg
          FROM tmp_hrms_slab_in t
         WHERE t.result_type = 'PERCENTAGE'
           AND hrms_is_variable(t.pct_base) = 0
           AND NOT EXISTS (SELECT 1 FROM salary_component_master m
                            WHERE UPPER(m.component_code) = t.pct_base AND m.component_id <> p_component_id
                              AND m.is_active = 1);
    END IF;
    -- C-098: overlapping ranges are allowed; where they overlap the lowest priority
    -- number wins (each slab has its own priority, checked above). A slab that can
    -- never win - its whole range and dates sit inside a slab with a lower number -
    -- is reported by hrms_component_rules_check (C-100).
    IF p_msg IS NOT NULL THEN
        LEAVE ap;
    END IF;

    DELETE FROM salary_component_slab WHERE component_id = p_component_id;
    INSERT INTO salary_component_slab
        (component_id, slab_based_on, slab_min_value, slab_max_value, result_type, result_value,
         percentage_base, priority, effective_from, effective_to, is_active, created_by)
    SELECT p_component_id, based_on, min_v, max_v, result_type, result_value,
           pct_base, priority, eff_from, eff_to, is_active, p_emp_id
      FROM tmp_hrms_slab_in
     ORDER BY priority;
    UPDATE salary_component_master
       SET is_slab = IF(p_count > 0, 1, 0), updated_at = CURRENT_TIMESTAMP
     WHERE component_id = p_component_id;
END$$

-- ---------------------------------------------------------------------
-- P2-007  hrms_update_component_master: reserved names and bases from payroll_variables; "applies only when" accepts any Yes/No variable
--        (copied from script.sql and patched by db_dumps/build/build_phase2.py)
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
    DECLARE v_audit_old  JSON DEFAULT NULL;    -- C-131
    DECLARE v_audit_new  JSON DEFAULT NULL;    -- C-131
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
            SET v_audit_old = hrms_audit_component_json(v_id);    -- C-131
            START TRANSACTION;
            UPDATE salary_component_master
               SET is_active = p_is_active, updated_at = CURRENT_TIMESTAMP
             WHERE component_id = v_id;
            IF p_is_active = 1 THEN
                CALL hrms_attach_component(v_id, v_attached);
            END IF;
            CALL hrms_component_change_finish(v_id, v_msg, v_findings, v_impact, v_structures, v_changed);
            IF v_msg IS NULL THEN
                -- C-131: audit trail (before / after)
                SET v_audit_new = hrms_audit_component_json(v_id);
                CALL hrms_payroll_audit_add('COMPONENT', IF(p_is_active = 1, 'ACTIVATE', 'DEACTIVATE'),
                     'salary_component_master', v_id, NULL, NULL, NULL, NULL, v_audit_old, v_audit_new,
                     CONCAT(v_old_code, IF(p_is_active = 1, ' activated', ' deactivated'),
                            '. Employee amounts changed: ', v_changed, '.'), p_emp_id);
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
    IF v_msg IS NULL AND (hrms_is_reserved_name(v_code) = 1
                                   OR v_code IN ('ROUND','LEAST','GREATEST','IF','CEIL','FLOOR','ABS','AND','OR','NOT','NONE')) THEN
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
    -- P2: "applies only when" may use any active Yes/No payroll variable
    IF v_eparam = 'EMPLOYEE_ESI_ELIGIBLE' THEN
        SET v_eparam = 'ESI_APPLICABLE';
    END IF;
    IF v_msg IS NULL AND v_eparam IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM payroll_variables
                        WHERE var_code = v_eparam AND is_active = 1 AND data_type = 'FLAG') THEN
        SET v_msg = CONCAT('"Applies only when" must be an active Yes/No payroll variable; ', v_eparam, ' is not one.');
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
        ELSEIF hrms_is_variable(v_base) = 0 THEN
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
    SET v_audit_old = IF(v_action = 'INSERT', NULL, hrms_audit_component_json(v_id));    -- C-131
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

    -- C-131: audit trail (before / after); a total that got this component is logged too
    SET v_audit_new = hrms_audit_component_json(v_id);
    CALL hrms_payroll_audit_add('COMPONENT', IF(v_action = 'INSERT', 'CREATE', 'UPDATE'),
         'salary_component_master', v_id, NULL, NULL, NULL, NULL, v_audit_old, v_audit_new,
         CONCAT(v_code, IF(v_action = 'INSERT', ' created', ' changed'), '. Employee amounts changed: ', v_changed, '.',
                IF(v_order_note IS NULL, '', CONCAT(' ', v_order_note))), p_emp_id);
    IF v_total_note LIKE 'Added to %' THEN
        CALL hrms_payroll_audit_add('COMPONENT', 'UPDATE', 'salary_component_master', v_total, NULL, NULL, NULL, NULL,
             JSON_OBJECT('code', v_total, 'formula', v_tformula),
             JSON_OBJECT('code', v_total, 'formula', CONCAT(TRIM(v_tformula), ' + ', v_code)),
             CONCAT(v_code, ' added to ', v_total, '.'), p_emp_id);
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
-- P2-008  hrms_update_employee_salary_component: bases from payroll_variables
--        (copied from script.sql and patched by db_dumps/build/build_phase2.py)
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
    DECLARE v_audit_old JSON DEFAULT NULL;    -- C-132
    DECLARE v_audit_new JSON DEFAULT NULL;    -- C-132
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
       AND hrms_is_variable(v_base) = 0 THEN
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

    SET v_audit_old = hrms_audit_salary_json(v_structure);    -- C-132
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
    -- C-132: audit trail
    SET v_audit_new = hrms_audit_salary_json(v_structure);
    CALL hrms_payroll_audit_add('SALARY', IF(v_calc = 'DEFAULT', 'COMPONENT_DEFAULT', 'COMPONENT_OWN'), 'employee_salary_structure',
         v_structure, p_target_emp_id, NULL, NULL, NULL, v_audit_old, v_audit_new,
         CONCAT(v_code, IF(v_calc = 'DEFAULT', ' follows the component master again.',
                           CONCAT(' set to ', v_calc, '.'))), p_emp_id);
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
-- P2-009  hrms_save_employee_salary: bases from payroll_variables
--        (copied from script.sql and patched by db_dumps/build/build_phase2.py)
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
    DECLARE v_audit_old JSON DEFAULT NULL;    -- C-132
    DECLARE v_audit_new JSON DEFAULT NULL;    -- C-132
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

    SET v_audit_old = hrms_audit_salary_json(p_structure_id);    -- C-132
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
           AND hrms_is_variable(v_base) = 0
           AND NOT EXISTS (SELECT 1 FROM salary_component_master WHERE UPPER(component_code) = v_base) THEN
            SET v_msg = CONCAT(v_code, ': "', v_base, '" is not a payroll variable or a component code.');
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
    -- C-132: audit trail (a new period is logged against the new salary row)
    SET v_audit_new = hrms_audit_salary_json(v_target);
    CALL hrms_payroll_audit_add('SALARY', IF(v_new = 1, 'NEW_PERIOD', 'UPDATE'), 'salary_structure', v_target,
         p_target_emp_id, NULL, NULL, NULL, v_audit_old, v_audit_new,
         CONCAT('Monthly CTC ', JSON_UNQUOTE(JSON_EXTRACT(v_audit_old, '$.monthly_ctc')), ' -> ', p_monthly_ctc,
                IF(v_count > 0, CONCAT('; ', v_count, ' component change(s)'), ''),
                IF(v_new = 1, CONCAT('; new salary from ', DATE_FORMAT(p_effective_from, '%d %b %Y'),
                                     ', previous salary row ', p_structure_id), ''), '.'), p_emp_id);
    COMMIT;

    SELECT 'Y' AS status,
           IF(v_new = 1,
              CONCAT('Saved as a new salary from ', DATE_FORMAT(p_effective_from, '%d %b %Y'),
                     '. The previous salary now ends on ', DATE_FORMAT(DATE_SUB(p_effective_from, INTERVAL 1 DAY), '%d %b %Y'), '.'),
              CONCAT('Salary saved and recalculated', IF(v_count > 0, CONCAT(' (', v_count, ' component change(s))'), ''), '.')) AS remarks,
           v_target AS structure_id, v_new AS new_period;
END$$

-- ---------------------------------------------------------------------
-- P2-010  hrms_component_rules_check: names from payroll_variables
--        (copied from script.sql and patched by db_dumps/build/build_phase2.py)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_rules_check$$
CREATE PROCEDURE hrms_component_rules_check(IN p_component_id BIGINT, IN p_output TINYINT)
BEGIN
    DECLARE v_done    INT DEFAULT 0;
    DECLARE v_code    VARCHAR(40);
    DECLARE v_calc    VARCHAR(30);
    DECLARE v_base    VARCHAR(40);
    DECLARE v_formula TEXT;
    DECLARE v_manual  TINYINT;
    DECLARE v_slabbed TINYINT;
    DECLARE v_cid     BIGINT;
    DECLARE v_focus   VARCHAR(40) DEFAULT NULL;
    DECLARE v_res     DECIMAL(18,4);
    DECLARE v_st      CHAR(1);
    DECLARE v_rm      VARCHAR(500);
    DECLARE v_i       INT DEFAULT 0;
    DECLARE v_added   INT DEFAULT 1;
    DECLARE v_list    TEXT;
    DECLARE cur CURSOR FOR
        SELECT m.component_id, UPPER(m.component_code), UPPER(m.calculation_type), UPPER(COALESCE(m.percentage_base, 'NONE')),
               NULLIF(TRIM(COALESCE(m.formula_expression, '')), ''),
               IF(m.is_manual = 1 OR m.calculation_type = 'MANUAL', 1, 0),
               IF(m.is_slab = 1 AND EXISTS (SELECT 1 FROM salary_component_slab s
                                             WHERE s.component_id = m.component_id AND s.is_active = 1), 1, 0)
          FROM salary_component_master m
         WHERE m.is_active = 1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    SET SESSION group_concat_max_len = 1000000;
    CALL hrms_engine_prepare();
    SELECT MAX(UPPER(component_code)) INTO v_focus FROM salary_component_master WHERE component_id = p_component_id;

    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hrms_findings (
        seq            INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        level          VARCHAR(10) NOT NULL,
        check_code     VARCHAR(20) NOT NULL,
        component_code VARCHAR(40) NULL,
        message        VARCHAR(700) NOT NULL,
        suggest_order  INT NULL
    );
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hrms_dep (
        code VARCHAR(40) NOT NULL,
        uses VARCHAR(64) NOT NULL,
        via  VARCHAR(20) NOT NULL,
        PRIMARY KEY (code, uses, via)
    );
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hrms_reach (
        f VARCHAR(64) NOT NULL,
        t VARCHAR(64) NOT NULL,
        PRIMARY KEY (f, t)
    );
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hrms_req_dates (
        d     DATE NOT NULL PRIMARY KEY,
        label VARCHAR(100) NOT NULL
    );
    DELETE FROM tmp_hrms_findings;
    DELETE FROM tmp_hrms_dep;
    DELETE FROM tmp_hrms_reach;
    DELETE FROM tmp_hrms_req_dates;

    -- 1. who uses whom: exactly the names the engine reads for each active component
    OPEN cur;
    rd: LOOP
        SET v_done = 0;
        FETCH cur INTO v_cid, v_code, v_calc, v_base, v_formula, v_manual, v_slabbed;
        IF v_done = 1 THEN LEAVE rd; END IF;
        IF v_slabbed = 1 THEN
            INSERT IGNORE INTO tmp_hrms_dep (code, uses, via)
            SELECT v_code, UPPER(s.slab_based_on), 'slab' FROM salary_component_slab s
             WHERE s.component_id = v_cid AND s.is_active = 1;
            INSERT IGNORE INTO tmp_hrms_dep (code, uses, via)
            SELECT v_code, UPPER(s.percentage_base), 'slab %' FROM salary_component_slab s
             WHERE s.component_id = v_cid AND s.is_active = 1 AND s.result_type = 'PERCENTAGE'
               AND UPPER(COALESCE(s.percentage_base, 'NONE')) <> 'NONE';
        ELSEIF v_manual = 1 THEN
            SET v_i = v_i;   -- entered by hand: uses nothing
        ELSEIF v_calc IN ('FORMULA', 'STATUTORY') AND v_formula IS NOT NULL THEN
            DELETE FROM tmp_hrms_formula_tokens;
            CALL hrms_formula_evaluate(v_formula, 'TOKENS', v_res, v_st, v_rm);
            IF v_st = 'Y' THEN
                INSERT IGNORE INTO tmp_hrms_dep (code, uses, via)
                SELECT v_code, token, 'formula' FROM tmp_hrms_formula_tokens WHERE token <> 'MANUAL_AMOUNT';
            ELSE
                INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
                VALUES ('ERROR', 'NAMES', v_code, LEFT(CONCAT(v_code, ': the formula cannot be read - ', v_rm), 700));
            END IF;
        ELSEIF v_calc = 'PERCENTAGE' AND v_base <> 'NONE' THEN
            INSERT IGNORE INTO tmp_hrms_dep (code, uses, via) VALUES (v_code, v_base, 'based on');
        END IF;
    END LOOP rd;
    CLOSE cur;

    IF p_output = 2 THEN
        SELECT d.code, d.uses, d.via, m.calculation_order AS uses_order
          FROM tmp_hrms_dep d
          LEFT JOIN salary_component_master m ON UPPER(m.component_code) = d.uses
         ORDER BY d.code, d.uses;
    ELSEIF p_output <> 3 THEN
        -- 2. NAMES: unknown or inactive names
        INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
        SELECT 'ERROR', 'NAMES', d.code,
               CONCAT(d.code, ' uses ', d.uses, ' (', d.via, '), which ',
                      IF(m.component_id IS NULL, 'does not exist', 'is inactive and always 0'), '.')
          FROM tmp_hrms_dep d
          LEFT JOIN salary_component_master m ON UPPER(m.component_code) = d.uses
         WHERE hrms_is_variable(d.uses) = 0
           AND (m.component_id IS NULL OR m.is_active = 0)
           AND (v_focus IS NULL OR d.code = v_focus OR d.uses = v_focus);

        -- 3. ORDER: everything each component reaches through what it uses
        INSERT IGNORE INTO tmp_hrms_reach (f, t) SELECT code, uses FROM tmp_hrms_dep;
        SET v_i = 0;
        WHILE v_added > 0 AND v_i < 40 DO
            DROP TEMPORARY TABLE IF EXISTS tmp_hrms_reach_new;
            CREATE TEMPORARY TABLE tmp_hrms_reach_new AS
                SELECT DISTINCT r.f, d.uses AS t FROM tmp_hrms_reach r JOIN tmp_hrms_dep d ON d.code = r.t;
            INSERT IGNORE INTO tmp_hrms_reach (f, t) SELECT f, t FROM tmp_hrms_reach_new;
            SET v_added = ROW_COUNT();
            SET v_i = v_i + 1;
        END WHILE;
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_reach_new;
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_reach_back;
        CREATE TEMPORARY TABLE tmp_hrms_reach_back AS SELECT f, t FROM tmp_hrms_reach;

        -- C-107: highest order each component uses, lowest order of what uses it
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_dep_max;
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_used_min;
        CREATE TEMPORARY TABLE tmp_hrms_dep_max AS
            SELECT d.code, MAX(m.calculation_order) AS max_order
              FROM tmp_hrms_dep d
              JOIN salary_component_master m ON UPPER(m.component_code) = d.uses AND m.is_active = 1
             GROUP BY d.code;
        CREATE TEMPORARY TABLE tmp_hrms_used_min AS
            SELECT d.uses AS code, MIN(m.calculation_order) AS min_order
              FROM tmp_hrms_dep d
              JOIN salary_component_master m ON UPPER(m.component_code) = d.code AND m.is_active = 1
             GROUP BY d.uses;
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_dep_max2;
        CREATE TEMPORARY TABLE tmp_hrms_dep_max2 AS SELECT code, max_order FROM tmp_hrms_dep_max;

        -- a pay component using one calculated later (no way back): move it above what it uses
        INSERT INTO tmp_hrms_findings (level, check_code, component_code, message, suggest_order)
        SELECT 'WARNING', 'ORDER', d.code,
               CONCAT(d.code, ' (order ', a.calculation_order, ') uses ', d.uses, ' (order ', b.calculation_order,
                      '), which is calculated later. Give ', d.code, ' an order above ', COALESCE(dm.max_order, b.calculation_order),
                      IF(um.min_order IS NULL, '', CONCAT(' and below ', um.min_order)),
                      IF(hrms_free_order(dm.max_order, um.min_order, a.component_id) IS NULL, '',
                         CONCAT(', for example ', hrms_free_order(dm.max_order, um.min_order, a.component_id))), '.'),
               hrms_free_order(dm.max_order, um.min_order, a.component_id)
          FROM tmp_hrms_dep d
          JOIN salary_component_master a ON UPPER(a.component_code) = d.code AND a.is_active = 1
                                        AND a.calculation_scope = 'COMPONENT'
          JOIN salary_component_master b ON UPPER(b.component_code) = d.uses AND b.is_active = 1
          LEFT JOIN tmp_hrms_dep_max dm ON dm.code = d.code
          LEFT JOIN tmp_hrms_used_min um ON um.code = d.code
         WHERE b.calculation_order >= a.calculation_order
           AND NOT EXISTS (SELECT 1 FROM tmp_hrms_reach_back r WHERE r.f = d.uses AND r.t = d.code)
           AND (v_focus IS NULL OR d.code = v_focus OR d.uses = v_focus);

        -- a total must come after everything it uses: move the used component below the total
        INSERT INTO tmp_hrms_findings (level, check_code, component_code, message, suggest_order)
        -- move the used component below the total when there is room, otherwise move the total up
        SELECT 'ERROR', 'ORDER',
               IF(hrms_free_order(GREATEST(COALESCE(bm.max_order, 0), COALESCE((SELECT MAX(z.calculation_order) FROM salary_component_master z WHERE z.is_active = 1 AND z.calculation_order < a.calculation_order AND z.component_id <> b.component_id), 0)), a.calculation_order, b.component_id) IS NULL, d.code, d.uses),
               CONCAT(d.code, ' is a total and must be calculated after everything it uses, but ', d.uses,
                      ' (order ', b.calculation_order, ') comes after it (order ', a.calculation_order, '). ',
                      IF(hrms_free_order(GREATEST(COALESCE(bm.max_order, 0), COALESCE((SELECT MAX(z.calculation_order) FROM salary_component_master z WHERE z.is_active = 1 AND z.calculation_order < a.calculation_order AND z.component_id <> b.component_id), 0)), a.calculation_order, b.component_id) IS NOT NULL,
                         CONCAT('Give ', d.uses, ' an order below ', a.calculation_order, ', for example ',
                                hrms_free_order(GREATEST(COALESCE(bm.max_order, 0), COALESCE((SELECT MAX(z.calculation_order) FROM salary_component_master z WHERE z.is_active = 1 AND z.calculation_order < a.calculation_order AND z.component_id <> b.component_id), 0)), a.calculation_order, b.component_id), '.'),
                         CONCAT('Give ', d.code, ' an order above ', COALESCE(am.max_order, b.calculation_order),
                                IF(hrms_free_order(am.max_order, au.min_order, a.component_id) IS NULL, '.',
                                   CONCAT(', for example ', hrms_free_order(am.max_order, au.min_order, a.component_id), '.'))))),
               COALESCE(hrms_free_order(GREATEST(COALESCE(bm.max_order, 0), COALESCE((SELECT MAX(z.calculation_order) FROM salary_component_master z WHERE z.is_active = 1 AND z.calculation_order < a.calculation_order AND z.component_id <> b.component_id), 0)), a.calculation_order, b.component_id),
                        hrms_free_order(am.max_order, au.min_order, a.component_id))
          FROM tmp_hrms_dep d
          JOIN salary_component_master a ON UPPER(a.component_code) = d.code AND a.is_active = 1
                                        AND a.calculation_scope = 'AGGREGATE'
          JOIN salary_component_master b ON UPPER(b.component_code) = d.uses AND b.is_active = 1
          LEFT JOIN tmp_hrms_dep_max bm ON bm.code = d.uses
          LEFT JOIN tmp_hrms_dep_max2 am ON am.code = d.code
          LEFT JOIN tmp_hrms_used_min au ON au.code = d.code
         WHERE b.calculation_order >= a.calculation_order
           AND NOT EXISTS (SELECT 1 FROM tmp_hrms_reach_back r WHERE r.f = d.uses AND r.t = d.code)
           AND (v_focus IS NULL OR d.code = v_focus OR d.uses = v_focus);

        -- a total must add up at least one component or total
        INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
        SELECT 'ERROR', 'TOTAL', UPPER(m.component_code),
               CONCAT(UPPER(m.component_code), ' is a total but uses no component or total. ',
                      'A total must add up components or other totals, for example BASIC + HRA.')
          FROM salary_component_master m
         WHERE m.is_active = 1 AND m.calculation_scope = 'AGGREGATE'
           AND NOT EXISTS (SELECT 1 FROM tmp_hrms_dep d
                             JOIN salary_component_master x ON UPPER(x.component_code) = d.uses AND x.is_active = 1
                            WHERE d.code = UPPER(m.component_code))
           AND (p_component_id IS NULL OR m.component_id = p_component_id);
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_dep_max;
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_dep_max2;
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_used_min;

        -- a real circle: settled by repeated passes, shown for information
        INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
        SELECT 'INFO', 'ORDER', d.code,
               CONCAT(d.code, ' (order ', a.calculation_order, ') uses ', d.uses, ' (order ', b.calculation_order,
                      ') and ', d.uses, ' depends back on ', d.code,
                      '. This circle is settled by calculating again until the amounts stop changing.')
          FROM tmp_hrms_dep d
          JOIN salary_component_master a ON UPPER(a.component_code) = d.code AND a.is_active = 1
          JOIN salary_component_master b ON UPPER(b.component_code) = d.uses AND b.is_active = 1
         WHERE b.calculation_order >= a.calculation_order
           AND EXISTS (SELECT 1 FROM tmp_hrms_reach_back r WHERE r.f = d.uses AND r.t = d.code)
           AND (v_focus IS NULL OR d.code = v_focus OR d.uses = v_focus);
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_reach_back;

        -- 4. SLAB: a slab that can never apply (inside a slab with a lower number)
        INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
        SELECT 'ERROR', 'SLAB', UPPER(m.component_code),
               CONCAT(UPPER(m.component_code), ': the slab with priority ', b.priority, ' (', b.slab_based_on, ' ',
                      FORMAT(b.slab_min_value, 2), ' to ', COALESCE(FORMAT(b.slab_max_value, 2), 'no limit'),
                      ') can never apply - the slab with priority ', a.priority, ' covers its whole range and wins.')
          FROM salary_component_slab b
          JOIN salary_component_slab a
            ON a.component_id = b.component_id AND a.slab_id <> b.slab_id
           AND a.is_active = 1 AND UPPER(a.slab_based_on) = UPPER(b.slab_based_on)
           AND a.priority < b.priority
           AND a.slab_min_value <= b.slab_min_value
           AND (a.slab_max_value IS NULL OR (b.slab_max_value IS NOT NULL AND b.slab_max_value <= a.slab_max_value))
           AND a.effective_from <= b.effective_from
           AND (a.effective_to IS NULL OR (b.effective_to IS NOT NULL AND b.effective_to <= a.effective_to))
          JOIN salary_component_master m ON m.component_id = b.component_id AND m.is_active = 1 AND m.is_slab = 1
         WHERE b.is_active = 1
           AND (p_component_id IS NULL OR m.component_id = p_component_id);

        -- gaps between the ranges of the slabs valid on each start date (and today)
        INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
        SELECT 'WARNING', 'SLAB', g.code,
               CONCAT(g.code, ': ', g.based_on, ' from ', FORMAT(g.gap_from, 2), ' to ', FORMAT(g.gap_to, 2),
                      ' has no slab (slabs valid on ', DATE_FORMAT(g.d, '%d %b %Y'),
                      '). An employee in this range gets 0.')
          FROM (
                SELECT x.code, x.based_on, x.d,
                       COALESCE(x.prev_max + 0.01, 0) AS gap_from, x.slab_min_value - 0.01 AS gap_to,
                       ROW_NUMBER() OVER (PARTITION BY x.code ORDER BY x.d, x.slab_min_value) AS rn
                  FROM (
                        SELECT UPPER(m.component_code) AS code, UPPER(s.slab_based_on) AS based_on, dd.d,
                               s.slab_min_value,
                               MAX(COALESCE(s.slab_max_value, 999999999999.99)) OVER (
                                   PARTITION BY m.component_id, UPPER(s.slab_based_on), dd.d
                                   ORDER BY s.slab_min_value, s.priority
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_max
                          FROM salary_component_master m
                          JOIN (SELECT DISTINCT component_id, effective_from AS d FROM salary_component_slab WHERE is_active = 1
                                UNION
                                SELECT DISTINCT component_id, CURDATE() FROM salary_component_slab WHERE is_active = 1) dd
                            ON dd.component_id = m.component_id
                          JOIN salary_component_slab s
                            ON s.component_id = m.component_id AND s.is_active = 1
                           AND s.effective_from <= dd.d AND (s.effective_to IS NULL OR s.effective_to >= dd.d)
                         WHERE m.is_active = 1 AND m.is_slab = 1
                           AND (p_component_id IS NULL OR m.component_id = p_component_id)
                       ) x
                 WHERE x.slab_min_value > COALESCE(x.prev_max, 0) + 0.01
               ) g
         WHERE g.rn = 1;

        -- dates that will be calculated: every salary period and every unfinished payroll
        INSERT IGNORE INTO tmp_hrms_req_dates (d, label)
        SELECT pc.period_end,
               CONCAT('payroll ', ELT(pc.payroll_month, 'January','February','March','April','May','June','July',
                      'August','September','October','November','December'), ' ', pc.payroll_year)
          FROM payroll_cycles pc
         WHERE pc.cycle_status IN ('OPEN','ATTENDANCE_VERIFIED','STRUCTURE_VERIFIED','PROCESSING','CALCULATED','APPROVED');
        INSERT IGNORE INTO tmp_hrms_req_dates (d, label)
        SELECT hrms_structure_calc_date(ss.structure_id), CONCAT('salary of ', MIN(ss.emp_id))
          FROM salary_structure ss
         WHERE ss.structure_status = 'ACTIVE'
         GROUP BY hrms_structure_calc_date(ss.structure_id);

        INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
        SELECT 'ERROR', 'SLAB', x.code,
               CONCAT(x.code, ': no slab is valid on ', DATE_FORMAT(x.d, '%d %b %Y'), ' (', x.label,
                      '), so that calculation would stop. Add a slab whose dates cover it.')
          FROM (
                SELECT UPPER(m.component_code) AS code, r.d, r.label,
                       ROW_NUMBER() OVER (PARTITION BY m.component_id ORDER BY r.d) AS rn
                  FROM salary_component_master m
                  JOIN tmp_hrms_req_dates r
                 WHERE m.is_active = 1 AND m.is_slab = 1
                   AND EXISTS (SELECT 1 FROM salary_component_slab s WHERE s.component_id = m.component_id AND s.is_active = 1)
                   AND NOT EXISTS (SELECT 1 FROM salary_component_slab s
                                    WHERE s.component_id = m.component_id AND s.is_active = 1
                                      AND s.effective_from <= r.d AND (s.effective_to IS NULL OR s.effective_to >= r.d))
                   AND (p_component_id IS NULL OR m.component_id = p_component_id)
               ) x
         WHERE x.rn = 1;

        -- 5. TOTAL: each pay component inside the total of its type
        INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
        SELECT 'WARNING', 'TOTAL', UPPER(m.component_code),
               CONCAT(UPPER(m.component_code), ' is ', LOWER(REPLACE(m.component_type, '_', ' ')), ' but is not in ',
                      t.total_code, ', so it is ',
                      CASE m.component_type WHEN 'EARNING' THEN 'not paid' WHEN 'DEDUCTION' THEN 'not deducted'
                           ELSE 'not counted in the CTC' END,
                      '. Add it to the ', t.total_code, ' formula.')
          FROM salary_component_master m
          JOIN (SELECT CONVERT('EARNING' USING utf8mb4) COLLATE utf8mb4_general_ci AS ctype,
                       CONVERT('GROSS' USING utf8mb4) COLLATE utf8mb4_general_ci AS total_code
                UNION ALL SELECT 'DEDUCTION', 'TOTAL_DEDUCTIONS'
                UNION ALL SELECT 'EMPLOYER_CONTRIBUTION', 'TOTAL_EMPLOYER_CONTRIBUTION') t
            ON t.ctype = m.component_type
          JOIN salary_component_master tm
            ON UPPER(tm.component_code) = t.total_code AND tm.is_active = 1 AND tm.calculation_scope = 'AGGREGATE'
         WHERE m.is_active = 1 AND m.calculation_scope = 'COMPONENT'
           AND NOT EXISTS (SELECT 1 FROM tmp_hrms_dep d WHERE d.code = t.total_code AND d.uses = UPPER(m.component_code))
           AND (p_component_id IS NULL OR m.component_id = p_component_id OR tm.component_id = p_component_id);

        -- a pay component inside the total of another type (counted twice or on the wrong side)
        INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
        SELECT 'WARNING', 'TOTAL', UPPER(m.component_code),
               CONCAT(UPPER(m.component_code), ' is ', LOWER(REPLACE(m.component_type, '_', ' ')), ' but is inside ',
                      d.code, '. Remove it from the ', d.code, ' formula.')
          FROM tmp_hrms_dep d
          JOIN (SELECT CONVERT('EARNING' USING utf8mb4) COLLATE utf8mb4_general_ci AS ctype,
                       CONVERT('GROSS' USING utf8mb4) COLLATE utf8mb4_general_ci AS total_code
                UNION ALL SELECT 'DEDUCTION', 'TOTAL_DEDUCTIONS'
                UNION ALL SELECT 'EMPLOYER_CONTRIBUTION', 'TOTAL_EMPLOYER_CONTRIBUTION') t
            ON t.total_code = d.code
          JOIN salary_component_master m
            ON UPPER(m.component_code) = d.uses AND m.is_active = 1 AND m.calculation_scope = 'COMPONENT'
           AND m.component_type <> t.ctype
          JOIN salary_component_master tm ON UPPER(tm.component_code) = d.code
         WHERE (p_component_id IS NULL OR m.component_id = p_component_id OR tm.component_id = p_component_id);

        -- 6. FORMULA: slab components ignore their own formula / percentage
        SELECT GROUP_CONCAT(UPPER(m.component_code) ORDER BY m.calculation_order SEPARATOR ', ') INTO v_list
          FROM salary_component_master m
         WHERE m.is_active = 1 AND m.is_slab = 1
           AND EXISTS (SELECT 1 FROM salary_component_slab s WHERE s.component_id = m.component_id AND s.is_active = 1)
           AND (NULLIF(TRIM(COALESCE(m.formula_expression, '')), '') IS NOT NULL
                OR (m.calculation_type = 'PERCENTAGE' AND COALESCE(m.percentage_value, 0) > 0))
           AND (p_component_id IS NULL OR m.component_id = p_component_id);
        IF v_list IS NOT NULL THEN
            INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
            VALUES ('INFO', 'FORMULA', IF(p_component_id IS NULL, NULL, v_focus),
                    LEFT(CONCAT('Decided by slabs, so the formula / percentage is not used: ', v_list, '.'), 700));
        END IF;

        -- 7. CYCLE: a calculated payroll that a rule change makes out of date
        INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
        SELECT 'WARNING', 'CYCLE', NULL,
               CONCAT('Payroll ', ELT(pc.payroll_month, 'January','February','March','April','May','June','July',
                      'August','September','October','November','December'), ' ', pc.payroll_year,
                      ' is ', pc.cycle_status, '. Saving a rule change sends it back to "Structures verified"; calculate it again.')
          FROM payroll_cycles pc
         WHERE pc.cycle_status IN ('PROCESSING', 'CALCULATED', 'APPROVED');

        IF p_output = 1 THEN
            SELECT level, check_code, component_code, message, suggest_order
              FROM tmp_hrms_findings
             ORDER BY FIELD(level, 'ERROR', 'WARNING', 'INFO'), seq;
        END IF;
    END IF;
END$$

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
