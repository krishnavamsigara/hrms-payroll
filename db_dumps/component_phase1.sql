-- =====================================================================
-- component_phase1.sql : salary components, phase 1
--   One "how is it calculated" choice, a separate Statutory flag, and the
--   procedures behind the new add / edit component page
--   (payroll/salary_components/new and /edit/{id}).
--
-- Database : production_hrms_db (MySQL 8) and hrmstest (MariaDB 10.11)
-- Run with : mysql --default-character-set=utf8mb4 -u <user> -p <database> < component_phase1.sql
-- Order    : script.sql -> component_phase1.sql -> component_phase2.sql -> component_phase3.sql
--            Run script.sql again later? Then run the three phase files
--            again too: script.sql recreates procedures the phases change.
-- Re-run   : safe. The column is added once, the clean-up only touches
--            rows that still hold unused settings, procedures are
--            recreated. Salary amounts do not change (every salary is
--            recalculated at the end and checked).
--
-- APPLICATION FILES (deploy with this phase)
--   new     app/Views/payroll/salary_component_form.php   add / edit page
--   changed app/Controllers/SalaryController.php          component_form, component_save
--           app/Models/SalaryModel.php                    component_get, formula_names,
--                                                         component_save, component_set_flags
--           app/Config/Routes.php                         payroll/salary_components/new,
--                                                         /edit/(:num), /save
--           app/Views/payroll/salary_components.php       Add / Edit open the new page
--
-- CHANGE INDEX
--   P1-001  ALTER TABLE  salary_component_master + is_statutory
--           (PF, ESI, PT ...). The old page saved its "Statutory?" answer
--           into is_taxable; taxable and statutory are now two flags.
--   P1-002  DATA         one calculation method per component: settings
--           the engine never used are cleared (formula text on percentage
--           components, percentage / formula on slab components, the
--           MANUAL_AMOUNT formula on monthly-entry components, STATUTORY
--           becomes FORMULA). Employee rows that follow the company rule
--           get the same values. Amounts stay the same.
--   P1-003  FUNCTION     hrms_component_method(component_id)
--           FIXED / PERCENT / FORMULA / SLAB / MONTHLY / TOTAL
--   P1-004  PROCEDURE    hrms_component_get      one component for the form
--   P1-005  PROCEDURE    hrms_formula_names      names a formula can use
--   P1-006  PROCEDURE    hrms_component_save     save with one method
--   P1-007  PROCEDURE    hrms_component_set_flags statutory flag (phase 3
--                        adds "counts in total" and "balancing")
--   P1-008  DATA         every salary recalculated (amounts unchanged)
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- P1-001  is_statutory (added once). Statutory = components that had
--         the STATUTORY calculation type or slabs before P1-002
--         (EPF, ESI, PT, EPF admin). HR can change it on the page.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_phase1_columns$$
CREATE PROCEDURE hrms_phase1_columns()
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = DATABASE() AND table_name = 'salary_component_master'
                      AND column_name = 'is_statutory') THEN
        ALTER TABLE salary_component_master
          ADD COLUMN is_statutory TINYINT(1) NOT NULL DEFAULT 0 AFTER is_taxable;
        UPDATE salary_component_master
           SET is_statutory = 1
         WHERE calculation_scope = 'COMPONENT'
           AND (calculation_type = 'STATUTORY' OR is_slab = 1);
    END IF;
END$$
CALL hrms_phase1_columns()$$
DROP PROCEDURE IF EXISTS hrms_phase1_columns$$

-- ---------------------------------------------------------------------
-- P1-002  one calculation method per component (pay components only;
--         totals keep their formula). Same precedence as the engine:
--         monthly entry, then slabs, then the calculation type.
-- ---------------------------------------------------------------------
-- monthly entry: no formula, no percentage
UPDATE salary_component_master
   SET calculation_type = 'MANUAL', is_manual = 1, is_slab = 0,
       formula_expression = NULL, percentage_base = 'NONE', percentage_value = 0
 WHERE calculation_scope = 'COMPONENT'
   AND (is_manual = 1 OR calculation_type = 'MANUAL')
   AND NOT (calculation_type = 'MANUAL' AND is_manual = 1 AND is_slab = 0 AND formula_expression IS NULL
            AND COALESCE(percentage_base, 'NONE') = 'NONE' AND COALESCE(percentage_value, 0) = 0)$$

