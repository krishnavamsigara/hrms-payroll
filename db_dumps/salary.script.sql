-- =====================================================================
-- salary.script.sql : salary periods of one employee
--                     (page payroll/salary_structure/edit/{emp_id})
--
-- Database : production_hrms_db (MySQL 8) and hrmstest (MariaDB 10.11)
-- Run with : mysql --default-character-set=utf8mb4 -u <user> -p <database> < salary.script.sql
-- Run after: script.sql (uses salary_structure, payroll_cycles and the
--            procedure hrms_save_employee_salary, C-080)
-- Re-run   : safe. Each procedure is dropped and created again. No table
--            and no data is changed.
--
-- CHANGE INDEX
--   ID     TYPE            OBJECT
--   S-001  NEW PROCEDURE   hrms_salary_timeline
--                          The salary periods of an employee, oldest first,
--                          with the gaps between them and a lock flag for
--                          periods already used by a finalized payroll.
--   S-002  NEW PROCEDURE   hrms_revise_employee_ctc
--                          "Revise CTC": a new monthly CTC from a new date.
--                          The current salary period ends the day before and
--                          a new period starts (salary history is kept).
--
-- WHAT "LOCKED" MEANS
--   A salary period is locked when a payroll cycle whose pay period overlaps
--   it is FINALIZED, PARTIALLY_PAID, PAID or CLOSED. That payroll keeps its
--   own copy of the amounts, so the monthly CTC of a locked period is not
--   edited in place any more: the CTC is revised from a new date (S-002).
--   The edit page enforces this (SalaryController::save_employee_salary).
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- S-001  NEW PROCEDURE hrms_salary_timeline
--        One employee: every ACTIVE salary period and every gap, oldest
--        first.
--          row_type = PERIOD : structure_id, date_from, date_to (NULL =
--                              onwards), monthly_ctc, is_current,
--                              locked (1/0), locked_cycles ("June 2026,
--                              July 2026"), locked_until (last day of the
--                              last finalized pay period it covers)
--          row_type = GAP    : date_from, date_to with no salary.
--                              date_to NULL = the last salary has ended and
--                              nothing follows it (only reported for an
--                              employee whose login is still active).
--        A gap before the first salary is not reported.
--        Who may call: active ADMIN or HR (user_login_details).
--        Returns: status, remarks, row_type, structure_id, date_from,
--                 date_to, monthly_ctc, is_current, locked, locked_cycles,
--                 locked_until. No salary at all = no rows.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_salary_timeline$$
CREATE PROCEDURE hrms_salary_timeline(IN p_emp_id VARCHAR(20), IN p_target_emp_id VARCHAR(20))
tl: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;
    DECLARE v_active        INT DEFAULT 0;

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can view salaries.' AS remarks, NULL AS row_type;
        LEAVE tl;
    END IF;

    SET SESSION group_concat_max_len = 100000;

    SELECT COUNT(*) INTO v_active
      FROM user_login_details
     WHERE emp_id = p_target_emp_id AND LOWER(TRIM(status)) = 'active';

    SELECT 'Y' AS status, '' AS remarks,
           t.row_type, t.structure_id, t.date_from, t.date_to, t.monthly_ctc,
           t.is_current, t.locked, t.locked_cycles, t.locked_until
      FROM (
            -- the salary periods
            SELECT 'PERIOD' AS row_type,
                   ss.structure_id,
                   ss.effective_from AS date_from,
                   ss.effective_to   AS date_to,
                   ss.monthly_ctc,
                   IF(ss.effective_from <= CURDATE()
                      AND (ss.effective_to IS NULL OR ss.effective_to >= CURDATE()), 1, 0) AS is_current,
                   IF(EXISTS (SELECT 1 FROM payroll_cycles c
                               WHERE c.period_start <= COALESCE(ss.effective_to, '9999-12-31')
                                 AND c.period_end >= ss.effective_from
                                 AND c.cycle_status IN ('FINALIZED', 'PARTIALLY_PAID', 'PAID', 'CLOSED')), 1, 0) AS locked,
                   (SELECT GROUP_CONCAT(CONCAT(ELT(c.payroll_month, 'January','February','March','April','May','June','July',
                                                   'August','September','October','November','December'), ' ', c.payroll_year)
                                        ORDER BY c.payroll_year, c.payroll_month SEPARATOR ', ')
                      FROM payroll_cycles c
                     WHERE c.period_start <= COALESCE(ss.effective_to, '9999-12-31')
                       AND c.period_end >= ss.effective_from
                       AND c.cycle_status IN ('FINALIZED', 'PARTIALLY_PAID', 'PAID', 'CLOSED')) AS locked_cycles,
                   (SELECT MAX(c.period_end)
                      FROM payroll_cycles c
                     WHERE c.period_start <= COALESCE(ss.effective_to, '9999-12-31')
                       AND c.period_end >= ss.effective_from
                       AND c.cycle_status IN ('FINALIZED', 'PARTIALLY_PAID', 'PAID', 'CLOSED')) AS locked_until
              FROM salary_structure ss
             WHERE ss.emp_id = p_target_emp_id AND ss.structure_status = 'ACTIVE'

            UNION ALL

            -- the gaps: a period that ends, and the next one does not start the day after
            SELECT 'GAP' AS row_type,
                   NULL AS structure_id,
                   DATE_ADD(g.effective_to, INTERVAL 1 DAY) AS date_from,
                   DATE_SUB(g.next_from, INTERVAL 1 DAY)    AS date_to,
                   NULL AS monthly_ctc,
                   IF(DATE_ADD(g.effective_to, INTERVAL 1 DAY) <= CURDATE()
                      AND (g.next_from IS NULL OR g.next_from > CURDATE()), 1, 0) AS is_current,
                   0 AS locked,
                   NULL AS locked_cycles,
                   NULL AS locked_until
              FROM (SELECT p.effective_to,
                           (SELECT MIN(n.effective_from)
                              FROM salary_structure n
                             WHERE n.emp_id = p.emp_id AND n.structure_status = 'ACTIVE'
                               AND n.effective_from > p.effective_from) AS next_from
                      FROM salary_structure p
                     WHERE p.emp_id = p_target_emp_id AND p.structure_status = 'ACTIVE'
                       AND p.effective_to IS NOT NULL) g
             WHERE (g.next_from IS NULL AND v_active > 0)
                OR g.next_from > DATE_ADD(g.effective_to, INTERVAL 1 DAY)
           ) t
     ORDER BY t.date_from, t.structure_id;
