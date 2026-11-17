-- =====================================================================
-- script.sql : HRMS payroll - dynamic salary components, slabs and
--              salary calculation
--
-- Database : production_hrms_db (MySQL 8). Written to also run on MariaDB 10.6+
--            (tested on MySQL 8 only).
-- Run with : mysql --default-character-set=utf8mb4 -u root -p production_hrms_db < script.sql
--            (utf8mb4 matters: from a Windows console the default is cp850,
--            and procedures keep the connection character set of their text)
-- Re-run   : safe. Every table change checks whether it is already applied;
--            procedures are dropped and created again; the data load (C-044)
--            runs only once.
-- Undo     : script_backup_original_procedures.sql restores the replaced
--            procedures. C-044 keeps the previous components and employee
--            amounts in salary_component_master_bak_step2 and
--            employee_salary_structure_bak_step2.
--
-- CHANGE INDEX
--   ID     TYPE              OBJECT
--   C-000  HELPER            hrms_script_* (temporary, dropped at the end)
--   C-001  ALTER TABLE       salary_component_master
--   C-002  NEW TABLE         salary_component_slab
--   C-003  ALTER TABLE       salary_structure
--   C-004  ALTER TABLE       employee_salary_structure
--   C-005  ALTER TABLE       employee_payroll_component_details
--   C-006  DATA              calculation_order of the existing components.
--   C-010  NEW PROCEDURE     hrms_formula_evaluate
--   C-013  NEW PROCEDURE     hrms_component_dependents
--   C-015  NEW PROCEDURE     hrms_formula_validate
--   C-016  NEW PROCEDURE     hrms_slab_resolve
--   C-019  NEW PROCEDURE     hrms_attach_component
--   C-022  NEW PROCEDURE     hrms_component_slab_list
--   C-025  ALTER TABLE       salary_component_master
--   C-026  NEW TABLE         employee_salary_structure_totals
--   C-027  NEW TABLE         payroll_manual_inputs
--   C-028  ALTER TABLE       payroll_runs
--   C-029  NEW PROCEDURE     hrms_engine_prepare
--   C-030  NEW PROCEDURE     hrms_engine_refresh_totals
--   C-031  NEW PROCEDURE     hrms_engine_load_vars
--   C-032  NEW PROCEDURE     hrms_formula_check
--   C-033  NEW PROCEDURE     hrms_engine_run
--   C-034  NEW PROCEDURE     hrms_calculate_structure
--   C-035  NEW PROCEDURE     hrms_recalculate_all_structures
--   C-036  NEW PROCEDURE     hrms_component_slab_apply
--   C-037  NEW PROCEDURE     hrms_component_slab_save
--   C-038  NEW PROCEDURE     hrms_component_slab_delete
--   C-039  UPDATE PROCEDURE  hrms_update_component_master
--   C-040  UPDATE PROCEDURE  hrms_get_salary_components
--   C-041  NEW PROCEDURE     hrms_calculate_payroll_detail
--   C-042  NEW PROCEDURE     hrms_calculate_payroll_run
--   C-043  NEW PROCEDURE     hrms_save_payroll_manual_input
--   C-044  DATA              load the new component set and its slabs
--   C-045  UPDATE PROCEDURE  hrms_create_payroll_cycle_complete
--   C-046  ALTER TABLE       payroll_cycles
--   C-047  ALTER TABLE       employee_payroll_details
--   C-048  NEW TABLE         payroll_cycle_status_log
--   C-049  NEW PROCEDURE     hrms_payroll_check_admin (removed by C-115)
--   C-050  NEW FUNCTION      hrms_payroll_cycle_actions
--   C-051  NEW PROCEDURE     hrms_payroll_load_cycle_emps
--   C-052  NEW PROCEDURE     hrms_payroll_log
--   C-053  NEW PROCEDURE     hrms_payroll_refresh_run_totals
--   C-054  NEW PROCEDURE     hrms_payroll_generate_payslips
--   C-055  NEW PROCEDURE     hrms_payroll_cycle_defaults
--   C-056  NEW PROCEDURE     hrms_payroll_cycle_create
--   C-057  NEW PROCEDURE     hrms_payroll_cycle_list
--   C-058  NEW PROCEDURE     hrms_payroll_cycle_get
--   C-059  NEW PROCEDURE     hrms_payroll_cycle_readiness
--   C-060  NEW PROCEDURE     hrms_payroll_cycle_employees
--   C-061  NEW PROCEDURE     hrms_payroll_prepare_run
--   C-062  NEW PROCEDURE     hrms_payroll_cycle_action
--   C-063  NEW PROCEDURE     hrms_payroll_calculate_employee
--   C-064  NEW PROCEDURE     hrms_payroll_employee_hold
--   C-065  NEW PROCEDURE     hrms_payroll_employee_pay
--   C-066  NEW PROCEDURE     hrms_payroll_cycle_log_list
--   C-067  UPDATE PROCEDURE  hrms_save_payroll_manual_input
--   C-068  NEW PROCEDURE     hrms_payroll_manual_inputs_list
--   C-069  UPDATE PROCEDURE  hrms_manage_payroll_status
--   C-070  UPDATE PROCEDURE  hrms_generate_employee_payslips
--   C-071  UPDATE PROCEDURE  hrms_update_employee_salary_component
--   C-072  UPDATE PROCEDURE  hrms_update_salary_structure
--   C-074  NEW PROCEDURE     hrms_preview_employee_salary
--   C-075  DATA              salary of BS00001 before November 2026
--   C-076  NEW PROCEDURE     hrms_payroll_cycle_delete
--   C-077  NEW PROCEDURE     hrms_payroll_cycle_breakdown
--   C-078  NEW PROCEDURE     hrms_salary_periods
--   C-079  NEW PROCEDURE     hrms_salary_components_for_structure
--   C-080  NEW PROCEDURE     hrms_save_employee_salary
--   C-081  NEW PROCEDURE     hrms_employees_without_salary
--   C-082  NEW PROCEDURE     hrms_salary_attach_all
--   C-083  NEW PROCEDURE     hrms_preview_new_salary
--   C-084  NEW PROCEDURE     hrms_create_employee_salary
--   C-073  UPDATE PROCEDURE  hrms_get_payslip
--   C-085  NEW FUNCTION      hrms_esi_wage_limit
--   C-086  NEW PROCEDURE     hrms_employee_payslip_list
--   C-087  UPDATE PROCEDURE  hrms_get_payslip: paid CTC   (inside C-073)
--   C-088  ALTER TABLE       employee_payslips: duplicate removed, unique key
--   C-089  UPDATE PROCEDURE  hrms_payroll_generate_payslips (inside C-054)
--   C-090  DATA              missing payslips of paid employees (Feb 2026)
--   C-091  UPDATE PROCEDURE  hrms_payroll_cycle_create: no month earlier
--                            than the last closed cycle    (inside C-056;
--                            removed again by C-125)
--   C-092  NEW PROCEDURE     hrms_salary_esi_review
--   -- component rules: checked before saving, every salary on its own date --
--   C-093  DATA              statutory slabs valid from 01 Apr 2025 (March 2026)
--   C-094  DATA              OTHERS uses TOTAL_EMPLOYER_CONTRIBUTION
--   C-095  UPDATE            no slab valid on the date = error; slab gaps
--                            reported  (inside C-016, C-029, C-033)
--   C-096  NEW FUNCTION      hrms_structure_calc_date; every salary period
--                            on its own date (inside C-035; C-071 C-072
--                            C-074 C-083 use it)
--   C-097  UPDATE            only active components in formulas, bases and
--                            slabs  (inside C-032, C-036, C-039)
--   C-098  UPDATE PROCEDURE  hrms_component_slab_apply: overlapping slabs
--                            allowed, priority decides  (inside C-036)
--   C-100  NEW PROCEDURE     hrms_component_rules_check  (the rule checker)
--   C-101  NEW PROCEDURE     hrms_component_change_finish  (check, recalc,
--                            impact)
--   C-102  NEW PROCEDURE     hrms_component_cycle_guard
--   C-104  UPDATE PROCEDURE  hrms_update_component_master: add to total,
--                            findings, impact  (inside C-039)
--   C-105  UPDATE PROCEDURE  hrms_component_slab_save / _delete use C-101
--                            (inside C-037, C-038)
--   -- calculation order and totals --
--   C-106  NEW FUNCTION      hrms_free_order; automatic order of a new
--                            component (inside C-039)
--   C-107  UPDATE PROCEDURE  hrms_component_rules_check: total rules,
--                            suggestions the right way (inside C-100)
--   C-108  ALTER TABLE       employee_payroll_component_details:
--                            calculation_scope, calculation_order
--   C-109  UPDATE PROCEDURE  hrms_calculate_payroll_detail stores the totals
--                            (inside C-041)
--   C-110  DATA              totals of the months already calculated
--   C-111  UPDATE PROCEDURE  hrms_get_payslip: totals column (inside C-073)
--   C-112  UPDATE PROCEDURE  hrms_get_payroll_month_details: totals column
--   C-113  NEW FUNCTION      hrms_pay_days: 30 - unpaid days (used in C-045,
--                            C-061, C-063)
--   C-114  UPDATE PROCEDURE  hrms_payroll_cycle_action: attendance must add up
--                            (inside C-062)
--   -- who may run payroll: active ADMIN or HR from user_login_details,
--   --   checked inside every procedure the pages call --
--   C-115  UPDATE            24 payroll procedures check user_login_details
--                            themselves; helper hrms_payroll_check_admin removed
--   C-116  UPDATE            standard check in C-040, C-055 (+ p_emp_id), C-073,
--                            C-086, C-112
--   C-117  UPDATE PROCEDURE  hrms_get_employee_salary_structure
--   C-118  UPDATE PROCEDURE  finalize_payroll_attendance_proc
--   C-119  UPDATE PROCEDURE  sp_generate_payroll_attendance
--   C-120  UPDATE PROCEDURE  sp_admin_edit_absent_attendance (had no check)
--   C-121  UPDATE PROCEDURE  get_payroll_attendance_data_proc (HR allowed)
--   C-122  UPDATE PROCEDURE  sp_get_payroll_cycle_status (+ p_emp_id)
--   C-123  UPDATE PROCEDURE  sp_get_payroll_finalization_status (+ p_emp_id)
--   C-124  NEW PROCEDURE     hrms_component_rules_view
--   C-125  UPDATE PROCEDURE  hrms_payroll_cycle_create: any month can be created
--                            (C-091 removed), so a deleted or missed month can be
--                            created again; refused only if that month already
--                            has a cycle, the code is taken or the period
--                            overlaps (inside C-056)
--   -- payroll audit trail: who changed what, when, before / after --
--   C-126  NEW TABLE         hrms_payroll_audit
--   C-127  NEW PROCEDURE     hrms_payroll_audit_add (internal)
--   C-128  NEW FUNCTION      hrms_audit_component_json / _salary_json /
--                            _attendance_json (snapshots)
--   C-129  NEW PROCEDURE     hrms_payroll_audit_event (payslip download,
--                            access denied)
--   C-130  NEW PROCEDURE     hrms_payroll_audit_list (Payroll Audit Log page)
--   C-131  UPDATE PROCEDURE  component / slab changes are audited
--                            (inside C-037, C-038, C-039)
--   C-132  UPDATE PROCEDURE  salary create / edit / CTC revise / own settings
--                            are audited (inside C-071, C-072, C-080, C-084)
--   C-133  UPDATE PROCEDURE  manual amounts are audited (inside C-067)
--   C-134  UPDATE PROCEDURE  attendance generate / finalize / absence edit are
--                            audited (inside C-118, C-119, C-120)
--
-- NAMES A FORMULA OR A SLAB CAN USE
--   - any component code. Totals (GROSS, TOTAL_DEDUCTIONS, NET_PAY ...) are
--     components too, with scope AGGREGATE and their own formula
--   - CTC               monthly CTC of the salary structure
--   - CTC1              CTC earned in the month = CTC x payable days / 30
--                       payable days = 30 - unpaid (LOP) days (C-113), so a full
--                       month is paid in full whatever the length of the period
--                       (equal to CTC when a full month is calculated)
--   - ANNUAL_CTC, PAY_DAYS (30), PAYABLE_DAYS, LOP_DAYS
--   - ESI_APPLICABLE    1 / 0 from salary_structure.esi_applicable
--   - ESI_WAGE          GROSS of the month being calculated
--   - STANDARD_ESI_WAGE GROSS of a full month
--   - MANUAL_AMOUNT     the amount entered by hand for the component
--   Allowed in a formula: numbers, + - * / ( ) , < > = !  and the functions
--   ROUND LEAST GREATEST IF CEIL FLOOR ABS AND OR NOT
--
-- HOW ONE EMPLOYEE IS CALCULATED (C-033)
--   Components are taken in calculation_order (lowest first):
--     1. manual component  -> the entered amount
--     2. eligibility       -> EMPLOYEE_ESI_ELIGIBLE needs esi_applicable = Y,
--                             otherwise the amount is 0
--     3. slab component    -> the slab with the lowest priority number whose
--                             range contains the "based on" value
--     4. FORMULA/STATUTORY -> the formula;  PERCENTAGE -> value % of "based on";
--        FIXED -> the value
--     5. minimum / maximum, then rounding
--   The pass is repeated until no amount changes, so components that refer
--   to each other in a circle (OTHERS uses EMP_ESI, EMP_ESI uses GROSS, GROSS
--   uses OTHERS) settle on one answer without any rule written in code.
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- C-000  HELPER  (temporary procedures used only by this script)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_script_add_column$$
CREATE PROCEDURE hrms_script_add_column(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_definition VARCHAR(500))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = p_table AND column_name = p_column) THEN
        SET @hrms_script_sql = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN `', p_column, '` ', p_definition);
        PREPARE hrms_script_stmt FROM @hrms_script_sql;
        EXECUTE hrms_script_stmt;
        DEALLOCATE PREPARE hrms_script_stmt;
    END IF;
END$$

DROP PROCEDURE IF EXISTS hrms_script_modify_column$$
CREATE PROCEDURE hrms_script_modify_column(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_skip_if_type VARCHAR(500), IN p_definition VARCHAR(500))
BEGIN
    -- Runs the MODIFY only while the column does not yet have the wanted type.
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = DATABASE() AND table_name = p_table AND column_name = p_column
                 AND LOWER(column_type) <> LOWER(p_skip_if_type)) THEN
        SET @hrms_script_sql = CONCAT('ALTER TABLE `', p_table, '` MODIFY COLUMN `', p_column, '` ', p_definition);
        PREPARE hrms_script_stmt FROM @hrms_script_sql;
        EXECUTE hrms_script_stmt;
        DEALLOCATE PREPARE hrms_script_stmt;
    END IF;
END$$

DROP PROCEDURE IF EXISTS hrms_script_add_index$$
CREATE PROCEDURE hrms_script_add_index(IN p_table VARCHAR(64), IN p_index VARCHAR(64), IN p_ddl VARCHAR(500))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.statistics
                   WHERE table_schema = DATABASE() AND table_name = p_table AND index_name = p_index) THEN
        SET @hrms_script_sql = p_ddl;
        PREPARE hrms_script_stmt FROM @hrms_script_sql;
        EXECUTE hrms_script_stmt;
        DEALLOCATE PREPARE hrms_script_stmt;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-001  ALTER TABLE salary_component_master
--        New columns use the same names as test_table_salary_component_master.
--        percentage_base becomes a component code (was a fixed list of 4).
--        percentage_value is widened so a FIXED amount above 99,999.99 fits.
-- ---------------------------------------------------------------------
CALL hrms_script_add_column('salary_component_master', 'formula_expression',         'TEXT NULL AFTER `percentage_value`')$$
CALL hrms_script_add_column('salary_component_master', 'minimum_amount',             'DECIMAL(12,2) NULL AFTER `formula_expression`')$$
CALL hrms_script_add_column('salary_component_master', 'maximum_amount',             'DECIMAL(12,2) NULL AFTER `minimum_amount`')$$
CALL hrms_script_add_column('salary_component_master', 'calculation_scope',          'ENUM(''COMPONENT'',''AGGREGATE'') NOT NULL DEFAULT ''COMPONENT''')$$
CALL hrms_script_add_column('salary_component_master', 'calculation_order',          'INT NOT NULL DEFAULT 100')$$
CALL hrms_script_add_column('salary_component_master', 'eligibility_parameter',      'VARCHAR(50) NULL')$$
CALL hrms_script_add_column('salary_component_master', 'eligibility_required_value', 'VARCHAR(10) NULL')$$
CALL hrms_script_add_column('salary_component_master', 'is_slab',                    'TINYINT(1) NOT NULL DEFAULT 0')$$
CALL hrms_script_add_column('salary_component_master', 'rounding_precision',         'INT NOT NULL DEFAULT 2')$$
CALL hrms_script_modify_column('salary_component_master', 'percentage_base',  'varchar(30)',   'VARCHAR(30) NULL DEFAULT ''NONE''')$$
CALL hrms_script_modify_column('salary_component_master', 'percentage_value', 'decimal(12,2)', 'DECIMAL(12,2) NULL DEFAULT 0.00')$$
CALL hrms_script_add_index('salary_component_master', 'idx_scm_calc_order',
     'ALTER TABLE `salary_component_master` ADD INDEX `idx_scm_calc_order` (`calculation_order`)')$$

-- ---------------------------------------------------------------------
-- C-002  NEW TABLE salary_component_slab  (live copy of the test slab design)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `salary_component_slab` (
    `slab_id`         BIGINT NOT NULL AUTO_INCREMENT,
    `component_id`    BIGINT NOT NULL,
    `slab_based_on`   VARCHAR(30) NOT NULL,
    `slab_min_value`  DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    `slab_max_value`  DECIMAL(12,2) NULL,
    `result_type`     ENUM('FIXED','PERCENTAGE') NOT NULL,
    `result_value`    DECIMAL(12,2) NOT NULL,
    `percentage_base` VARCHAR(30) NOT NULL DEFAULT 'NONE',
    `priority`        INT NOT NULL DEFAULT 1,
    `effective_from`  DATE NOT NULL,
    `effective_to`    DATE NULL,
    `is_active`       TINYINT(1) NOT NULL DEFAULT 1,
    `created_by`      VARCHAR(20) NULL,
    `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`slab_id`),
    UNIQUE KEY `uq_scs_component_priority` (`component_id`, `priority`),
    KEY `idx_scs_component` (`component_id`),
    KEY `idx_scs_effective` (`effective_from`, `effective_to`)
)$$

-- ---------------------------------------------------------------------
-- C-003  ALTER TABLE salary_structure : esi_applicable (Y/N, default N)
--        Values are copied once from test_salary_structure by emp_id,
--        only at the moment the column is created.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_script_c003$$
CREATE PROCEDURE hrms_script_c003()
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = 'salary_structure' AND column_name = 'esi_applicable') THEN
        ALTER TABLE `salary_structure`
            ADD COLUMN `esi_applicable` ENUM('Y','N') NOT NULL DEFAULT 'N' AFTER `structure_status`;
        IF EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = 'test_salary_structure' AND column_name = 'esi_applicable') THEN
            SET @hrms_script_sql =
                'UPDATE salary_structure ss
                   JOIN (SELECT emp_id, MAX(esi_applicable = ''Y'') AS is_y
                           FROM test_salary_structure
                          WHERE structure_status = ''ACTIVE''
                          GROUP BY emp_id) t ON t.emp_id = ss.emp_id
                    SET ss.esi_applicable = IF(t.is_y = 1, ''Y'', ''N'')';
            PREPARE hrms_script_stmt FROM @hrms_script_sql;
            EXECUTE hrms_script_stmt;
            DEALLOCATE PREPARE hrms_script_stmt;
        END IF;
    END IF;
END$$
CALL hrms_script_c003()$$
DROP PROCEDURE IF EXISTS hrms_script_c003$$

-- ---------------------------------------------------------------------
-- C-004  ALTER TABLE employee_salary_structure
--        One row per structure + component, and columns wide enough for
--        any "based on" code and a full formula.
-- ---------------------------------------------------------------------
CALL hrms_script_modify_column('employee_salary_structure', 'percentage_base',    'varchar(30)', 'VARCHAR(30) NULL DEFAULT ''NONE''')$$
CALL hrms_script_modify_column('employee_salary_structure', 'formula_expression', 'text',        'TEXT NULL')$$
CALL hrms_script_add_index('employee_salary_structure', 'uq_ess_structure_component',
     'ALTER TABLE `employee_salary_structure` ADD UNIQUE KEY `uq_ess_structure_component` (`structure_id`, `component_id`)')$$
CALL hrms_script_add_index('employee_salary_structure', 'idx_ess_component',
     'ALTER TABLE `employee_salary_structure` ADD INDEX `idx_ess_component` (`component_id`)')$$

-- ---------------------------------------------------------------------
-- C-005  ALTER TABLE employee_payroll_component_details
--        The payroll snapshot copies percentage_base / percentage_value /
--        formula_expression from the tables above, so it gets the same widths.
-- ---------------------------------------------------------------------
CALL hrms_script_modify_column('employee_payroll_component_details', 'percentage_base',    'varchar(30)',   'VARCHAR(30) NULL DEFAULT ''NONE''')$$
CALL hrms_script_modify_column('employee_payroll_component_details', 'percentage_value',   'decimal(12,2)', 'DECIMAL(12,2) NOT NULL DEFAULT 0.00')$$
CALL hrms_script_modify_column('employee_payroll_component_details', 'formula_expression', 'text',          'TEXT NULL')$$

-- ---------------------------------------------------------------------
-- C-006  DATA : calculation_order of the existing components.
--        Only rows still on the default (100) are touched. No amounts,
--        percentages or formulas are changed here.
-- ---------------------------------------------------------------------
UPDATE salary_component_master
   SET calculation_order = CASE UPPER(component_code)
        WHEN 'BASIC'           THEN 10
        WHEN 'HRA'             THEN 20
        WHEN 'CONVEYANCE'      THEN 30
        WHEN 'MEDICAL'         THEN 40
        WHEN 'SPECIAL'         THEN 50
        WHEN 'OTHER_EARNING'   THEN 60
        WHEN 'INCENTIVE'       THEN 70
        WHEN 'EMP_PF'          THEN 110
        WHEN 'EMP_ESI'         THEN 120
        WHEN 'PROF_TAX'        THEN 130
        WHEN 'TDS'             THEN 140
        WHEN 'OTHER_DEDUCTION' THEN 150
        WHEN 'LOP'             THEN 160
        WHEN 'ER_PF'           THEN 210
        WHEN 'ER_ESI'          THEN 220
        WHEN 'GRATUITY'        THEN 230
        ELSE 900
   END
 WHERE calculation_order = 100
   AND UPPER(component_code) IN ('BASIC','HRA','CONVEYANCE','MEDICAL','SPECIAL','OTHER_EARNING','INCENTIVE',
                                 'EMP_PF','EMP_ESI','PROF_TAX','TDS','OTHER_DEDUCTION','LOP',
                                 'ER_PF','ER_ESI','GRATUITY','TESTING')$$

-- ---------------------------------------------------------------------
-- C-010  NEW PROCEDURE hrms_formula_evaluate   (formula engine)
--   p_mode 'TOKENS' : only lists the names used, into tmp_hrms_formula_tokens
--   p_mode 'EVAL'   : replaces every name by its value from
--                     tmp_hrms_formula_vars and calculates the result
--   Names are replaced as whole words by a tokenizer, never by plain text
--   replace, and only the characters / functions listed at the top of this
--   file are accepted, so a formula cannot run any other SQL.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_formula_evaluate$$
CREATE PROCEDURE hrms_formula_evaluate(
    IN  p_formula TEXT,
    IN  p_mode    VARCHAR(10),
    OUT p_result  DECIMAL(18,4),
    OUT p_status  CHAR(1),
    OUT p_remarks VARCHAR(500)
)
fx: BEGIN
    DECLARE v_rest   TEXT;
    DECLARE v_out    TEXT DEFAULT '';
    DECLARE v_token  VARCHAR(64);
    DECLARE v_prefix TEXT;
    DECLARE v_pos    INT DEFAULT 0;
    DECLARE v_found  INT DEFAULT 0;
    DECLARE v_val    DECIMAL(18,4);
    DECLARE v_guard  INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_result  = NULL;
        SET p_status  = 'N';
        SET p_remarks = 'Formula is not valid. Check the brackets, operators, commas and function names.';
    END;

    SET p_result = NULL;
    SET p_status = 'N';
    SET p_remarks = '';
    DELETE FROM tmp_hrms_formula_tokens;

    SET v_rest = UPPER(TRIM(COALESCE(p_formula, '')));
    IF v_rest = '' THEN
        SET p_remarks = 'Formula is empty.';
        LEAVE fx;
    END IF;
    IF CHAR_LENGTH(v_rest) > 2000 THEN
        SET p_remarks = 'Formula is too long (maximum 2000 characters).';
        LEAVE fx;
    END IF;
    IF v_rest REGEXP '[^A-Z0-9_ .,()+*/<>=!\\-]' THEN
        SET p_remarks = 'Formula has characters that are not allowed. Use names, numbers, + - * / ( ) , < > = ! and the functions ROUND, LEAST, GREATEST, IF, CEIL, FLOOR, ABS.';
        LEAVE fx;
    END IF;
    IF LOCATE('--', v_rest) > 0 OR LOCATE('/*', v_rest) > 0 OR LOCATE('*/', v_rest) > 0 THEN
        SET p_remarks = 'Formula must not contain --, /* or */.';
        LEAVE fx;
    END IF;

    tok: LOOP
        SET v_guard = v_guard + 1;
        IF v_guard > 500 THEN
            SET p_remarks = 'Formula is too complex.';
            LEAVE fx;
        END IF;
        SET v_token = REGEXP_SUBSTR(v_rest, '[A-Z_][A-Z0-9_]*');
        IF v_token IS NULL OR v_token = '' THEN
            SET v_out = CONCAT(v_out, v_rest);
            LEAVE tok;
        END IF;
        SET v_pos    = LOCATE(v_token, v_rest);
        SET v_prefix = LEFT(v_rest, v_pos - 1);
        IF v_prefix REGEXP '[0-9.]$' THEN
            SET p_remarks = CONCAT('Formula is not valid near "', RIGHT(CONCAT(v_prefix, v_token), 25), '": a number is joined to a name.');
            LEAVE fx;
        END IF;
        SET v_rest = SUBSTRING(v_rest, v_pos + CHAR_LENGTH(v_token));

        IF v_token IN ('ROUND','LEAST','GREATEST','IF','CEIL','FLOOR','ABS','AND','OR','NOT') THEN
            SET v_out = CONCAT(v_out, v_prefix, v_token);
        ELSE
            INSERT IGNORE INTO tmp_hrms_formula_tokens (token) VALUES (v_token);
            IF p_mode = 'EVAL' THEN
                SELECT COUNT(*), MAX(var_value) INTO v_found, v_val
                  FROM tmp_hrms_formula_vars WHERE var_code = v_token;
                IF v_found = 0 THEN
                    SET p_remarks = CONCAT('Unknown name in formula: ', v_token);
                    LEAVE fx;
                END IF;
                SET v_out = CONCAT(v_out, v_prefix, '(', CAST(COALESCE(v_val, 0) AS CHAR), ')');
            ELSE
                SET v_out = CONCAT(v_out, v_prefix, '(1)');
            END IF;
        END IF;
    END LOOP tok;

    IF p_mode <> 'EVAL' THEN
        SET p_status = 'Y';
        LEAVE fx;
    END IF;

    SET @hrms_fx_result = NULL;
    SET @hrms_fx_sql = CONCAT('SELECT (', v_out, ') INTO @hrms_fx_result');
    PREPARE hrms_fx_stmt FROM @hrms_fx_sql;
    EXECUTE hrms_fx_stmt;
    DEALLOCATE PREPARE hrms_fx_stmt;

    IF @hrms_fx_result IS NULL THEN
        SET p_remarks = 'Formula gives no result (check for division by zero).';
        LEAVE fx;
    END IF;
    SET p_result = CAST(@hrms_fx_result AS DECIMAL(18,4));
    SET p_status = 'Y';
END$$

-- ---------------------------------------------------------------------
-- C-013  NEW PROCEDURE hrms_component_dependents
--        Lists the components whose calculation uses the given code
--        (as "based on", inside a formula, or in a slab).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_dependents$$
CREATE PROCEDURE hrms_component_dependents(
    IN  p_component_code       VARCHAR(30),
    IN  p_exclude_component_id BIGINT,
    IN  p_max_order            INT,
    IN  p_active_only          TINYINT,
    OUT p_list                 VARCHAR(500)
)
BEGIN
    DECLARE v_code VARCHAR(40);
    SET v_code = UPPER(TRIM(COALESCE(p_component_code, '')));
    SET p_list = NULL;

    SELECT LEFT(GROUP_CONCAT(CONCAT(UPPER(m.component_code), ' (order ', m.calculation_order, ')')
                             ORDER BY m.calculation_order SEPARATOR ', '), 500)
      INTO p_list
      FROM salary_component_master m
     WHERE (p_exclude_component_id IS NULL OR m.component_id <> p_exclude_component_id)
       AND (p_max_order IS NULL OR m.calculation_order <= p_max_order)
       AND (COALESCE(p_active_only, 0) = 0 OR m.is_active = 1)
       AND (
              (m.calculation_type = 'PERCENTAGE' AND UPPER(COALESCE(m.percentage_base, '')) = v_code)
           OR (m.calculation_type IN ('FORMULA', 'STATUTORY')
               AND m.formula_expression IS NOT NULL
               AND LOCATE(CONCAT(' ', v_code, ' '),
                          CONCAT(' ', REGEXP_REPLACE(UPPER(m.formula_expression), '[^A-Z0-9_]', ' '), ' ')) > 0)
           OR EXISTS (SELECT 1 FROM salary_component_slab s
                       WHERE s.component_id = m.component_id AND s.is_active = 1
                         AND (UPPER(s.slab_based_on) = v_code OR UPPER(COALESCE(s.percentage_base, '')) = v_code))
           );
END$$

-- ---------------------------------------------------------------------
-- C-015  NEW PROCEDURE hrms_formula_validate  (page button "Check formula")
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_formula_validate$$
CREATE PROCEDURE hrms_formula_validate(
    IN p_emp_id            VARCHAR(20),
    IN p_component_id      BIGINT,
    IN p_component_code    VARCHAR(30),
    IN p_calculation_order INT,
    IN p_formula           TEXT
)
BEGIN
    DECLARE v_role   VARCHAR(30);
    DECLARE v_ustat  VARCHAR(20);
    DECLARE v_st     CHAR(1) DEFAULT 'N';
    DECLARE v_rm     VARCHAR(500) DEFAULT '';
    DECLARE v_sample DECIMAL(18,4);
    DECLARE v_err    VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        SELECT 'N' AS status, COALESCE(v_err, 'Formula check failed.') AS remarks, NULL AS sample_result;
    END;

    SELECT MAX(user_category), MAX(status) INTO v_role, v_ustat
      FROM user_login_details WHERE emp_id = p_emp_id;

    IF v_role IS NULL OR LOWER(COALESCE(v_ustat, '')) <> 'active' OR UPPER(v_role) NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can check formulas.' AS remarks, NULL AS sample_result;
    ELSE
        CALL hrms_formula_check(p_component_id, p_component_code, COALESCE(p_calculation_order, 9999), p_formula, v_st, v_rm, v_sample);
        SELECT v_st AS status, v_rm AS remarks, ROUND(v_sample, 2) AS sample_result;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-016  NEW PROCEDURE hrms_slab_resolve   (slab priority engine)
--        Among the active slabs valid on p_on_date whose range contains
--        the "based on" value, the LOWEST priority number wins.
--        Uses the values loaded by hrms_engine_load_vars.
--        C-095: p_matched 1 = a slab applies; 2 = slabs are valid on the
--        date but the value is in none of their ranges (a gap, amount 0);
--        0 = no slab of the component is valid on the date at all.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_slab_resolve$$
CREATE PROCEDURE hrms_slab_resolve(
    IN  p_component_id BIGINT,
    IN  p_on_date      DATE,
    OUT p_amount       DECIMAL(18,4),
    OUT p_matched      TINYINT
)
BEGIN
    DECLARE v_slab_id BIGINT DEFAULT NULL;
    DECLARE v_type    VARCHAR(20);
    DECLARE v_value   DECIMAL(18,4);
    DECLARE v_pbase   VARCHAR(40);
    DECLARE v_base    DECIMAL(18,4);

    SET p_amount = 0;
    SET p_matched = 0;

    SELECT CAST(SUBSTRING_INDEX(GROUP_CONCAT(s.slab_id ORDER BY s.priority, s.slab_id), ',', 1) AS UNSIGNED)
      INTO v_slab_id
      FROM salary_component_slab s
      JOIN tmp_hrms_formula_vars v ON v.var_code = UPPER(s.slab_based_on)
     WHERE s.component_id = p_component_id
       AND s.is_active = 1
       AND s.effective_from <= p_on_date
       AND (s.effective_to IS NULL OR s.effective_to >= p_on_date)
       AND v.var_value >= s.slab_min_value
       AND (s.slab_max_value IS NULL OR v.var_value <= s.slab_max_value);

    IF v_slab_id IS NOT NULL THEN
        SELECT MAX(result_type), MAX(result_value), MAX(UPPER(percentage_base))
          INTO v_type, v_value, v_pbase
          FROM salary_component_slab WHERE slab_id = v_slab_id;
        SET p_matched = 1;
        IF v_type = 'PERCENTAGE' THEN
            SELECT COALESCE(MAX(var_value), 0) INTO v_base FROM tmp_hrms_formula_vars WHERE var_code = v_pbase;
            SET p_amount = v_base * v_value / 100;
        ELSE
            SET p_amount = v_value;
        END IF;
    ELSEIF EXISTS (SELECT 1 FROM salary_component_slab s
                    WHERE s.component_id = p_component_id AND s.is_active = 1
                      AND s.effective_from <= p_on_date
                      AND (s.effective_to IS NULL OR s.effective_to >= p_on_date)) THEN
        SET p_matched = 2;   -- C-095: value falls in a gap between the ranges
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-019  NEW PROCEDURE hrms_attach_component
--        Adds the component (p_component_id NULL = every active component)
--        to each ACTIVE salary structure that does not have it yet.
--        New rows start at amount 0; C-018 then calculates them.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_attach_component$$
CREATE PROCEDURE hrms_attach_component(
    IN  p_component_id BIGINT,
    OUT p_attached     INT
)
BEGIN
    INSERT INTO employee_salary_structure
        (structure_id, component_id, calculation_type, component_value, percentage_base,
         formula_expression, monthly_amount, is_overridden)
    SELECT ss.structure_id, m.component_id,
           CASE WHEN m.calculation_type = 'STATUTORY' THEN 'MANUAL' ELSE m.calculation_type END,
           COALESCE(m.percentage_value, 0),
           COALESCE(m.percentage_base, 'NONE'),
           m.formula_expression,
           0.00,
           0
      FROM salary_structure ss
      JOIN salary_component_master m
        ON m.is_active = 1
       AND m.calculation_scope = 'COMPONENT'
       AND (p_component_id IS NULL OR m.component_id = p_component_id)
     WHERE ss.structure_status = 'ACTIVE'
       AND NOT EXISTS (SELECT 1 FROM employee_salary_structure e
                        WHERE e.structure_id = ss.structure_id AND e.component_id = m.component_id);
    SET p_attached = ROW_COUNT();
END$$

-- ---------------------------------------------------------------------
-- C-022  NEW PROCEDURE hrms_component_slab_list
--        One row per slab. With no slabs, one row with slab_id NULL.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_slab_list$$
CREATE PROCEDURE hrms_component_slab_list(
    IN p_emp_id       VARCHAR(20),
    IN p_component_id BIGINT
)
BEGIN
    DECLARE v_role  VARCHAR(30);
    DECLARE v_ustat VARCHAR(20);
    DECLARE v_n     INT DEFAULT 0;

    SELECT MAX(user_category), MAX(status) INTO v_role, v_ustat
      FROM user_login_details WHERE emp_id = p_emp_id;
    SELECT COUNT(*) INTO v_n FROM salary_component_slab WHERE component_id = p_component_id;

    IF v_role IS NULL OR LOWER(COALESCE(v_ustat, '')) <> 'active' OR UPPER(v_role) NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view slabs.' AS remarks, NULL AS slab_id;
    ELSEIF v_n = 0 THEN
        SELECT 'Y' AS status, 'No slabs for this component.' AS remarks, NULL AS slab_id;
    ELSE
        SELECT 'Y' AS status, 'Slabs retrieved successfully' AS remarks,
               s.slab_id, s.component_id, s.priority, s.slab_based_on, s.slab_min_value, s.slab_max_value,
               s.result_type, s.result_value, s.percentage_base, s.effective_from, s.effective_to, s.is_active
          FROM salary_component_slab s
         WHERE s.component_id = p_component_id
         ORDER BY s.priority, s.slab_id;
    END IF;
END$$

-- =====================================================================
-- STEP 2 : complete dynamic salary calculation
--   - totals (GROSS, NET_PAY ...) are real components with their own formula
--   - components may refer to each other in a circle (OTHERS <-> EMP_ESI):
--     the engine repeats the calculation until the amounts stop changing
--   - a component and its slabs are saved together
--   - the pasted component set and slabs are loaded into the live tables
--   - the monthly payroll is calculated by the same engine
-- =====================================================================

-- ---------------------------------------------------------------------
-- C-025  ALTER TABLE salary_component_master : is_manual
--        1 = the amount is entered by hand (never calculated).
-- ---------------------------------------------------------------------
CALL hrms_script_add_column('salary_component_master', 'is_manual', 'TINYINT(1) NOT NULL DEFAULT 0')$$
UPDATE salary_component_master SET is_manual = 1 WHERE calculation_type = 'MANUAL' AND is_manual = 0$$

-- ---------------------------------------------------------------------
-- C-026  NEW TABLE employee_salary_structure_totals
--        Full-month value of every total (AGGREGATE) component per salary
--        structure. Totals are not rows of employee_salary_structure, so
--        they are never counted as an earning or a deduction.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `employee_salary_structure_totals` (
    `structure_id`   BIGINT NOT NULL,
    `component_id`   BIGINT NOT NULL,
    `monthly_amount` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`structure_id`, `component_id`)
)$$

-- ---------------------------------------------------------------------
-- C-027  NEW TABLE payroll_manual_inputs
--        Amount of a manual component (TDS, ADVANCE, OTHER_EARNINGS ...)
--        for one employee and one payroll month.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `payroll_manual_inputs` (
    `input_id`      BIGINT NOT NULL AUTO_INCREMENT,
    `emp_id`        VARCHAR(20) NOT NULL,
    `payroll_month` TINYINT NOT NULL,
    `payroll_year`  SMALLINT NOT NULL,
    `component_id`  BIGINT NOT NULL,
    `amount`        DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    `remarks`       VARCHAR(255) NULL,
    `created_by`    VARCHAR(20) NULL,
    `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`input_id`),
    UNIQUE KEY `uq_pmi_emp_period_component` (`emp_id`, `payroll_month`, `payroll_year`, `component_id`)
)$$