-- slabs (only when active slabs exist: that is when the engine uses them)
UPDATE salary_component_master m
   SET m.calculation_type = 'FIXED', m.formula_expression = NULL,
       m.percentage_base = 'NONE', m.percentage_value = 0
 WHERE m.calculation_scope = 'COMPONENT' AND m.is_manual = 0 AND m.is_slab = 1
   AND EXISTS (SELECT 1 FROM salary_component_slab s WHERE s.component_id = m.component_id AND s.is_active = 1)
   AND NOT (m.calculation_type = 'FIXED' AND m.formula_expression IS NULL
            AND COALESCE(m.percentage_base, 'NONE') = 'NONE' AND COALESCE(m.percentage_value, 0) = 0)$$

-- STATUTORY is a formula
UPDATE salary_component_master
   SET calculation_type = 'FORMULA'
 WHERE calculation_scope = 'COMPONENT' AND calculation_type = 'STATUTORY'$$

-- percentage / fixed: the formula text was never used
UPDATE salary_component_master
   SET formula_expression = NULL
 WHERE calculation_scope = 'COMPONENT' AND calculation_type IN ('PERCENTAGE', 'FIXED')
   AND formula_expression IS NOT NULL$$
UPDATE salary_component_master
   SET percentage_base = 'NONE'
 WHERE calculation_scope = 'COMPONENT' AND calculation_type = 'FIXED'
   AND COALESCE(percentage_base, 'NONE') <> 'NONE'$$

-- formula: the percentage was never used
UPDATE salary_component_master
   SET percentage_value = 0, percentage_base = 'NONE'
 WHERE calculation_scope = 'COMPONENT' AND calculation_type = 'FORMULA'
   AND (COALESCE(percentage_value, 0) <> 0 OR COALESCE(percentage_base, 'NONE') <> 'NONE')$$

-- employee rows that follow the company rule show the same settings
UPDATE employee_salary_structure ess
  JOIN salary_component_master m ON m.component_id = ess.component_id
   SET ess.calculation_type   = CASE WHEN m.calculation_type = 'STATUTORY' THEN 'MANUAL' ELSE m.calculation_type END,
       ess.component_value    = COALESCE(m.percentage_value, 0),
       ess.percentage_base    = COALESCE(m.percentage_base, 'NONE'),
       ess.formula_expression = m.formula_expression
 WHERE ess.is_overridden = 0
   AND (ess.calculation_type <> CASE WHEN m.calculation_type = 'STATUTORY' THEN 'MANUAL' ELSE m.calculation_type END
        OR ess.component_value <> COALESCE(m.percentage_value, 0)
        OR COALESCE(ess.percentage_base, 'NONE') <> COALESCE(m.percentage_base, 'NONE')
        OR NOT (ess.formula_expression <=> m.formula_expression))$$

-- ---------------------------------------------------------------------
-- P1-003  hrms_component_method : the one calculation method of a component
--   TOTAL    a total (AGGREGATE), always a formula
--   MONTHLY  amount entered every month (manual)
--   SLAB     taken from the slab table
--   PERCENT  value % of a base
--   FIXED    a fixed amount
--   FORMULA  a formula
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS hrms_component_method$$
CREATE FUNCTION hrms_component_method(p_component_id BIGINT) RETURNS VARCHAR(10)
READS SQL DATA
BEGIN
    DECLARE v_method VARCHAR(10);
    SELECT CASE
             WHEN m.calculation_scope = 'AGGREGATE' THEN 'TOTAL'
             WHEN m.is_manual = 1 OR m.calculation_type = 'MANUAL' THEN 'MONTHLY'
             WHEN m.is_slab = 1 THEN 'SLAB'
             WHEN m.calculation_type = 'PERCENTAGE' THEN 'PERCENT'
             WHEN m.calculation_type = 'FIXED' THEN 'FIXED'
             ELSE 'FORMULA'
           END
      INTO v_method
      FROM salary_component_master m
     WHERE m.component_id = p_component_id;
    RETURN v_method;