END$$

-- ---------------------------------------------------------------------
-- S-002  NEW PROCEDURE hrms_revise_employee_ctc
--        Revise the monthly CTC of an employee from a new date.
--          p_structure_id   the salary period being revised
--          p_monthly_ctc    the new monthly CTC
--          p_effective_from the first day of the new CTC: after the first
--                           day of the period and not after its last day
--        The period ends the day before p_effective_from and a new period
--        starts on it with the new CTC, the same components and the same
--        employee settings, calculated by the salary engine. This is done
--        by hrms_save_employee_salary (C-080), so the rules, the audit row
--        (SALARY / NEW_PERIOD) and the answer are the same.
--        Refused when the date is the first day of the period (that would
--        change the period itself, not revise it) or outside the period.
--        Payrolls already finalized keep their own copy and do not change.
--        Who may call: active ADMIN or HR (user_login_details).
--        Returns: status, remarks, structure_id (the new period),
--                 new_period (1).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_revise_employee_ctc$$
CREATE PROCEDURE hrms_revise_employee_ctc(
    IN p_emp_id         VARCHAR(20),
    IN p_target_emp_id  VARCHAR(20),
    IN p_structure_id   BIGINT,
    IN p_monthly_ctc    DECIMAL(12,2),
    IN p_effective_from DATE
)
rv: BEGIN
    DECLARE v_user_category VARCHAR(20) DEFAULT NULL;
    DECLARE v_from DATE;
    DECLARE v_to   DATE;
    DECLARE v_ctc  DECIMAL(12,2);
    DECLARE v_msg  VARCHAR(500) DEFAULT NULL;

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';

    SELECT MAX(effective_from), MAX(effective_to), MAX(monthly_ctc) INTO v_from, v_to, v_ctc
      FROM salary_structure
     WHERE structure_id = p_structure_id AND emp_id = p_target_emp_id AND structure_status = 'ACTIVE';

    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SET v_msg = 'Access denied: only active ADMIN or HR users can change salaries.';
    ELSEIF v_from IS NULL THEN
        SET v_msg = 'Salary period not found for this employee.';
    ELSEIF p_monthly_ctc IS NULL OR p_monthly_ctc <= 0 THEN
        SET v_msg = 'The new monthly CTC must be more than 0.';
    ELSEIF p_effective_from IS NULL THEN
        SET v_msg = 'Choose the date the new CTC applies from.';
    ELSEIF p_effective_from <= v_from THEN
        SET v_msg = CONCAT('The new CTC must start after ', DATE_FORMAT(v_from, '%d %b %Y'),
                           ', the first day of this salary period.');
    ELSEIF v_to IS NOT NULL AND p_effective_from > v_to THEN
        SET v_msg = CONCAT('This salary period ends on ', DATE_FORMAT(v_to, '%d %b %Y'),
                           '. To revise a later date, open the salary period that covers it.');
    ELSEIF p_monthly_ctc = v_ctc THEN
        SET v_msg = CONCAT('The monthly CTC is already ', v_ctc, '. Enter the new CTC.');
    END IF;

    IF v_msg IS NOT NULL THEN
        SELECT 'N' AS status, v_msg AS remarks, p_structure_id AS structure_id, 0 AS new_period;
        LEAVE rv;
    END IF;

    -- a later date than the start of the period = C-080 creates the new period
    CALL hrms_save_employee_salary(p_emp_id, p_target_emp_id, p_structure_id, p_monthly_ctc, p_effective_from, NULL);
END$$

DELIMITER ;
