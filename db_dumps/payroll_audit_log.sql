-- =====================================================================
-- payroll_audit_log.sql : payroll audit trail (Payroll Audit Log page)
--   The audit table and its procedures, on their own, for a server that
--   does not have them yet (for example the remote server hrmstest).
--
-- Database : hrmstest (MariaDB 10.11) and production_hrms_db (MySQL 8)
-- Run with : mysql --default-character-set=utf8mb4 -u hrmstest -p hrmstest < payroll_audit_log.sql
-- Re-run   : safe. The table is created only when missing (existing audit
--            rows are kept); the functions and procedures are recreated.
-- Source   : the same text as script.sql C-126 .. C-130. If the current
--            script.sql has already run on the server, all of this is
--            already there and this file changes nothing.
--
-- WHAT IS IN IT
--   C-048  TABLE      payroll_cycle_status_log      cycle history (only when missing)
--   C-126  TABLE      hrms_payroll_audit            one row per change / event
--   C-127  PROCEDURE  hrms_payroll_audit_add        writes a row (internal)
--   C-128  FUNCTIONS  hrms_audit_component_json, hrms_audit_salary_json,
--                     hrms_audit_attendance_json    before / after snapshots
--   C-129  PROCEDURE  hrms_payroll_audit_event      payslip download, access denied
--   C-130  PROCEDURE  hrms_payroll_audit_list       the Payroll Audit Log page
--
-- WHAT WRITES TO IT (not in this file)
--   The component, slab, salary, manual-amount and attendance procedures
--   of script.sql (C-131 .. C-134), attendance_finalize.sql and the
--   component_phase files call hrms_payroll_audit_add. Install this file
--   before them if the server has no audit table yet.
--   hrms_audit_component_json / hrms_audit_salary_json use JSON_ARRAYAGG:
--   MySQL 8 or MariaDB 10.5+.
--
-- APPLICATION (already in the code)
--   payroll/audit_log -> SalaryController::audit_log (page)
--   payroll/audit_payslip_download -> SalaryController::audit_payslip_download
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- C-048  TABLE payroll_cycle_status_log (only when missing)
--        The history of every payroll cycle step. Created by script.sql;
--        here too because the audit page (C-130) lists it next to the
--        audit rows. Same definition as script.sql C-048, including the
--        cycle_code column.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `payroll_cycle_status_log` (
    `log_id`            BIGINT NOT NULL AUTO_INCREMENT,
    `payroll_cycle_id`  BIGINT NOT NULL,
    `cycle_code`        VARCHAR(50) NULL,
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
) ENGINE=InnoDB$$

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
    SET v_slabs = (SELECT JSON_ARRAYAGG(JSON_EXTRACT(s.j, '$'))
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
                               'slabs', JSON_EXTRACT(COALESCE(v_slabs, '[]'), '$'))
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
    SET v_own = (SELECT JSON_ARRAYAGG(JSON_EXTRACT(o.j, '$'))
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
                               'own_settings', JSON_EXTRACT(COALESCE(v_own, '[]'), '$'),
                               'amounts', JSON_EXTRACT(COALESCE(v_amounts, '{}'), '$'))
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

DELIMITER ;