END$$

-- ---------------------------------------------------------------------
-- P1-004  hrms_component_get : one component for the add / edit page
--         (every column of salary_component_master, so later phases'
--         columns come with it), its method and its slab count.
--         p_component_id NULL = nothing to load (new component).
--         Who may call: active ADMIN or HR.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_get$$
CREATE PROCEDURE hrms_component_get(IN p_emp_id VARCHAR(20), IN p_component_id BIGINT)
cg: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can manage salary components.' AS remarks;
        LEAVE cg;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM salary_component_master WHERE component_id = p_component_id) THEN
        SELECT 'N' AS status, 'Salary component not found.' AS remarks;
        LEAVE cg;
    END IF;
    SELECT 'Y' AS status, '' AS remarks,
           hrms_component_method(m.component_id) AS method,
           (SELECT COUNT(*) FROM salary_component_slab s WHERE s.component_id = m.component_id AND s.is_active = 1) AS slab_count,
           (SELECT COUNT(*) FROM employee_salary_structure e WHERE e.component_id = m.component_id) AS employee_rows,
           m.*
      FROM salary_component_master m
     WHERE m.component_id = p_component_id;
END$$

-- ---------------------------------------------------------------------
-- P1-005  hrms_formula_names : every name a formula, a percentage base, a
--         slab or a condition can use, for the page's insert buttons.
--           kind = VARIABLE  built-in name (CTC, CTC1, PAYABLE_DAYS ...)
--                  TOTAL     a total component (GROSS, NET_PAY ...)
--                  COMPONENT a pay component
--           data_type = NUMBER or FLAG (FLAG = 1 / 0, usable in
--                       "Applies only when")
--         Phase 2 replaces the fixed variable list with the
--         payroll_variables table.
--         Who may call: active ADMIN or HR.
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
            SELECT 'VARIABLE' AS kind, v.code, v.label, v.data_type, NULL AS component_type,
                   NULL AS component_id, 0 AS calculation_order, 1 AS is_active, v.sort_order
              FROM (          SELECT 'CTC' AS code, 'Monthly CTC' AS label, 'NUMBER' AS data_type, 10 AS sort_order
                    UNION ALL SELECT 'CTC1', 'CTC earned in the month (CTC x pay days / 30)', 'NUMBER', 20
                    UNION ALL SELECT 'ANNUAL_CTC', 'Annual CTC', 'NUMBER', 30
                    UNION ALL SELECT 'PAY_DAYS', 'Days of a month (30)', 'NUMBER', 40
                    UNION ALL SELECT 'PAYABLE_DAYS', 'Paid days of the month', 'NUMBER', 50
                    UNION ALL SELECT 'LOP_DAYS', 'Unpaid (LOP) days', 'NUMBER', 60
                    UNION ALL SELECT 'ESI_WAGE', 'ESI wage of the month (= GROSS)', 'NUMBER', 70
                    UNION ALL SELECT 'STANDARD_ESI_WAGE', 'ESI wage of a full month', 'NUMBER', 80
                    UNION ALL SELECT 'MANUAL_AMOUNT', 'Amount entered for the month', 'NUMBER', 90
                    UNION ALL SELECT 'ESI_APPLICABLE', 'ESI applies to the employee (1 / 0)', 'FLAG', 100) v
            UNION ALL
            SELECT IF(m.calculation_scope = 'AGGREGATE', 'TOTAL', 'COMPONENT'), UPPER(m.component_code), m.component_name,
                   'NUMBER', m.component_type, m.component_id, m.calculation_order, m.is_active, 1000 + m.calculation_order
              FROM salary_component_master m
           ) x
     ORDER BY FIELD(x.kind, 'VARIABLE', 'COMPONENT', 'TOTAL'), x.sort_order, x.code;