-- ---------------------------------------------------------------------
-- C-028  ALTER TABLE payroll_runs : put back the table the hrms_* payroll
--        procedures use (payroll_run_id, payroll_cycle_id, run_status ...).
--        It had been replaced by a table of another design, which broke
--        the payroll dashboard, payslips and cycle creation. That table is
--        kept as payroll_runs_engine_v2. The run rows of the existing
--        payroll history are rebuilt from payroll_cycles (same id, same
--        creation time).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_script_c028$$
CREATE PROCEDURE hrms_script_c028()
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = 'payroll_runs' AND column_name = 'payroll_cycle_id') THEN
        IF EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = DATABASE() AND table_name = 'payroll_runs') THEN
            RENAME TABLE `payroll_runs` TO `payroll_runs_engine_v2`;
        END IF;

        CREATE TABLE `payroll_runs` (
            `payroll_run_id`               BIGINT NOT NULL AUTO_INCREMENT,
            `payroll_cycle_id`             BIGINT NOT NULL,
            `run_number`                   INT NOT NULL DEFAULT 1,
            `run_type`                     VARCHAR(20) NOT NULL DEFAULT 'REGULAR',
            `run_status`                   VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
            `total_employees`              INT NOT NULL DEFAULT 0,
            `total_earnings`               DECIMAL(14,2) NOT NULL DEFAULT 0.00,
            `total_deductions`             DECIMAL(14,2) NOT NULL DEFAULT 0.00,
            `total_employer_contributions` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
            `total_net_pay`                DECIMAL(14,2) NOT NULL DEFAULT 0.00,
            `created_by`                   VARCHAR(50) NULL,
            `calculated_by`                VARCHAR(50) NULL,
            `calculated_at`                DATETIME NULL,
            `approved_by`                  VARCHAR(50) NULL,
            `approved_at`                  DATETIME NULL,
            `finalized_by`                 VARCHAR(50) NULL,
            `finalized_at`                 DATETIME NULL,
            `created_at`                   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at`                   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`payroll_run_id`),
            KEY `idx_payroll_runs_cycle` (`payroll_cycle_id`)
        );

        INSERT INTO payroll_runs
            (payroll_run_id, payroll_cycle_id, run_number, run_type, run_status, total_employees,
             total_earnings, total_deductions, total_employer_contributions, total_net_pay,
             created_by, calculated_by, calculated_at, approved_by, approved_at, finalized_by, finalized_at, created_at)
        SELECT d.payroll_run_id, c.payroll_cycle_id, 1, 'REGULAR',
               CASE WHEN c.cycle_status IN ('FINALIZED', 'PAID', 'CLOSED') THEN 'FINALIZED' ELSE 'APPROVED' END,
               d.employees, d.earnings, d.deductions, d.employer, d.net,
               c.created_by, c.created_by, c.created_at, c.created_by, c.created_at,
               c.finalized_by, c.finalized_at, c.created_at
          FROM (SELECT payroll_run_id, COUNT(*) AS employees, MIN(created_at) AS first_at,
                       SUM(gross_earnings) AS earnings, SUM(total_deductions) AS deductions,
                       SUM(employer_contributions) AS employer, SUM(net_pay) AS net
                  FROM employee_payroll_details
                 GROUP BY payroll_run_id) d
          JOIN payroll_cycles c
            ON c.payroll_cycle_id = d.payroll_run_id
           AND ABS(TIMESTAMPDIFF(SECOND, c.created_at, d.first_at)) <= 60;
    END IF;
END$$
CALL hrms_script_c028()$$
DROP PROCEDURE IF EXISTS hrms_script_c028$$

-- ---------------------------------------------------------------------
-- C-029  NEW PROCEDURE hrms_engine_prepare
--        Work tables of the engine (temporary, one set per connection).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_engine_prepare$$
CREATE PROCEDURE hrms_engine_prepare()
BEGIN
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hrms_formula_vars (
        var_code     VARCHAR(40) NOT NULL PRIMARY KEY,
        var_value    DECIMAL(18,4) NOT NULL DEFAULT 0,
        var_type     VARCHAR(30) NULL,
        var_scope    VARCHAR(20) NULL,
        var_order    INT NULL,
        component_id BIGINT NULL
    );
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hrms_formula_tokens (
        token VARCHAR(64) NOT NULL PRIMARY KEY
    );
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hrms_calc (
        cid         BIGINT NOT NULL PRIMARY KEY,
        ecid        BIGINT NULL,
        code        VARCHAR(40) NOT NULL,
        ctype       VARCHAR(30) NOT NULL,
        scope       VARCHAR(20) NOT NULL,
        calc_order  INT NOT NULL,
        eff_calc    VARCHAR(20) NOT NULL,
        eff_value   DECIMAL(18,4) NOT NULL DEFAULT 0,
        eff_base    VARCHAR(40) NOT NULL,
        eff_formula TEXT NULL,
        eff_slab    TINYINT NOT NULL DEFAULT 0,
        eff_manual  TINYINT NOT NULL DEFAULT 0,
        min_amt     DECIMAL(12,2) NULL,
        max_amt     DECIMAL(12,2) NULL,
        elig_param  VARCHAR(50) NULL,
        elig_value  VARCHAR(10) NULL,
        rounding    INT NOT NULL DEFAULT 2,
        stored_amt  DECIMAL(14,2) NOT NULL DEFAULT 0,
        manual_amt  DECIMAL(14,2) NOT NULL DEFAULT 0,
        overridden  TINYINT NOT NULL DEFAULT 0,
        new_amt     DECIMAL(18,4) NOT NULL DEFAULT 0
    );
    -- C-095: slab components whose value fell in a gap (last pass of one engine run)
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hrms_slab_gap (
        cid      BIGINT NOT NULL PRIMARY KEY,
        is_gap   TINYINT NOT NULL DEFAULT 0
    );
    -- C-095: the same, collected for every salary by hrms_recalculate_all_structures
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hrms_gap_list (
        structure_id BIGINT NOT NULL,
        cid          BIGINT NOT NULL,
        PRIMARY KEY (structure_id, cid)
    );
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hrms_struct_list (
        structure_id BIGINT NOT NULL PRIMARY KEY
    );
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hrms_detail_list (
        payroll_detail_id BIGINT NOT NULL PRIMARY KEY
    );
END$$

-- ---------------------------------------------------------------------
-- C-030  NEW PROCEDURE hrms_engine_refresh_totals
--        Keeps the built-in names up to date while components are being
--        calculated: ESI_WAGE (= GROSS), STANDARD_ESI_WAGE (= GROSS of a
--        full month), and the fallback totals GROSS / TOTAL_DEDUCTIONS /
--        TOTAL_EMPLOYER_CONTRIBUTION when no component has that code.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_engine_refresh_totals$$
CREATE PROCEDURE hrms_engine_refresh_totals(IN p_exclude_component_id BIGINT)
BEGIN
    DECLARE v_n     INT DEFAULT 0;
    DECLARE v_gross DECIMAL(18,4) DEFAULT 0;
    DECLARE v_ded   DECIMAL(18,4) DEFAULT 0;
    DECLARE v_er    DECIMAL(18,4) DEFAULT 0;
    DECLARE v_g     DECIMAL(18,4) DEFAULT 0;

    SELECT COUNT(*) INTO v_n FROM tmp_hrms_formula_vars WHERE var_type = 'BUILTIN_TOTAL';
    IF v_n > 0 THEN
        SELECT COALESCE(SUM(IF(var_type = 'EARNING', var_value, 0)), 0),
               COALESCE(SUM(IF(var_type = 'DEDUCTION', var_value, 0)), 0),
               COALESCE(SUM(IF(var_type = 'EMPLOYER_CONTRIBUTION', var_value, 0)), 0)
          INTO v_gross, v_ded, v_er
          FROM tmp_hrms_formula_vars
         WHERE var_scope = 'COMPONENT'
           AND (p_exclude_component_id IS NULL OR component_id <> p_exclude_component_id);
        UPDATE tmp_hrms_formula_vars
           SET var_value = CASE var_code WHEN 'GROSS' THEN v_gross
                                         WHEN 'TOTAL_DEDUCTIONS' THEN v_ded
                                         ELSE v_er END
         WHERE var_type = 'BUILTIN_TOTAL';
    END IF;

    SELECT COALESCE(MAX(var_value), 0) INTO v_g FROM tmp_hrms_formula_vars WHERE var_code = 'GROSS';
    UPDATE tmp_hrms_formula_vars
       SET var_value = v_g
     WHERE var_code = 'ESI_WAGE'
        OR (var_code = 'STANDARD_ESI_WAGE' AND var_scope = 'FOLLOW_GROSS');
END$$

-- ---------------------------------------------------------------------
-- C-031  NEW PROCEDURE hrms_engine_load_vars
--        Loads every name a formula or slab can use for one salary structure.
--        p_ctc1 NULL  -> full month  (CTC1 = monthly CTC, STANDARD_ESI_WAGE follows GROSS)
--        p_ctc1 given -> payroll month (CTC1 = earned CTC, STANDARD_ESI_WAGE =
--                        the full-month GROSS saved for the structure)
--        p_structure_id NULL -> sample values, used to test a formula.
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

    SELECT COUNT(*), COALESCE(MAX(monthly_ctc), 50000), COALESCE(MAX(annual_ctc), 600000), COALESCE(MAX(esi_applicable), 'N')
      INTO v_found, v_ctc, v_annual, v_esi
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
END$$

-- ---------------------------------------------------------------------
-- C-032  NEW PROCEDURE hrms_formula_check   (formula checking)
--        Rejects: bad syntax, forbidden characters, unknown names and a
--        component using itself. C-097: also inactive components. A name may be calculated later than the
--        component: such circles are settled by the engine (C-033) and
--        tested on every employee when the component is saved or checked.
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
     WHERE t.token NOT IN ('CTC','CTC1','ANNUAL_CTC','GROSS','TOTAL_DEDUCTIONS','TOTAL_EMPLOYER_CONTRIBUTION',
                           'ESI_APPLICABLE','PAY_DAYS','PAYABLE_DAYS','LOP_DAYS','MANUAL_AMOUNT','ESI_WAGE','STANDARD_ESI_WAGE')
       AND NOT EXISTS (SELECT 1 FROM salary_component_master m WHERE UPPER(m.component_code) = t.token);
    IF v_list IS NOT NULL THEN
        SET p_remarks = LEFT(CONCAT('Unknown name in formula: ', v_list,
            '. Use a component code or CTC, CTC1, GROSS, ESI_WAGE, STANDARD_ESI_WAGE, MANUAL_AMOUNT, PAYABLE_DAYS, LOP_DAYS.'), 500);
        LEAVE chk;
    END IF;

    -- C-097: an inactive component always counts as 0, so it cannot be used
    SELECT GROUP_CONCAT(t.token ORDER BY t.token SEPARATOR ', ') INTO v_list
      FROM tmp_hrms_formula_tokens t
     WHERE t.token NOT IN ('CTC','CTC1','ANNUAL_CTC','GROSS','TOTAL_DEDUCTIONS','TOTAL_EMPLOYER_CONTRIBUTION',
                           'ESI_APPLICABLE','PAY_DAYS','PAYABLE_DAYS','LOP_DAYS','MANUAL_AMOUNT','ESI_WAGE','STANDARD_ESI_WAGE')
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
-- C-033  NEW PROCEDURE hrms_engine_run   (the calculation engine)
--   Calculates every active component of one salary structure into
--   tmp_hrms_calc.new_amt. Nothing is written to real tables here.
--   One pass takes the components in calculation_order:
--     1. manual component        -> the entered amount
--     2. eligibility             -> EMPLOYEE_ESI_ELIGIBLE compares
--                                   salary_structure.esi_applicable; not eligible = 0
--     3. slab component          -> lowest priority slab whose range fits
--                                   (C-095: no slab valid on the date = error)
--     4. FORMULA / STATUTORY     -> the formula
--        PERCENTAGE              -> value % of the "based on" name
--        FIXED                   -> the value
--        (no rule)               -> the stored amount is kept
--     5. minimum / maximum, then rounding
--   Passes are repeated until no amount changes any more, so components
--   that depend on each other in a circle settle on one answer. More than
--   30 passes means the circle never settles and is reported as an error.
--   An employee row with is_overridden = 1 uses its own settings.
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
            ELSEIF TRIM(COALESCE(v_eparam, '')) <> ''
               AND UPPER(v_eparam) IN ('EMPLOYEE_ESI_ELIGIBLE', 'ESI_APPLICABLE')
               AND UPPER(v_esi) <> UPPER(COALESCE(NULLIF(TRIM(v_evalue), ''), 'Y')) THEN
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
-- C-034  NEW PROCEDURE hrms_calculate_structure
--        Runs the engine for a full month and saves the result:
--        components -> employee_salary_structure.monthly_amount
--        totals     -> employee_salary_structure_totals
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_calculate_structure$$
CREATE PROCEDURE hrms_calculate_structure(
    IN  p_structure_id BIGINT,
    IN  p_on_date      DATE,
    OUT p_rows_changed INT,
    OUT p_errors       INT,
    OUT p_error_text   VARCHAR(500)
)
BEGIN
    DECLARE v_passes INT DEFAULT 0;

    SET p_rows_changed = 0;
    CALL hrms_engine_run(p_structure_id, NULL, NULL, NULL, NULL, NULL, p_on_date, v_passes, p_errors, p_error_text);

    IF p_errors = 0 THEN
        UPDATE employee_salary_structure e
          JOIN tmp_hrms_calc c ON c.ecid = e.employee_component_id
           SET e.monthly_amount = ROUND(c.new_amt, 2)
         WHERE c.scope = 'COMPONENT'
           AND e.monthly_amount <> ROUND(c.new_amt, 2);
        SET p_rows_changed = ROW_COUNT();

        DELETE FROM employee_salary_structure_totals WHERE structure_id = p_structure_id;
        INSERT INTO employee_salary_structure_totals (structure_id, component_id, monthly_amount)
        SELECT p_structure_id, c.cid, ROUND(c.new_amt, 2)
          FROM tmp_hrms_calc c
         WHERE c.scope = 'AGGREGATE';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-035  NEW PROCEDURE hrms_recalculate_all_structures
--        Runs C-034 for every ACTIVE salary structure. Stops at the first
--        error and reports the employee and the reason.
--        C-096: each salary period is calculated on its own date
--        (hrms_structure_calc_date), not on today for every period, and
--        slab gaps are collected in tmp_hrms_gap_list.
-- ---------------------------------------------------------------------
-- C-096  NEW FUNCTION hrms_structure_calc_date
--        The date a salary period is calculated on: today while the period
--        runs, its last day once it has ended, its first day if it starts
--        later.
DROP FUNCTION IF EXISTS hrms_structure_calc_date$$
CREATE FUNCTION hrms_structure_calc_date(p_structure_id BIGINT) RETURNS DATE
READS SQL DATA
BEGIN
    DECLARE v_date DATE;
    SELECT GREATEST(effective_from, LEAST(CURDATE(), COALESCE(effective_to, CURDATE())))
      INTO v_date
      FROM salary_structure WHERE structure_id = p_structure_id;
    RETURN COALESCE(v_date, CURDATE());
END$$

DROP PROCEDURE IF EXISTS hrms_recalculate_component$$
DROP PROCEDURE IF EXISTS hrms_recalculate_all_structures$$
CREATE PROCEDURE hrms_recalculate_all_structures(
    OUT p_structures   INT,
    OUT p_rows_changed INT,
    OUT p_errors       INT,
    OUT p_error_text   VARCHAR(500)
)
BEGIN
    DECLARE v_done      INT DEFAULT 0;
    DECLARE v_structure BIGINT;
    DECLARE v_changed   INT DEFAULT 0;
    DECLARE v_err       INT DEFAULT 0;
    DECLARE v_text      VARCHAR(500);
    DECLARE v_emp       VARCHAR(20);
    DECLARE cur CURSOR FOR SELECT structure_id FROM tmp_hrms_struct_list ORDER BY structure_id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    SET p_structures = 0;
    SET p_rows_changed = 0;
    SET p_errors = 0;
    SET p_error_text = NULL;

    CALL hrms_engine_prepare();
    DELETE FROM tmp_hrms_struct_list;
    DELETE FROM tmp_hrms_gap_list;
    INSERT INTO tmp_hrms_struct_list (structure_id)
    SELECT structure_id FROM salary_structure WHERE structure_status = 'ACTIVE';

    OPEN cur;
    st: LOOP
        SET v_done = 0;
        FETCH cur INTO v_structure;
        IF v_done = 1 THEN
            LEAVE st;
        END IF;
        SET @hrms_calc_date = hrms_structure_calc_date(v_structure);   -- a function cannot sit inside CALL here
        CALL hrms_calculate_structure(v_structure, @hrms_calc_date, v_changed, v_err, v_text);
        INSERT IGNORE INTO tmp_hrms_gap_list (structure_id, cid)
        SELECT v_structure, cid FROM tmp_hrms_slab_gap WHERE is_gap = 1;
        IF v_err > 0 THEN
            SELECT COALESCE(MAX(emp_id), '?') INTO v_emp FROM salary_structure WHERE structure_id = v_structure;
            SET p_errors = v_err;
            SET p_error_text = LEFT(CONCAT('Employee ', v_emp, ' - ', COALESCE(v_text, 'calculation failed')), 500);
            LEAVE st;
        END IF;
        SET p_structures   = p_structures + 1;
        SET p_rows_changed = p_rows_changed + COALESCE(v_changed, 0);
    END LOOP st;
    CLOSE cur;
END$$

-- ---------------------------------------------------------------------
-- C-036  NEW PROCEDURE hrms_component_slab_apply   (internal)
--        Checks a JSON array of slabs and replaces the slabs of one
--        component. No transaction and no recalculation of its own: the
--        caller does both. p_msg NULL = saved.
--        Rejected: "from" above "to", two slabs with one priority, an
--        unknown or inactive base (C-097). C-098: overlapping ranges are
--        allowed - the lowest priority number wins where they overlap.
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
         WHERE t.based_on NOT IN ('CTC','CTC1','ANNUAL_CTC','GROSS','TOTAL_DEDUCTIONS','TOTAL_EMPLOYER_CONTRIBUTION','ESI_WAGE','STANDARD_ESI_WAGE')
           AND NOT EXISTS (SELECT 1 FROM salary_component_master m
                            WHERE UPPER(m.component_code) = t.based_on AND m.component_id <> p_component_id
                              AND m.is_active = 1);
    END IF;
    IF p_msg IS NULL THEN
        SELECT MIN(CONCAT('Slab ', t.row_no, ': percentage of "', t.pct_base, '" is not CTC, GROSS or an active component code.'))
          INTO p_msg
          FROM tmp_hrms_slab_in t
         WHERE t.result_type = 'PERCENTAGE'
           AND t.pct_base NOT IN ('CTC','CTC1','ANNUAL_CTC','GROSS','TOTAL_DEDUCTIONS','TOTAL_EMPLOYER_CONTRIBUTION','ESI_WAGE','STANDARD_ESI_WAGE')
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
-- C-037  NEW PROCEDURE hrms_component_slab_save
--        Replaces all slabs of one component, then recalculates every
--        employee. If any employee cannot be calculated nothing is saved.
--        C-105: ends in hrms_component_change_finish (rule checker, impact)
--        and sends calculated payroll cycles back; returns findings, impact.
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
    DECLARE v_audit_old  JSON DEFAULT NULL;    -- C-131
    DECLARE v_audit_new  JSON DEFAULT NULL;    -- C-131
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

    SET v_audit_old = hrms_audit_component_json(p_component_id);    -- C-131
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
    -- C-131: audit trail (component with its slabs, before / after)
    SET v_audit_new = hrms_audit_component_json(p_component_id);
    CALL hrms_payroll_audit_add('SLAB', IF(v_count = 0, 'SLABS_REMOVED', 'SLABS_SAVED'), 'salary_component_slab',
         p_component_id, NULL, NULL, NULL, NULL, v_audit_old, v_audit_new,
         CONCAT(JSON_UNQUOTE(JSON_EXTRACT(v_audit_new, '$.code')), ': ', v_count, ' slab(s) saved. Employee amounts changed: ',
                v_changed, '.'), p_emp_id);
    CALL hrms_component_cycle_guard(p_emp_id, 'Slabs changed', v_notice);
    COMMIT;
    SELECT 'Y' AS status,
           CONCAT(v_count, ' slab(s) saved. Employee amounts changed: ', v_changed, '.',
                  IF(v_notice IS NULL, '', CONCAT(' ', v_notice))) AS remarks,
           p_component_id AS component_id, v_count AS slab_count, v_changed AS employee_rows_changed,
           v_findings AS findings, v_impact AS impact;
END$$

-- ---------------------------------------------------------------------
-- C-038  NEW PROCEDURE hrms_component_slab_delete   (removes one slab)
--        C-105: ends in hrms_component_change_finish and the cycle guard.
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
    DECLARE v_audit_old  JSON DEFAULT NULL;    -- C-131
    DECLARE v_audit_new  JSON DEFAULT NULL;    -- C-131
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

    SET v_audit_old = hrms_audit_component_json(v_component);    -- C-131
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
    -- C-131: audit trail (component with its slabs, before / after)
    SET v_audit_new = hrms_audit_component_json(v_component);
    CALL hrms_payroll_audit_add('SLAB', 'SLAB_DELETED', 'salary_component_slab', p_slab_id, NULL, NULL, NULL, NULL,
         v_audit_old, v_audit_new,
         CONCAT(JSON_UNQUOTE(JSON_EXTRACT(v_audit_new, '$.code')), ': slab ', p_slab_id, ' deleted. Slabs left: ', v_left,
                '. Employee amounts changed: ', v_changed, '.'), p_emp_id);
    CALL hrms_component_cycle_guard(p_emp_id, 'A slab was deleted', v_notice);
    COMMIT;
    SELECT 'Y' AS status,
           CONCAT('Slab deleted. Slabs left: ', v_left, '. Employee amounts changed: ', v_changed, '.',
                  IF(v_notice IS NULL, '', CONCAT(' ', v_notice))) AS remarks,
           v_component AS component_id, v_left AS slab_count, v_changed AS employee_rows_changed,
           v_findings AS findings, v_impact AS impact;
END$$

-- ---------------------------------------------------------------------
-- C-039  UPDATE PROCEDURE hrms_update_component_master
--   The component page saves through this one procedure.
--   Parameters 1-20 are as before; three are added:
--     p_is_manual  1 = amount entered by hand
--     p_slab_json  NULL = leave the slabs as they are
--                  JSON array = replace the slabs ([] removes them)
--     p_dry_run    1 = check only: everything is validated and every
--                  employee is recalculated, then nothing is saved
--   INSERT : creates the component (+ slabs), adds it to every ACTIVE
--            salary structure and recalculates all employees.
--   UPDATE : saves the component (+ slabs) and recalculates all employees.
--   ACTIVE : switches the component on/off and recalculates.
--   If one employee cannot be calculated (bad formula, a circle that never
--   settles) the whole change is cancelled and the reason is returned.
--   Returns one row: status (Y/N), remarks, component_id,
--   attached_structures, employee_rows_changed.
--   C-104: p_add_to_total (24th) 1 = put a new / changed pay component into
--   the total of its type when it is not there yet (GROSS, TOTAL_DEDUCTIONS,
--   TOTAL_EMPLOYER_CONTRIBUTION; only when that total is a plain sum).
--   Every change now ends in hrms_component_change_finish (C-101): rule
--   checker, every salary recalculated on its own date, impact. A saved
--   change sends calculated payroll cycles back (C-102). Two more columns
--   are returned: findings (JSON) and impact (JSON).
--   C-106: a new active component with no calculation order gets one
--   automatically: after everything it uses and, for a pay component going
--   into its total, before that total (a new earning lands between the last
--   component and GROSS). A new total lands right after what it uses.
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
-- C-040  UPDATE PROCEDURE hrms_get_salary_components
--        Same output as before plus the engine columns, is_manual and
--        slab_count; listed in calculation order.
--        C-116: standard role check (active ADMIN or HR from user_login_details).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_get_salary_components$$
CREATE PROCEDURE hrms_get_salary_components(
    IN p_emp_id VARCHAR(20)
)
BEGIN
    DECLARE v_user_category VARCHAR(50) DEFAULT NULL;
    DECLARE v_user_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_user_found INT DEFAULT 0;
    DECLARE v_total_components INT DEFAULT 0;
    DECLARE v_earnings_count INT DEFAULT 0;
    DECLARE v_deductions_count INT DEFAULT 0;
    DECLARE v_employer_contribution_count INT DEFAULT 0;

    -- C-116: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view salary components.' AS remarks,
               0 AS total_components, 0 AS earnings_count, 0 AS deductions_count, 0 AS employer_contribution_count;
    ELSE
        SELECT COUNT(*),
               COALESCE(SUM(component_type = 'EARNING' AND calculation_scope = 'COMPONENT'), 0),
               COALESCE(SUM(component_type = 'DEDUCTION' AND calculation_scope = 'COMPONENT'), 0),
               COALESCE(SUM(component_type = 'EMPLOYER_CONTRIBUTION' AND calculation_scope = 'COMPONENT'), 0)
          INTO v_total_components, v_earnings_count, v_deductions_count, v_employer_contribution_count
          FROM salary_component_master;

        IF v_total_components = 0 THEN
            SELECT 'N' AS status, 'No active salary components found' AS remarks,
                   v_total_components AS total_components, v_earnings_count AS earnings_count,
                   v_deductions_count AS deductions_count,
                   v_employer_contribution_count AS employer_contribution_count;
        ELSE
            SELECT 'Y' AS status,
                   'Salary components retrieved successfully' AS remarks,
                   v_total_components AS total_components,
                   v_earnings_count AS earnings_count,
                   v_deductions_count AS deductions_count,
                   v_employer_contribution_count AS employer_contribution_count,
                   m.component_id,
                   m.component_code,
                   m.component_name,
                   m.component_type,
                   m.calculation_type,
                   m.percentage_base,
                   m.percentage_value,
                   m.is_taxable,
                   m.is_active,
                   m.formula_expression,
                   m.minimum_amount,
                   m.maximum_amount,
                   m.calculation_scope,
                   m.calculation_order,
                   m.eligibility_parameter,
                   m.eligibility_required_value,
                   m.is_slab,
                   m.rounding_precision,
                   m.is_manual,
                   (SELECT COUNT(*) FROM salary_component_slab s
                     WHERE s.component_id = m.component_id AND s.is_active = 1) AS slab_count
              FROM salary_component_master m
             ORDER BY m.is_active DESC, m.calculation_order, m.component_id;
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-041  NEW PROCEDURE hrms_calculate_payroll_detail
--        Calculates one employee of a payroll run with the engine:
--        CTC1 = earned CTC of the month (employee_payroll_details.ctc1),
--        manual components from payroll_manual_inputs, slabs valid on the
--        last day of the pay period. Writes the component rows and the
--        totals of the employee (gross, deductions, employer, net).
--        Totals come from the components GROSS, TOTAL_DEDUCTIONS,
--        TOTAL_EMPLOYER_CONTRIBUTION and NET_PAY when they exist,
--        otherwise from the sum of each component type.
--        C-109: the totals (AGGREGATE components: GROSS, NET_PAY, TOTAL_CTC and
--        any other total) are stored too, as rows with calculation_scope =
--        'AGGREGATE', so a payslip or report can show them.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_calculate_payroll_detail$$
CREATE PROCEDURE hrms_calculate_payroll_detail(
    IN  p_payroll_detail_id BIGINT,
    OUT p_errors            INT,
    OUT p_error_text        VARCHAR(500)
)
BEGIN
    DECLARE v_structure BIGINT;
    DECLARE v_emp       VARCHAR(20);
    DECLARE v_ctc1      DECIMAL(14,2);
    DECLARE v_days      DECIMAL(5,2);
    DECLARE v_month     INT;
    DECLARE v_year      INT;
    DECLARE v_end       DATE;
    DECLARE v_passes    INT DEFAULT 0;
    DECLARE v_sum_earn  DECIMAL(14,2);
    DECLARE v_sum_ded   DECIMAL(14,2);
    DECLARE v_sum_er    DECIMAL(14,2);
    DECLARE v_gross     DECIMAL(14,2);
    DECLARE v_ded       DECIMAL(14,2);
    DECLARE v_er        DECIMAL(14,2);
    DECLARE v_net       DECIMAL(14,2);

    SELECT MAX(d.structure_id), MAX(d.emp_id), MAX(d.ctc1), MAX(d.payable_days),
           MAX(c.payroll_month), MAX(c.payroll_year), MAX(c.period_end)
      INTO v_structure, v_emp, v_ctc1, v_days, v_month, v_year, v_end
      FROM employee_payroll_details d
      LEFT JOIN payroll_runs r   ON r.payroll_run_id = d.payroll_run_id
      LEFT JOIN payroll_cycles c ON c.payroll_cycle_id = r.payroll_cycle_id
     WHERE d.payroll_detail_id = p_payroll_detail_id;

    CALL hrms_engine_run(v_structure, COALESCE(v_ctc1, 0), LEAST(GREATEST(COALESCE(v_days, 0), 0), 30),
                         v_emp, v_month, v_year, COALESCE(v_end, CURDATE()), v_passes, p_errors, p_error_text);

    IF p_errors = 0 THEN
        DELETE FROM employee_payroll_component_details WHERE payroll_detail_id = p_payroll_detail_id;
        INSERT INTO employee_payroll_component_details
            (payroll_detail_id, component_id, component_code, component_name, component_type,
             calculation_scope, calculation_order, calculation_type,
             component_value, percentage_base, percentage_value, formula_expression, calculated_amount, is_taxable)
        SELECT p_payroll_detail_id, m.component_id, m.component_code, m.component_name, m.component_type,
               c.scope, c.calc_order,
               CASE WHEN c.overridden = 1 THEN c.eff_calc ELSE m.calculation_type END,
               ROUND(c.eff_value, 2), c.eff_base, COALESCE(m.percentage_value, 0), c.eff_formula,
               ROUND(c.new_amt, 2), COALESCE(m.is_taxable, 1)
          FROM tmp_hrms_calc c
          JOIN salary_component_master m ON m.component_id = c.cid
         ORDER BY c.calc_order, c.cid;

        SELECT COALESCE(SUM(IF(scope = 'COMPONENT' AND ctype = 'EARNING', new_amt, 0)), 0),
               COALESCE(SUM(IF(scope = 'COMPONENT' AND ctype = 'DEDUCTION', new_amt, 0)), 0),
               COALESCE(SUM(IF(scope = 'COMPONENT' AND ctype = 'EMPLOYER_CONTRIBUTION', new_amt, 0)), 0),
               MAX(IF(scope = 'AGGREGATE' AND code = 'GROSS', new_amt, NULL)),
               MAX(IF(scope = 'AGGREGATE' AND code = 'TOTAL_DEDUCTIONS', new_amt, NULL)),
               MAX(IF(scope = 'AGGREGATE' AND code = 'TOTAL_EMPLOYER_CONTRIBUTION', new_amt, NULL)),
               MAX(IF(scope = 'AGGREGATE' AND code = 'NET_PAY', new_amt, NULL))
          INTO v_sum_earn, v_sum_ded, v_sum_er, v_gross, v_ded, v_er, v_net
          FROM tmp_hrms_calc;

        SET v_gross = COALESCE(v_gross, v_sum_earn);
        SET v_ded   = COALESCE(v_ded, v_sum_ded);
        SET v_er    = COALESCE(v_er, v_sum_er);
        SET v_net   = COALESCE(v_net, v_gross - v_ded);

        UPDATE employee_payroll_details
           SET gross_earnings = ROUND(v_gross, 2),
               total_deductions = ROUND(v_ded, 2),
               employer_contributions = ROUND(v_er, 2),
               net_pay = ROUND(v_net, 2),
               employee_payroll_status = 'CALCULATED',
               calculation_remarks = LEFT(CONCAT(COALESCE(calculation_remarks, ''),
                   ' Components calculated by the salary engine from the component master (', v_passes, ' passes).'), 1000)
         WHERE payroll_detail_id = p_payroll_detail_id;
    ELSE
        SET p_error_text = LEFT(CONCAT('Employee ', COALESCE(v_emp, '?'), ' - ', COALESCE(p_error_text, 'calculation failed')), 500);
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-042  NEW PROCEDURE hrms_calculate_payroll_run
--        Runs C-041 for every employee of a payroll run. Stops at the
--        first error and reports the employee and the reason.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_calculate_payroll_run$$
CREATE PROCEDURE hrms_calculate_payroll_run(
    IN  p_payroll_run_id BIGINT,
    OUT p_employees      INT,
    OUT p_errors         INT,
    OUT p_error_text     VARCHAR(500)
)
BEGIN
    DECLARE v_done   INT DEFAULT 0;
    DECLARE v_detail BIGINT;
    DECLARE v_err    INT DEFAULT 0;
    DECLARE v_text   VARCHAR(500);
    DECLARE cur CURSOR FOR SELECT payroll_detail_id FROM tmp_hrms_detail_list ORDER BY payroll_detail_id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    SET p_employees = 0;
    SET p_errors = 0;
    SET p_error_text = NULL;

    CALL hrms_engine_prepare();
    DELETE FROM tmp_hrms_detail_list;
    INSERT INTO tmp_hrms_detail_list (payroll_detail_id)
    SELECT payroll_detail_id FROM employee_payroll_details WHERE payroll_run_id = p_payroll_run_id;

    OPEN cur;
    dt: LOOP
        SET v_done = 0;
        FETCH cur INTO v_detail;
        IF v_done = 1 THEN
            LEAVE dt;
        END IF;
        CALL hrms_calculate_payroll_detail(v_detail, v_err, v_text);
        IF v_err > 0 THEN
            SET p_errors = v_err;
            SET p_error_text = v_text;
            LEAVE dt;
        END IF;
        SET p_employees = p_employees + 1;
    END LOOP dt;
    CLOSE cur;
END$$

-- ---------------------------------------------------------------------
-- C-043  NEW PROCEDURE hrms_save_payroll_manual_input
--        Stores the amount of a manual component for one employee and one
--        payroll month (used when that month's payroll is calculated).
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
    DECLARE v_role   VARCHAR(30);
    DECLARE v_ustat  VARCHAR(20);
    DECLARE v_manual INT DEFAULT 0;

    SELECT MAX(user_category), MAX(status) INTO v_role, v_ustat
      FROM user_login_details WHERE emp_id = p_emp_id;
    SELECT COUNT(*) INTO v_manual FROM salary_component_master
     WHERE component_id = p_component_id AND is_active = 1 AND (is_manual = 1 OR calculation_type = 'MANUAL');

    IF v_role IS NULL OR LOWER(COALESCE(v_ustat, '')) <> 'active' OR UPPER(v_role) NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can enter manual amounts.' AS remarks;
    ELSEIF v_manual = 0 THEN
        SELECT 'N' AS status, 'This is not an active manual component.' AS remarks;
    ELSEIF p_month IS NULL OR p_month NOT BETWEEN 1 AND 12 OR p_year IS NULL OR p_year NOT BETWEEN 2000 AND 2100 THEN
        SELECT 'N' AS status, 'Invalid payroll month or year.' AS remarks;
    ELSEIF p_amount IS NULL OR p_amount < 0 THEN
        SELECT 'N' AS status, 'Amount must be 0 or more.' AS remarks;
    ELSE
        INSERT INTO payroll_manual_inputs (emp_id, payroll_month, payroll_year, component_id, amount, remarks, created_by)
        VALUES (p_target_emp_id, p_month, p_year, p_component_id, p_amount, NULLIF(TRIM(p_remarks), ''), p_emp_id)
        ON DUPLICATE KEY UPDATE amount = VALUES(amount), remarks = VALUES(remarks), created_by = VALUES(created_by);
        SELECT 'Y' AS status, 'Manual amount saved.' AS remarks;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-044  DATA : load the new component set and its slabs
--   Runs once (skipped when the component TOTAL_CTC already exists).
--   1. backup tables  salary_component_master_bak_step2,
--                     employee_salary_structure_bak_step2
--   2. existing components keep their id and get the new code:
--        OTHER_EARNING -> OTHERS          EMP_PF   -> EE_EPF
--        EMP_ESI (deduction) -> EE_ESI    ER_PF    -> EMP_EPF
--        ER_ESI  -> EMP_ESI               PROF_TAX -> PT
--        INCENTIVE -> OTHER_EARNINGS      OTHER_DEDUCTION -> ADVANCE
--   3. the 20 components get their definition; missing ones are created
--   4. SPECIAL, LOP, GRATUITY and TESTING are deactivated (kept for history)
--   5. the 13 slabs are loaded
--   6. every ACTIVE salary structure gets all components and is recalculated
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_script_rename_component$$
CREATE PROCEDURE hrms_script_rename_component(IN p_old VARCHAR(30), IN p_type VARCHAR(30), IN p_new VARCHAR(30))
BEGIN
    DECLARE v_new_exists INT DEFAULT 0;
    SELECT COUNT(*) INTO v_new_exists FROM salary_component_master WHERE UPPER(component_code) = UPPER(p_new);
    IF v_new_exists = 0 THEN
        UPDATE salary_component_master
           SET component_code = p_new
         WHERE UPPER(component_code) = UPPER(p_old) AND component_type = p_type;
    END IF;
END$$

DROP PROCEDURE IF EXISTS hrms_script_c044$$
CREATE PROCEDURE hrms_script_c044()
ld: BEGIN
    DECLARE v_done       INT DEFAULT 0;
    DECLARE v_attached   INT DEFAULT 0;
    DECLARE v_structures INT DEFAULT 0;
    DECLARE v_changed    INT DEFAULT 0;
    DECLARE v_errors     INT DEFAULT 0;
    DECLARE v_text       VARCHAR(500);
    DECLARE v_signal     VARCHAR(128);

    SELECT COUNT(*) INTO v_done FROM salary_component_master WHERE component_code = 'TOTAL_CTC';
    IF v_done > 0 THEN
        LEAVE ld;
    END IF;

    CREATE TABLE IF NOT EXISTS salary_component_master_bak_step2 AS SELECT * FROM salary_component_master;
    CREATE TABLE IF NOT EXISTS employee_salary_structure_bak_step2 AS SELECT * FROM employee_salary_structure;

    START TRANSACTION;

    CALL hrms_script_rename_component('EMP_ESI',         'DEDUCTION',             'EE_ESI');
    CALL hrms_script_rename_component('ER_ESI',          'EMPLOYER_CONTRIBUTION', 'EMP_ESI');
    CALL hrms_script_rename_component('EMP_PF',          'DEDUCTION',             'EE_EPF');
    CALL hrms_script_rename_component('ER_PF',           'EMPLOYER_CONTRIBUTION', 'EMP_EPF');
    CALL hrms_script_rename_component('PROF_TAX',        'DEDUCTION',             'PT');
    CALL hrms_script_rename_component('OTHER_EARNING',   'EARNING',               'OTHERS');
    CALL hrms_script_rename_component('INCENTIVE',       'EARNING',               'OTHER_EARNINGS');
    CALL hrms_script_rename_component('OTHER_DEDUCTION', 'DEDUCTION',             'ADVANCE');

    INSERT INTO salary_component_master
        (component_code, component_name, component_type, calculation_type, percentage_base, percentage_value,
         minimum_amount, maximum_amount, formula_expression, is_taxable, is_active, calculation_scope,
         calculation_order, eligibility_parameter, eligibility_required_value, is_manual, is_slab, rounding_precision)
    VALUES
        ('BASIC',          'Basic Salary',           'EARNING', 'PERCENTAGE', 'CTC1', 50.00, NULL, NULL, 'CTC1 * 0.50', 1, 1, 'COMPONENT', 10, NULL, NULL, 0, 0, 2),
        ('HRA',            'House Rent Allowance',   'EARNING', 'PERCENTAGE', 'CTC1', 20.00, NULL, NULL, 'CTC1 * 0.20', 1, 1, 'COMPONENT', 20, NULL, NULL, 0, 0, 2),
        ('MEDICAL',        'Medical Allowance',      'EARNING', 'PERCENTAGE', 'CTC1',  5.00, NULL, NULL, 'CTC1 * 0.05', 1, 1, 'COMPONENT', 30, NULL, NULL, 0, 0, 2),
        ('CONVEYANCE',     'Conveyance Allowance',   'EARNING', 'PERCENTAGE', 'CTC1',  8.00, NULL, NULL, 'CTC1 * 0.08', 1, 1, 'COMPONENT', 40, NULL, NULL, 0, 0, 2),
        ('OTHER_EARNINGS', 'Other Earnings',         'EARNING', 'MANUAL',     'NONE',  0.00, NULL, NULL, NULL,          1, 1, 'COMPONENT', 90, NULL, NULL, 1, 0, 2),
        ('OTHERS',         'Other Salary Component', 'EARNING', 'FORMULA',    'CTC1', 17.00, NULL, NULL, '(CTC1 * 0.17) - (ER_NPS + EMP_EPF + EMP_ESI + ER_ADMIN)', 1, 1, 'COMPONENT', 80, NULL, NULL, 0, 0, 2),
        ('EMP_EPF',        'Employer EPF',           'EMPLOYER_CONTRIBUTION', 'PERCENTAGE', 'BASIC', 12.00, NULL, 3000.00, 'LEAST(BASIC * 0.12, 3000)', 0, 1, 'COMPONENT', 60, NULL, NULL, 0, 1, 2),
        ('EMP_ESI',        'Employer ESI',           'EMPLOYER_CONTRIBUTION', 'STATUTORY',  'GROSS',  3.25, NULL, NULL, 'IF(STANDARD_ESI_WAGE <= 21000, ROUND(ESI_WAGE * 0.0325, 2), 0)', 0, 1, 'COMPONENT', 180, 'EMPLOYEE_ESI_ELIGIBLE', 'Y', 0, 1, 2),
        ('EE_EPF',         'Employee EPF',           'DEDUCTION', 'PERCENTAGE', 'BASIC', 12.00, NULL, 3000.00, 'LEAST(BASIC * 0.12, 3000)', 0, 1, 'COMPONENT', 110, NULL, NULL, 0, 1, 2),
        ('EE_ESI',         'Employee ESI',           'DEDUCTION', 'STATUTORY',  'GROSS',  0.75, NULL, NULL, 'IF(STANDARD_ESI_WAGE <= 21000, ROUND(ESI_WAGE * 0.0075, 2), 0)', 0, 1, 'COMPONENT', 120, 'EMPLOYEE_ESI_ELIGIBLE', 'Y', 0, 1, 2),
        ('PT',             'Professional Tax',       'DEDUCTION', 'STATUTORY',  'GROSS',  0.00, NULL, 200.00, 'IF(GROSS > 20000, 200, IF(GROSS >= 15000, 150, 0))', 0, 1, 'COMPONENT', 130, NULL, NULL, 0, 1, 2),
        ('TDS',            'Income Tax TDS',         'DEDUCTION', 'MANUAL',     'NONE',   0.00, NULL, NULL, 'MANUAL_AMOUNT', 0, 1, 'COMPONENT', 150, NULL, NULL, 1, 0, 2),
        ('ER_NPS',         'Employer NPS',           'EMPLOYER_CONTRIBUTION', 'PERCENTAGE', 'BASIC', 0.00, 0.00, NULL, '0', 0, 1, 'COMPONENT', 50, NULL, NULL, 0, 0, 2),
        ('ER_ADMIN',       'EPF Admin Charges',      'EMPLOYER_CONTRIBUTION', 'STATUTORY',  'BASIC', 1.00, NULL, 250.00, 'LEAST(BASIC * 0.01, 250)', 0, 1, 'COMPONENT', 70, NULL, NULL, 0, 1, 2),
        ('GROSS',          'Gross Salary',           'EARNING',   'FORMULA', 'NONE', 0.00, NULL, NULL, 'BASIC + HRA + MEDICAL + CONVEYANCE + OTHERS + OTHER_EARNINGS', 1, 1, 'AGGREGATE', 100, NULL, NULL, 0, 0, 2),
        ('TOTAL_DEDUCTIONS', 'Total Deductions',     'DEDUCTION', 'FORMULA', 'NONE', 0.00, NULL, NULL, 'PT + EE_EPF + ADVANCE + TDS + EE_ESI', 0, 1, 'AGGREGATE', 160, NULL, NULL, 0, 0, 2),
        ('NET_PAY',        'Net Pay',                'EARNING',   'FORMULA', 'NONE', 0.00, NULL, NULL, 'GROSS - TOTAL_DEDUCTIONS', 0, 1, 'AGGREGATE', 170, NULL, NULL, 0, 0, 2),
        ('TOTAL_CTC',      'Total CTC',              'EMPLOYER_CONTRIBUTION', 'FORMULA', 'NONE', 0.00, NULL, NULL, 'GROSS + TOTAL_EMPLOYER_CONTRIBUTION', 0, 1, 'AGGREGATE', 200, NULL, NULL, 0, 0, 2),
        ('TOTAL_EMPLOYER_CONTRIBUTION', 'Total Employer Contribution', 'EMPLOYER_CONTRIBUTION', 'FORMULA', 'NONE', 0.00, NULL, NULL, 'ER_NPS + EMP_EPF + EMP_ESI + ER_ADMIN', 0, 1, 'AGGREGATE', 190, NULL, NULL, 0, 0, 2),
        ('ADVANCE',        'Salary Advance',         'DEDUCTION', 'MANUAL',     'NONE',   0.00, NULL, NULL, 'MANUAL_AMOUNT', 0, 1, 'COMPONENT', 140, NULL, NULL, 1, 0, 2)
    ON DUPLICATE KEY UPDATE
        component_name = VALUES(component_name),
        component_type = VALUES(component_type),
        calculation_type = VALUES(calculation_type),
        percentage_base = VALUES(percentage_base),
        percentage_value = VALUES(percentage_value),
        minimum_amount = VALUES(minimum_amount),
        maximum_amount = VALUES(maximum_amount),
        formula_expression = VALUES(formula_expression),
        is_taxable = VALUES(is_taxable),
        is_active = VALUES(is_active),
        calculation_scope = VALUES(calculation_scope),
        calculation_order = VALUES(calculation_order),
        eligibility_parameter = VALUES(eligibility_parameter),
        eligibility_required_value = VALUES(eligibility_required_value),
        is_manual = VALUES(is_manual),
        is_slab = VALUES(is_slab),
        rounding_precision = VALUES(rounding_precision);

    UPDATE salary_component_master
       SET is_active = 0
     WHERE UPPER(component_code) IN ('SPECIAL', 'LOP', 'GRATUITY', 'TESTING');

    -- slabs
    DELETE s FROM salary_component_slab s
      JOIN salary_component_master m ON m.component_id = s.component_id
     WHERE m.component_code IN ('EE_ESI', 'ER_ADMIN', 'PT', 'EMP_ESI', 'EMP_EPF', 'EE_EPF');
    INSERT INTO salary_component_slab
        (component_id, slab_based_on, slab_min_value, slab_max_value, result_type, result_value,
         percentage_base, priority, effective_from, effective_to, is_active, created_by)
    SELECT m.component_id, x.based_on, x.min_v, x.max_v, x.rtype, x.rvalue, x.pbase, x.prio, '2026-04-01', NULL, 1, 'SCRIPT'
      FROM (
                  SELECT 'EE_ESI' AS code, 'GROSS' AS based_on, 0.00 AS min_v, 21000.00 AS max_v, 'PERCENTAGE' AS rtype, 0.75 AS rvalue, 'GROSS' AS pbase, 1 AS prio
        UNION ALL SELECT 'EE_ESI',   'GROSS', 21000.01, NULL,     'FIXED',         0.00, 'NONE',  2
        UNION ALL SELECT 'ER_ADMIN', 'BASIC',     0.00, 25000.00, 'PERCENTAGE',    1.00, 'BASIC', 1
        UNION ALL SELECT 'ER_ADMIN', 'BASIC', 25000.01, NULL,     'FIXED',       250.00, 'NONE',  2
        UNION ALL SELECT 'PT',       'GROSS',     0.00, 14999.99, 'FIXED',         0.00, 'NONE',  1
        UNION ALL SELECT 'PT',       'GROSS', 15000.00, 20000.00, 'FIXED',       150.00, 'NONE',  2
        UNION ALL SELECT 'PT',       'GROSS', 20000.01, NULL,     'FIXED',       200.00, 'NONE',  3
        UNION ALL SELECT 'EMP_ESI',  'GROSS',     0.00, 21000.00, 'PERCENTAGE',    3.25, 'GROSS', 1
        UNION ALL SELECT 'EMP_ESI',  'GROSS', 21000.01, NULL,     'FIXED',         0.00, 'NONE',  2
        UNION ALL SELECT 'EMP_EPF',  'BASIC',     0.00, 25000.00, 'PERCENTAGE',   12.00, 'BASIC', 1
        UNION ALL SELECT 'EMP_EPF',  'BASIC', 25000.01, NULL,     'FIXED',      3000.00, 'NONE',  2
        UNION ALL SELECT 'EE_EPF',   'BASIC',     0.00, 25000.00, 'PERCENTAGE',   12.00, 'BASIC', 1
        UNION ALL SELECT 'EE_EPF',   'BASIC', 25000.01, NULL,     'FIXED',      3000.00, 'NONE',  2
      ) x
      JOIN salary_component_master m ON m.component_code = x.code;

    -- employee rows that are not overridden follow the master
    UPDATE employee_salary_structure ess
      JOIN salary_component_master m ON m.component_id = ess.component_id
       SET ess.calculation_type   = CASE WHEN m.calculation_type = 'STATUTORY' THEN 'MANUAL' ELSE m.calculation_type END,
           ess.component_value    = COALESCE(m.percentage_value, 0),
           ess.percentage_base    = COALESCE(m.percentage_base, 'NONE'),
           ess.formula_expression = m.formula_expression
     WHERE ess.is_overridden = 0;

    CALL hrms_attach_component(NULL, v_attached);
    CALL hrms_recalculate_all_structures(v_structures, v_changed, v_errors, v_text);

    IF v_errors > 0 THEN
        ROLLBACK;
        SET v_signal = LEFT(CONCAT('Component load cancelled: ', COALESCE(v_text, 'calculation failed')), 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_signal;
    END IF;
    COMMIT;
END$$
CALL hrms_script_c044()$$
DROP PROCEDURE IF EXISTS hrms_script_c044$$
DROP PROCEDURE IF EXISTS hrms_script_rename_component$$

-- ---------------------------------------------------------------------
-- C-045  UPDATE PROCEDURE hrms_create_payroll_cycle_complete
--        Unchanged except for the calculation: the fixed rule
--        "stored amount x payable days / 30" and the sums by component type are
--        replaced by one call to the salary engine (C-042). The original
--        procedure is in script_backup_original_procedures.sql.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_create_payroll_cycle_complete$$
CREATE PROCEDURE `hrms_create_payroll_cycle_complete`(
    IN p_requester_emp_id VARCHAR(20),
    IN p_payroll_month TINYINT,
    IN p_payroll_year SMALLINT,
    IN p_payment_date DATE,
    IN p_period_start DATE,
    IN p_period_end DATE,
    IN p_remarks VARCHAR(500),
    IN p_cycle_code VARCHAR(50)
)
BEGIN
    

    DECLARE v_requester_found INT DEFAULT 0;
    DECLARE v_employee_count INT DEFAULT 0;
    DECLARE v_attendance_count INT DEFAULT 0;
    DECLARE v_salary_count INT DEFAULT 0;
    DECLARE v_duplicate_count INT DEFAULT 0;

    DECLARE v_payroll_cycle_id BIGINT;
    DECLARE v_payroll_run_id BIGINT;

    DECLARE v_period_start DATE;
    DECLARE v_period_end DATE;

    DECLARE v_expected_start DATE;
    DECLARE v_expected_end DATE;

    DECLARE v_total_payroll_details INT DEFAULT 0;
    DECLARE v_total_components INT DEFAULT 0;
    DECLARE v_error_message VARCHAR(128) DEFAULT 'Payroll creation failed';
    DECLARE v_original_time_zone VARCHAR(64) DEFAULT '+00:00';
    DECLARE v_transaction_started TINYINT DEFAULT 0;
    DECLARE v_engine_employees INT DEFAULT 0;
    DECLARE v_engine_errors INT DEFAULT 0;
    DECLARE v_engine_text VARCHAR(500);
    DECLARE v_engine_signal VARCHAR(128);

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        IF v_transaction_started = 1 THEN
            ROLLBACK;
            SET v_transaction_started = 0;
        END IF;

        SET SESSION time_zone = v_original_time_zone;

        SELECT
            'N' AS status,
            COALESCE(v_error_message, 'Payroll creation failed') AS remarks,
            NULL AS payroll_cycle_id,
            TRIM(p_cycle_code) AS cycle_code,
            NULL AS payroll_run_id,
            p_payroll_month AS payroll_month,
            p_payroll_year AS payroll_year,
            p_period_start AS period_start,
            p_period_end AS period_end,
            p_payment_date AS payment_date,
            v_employee_count AS active_employee_count,
            v_total_payroll_details AS payroll_details_inserted,
            v_total_components AS payroll_components_inserted,
            'FAILED' AS payroll_run_status;
    END;


    
    SET v_original_time_zone = @@SESSION.time_zone;
    SET SESSION time_zone = '+05:30';

    

    IF p_requester_emp_id IS NULL
       OR TRIM(p_requester_emp_id) = '' THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Requester employee ID is required';

    END IF;


    IF p_payroll_month IS NULL
       OR p_payroll_month NOT BETWEEN 1 AND 12 THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Invalid payroll month';

    END IF;


    IF p_payroll_year IS NULL
       OR p_payroll_year < 2000
       OR p_payroll_year > 2100 THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Invalid payroll year';

    END IF;


    IF p_cycle_code IS NULL
       OR TRIM(p_cycle_code) = '' THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Payroll cycle code is required';

    END IF;


    IF p_period_start IS NULL
       OR p_period_end IS NULL THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Payroll period start and end dates are required';

    END IF;


    IF p_period_start > p_period_end THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Payroll start date cannot be after end date';

    END IF;


    

    SELECT COUNT(*)
    INTO v_requester_found
    FROM user_login_details
    WHERE emp_id = p_requester_emp_id
      AND status = 'ACTIVE'
      AND user_category IN ('ADMIN', 'HR');


    IF v_requester_found = 0 THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Access denied: Active ADMIN or HR account required';

    END IF;


    

    SET v_expected_start = DATE_SUB(
        STR_TO_DATE(
            CONCAT(
                p_payroll_year,
                '-',
                LPAD(p_payroll_month, 2, '0'),
                '-25'
            ),
            '%Y-%m-%d'
        ),
        INTERVAL 1 MONTH
    );


    SET v_expected_end = STR_TO_DATE(
        CONCAT(
            p_payroll_year,
            '-',
            LPAD(p_payroll_month, 2, '0'),
            '-24'
        ),
        '%Y-%m-%d'
    );


    IF p_period_start <> v_expected_start
       OR p_period_end <> v_expected_end THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Invalid payroll period: dates must follow the 25th-to-24th cycle';

    END IF;


    SET v_period_start = p_period_start;
    SET v_period_end = p_period_end;


    

    SELECT COUNT(*)
    INTO v_duplicate_count
    FROM payroll_cycles
    WHERE payroll_month = p_payroll_month
      AND payroll_year = p_payroll_year;


    IF v_duplicate_count > 0 THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Payroll cycle already exists for this month and year';

    END IF;


    SELECT COUNT(*)
    INTO v_duplicate_count
    FROM payroll_cycles
    WHERE cycle_code = TRIM(p_cycle_code);


    IF v_duplicate_count > 0 THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Payroll cycle code already exists';

    END IF;


    

    SELECT COUNT(DISTINCT emp_id)
    INTO v_employee_count
    FROM user_login_details
    WHERE status = 'ACTIVE'
      AND emp_id IS NOT NULL
      AND TRIM(emp_id) <> '';


    IF v_employee_count = 0 THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'No active employees found';

    END IF;


    

    SELECT COUNT(DISTINCT u.emp_id)
    INTO v_attendance_count
    FROM user_login_details u
    WHERE u.status = 'ACTIVE'
      AND u.emp_id IS NOT NULL
      AND TRIM(u.emp_id) <> ''
      AND EXISTS (
          SELECT 1
          FROM payroll_attendance_summary a
          WHERE a.emp_id = u.emp_id
            AND a.payroll_month = p_payroll_month
            AND a.payroll_year = p_payroll_year
            AND a.is_finalized = 'Y'
      );


    IF v_attendance_count <> v_employee_count THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Cannot create payroll: Some active employees have missing or unfinalized attendance';

    END IF;


    

    SELECT COUNT(DISTINCT u.emp_id)
    INTO v_salary_count
    FROM user_login_details u
    WHERE u.status = 'ACTIVE'
      AND u.emp_id IS NOT NULL
      AND TRIM(u.emp_id) <> ''
      AND EXISTS (
          SELECT 1
          FROM salary_structure ss
          WHERE ss.emp_id = u.emp_id
            AND ss.structure_status = 'ACTIVE'
            AND ss.effective_from <= v_period_end
            AND (
                ss.effective_to IS NULL
                OR ss.effective_to >= v_period_start
            )
      );


    IF v_salary_count <> v_employee_count THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Cannot create payroll: Some active employees do not have an applicable active salary structure';

    END IF;


    

    START TRANSACTION;
    SET v_transaction_started = 1;


    

    INSERT INTO payroll_cycles (
        cycle_code,
        payroll_month,
        payroll_year,
        period_start,
        period_end,
        payment_date,
        cycle_status,
        created_by,
        remarks
    )
    VALUES (
        TRIM(p_cycle_code),
        p_payroll_month,
        p_payroll_year,
        v_period_start,
        v_period_end,
        p_payment_date,
        'OPEN',
        p_requester_emp_id,
        NULLIF(TRIM(p_remarks), '')
    );


    SET v_payroll_cycle_id = LAST_INSERT_ID();


    

    INSERT INTO payroll_runs (
        payroll_cycle_id,
        run_number,
        run_type,
        run_status,
        total_employees,
        created_by
    )
    VALUES (
        v_payroll_cycle_id,
        1,
        'REGULAR',
        'DRAFT',
        v_employee_count,
        p_requester_emp_id
    );


    SET v_payroll_run_id = LAST_INSERT_ID();


    

    INSERT INTO employee_payroll_details (
        payroll_run_id,
        emp_id,
        structure_id,
        monthly_ctc,
        annual_ctc,
        total_days,
        payable_days,
        paid_leave_days,
        unpaid_leave_days,
        absent_days,
        ctc1,
        gross_earnings,
        total_deductions,
        employer_contributions,
        net_pay,
        calculation_version,
        calculation_remarks,
        employee_payroll_status
    )
    SELECT
        v_payroll_run_id,
        u.emp_id,
        ss.structure_id,
        ss.monthly_ctc,
        ss.annual_ctc,
        a.total_days,
        hrms_pay_days(a.unpaid_days),   -- C-113
        0,
        a.unpaid_days,
        a.absent_days,

        ROUND(
            ss.monthly_ctc
            * hrms_pay_days(a.unpaid_days)
            / 30,
            2
        ),

        0.00,
        0.00,
        0.00,
        0.00,

        1,

        CONCAT(
            'Payroll created using a fixed 30-day salary basis. ',
            'Payable days capped at 30. Attendance finalized for ',
            LPAD(p_payroll_month, 2, '0'),
            '/',
            p_payroll_year
        ),

        'CALCULATED'

    FROM (
        SELECT DISTINCT emp_id
        FROM user_login_details
        WHERE status = 'ACTIVE'
          AND emp_id IS NOT NULL
          AND TRIM(emp_id) <> ''
    ) u

    INNER JOIN payroll_attendance_summary a
        ON a.emp_id = u.emp_id
       AND a.payroll_month = p_payroll_month
       AND a.payroll_year = p_payroll_year
       AND a.is_finalized = 'Y'

    INNER JOIN salary_structure ss
        ON ss.emp_id = u.emp_id
       AND ss.structure_status = 'ACTIVE'
       AND ss.effective_from <= v_period_end
       AND (
            ss.effective_to IS NULL
            OR ss.effective_to >= v_period_start
       );


    SET v_total_payroll_details = ROW_COUNT();


    

    -- Components and totals of every employee are calculated by the salary
    -- engine from the component master (formulas, slabs, calculation order).
    CALL hrms_calculate_payroll_run(v_payroll_run_id, v_engine_employees, v_engine_errors, v_engine_text);
    IF v_engine_errors > 0 THEN
        SET v_engine_signal = LEFT(CONCAT('Payroll not created: ', COALESCE(v_engine_text, 'calculation failed')), 128);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = v_engine_signal;
    END IF;
    SELECT COUNT(*)
    INTO v_total_components
    FROM employee_payroll_component_details epc
    INNER JOIN employee_payroll_details epd
        ON epd.payroll_detail_id = epc.payroll_detail_id
    WHERE epd.payroll_run_id = v_payroll_run_id;
    UPDATE payroll_runs pr

    INNER JOIN (
        SELECT
            payroll_run_id,

            COUNT(*) AS total_employees,

            ROUND(
                SUM(gross_earnings),
                2
            ) AS total_earnings,

            ROUND(
                SUM(total_deductions),
                2
            ) AS total_deductions,

            ROUND(
                SUM(employer_contributions),
                2
            ) AS total_employer_contributions,

            ROUND(
                SUM(net_pay),
                2
            ) AS total_net_pay

        FROM employee_payroll_details

        WHERE payroll_run_id = v_payroll_run_id

        GROUP BY payroll_run_id
    ) totals
        ON totals.payroll_run_id = pr.payroll_run_id

    SET
        pr.total_employees = totals.total_employees,

        pr.total_earnings = totals.total_earnings,

        pr.total_deductions = totals.total_deductions,

        pr.total_employer_contributions =
            totals.total_employer_contributions,

        pr.total_net_pay = totals.total_net_pay,

        pr.run_status = 'CALCULATED'

    WHERE pr.payroll_run_id = v_payroll_run_id;


    

    IF v_total_payroll_details <> v_employee_count THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Payroll detail count mismatch; transaction cancelled';

    END IF;


    

    UPDATE employee_payroll_details
    SET employee_payroll_status = 'APPROVED'
    WHERE payroll_run_id = v_payroll_run_id;

    UPDATE payroll_runs
    SET run_status = 'APPROVED',
        calculated_by = TRIM(p_requester_emp_id),
        calculated_at = NOW(),
        approved_by = TRIM(p_requester_emp_id),
        approved_at = NOW()
    WHERE payroll_run_id = v_payroll_run_id;

    

    

    COMMIT;
    SET v_transaction_started = 0;


    

    SET SESSION time_zone = v_original_time_zone;

    SELECT
        'Y' AS status,
        'Payroll calculated and directly approved successfully' AS remarks,
        v_payroll_cycle_id AS payroll_cycle_id,
        TRIM(p_cycle_code) AS cycle_code,
        v_payroll_run_id AS payroll_run_id,
        p_payroll_month AS payroll_month,
        p_payroll_year AS payroll_year,
        v_period_start AS period_start,
        v_period_end AS period_end,
        p_payment_date AS payment_date,
        v_employee_count AS active_employee_count,
        v_total_payroll_details AS payroll_details_inserted,
        v_total_components AS payroll_components_inserted,
        'APPROVED' AS payroll_run_status;

END$$

-- =====================================================================
-- STEP 3 : payroll cycle, step by step
--
--   OPEN --> ATTENDANCE_VERIFIED --> STRUCTURE_VERIFIED --> PROCESSING
--        --> CALCULATED --> APPROVED --> FINALIZED --> PAID / PARTIALLY_PAID
--        --> CLOSED
--
--   Back is allowed up to APPROVED:
--     ATTENDANCE_VERIFIED -> OPEN, STRUCTURE_VERIFIED -> ATTENDANCE_VERIFIED,
--     PROCESSING / CALCULATED -> STRUCTURE_VERIFIED, APPROVED -> CALCULATED.
--   FINALIZED, PARTIALLY_PAID, PAID and CLOSED never go back.
--   An employee on HOLD is not paid with the others: the cycle becomes
--   PARTIALLY_PAID and cannot be closed until every held employee is paid.
-- =====================================================================

-- ---------------------------------------------------------------------
-- C-046  ALTER TABLE payroll_cycles : every step of the cycle as a status,
--        and who marked it paid. An invalid payment date 0000-00-00 is
--        cleared first (it blocks any change of the table in strict mode).
-- ---------------------------------------------------------------------
UPDATE payroll_cycles SET payment_date = NULL WHERE CAST(payment_date AS CHAR) = '0000-00-00'$$
CALL hrms_script_modify_column('payroll_cycles', 'cycle_status',
     'enum(''open'',''attendance_verified'',''structure_verified'',''processing'',''calculated'',''approved'',''finalized'',''partially_paid'',''paid'',''closed'')',
     'ENUM(''OPEN'',''ATTENDANCE_VERIFIED'',''STRUCTURE_VERIFIED'',''PROCESSING'',''CALCULATED'',''APPROVED'',''FINALIZED'',''PARTIALLY_PAID'',''PAID'',''CLOSED'') NOT NULL DEFAULT ''OPEN''')$$
CALL hrms_script_add_column('payroll_cycles', 'paid_by', 'VARCHAR(50) NULL AFTER `finalized_at`')$$
CALL hrms_script_add_column('payroll_cycles', 'paid_at', 'DATETIME NULL AFTER `paid_by`')$$

-- ---------------------------------------------------------------------
-- C-047  ALTER TABLE employee_payroll_details : PENDING (waiting to be
--        calculated) and ERROR, who paid and when, one row per employee
--        per run.
-- ---------------------------------------------------------------------
CALL hrms_script_modify_column('employee_payroll_details', 'employee_payroll_status',
     'enum(''pending'',''calculated'',''error'',''under_review'',''approved'',''finalized'',''cancelled'')',
     'ENUM(''PENDING'',''CALCULATED'',''ERROR'',''UNDER_REVIEW'',''APPROVED'',''FINALIZED'',''CANCELLED'') NOT NULL DEFAULT ''PENDING''')$$
CALL hrms_script_add_column('employee_payroll_details', 'paid_by', 'VARCHAR(50) NULL')$$
CALL hrms_script_add_column('employee_payroll_details', 'paid_at', 'DATETIME NULL')$$
CALL hrms_script_add_index('employee_payroll_details', 'uq_epd_run_emp',
     'ALTER TABLE `employee_payroll_details` ADD UNIQUE KEY `uq_epd_run_emp` (`payroll_run_id`, `emp_id`)')$$
CALL hrms_script_add_index('employee_payroll_component_details', 'idx_epcd_detail',
     'ALTER TABLE `employee_payroll_component_details` ADD INDEX `idx_epcd_detail` (`payroll_detail_id`)')$$
CALL hrms_script_add_index('employee_payslips', 'idx_eps_detail',
     'ALTER TABLE `employee_payslips` ADD INDEX `idx_eps_detail` (`payroll_detail_id`)')$$

-- ---------------------------------------------------------------------
-- C-048  NEW TABLE payroll_cycle_status_log
--        Every step of a cycle and every hold / release / pay of an
--        employee, with who did it and when.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `payroll_cycle_status_log` (
    `log_id`            BIGINT NOT NULL AUTO_INCREMENT,
    `payroll_cycle_id`  BIGINT NOT NULL,
    `payroll_detail_id` BIGINT NULL,
    `emp_id`            VARCHAR(20) NULL,
    `action`            VARCHAR(40) NOT NULL,
    `from_status`       VARCHAR(30) NULL,
    `to_status`         VARCHAR(30) NULL,
    `remarks`           VARCHAR(500) NULL,
    `performed_by`      VARCHAR(20) NULL,
    `performed_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`log_id`),
    KEY `idx_pcsl_cycle` (`payroll_cycle_id`, `log_id`)
)$$
-- The cycle code is kept on every history row, so the history of a deleted
-- cycle can still be found (its rows get the cycle id as a negative number).
CALL hrms_script_add_column('payroll_cycle_status_log', 'cycle_code', 'VARCHAR(50) NULL AFTER `payroll_cycle_id`')$$
UPDATE payroll_cycle_status_log l
  JOIN payroll_cycles c ON c.payroll_cycle_id = l.payroll_cycle_id
   SET l.cycle_code = c.cycle_code
 WHERE l.cycle_code IS NULL$$

