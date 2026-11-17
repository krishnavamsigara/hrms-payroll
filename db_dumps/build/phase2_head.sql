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