END$$

-- ---------------------------------------------------------------------
-- P1-006  hrms_component_save : the new page saves through this.
--   p_method  FIXED    p_value = amount
--             PERCENT  p_value = %, p_base = what it is taken of
--             FORMULA  p_formula
--             SLAB     p_slab_json = the slabs (at least one)
--             MONTHLY  amount entered every month
--             (a total, p_scope = AGGREGATE, is always FORMULA)
--   The settings of the other methods are cleared, so a component never
--   keeps a rule the engine does not use. Everything else (checks, slabs,
--   adding to every salary, recalculation, audit, sending calculated
--   payroll cycles back, dry run) is done by hrms_update_component_master
--   (C-039), whose answer row is returned unchanged:
--   status, remarks, component_id, attached_structures,
--   employee_rows_changed, findings, impact.
--   p_component_id NULL = new component.
--   p_include_in_total 1 = put a new / changed component into the total
--   of its type (GROSS / TOTAL_DEDUCTIONS / TOTAL_EMPLOYER_CONTRIBUTION).
--   p_order NULL = automatic for a new component, unchanged otherwise.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_save$$
CREATE PROCEDURE hrms_component_save(
    IN p_emp_id           VARCHAR(20),
    IN p_component_id     BIGINT,
    IN p_code             VARCHAR(30),
    IN p_name             VARCHAR(100),
    IN p_type             VARCHAR(30),
    IN p_scope            VARCHAR(20),
    IN p_method           VARCHAR(10),
    IN p_value            DECIMAL(12,2),
    IN p_base             VARCHAR(40),
    IN p_formula          TEXT,
    IN p_min              DECIMAL(12,2),
    IN p_max              DECIMAL(12,2),
    IN p_eligibility      VARCHAR(50),
    IN p_rounding         INT,
    IN p_is_taxable       TINYINT,
    IN p_is_active        TINYINT,
    IN p_order            INT,
    IN p_include_in_total TINYINT,
    IN p_slab_json        LONGTEXT,
    IN p_dry_run          TINYINT
)
cs: BEGIN
    DECLARE v_scope   VARCHAR(20);
    DECLARE v_method  VARCHAR(10);
    DECLARE v_calc    VARCHAR(20);
    DECLARE v_base    VARCHAR(40) DEFAULT 'NONE';
    DECLARE v_value   DECIMAL(12,2) DEFAULT 0;
    DECLARE v_formula TEXT DEFAULT NULL;
    DECLARE v_slab    TINYINT DEFAULT 0;
    DECLARE v_manual  TINYINT DEFAULT 0;
    DECLARE v_slabs   LONGTEXT DEFAULT NULL;
    DECLARE v_elig    VARCHAR(50);
    DECLARE v_msg     VARCHAR(500) DEFAULT NULL;
    DECLARE v_has_slabs INT DEFAULT 0;

    SET v_scope   = UPPER(TRIM(COALESCE(NULLIF(TRIM(p_scope), ''), 'COMPONENT')));
    SET v_method  = UPPER(TRIM(COALESCE(p_method, '')));
    SET v_elig    = NULLIF(UPPER(TRIM(COALESCE(p_eligibility, ''))), '');
    IF v_scope = 'AGGREGATE' THEN
        SET v_method = 'FORMULA';
    END IF;
    IF p_component_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_has_slabs FROM salary_component_slab WHERE component_id = p_component_id;
    END IF;

    CASE v_method
        WHEN 'FIXED' THEN
            SET v_calc = 'FIXED', v_value = COALESCE(p_value, 0);
            IF p_value IS NULL THEN SET v_msg = 'Enter the fixed amount.'; END IF;
        WHEN 'PERCENT' THEN
            SET v_calc = 'PERCENTAGE', v_value = COALESCE(p_value, 0),
                v_base = UPPER(TRIM(COALESCE(NULLIF(TRIM(p_base), ''), 'NONE')));
            IF p_value IS NULL THEN
                SET v_msg = 'Enter the percentage.';
            ELSEIF v_base = 'NONE' THEN
                SET v_msg = 'Choose what the percentage is taken of.';
            END IF;
        WHEN 'FORMULA' THEN
            SET v_calc = 'FORMULA', v_formula = NULLIF(TRIM(COALESCE(p_formula, '')), '');
            IF v_formula IS NULL THEN SET v_msg = 'Enter the formula.'; END IF;
        WHEN 'SLAB' THEN
            SET v_calc = 'FIXED', v_slab = 1, v_slabs = p_slab_json;
            IF NULLIF(TRIM(COALESCE(p_slab_json, '')), '') IS NULL OR JSON_VALID(p_slab_json) = 0
               OR COALESCE(JSON_LENGTH(p_slab_json), 0) = 0 THEN
                SET v_msg = 'Add at least one slab.';
            END IF;
        WHEN 'MONTHLY' THEN
            SET v_calc = 'MANUAL', v_manual = 1;
        ELSE
            SET v_msg = 'Choose how the component is calculated: fixed, percent, formula, slabs or monthly entry.';
    END CASE;

    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks, p_component_id AS component_id,
               0 AS attached_structures, 0 AS employee_rows_changed, NULL AS findings, NULL AS impact;
        LEAVE cs;
    END IF;

    -- leaving slabs: remove the slabs it had
    IF v_slab = 0 AND v_has_slabs > 0 THEN
        SET v_slabs = '[]';
    END IF;

    CALL hrms_update_component_master(
        p_emp_id,
        IF(p_component_id IS NULL, 'INSERT', 'UPDATE'),
        p_component_id,
        p_code, p_name, p_type,
        v_calc, v_base, v_value,
        COALESCE(p_is_taxable, 0), COALESCE(p_is_active, 1),
        v_formula, p_min, p_max,
        v_scope, p_order,
        IF(v_scope = 'AGGREGATE', NULL, v_elig), IF(v_scope = 'AGGREGATE' OR v_elig IS NULL, NULL, 'Y'),
        v_slab, p_rounding, v_manual, v_slabs,
        COALESCE(p_dry_run, 0),
        IF(v_scope = 'AGGREGATE', 0, COALESCE(p_include_in_total, 0)));