-- ---------------------------------------------------------------------
-- C-049  NEW PROCEDURE hrms_payroll_check_admin   (helper)
-- ---------------------------------------------------------------------
-- C-115: removed. Every payroll procedure now checks user_login_details itself
--        (active ADMIN or HR), so this helper is no longer used.
DROP PROCEDURE IF EXISTS hrms_payroll_check_admin$$

-- ---------------------------------------------------------------------
-- C-050  NEW FUNCTION hrms_payroll_cycle_actions
--        The actions allowed in each cycle status (comma separated).
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS hrms_payroll_cycle_actions$$
CREATE FUNCTION hrms_payroll_cycle_actions(p_status VARCHAR(30)) RETURNS VARCHAR(200) CHARSET utf8mb4 COLLATE utf8mb4_general_ci
DETERMINISTIC NO SQL
BEGIN
    RETURN CASE UPPER(COALESCE(p_status, ''))
        WHEN 'OPEN'                THEN 'VERIFY_ATTENDANCE'
        WHEN 'ATTENDANCE_VERIFIED' THEN 'VERIFY_STRUCTURE,BACK'
        WHEN 'STRUCTURE_VERIFIED'  THEN 'START_CALCULATION,BACK'
        WHEN 'PROCESSING'          THEN 'FINISH_CALCULATION,BACK'
        WHEN 'CALCULATED'          THEN 'APPROVE,RECALCULATE,BACK'
        WHEN 'APPROVED'            THEN 'FINALIZE,BACK'
        WHEN 'FINALIZED'           THEN 'MARK_PAID'
        WHEN 'PARTIALLY_PAID'      THEN 'GENERATE_PAYSLIPS'
        WHEN 'PAID'                THEN 'GENERATE_PAYSLIPS,CLOSE'
        ELSE ''
    END;
END$$

-- ---------------------------------------------------------------------
-- C-051  NEW PROCEDURE hrms_payroll_load_cycle_emps   (helper)
--        Fills tmp_hrms_cycle_emps with the employees of a cycle: every
--        active employee, their attendance summary for the month and the
--        ACTIVE salary structure that covers the pay period.
--        p_emp_filter NULL = everybody.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_load_cycle_emps$$
CREATE PROCEDURE hrms_payroll_load_cycle_emps(IN p_cycle_id BIGINT, IN p_emp_filter VARCHAR(20))
BEGIN
    DECLARE v_month INT;
    DECLARE v_year  INT;
    DECLARE v_start DATE;
    DECLARE v_end   DATE;

    SET SESSION group_concat_max_len = 1000000;
    SELECT MAX(payroll_month), MAX(payroll_year), MAX(period_start), MAX(period_end)
      INTO v_month, v_year, v_start, v_end
      FROM payroll_cycles WHERE payroll_cycle_id = p_cycle_id;

    DROP TEMPORARY TABLE IF EXISTS tmp_hrms_cycle_emps;
    CREATE TEMPORARY TABLE tmp_hrms_cycle_emps (
        emp_id        VARCHAR(20) NOT NULL PRIMARY KEY,
        emp_name      VARCHAR(150) NULL,
        has_att       TINYINT NOT NULL DEFAULT 0,
        att_final     TINYINT NOT NULL DEFAULT 0,
        total_days    DECIMAL(5,2) NOT NULL DEFAULT 0,
        paid_days     DECIMAL(5,2) NOT NULL DEFAULT 0,
        unpaid_days   DECIMAL(5,2) NOT NULL DEFAULT 0,
        absent_days   DECIMAL(5,2) NOT NULL DEFAULT 0,
        structure_id  BIGINT NULL,
        monthly_ctc   DECIMAL(12,2) NOT NULL DEFAULT 0,
        annual_ctc    DECIMAL(14,2) NOT NULL DEFAULT 0,
        components    INT NOT NULL DEFAULT 0
    );

    INSERT INTO tmp_hrms_cycle_emps (emp_id, emp_name)
    SELECT u.emp_id, COALESCE(n.emp_name, u.emp_id)
      FROM (SELECT DISTINCT TRIM(emp_id) AS emp_id FROM user_login_details
             WHERE LOWER(status) = 'active' AND emp_id IS NOT NULL AND TRIM(emp_id) <> '') u
      LEFT JOIN (SELECT emp_id, MAX(emp_name) AS emp_name FROM user_details GROUP BY emp_id) n ON n.emp_id = u.emp_id
     WHERE p_emp_filter IS NULL OR u.emp_id = p_emp_filter;

    UPDATE tmp_hrms_cycle_emps t
      JOIN payroll_attendance_summary a
        ON a.emp_id = t.emp_id AND a.payroll_month = v_month AND a.payroll_year = v_year
       SET t.has_att = 1,
           t.att_final = IF(a.is_finalized = 'Y', 1, 0),
           t.total_days = COALESCE(a.total_days, 0),
           t.paid_days = COALESCE(a.paid_days, 0),
           t.unpaid_days = COALESCE(a.unpaid_days, 0),
           t.absent_days = COALESCE(a.absent_days, 0);

    UPDATE tmp_hrms_cycle_emps t
       SET t.structure_id = (SELECT ss.structure_id FROM salary_structure ss
                              WHERE ss.emp_id = t.emp_id AND ss.structure_status = 'ACTIVE'
                                AND ss.effective_from <= v_end
                                AND (ss.effective_to IS NULL OR ss.effective_to >= v_start)
                              ORDER BY ss.effective_from DESC, ss.structure_id DESC LIMIT 1);

    UPDATE tmp_hrms_cycle_emps t
      JOIN salary_structure ss ON ss.structure_id = t.structure_id
       SET t.monthly_ctc = ss.monthly_ctc,
           t.annual_ctc = ss.annual_ctc,
           t.components = (SELECT COUNT(*) FROM employee_salary_structure e
                             JOIN salary_component_master m ON m.component_id = e.component_id AND m.is_active = 1
                            WHERE e.structure_id = ss.structure_id);
END$$

-- ---------------------------------------------------------------------
-- C-052  NEW PROCEDURE hrms_payroll_log   (helper)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_log$$
CREATE PROCEDURE hrms_payroll_log(
    IN p_cycle_id BIGINT, IN p_detail_id BIGINT, IN p_emp VARCHAR(20), IN p_action VARCHAR(40),
    IN p_from VARCHAR(30), IN p_to VARCHAR(30), IN p_remarks VARCHAR(500), IN p_by VARCHAR(20))
BEGIN
    INSERT INTO payroll_cycle_status_log
        (payroll_cycle_id, cycle_code, payroll_detail_id, emp_id, action, from_status, to_status, remarks, performed_by)
    VALUES (p_cycle_id, (SELECT MAX(cycle_code) FROM payroll_cycles WHERE payroll_cycle_id = p_cycle_id),
            p_detail_id, p_emp, p_action, p_from, p_to, LEFT(p_remarks, 500), p_by);
END$$

-- ---------------------------------------------------------------------
-- C-053  NEW PROCEDURE hrms_payroll_refresh_run_totals   (helper)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_refresh_run_totals$$
CREATE PROCEDURE hrms_payroll_refresh_run_totals(IN p_run_id BIGINT)
BEGIN
    UPDATE payroll_runs pr
      LEFT JOIN (SELECT payroll_run_id, COUNT(*) n, SUM(gross_earnings) g, SUM(total_deductions) d,
                        SUM(employer_contributions) e, SUM(net_pay) np
                   FROM employee_payroll_details WHERE payroll_run_id = p_run_id GROUP BY payroll_run_id) t
        ON t.payroll_run_id = pr.payroll_run_id
       SET pr.total_employees = COALESCE(t.n, 0),
           pr.total_earnings = COALESCE(t.g, 0),
           pr.total_deductions = COALESCE(t.d, 0),
           pr.total_employer_contributions = COALESCE(t.e, 0),
           pr.total_net_pay = COALESCE(t.np, 0)
     WHERE pr.payroll_run_id = p_run_id;
END$$

-- ---------------------------------------------------------------------
-- C-054  NEW PROCEDURE hrms_payroll_generate_payslips   (helper)
--        One payslip for every PAID employee of the cycle that has none.
--        p_detail_id given = only that employee.
--        C-089: safe when two calls run at the same moment (no duplicate).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_generate_payslips$$
CREATE PROCEDURE hrms_payroll_generate_payslips(
    IN p_cycle_id BIGINT, IN p_detail_id BIGINT, IN p_by VARCHAR(20), OUT p_created INT)
BEGIN
    DECLARE v_prefix VARCHAR(20);
    -- C-089: a second click at the same moment hits uq_eps_active_detail (C-088);
    -- the first call already made the payslips, so this one creates none
    DECLARE CONTINUE HANDLER FOR 1062 SET p_created = 0;
    SET p_created = 0;
    SELECT COALESCE(NULLIF(TRIM(MAX(payslip_prefix)), ''), 'PS-') INTO v_prefix FROM company_settings;
    SET v_prefix = COALESCE(v_prefix, 'PS-');

    INSERT INTO employee_payslips
        (payroll_detail_id, payslip_number, payslip_status, file_path, generated_by, generated_at)
    SELECT epd.payroll_detail_id,
           CONCAT(v_prefix, pc.payroll_year, '-', LPAD(pc.payroll_month, 2, '0'), '-',
                  REPLACE(TRIM(epd.emp_id), ' ', ''), '-', epd.payroll_detail_id),
           'GENERATED', NULL, p_by, NOW()
      FROM employee_payroll_details epd
      JOIN payroll_runs pr ON pr.payroll_run_id = epd.payroll_run_id
      JOIN payroll_cycles pc ON pc.payroll_cycle_id = pr.payroll_cycle_id
     WHERE pc.payroll_cycle_id = p_cycle_id
       AND (p_detail_id IS NULL OR epd.payroll_detail_id = p_detail_id)
       AND epd.payment_status = 'PAID'
       AND epd.employee_payroll_status <> 'CANCELLED'
       AND NOT EXISTS (SELECT 1 FROM employee_payslips x
                        WHERE x.payroll_detail_id = epd.payroll_detail_id AND x.payslip_status <> 'REVOKED');
    SET p_created = GREATEST(ROW_COUNT(), 0);
END$$

-- ---------------------------------------------------------------------
-- C-055  NEW PROCEDURE hrms_payroll_cycle_defaults
--        Suggested pay period, payment date and cycle code for a month,
--        from company_settings (payroll_cycle_start_day, payroll_cycle_end_day,
--        salary_pay_day). No settings = 1st to last day of the month.
--        C-116: p_emp_id (who is calling) added as the first parameter, with
--        the standard role check (active ADMIN or HR).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_cycle_defaults$$
CREATE PROCEDURE hrms_payroll_cycle_defaults(IN p_emp_id VARCHAR(20), IN p_month INT, IN p_year INT)
df: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-116
    DECLARE v_sd    INT;
    DECLARE v_ed    INT;
    DECLARE v_pd    INT;
    DECLARE v_first DATE;
    DECLARE v_prev  DATE;
    DECLARE v_start DATE;
    DECLARE v_end   DATE;
    DECLARE v_pay   DATE;
    DECLARE v_next  DATE;

    -- C-116: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can create payroll cycles.' AS remarks;
        LEAVE df;
    END IF;

    IF p_month IS NULL OR p_month NOT BETWEEN 1 AND 12 OR p_year IS NULL OR p_year NOT BETWEEN 2000 AND 2100 THEN
        SELECT 'N' AS status, 'Invalid payroll month or year.' AS remarks;
    ELSE
        SELECT MAX(payroll_cycle_start_day), MAX(payroll_cycle_end_day), MAX(salary_pay_day)
          INTO v_sd, v_ed, v_pd FROM company_settings;
        SET v_first = STR_TO_DATE(CONCAT(p_year, '-', p_month, '-01'), '%Y-%c-%d');
        SET v_prev  = DATE_SUB(v_first, INTERVAL 1 MONTH);

        IF v_sd IS NULL OR v_ed IS NULL OR v_sd NOT BETWEEN 1 AND 31 OR v_ed NOT BETWEEN 1 AND 31 THEN
            SET v_start = v_first;
            SET v_end   = LAST_DAY(v_first);
        ELSEIF v_sd > v_ed THEN
            SET v_start = DATE_ADD(v_prev, INTERVAL LEAST(v_sd, DAY(LAST_DAY(v_prev))) - 1 DAY);
            SET v_end   = DATE_ADD(v_first, INTERVAL LEAST(v_ed, DAY(LAST_DAY(v_first))) - 1 DAY);
        ELSE
            SET v_start = DATE_ADD(v_first, INTERVAL LEAST(v_sd, DAY(LAST_DAY(v_first))) - 1 DAY);
            SET v_end   = DATE_ADD(v_first, INTERVAL LEAST(v_ed, DAY(LAST_DAY(v_first))) - 1 DAY);
        END IF;

        IF v_pd IS NULL OR v_pd NOT BETWEEN 1 AND 31 THEN
            SET v_pay = v_end;
        ELSE
            SET v_next = DATE_ADD(DATE_FORMAT(v_end, '%Y-%m-01'), INTERVAL IF(v_pd <= DAY(v_end), 1, 0) MONTH);
            SET v_pay  = DATE_ADD(v_next, INTERVAL LEAST(v_pd, DAY(LAST_DAY(v_next))) - 1 DAY);
        END IF;

        SELECT 'Y' AS status, 'Defaults from company settings' AS remarks,
               v_start AS period_start, v_end AS period_end, v_pay AS payment_date,
               CONCAT('pay-', DATE_FORMAT(v_start, '%d%m'), '-', DATE_FORMAT(v_end, '%d%m'), '-', p_year) AS cycle_code,
               v_sd AS start_day, v_ed AS end_day, v_pd AS pay_day;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-056  NEW PROCEDURE hrms_payroll_cycle_create
--        Creates a cycle in status OPEN. Nothing is calculated yet.
--        Refused while another cycle is not CLOSED: only one payroll cycle
--        can be in progress at a time.
--        C-125: any month can be created (C-091 "no month earlier than the last
--        closed cycle" is removed), so a deleted or missed month can be created
--        again. Refused only when a cycle already exists for that month, the
--        code is taken, or the period overlaps another cycle.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_cycle_create$$
CREATE PROCEDURE hrms_payroll_cycle_create(
    IN p_emp_id       VARCHAR(20),
    IN p_month        INT,
    IN p_year         INT,
    IN p_cycle_code   VARCHAR(50),
    IN p_period_start DATE,
    IN p_period_end   DATE,
    IN p_payment_date DATE,
    IN p_remarks      VARCHAR(500)
)
cc: BEGIN
    DECLARE v_ok   TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_msg  VARCHAR(500) DEFAULT NULL;
    DECLARE v_n    INT DEFAULT 0;
    DECLARE v_code VARCHAR(50);
    DECLARE v_id   BIGINT;
    DECLARE v_err  VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'Payroll cycle could not be created.') AS remarks, NULL AS payroll_cycle_id;
    END;

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    SET v_code = TRIM(COALESCE(p_cycle_code, ''));

    IF v_ok = 0 THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can create payroll cycles.';
    ELSEIF p_month IS NULL OR p_month NOT BETWEEN 1 AND 12 OR p_year IS NULL OR p_year NOT BETWEEN 2000 AND 2100 THEN
        SET v_msg = 'Invalid payroll month or year.';
    ELSEIF v_code = '' THEN
        SET v_msg = 'Payroll cycle code is required.';
    ELSEIF p_period_start IS NULL OR p_period_end IS NULL THEN
        SET v_msg = 'Start date and end date are required.';
    ELSEIF p_period_start > p_period_end THEN
        SET v_msg = 'Start date cannot be after end date.';
    ELSEIF DATEDIFF(p_period_end, p_period_start) > 61 THEN
        SET v_msg = 'A pay period cannot be longer than 62 days.';
    ELSEIF p_payment_date IS NOT NULL AND p_payment_date < p_period_start THEN
        SET v_msg = 'Payment date cannot be before the start date.';
    END IF;

    -- C-125: any month may be created; only one cycle per month (checked first: clearest message)
    IF v_msg IS NULL THEN
        SELECT COUNT(*) INTO v_n FROM payroll_cycles WHERE payroll_month = p_month AND payroll_year = p_year;
        IF v_n > 0 THEN
            SET v_msg = CONCAT('A payroll cycle already exists for ',
                               ELT(p_month, 'January','February','March','April','May','June','July',
                                   'August','September','October','November','December'), ' ', p_year, '.');
        END IF;
    END IF;
    -- only one payroll cycle can be in progress at a time
    IF v_msg IS NULL THEN
        SELECT MIN(CONCAT('Payroll for ',
                          ELT(payroll_month, 'January','February','March','April','May','June','July',
                              'August','September','October','November','December'),
                          ' ', payroll_year, ' (', COALESCE(cycle_code, payroll_cycle_id), ') is still ', cycle_status,
                          '. Finish or delete it before creating another payroll cycle.'))
          INTO v_msg
          FROM payroll_cycles
         WHERE cycle_status <> 'CLOSED';
    END IF;
    IF v_msg IS NULL THEN
        SELECT COUNT(*) INTO v_n FROM payroll_cycles WHERE cycle_code = v_code;
        IF v_n > 0 THEN
            SET v_msg = CONCAT('Payroll cycle code already exists: ', v_code);
        END IF;
    END IF;
    IF v_msg IS NULL THEN
        SELECT MIN(CONCAT('The period overlaps the cycle ', COALESCE(cycle_code, payroll_cycle_id), ' (',
                          DATE_FORMAT(period_start, '%d %b %Y'), ' - ', DATE_FORMAT(period_end, '%d %b %Y'), ').'))
          INTO v_msg
          FROM payroll_cycles
         WHERE period_start <= p_period_end AND period_end >= p_period_start;
    END IF;

    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks, NULL AS payroll_cycle_id;
        LEAVE cc;
    END IF;

    START TRANSACTION;
    INSERT INTO payroll_cycles
        (cycle_code, payroll_month, payroll_year, period_start, period_end, payment_date, cycle_status, created_by, remarks)
    VALUES
        (v_code, p_month, p_year, p_period_start, p_period_end, p_payment_date, 'OPEN', p_emp_id, NULLIF(TRIM(p_remarks), ''));
    SET v_id = LAST_INSERT_ID();
    CALL hrms_payroll_log(v_id, NULL, NULL, 'CREATE', NULL, 'OPEN', CONCAT('Cycle ', v_code, ' created'), p_emp_id);
    COMMIT;

    SELECT 'Y' AS status, CONCAT('Payroll cycle ', v_code, ' created. Next: verify attendance.') AS remarks,
           v_id AS payroll_cycle_id;
END$$

-- ---------------------------------------------------------------------
-- C-057  NEW PROCEDURE hrms_payroll_cycle_list
--        Cycles of a year with the totals of their latest run.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_cycle_list$$
CREATE PROCEDURE hrms_payroll_cycle_list(IN p_emp_id VARCHAR(20), IN p_year INT)
BEGIN
    DECLARE v_ok TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    -- C-115: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view payroll cycles.' AS remarks, NULL AS payroll_cycle_id;
    ELSE
        SELECT 'Y' AS status, 'Payroll cycles retrieved' AS remarks,
               pc.payroll_cycle_id, pc.cycle_code, pc.payroll_month, MONTHNAME(pc.period_end) AS period_month_name,
               ELT(pc.payroll_month, 'January','February','March','April','May','June','July',
                   'August','September','October','November','December') AS month_name,
               pc.payroll_year, pc.period_start, pc.period_end, pc.payment_date, pc.cycle_status, pc.remarks,
               pr.payroll_run_id, COALESCE(pr.run_status, 'DRAFT') AS run_status,
               COALESCE(pr.total_employees, 0) AS total_employees,
               COALESCE(pr.total_earnings, 0) AS total_earnings,
               COALESCE(pr.total_deductions, 0) AS total_deductions,
               COALESCE(pr.total_net_pay, 0) AS total_net_pay,
               (SELECT COUNT(*) FROM employee_payroll_details d WHERE d.payroll_run_id = pr.payroll_run_id
                   AND d.payment_decision = 'HOLD' AND d.payment_status <> 'PAID') AS on_hold_count,
               (SELECT COUNT(*) FROM employee_payroll_details d WHERE d.payroll_run_id = pr.payroll_run_id
                   AND d.payment_status = 'PAID') AS paid_count,
               hrms_payroll_cycle_actions(pc.cycle_status) AS allowed_actions
          FROM payroll_cycles pc
          LEFT JOIN payroll_runs pr
            ON pr.payroll_run_id = (SELECT MAX(r.payroll_run_id) FROM payroll_runs r WHERE r.payroll_cycle_id = pc.payroll_cycle_id)
         WHERE p_year IS NULL OR pc.payroll_year = p_year
         ORDER BY pc.payroll_year DESC, pc.payroll_month DESC;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-058  NEW PROCEDURE hrms_payroll_cycle_get
--        One row: the cycle, its run, the counts behind every step and
--        the actions allowed now.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_cycle_get$$
CREATE PROCEDURE hrms_payroll_cycle_get(IN p_emp_id VARCHAR(20), IN p_cycle_id BIGINT)
BEGIN
    DECLARE v_ok       TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_n        INT DEFAULT 0;
    DECLARE v_run      BIGINT;
    DECLARE v_active   INT DEFAULT 0;
    DECLARE v_att_ok   INT DEFAULT 0;
    DECLARE v_att_miss VARCHAR(500);
    DECLARE v_str_ok   INT DEFAULT 0;
    DECLARE v_str_miss VARCHAR(500);

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    SELECT COUNT(*) INTO v_n FROM payroll_cycles WHERE payroll_cycle_id = p_cycle_id;

    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view payroll cycles.' AS remarks;
    ELSEIF v_n = 0 THEN
        SELECT 'N' AS status, 'Payroll cycle not found.' AS remarks;
    ELSE
        CALL hrms_payroll_load_cycle_emps(p_cycle_id, NULL);
        SELECT COUNT(*), COALESCE(SUM(att_final), 0), COALESCE(SUM(structure_id IS NOT NULL AND components > 0), 0)
          INTO v_active, v_att_ok, v_str_ok
          FROM tmp_hrms_cycle_emps;
        SELECT LEFT(GROUP_CONCAT(CONCAT(emp_id, ' ', emp_name) ORDER BY emp_id SEPARATOR ', '), 500) INTO v_att_miss
          FROM tmp_hrms_cycle_emps WHERE att_final = 0;
        SELECT LEFT(GROUP_CONCAT(CONCAT(emp_id, ' ', emp_name) ORDER BY emp_id SEPARATOR ', '), 500) INTO v_str_miss
          FROM tmp_hrms_cycle_emps WHERE structure_id IS NULL OR components = 0;
        SELECT MAX(payroll_run_id) INTO v_run FROM payroll_runs WHERE payroll_cycle_id = p_cycle_id;

        SELECT 'Y' AS status, 'Payroll cycle retrieved' AS remarks,
               pc.payroll_cycle_id, pc.cycle_code, pc.payroll_month,
               ELT(pc.payroll_month, 'January','February','March','April','May','June','July',
                   'August','September','October','November','December') AS month_name,
               pc.payroll_year, pc.period_start, pc.period_end, pc.payment_date, pc.cycle_status, pc.remarks AS cycle_remarks,
               pc.created_by, pc.created_at, pc.finalized_by, pc.finalized_at, pc.paid_by, pc.paid_at, pc.closed_by, pc.closed_at,
               hrms_payroll_cycle_actions(pc.cycle_status) AS allowed_actions,
               v_active AS active_employees,
               v_att_ok AS attendance_finalized, v_att_miss AS attendance_missing,
               v_str_ok AS structures_ready, v_str_miss AS structures_missing,
               v_run AS payroll_run_id, pr.run_status,
               COALESCE(pr.total_employees, 0) AS run_employees,
               COALESCE(pr.total_earnings, 0) AS total_earnings,
               COALESCE(pr.total_deductions, 0) AS total_deductions,
               COALESCE(pr.total_employer_contributions, 0) AS total_employer_contributions,
               COALESCE(pr.total_net_pay, 0) AS total_net_pay,
               (SELECT COUNT(*) FROM employee_payroll_details d WHERE d.payroll_run_id = v_run) AS detail_count,
               (SELECT COUNT(*) FROM employee_payroll_details d WHERE d.payroll_run_id = v_run AND d.employee_payroll_status = 'PENDING') AS pending_count,
               (SELECT COUNT(*) FROM employee_payroll_details d WHERE d.payroll_run_id = v_run AND d.employee_payroll_status = 'ERROR') AS error_count,
               (SELECT COUNT(*) FROM employee_payroll_details d WHERE d.payroll_run_id = v_run AND d.payment_decision = 'HOLD' AND d.payment_status <> 'PAID') AS on_hold_count,
               (SELECT COUNT(*) FROM employee_payroll_details d WHERE d.payroll_run_id = v_run AND d.payment_status = 'PAID') AS paid_count,
               (SELECT COUNT(*) FROM employee_payroll_details d WHERE d.payroll_run_id = v_run AND d.payment_status <> 'PAID') AS unpaid_count,
               (SELECT COUNT(*) FROM employee_payslips s JOIN employee_payroll_details d ON d.payroll_detail_id = s.payroll_detail_id
                 WHERE d.payroll_run_id = v_run AND s.payslip_status <> 'REVOKED') AS payslip_count,
               (SELECT COALESCE(SUM(d.net_pay), 0) FROM employee_payroll_details d WHERE d.payroll_run_id = v_run AND d.payment_status = 'PAID') AS paid_net_pay,
               (SELECT COALESCE(SUM(d.net_pay), 0) FROM employee_payroll_details d WHERE d.payroll_run_id = v_run AND d.payment_decision = 'HOLD' AND d.payment_status <> 'PAID') AS on_hold_net_pay
          FROM payroll_cycles pc
          LEFT JOIN payroll_runs pr ON pr.payroll_run_id = v_run
         WHERE pc.payroll_cycle_id = p_cycle_id;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-059  NEW PROCEDURE hrms_payroll_cycle_readiness
--        Attendance and salary structure of every active employee for the
--        cycle (used by the attendance and salary structure steps).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_cycle_readiness$$
CREATE PROCEDURE hrms_payroll_cycle_readiness(IN p_emp_id VARCHAR(20), IN p_cycle_id BIGINT)
BEGIN
    DECLARE v_ok TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    -- C-115: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view payroll cycles.' AS remarks, NULL AS emp_id;
    ELSE
        CALL hrms_payroll_load_cycle_emps(p_cycle_id, NULL);
        SELECT 'Y' AS status, '' AS remarks, t.emp_id, t.emp_name, t.has_att, t.att_final,
               t.total_days, t.paid_days, t.unpaid_days, t.absent_days,
               t.structure_id, t.monthly_ctc, t.annual_ctc, t.components,
               IF(t.structure_id IS NULL, NULL, (SELECT COUNT(*) FROM employee_salary_structure e
                                                  WHERE e.structure_id = t.structure_id AND e.is_overridden = 1)) AS overridden_components,
               (SELECT ROUND(MAX(x.monthly_amount), 2) FROM employee_salary_structure_totals x
                  JOIN salary_component_master m ON m.component_id = x.component_id
                 WHERE x.structure_id = t.structure_id AND m.component_code = 'NET_PAY') AS full_month_net_pay
          FROM tmp_hrms_cycle_emps t
         ORDER BY (t.att_final = 1 AND t.structure_id IS NOT NULL AND t.components > 0), t.emp_id;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-060  NEW PROCEDURE hrms_payroll_cycle_employees
--        Payroll result of every employee in the cycle's run.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_cycle_employees$$
CREATE PROCEDURE hrms_payroll_cycle_employees(IN p_emp_id VARCHAR(20), IN p_cycle_id BIGINT, IN p_filter VARCHAR(20))
BEGIN
    DECLARE v_ok  TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_run BIGINT;
    -- C-115: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    SELECT MAX(payroll_run_id) INTO v_run FROM payroll_runs WHERE payroll_cycle_id = p_cycle_id;
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view payroll cycles.' AS remarks, NULL AS payroll_detail_id;
    ELSE
        SELECT 'Y' AS status, '' AS remarks,
               d.payroll_detail_id, d.emp_id, COALESCE(n.emp_name, d.emp_id) AS emp_name,
               d.structure_id, d.monthly_ctc, d.total_days, d.payable_days, d.unpaid_leave_days, d.absent_days, d.ctc1,
               d.gross_earnings, d.total_deductions, d.employer_contributions, d.net_pay,
               d.employee_payroll_status, d.payment_decision, d.payment_status,
               d.hold_reason, d.hold_by, d.hold_at, d.released_by, d.released_at, d.paid_by, d.paid_at,
               d.calculation_remarks,
               (SELECT MAX(s.payslip_number) FROM employee_payslips s
                 WHERE s.payroll_detail_id = d.payroll_detail_id AND s.payslip_status <> 'REVOKED') AS payslip_number
          FROM employee_payroll_details d
          LEFT JOIN (SELECT emp_id, MAX(emp_name) AS emp_name FROM user_details GROUP BY emp_id) n ON n.emp_id = d.emp_id
         WHERE d.payroll_run_id = v_run
           AND (p_filter IS NULL OR p_filter = ''
                OR (p_filter = 'PENDING' AND d.employee_payroll_status IN ('PENDING', 'ERROR'))
                OR (p_filter = 'HOLD' AND d.payment_decision = 'HOLD' AND d.payment_status <> 'PAID')
                OR (p_filter = 'UNPAID' AND d.payment_status <> 'PAID'))
         ORDER BY d.emp_id;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-061  NEW PROCEDURE hrms_payroll_prepare_run   (helper)
--        Creates the run of a cycle if needed and one PENDING row for every
--        active employee (existing rows are reset to PENDING, a HOLD decision
--        is kept). Employees who are no longer active are removed.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_prepare_run$$
CREATE PROCEDURE hrms_payroll_prepare_run(IN p_cycle_id BIGINT, IN p_by VARCHAR(20), OUT p_run_id BIGINT, OUT p_count INT)
BEGIN
    CALL hrms_payroll_load_cycle_emps(p_cycle_id, NULL);

    SELECT MAX(payroll_run_id) INTO p_run_id FROM payroll_runs WHERE payroll_cycle_id = p_cycle_id;
    IF p_run_id IS NULL THEN
        INSERT INTO payroll_runs (payroll_cycle_id, run_number, run_type, run_status, total_employees, created_by)
        VALUES (p_cycle_id, 1, 'REGULAR', 'DRAFT', 0, p_by);
        SET p_run_id = LAST_INSERT_ID();
    END IF;

    DELETE c FROM employee_payroll_component_details c
      JOIN employee_payroll_details d ON d.payroll_detail_id = c.payroll_detail_id
     WHERE d.payroll_run_id = p_run_id
       AND NOT EXISTS (SELECT 1 FROM tmp_hrms_cycle_emps t WHERE t.emp_id = d.emp_id);
    DELETE d FROM employee_payroll_details d
     WHERE d.payroll_run_id = p_run_id
       AND NOT EXISTS (SELECT 1 FROM tmp_hrms_cycle_emps t WHERE t.emp_id = d.emp_id);

    INSERT INTO employee_payroll_details
        (payroll_run_id, emp_id, structure_id, monthly_ctc, annual_ctc, total_days, payable_days, paid_leave_days,
         unpaid_leave_days, absent_days, ctc1, gross_earnings, total_deductions, employer_contributions, net_pay,
         calculation_version, calculation_remarks, employee_payroll_status)
    SELECT p_run_id, t.emp_id, t.structure_id, t.monthly_ctc, t.annual_ctc, t.total_days,
           hrms_pay_days(t.unpaid_days), 0, t.unpaid_days, t.absent_days,
           ROUND(t.monthly_ctc * hrms_pay_days(t.unpaid_days) / 30, 2), 0, 0, 0, 0,
           1, 'Waiting to be calculated.', 'PENDING'
      FROM tmp_hrms_cycle_emps t
    ON DUPLICATE KEY UPDATE
           structure_id = VALUES(structure_id), monthly_ctc = VALUES(monthly_ctc), annual_ctc = VALUES(annual_ctc),
           total_days = VALUES(total_days), payable_days = VALUES(payable_days),
           unpaid_leave_days = VALUES(unpaid_leave_days), absent_days = VALUES(absent_days), ctc1 = VALUES(ctc1),
           calculation_version = employee_payroll_details.calculation_version + 1,
           calculation_remarks = 'Waiting to be calculated.', employee_payroll_status = 'PENDING';

    SELECT COUNT(*) INTO p_count FROM employee_payroll_details WHERE payroll_run_id = p_run_id;
    UPDATE payroll_runs SET run_status = 'DRAFT', total_employees = p_count WHERE payroll_run_id = p_run_id;
END$$