END$$

-- ---------------------------------------------------------------------
-- P1-007  hrms_component_set_flags : flags kept next to the component,
--         set by the page after a successful save.
--           p_is_statutory      1 = statutory (PF, ESI, PT ...): a label
--           p_include_in_total  used from phase 3 (ignored here)
--           p_is_balancing      used from phase 3 (ignored here)
--         Who may call: active ADMIN or HR.
--         Returns: status, remarks.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_set_flags$$
CREATE PROCEDURE hrms_component_set_flags(
    IN p_emp_id           VARCHAR(20),
    IN p_component_id     BIGINT,
    IN p_is_statutory     TINYINT,
    IN p_include_in_total TINYINT,
    IN p_is_balancing     TINYINT
)
sf: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can manage salary components.' AS remarks;
        LEAVE sf;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM salary_component_master WHERE component_id = p_component_id) THEN
        SELECT 'N' AS status, 'Salary component not found.' AS remarks;
        LEAVE sf;
    END IF;
    UPDATE salary_component_master
       SET is_statutory = IF(COALESCE(p_is_statutory, 0) = 1, 1, 0)
     WHERE component_id = p_component_id;
    SELECT 'Y' AS status, 'Flags saved.' AS remarks;
END$$

-- ---------------------------------------------------------------------
-- P1-008  every salary recalculated after P1-002 (amounts stay the same;
--         stops with an error if any salary cannot be calculated)
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