-- ---------------------------------------------------------------------
-- C-062  NEW PROCEDURE hrms_payroll_cycle_action   (cycle status engine)
--        C-114: attendance steps also need paid + unpaid = days of the period.
--   p_action: VERIFY_ATTENDANCE, VERIFY_STRUCTURE, START_CALCULATION,
--             RECALCULATE, FINISH_CALCULATION, APPROVE, FINALIZE,
--             MARK_PAID, GENERATE_PAYSLIPS, CLOSE, BACK
--   Only the actions of hrms_payroll_cycle_actions(current status) are
--   accepted. Returns: status, remarks, payroll_cycle_id, cycle_status,
--   pending_count.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_cycle_action$$
CREATE PROCEDURE hrms_payroll_cycle_action(
    IN p_emp_id   VARCHAR(20),
    IN p_cycle_id BIGINT,
    IN p_action   VARCHAR(40),
    IN p_remarks  VARCHAR(500)
)
ca: BEGIN
    DECLARE v_ok      TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_action  VARCHAR(40);
    DECLARE v_status  VARCHAR(30);
    DECLARE v_new     VARCHAR(30);
    DECLARE v_msg     VARCHAR(500) DEFAULT NULL;
    DECLARE v_done    VARCHAR(500) DEFAULT NULL;
    DECLARE v_run     BIGINT;
    DECLARE v_n       INT DEFAULT 0;
    DECLARE v_m       INT DEFAULT 0;
    DECLARE v_list    VARCHAR(500);
    DECLARE v_pending INT DEFAULT 0;
    DECLARE v_allowed VARCHAR(200) DEFAULT '';
    DECLARE v_err     VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'The step could not be completed. Nothing was changed.') AS remarks,
               p_cycle_id AS payroll_cycle_id, v_status AS cycle_status, 0 AS pending_count;
    END;

    SET v_action = UPPER(TRIM(COALESCE(p_action, '')));
    -- C-115: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can run payroll.' AS remarks,
               p_cycle_id AS payroll_cycle_id, NULL AS cycle_status, 0 AS pending_count;
        LEAVE ca;
    END IF;

    START TRANSACTION;
    SELECT MAX(cycle_status) INTO v_status FROM payroll_cycles WHERE payroll_cycle_id = p_cycle_id FOR UPDATE;
    SELECT MAX(payroll_run_id) INTO v_run FROM payroll_runs WHERE payroll_cycle_id = p_cycle_id;
    SET v_allowed = COALESCE(hrms_payroll_cycle_actions(v_status), '');
    SET SESSION group_concat_max_len = 1000000;

    IF v_status IS NULL THEN
        SET v_msg = 'Payroll cycle not found.';
    ELSEIF FIND_IN_SET(v_action, v_allowed) = 0 THEN
        SET v_msg = IF(v_action = 'BACK',
                       CONCAT('A cycle in status ', v_status, ' cannot go back.'),
                       CONCAT('"', v_action, '" is not allowed while the cycle is ', v_status,
                              IF(v_allowed = '', '.', CONCAT('. Allowed: ', REPLACE(v_allowed, ',', ', '), '.'))));
    END IF;

    -- ---------------- BACK ----------------
    IF v_msg IS NULL AND v_action = 'BACK' THEN
        SET v_new = CASE v_status
            WHEN 'ATTENDANCE_VERIFIED' THEN 'OPEN'
            WHEN 'STRUCTURE_VERIFIED'  THEN 'ATTENDANCE_VERIFIED'
            WHEN 'PROCESSING'          THEN 'STRUCTURE_VERIFIED'
            WHEN 'CALCULATED'          THEN 'STRUCTURE_VERIFIED'
            WHEN 'APPROVED'            THEN 'CALCULATED' END;
        IF v_status IN ('PROCESSING', 'CALCULATED') AND v_run IS NOT NULL THEN
            UPDATE employee_payroll_details
               SET employee_payroll_status = 'PENDING', calculation_remarks = 'Sent back: recalculate after the changes.'
             WHERE payroll_run_id = v_run;
            UPDATE payroll_runs SET run_status = 'DRAFT' WHERE payroll_run_id = v_run;
            SET v_done = 'Back to salary structures. Employee results will be calculated again.';
        ELSEIF v_status = 'APPROVED' THEN
            UPDATE employee_payroll_details SET employee_payroll_status = 'CALCULATED'
             WHERE payroll_run_id = v_run AND employee_payroll_status = 'APPROVED';
            UPDATE payroll_runs SET run_status = 'CALCULATED', approved_by = NULL, approved_at = NULL WHERE payroll_run_id = v_run;
            SET v_done = 'Approval withdrawn. The payroll is back to CALCULATED.';
        ELSE
            SET v_done = CONCAT('Moved back to ', v_new, '.');
        END IF;
    END IF;

    -- ---------------- VERIFY_ATTENDANCE / VERIFY_STRUCTURE / START / RECALCULATE ----------------
    IF v_msg IS NULL AND v_action IN ('VERIFY_ATTENDANCE', 'VERIFY_STRUCTURE', 'START_CALCULATION', 'RECALCULATE') THEN
        CALL hrms_payroll_load_cycle_emps(p_cycle_id, NULL);
        SELECT COUNT(*), COALESCE(SUM(att_final = 0), 0) INTO v_n, v_m FROM tmp_hrms_cycle_emps;
        IF v_n = 0 THEN
            SET v_msg = 'There are no active employees.';
        ELSEIF v_m > 0 THEN
            SELECT LEFT(CONCAT(v_m, ' employee(s) have no finalized attendance for this month: ',
                               GROUP_CONCAT(CONCAT(emp_id, ' ', emp_name) ORDER BY emp_id SEPARATOR ', ')), 500)
              INTO v_msg FROM tmp_hrms_cycle_emps WHERE att_final = 0;
        END IF;
        -- C-114: pay days are 30 - unpaid days, so a day without a status would be paid.
        -- Paid + unpaid days must equal the days of the period for every employee.
        IF v_msg IS NULL THEN
            SELECT COUNT(*) INTO v_m FROM tmp_hrms_cycle_emps
             WHERE att_final = 1 AND ABS(COALESCE(paid_days, 0) + COALESCE(unpaid_days, 0) - COALESCE(total_days, 0)) > 0.01;
            IF v_m > 0 THEN
                SELECT LEFT(CONCAT(v_m, ' employee(s) have attendance that does not add up (paid + unpaid days is not the ',
                                   'days of the period), so their pay days cannot be trusted. Correct the attendance first: ',
                                   GROUP_CONCAT(CONCAT(emp_id, ' ', COALESCE(paid_days, 0), '+', COALESCE(unpaid_days, 0), '/', COALESCE(total_days, 0))
                                                ORDER BY emp_id SEPARATOR ', ')), 500)
                  INTO v_msg FROM tmp_hrms_cycle_emps
                 WHERE att_final = 1 AND ABS(COALESCE(paid_days, 0) + COALESCE(unpaid_days, 0) - COALESCE(total_days, 0)) > 0.01;
            END IF;
        END IF;
    END IF;
    IF v_msg IS NULL AND v_action IN ('VERIFY_STRUCTURE', 'START_CALCULATION', 'RECALCULATE') THEN
        SELECT COUNT(*) INTO v_m FROM tmp_hrms_cycle_emps WHERE structure_id IS NULL OR components = 0;
        IF v_m > 0 THEN
            SELECT LEFT(CONCAT(v_m, ' employee(s) have no active salary structure for this pay period: ',
                               GROUP_CONCAT(CONCAT(emp_id, ' ', emp_name) ORDER BY emp_id SEPARATOR ', ')), 500)
              INTO v_msg FROM tmp_hrms_cycle_emps WHERE structure_id IS NULL OR components = 0;
        END IF;
    END IF;
    IF v_msg IS NULL AND v_action = 'VERIFY_ATTENDANCE' THEN
        SET v_new = 'ATTENDANCE_VERIFIED';
        SET v_done = CONCAT('Attendance of all ', v_n, ' employees is finalized. Next: check the salary structures.');
    END IF;
    IF v_msg IS NULL AND v_action = 'VERIFY_STRUCTURE' THEN
        SET v_new = 'STRUCTURE_VERIFIED';
        SET v_done = CONCAT('All ', v_n, ' employees have a salary structure. Next: calculate salaries.');
    END IF;
    IF v_msg IS NULL AND v_action IN ('START_CALCULATION', 'RECALCULATE') THEN
        CALL hrms_payroll_prepare_run(p_cycle_id, p_emp_id, v_run, v_pending);
        SET v_new = 'PROCESSING';
        SET v_done = CONCAT(v_pending, ' employees are ready to be calculated.');
    END IF;

    -- ---------------- FINISH_CALCULATION ----------------
    IF v_msg IS NULL AND v_action = 'FINISH_CALCULATION' THEN
        SELECT COUNT(*), COALESCE(SUM(employee_payroll_status = 'PENDING'), 0), COALESCE(SUM(employee_payroll_status = 'ERROR'), 0)
          INTO v_n, v_pending, v_m
          FROM employee_payroll_details WHERE payroll_run_id = v_run;
        IF v_n = 0 THEN
            SET v_msg = 'No employees in this payroll yet. Start the calculation first.';
        ELSEIF v_pending > 0 THEN
            SET v_msg = CONCAT(v_pending, ' employee(s) are not calculated yet.');
        ELSEIF v_m > 0 THEN
            SET v_msg = CONCAT(v_m, ' employee(s) could not be calculated. Fix them and calculate them again.');
        ELSE
            CALL hrms_payroll_refresh_run_totals(v_run);
            UPDATE payroll_runs SET run_status = 'CALCULATED', calculated_by = p_emp_id, calculated_at = NOW()
             WHERE payroll_run_id = v_run;
            SET v_new = 'CALCULATED';
            SET v_done = CONCAT('Salaries of ', v_n, ' employees calculated. Review, put employees on hold if needed, then approve.');
        END IF;
    END IF;

    -- ---------------- APPROVE ----------------
    IF v_msg IS NULL AND v_action = 'APPROVE' THEN
        SELECT COUNT(*) INTO v_m FROM employee_payroll_details
         WHERE payroll_run_id = v_run AND employee_payroll_status IN ('PENDING', 'ERROR');
        IF v_m > 0 THEN
            SET v_msg = CONCAT(v_m, ' employee(s) are not calculated. Recalculate them before approving.');
        ELSE
            CALL hrms_payroll_refresh_run_totals(v_run);
            UPDATE employee_payroll_details SET employee_payroll_status = 'APPROVED'
             WHERE payroll_run_id = v_run AND employee_payroll_status = 'CALCULATED';
            UPDATE payroll_runs SET run_status = 'APPROVED', approved_by = p_emp_id, approved_at = NOW()
             WHERE payroll_run_id = v_run;
            SET v_new = 'APPROVED';
            SET v_done = 'Payroll approved. Next: finalize (after that the cycle cannot go back).';
        END IF;
    END IF;

    -- ---------------- FINALIZE ----------------
    IF v_msg IS NULL AND v_action = 'FINALIZE' THEN
        UPDATE employee_payroll_details SET employee_payroll_status = 'FINALIZED'
         WHERE payroll_run_id = v_run AND employee_payroll_status = 'APPROVED';
        UPDATE payroll_runs SET run_status = 'FINALIZED', finalized_by = p_emp_id, finalized_at = NOW()
         WHERE payroll_run_id = v_run;
        UPDATE payroll_cycles SET finalized_by = p_emp_id, finalized_at = NOW() WHERE payroll_cycle_id = p_cycle_id;
        SET v_new = 'FINALIZED';
        SET v_done = 'Payroll finalized. Next: mark as paid.';
    END IF;

    -- ---------------- MARK_PAID ----------------
    IF v_msg IS NULL AND v_action = 'MARK_PAID' THEN
        UPDATE employee_payroll_details
           SET payment_status = 'PAID', paid_by = p_emp_id, paid_at = NOW()
         WHERE payroll_run_id = v_run AND payment_decision = 'RELEASE' AND payment_status <> 'PAID';
        SET v_n = ROW_COUNT();
        UPDATE employee_payroll_details SET payment_status = 'ON_HOLD'
         WHERE payroll_run_id = v_run AND payment_decision = 'HOLD' AND payment_status <> 'PAID';
        SET v_m = ROW_COUNT();
        UPDATE payroll_cycles SET paid_by = p_emp_id, paid_at = NOW() WHERE payroll_cycle_id = p_cycle_id;
        SET v_new = IF(v_m > 0, 'PARTIALLY_PAID', 'PAID');
        SET v_done = IF(v_m > 0,
            CONCAT(v_n, ' employees marked as paid. ', v_m, ' employee(s) are on hold: pay them from the hold list. Next: generate payslips.'),
            CONCAT(v_n, ' employees marked as paid. Next: generate payslips.'));
    END IF;

    -- ---------------- GENERATE_PAYSLIPS ----------------
    IF v_msg IS NULL AND v_action = 'GENERATE_PAYSLIPS' THEN
        CALL hrms_payroll_generate_payslips(p_cycle_id, NULL, p_emp_id, v_n);
        SET v_new = v_status;
        SET v_done = CONCAT(v_n, ' payslip(s) generated',
                            IF(v_status = 'PAID', '. Next: close the cycle.', '. Employees on hold get a payslip when they are paid.'));
    END IF;

    -- ---------------- CLOSE ----------------
    IF v_msg IS NULL AND v_action = 'CLOSE' THEN
        SELECT COUNT(*) INTO v_m FROM employee_payroll_details WHERE payroll_run_id = v_run AND payment_status <> 'PAID';
        SELECT COUNT(*) INTO v_n FROM employee_payroll_details d
         WHERE d.payroll_run_id = v_run AND d.payment_status = 'PAID'
           AND NOT EXISTS (SELECT 1 FROM employee_payslips s WHERE s.payroll_detail_id = d.payroll_detail_id AND s.payslip_status <> 'REVOKED');
        IF v_m > 0 THEN
            SET v_msg = CONCAT(v_m, ' employee(s) are not paid yet. The cycle cannot be closed.');
        ELSEIF v_n > 0 THEN
            SET v_msg = CONCAT(v_n, ' paid employee(s) have no payslip yet. Generate payslips first.');
        ELSE
            UPDATE payroll_cycles SET closed_by = p_emp_id, closed_at = NOW() WHERE payroll_cycle_id = p_cycle_id;
            SET v_new = 'CLOSED';
            SET v_done = 'Payroll cycle closed.';
        END IF;
    END IF;

    IF v_msg IS NOT NULL THEN
        ROLLBACK;
        SELECT 'N' AS status, v_msg AS remarks, p_cycle_id AS payroll_cycle_id, v_status AS cycle_status, 0 AS pending_count;
        LEAVE ca;
    END IF;

    UPDATE payroll_cycles SET cycle_status = v_new WHERE payroll_cycle_id = p_cycle_id;
    CALL hrms_payroll_log(p_cycle_id, NULL, NULL, v_action, v_status, v_new,
                          CONCAT(v_done, IF(NULLIF(TRIM(p_remarks), '') IS NULL, '', CONCAT(' Note: ', TRIM(p_remarks)))), p_emp_id);
    COMMIT;

    SELECT COUNT(*) INTO v_pending FROM employee_payroll_details
     WHERE payroll_run_id = v_run AND employee_payroll_status IN ('PENDING', 'ERROR');
    SELECT 'Y' AS status, v_done AS remarks, p_cycle_id AS payroll_cycle_id, v_new AS cycle_status, v_pending AS pending_count;
END$$

-- ---------------------------------------------------------------------
-- C-063  NEW PROCEDURE hrms_payroll_calculate_employee
--        Calculates ONE employee of a cycle with the salary engine. The page
--        calls it once per employee to show the progress. Attendance, CTC
--        and salary structure are read again first, so a change made in the
--        salary structure page is picked up.
--        Allowed while the cycle is PROCESSING, or CALCULATED (recalculate
--        one employee after a change).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_calculate_employee$$
CREATE PROCEDURE hrms_payroll_calculate_employee(IN p_emp_id VARCHAR(20), IN p_cycle_id BIGINT, IN p_detail_id BIGINT)
ce: BEGIN
    DECLARE v_ok      TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_status  VARCHAR(30);
    DECLARE v_run     BIGINT;
    DECLARE v_emp     VARCHAR(20);
    DECLARE v_name    VARCHAR(150);
    DECLARE v_dstat   VARCHAR(30);
    DECLARE v_msg     VARCHAR(500) DEFAULT NULL;
    DECLARE v_errs    INT DEFAULT 0;
    DECLARE v_text    VARCHAR(500);
    DECLARE v_net     DECIMAL(14,2);
    DECLARE v_left    INT DEFAULT 0;
    DECLARE v_failed  INT DEFAULT 0;
    DECLARE v_n       INT DEFAULT 0;
    DECLARE v_err     VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        UPDATE employee_payroll_details
           SET employee_payroll_status = 'ERROR', calculation_remarks = LEFT(CONCAT('Calculation failed: ', COALESCE(v_err, '?')), 1000)
         WHERE payroll_detail_id = p_detail_id AND employee_payroll_status IN ('PENDING', 'ERROR', 'CALCULATED');
        SELECT 'N' AS status, COALESCE(v_err, 'Calculation failed.') AS remarks, p_detail_id AS payroll_detail_id,
               v_emp AS emp_id, v_name AS emp_name, NULL AS net_pay, NULL AS pending_left, NULL AS error_count;
    END;

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    SELECT MAX(pc.cycle_status), MAX(pr.payroll_run_id) INTO v_status, v_run
      FROM payroll_cycles pc LEFT JOIN payroll_runs pr ON pr.payroll_cycle_id = pc.payroll_cycle_id
     WHERE pc.payroll_cycle_id = p_cycle_id;
    SELECT MAX(d.emp_id), MAX(d.employee_payroll_status) INTO v_emp, v_dstat
      FROM employee_payroll_details d WHERE d.payroll_detail_id = p_detail_id AND d.payroll_run_id = v_run;
    SELECT MAX(emp_name) INTO v_name FROM user_details WHERE emp_id = v_emp;
    SET v_name = COALESCE(v_name, v_emp);

    IF v_ok = 0 THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can run payroll.';
    ELSEIF v_status IS NULL THEN
        SET v_msg = 'Payroll cycle not found.';
    ELSEIF v_status NOT IN ('PROCESSING', 'CALCULATED') THEN
        SET v_msg = CONCAT('Salaries can be calculated only while the cycle is PROCESSING or CALCULATED (now ', v_status, ').');
    ELSEIF v_emp IS NULL THEN
        SET v_msg = 'This employee is not part of the payroll cycle.';
    ELSEIF v_dstat NOT IN ('PENDING', 'ERROR', 'CALCULATED') THEN
        SET v_msg = CONCAT('Employee is ', v_dstat, ' and cannot be recalculated.');
    END IF;

    IF v_msg IS NULL THEN
        CALL hrms_payroll_load_cycle_emps(p_cycle_id, v_emp);
        SELECT COUNT(*) INTO v_n FROM tmp_hrms_cycle_emps WHERE att_final = 1 AND structure_id IS NOT NULL AND components > 0;
        IF v_n = 0 THEN
            SET v_msg = 'Attendance is not finalized or the employee has no active salary structure for this pay period.';
        END IF;
    END IF;

    IF v_msg IS NOT NULL THEN
        IF v_emp IS NOT NULL AND v_dstat IN ('PENDING', 'ERROR', 'CALCULATED') AND v_status IN ('PROCESSING', 'CALCULATED') THEN
            UPDATE employee_payroll_details SET employee_payroll_status = 'ERROR', calculation_remarks = v_msg
             WHERE payroll_detail_id = p_detail_id;
        END IF;
        SELECT 'N' AS status, v_msg AS remarks, p_detail_id AS payroll_detail_id, v_emp AS emp_id, v_name AS emp_name,
               NULL AS net_pay, NULL AS pending_left, NULL AS error_count;
        LEAVE ce;
    END IF;

    START TRANSACTION;
    UPDATE employee_payroll_details d
      JOIN tmp_hrms_cycle_emps t ON t.emp_id = d.emp_id
       SET d.structure_id = t.structure_id, d.monthly_ctc = t.monthly_ctc, d.annual_ctc = t.annual_ctc,
           d.total_days = t.total_days, d.payable_days = hrms_pay_days(t.unpaid_days),
           d.unpaid_leave_days = t.unpaid_days, d.absent_days = t.absent_days,
           d.ctc1 = ROUND(t.monthly_ctc * hrms_pay_days(t.unpaid_days) / 30, 2),
           d.calculation_remarks = CONCAT('Pay days ', hrms_pay_days(t.unpaid_days), ' of 30 (30 - ', t.unpaid_days, ' unpaid days).')
     WHERE d.payroll_detail_id = p_detail_id;

    CALL hrms_calculate_payroll_detail(p_detail_id, v_errs, v_text);
    IF v_errs > 0 THEN
        UPDATE employee_payroll_details
           SET employee_payroll_status = 'ERROR', calculation_remarks = LEFT(COALESCE(v_text, 'Calculation failed.'), 1000)
         WHERE payroll_detail_id = p_detail_id;
    END IF;
    IF v_status = 'CALCULATED' THEN
        CALL hrms_payroll_refresh_run_totals(v_run);
        CALL hrms_payroll_log(p_cycle_id, p_detail_id, v_emp, 'RECALCULATE_EMPLOYEE', v_dstat,
                              IF(v_errs > 0, 'ERROR', 'CALCULATED'), COALESCE(v_text, 'Recalculated'), p_emp_id);
    END IF;
    COMMIT;

    SELECT MAX(net_pay) INTO v_net FROM employee_payroll_details WHERE payroll_detail_id = p_detail_id;
    SELECT COALESCE(SUM(employee_payroll_status = 'PENDING'), 0), COALESCE(SUM(employee_payroll_status = 'ERROR'), 0)
      INTO v_left, v_failed FROM employee_payroll_details WHERE payroll_run_id = v_run;

    SELECT IF(v_errs > 0, 'N', 'Y') AS status,
           IF(v_errs > 0, COALESCE(v_text, 'Calculation failed.'), CONCAT('Net pay ', FORMAT(v_net, 2))) AS remarks,
           p_detail_id AS payroll_detail_id, v_emp AS emp_id, v_name AS emp_name,
           v_net AS net_pay, v_left AS pending_left, v_failed AS error_count;
END$$

-- ---------------------------------------------------------------------
-- C-064  NEW PROCEDURE hrms_payroll_employee_hold
--        p_action HOLD (reason required) or RELEASE, for one employee.
--        Allowed while the cycle is CALCULATED, APPROVED, FINALIZED or
--        PARTIALLY_PAID, and only for an employee not paid yet.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_employee_hold$$
CREATE PROCEDURE hrms_payroll_employee_hold(
    IN p_emp_id    VARCHAR(20),
    IN p_detail_id BIGINT,
    IN p_action    VARCHAR(20),
    IN p_reason    VARCHAR(500)
)
eh: BEGIN
    DECLARE v_ok     TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_action VARCHAR(20);
    DECLARE v_cycle  BIGINT;
    DECLARE v_status VARCHAR(30);
    DECLARE v_emp    VARCHAR(20);
    DECLARE v_dec    VARCHAR(20);
    DECLARE v_pay    VARCHAR(20);
    DECLARE v_msg    VARCHAR(500) DEFAULT NULL;
    DECLARE v_err    VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'Hold could not be changed.') AS remarks, p_detail_id AS payroll_detail_id;
    END;

    SET v_action = UPPER(TRIM(COALESCE(p_action, '')));
    -- C-115: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    SELECT MAX(pc.payroll_cycle_id), MAX(pc.cycle_status), MAX(d.emp_id), MAX(d.payment_decision), MAX(d.payment_status)
      INTO v_cycle, v_status, v_emp, v_dec, v_pay
      FROM employee_payroll_details d
      JOIN payroll_runs pr ON pr.payroll_run_id = d.payroll_run_id
      JOIN payroll_cycles pc ON pc.payroll_cycle_id = pr.payroll_cycle_id
     WHERE d.payroll_detail_id = p_detail_id;

    IF v_ok = 0 THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can hold or release salaries.';
    ELSEIF v_emp IS NULL THEN
        SET v_msg = 'Employee payroll row not found.';
    ELSEIF v_action NOT IN ('HOLD', 'RELEASE') THEN
        SET v_msg = 'Action must be HOLD or RELEASE.';
    ELSEIF v_status NOT IN ('CALCULATED', 'APPROVED', 'FINALIZED', 'PARTIALLY_PAID') THEN
        SET v_msg = CONCAT('Salaries can be held or released only after calculation and before the cycle is fully paid (now ', v_status, ').');
    ELSEIF v_pay = 'PAID' THEN
        SET v_msg = 'This employee is already paid.';
    ELSEIF v_action = 'HOLD' AND NULLIF(TRIM(p_reason), '') IS NULL THEN
        SET v_msg = 'A reason is required to hold a salary.';
    ELSEIF v_action = 'HOLD' AND v_dec = 'HOLD' THEN
        SET v_msg = 'This salary is already on hold.';
    ELSEIF v_action = 'RELEASE' AND v_dec = 'RELEASE' THEN
        SET v_msg = 'This salary is not on hold.';
    END IF;

    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks, p_detail_id AS payroll_detail_id;
        LEAVE eh;
    END IF;

    START TRANSACTION;
    IF v_action = 'HOLD' THEN
        UPDATE employee_payroll_details
           SET payment_decision = 'HOLD', hold_reason = TRIM(p_reason), hold_by = p_emp_id, hold_at = NOW(),
               payment_status = IF(v_status = 'PARTIALLY_PAID', 'ON_HOLD', payment_status)
         WHERE payroll_detail_id = p_detail_id;
    ELSE
        UPDATE employee_payroll_details
           SET payment_decision = 'RELEASE', released_by = p_emp_id, released_at = NOW(),
               payment_status = IF(payment_status = 'ON_HOLD', 'NOT_PAID', payment_status)
         WHERE payroll_detail_id = p_detail_id;
    END IF;
    CALL hrms_payroll_log(v_cycle, p_detail_id, v_emp, CONCAT('EMPLOYEE_', v_action), v_dec, v_action,
                          COALESCE(NULLIF(TRIM(p_reason), ''), CONCAT('Salary ', LOWER(v_action), 'd')), p_emp_id);
    COMMIT;

    SELECT 'Y' AS status,
           IF(v_action = 'HOLD', CONCAT('Salary of ', v_emp, ' is on hold.'),
              CONCAT('Salary of ', v_emp, ' released', IF(v_status = 'PARTIALLY_PAID', '. Pay it from the hold list.', '.'))) AS remarks,
           p_detail_id AS payroll_detail_id;
END$$

-- ---------------------------------------------------------------------
-- C-065  NEW PROCEDURE hrms_payroll_employee_pay
--        Pays one employee who was held when the cycle was marked paid
--        (cycle PARTIALLY_PAID): release, mark paid and generate the payslip.
--        When nobody is left unpaid the cycle becomes PAID.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_employee_pay$$
CREATE PROCEDURE hrms_payroll_employee_pay(IN p_emp_id VARCHAR(20), IN p_detail_id BIGINT, IN p_remarks VARCHAR(500))
ep: BEGIN
    DECLARE v_ok     TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_cycle  BIGINT;
    DECLARE v_run    BIGINT;
    DECLARE v_status VARCHAR(30);
    DECLARE v_emp    VARCHAR(20);
    DECLARE v_dec    VARCHAR(20);
    DECLARE v_pay    VARCHAR(20);
    DECLARE v_left   INT DEFAULT 0;
    DECLARE v_slips  INT DEFAULT 0;
    DECLARE v_msg    VARCHAR(500) DEFAULT NULL;
    DECLARE v_err    VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'Payment could not be recorded.') AS remarks,
               p_detail_id AS payroll_detail_id, NULL AS cycle_status;
    END;

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    SELECT MAX(pc.payroll_cycle_id), MAX(pr.payroll_run_id), MAX(pc.cycle_status), MAX(d.emp_id),
           MAX(d.payment_decision), MAX(d.payment_status)
      INTO v_cycle, v_run, v_status, v_emp, v_dec, v_pay
      FROM employee_payroll_details d
      JOIN payroll_runs pr ON pr.payroll_run_id = d.payroll_run_id
      JOIN payroll_cycles pc ON pc.payroll_cycle_id = pr.payroll_cycle_id
     WHERE d.payroll_detail_id = p_detail_id;

    IF v_ok = 0 THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can record payments.';
    ELSEIF v_emp IS NULL THEN
        SET v_msg = 'Employee payroll row not found.';
    ELSEIF v_status <> 'PARTIALLY_PAID' THEN
        SET v_msg = CONCAT('Single payments are made only for held salaries after the cycle is marked paid (now ', v_status, ').');
    ELSEIF v_pay = 'PAID' THEN
        SET v_msg = 'This employee is already paid.';
    END IF;
    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks, p_detail_id AS payroll_detail_id, v_status AS cycle_status;
        LEAVE ep;
    END IF;

    START TRANSACTION;
    UPDATE payroll_cycles SET cycle_status = cycle_status WHERE payroll_cycle_id = v_cycle;
    UPDATE employee_payroll_details
       SET released_by = IF(payment_decision = 'HOLD', p_emp_id, released_by),
           released_at = IF(payment_decision = 'HOLD', NOW(), released_at),
           payment_decision = 'RELEASE', payment_status = 'PAID', paid_by = p_emp_id, paid_at = NOW()
     WHERE payroll_detail_id = p_detail_id;
    CALL hrms_payroll_generate_payslips(v_cycle, p_detail_id, p_emp_id, v_slips);
    CALL hrms_payroll_log(v_cycle, p_detail_id, v_emp, 'EMPLOYEE_PAID', v_pay, 'PAID',
                          COALESCE(NULLIF(TRIM(p_remarks), ''), 'Held salary paid'), p_emp_id);

    SELECT COUNT(*) INTO v_left FROM employee_payroll_details WHERE payroll_run_id = v_run AND payment_status <> 'PAID';
    IF v_left = 0 THEN
        UPDATE payroll_cycles SET cycle_status = 'PAID' WHERE payroll_cycle_id = v_cycle;
        CALL hrms_payroll_log(v_cycle, NULL, NULL, 'ALL_PAID', 'PARTIALLY_PAID', 'PAID', 'Last held salary paid', p_emp_id);
    END IF;
    COMMIT;

    SELECT 'Y' AS status,
           CONCAT('Salary of ', v_emp, ' paid', IF(v_slips > 0, ' and payslip generated', ''),
                  IF(v_left = 0, '. Everybody is paid: the cycle can now be closed.', CONCAT('. Still unpaid: ', v_left, '.'))) AS remarks,
           p_detail_id AS payroll_detail_id, IF(v_left = 0, 'PAID', 'PARTIALLY_PAID') AS cycle_status;
END$$

-- ---------------------------------------------------------------------
-- C-066  NEW PROCEDURE hrms_payroll_cycle_log_list   (history of a cycle)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_cycle_log_list$$
CREATE PROCEDURE hrms_payroll_cycle_log_list(IN p_emp_id VARCHAR(20), IN p_cycle_id BIGINT)
BEGIN
    DECLARE v_ok TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    -- C-115: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view payroll cycles.' AS remarks, NULL AS log_id;
    ELSE
        SELECT 'Y' AS status, '' AS remarks, l.log_id, l.payroll_detail_id, l.emp_id, l.action, l.from_status, l.to_status,
               l.remarks AS log_remarks, l.performed_by, COALESCE(n.emp_name, l.performed_by) AS performed_by_name, l.performed_at
          FROM payroll_cycle_status_log l
          LEFT JOIN (SELECT emp_id, MAX(emp_name) AS emp_name FROM user_details GROUP BY emp_id) n ON n.emp_id = l.performed_by
         WHERE l.payroll_cycle_id = p_cycle_id
         ORDER BY l.log_id DESC
         LIMIT 200;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-067  UPDATE PROCEDURE hrms_save_payroll_manual_input
--        As C-043, plus: refused once the month's cycle is approved, and
--        amount 0 removes the entry. Returns the employee's payroll row id
--        so the page can recalculate that employee.
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
    DECLARE v_old_amount  DECIMAL(12,2) DEFAULT NULL;    -- C-133
    DECLARE v_old_remarks VARCHAR(255)  DEFAULT NULL;    -- C-133
    DECLARE v_code        VARCHAR(40)   DEFAULT NULL;    -- C-133
    DECLARE v_cycle       BIGINT        DEFAULT NULL;    -- C-133

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
    -- C-133: values before the change, for the audit trail
    SELECT MAX(amount), MAX(remarks) INTO v_old_amount, v_old_remarks
      FROM payroll_manual_inputs
     WHERE emp_id = p_target_emp_id AND payroll_month = p_month AND payroll_year = p_year AND component_id = p_component_id;
    SELECT MAX(UPPER(component_code)) INTO v_code FROM salary_component_master WHERE component_id = p_component_id;
    SELECT MAX(payroll_cycle_id) INTO v_cycle FROM payroll_cycles WHERE payroll_month = p_month AND payroll_year = p_year;

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
        IF v_old_amount IS NOT NULL THEN    -- C-133
            CALL hrms_payroll_audit_add('MANUAL_INPUT', 'REMOVE', 'payroll_manual_inputs', v_code, p_target_emp_id,
                 v_cycle, p_month, p_year, JSON_OBJECT('component', v_code, 'amount', v_old_amount, 'remarks', v_old_remarks),
                 NULL, CONCAT(v_code, ' manual amount ', v_old_amount, ' removed.'), p_emp_id);
        END IF;
        SELECT 'Y' AS status, 'Manual amount removed.' AS remarks, v_detail AS payroll_detail_id;
    ELSE
        INSERT INTO payroll_manual_inputs (emp_id, payroll_month, payroll_year, component_id, amount, remarks, created_by)
        VALUES (p_target_emp_id, p_month, p_year, p_component_id, p_amount, NULLIF(TRIM(p_remarks), ''), p_emp_id)
        ON DUPLICATE KEY UPDATE amount = VALUES(amount), remarks = VALUES(remarks), created_by = VALUES(created_by);
        CALL hrms_payroll_audit_add('MANUAL_INPUT', IF(v_old_amount IS NULL, 'CREATE', 'UPDATE'), 'payroll_manual_inputs',    -- C-133
             v_code, p_target_emp_id, v_cycle, p_month, p_year,
             IF(v_old_amount IS NULL, NULL, JSON_OBJECT('component', v_code, 'amount', v_old_amount, 'remarks', v_old_remarks)),
             JSON_OBJECT('component', v_code, 'amount', p_amount, 'remarks', NULLIF(TRIM(p_remarks), '')),
             CONCAT(v_code, ' manual amount ', COALESCE(CONCAT(v_old_amount, ' -> '), ''), p_amount, '.'), p_emp_id);
        SELECT 'Y' AS status, 'Manual amount saved.' AS remarks, v_detail AS payroll_detail_id;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-068  NEW PROCEDURE hrms_payroll_manual_inputs_list
--        Manual components and the amounts entered for one month.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_manual_inputs_list$$
CREATE PROCEDURE hrms_payroll_manual_inputs_list(IN p_emp_id VARCHAR(20), IN p_month INT, IN p_year INT)
BEGIN
    DECLARE v_ok TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    -- C-115: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view manual amounts.' AS remarks, NULL AS input_id;
    ELSE
        SELECT 'Y' AS status, '' AS remarks, i.input_id, i.emp_id, COALESCE(n.emp_name, i.emp_id) AS emp_name,
               i.component_id, m.component_code, m.component_name, m.component_type, i.amount, i.remarks AS input_remarks,
               i.created_by, i.updated_at
          FROM payroll_manual_inputs i
          JOIN salary_component_master m ON m.component_id = i.component_id
          LEFT JOIN (SELECT emp_id, MAX(emp_name) AS emp_name FROM user_details GROUP BY emp_id) n ON n.emp_id = i.emp_id
         WHERE i.payroll_month = p_month AND i.payroll_year = p_year
         ORDER BY i.emp_id, m.calculation_order;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-069  UPDATE PROCEDURE hrms_manage_payroll_status
--        Same parameters. FINALIZE and PAID now go through the cycle
--        status engine (C-062), so the old pages follow the same rules:
--        PAID = mark as paid (held employees stay unpaid).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_manage_payroll_status$$
CREATE PROCEDURE hrms_manage_payroll_status(
    IN p_requester_emp_id VARCHAR(20),
    IN p_payroll_month    TINYINT,
    IN p_payroll_year     SMALLINT,
    IN p_action           VARCHAR(20)
)
BEGIN
    DECLARE v_cycle BIGINT;
    SELECT MAX(payroll_cycle_id) INTO v_cycle FROM payroll_cycles
     WHERE payroll_month = p_payroll_month AND payroll_year = p_payroll_year;
    IF v_cycle IS NULL THEN
        SELECT 'N' AS status, 'No payroll cycle exists for the selected month and year.' AS remarks;
    ELSEIF UPPER(TRIM(COALESCE(p_action, ''))) NOT IN ('FINALIZE', 'PAID') THEN
        SELECT 'N' AS status, 'Action must be FINALIZE or PAID.' AS remarks;
    ELSE
        CALL hrms_payroll_cycle_action(p_requester_emp_id, v_cycle,
                                       IF(UPPER(TRIM(p_action)) = 'PAID', 'MARK_PAID', 'FINALIZE'), NULL);
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-070  UPDATE PROCEDURE hrms_generate_employee_payslips
--        Same parameters; goes through the cycle status engine (C-062).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_generate_employee_payslips$$
CREATE PROCEDURE hrms_generate_employee_payslips(
    IN p_requester_emp_id VARCHAR(20),
    IN p_payroll_month    TINYINT,
    IN p_payroll_year     SMALLINT
)
BEGIN
    DECLARE v_cycle BIGINT;
    SELECT MAX(payroll_cycle_id) INTO v_cycle FROM payroll_cycles
     WHERE payroll_month = p_payroll_month AND payroll_year = p_payroll_year;
    IF v_cycle IS NULL THEN
        SELECT 'N' AS status, 'No payroll cycle exists for the selected month and year.' AS remarks;
    ELSE
        CALL hrms_payroll_cycle_action(p_requester_emp_id, v_cycle, 'GENERATE_PAYSLIPS', NULL);
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-071  UPDATE PROCEDURE hrms_update_employee_salary_component
--        Same parameters. Saves the employee's own setting for one
--        component (is_overridden = 1) and recalculates the employee with
--        the salary engine. p_calculation_type DEFAULT removes the employee's
--        own setting so the component follows the component master again.
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
-- C-072  UPDATE PROCEDURE hrms_update_salary_structure
--        Same parameters. Saves the new monthly CTC and effective date and
--        recalculates every component with the salary engine.
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
    DECLARE v_audit_old JSON DEFAULT NULL;    -- C-132
    DECLARE v_audit_new JSON DEFAULT NULL;    -- C-132
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

    SET v_audit_old = hrms_audit_salary_json(v_structure);    -- C-132
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
    -- C-132: audit trail
    SET v_audit_new = hrms_audit_salary_json(v_structure);
    CALL hrms_payroll_audit_add('SALARY', 'CTC_REVISE', 'salary_structure', v_structure, p_target_emp_id,
         NULL, NULL, NULL, v_audit_old, v_audit_new,
         CONCAT('Monthly CTC ', JSON_UNQUOTE(JSON_EXTRACT(v_audit_old, '$.monthly_ctc')), ' -> ', p_monthly_ctc,
                ', effective from ', DATE_FORMAT(p_effective_from, '%d %b %Y'), '.'), p_emp_id);
    COMMIT;

    SELECT 'Y' AS status, 'Salary structure updated and salary recalculated.' AS remarks,
           p_target_emp_id AS emp_id, v_structure AS structure_id, p_monthly_ctc AS monthly_ctc,
           p_monthly_ctc * 12 AS annual_ctc, p_effective_from AS effective_from;
END$$

-- ---------------------------------------------------------------------
-- C-074  NEW PROCEDURE hrms_preview_employee_salary
--        p_structure_id: the salary period to preview (NULL = the salary in
--        force today).
--        Live preview for the salary structure page. Applies a new monthly
--        CTC and/or changed components exactly as saving would (C-071 and
--        C-072), runs the salary engine, returns every amount and total, and
--        then ROLLS BACK: nothing is saved.
--        p_changes: JSON array, e.g.
--          [{"component_id":2,"calculation_type":"FIXED","component_value":5000,
--            "percentage_base":"NONE","formula_expression":null}]
--        Returns one row per active component and total: status, remarks,
--        component_code, component_type, calculation_scope, monthly_amount,
--        is_overridden.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_preview_employee_salary$$
CREATE PROCEDURE hrms_preview_employee_salary(
    IN p_emp_id        VARCHAR(20),
    IN p_target_emp_id VARCHAR(20),
    IN p_structure_id  BIGINT,
    IN p_monthly_ctc   DECIMAL(12,2),
    IN p_changes       LONGTEXT
)
pv: BEGIN
    DECLARE v_ok        TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_structure BIGINT;
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
    DECLARE v_st        CHAR(1);
    DECLARE v_rm        VARCHAR(500);
    DECLARE v_sample    DECIMAL(18,4);
    DECLARE v_changed   INT DEFAULT 0;
    DECLARE v_errs      INT DEFAULT 0;
    DECLARE v_text      VARCHAR(500);
    DECLARE v_err       VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'Preview failed.') AS remarks;
    END;

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF p_structure_id IS NOT NULL AND p_structure_id > 0 THEN
        -- a given salary period of this employee
        SELECT MAX(structure_id) INTO v_structure FROM salary_structure
         WHERE structure_id = p_structure_id AND emp_id = p_target_emp_id AND structure_status = 'ACTIVE';
    ELSE
        -- the salary in force today
        SELECT ss.structure_id INTO v_structure
          FROM salary_structure ss
         WHERE ss.emp_id = p_target_emp_id AND ss.structure_status = 'ACTIVE'
           AND (ss.effective_to IS NULL OR ss.effective_to >= CURDATE())
         ORDER BY ss.effective_from DESC, ss.structure_id DESC LIMIT 1;
    END IF;

    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can preview salaries.' AS remarks;
        LEAVE pv;
    ELSEIF v_structure IS NULL THEN
        SELECT 'N' AS status, 'Employee has no active salary structure.' AS remarks;
        LEAVE pv;
    ELSEIF p_monthly_ctc IS NOT NULL AND p_monthly_ctc < 0 THEN
        SELECT 'N' AS status, 'Monthly CTC cannot be negative.' AS remarks;
        LEAVE pv;
    ELSEIF NULLIF(TRIM(COALESCE(p_changes, '')), '') IS NOT NULL
       AND (JSON_VALID(p_changes) = 0 OR LEFT(TRIM(p_changes), 1) <> '[') THEN
        SELECT 'N' AS status, 'Changes must be a JSON array.' AS remarks;
        LEAVE pv;
    END IF;

    START TRANSACTION;

    IF p_monthly_ctc IS NOT NULL AND p_monthly_ctc > 0 THEN
        UPDATE salary_structure SET monthly_ctc = p_monthly_ctc, annual_ctc = p_monthly_ctc * 12
         WHERE structure_id = v_structure;
    END IF;

    SET v_count = COALESCE(JSON_LENGTH(NULLIF(TRIM(COALESCE(p_changes, '')), '')), 0);
    WHILE v_i < v_count DO
        SET v_path    = CONCAT('$[', v_i, ']');
        SET v_cid     = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_changes, CONCAT(v_path, '.component_id'))), 'null') AS UNSIGNED);
        SET v_calc    = UPPER(TRIM(COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_changes, CONCAT(v_path, '.calculation_type'))), 'null'), '')));
        SET v_value   = NULLIF(TRIM(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_changes, CONCAT(v_path, '.component_value'))), '')), 'null');
        SET v_base    = UPPER(TRIM(COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_changes, CONCAT(v_path, '.percentage_base'))), 'null'), 'NONE')));
        SET v_formula = NULLIF(UPPER(TRIM(COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_changes, CONCAT(v_path, '.formula_expression'))), 'null'), ''))), '');
        IF v_value IS NULL OR v_value NOT REGEXP '^-?[0-9]+(\\.[0-9]+)?$' THEN
            SET v_value = '0';
        END IF;

        -- a formula is checked exactly as saving would check it
        IF v_calc = 'FORMULA' THEN
            SELECT MAX(UPPER(component_code)), MAX(calculation_order) INTO v_code, v_order
              FROM salary_component_master WHERE component_id = v_cid;
            IF v_formula IS NULL THEN
                SET v_st = 'N';
                SET v_rm = 'A formula is required.';
            ELSE
                CALL hrms_formula_check(v_cid, v_code, v_order, v_formula, v_st, v_rm, v_sample);
            END IF;
            IF v_st <> 'Y' THEN
                ROLLBACK;
                SELECT 'N' AS status, LEFT(CONCAT(COALESCE(v_code, 'Formula'), ': ', v_rm), 500) AS remarks;
                LEAVE pv;
            END IF;
        END IF;

        IF v_calc = 'DEFAULT' THEN
            UPDATE employee_salary_structure e
              JOIN salary_component_master m ON m.component_id = e.component_id
               SET e.calculation_type = CASE WHEN m.calculation_type = 'STATUTORY' THEN 'MANUAL' ELSE m.calculation_type END,
                   e.component_value = COALESCE(m.percentage_value, 0), e.percentage_base = COALESCE(m.percentage_base, 'NONE'),
                   e.formula_expression = m.formula_expression, e.is_overridden = 0
             WHERE e.structure_id = v_structure AND e.component_id = v_cid;
        ELSEIF v_calc IN ('FIXED', 'PERCENTAGE', 'FORMULA', 'MANUAL') THEN
            UPDATE employee_salary_structure
               SET calculation_type = v_calc,
                   component_value = GREATEST(CAST(v_value AS DECIMAL(12,2)), 0),
                   percentage_base = IF(v_calc = 'PERCENTAGE', v_base, 'NONE'),
                   formula_expression = IF(v_calc = 'FORMULA', v_formula, NULL),
                   monthly_amount = IF(v_calc = 'MANUAL', GREATEST(CAST(v_value AS DECIMAL(12,2)), 0), monthly_amount),
                   is_overridden = 1
             WHERE structure_id = v_structure AND component_id = v_cid;
        END IF;
        SET v_i = v_i + 1;
    END WHILE;

    SET @hrms_calc_date = hrms_structure_calc_date(v_structure);
    CALL hrms_calculate_structure(v_structure, @hrms_calc_date, v_changed, v_errs, v_text);   -- C-096
    IF v_errs > 0 THEN
        ROLLBACK;
        SELECT 'N' AS status, LEFT(CONCAT('This would not calculate: ', COALESCE(v_text, 'unknown error')), 500) AS remarks;
        LEAVE pv;
    END IF;

    SELECT 'Y' AS status, 'Preview from the salary engine (not saved)' AS remarks,
           x.component_code, x.component_type, x.calculation_scope, x.monthly_amount, x.is_overridden, x.calculation_order
      FROM (
            SELECT m.component_code, m.component_type, m.calculation_scope, e.monthly_amount, e.is_overridden, m.calculation_order
              FROM employee_salary_structure e
              JOIN salary_component_master m ON m.component_id = e.component_id AND m.is_active = 1
             WHERE e.structure_id = v_structure
            UNION ALL
            SELECT m.component_code, m.component_type, m.calculation_scope, t.monthly_amount, 0, m.calculation_order
              FROM employee_salary_structure_totals t
              JOIN salary_component_master m ON m.component_id = t.component_id AND m.is_active = 1
             WHERE t.structure_id = v_structure
           ) x
     ORDER BY x.calculation_order;

    ROLLBACK;
END$$

-- ---------------------------------------------------------------------
-- C-075  DATA : salary of BS00001 before November 2026
--        BS00001's only salary structure (CTC 40,000) starts 2026-11-01:
--        the earlier salary was overwritten when the CTC was revised. The
--        February, April and May 2026 payrolls paid CTC 30,000, so that
--        salary is added back for 2026-01-01 to 2026-10-31 (the date every
--        other employee's salary starts). All active components are attached
--        and the amounts are calculated by the salary engine.
--        Runs once: skipped when BS00001 already has a salary that covers
--        2026-01-01.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_script_c075$$
CREATE PROCEDURE hrms_script_c075()
c75: BEGIN
    DECLARE v_n         INT DEFAULT 0;
    DECLARE v_structure BIGINT;
    DECLARE v_attached  INT DEFAULT 0;
    DECLARE v_changed   INT DEFAULT 0;
    DECLARE v_errs      INT DEFAULT 0;
    DECLARE v_text      VARCHAR(500);
    DECLARE v_signal    VARCHAR(128);

    SELECT COUNT(*) INTO v_n FROM salary_structure
     WHERE emp_id = 'BS00001' AND structure_status = 'ACTIVE'
       AND effective_from <= '2026-01-01' AND (effective_to IS NULL OR effective_to >= '2026-01-01');
    IF v_n > 0 THEN
        LEAVE c75;
    END IF;
    SELECT COUNT(*) INTO v_n FROM salary_structure
     WHERE emp_id = 'BS00001' AND structure_status = 'ACTIVE'
       AND effective_from <= '2026-10-31' AND (effective_to IS NULL OR effective_to >= '2026-01-01')
       AND effective_from < '2026-11-01';
    IF v_n > 0 THEN
        LEAVE c75;
    END IF;

    START TRANSACTION;
    INSERT INTO salary_structure
        (emp_id, monthly_ctc, annual_ctc, effective_from, effective_to, structure_status, esi_applicable, created_by)
    VALUES
        ('BS00001', 30000.00, 360000.00, '2026-01-01', '2026-10-31', 'ACTIVE', 'N', 'SCRIPT');
    SET v_structure = LAST_INSERT_ID();
    CALL hrms_attach_component(NULL, v_attached);
    CALL hrms_calculate_structure(v_structure, '2026-10-31', v_changed, v_errs, v_text);
    IF v_errs > 0 THEN
        ROLLBACK;
        SET v_signal = LEFT(CONCAT('BS00001 salary not added: ', COALESCE(v_text, 'calculation failed')), 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_signal;
    END IF;
    COMMIT;
END$$
CALL hrms_script_c075()$$
DROP PROCEDURE IF EXISTS hrms_script_c075$$

-- ---------------------------------------------------------------------
-- C-076  NEW PROCEDURE hrms_payroll_cycle_delete
--        Deletes a payroll cycle that has not been finalized (status OPEN,
--        ATTENDANCE_VERIFIED, STRUCTURE_VERIFIED, PROCESSING, CALCULATED or
--        APPROVED): the cycle, its run, the employee payroll rows and their
--        component rows. A reason is required.
--        Kept: manual amounts of the month (payroll_manual_inputs, used again
--        by a new cycle for that month), attendance, salary structures, and
--        the cycle's history: its rows get the cycle id as a negative number
--        (so a new cycle never inherits them) and keep the cycle code, plus a
--        DELETE row with the reason and the totals that were deleted.
--        Refused from FINALIZED onwards, or if any employee is paid or has a
--        payslip.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_cycle_delete$$
CREATE PROCEDURE hrms_payroll_cycle_delete(
    IN p_emp_id   VARCHAR(20),
    IN p_cycle_id BIGINT,
    IN p_reason   VARCHAR(500)
)
cd: BEGIN
    DECLARE v_ok      TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_status  VARCHAR(30);
    DECLARE v_code    VARCHAR(50);
    DECLARE v_month   INT;
    DECLARE v_year    INT;
    DECLARE v_emps    INT DEFAULT 0;
    DECLARE v_net     DECIMAL(14,2) DEFAULT 0;
    DECLARE v_paid    INT DEFAULT 0;
    DECLARE v_slips   INT DEFAULT 0;
    DECLARE v_msg     VARCHAR(500) DEFAULT NULL;
    DECLARE v_label   VARCHAR(60);
    DECLARE v_err     VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'The payroll cycle could not be deleted. Nothing was changed.') AS remarks,
               p_cycle_id AS payroll_cycle_id;
    END;

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can delete payroll cycles.' AS remarks, p_cycle_id AS payroll_cycle_id;
        LEAVE cd;
    END IF;
    IF NULLIF(TRIM(COALESCE(p_reason, '')), '') IS NULL THEN
        SELECT 'N' AS status, 'A reason is required to delete a payroll cycle.' AS remarks, p_cycle_id AS payroll_cycle_id;
        LEAVE cd;
    END IF;

    START TRANSACTION;
    SELECT MAX(cycle_status), MAX(cycle_code), MAX(payroll_month), MAX(payroll_year)
      INTO v_status, v_code, v_month, v_year
      FROM payroll_cycles WHERE payroll_cycle_id = p_cycle_id FOR UPDATE;

    SELECT COUNT(*), COALESCE(SUM(d.net_pay), 0), COALESCE(SUM(d.payment_status = 'PAID'), 0)
      INTO v_emps, v_net, v_paid
      FROM employee_payroll_details d
      JOIN payroll_runs r ON r.payroll_run_id = d.payroll_run_id
     WHERE r.payroll_cycle_id = p_cycle_id;
    SELECT COUNT(*) INTO v_slips
      FROM employee_payslips s
      JOIN employee_payroll_details d ON d.payroll_detail_id = s.payroll_detail_id
      JOIN payroll_runs r ON r.payroll_run_id = d.payroll_run_id
     WHERE r.payroll_cycle_id = p_cycle_id;

    IF v_status IS NULL THEN
        SET v_msg = 'Payroll cycle not found.';
    ELSEIF v_status NOT IN ('OPEN', 'ATTENDANCE_VERIFIED', 'STRUCTURE_VERIFIED', 'PROCESSING', 'CALCULATED', 'APPROVED') THEN
        SET v_msg = CONCAT('A payroll cycle that is ', v_status, ' cannot be deleted. Only cycles that are not finalized can be deleted.');
    ELSEIF v_paid > 0 OR v_slips > 0 THEN
        SET v_msg = 'This payroll has paid employees or payslips and cannot be deleted.';
    END IF;
    IF v_msg IS NOT NULL THEN
        ROLLBACK;
        SELECT 'N' AS status, v_msg AS remarks, p_cycle_id AS payroll_cycle_id;
        LEAVE cd;
    END IF;

    SET v_label = CONCAT(ELT(v_month, 'January','February','March','April','May','June','July',
                             'August','September','October','November','December'), ' ', v_year);

    DELETE c FROM employee_payroll_component_details c
      JOIN employee_payroll_details d ON d.payroll_detail_id = c.payroll_detail_id
      JOIN payroll_runs r ON r.payroll_run_id = d.payroll_run_id
     WHERE r.payroll_cycle_id = p_cycle_id;
    DELETE d FROM employee_payroll_details d
      JOIN payroll_runs r ON r.payroll_run_id = d.payroll_run_id
     WHERE r.payroll_cycle_id = p_cycle_id;
    DELETE FROM payroll_runs WHERE payroll_cycle_id = p_cycle_id;

    CALL hrms_payroll_log(p_cycle_id, NULL, NULL, 'DELETE', v_status, 'DELETED',
                          LEFT(CONCAT('Payroll ', v_label, ' deleted. Reason: ', TRIM(p_reason),
                                      IF(v_emps > 0, CONCAT('. It had ', v_emps, ' employees, net pay ', FORMAT(v_net, 2)), '')), 500),
                          p_emp_id);
    UPDATE payroll_cycle_status_log
       SET payroll_cycle_id = -p_cycle_id, cycle_code = COALESCE(cycle_code, v_code)
     WHERE payroll_cycle_id = p_cycle_id;
    DELETE FROM payroll_cycles WHERE payroll_cycle_id = p_cycle_id;
    COMMIT;

    SELECT 'Y' AS status,
           CONCAT('Payroll ', v_label, ' (', v_code, ') deleted.', IF(v_emps > 0, CONCAT(' ', v_emps, ' employee results removed.'), '')) AS remarks,
           p_cycle_id AS payroll_cycle_id;
END$$

-- ---------------------------------------------------------------------
-- C-077  NEW PROCEDURE hrms_payroll_cycle_breakdown
--        Salary breakdown of every active employee for a payroll cycle:
--        the salary period that covers the cycle's pay period, and every
--        active component and total of it (full-month amounts). One row per
--        employee and component; an employee without a salary has one row
--        with no component.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_cycle_breakdown$$
CREATE PROCEDURE hrms_payroll_cycle_breakdown(IN p_emp_id VARCHAR(20), IN p_cycle_id BIGINT)
BEGIN
    DECLARE v_ok TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    -- C-115: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view salaries.' AS remarks, NULL AS emp_id;
    ELSE
        CALL hrms_payroll_load_cycle_emps(p_cycle_id, NULL);
        SELECT 'Y' AS status, '' AS remarks,
               t.emp_id, t.emp_name, t.structure_id, ss.effective_from, ss.effective_to, t.monthly_ctc,
               m.component_id, m.component_code, m.component_name, m.component_type, m.calculation_scope,
               m.calculation_order, x.monthly_amount, x.is_overridden,
               x.calculation_type AS own_calculation_type, x.component_value AS own_value,
               x.percentage_base AS own_base, x.formula_expression AS own_formula
          FROM tmp_hrms_cycle_emps t
          LEFT JOIN salary_structure ss ON ss.structure_id = t.structure_id
          LEFT JOIN (
                SELECT e.structure_id, e.component_id, e.monthly_amount, e.is_overridden,
                       e.calculation_type, e.component_value, e.percentage_base, e.formula_expression
                  FROM employee_salary_structure e
                UNION ALL
                SELECT s.structure_id, s.component_id, s.monthly_amount, 0, NULL, NULL, NULL, NULL
                  FROM employee_salary_structure_totals s
               ) x ON x.structure_id = t.structure_id
          LEFT JOIN salary_component_master m ON m.component_id = x.component_id
         WHERE x.component_id IS NULL OR m.is_active = 1
         ORDER BY t.emp_id, m.calculation_order, m.component_id;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-078  NEW PROCEDURE hrms_salary_periods
--        One employee: name, department, designation and every salary period
--        (newest first), with the payroll cycles whose pay period it covers.
--        An employee without any salary gets one row with structure_id NULL.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_salary_periods$$
CREATE PROCEDURE hrms_salary_periods(IN p_emp_id VARCHAR(20), IN p_target_emp_id VARCHAR(20))
BEGIN
    DECLARE v_ok TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    -- C-115: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    SET SESSION group_concat_max_len = 100000;
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view salaries.' AS remarks, NULL AS emp_id;
    ELSEIF NOT EXISTS (SELECT 1 FROM user_details WHERE emp_id = p_target_emp_id)
       AND NOT EXISTS (SELECT 1 FROM salary_structure WHERE emp_id = p_target_emp_id) THEN
        SELECT 'N' AS status, CONCAT('Employee ', COALESCE(p_target_emp_id, ''), ' not found.') AS remarks, NULL AS emp_id;
    ELSE
        SELECT 'Y' AS status, '' AS remarks,
               p_target_emp_id AS emp_id,
               (SELECT MAX(d.emp_name) FROM user_details d WHERE d.emp_id = p_target_emp_id) AS emp_name,
               (SELECT MAX(dm.department_name) FROM user_details d JOIN department_master dm ON dm.department_id = d.department
                 WHERE d.emp_id = p_target_emp_id) AS department,
               (SELECT MAX(dg.designation_name) FROM user_details d JOIN designation_master dg ON dg.designation_id = d.designation
                 WHERE d.emp_id = p_target_emp_id) AS designation,
               (SELECT MAX(u.status) FROM user_login_details u WHERE u.emp_id = p_target_emp_id) AS login_status,
               (SELECT MAX(d.joining_date) FROM user_details d WHERE d.emp_id = p_target_emp_id) AS joining_date,
               ss.structure_id, ss.monthly_ctc, ss.annual_ctc, ss.effective_from, ss.effective_to,
               ss.structure_status, ss.esi_applicable,
               IF(ss.structure_id IS NOT NULL AND ss.effective_from <= CURDATE()
                  AND (ss.effective_to IS NULL OR ss.effective_to >= CURDATE()), 1, 0) AS is_current,
               (SELECT GROUP_CONCAT(CONCAT(c.payroll_cycle_id, '|',
                                           ELT(c.payroll_month, 'January','February','March','April','May','June','July',
                                               'August','September','October','November','December'), ' ', c.payroll_year, '|',
                                           c.cycle_status)
                                    ORDER BY c.payroll_year, c.payroll_month SEPARATOR ';')
                  FROM payroll_cycles c
                 WHERE ss.structure_id IS NOT NULL
                   AND c.period_start <= COALESCE(ss.effective_to, '9999-12-31')
                   AND c.period_end >= ss.effective_from) AS cycles
          FROM (SELECT 1 AS one) d
          LEFT JOIN salary_structure ss ON ss.emp_id = p_target_emp_id AND ss.structure_status = 'ACTIVE'
         ORDER BY ss.effective_from DESC, ss.structure_id DESC;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-079  NEW PROCEDURE hrms_salary_components_for_structure
--        Every active component and total of one salary period: the
--        company rule (component master, slabs as text), the employee's own
--        setting if any, and the amount. p_structure_id NULL = the company
--        rules of every active component only (for a new salary).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_salary_components_for_structure$$
CREATE PROCEDURE hrms_salary_components_for_structure(IN p_emp_id VARCHAR(20), IN p_structure_id BIGINT)
BEGIN
    DECLARE v_ok TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    -- C-115: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    SET SESSION group_concat_max_len = 100000;
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view salaries.' AS remarks, NULL AS component_id;
    ELSEIF p_structure_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM salary_structure WHERE structure_id = p_structure_id) THEN
        SELECT 'N' AS status, 'Salary period not found.' AS remarks, NULL AS component_id;
    ELSE
        SELECT 'Y' AS status, '' AS remarks,
               m.component_id, m.component_code, m.component_name, m.component_type, m.calculation_scope,
               m.calculation_order, m.calculation_type AS rule_calculation_type, m.percentage_base AS rule_base,
               m.percentage_value AS rule_value, m.formula_expression AS rule_formula,
               m.minimum_amount, m.maximum_amount, m.eligibility_parameter, m.eligibility_required_value,
               m.is_slab, m.is_manual, m.is_taxable,
               (SELECT GROUP_CONCAT(CONCAT(s.slab_based_on, ' ', FORMAT(s.slab_min_value, 2),
                                           IF(s.slab_max_value IS NULL, ' and above', CONCAT(' to ', FORMAT(s.slab_max_value, 2))),
                                           ': ', IF(s.result_type = 'FIXED', CONCAT('Rs ', FORMAT(s.result_value, 2)),
                                                    CONCAT(s.result_value + 0, '% of ', s.percentage_base)))
                                    ORDER BY s.priority SEPARATOR '; ')
                  FROM salary_component_slab s WHERE s.component_id = m.component_id AND s.is_active = 1) AS slab_text,
               e.employee_component_id, e.is_overridden,
               e.calculation_type AS own_calculation_type, e.component_value AS own_value,
               e.percentage_base AS own_base, e.formula_expression AS own_formula,
               COALESCE(e.monthly_amount, t.monthly_amount, 0) AS monthly_amount
          FROM salary_component_master m
          LEFT JOIN employee_salary_structure e ON e.component_id = m.component_id AND e.structure_id = p_structure_id
          LEFT JOIN employee_salary_structure_totals t ON t.component_id = m.component_id AND t.structure_id = p_structure_id
         WHERE m.is_active = 1
           AND (p_structure_id IS NULL OR e.employee_component_id IS NOT NULL OR m.calculation_scope = 'AGGREGATE')
         ORDER BY m.calculation_order, m.component_id;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-080  NEW PROCEDURE hrms_save_employee_salary
--        Saves one salary period of one employee in a single step: monthly
--        CTC, the date it applies from, and every changed component
--        (p_changes, same JSON as C-074; calculation_type DEFAULT removes the
--        employee's own setting). Then the salary engine recalculates it.
--        Salary history is kept: when p_effective_from is later than the
--        period's start, a NEW period is created from that date (with the
--        same components and own settings) and the old one ends the day
--        before. A date before the period's start or after its end is
--        refused. Anything invalid = nothing is saved.
--        Returns: status, remarks, structure_id (the period saved),
--        new_period (1 = a new period was created).
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
-- C-081  NEW PROCEDURE hrms_employees_without_salary
--        Active employees who have no ACTIVE salary at all (new joiners),
--        with joining date, department and designation.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_employees_without_salary$$
CREATE PROCEDURE hrms_employees_without_salary(IN p_emp_id VARCHAR(20))
BEGIN
    DECLARE v_ok TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    -- C-115: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view salaries.' AS remarks, NULL AS emp_id;
    ELSE
        SELECT 'Y' AS status, '' AS remarks, u.emp_id,
               (SELECT MAX(d.emp_name) FROM user_details d WHERE d.emp_id = u.emp_id) AS emp_name,
               (SELECT MAX(d.joining_date) FROM user_details d WHERE d.emp_id = u.emp_id) AS joining_date,
               (SELECT MAX(dm.department_name) FROM user_details d JOIN department_master dm ON dm.department_id = d.department
                 WHERE d.emp_id = u.emp_id) AS department,
               (SELECT MAX(dg.designation_name) FROM user_details d JOIN designation_master dg ON dg.designation_id = d.designation
                 WHERE d.emp_id = u.emp_id) AS designation
          FROM (SELECT DISTINCT TRIM(emp_id) AS emp_id FROM user_login_details
                 WHERE LOWER(status) = 'active' AND emp_id IS NOT NULL AND TRIM(emp_id) <> '') u
         WHERE NOT EXISTS (SELECT 1 FROM salary_structure s WHERE s.emp_id = u.emp_id AND s.structure_status = 'ACTIVE')
         ORDER BY u.emp_id;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C-082  NEW PROCEDURE hrms_salary_attach_all   (helper)
--        Attaches every active pay component of the component master to
--        one salary period (with the company rule, amount 0 until the
--        engine calculates it). Components already attached are skipped.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_salary_attach_all$$
CREATE PROCEDURE hrms_salary_attach_all(IN p_structure_id BIGINT, OUT p_attached INT)
BEGIN
    INSERT INTO employee_salary_structure
        (structure_id, component_id, calculation_type, component_value, percentage_base,
         formula_expression, monthly_amount, is_overridden)
    SELECT p_structure_id, m.component_id,
           CASE WHEN m.calculation_type = 'STATUTORY' THEN 'MANUAL' ELSE m.calculation_type END,
           COALESCE(m.percentage_value, 0), COALESCE(m.percentage_base, 'NONE'), m.formula_expression, 0.00, 0
      FROM salary_component_master m
     WHERE m.is_active = 1 AND m.calculation_scope = 'COMPONENT'
       AND NOT EXISTS (SELECT 1 FROM employee_salary_structure e
                        WHERE e.structure_id = p_structure_id AND e.component_id = m.component_id);
    SET p_attached = ROW_COUNT();
END$$

-- ---------------------------------------------------------------------
-- C-083  NEW PROCEDURE hrms_preview_new_salary
--        What a new salary would look like: builds it with every active
--        component, calculates it with the salary engine, returns the
--        amounts (same rows as C-074) and ROLLS BACK. Nothing is saved.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_preview_new_salary$$
CREATE PROCEDURE hrms_preview_new_salary(
    IN p_emp_id        VARCHAR(20),
    IN p_target_emp_id VARCHAR(20),
    IN p_monthly_ctc   DECIMAL(12,2),
    IN p_esi           VARCHAR(1)
)
pn: BEGIN
    DECLARE v_ok        TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
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
        SELECT 'N' AS status, COALESCE(v_err, 'Preview failed.') AS remarks;
    END;

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can preview salaries.' AS remarks;
        LEAVE pn;
    ELSEIF p_monthly_ctc IS NULL OR p_monthly_ctc <= 0 THEN
        SELECT 'N' AS status, 'Enter the monthly CTC.' AS remarks;
        LEAVE pn;
    END IF;

    START TRANSACTION;
    INSERT INTO salary_structure (emp_id, monthly_ctc, annual_ctc, effective_from, effective_to, structure_status, esi_applicable, created_by)
    VALUES (COALESCE(NULLIF(TRIM(p_target_emp_id), ''), 'PREVIEW'), p_monthly_ctc, p_monthly_ctc * 12, CURDATE(), CURDATE(),
            'DRAFT', IF(UPPER(p_esi) = 'Y', 'Y', 'N'), p_emp_id);
    SET v_structure = LAST_INSERT_ID();
    CALL hrms_salary_attach_all(v_structure, v_attached);
    SET @hrms_calc_date = hrms_structure_calc_date(v_structure);
    CALL hrms_calculate_structure(v_structure, @hrms_calc_date, v_changed, v_errs, v_text);   -- C-096
    IF v_errs > 0 THEN
        ROLLBACK;
        SELECT 'N' AS status, LEFT(CONCAT('This salary would not calculate: ', COALESCE(v_text, 'unknown error')), 500) AS remarks;
        LEAVE pn;
    END IF;

    SELECT 'Y' AS status, 'Preview from the salary engine (not saved)' AS remarks,
           x.component_code, x.component_type, x.calculation_scope, x.monthly_amount, 0 AS is_overridden, x.calculation_order
      FROM (
            SELECT m.component_code, m.component_type, m.calculation_scope, e.monthly_amount, m.calculation_order
              FROM employee_salary_structure e
              JOIN salary_component_master m ON m.component_id = e.component_id AND m.is_active = 1
             WHERE e.structure_id = v_structure
            UNION ALL
            SELECT m.component_code, m.component_type, m.calculation_scope, t.monthly_amount, m.calculation_order
              FROM employee_salary_structure_totals t
              JOIN salary_component_master m ON m.component_id = t.component_id AND m.is_active = 1
             WHERE t.structure_id = v_structure
           ) x
     ORDER BY x.calculation_order;
    ROLLBACK;
END$$

-- ---------------------------------------------------------------------
-- C-084  NEW PROCEDURE hrms_create_employee_salary
--        Creates a salary for an employee (a new joiner, or a gap in the
--        salary history): monthly CTC, the date it applies from and ESI.
--        Every active component of the master is attached with the company
--        rule and calculated by the salary engine. If a later salary
--        already exists, the new one ends the day before it.
--        Refused when a salary already covers that date (use Edit then).
--        Returns: status, remarks, structure_id.
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
    DECLARE v_audit_old JSON DEFAULT NULL;    -- C-132
    DECLARE v_audit_new JSON DEFAULT NULL;    -- C-132
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
    -- C-132: audit trail
    SET v_audit_new = hrms_audit_salary_json(v_structure);
    CALL hrms_payroll_audit_add('SALARY', 'CREATE', 'salary_structure', v_structure, p_target_emp_id, NULL, NULL, NULL,
         NULL, v_audit_new,
         CONCAT('Salary created: monthly CTC ', p_monthly_ctc, ' from ', DATE_FORMAT(p_effective_from, '%d %b %Y'),
                ', ESI ', UPPER(p_esi), '.'), p_emp_id);
    COMMIT;

    SELECT 'Y' AS status,
           CONCAT('Salary created from ', DATE_FORMAT(p_effective_from, '%d %b %Y'),
                  IF(v_to IS NULL, '', CONCAT(' to ', DATE_FORMAT(v_to, '%d %b %Y'))),
                  ' with ', v_attached, ' components.') AS remarks,
           v_structure AS structure_id;
END$$

-- ---------------------------------------------------------------------
-- C-073  UPDATE PROCEDURE hrms_get_payslip
--        Unchanged except that payslips are also shown while the cycle is
--        PARTIALLY_PAID or PAID (before only FINALIZED or CLOSED).
--        C-087: monthly_ctc is the CTC the employee was paid on in that
--        month (employee_payroll_details.monthly_ctc), not today's salary.
--        C-111: components = pay components only; a new column totals lists
--        the totals of the month (GROSS, NET_PAY, TOTAL_CTC ...) in order.
--        C-116: standard role check (active ADMIN, HR or EMP; EMP only own) and
--        every refusal returned as an 'N' row.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_get_payslip$$
CREATE PROCEDURE `hrms_get_payslip`(
    IN p_requester_emp_id VARCHAR(20),
    IN p_target_emp_id VARCHAR(20),
    IN p_payroll_month TINYINT,
    IN p_payroll_year SMALLINT
)
main: BEGIN

    

    DECLARE v_user_found INT DEFAULT 0;
    DECLARE v_user_category VARCHAR(50) DEFAULT NULL;
    DECLARE v_user_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_record_count INT DEFAULT 0;
    DECLARE v_err VARCHAR(500) DEFAULT NULL;
    -- C-116: every refusal is returned as an 'N' row instead of a database error
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        SELECT 'N' AS status, v_err AS remarks;
    END;

    SET SESSION group_concat_max_len = 1000000;   -- C-111: totals list

    

    IF p_requester_emp_id IS NULL
       OR TRIM(p_requester_emp_id) = '' THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Requester employee ID is required';

    END IF;

    

    -- C-116: who is calling - active ADMIN, HR or EMP (user_login_details); an EMP sees only own payslips
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_requester_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR', 'EMP') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN, HR or EMP users can view payslips.' AS remarks;
        LEAVE main;
    END IF;

    

    IF (p_payroll_month IS NULL AND p_payroll_year IS NOT NULL)
       OR (p_payroll_month IS NOT NULL AND p_payroll_year IS NULL) THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Payroll month and year must be supplied together';

    END IF;

    IF p_payroll_month IS NOT NULL
       AND p_payroll_month NOT BETWEEN 1 AND 12 THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid payroll month';

    END IF;

    IF p_payroll_year IS NOT NULL
       AND p_payroll_year NOT BETWEEN 2000 AND 2100 THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid payroll year';

    END IF;

    

    IF v_user_category = 'EMP' THEN

        IF p_target_emp_id IS NOT NULL
           AND TRIM(p_target_emp_id) <> ''
           AND TRIM(p_target_emp_id)
               <> TRIM(p_requester_emp_id) THEN

            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'Access denied: Employees can view only their own payslips';

        END IF;

    END IF;

    

    SELECT COUNT(*)
    INTO v_record_count
    FROM payroll_cycles pc

    INNER JOIN payroll_runs pr
        ON pr.payroll_cycle_id = pc.payroll_cycle_id

    INNER JOIN employee_payroll_details epd
        ON epd.payroll_run_id = pr.payroll_run_id

    WHERE
        UPPER(pc.cycle_status) IN ('FINALIZED', 'PARTIALLY_PAID', 'PAID', 'CLOSED')

        AND UPPER(pr.run_status) = 'FINALIZED'

        AND UPPER(epd.employee_payroll_status) = 'FINALIZED'

        AND (
            p_payroll_month IS NULL
            OR (
                pc.payroll_month = p_payroll_month
                AND pc.payroll_year = p_payroll_year
            )
        )

        AND (
            (
                v_user_category IN ('ADMIN', 'HR')
                AND (
                    p_target_emp_id IS NULL
                    OR TRIM(p_target_emp_id) = ''
                    OR epd.emp_id = TRIM(p_target_emp_id)
                )
            )

            OR

            (
                v_user_category = 'EMP'
                AND epd.emp_id = TRIM(p_requester_emp_id)
            )
        );

    

    IF v_record_count = 0 THEN

        SELECT
            'N' AS status,
            CASE
                WHEN p_payroll_month IS NOT NULL THEN
                    'No finalized payslip found for the requested payroll month and year'
                ELSE
                    'No finalized payslips found for the requested employee or access scope'
            END AS remarks,

            NULL AS payroll_cycle_id,
            NULL AS payroll_month,
            NULL AS payroll_year,
            NULL AS cycle_status,

            NULL AS payroll_run_id,
            NULL AS run_status,

            NULL AS emp_id,
            NULL AS ref_id,
            NULL AS emp_name,
            NULL AS email,
            NULL AS mobile,

            NULL AS department_name,
            NULL AS designation_name,
            NULL AS reporting,
            NULL AS joining_date,

            NULL AS pan,
            NULL AS pf_account_no,
            NULL AS esic_no,
            NULL AS uan,

            NULL AS payroll_detail_id,
            NULL AS gross_earnings,
            NULL AS total_deductions,
            NULL AS employer_contributions,
            NULL AS net_pay,
            NULL AS payment_decision,
            NULL AS payment_status,
            NULL AS employee_payroll_status,

            JSON_ARRAY() AS components,
            JSON_ARRAY() AS totals;

    ELSE

        

        SELECT

            

            'Y' AS status,

            'Payslip retrieved successfully' AS remarks,

            

           
            pc.payroll_month,
            pc.payroll_year,
           

            

            
            pr.run_status,
            
            -- C-087: the CTC this month was paid on
            COALESCE(epd.monthly_ctc,
                     (SELECT ss.monthly_ctc FROM salary_structure ss
                       WHERE ss.structure_id = epd.structure_id)) AS monthly_ctc,

            

            epd.emp_id,
            
            ud.emp_name,
            
            ud.mobile,
            ud.bank_name,
            ud.bank_account_no,

            

            dm.department_name,
            dsm.designation_name,
            
            cs.city AS company_city,
            
            ud.joining_date,

            

            ud.pan,
            ud.pf_account_no,
            ud.esic_no,
            ud.uan,

            

            epd.payroll_detail_id,
            epd.gross_earnings,
            epd.total_deductions,
            epd.employer_contributions,
            epd.net_pay,
            epd.payment_decision,
            epd.payment_status,
            epd.employee_payroll_status,

            

            COALESCE(
                (
                    SELECT JSON_ARRAYAGG(
                        JSON_OBJECT(
                            'component_name',
                            epcd.component_name,
                            'component_type',
                            epcd.component_type,
                            'calculated_amount',
                            epcd.calculated_amount
                        )
                    )
                    FROM employee_payroll_component_details epcd
                    WHERE epcd.payroll_detail_id =
                          epd.payroll_detail_id
                      AND epcd.calculation_scope = 'COMPONENT'
                ),
                JSON_ARRAY()
            ) AS components,
            -- C-111: the totals of the month, in calculation order
            COALESCE(
                (
                    SELECT CAST(CONCAT('[', GROUP_CONCAT(
                               JSON_OBJECT('component_code', epcd.component_code,
                                           'component_name', epcd.component_name,
                                           'component_type', epcd.component_type,
                                           'calculation_order', epcd.calculation_order,
                                           'calculated_amount', epcd.calculated_amount)
                               ORDER BY epcd.calculation_order, epcd.component_id SEPARATOR ','), ']') AS JSON)
                    FROM employee_payroll_component_details epcd
                    WHERE epcd.payroll_detail_id = epd.payroll_detail_id
                      AND epcd.calculation_scope = 'AGGREGATE'
                ),
                JSON_ARRAY()
            ) AS totals

        FROM payroll_cycles pc

        INNER JOIN payroll_runs pr
            ON pr.payroll_cycle_id = pc.payroll_cycle_id

        INNER JOIN employee_payroll_details epd
            ON epd.payroll_run_id = pr.payroll_run_id

        LEFT JOIN user_details ud
            ON ud.emp_id = epd.emp_id

        LEFT JOIN department_master dm
            ON dm.department_id = ud.department

        LEFT JOIN designation_master dsm
            ON dsm.designation_id = ud.designation
            
        LEFT JOIN company_settings cs
    ON cs.id = 1    

        WHERE

            

            UPPER(pc.cycle_status) IN ('FINALIZED', 'PARTIALLY_PAID', 'PAID', 'CLOSED')

            AND UPPER(pr.run_status) = 'FINALIZED'

            AND UPPER(epd.employee_payroll_status) = 'FINALIZED'

            

            AND (
                p_payroll_month IS NULL
                OR (
                    pc.payroll_month = p_payroll_month
                    AND pc.payroll_year = p_payroll_year
                )
            )

            

            AND (
                (
                    v_user_category IN ('ADMIN', 'HR')
                    AND (
                        p_target_emp_id IS NULL
                        OR TRIM(p_target_emp_id) = ''
                        OR epd.emp_id = TRIM(p_target_emp_id)
                    )
                )

                OR

                (
                    v_user_category = 'EMP'
                    AND epd.emp_id = TRIM(p_requester_emp_id)
                )
            )

        ORDER BY
            pc.payroll_year DESC,
            pc.payroll_month DESC,
            epd.emp_id;

    END IF;

END$$

-- ---------------------------------------------------------------------
-- C-085  NEW FUNCTION hrms_esi_wage_limit
--        The ESI wage limit, read from the ESI slabs (the highest "to" value
--        of an active EE_ESI / EMP_ESI slab that charges something).
--        21000 only when no such slab exists.
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS hrms_esi_wage_limit$$
CREATE FUNCTION hrms_esi_wage_limit() RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_limit DECIMAL(12,2);
    SELECT MAX(s.slab_max_value) INTO v_limit
      FROM salary_component_slab s
      JOIN salary_component_master m ON m.component_id = s.component_id
     WHERE m.component_code IN ('EE_ESI', 'EMP_ESI')
       AND s.is_active = 1
       AND s.result_value > 0
       AND s.slab_max_value IS NOT NULL
       AND (s.effective_from IS NULL OR s.effective_from <= CURDATE())
       AND (s.effective_to IS NULL OR s.effective_to >= CURDATE());
    RETURN COALESCE(v_limit, 21000.00);
END$$

-- ---------------------------------------------------------------------
-- C-086  NEW PROCEDURE hrms_employee_payslip_list
--        Payslips from the payroll cycles (employee_payslips), for the
--        employee "Pay Roll" page and the admin payslips page. Replaces
--        new_pay_slip / view_all_salary there, which read the old salary_tbl.
--        p_target_emp_id : NULL = everyone (ADMIN / HR); EMP sees only self
--        p_month         : 'ALL' / NULL, a month name, or 1-12
--        p_year          : '2026-27' (financial year Apr-Mar), '2026', or NULL
--        Only paid employees with a payslip are listed.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_employee_payslip_list$$
CREATE PROCEDURE hrms_employee_payslip_list(
    IN p_requester_emp_id VARCHAR(20),
    IN p_target_emp_id    VARCHAR(20),
    IN p_month            VARCHAR(20),
    IN p_year             VARCHAR(10)
)
pl: BEGIN
    DECLARE v_category VARCHAR(50);
    DECLARE v_status   VARCHAR(20);
    DECLARE v_target   VARCHAR(20);
    DECLARE v_month    INT DEFAULT NULL;
    DECLARE v_from     INT DEFAULT NULL;   -- year * 12 + month
    DECLARE v_to       INT DEFAULT NULL;
    DECLARE v_m        VARCHAR(20);
    DECLARE v_y        VARCHAR(10);
    DECLARE v_n        INT DEFAULT 0;

    -- C-116: who is calling - active ADMIN, HR or EMP (user_login_details); an EMP sees only own payslips
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_requester_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_category IS NULL OR v_category NOT IN ('ADMIN', 'HR', 'EMP') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN, HR or EMP users can view payslips.' AS remarks;
        LEAVE pl;
    END IF;

    SET v_target = NULLIF(TRIM(p_target_emp_id), '');
    IF v_category = 'EMP' THEN
        SET v_target = TRIM(p_requester_emp_id);
    END IF;

    SET v_m = UPPER(TRIM(COALESCE(p_month, '')));
    IF v_m NOT IN ('', 'ALL') THEN
        IF v_m REGEXP '^[0-9]{1,2}$' THEN
            SET v_month = CAST(v_m AS UNSIGNED);
        ELSE
            SET v_month = FIELD(LEFT(v_m, 3), 'JAN','FEB','MAR','APR','MAY','JUN',
                                              'JUL','AUG','SEP','OCT','NOV','DEC');
        END IF;
        IF v_month NOT BETWEEN 1 AND 12 THEN
            SELECT 'N' AS status, 'Invalid month.' AS remarks;
            LEAVE pl;
        END IF;
    END IF;

    SET v_y = TRIM(COALESCE(p_year, ''));
    IF v_y REGEXP '^[0-9]{4}-[0-9]{2}$' THEN                 -- financial year
        SET v_from = CAST(LEFT(v_y, 4) AS UNSIGNED) * 12 + 4;
        SET v_to   = v_from + 11;
    ELSEIF v_y REGEXP '^[0-9]{4}$' THEN                      -- calendar year
        SET v_from = CAST(v_y AS UNSIGNED) * 12 + 1;
        SET v_to   = v_from + 11;
    ELSEIF v_y <> '' THEN
        SELECT 'N' AS status, 'Invalid year.' AS remarks;
        LEAVE pl;
    END IF;

    SELECT COUNT(*) INTO v_n
      FROM employee_payslips ps
      JOIN employee_payroll_details epd ON epd.payroll_detail_id = ps.payroll_detail_id
      JOIN payroll_runs pr ON pr.payroll_run_id = epd.payroll_run_id
      JOIN payroll_cycles pc ON pc.payroll_cycle_id = pr.payroll_cycle_id
     WHERE ps.payslip_status <> 'REVOKED'
       AND epd.payment_status = 'PAID'
       AND (v_target IS NULL OR epd.emp_id = v_target)
       AND (v_month IS NULL OR pc.payroll_month = v_month)
       AND (v_from IS NULL OR pc.payroll_year * 12 + pc.payroll_month BETWEEN v_from AND v_to);

    IF v_n = 0 THEN
        SELECT 'N' AS status, 'No payslips found for the selected period.' AS remarks;
        LEAVE pl;
    END IF;

    SELECT 'Y' AS status,
           'Payslips retrieved successfully' AS remarks,
           epd.emp_id,
           ud.emp_name,
           dm.department_name,
           ELT(pc.payroll_month, 'January','February','March','April','May','June','July',
               'August','September','October','November','December') AS month,
           pc.payroll_month AS month_no,
           pc.payroll_year AS year,
           pc.cycle_code,
           ps.payslip_number,
           epd.payroll_detail_id,
           epd.net_pay,
           epd.paid_at
      FROM employee_payslips ps
      JOIN employee_payroll_details epd ON epd.payroll_detail_id = ps.payroll_detail_id
      JOIN payroll_runs pr ON pr.payroll_run_id = epd.payroll_run_id
      JOIN payroll_cycles pc ON pc.payroll_cycle_id = pr.payroll_cycle_id
      LEFT JOIN user_details ud ON ud.emp_id = epd.emp_id
      LEFT JOIN department_master dm ON dm.department_id = ud.department
     WHERE ps.payslip_status <> 'REVOKED'
       AND epd.payment_status = 'PAID'
       AND (v_target IS NULL OR epd.emp_id = v_target)
       AND (v_month IS NULL OR pc.payroll_month = v_month)
       AND (v_from IS NULL OR pc.payroll_year * 12 + pc.payroll_month BETWEEN v_from AND v_to)
     ORDER BY pc.payroll_year DESC, pc.payroll_month DESC, epd.emp_id;
END$$

-- ---------------------------------------------------------------------
-- C-088  ALTER TABLE employee_payslips
--        One live payslip per payroll detail. April 2026 had two payslips
--        for BS00298 (detail 869, made in the same second); the later copy
--        is removed and a unique key stops it happening again. A REVOKED
--        payslip does not count, so a payslip can be made again after a
--        revoke.
-- ---------------------------------------------------------------------
DELETE ps
  FROM employee_payslips ps
  JOIN employee_payslips keep
    ON keep.payroll_detail_id = ps.payroll_detail_id
   AND keep.payslip_status <> 'REVOKED'
   AND keep.payslip_id < ps.payslip_id
 WHERE ps.payslip_status <> 'REVOKED'$$

CALL hrms_script_add_column('employee_payslips', 'active_detail_id',
     'BIGINT GENERATED ALWAYS AS (IF(`payslip_status` <> ''REVOKED'', `payroll_detail_id`, NULL)) STORED AFTER `payroll_detail_id`')$$
CALL hrms_script_add_index('employee_payslips', 'uq_eps_active_detail',
     'ALTER TABLE employee_payslips ADD UNIQUE KEY uq_eps_active_detail (active_detail_id)')$$

-- ---------------------------------------------------------------------
-- C-090  DATA : payslips missing for paid employees
--        February 2026 (cycle 5) was closed with no payslips. Makes the
--        missing payslip of every PAID employee in every paid / closed
--        cycle. Re-run makes nothing new.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_script_c090$$
CREATE PROCEDURE hrms_script_c090()
BEGIN
    DECLARE v_done  INT DEFAULT 0;
    DECLARE v_cycle BIGINT;
    DECLARE v_made  INT;
    DECLARE cur CURSOR FOR
        SELECT payroll_cycle_id FROM payroll_cycles
         WHERE cycle_status IN ('PARTIALLY_PAID', 'PAID', 'CLOSED') ORDER BY payroll_cycle_id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
    OPEN cur;
    rd: LOOP
        FETCH cur INTO v_cycle;
        IF v_done = 1 THEN LEAVE rd; END IF;
        CALL hrms_payroll_generate_payslips(v_cycle, NULL, 'SCRIPT', v_made);
    END LOOP;
    CLOSE cur;
END$$
CALL hrms_script_c090()$$
DROP PROCEDURE IF EXISTS hrms_script_c090$$

-- ---------------------------------------------------------------------
-- C-092  NEW PROCEDURE hrms_salary_esi_review
--        Current salaries (open period) of active employees with ESI = N
--        whose GROSS is within the ESI wage limit (C-085). Nothing is
--        changed: HR reviews them on the Salaries page.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_salary_esi_review$$
CREATE PROCEDURE hrms_salary_esi_review(IN p_emp_id VARCHAR(20))
er: BEGIN
    DECLARE v_ok    TINYINT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-115
    DECLARE v_limit DECIMAL(12,2);

    -- C-115: who is calling - active ADMIN or HR only (user_login_details)

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category

      FROM user_login_details

     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SET v_ok = IF(v_user_category IN ('ADMIN', 'HR'), 1, 0);
    IF v_ok = 0 THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can review salaries.' AS remarks;
        LEAVE er;
    END IF;

    SET v_limit = hrms_esi_wage_limit();

    SELECT 'Y' AS status,
           'ESI is off but GROSS is within the ESI wage limit' AS remarks,
           ss.emp_id,
           ss.structure_id,
           t.monthly_amount AS gross,
           v_limit AS esi_limit
      FROM salary_structure ss
      JOIN employee_salary_structure_totals t ON t.structure_id = ss.structure_id
      JOIN salary_component_master m ON m.component_id = t.component_id AND m.component_code = 'GROSS'
      -- same employees as the Salaries list: active login only
      JOIN user_login_details ul ON ul.emp_id = ss.emp_id AND LOWER(COALESCE(ul.status, '')) = 'active'
     WHERE ss.structure_status = 'ACTIVE'
       AND ss.effective_to IS NULL
       AND COALESCE(ss.esi_applicable, 'N') = 'N'
       AND t.monthly_amount > 0
       AND t.monthly_amount <= v_limit
     ORDER BY ss.emp_id;
END$$

-- ---------------------------------------------------------------------
-- C-093  DATA : statutory slabs valid from 01 Apr 2025
--        The EPF, ESI, PT and EPF-admin slabs loaded by C-044 started on
--        01 Apr 2026, so a payroll month before April 2026 (March 2026,
--        cycle 8) found no slab and paid EPF, ESI and PT as 0. The same
--        rules applied before, so their start date moves to 01 Apr 2025.
--        Only slabs still carrying the original C-044 date are changed.
-- ---------------------------------------------------------------------
UPDATE salary_component_slab
   SET effective_from = '2025-04-01', updated_at = CURRENT_TIMESTAMP
 WHERE created_by = 'SCRIPT' AND effective_from = '2026-04-01'$$

-- ---------------------------------------------------------------------
-- C-094  DATA : OTHERS uses TOTAL_EMPLOYER_CONTRIBUTION
--        OTHERS balances the salary to the CTC by taking away the employer
--        contributions, which were listed by name. A new employer
--        contribution would have been missed and the salary would no longer
--        add up to the CTC. The list is replaced by the total that already
--        holds exactly these four, so every amount stays the same and new
--        employer contributions are taken away automatically.
-- ---------------------------------------------------------------------
UPDATE salary_component_master
   SET formula_expression = '(CTC1 * 0.17) - TOTAL_EMPLOYER_CONTRIBUTION', updated_at = CURRENT_TIMESTAMP
 WHERE UPPER(component_code) = 'OTHERS'
   AND REPLACE(UPPER(formula_expression), ' ', '') = '(CTC1*0.17)-(ER_NPS+EMP_EPF+EMP_ESI+ER_ADMIN)'$$
UPDATE employee_salary_structure e
  JOIN salary_component_master m ON m.component_id = e.component_id
   SET e.formula_expression = m.formula_expression
 WHERE UPPER(m.component_code) = 'OTHERS' AND e.is_overridden = 0
   AND COALESCE(e.formula_expression, '') <> COALESCE(m.formula_expression, '')$$

-- ---------------------------------------------------------------------
-- C-100  NEW PROCEDURE hrms_component_rules_check   (the rule checker)
--        Looks at the components and slabs as they are now (inside the
--        save transaction they already hold the change) and lists what is
--        wrong, in tmp_hrms_findings:
--          ERROR   stops the save        WARNING / INFO  shown, save allowed
--        Checks
--          NAMES   a formula, base or slab uses an unknown or inactive name
--          ORDER   a component uses one calculated later that does not
--                  depend back on it (suggested order given); real circles
--                  (A uses B, B uses A) are listed as INFO - the engine
--                  repeats passes until they settle
--          SLAB    a slab that can never apply; a gap between ranges;
--                  no slab valid on a date that will be calculated
--                  (salary periods and payroll cycles not yet finalized)
--          TOTAL   a pay component that is not inside its total
--                  (earning -> GROSS, deduction -> TOTAL_DEDUCTIONS,
--                  employer -> TOTAL_EMPLOYER_CONTRIBUTION)
--          FORMULA a slab component also has a formula / % that is not used
--          CYCLE   a payroll cycle is calculated but not finalized
--        p_component_id NULL = all components; given = only findings that
--        involve that component (CYCLE always).
--        p_output 0 = fill the table only, 1 = also return the findings,
--                 2 = return the dependency list (code, uses, via) instead,
--                 3 = build the dependency list only (tmp_hrms_dep), no output
--        C-107: a TOTAL must use at least one component or total, and must be
--        calculated after everything it uses (ERROR); the suggested order now
--        points the right way (move the component below the total; move a
--        component above what it uses) and comes from hrms_free_order (C-106).
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
         WHERE d.uses NOT IN ('CTC','CTC1','ANNUAL_CTC','GROSS','TOTAL_DEDUCTIONS','TOTAL_EMPLOYER_CONTRIBUTION',
                              'ESI_APPLICABLE','PAY_DAYS','PAYABLE_DAYS','LOP_DAYS','MANUAL_AMOUNT','ESI_WAGE','STANDARD_ESI_WAGE')
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
-- C-101  NEW PROCEDURE hrms_component_change_finish   (internal)
--        The common end of every component / slab change, run inside the
--        caller's transaction (the caller commits or rolls back):
--          1. rule checker (C-100); an ERROR stops here
--          2. totals of every salary before the change
--          3. engine on every salary period (each on its own date)
--          4. totals after; the impact per employee; CTC balance; slab gaps
--        Results come back as JSON so they survive the caller's rollback:
--          p_findings  [{level, check, component, message, suggest_order}]
--          p_impact    {structures, changed, rows:[{emp_id, emp_name, gross_before,
--                       gross_after, ded_before, ded_after, net_before, net_after}]}
--                      (rows: the 50 biggest changes in net pay)
--        p_error NULL = can be saved.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_change_finish$$
CREATE PROCEDURE hrms_component_change_finish(
    IN  p_component_id BIGINT,
    OUT p_error        VARCHAR(500),
    OUT p_findings     LONGTEXT,
    OUT p_impact       LONGTEXT,
    OUT p_structures   INT,
    OUT p_changed      INT
)
BEGIN
    DECLARE v_errors   INT DEFAULT 0;
    DECLARE v_msg      VARCHAR(500) DEFAULT NULL;
    DECLARE v_emps     INT DEFAULT 0;
    DECLARE v_rows     LONGTEXT;
    DECLARE v_seq      INT DEFAULT NULL;

    SET p_error = NULL;
    SET p_findings = '[]';
    SET p_impact = NULL;
    SET p_structures = 0;
    SET p_changed = 0;
    SET SESSION group_concat_max_len = 1000000;

    CALL hrms_component_rules_check(p_component_id, 0);
    SELECT MIN(seq) INTO v_seq FROM tmp_hrms_findings WHERE level = 'ERROR';
    IF v_seq IS NOT NULL THEN
        SELECT MAX(message) INTO p_error FROM tmp_hrms_findings WHERE seq = v_seq;
    END IF;

    IF p_error IS NULL THEN
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_snap_before;
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_snap_after;
        CREATE TEMPORARY TABLE tmp_hrms_snap_before AS
            SELECT t.structure_id,
                   SUM(IF(UPPER(m.component_code) = 'GROSS', t.monthly_amount, 0))            AS gross,
                   SUM(IF(UPPER(m.component_code) = 'TOTAL_DEDUCTIONS', t.monthly_amount, 0)) AS ded,
                   SUM(IF(UPPER(m.component_code) = 'NET_PAY', t.monthly_amount, 0))          AS net,
                   SUM(IF(UPPER(m.component_code) = 'TOTAL_CTC', t.monthly_amount, 0))        AS tctc
              FROM employee_salary_structure_totals t
              JOIN salary_component_master m ON m.component_id = t.component_id
             GROUP BY t.structure_id;

        CALL hrms_recalculate_all_structures(p_structures, p_changed, v_errors, v_msg);

        IF v_msg IS NOT NULL THEN
            SET p_error = v_msg;
            INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
            VALUES ('ERROR', 'ENGINE', NULL, LEFT(CONCAT('Calculation stopped: ', v_msg), 700));
        ELSE
            CREATE TEMPORARY TABLE tmp_hrms_snap_after AS
                SELECT t.structure_id,
                       SUM(IF(UPPER(m.component_code) = 'GROSS', t.monthly_amount, 0))            AS gross,
                       SUM(IF(UPPER(m.component_code) = 'TOTAL_DEDUCTIONS', t.monthly_amount, 0)) AS ded,
                       SUM(IF(UPPER(m.component_code) = 'NET_PAY', t.monthly_amount, 0))          AS net,
                       SUM(IF(UPPER(m.component_code) = 'TOTAL_CTC', t.monthly_amount, 0))        AS tctc
                  FROM employee_salary_structure_totals t
                  JOIN salary_component_master m ON m.component_id = t.component_id
                 GROUP BY t.structure_id;

            SELECT COUNT(*) INTO v_emps
              FROM tmp_hrms_snap_after a
              LEFT JOIN tmp_hrms_snap_before b ON b.structure_id = a.structure_id
             WHERE ABS(a.gross - COALESCE(b.gross, 0)) >= 0.01 OR ABS(a.ded - COALESCE(b.ded, 0)) >= 0.01
                OR ABS(a.net - COALESCE(b.net, 0)) >= 0.01;

            SELECT GROUP_CONCAT(j ORDER BY k DESC, emp SEPARATOR ',') INTO v_rows
              FROM (
                    SELECT ABS(a.net - COALESCE(b.net, 0)) AS k, ss.emp_id AS emp,
                           JSON_OBJECT('emp_id', ss.emp_id, 'emp_name', ud.emp_name,
                                       'from', DATE_FORMAT(ss.effective_from, '%d %b %Y'),
                                       'gross_before', COALESCE(b.gross, 0), 'gross_after', a.gross,
                                       'ded_before', COALESCE(b.ded, 0), 'ded_after', a.ded,
                                       'net_before', COALESCE(b.net, 0), 'net_after', a.net) AS j
                      FROM tmp_hrms_snap_after a
                      LEFT JOIN tmp_hrms_snap_before b ON b.structure_id = a.structure_id
                      JOIN salary_structure ss ON ss.structure_id = a.structure_id
                      LEFT JOIN user_details ud ON ud.emp_id = ss.emp_id
                     WHERE ABS(a.gross - COALESCE(b.gross, 0)) >= 0.01 OR ABS(a.ded - COALESCE(b.ded, 0)) >= 0.01
                        OR ABS(a.net - COALESCE(b.net, 0)) >= 0.01
                     ORDER BY k DESC, emp
                     LIMIT 50
                   ) z;
            SET p_impact = CONCAT('{"structures":', p_structures, ',"changed":', v_emps,
                                  ',"rows":[', COALESCE(v_rows, ''), ']}');

            -- the salary no longer adds up to the CTC (only salaries that did before)
            INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
            SELECT 'WARNING', 'CTC', NULL,
                   LEFT(CONCAT(COUNT(DISTINCT ss.emp_id), ' employee', IF(COUNT(DISTINCT ss.emp_id) = 1, '', 's'),
                               ' would no longer add up to the CTC (TOTAL_CTC differs from CTC): ',
                               SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT ss.emp_id ORDER BY ss.emp_id SEPARATOR ', '), ', ', 10),
                               IF(COUNT(DISTINCT ss.emp_id) > 10, CONCAT(' and ', COUNT(DISTINCT ss.emp_id) - 10, ' more'), ''), '.'), 700)
              FROM tmp_hrms_snap_after a
              JOIN tmp_hrms_snap_before b ON b.structure_id = a.structure_id
              JOIN salary_structure ss ON ss.structure_id = a.structure_id
             WHERE ABS(a.tctc - ss.monthly_ctc) > 1 AND ABS(b.tctc - ss.monthly_ctc) <= 1
            HAVING COUNT(*) > 0;

            -- employees whose value fell in a slab gap
            INSERT INTO tmp_hrms_findings (level, check_code, component_code, message)
            SELECT 'WARNING', 'SLAB', UPPER(m.component_code),
                   LEFT(CONCAT(UPPER(m.component_code), ': ', COUNT(DISTINCT ss.emp_id), ' employee', IF(COUNT(DISTINCT ss.emp_id) = 1, '', 's'),
                               ' fall in no slab range and get 0: ',
                               SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT ss.emp_id ORDER BY ss.emp_id SEPARATOR ', '), ', ', 10),
                               IF(COUNT(DISTINCT ss.emp_id) > 10, CONCAT(' and ', COUNT(DISTINCT ss.emp_id) - 10, ' more'), ''), '.'), 700)
              FROM tmp_hrms_gap_list g
              JOIN salary_component_master m ON m.component_id = g.cid
              JOIN salary_structure ss ON ss.structure_id = g.structure_id
             GROUP BY m.component_id, m.component_code;
        END IF;
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_snap_before;
        DROP TEMPORARY TABLE IF EXISTS tmp_hrms_snap_after;
    END IF;

    SELECT CONCAT('[', COALESCE(GROUP_CONCAT(JSON_OBJECT('level', level, 'check', check_code, 'component', component_code,
                                                         'message', message, 'suggest_order', suggest_order)
                                             ORDER BY FIELD(level, 'ERROR', 'WARNING', 'INFO'), seq SEPARATOR ','), ''), ']')
      INTO p_findings
      FROM tmp_hrms_findings;
END$$

-- ---------------------------------------------------------------------
-- C-102  NEW PROCEDURE hrms_component_cycle_guard   (internal)
--        After a saved rule change: every payroll cycle that is being
--        calculated, calculated or approved (not finalized) goes back to
--        STRUCTURE_VERIFIED and its employees to PENDING, so the next
--        calculation uses the new rules. Finalized / paid cycles are never
--        touched. Runs inside the caller's transaction.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_cycle_guard$$
CREATE PROCEDURE hrms_component_cycle_guard(
    IN  p_emp_id VARCHAR(20),
    IN  p_reason VARCHAR(200),
    OUT p_notice VARCHAR(500)
)
BEGIN
    DECLARE v_done   INT DEFAULT 0;
    DECLARE v_cycle  BIGINT;
    DECLARE v_status VARCHAR(30);
    DECLARE v_label  VARCHAR(40);
    DECLARE cur CURSOR FOR
        SELECT payroll_cycle_id, cycle_status,
               CONCAT(ELT(payroll_month, 'January','February','March','April','May','June','July',
                          'August','September','October','November','December'), ' ', payroll_year)
          FROM payroll_cycles
         WHERE cycle_status IN ('PROCESSING', 'CALCULATED', 'APPROVED');
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    SET p_notice = NULL;
    OPEN cur;
    cy: LOOP
        SET v_done = 0;
        FETCH cur INTO v_cycle, v_status, v_label;
        IF v_done = 1 THEN LEAVE cy; END IF;

        UPDATE employee_payroll_details epd
          JOIN payroll_runs pr ON pr.payroll_run_id = epd.payroll_run_id
           SET epd.employee_payroll_status = 'PENDING',
               epd.calculation_remarks = 'Salary rules changed: calculate again.'
         WHERE pr.payroll_cycle_id = v_cycle;
        UPDATE payroll_runs SET run_status = 'DRAFT', approved_by = NULL, approved_at = NULL
         WHERE payroll_cycle_id = v_cycle;
        UPDATE payroll_cycles SET cycle_status = 'STRUCTURE_VERIFIED', updated_at = CURRENT_TIMESTAMP
         WHERE payroll_cycle_id = v_cycle;
        CALL hrms_payroll_log(v_cycle, NULL, NULL, 'RULES_CHANGED', v_status, 'STRUCTURE_VERIFIED',
                              CONCAT(COALESCE(p_reason, 'Salary rules changed'), '. Calculate the payroll again.'), p_emp_id);
        SET p_notice = LEFT(CONCAT(COALESCE(CONCAT(p_notice, ' '), ''), 'Payroll ', v_label, ' was ', v_status,
                                   ' and is back at "Structures verified": calculate it again.'), 500);
    END LOOP cy;
    CLOSE cur;
END$$

-- ---------------------------------------------------------------------
-- C-106  NEW FUNCTION hrms_free_order
--        A free calculation order after p_after and before p_before: the
--        middle of the gap between p_after and the next order in use
--        (active components, p_exclude_id left out). NULL = no free number.
--        Used by the automatic order of a new component (C-039) and by the
--        suggestions of the rule checker (C-100).
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS hrms_free_order$$
CREATE FUNCTION hrms_free_order(p_after INT, p_before INT, p_exclude_id BIGINT) RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_after INT;
    DECLARE v_next  INT;
    DECLARE v_upper INT;
    SET v_after = COALESCE(p_after, 0);
    SELECT MIN(calculation_order) INTO v_next
      FROM salary_component_master
     WHERE is_active = 1 AND calculation_order > v_after
       AND (p_exclude_id IS NULL OR component_id <> p_exclude_id);
    SET v_upper = LEAST(COALESCE(v_next, v_after + 20), COALESCE(p_before, 2147483647), 10000);
    IF v_upper - v_after >= 2 THEN
        RETURN v_after + FLOOR((v_upper - v_after) / 2);
    END IF;
    RETURN NULL;
END$$

-- ---------------------------------------------------------------------
-- C-108  ALTER TABLE employee_payroll_component_details
--        calculation_scope: COMPONENT = a pay line, AGGREGATE = a total
--        (GROSS, NET_PAY, TOTAL_CTC ...). calculation_order: the order the
--        engine used, so totals can be listed in that order.
-- ---------------------------------------------------------------------
CALL hrms_script_add_column('employee_payroll_component_details', 'calculation_scope',
     'ENUM(''COMPONENT'',''AGGREGATE'') NOT NULL DEFAULT ''COMPONENT'' AFTER `component_type`')$$
CALL hrms_script_add_column('employee_payroll_component_details', 'calculation_order',
     'INT NULL AFTER `calculation_scope`')$$
CALL hrms_script_add_index('employee_payroll_component_details', 'idx_epcd_detail_scope',
     'ALTER TABLE employee_payroll_component_details ADD INDEX idx_epcd_detail_scope (payroll_detail_id, calculation_scope)')$$
UPDATE employee_payroll_component_details c
  JOIN salary_component_master m ON m.component_id = c.component_id
   SET c.calculation_order = m.calculation_order
 WHERE c.calculation_order IS NULL AND c.calculation_scope = 'COMPONENT'$$

-- ---------------------------------------------------------------------
-- C-110  DATA : totals of the payroll months already calculated
--        Months calculated before C-109 have no total rows. They are added
--        from the totals already stored on the employee row, so they match
--        exactly what was paid: GROSS = gross_earnings, TOTAL_DEDUCTIONS =
--        total_deductions, TOTAL_EMPLOYER_CONTRIBUTION = employer_contributions,
--        NET_PAY = net_pay, TOTAL_CTC = gross + employer contributions (only
--        while its formula is GROSS + TOTAL_EMPLOYER_CONTRIBUTION).
--        Employees that already have total rows are skipped (re-run safe).
-- ---------------------------------------------------------------------
INSERT INTO employee_payroll_component_details
    (payroll_detail_id, component_id, component_code, component_name, component_type,
     calculation_scope, calculation_order, calculation_type,
     component_value, percentage_base, percentage_value, formula_expression, calculated_amount, is_taxable)
SELECT epd.payroll_detail_id, m.component_id, m.component_code, m.component_name, m.component_type,
       'AGGREGATE', m.calculation_order, 'FORMULA', 0, 'NONE', 0, m.formula_expression,
       CASE UPPER(m.component_code)
            WHEN 'GROSS'                       THEN epd.gross_earnings
            WHEN 'TOTAL_DEDUCTIONS'            THEN epd.total_deductions
            WHEN 'TOTAL_EMPLOYER_CONTRIBUTION' THEN epd.employer_contributions
            WHEN 'NET_PAY'                     THEN epd.net_pay
            ELSE COALESCE(epd.gross_earnings, 0) + COALESCE(epd.employer_contributions, 0)
       END,
       COALESCE(m.is_taxable, 0)
  FROM employee_payroll_details epd
  JOIN salary_component_master m
    ON m.calculation_scope = 'AGGREGATE' AND m.is_active = 1
   AND (UPPER(m.component_code) IN ('GROSS', 'TOTAL_DEDUCTIONS', 'TOTAL_EMPLOYER_CONTRIBUTION', 'NET_PAY')
        OR (UPPER(m.component_code) = 'TOTAL_CTC'
            AND REPLACE(UPPER(m.formula_expression), ' ', '') = 'GROSS+TOTAL_EMPLOYER_CONTRIBUTION'))
 WHERE epd.employee_payroll_status IN ('CALCULATED', 'APPROVED', 'FINALIZED')
   AND NOT EXISTS (SELECT 1 FROM employee_payroll_component_details x
                    WHERE x.payroll_detail_id = epd.payroll_detail_id AND x.calculation_scope = 'AGGREGATE')$$

-- ---------------------------------------------------------------------
-- C-112  UPDATE PROCEDURE hrms_get_payroll_month_details
--        (payroll summary page) Unchanged except: salary_components holds
--        the pay components only, and a new column salary_totals holds the
--        totals of the month. Original in script_backup_original_procedures.sql.
--        C-116: standard role check (active ADMIN or HR from user_login_details).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_get_payroll_month_details$$
CREATE PROCEDURE `hrms_get_payroll_month_details`(
    IN p_emp_id VARCHAR(20),
    IN p_month TINYINT,
    IN p_year SMALLINT
)
BEGIN
    DECLARE v_requester_found INT DEFAULT 0;
    DECLARE v_cycle_found INT DEFAULT 0;
    DECLARE v_remarks VARCHAR(500) DEFAULT NULL;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-116

    

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_remarks = MESSAGE_TEXT;

        SELECT
            'N' AS status,
            v_remarks AS remarks;
    END;

    

    SET time_zone = '+05:30';

    

    IF p_emp_id IS NULL OR TRIM(p_emp_id) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Requester employee ID is required';
    END IF;

    

    IF p_month IS NULL OR p_month NOT BETWEEN 1 AND 12 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid payroll month';
    END IF;

    

    IF p_year IS NULL OR p_year NOT BETWEEN 2000 AND 2100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid payroll year';
    END IF;

    

    -- C-116: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SIGNAL SQLSTATE '45000'   -- returned as an 'N' row by the handler above
            SET MESSAGE_TEXT = 'Access denied: only active ADMIN or HR users can view payroll month details.';
    END IF;

    

    SELECT COUNT(*)
    INTO v_cycle_found
    FROM payroll_cycles
    WHERE payroll_month = p_month
      AND payroll_year = p_year;

    IF v_cycle_found = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Payroll cycle not found for the selected month and year';
    END IF;

    

    WITH ranked_payroll AS
    (
        SELECT
            pc.payroll_cycle_id,
            pc.payroll_month,
            pc.payroll_year,
            pc.period_start,
            pc.period_end,
            pc.payment_date,
            pc.cycle_status,

            pr.payroll_run_id,
            pr.run_number,
            pr.run_type,
            pr.run_status,
            pr.total_employees,

            epd.payroll_detail_id,
            epd.emp_id,
            epd.structure_id,

            epd.monthly_ctc,
            epd.annual_ctc,

            epd.total_days,
            epd.payable_days,
            epd.paid_leave_days,
            epd.unpaid_leave_days,
            epd.absent_days,

            epd.ctc1,
            epd.gross_earnings,
            epd.total_deductions,
            epd.employer_contributions,
            epd.net_pay,

            epd.calculation_version,
            epd.calculation_remarks,
            epd.employee_payroll_status,

            ROW_NUMBER() OVER
            (
                PARTITION BY epd.emp_id
                ORDER BY
                    pr.run_number DESC,
                    pr.payroll_run_id DESC,
                    epd.payroll_detail_id DESC
            ) AS row_num

        FROM payroll_cycles pc

        INNER JOIN payroll_runs pr
            ON pr.payroll_cycle_id = pc.payroll_cycle_id

        INNER JOIN employee_payroll_details epd
            ON epd.payroll_run_id = pr.payroll_run_id

        WHERE pc.payroll_month = p_month
          AND pc.payroll_year = p_year
    )

    SELECT
        
        'Y' AS status,
        'Payroll month details retrieved successfully' AS remarks,

        
        rp.payroll_cycle_id,
        rp.payroll_month,

        MONTHNAME(
            STR_TO_DATE(
                CONCAT(
                    rp.payroll_year,
                    '-',
                    LPAD(rp.payroll_month, 2, '0'),
                    '-01'
                ),
                '%Y-%m-%d'
            )
        ) AS month_name,

        rp.payroll_year,
        rp.period_start,
        rp.period_end,
        rp.payment_date,
        rp.cycle_status AS payroll_cycle_status,

        
        rp.payroll_run_id,
        rp.run_number,
        rp.run_type,
        rp.run_status AS payroll_run_status,
        rp.total_employees,

        
        rp.payroll_detail_id,
        rp.emp_id,
        ud.ref_id,
        ud.emp_name,
        ud.email,
        ud.mobile,

        
        ud.dob,
        ud.gender,
        ud.marital_status,
        ud.father_name,
        ud.mother_name,
        ud.current_address,
        ud.perminent_address,

        
        ud.bank_holder_name,
        ud.bank_name,
        ud.bank_branch,
        ud.bank_account_no,
        ud.ifsc,
        ud.upi_id,
        ud.bank_account_type,

        
        ud.pan,
        ud.pf_account_no,
        ud.esic_no,
        ud.aadhaar,
        ud.uan,

        
        ud.location,
        ud.department,
        ud.designation,
        ud.reporting,
        ud.joining_date,
        ud.at_blooms,
        ud.profisional_details_status,

        
        rp.structure_id,
        rp.monthly_ctc,
        rp.annual_ctc,

        
        rp.total_days,
        rp.payable_days,
        rp.paid_leave_days,
        rp.unpaid_leave_days,
        rp.absent_days,

        
        rp.ctc1,
        rp.gross_earnings,
        rp.total_deductions,
        rp.employer_contributions,
        rp.net_pay,

        
        rp.employee_payroll_status
            AS monthly_employee_payroll_status,

        rp.calculation_version,
        rp.calculation_remarks,

        
        COALESCE(
            (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'component_id', epcd.component_id,
                        'component_code', epcd.component_code,
                        'component_name', epcd.component_name,
                        'component_type', epcd.component_type,
                        'calculation_type', epcd.calculation_type,
                        'component_value', epcd.component_value,
                        'percentage_base', epcd.percentage_base,
                        'percentage_value', epcd.percentage_value,
                        'formula_expression', epcd.formula_expression,
                        'calculated_amount', epcd.calculated_amount,
                        'is_taxable', epcd.is_taxable
                    )
                )
                FROM employee_payroll_component_details epcd
                WHERE epcd.payroll_detail_id =
                      rp.payroll_detail_id
                  AND epcd.calculation_scope = 'COMPONENT'   -- C-112
            ),
            JSON_ARRAY()
        ) AS salary_components,

        -- C-112: the totals of the month (GROSS, NET_PAY, TOTAL_CTC ...)
        COALESCE(
            (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'component_code', epcd.component_code,
                        'component_name', epcd.component_name,
                        'component_type', epcd.component_type,
                        'calculation_order', epcd.calculation_order,
                        'calculated_amount', epcd.calculated_amount
                    )
                )
                FROM employee_payroll_component_details epcd
                WHERE epcd.payroll_detail_id = rp.payroll_detail_id
                  AND epcd.calculation_scope = 'AGGREGATE'
            ),
            JSON_ARRAY()
        ) AS salary_totals

    FROM ranked_payroll rp

    LEFT JOIN user_details ud
        ON ud.emp_id = rp.emp_id

    WHERE rp.row_num = 1

    ORDER BY rp.emp_id;

END$$

-- ---------------------------------------------------------------------
-- C-113  NEW FUNCTION hrms_pay_days
--        Pay days of a month = 30 - unpaid (LOP) days, never below 0.
--        Every month counts as 30 days: full attendance is always the full
--        CTC (before: paid days capped at 30, so a 28-day period paid only
--        28/30 of the CTC), and each unpaid day costs CTC / 30.
--        Used by hrms_payroll_prepare_run (C-061), hrms_payroll_calculate_employee
--        (C-063) and the old hrms_create_payroll_cycle_complete (C-045).
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS hrms_pay_days$$
CREATE FUNCTION hrms_pay_days(p_unpaid_days DECIMAL(6,2)) RETURNS DECIMAL(5,2)
DETERMINISTIC NO SQL
BEGIN
    RETURN GREATEST(30 - GREATEST(COALESCE(p_unpaid_days, 0), 0), 0);
END$$

-- ---------------------------------------------------------------------
-- C-117  UPDATE PROCEDURE hrms_get_employee_salary_structure
--        (Salaries list) Unchanged except the standard role check: active
--        ADMIN or HR from user_login_details. Original in
--        script_backup_original_procedures.sql.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_get_employee_salary_structure$$
CREATE PROCEDURE `hrms_get_employee_salary_structure`(
    IN p_requester_emp_id VARCHAR(20),
    IN p_target_emp_id VARCHAR(20)
)
BEGIN
    DECLARE v_user_category VARCHAR(50) DEFAULT NULL;
    DECLARE v_user_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_user_found INT DEFAULT 0;
    DECLARE v_target_found INT DEFAULT 0;

    
    -- C-117: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_requester_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view salary details.' AS remarks;
    ELSE

            
            IF NULLIF(TRIM(p_target_emp_id), '') IS NOT NULL THEN

                SELECT COUNT(*)
                INTO v_target_found
                FROM user_login_details
                WHERE emp_id = TRIM(p_target_emp_id)
                  AND LOWER(COALESCE(status, '')) = 'active';

                IF v_target_found = 0 THEN

                    SELECT 'N' AS status,
                           'Target employee not found or inactive'
                           AS remarks;

                ELSE

                    SELECT
                        'Y' AS status,
                        'Employee salary details retrieved successfully'
                            AS remarks,

                        ud.emp_id,
                        ud.emp_name,
                        ss.structure_id,
                        ss.monthly_ctc,
                        ss.annual_ctc,
                        ss.effective_from,
                        ss.effective_to,
                        ss.structure_status,

                        COUNT(ess.employee_component_id)
                            AS total_components,

                        COALESCE(SUM(
                            scm.component_type = 'EARNING'
                        ), 0) AS earnings_count,

                        COALESCE(SUM(
                            scm.component_type = 'DEDUCTION'
                        ), 0) AS deductions_count,

                        COALESCE(SUM(
                            scm.component_type = 'EMPLOYER_CONTRIBUTION'
                        ), 0) AS employer_contribution_count,

                        COALESCE(
                            JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    'employee_component_id',
                                        ess.employee_component_id,
                                    'component_id',
                                        scm.component_id,
                                    'component_code',
                                        scm.component_code,
                                    'component_name',
                                        scm.component_name,
                                    'component_type',
                                        scm.component_type,
                                    'calculation_type',
                                        ess.calculation_type,
                                    'component_value',
                                        ess.component_value,
                                    'percentage_base',
                                        ess.percentage_base,
                                    'formula_expression',
                                        ess.formula_expression,
                                    'monthly_amount',
                                        ess.monthly_amount,
                                    'is_taxable',
                                        scm.is_taxable,
                                    'is_active',
                                        scm.is_active
                                )
                            ),
                            JSON_ARRAY()
                        ) AS salary_components

                    FROM user_details ud

                    INNER JOIN salary_structure ss
                        ON ss.emp_id = ud.emp_id

                    INNER JOIN employee_salary_structure ess
                        ON ess.structure_id = ss.structure_id

                    INNER JOIN salary_component_master scm
                        ON scm.component_id = ess.component_id
                       AND scm.is_active = 1

                    WHERE ud.emp_id = TRIM(p_target_emp_id)
                      AND ss.effective_from <= CURDATE()
                      AND (
                          ss.effective_to IS NULL
                          OR ss.effective_to >= CURDATE()
                      )
                      AND UPPER(COALESCE(ss.structure_status, ''))
                          = 'ACTIVE'

                    GROUP BY
                        ud.emp_id,
                        ud.emp_name,
                        ss.structure_id,
                        ss.monthly_ctc,
                        ss.annual_ctc,
                        ss.effective_from,
                        ss.effective_to,
                        ss.structure_status;

                END IF;

            ELSE

                
                SELECT
                    'Y' AS status,
                    'Active employee salary details retrieved successfully'
                        AS remarks,

                    ud.emp_id,
                    ud.emp_name,
                    ss.structure_id,
                    ss.monthly_ctc,
                    ss.annual_ctc,
                    ss.effective_from,
                    ss.effective_to,
                    ss.structure_status,

                    COUNT(ess.employee_component_id)
                        AS total_components,

                    COALESCE(SUM(
                        scm.component_type = 'EARNING'
                    ), 0) AS earnings_count,

                    COALESCE(SUM(
                        scm.component_type = 'DEDUCTION'
                    ), 0) AS deductions_count,

                    COALESCE(SUM(
                        scm.component_type = 'EMPLOYER_CONTRIBUTION'
                    ), 0) AS employer_contribution_count,

                    COALESCE(
                        JSON_ARRAYAGG(
                            JSON_OBJECT(
                                'employee_component_id',
                                    ess.employee_component_id,
                                'component_id',
                                    scm.component_id,
                                'component_code',
                                    scm.component_code,
                                'component_name',
                                    scm.component_name,
                                'component_type',
                                    scm.component_type,
                                'calculation_type',
                                    ess.calculation_type,
                                'component_value',
                                    ess.component_value,
                                'percentage_base',
                                    ess.percentage_base,
                                'formula_expression',
                                    ess.formula_expression,
                                'monthly_amount',
                                    ess.monthly_amount,
                                'is_taxable',
                                    scm.is_taxable,
                                'is_active',
                                    scm.is_active
                            )
                        ),
                        JSON_ARRAY()
                    ) AS salary_components

                FROM user_details ud

                INNER JOIN user_login_details ul
                    ON ul.emp_id = ud.emp_id

                INNER JOIN salary_structure ss
                    ON ss.emp_id = ud.emp_id

                INNER JOIN employee_salary_structure ess
                    ON ess.structure_id = ss.structure_id

                INNER JOIN salary_component_master scm
                    ON scm.component_id = ess.component_id
                   AND scm.is_active = 1

                WHERE LOWER(COALESCE(ul.status, '')) = 'active'
                  AND ss.effective_from <= CURDATE()
                  AND (
                      ss.effective_to IS NULL
                      OR ss.effective_to >= CURDATE()
                  )
                  AND UPPER(COALESCE(ss.structure_status, ''))
                      = 'ACTIVE'

                GROUP BY
                    ud.emp_id,
                    ud.emp_name,
                    ss.structure_id,
                    ss.monthly_ctc,
                    ss.annual_ctc,
                    ss.effective_from,
                    ss.effective_to,
                    ss.structure_status

                ORDER BY ud.emp_id;

            END IF;

        END IF;
END$$

-- ---------------------------------------------------------------------
-- C-118  UPDATE PROCEDURE finalize_payroll_attendance_proc
--        Unchanged except the standard role check: active ADMIN or HR (the
--        list also had SUPERADMIN, a role nobody has).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS finalize_payroll_attendance_proc$$
CREATE PROCEDURE `finalize_payroll_attendance_proc`(
    IN p_emp_id VARCHAR(20),
    IN p_month INT,
    IN p_year INT
)
main_block: BEGIN

    DECLARE v_user_category VARCHAR(20);
    DECLARE v_audit_old JSON DEFAULT NULL;    -- C-134
    DECLARE v_audit_new JSON DEFAULT NULL;    -- C-134
    DECLARE v_audit_cycle BIGINT DEFAULT NULL;    -- C-134

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

    

    SET v_audit_old = hrms_audit_attendance_json(p_month, p_year);    -- C-134
    START TRANSACTION;

    UPDATE payroll_attendance_summary
    SET
        is_finalized = 'Y',
        updated_at = NOW()
    WHERE payroll_month = p_month
      AND payroll_year = p_year
      AND (is_finalized IS NULL OR is_finalized <> 'Y');

    -- C-134: audit trail
    SET v_audit_new = hrms_audit_attendance_json(p_month, p_year);
    SELECT MAX(payroll_cycle_id) INTO v_audit_cycle FROM payroll_cycles WHERE payroll_month = p_month AND payroll_year = p_year;
    CALL hrms_payroll_audit_add('ATTENDANCE', 'FINALIZE', 'payroll_attendance_summary',
         CONCAT(p_year, '-', LPAD(p_month, 2, '0')), NULL, v_audit_cycle, p_month, p_year, v_audit_old, v_audit_new,
         CONCAT('Attendance finalized for ', LPAD(p_month, 2, '0'), '/', p_year, ' (', v_total_records, ' employees).'), p_emp_id);
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
-- C-119  UPDATE PROCEDURE sp_generate_payroll_attendance
--        Unchanged except the standard role check: a refusal is an 'N' row
--        (status, message - the columns this page reads), not a database error.
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
    DECLARE v_audit_old JSON DEFAULT NULL;    -- C-134
    DECLARE v_audit_new JSON DEFAULT NULL;    -- C-134
    DECLARE v_audit_cycle BIGINT DEFAULT NULL;    -- C-134

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

    

    SET v_audit_old = hrms_audit_attendance_json(p_month, p_year);    -- C-134
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

    

    -- C-134: audit trail (month totals before / after)
    SET v_audit_new = hrms_audit_attendance_json(p_month, p_year);
    SELECT MAX(payroll_cycle_id) INTO v_audit_cycle FROM payroll_cycles WHERE payroll_month = p_month AND payroll_year = p_year;
    CALL hrms_payroll_audit_add('ATTENDANCE', 'GENERATE', 'payroll_attendance_summary',
         CONCAT(p_year, '-', LPAD(p_month, 2, '0')), NULL, v_audit_cycle, p_month, p_year, v_audit_old, v_audit_new,
         CONCAT('Generated for ', v_generated_count, ' employees, ', DATE_FORMAT(v_start_date, '%d %b %Y'), ' to ',
                DATE_FORMAT(v_end_date, '%d %b %Y'), '.'), p_admin_emp_id);
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
-- C-120  UPDATE PROCEDURE sp_admin_edit_absent_attendance
--        It had no role check: any logged-in employee could turn an absence
--        into WFH or leave (changing LOP and pay). Now only an active ADMIN or
--        HR (p_admin_emp_id, from user_login_details) can; others get
--        p_out_status = 'N'.
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
    DECLARE v_audit_new   JSON    DEFAULT NULL;    -- C-134
    DECLARE v_audit_cycle BIGINT  DEFAULT NULL;    -- C-134
    DECLARE v_audit_month INT     DEFAULT NULL;    -- C-134
    DECLARE v_audit_year  INT     DEFAULT NULL;    -- C-134
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

    -- C-134: audit trail of a successful edit (the payroll month is the cycle whose period has the date)
    IF p_out_status = 'Y' THEN
        SELECT MAX(payroll_cycle_id), MAX(payroll_month), MAX(payroll_year) INTO v_audit_cycle, v_audit_month, v_audit_year
          FROM payroll_cycles WHERE p_att_date BETWEEN period_start AND period_end;
        SET v_audit_new = (SELECT JSON_OBJECT('status', status, 'punch_in', punch_in, 'punch_out', punch_out)
                             FROM attendance WHERE emp_id = p_emp_id AND attendance_date = p_att_date LIMIT 1);
        SET v_audit_new = JSON_MERGE_PATCH(COALESCE(v_audit_new, JSON_OBJECT()),
                                           JSON_OBJECT('edit_type', UPPER(p_edit_type), 'leave_application_id', v_app_id));
        CALL hrms_payroll_audit_add('ATTENDANCE', 'ABSENCE_EDIT', 'attendance', DATE_FORMAT(p_att_date, '%Y-%m-%d'),
             p_emp_id, v_audit_cycle, v_audit_month, v_audit_year,
             JSON_OBJECT('status', v_att_status, 'date', DATE_FORMAT(p_att_date, '%Y-%m-%d')), v_audit_new,
             p_out_message, p_admin_emp_id);
    END IF;

    END main_block;

END$$

-- ---------------------------------------------------------------------
-- C-121  UPDATE PROCEDURE get_payroll_attendance_data_proc
--        Was ADMIN only (HR running payroll saw no attendance) and did not
--        check that the login is active. Now the standard check; a refusal is
--        an 'N' row. The attendance rows are unchanged.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_payroll_attendance_data_proc$$
CREATE PROCEDURE `get_payroll_attendance_data_proc`(
    IN p_emp_id VARCHAR(20),
    IN p_month INT,
    IN p_year INT
)
pa: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;

    -- C-121: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view payroll attendance.' AS remarks;
        LEAVE pa;
    END IF;

    SELECT p.*, e.emp_name,
           IFNULL(d.department_name, 'N/A') AS department,
           IFNULL(dg.designation_name, 'N/A') AS designation
      FROM payroll_attendance_summary p
      JOIN user_details e ON p.emp_id = e.emp_id
      LEFT JOIN department_master d ON e.department = d.department_id
      LEFT JOIN designation_master dg ON e.designation = dg.designation_id
     WHERE p.payroll_month = p_month AND p.payroll_year = p_year
     ORDER BY p.emp_id ASC;
END$$

-- ---------------------------------------------------------------------
-- C-122  UPDATE PROCEDURE sp_get_payroll_cycle_status
--        (attendance cycle page) p_emp_id added as the first parameter with
--        the standard role check; a wrong year is an 'N' row, not an error.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_get_payroll_cycle_status$$
CREATE PROCEDURE `sp_get_payroll_cycle_status`(
    IN p_emp_id VARCHAR(20),
    IN p_financial_year VARCHAR(9)
)
cs: BEGIN
    DECLARE v_start_year INT;
    DECLARE v_end_year INT;
    DECLARE v_cycle_start_day INT;
    DECLARE v_cycle_end_day INT;
    DECLARE v_total_records INT DEFAULT 0;
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-122
    DECLARE v_err VARCHAR(500) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        SELECT 'N' AS status, v_err AS remarks;
    END;

    
    SET time_zone = '+05:30';

    -- C-122: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view the attendance cycle.' AS remarks;
        LEAVE cs;
    END IF;

    
    IF p_financial_year IS NULL
       OR p_financial_year NOT REGEXP '^[0-9]{4}-[0-9]{4}$'
    THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Invalid financial year. Use YYYY-YYYY.';
    END IF;

    SET v_start_year =
        CAST(LEFT(p_financial_year, 4) AS UNSIGNED);

    SET v_end_year =
        CAST(RIGHT(p_financial_year, 4) AS UNSIGNED);

    
    IF v_end_year <> v_start_year + 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Financial year must contain consecutive years.';
    END IF;

    
    SELECT
        payroll_cycle_start_day,
        payroll_cycle_end_day
    INTO
        v_cycle_start_day,
        v_cycle_end_day
    FROM company_settings
    ORDER BY id
    LIMIT 1;

    IF v_cycle_start_day IS NULL
       OR v_cycle_end_day IS NULL
       OR v_cycle_start_day NOT BETWEEN 1 AND 31
       OR v_cycle_end_day NOT BETWEEN 1 AND 31
    THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Invalid payroll cycle configuration.';
    END IF;

    
    SELECT COUNT(*)
    INTO v_total_records
    FROM payroll_attendance_summary
    WHERE
        (payroll_year = v_start_year
         AND payroll_month BETWEEN 4 AND 12)
        OR
        (payroll_year = v_end_year
         AND payroll_month BETWEEN 1 AND 3);

    
    IF v_total_records = 0 THEN

        SELECT
            p_financial_year AS financial_year,
            NULL AS payroll_year,
            NULL AS payroll_month,
            NULL AS cycle_name,
            NULL AS cycle_start_date,
            NULL AS cycle_end_date,
            0 AS employee_count,
            0 AS finalized_employee_count,
            'N' AS status,
            NULL AS attendance_status,
            'Data not available' AS remarks,
            '+05:30' AS timezone;

    ELSE

        WITH RECURSIVE payroll_months AS (
            
            SELECT
                1 AS month_no,
                v_start_year AS payroll_year,
                4 AS payroll_month

            UNION ALL

            SELECT
                month_no + 1,
                CASE
                    WHEN payroll_month = 12
                        THEN payroll_year + 1
                    ELSE payroll_year
                END,
                CASE
                    WHEN payroll_month = 12
                        THEN 1
                    ELSE payroll_month + 1
                END
            FROM payroll_months
            WHERE month_no < 12
        ),

        cycle_dates AS (
            SELECT
                pm.month_no,
                pm.payroll_month,
                pm.payroll_year,
                STR_TO_DATE(
                    CONCAT(
                        pm.payroll_year, '-',
                        LPAD(pm.payroll_month, 2, '0'),
                        '-01'
                    ),
                    '%Y-%m-%d'
                ) AS month_first_day
            FROM payroll_months pm
        ),

        calculated_cycles AS (
            SELECT
                month_no,
                payroll_month,
                payroll_year,

                DATE_FORMAT(
                    month_first_day,
                    '%M %Y'
                ) AS cycle_name,

                
                CASE
                    WHEN v_cycle_start_day > v_cycle_end_day
                    THEN DATE_ADD(
                        DATE_SUB(
                            DATE_SUB(
                                month_first_day,
                                INTERVAL 1 DAY
                            ),
                            INTERVAL DAYOFMONTH(
                                DATE_SUB(
                                    month_first_day,
                                    INTERVAL 1 DAY
                                )
                            ) - 1 DAY
                        ),
                        INTERVAL LEAST(
                            v_cycle_start_day,
                            DAY(
                                LAST_DAY(
                                    DATE_SUB(
                                        month_first_day,
                                        INTERVAL 1 MONTH
                                    )
                                )
                            )
                        ) - 1 DAY
                    )
                    ELSE DATE_ADD(
                        month_first_day,
                        INTERVAL LEAST(
                            v_cycle_start_day,
                            DAY(LAST_DAY(month_first_day))
                        ) - 1 DAY
                    )
                END AS cycle_start_date,

                
                DATE_ADD(
                    month_first_day,
                    INTERVAL LEAST(
                        v_cycle_end_day,
                        DAY(LAST_DAY(month_first_day))
                    ) - 1 DAY
                ) AS cycle_end_date

            FROM cycle_dates
        ),

        monthly_summary AS (
            SELECT
                payroll_year,
                payroll_month,
                COUNT(summary_id) AS employee_count,

                SUM(
                    CASE
                        WHEN is_finalized = 'Y' THEN 1
                        ELSE 0
                    END
                ) AS finalized_employee_count

            FROM payroll_attendance_summary

            GROUP BY
                payroll_year,
                payroll_month
        )

        SELECT
            p_financial_year AS financial_year,
            cc.payroll_year,
            cc.payroll_month,
            cc.cycle_name,
            cc.cycle_start_date,
            cc.cycle_end_date,

            ms.employee_count,
            ms.finalized_employee_count,

            
            'Y' AS status,

            
            CASE
                WHEN ms.finalized_employee_count =
                     ms.employee_count
                THEN 'FINALIZED'
                ELSE 'INPROGRESS'
            END AS attendance_status,

            
            CASE
                WHEN ms.finalized_employee_count =
                     ms.employee_count
                THEN 'All employee payroll summaries are finalized'
                ELSE CONCAT(
                    ms.employee_count -
                    ms.finalized_employee_count,
                    ' employee(s) pending finalization'
                )
            END AS remarks,

            '+05:30' AS timezone

        FROM calculated_cycles cc

        INNER JOIN monthly_summary ms
            ON ms.payroll_month = cc.payroll_month
           AND ms.payroll_year = cc.payroll_year

        ORDER BY cc.month_no DESC;

    END IF;

END$$

-- ---------------------------------------------------------------------
-- C-123  UPDATE PROCEDURE sp_get_payroll_finalization_status
--        p_emp_id added as the first parameter with the standard role check
--        (a refusal uses this procedure's own columns: attendance_status, message).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_get_payroll_finalization_status$$
CREATE PROCEDURE `sp_get_payroll_finalization_status`(
    IN p_emp_id VARCHAR(20),
    IN p_month INT,
    IN p_year INT
)
fs: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;   -- C-123

    -- C-123: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS attendance_status, 'Access denied: only active ADMIN or HR users can view attendance status.' AS message;
        LEAVE fs;
    END IF;


    IF p_month IS NULL OR p_month NOT BETWEEN 1 AND 12
       OR p_year IS NULL THEN

        SELECT
            'N' AS attendance_status,
            'Invalid month or year' AS message;

    ELSE

        SELECT
            CASE
                WHEN COUNT(*) = 0 THEN 'N'
                WHEN SUM(is_finalized = 'N') > 0 THEN 'N'
                WHEN SUM(is_finalized = 'Y') = COUNT(*) THEN 'Y'
                ELSE 'N'
            END AS attendance_status,

            CASE
                WHEN COUNT(*) = 0
                    THEN 'Data not available'
                WHEN SUM(is_finalized = 'Y') = COUNT(*)
                    THEN 'Attendance finalized'
                ELSE 'Attendance not finalized'
            END AS message

        FROM payroll_attendance_summary
        WHERE payroll_month = p_month
          AND payroll_year = p_year;

    END IF;

END$$

-- ---------------------------------------------------------------------
-- C-124  NEW PROCEDURE hrms_component_rules_view
--        Components page: the rule checker (C-100) behind the standard role
--        check. p_output 1 = findings, 2 = who uses whom. The engine keeps
--        calling hrms_component_rules_check directly (internal).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_rules_view$$
CREATE PROCEDURE hrms_component_rules_view(IN p_emp_id VARCHAR(20), IN p_output TINYINT)
rv: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;

    -- C-124: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view the component rule check.' AS remarks;
        LEAVE rv;
    END IF;
    CALL hrms_component_rules_check(NULL, IF(p_output = 2, 2, 1));
END$$

-- ---------------------------------------------------------------------
-- C-126  NEW TABLE hrms_payroll_audit
--        One audit trail for the payroll module: who changed what, when,
--        with the values before and after (JSON). Cycle steps stay in
--        payroll_cycle_status_log (the cycle screen reads it); the audit
--        page (C-130) shows both together.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hrms_payroll_audit (
    audit_id         BIGINT        NOT NULL AUTO_INCREMENT,
    module           VARCHAR(20)   NOT NULL,
    action           VARCHAR(40)   NOT NULL,
    ref_table        VARCHAR(64)   NULL,
    ref_id           VARCHAR(64)   NULL,
    affected_emp_id  VARCHAR(20)   NULL,
    payroll_cycle_id BIGINT        NULL,
    payroll_month    TINYINT       NULL,
    payroll_year     SMALLINT      NULL,
    old_values       JSON          NULL,
    new_values       JSON          NULL,
    remarks          VARCHAR(1000) NULL,
    performed_by     VARCHAR(20)   NOT NULL,
    performed_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (audit_id),
    KEY idx_hpa_when   (performed_at),
    KEY idx_hpa_module (module, performed_at),
    KEY idx_hpa_emp    (affected_emp_id),
    KEY idx_hpa_by     (performed_by),
    KEY idx_hpa_month  (payroll_year, payroll_month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci$$

-- ---------------------------------------------------------------------
-- C-127  NEW PROCEDURE hrms_payroll_audit_add (internal)
--        Writes one audit row. Called only from inside the payroll
--        procedures, after their own role check, so it has none itself.
--        When old and new are both given and equal, the row is still kept
--        and the remarks start with "No values changed."
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_audit_add$$
CREATE PROCEDURE hrms_payroll_audit_add(
    IN p_module    VARCHAR(20),
    IN p_action    VARCHAR(40),
    IN p_ref_table VARCHAR(64),
    IN p_ref_id    VARCHAR(64),
    IN p_affected  VARCHAR(20),
    IN p_cycle_id  BIGINT,
    IN p_month     INT,
    IN p_year      INT,
    IN p_old       JSON,
    IN p_new       JSON,
    IN p_remarks   VARCHAR(1000),
    IN p_by        VARCHAR(20)
)
BEGIN
    DECLARE v_remarks VARCHAR(1000);
    SET v_remarks = NULLIF(TRIM(COALESCE(p_remarks, '')), '');
    IF p_old IS NOT NULL AND p_new IS NOT NULL AND JSON_CONTAINS(p_old, p_new) AND JSON_CONTAINS(p_new, p_old) THEN
        SET v_remarks = LEFT(CONCAT('No values changed.', IF(v_remarks IS NULL, '', CONCAT(' ', v_remarks))), 1000);
    END IF;
    INSERT INTO hrms_payroll_audit
        (module, action, ref_table, ref_id, affected_emp_id, payroll_cycle_id, payroll_month, payroll_year,
         old_values, new_values, remarks, performed_by)
    VALUES
        (UPPER(p_module), UPPER(p_action), p_ref_table, LEFT(p_ref_id, 64), NULLIF(TRIM(COALESCE(p_affected, '')), ''),
         p_cycle_id, p_month, p_year, p_old, p_new, v_remarks, COALESCE(NULLIF(TRIM(p_by), ''), 'UNKNOWN'));
END$$

-- ---------------------------------------------------------------------
-- C-128  NEW FUNCTIONS hrms_audit_component_json / hrms_audit_salary_json /
--        hrms_audit_attendance_json
--        Snapshots used as old_values / new_values in hrms_payroll_audit.
--        A missing row gives NULL (scalar subqueries, no NOT FOUND).
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS hrms_audit_component_json$$
CREATE FUNCTION hrms_audit_component_json(p_component_id BIGINT) RETURNS JSON
READS SQL DATA
BEGIN
    DECLARE v_slabs JSON DEFAULT NULL;
    SET v_slabs = (SELECT JSON_ARRAYAGG(s.j)
                     FROM (SELECT JSON_OBJECT('slab_id', slab_id, 'based_on', slab_based_on,
                                              'min', slab_min_value, 'max', slab_max_value,
                                              'result_type', result_type, 'result_value', result_value,
                                              'percentage_base', percentage_base, 'priority', priority,
                                              'effective_from', effective_from, 'effective_to', effective_to,
                                              'active', is_active) AS j
                             FROM salary_component_slab
                            WHERE component_id = p_component_id
                            ORDER BY priority, slab_id
                            LIMIT 1000) s);
    RETURN (SELECT JSON_OBJECT('component_id', component_id, 'code', component_code, 'name', component_name,
                               'type', component_type, 'calculation_type', calculation_type,
                               'percentage_base', percentage_base, 'percentage_value', percentage_value,
                               'formula', formula_expression, 'minimum', minimum_amount, 'maximum', maximum_amount,
                               'scope', calculation_scope, 'order', calculation_order,
                               'eligibility', eligibility_parameter, 'eligibility_value', eligibility_required_value,
                               'manual', is_manual, 'slab', is_slab, 'rounding', rounding_precision,
                               'taxable', is_taxable, 'active', is_active,
                               'slabs', COALESCE(v_slabs, JSON_ARRAY()))
              FROM salary_component_master
             WHERE component_id = p_component_id
             LIMIT 1);
END$$

DROP FUNCTION IF EXISTS hrms_audit_salary_json$$
CREATE FUNCTION hrms_audit_salary_json(p_structure_id BIGINT) RETURNS JSON
READS SQL DATA
BEGIN
    DECLARE v_own     JSON DEFAULT NULL;
    DECLARE v_amounts JSON DEFAULT NULL;
    SET v_own = (SELECT JSON_ARRAYAGG(o.j)
                   FROM (SELECT JSON_OBJECT('code', UPPER(m.component_code), 'calculation_type', e.calculation_type,
                                            'value', e.component_value, 'percentage_base', e.percentage_base,
                                            'formula', e.formula_expression) AS j
                           FROM employee_salary_structure e
                           JOIN salary_component_master m ON m.component_id = e.component_id
                          WHERE e.structure_id = p_structure_id AND e.is_overridden = 1
                          ORDER BY m.calculation_order, m.component_id
                          LIMIT 1000) o);
    SET v_amounts = (SELECT JSON_OBJECTAGG(UPPER(m.component_code), e.monthly_amount)
                       FROM employee_salary_structure e
                       JOIN salary_component_master m ON m.component_id = e.component_id
                      WHERE e.structure_id = p_structure_id);
    RETURN (SELECT JSON_OBJECT('structure_id', structure_id, 'emp_id', emp_id,
                               'monthly_ctc', monthly_ctc, 'annual_ctc', annual_ctc,
                               'effective_from', effective_from, 'effective_to', effective_to,
                               'status', structure_status, 'esi_applicable', esi_applicable,
                               'own_settings', COALESCE(v_own, JSON_ARRAY()),
                               'amounts', COALESCE(v_amounts, JSON_OBJECT()))
              FROM salary_structure
             WHERE structure_id = p_structure_id
             LIMIT 1);
END$$

DROP FUNCTION IF EXISTS hrms_audit_attendance_json$$
CREATE FUNCTION hrms_audit_attendance_json(p_month INT, p_year INT) RETURNS JSON
READS SQL DATA
BEGIN
    RETURN (SELECT JSON_OBJECT('employees', COUNT(*),
                               'finalized', COALESCE(SUM(is_finalized = 'Y'), 0),
                               'present_days', COALESCE(SUM(present_days), 0),
                               'wfh_days', COALESCE(SUM(wfh_days), 0),
                               'leave_days', COALESCE(SUM(leave_days), 0),
                               'absent_days', COALESCE(SUM(absent_days), 0),
                               'paid_days', COALESCE(SUM(paid_days), 0),
                               'unpaid_days', COALESCE(SUM(unpaid_days), 0))
              FROM payroll_attendance_summary
             WHERE payroll_month = p_month AND payroll_year = p_year);
END$$

-- ---------------------------------------------------------------------
-- C-129  NEW PROCEDURE hrms_payroll_audit_event
--        Events the application records itself:
--          PAYSLIP_DOWNLOAD  any active user; an EMP only for their own payslip
--          ACCESS_DENIED     a payroll procedure answered "Access denied"
--                            (written by the models, see SalaryModel)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_audit_event$$
CREATE PROCEDURE hrms_payroll_audit_event(
    IN p_emp_id   VARCHAR(20),
    IN p_action   VARCHAR(40),
    IN p_ref_id   VARCHAR(64),
    IN p_affected VARCHAR(20),
    IN p_month    INT,
    IN p_year     INT,
    IN p_remarks  VARCHAR(1000)
)
ev: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;
    DECLARE v_action        VARCHAR(40);
    DECLARE v_cycle         BIGINT DEFAULT NULL;

    SET v_action = UPPER(TRIM(COALESCE(p_action, '')));

    IF v_action = 'ACCESS_DENIED' THEN
        CALL hrms_payroll_audit_add('SECURITY', 'ACCESS_DENIED', 'procedure', p_ref_id, NULL, NULL, NULL, NULL,
                                    NULL, NULL, p_remarks, COALESCE(NULLIF(TRIM(p_emp_id), ''), 'UNKNOWN'));
        SELECT 'Y' AS status, 'Recorded.' AS remarks;
        LEAVE ev;
    END IF;

    -- C-129: who is calling - any active user (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR', 'EMP') THEN
        SELECT 'N' AS status, 'Access denied: only active users can record payroll events.' AS remarks;
        LEAVE ev;
    END IF;

    IF v_action <> 'PAYSLIP_DOWNLOAD' THEN
        SELECT 'N' AS status, 'Unknown payroll event.' AS remarks;
        LEAVE ev;
    END IF;
    IF v_user_category = 'EMP' AND TRIM(COALESCE(p_affected, '')) <> TRIM(p_emp_id) THEN
        SELECT 'N' AS status, 'Access denied: employees can only download their own payslips.' AS remarks;
        LEAVE ev;
    END IF;

    SELECT MAX(payroll_cycle_id) INTO v_cycle FROM payroll_cycles
     WHERE payroll_month = p_month AND payroll_year = p_year;
    CALL hrms_payroll_audit_add('PAYSLIP', 'PAYSLIP_DOWNLOAD', 'employee_payslips', p_ref_id, p_affected, v_cycle,
                                p_month, p_year, NULL, NULL, p_remarks, p_emp_id);
    SELECT 'Y' AS status, 'Recorded.' AS remarks;
END$$

-- ---------------------------------------------------------------------
-- C-130  NEW PROCEDURE hrms_payroll_audit_list
--        Payroll Audit Log page. Active ADMIN or HR only. Returns the
--        audit trail (C-126) and the cycle log (payroll_cycle_status_log)
--        together, newest first, with filters:
--          p_module   '' = all; COMPONENT, SLAB, SALARY, MANUAL_INPUT,
--                     ATTENDANCE, PAYSLIP, SECURITY or CYCLE
--          p_emp      employee affected OR the person who did it
--          p_from/p_to performed between these dates
--          p_search   text in action, reference, remarks, names or the
--                     before / after values
--          p_limit    rows per page (1-500, default 100), p_offset
--        Every row carries total_rows (all matches) for paging.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_audit_list$$
CREATE PROCEDURE hrms_payroll_audit_list(
    IN p_emp_id VARCHAR(20),
    IN p_module VARCHAR(20),
    IN p_emp    VARCHAR(20),
    IN p_from   DATE,
    IN p_to     DATE,
    IN p_search VARCHAR(100),
    IN p_limit  INT,
    IN p_offset INT
)
al: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;
    DECLARE v_module        VARCHAR(20);
    DECLARE v_emp           VARCHAR(20);
    DECLARE v_search        VARCHAR(102);
    DECLARE v_limit         INT;
    DECLARE v_offset        INT;

    -- C-130: who is calling - active ADMIN or HR only (user_login_details)
    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view the payroll audit log.' AS remarks;
        LEAVE al;
    END IF;

    SET v_module = NULLIF(UPPER(TRIM(COALESCE(p_module, ''))), '');
    SET v_emp    = NULLIF(UPPER(TRIM(COALESCE(p_emp, ''))), '');
    SET v_search = IF(NULLIF(TRIM(COALESCE(p_search, '')), '') IS NULL, NULL, CONCAT('%', TRIM(p_search), '%'));
    SET v_limit  = LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
    SET v_offset = GREATEST(COALESCE(p_offset, 0), 0);

    SELECT 'Y' AS status, '' AS remarks,
           x.source, x.id, x.module, x.action, x.ref_table, x.ref_id,
           x.affected_emp_id, na.emp_name AS affected_name,
           x.payroll_cycle_id, x.payroll_month, x.payroll_year,
           x.old_values, x.new_values, x.details,
           x.performed_by, COALESCE(nb.emp_name, x.performed_by) AS performed_by_name, x.performed_at,
           COUNT(*) OVER () AS total_rows
      FROM (SELECT 'AUDIT' AS source, a.audit_id AS id, a.module, a.action, a.ref_table, a.ref_id,
                   a.affected_emp_id, a.payroll_cycle_id, a.payroll_month, a.payroll_year,
                   a.old_values, a.new_values, a.remarks AS details, a.performed_by, a.performed_at
              FROM hrms_payroll_audit a
            UNION ALL
            SELECT 'CYCLE', l.log_id, 'CYCLE', l.action, 'payroll_cycles', l.cycle_code,
                   l.emp_id, l.payroll_cycle_id, pc.payroll_month, pc.payroll_year,
                   IF(l.from_status IS NULL, NULL, JSON_OBJECT('status', l.from_status)),
                   IF(l.to_status IS NULL, NULL, JSON_OBJECT('status', l.to_status)),
                   l.remarks, l.performed_by, l.performed_at
              FROM payroll_cycle_status_log l
              LEFT JOIN payroll_cycles pc ON pc.payroll_cycle_id = l.payroll_cycle_id) x
      LEFT JOIN (SELECT emp_id, MAX(emp_name) AS emp_name FROM user_details GROUP BY emp_id) na ON na.emp_id = x.affected_emp_id
      LEFT JOIN (SELECT emp_id, MAX(emp_name) AS emp_name FROM user_details GROUP BY emp_id) nb ON nb.emp_id = x.performed_by
     WHERE (v_module IS NULL OR x.module = v_module)
       AND (v_emp IS NULL OR UPPER(x.affected_emp_id) = v_emp OR UPPER(x.performed_by) = v_emp)
       AND (p_from IS NULL OR x.performed_at >= p_from)
       AND (p_to IS NULL OR x.performed_at < DATE_ADD(p_to, INTERVAL 1 DAY))
       AND (v_search IS NULL OR x.action LIKE v_search OR x.ref_id LIKE v_search OR x.details LIKE v_search
            OR na.emp_name LIKE v_search OR nb.emp_name LIKE v_search
            OR CAST(x.old_values AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_general_ci LIKE v_search
            OR CAST(x.new_values AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_general_ci LIKE v_search)
     ORDER BY x.performed_at DESC, x.id DESC
     LIMIT v_limit OFFSET v_offset;
END$$

-- ---------------------------------------------------------------------
-- C-000  HELPER : remove the temporary script procedures
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_script_add_column$$
DROP PROCEDURE IF EXISTS hrms_script_modify_column$$
DROP PROCEDURE IF EXISTS hrms_script_add_index$$

DELIMITER ;

-- End of script.sql
