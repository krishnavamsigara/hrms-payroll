-- =====================================================================
-- attendance_finalize.sql : finalize and unfinalize the payroll attendance
--                           of a month with ONE procedure
--                           (page admin/attendance_finalize?month=&year=)
--
-- Database : production_hrms_db (MySQL 8) and hrmstest (MariaDB 10.11)
-- Run with : mysql --default-character-set=utf8mb4 -u <user> -p <database> < attendance_finalize.sql
-- Re-run   : safe. The procedure is dropped and created again. No data is
--            changed.
-- Same code: script.sql C-118 holds the same procedure (C-136), so running
--            script.sql again keeps this version.
--
-- IMPORTANT: the procedure now has 4 parameters. Deploy it together with
--            the application code (AdminModel::get_finalized passes the
--            action); the old 3-parameter call fails against it.
--
-- C-136  UPDATE PROCEDURE finalize_payroll_attendance_proc
--   finalize_payroll_attendance_proc(p_emp_id, p_month, p_year, p_action)
--     p_action  FINALIZE    (or NULL / empty): every summary row of the
--                           month gets is_finalized = 'Y'. Unchanged rules.
--               UNFINALIZE  every summary row of the month gets
--                           is_finalized = 'N', so attendance can be
--                           corrected or generated again.
--   UNFINALIZE and the payroll cycle of the same month:
--     no cycle, OPEN          allowed
--     ATTENDANCE_VERIFIED,    allowed; nothing is calculated yet, so the
--     STRUCTURE_VERIFIED      cycle is moved back to OPEN in the same step
--                             (cycle log: ATTENDANCE_UNFINALIZED) and
--                             attendance is verified again later
--     PROCESSING, CALCULATED, refused: salaries are already calculated from
--     APPROVED                this attendance. Go back on the payroll cycle
--                             page first (that resets the calculation)
--     FINALIZED, PARTIALLY_   refused: the payroll was paid with this
--     PAID, PAID, CLOSED      attendance; correct it in a later month
--   It is also refused when the attendance of the month is not finalized.
--   Both actions are written to the payroll audit trail (ATTENDANCE /
--   FINALIZE or UNFINALIZE) with the totals before and after.
--   Who may call: active ADMIN or HR (user_login_details).
--   Returns: status (Y/N), remarks.
-- =====================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS finalize_payroll_attendance_proc$$
CREATE PROCEDURE `finalize_payroll_attendance_proc`(
    IN p_emp_id VARCHAR(20),
    IN p_month  INT,
    IN p_year   INT,
    IN p_action VARCHAR(20)
)
main_block: BEGIN

    DECLARE v_user_category VARCHAR(20);
    DECLARE v_action        VARCHAR(20);
    DECLARE v_audit_old     JSON DEFAULT NULL;
    DECLARE v_audit_new     JSON DEFAULT NULL;
    DECLARE v_audit_cycle   BIGINT DEFAULT NULL;
    DECLARE v_cycle_code    VARCHAR(50) DEFAULT NULL;
    DECLARE v_cycle_status  VARCHAR(30) DEFAULT NULL;

    DECLARE v_total_records     INT DEFAULT 0;
    DECLARE v_finalized_records INT DEFAULT 0;
    DECLARE v_duplicate_groups  INT DEFAULT 0;
    DECLARE v_changed           INT DEFAULT 0;
    DECLARE v_cycle_reset       TINYINT DEFAULT 0;   -- 1 = the cycle went back to OPEN

    DECLARE v_error_no      INT DEFAULT 0;
    DECLARE v_error_message TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_no = MYSQL_ERRNO,
            v_error_message = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status,
               CONCAT('Database error [', COALESCE(v_error_no, 0), ']: ',
                      COALESCE(v_error_message, 'Unknown error')) AS remarks;
    END;

    SET time_zone = '+05:30';
    SET v_action = UPPER(TRIM(COALESCE(NULLIF(TRIM(p_action), ''), 'FINALIZE')));

    -- ---- input --------------------------------------------------------
    IF p_emp_id IS NULL OR TRIM(p_emp_id) = '' THEN
        SELECT 'N' AS status, 'Requester employee ID is required.' AS remarks;
        LEAVE main_block;
    END IF;

    IF p_month IS NULL OR p_month NOT BETWEEN 1 AND 12
       OR p_year IS NULL OR p_year NOT BETWEEN 1900 AND 9999 THEN
        SELECT 'N' AS status, 'Invalid month or year.' AS remarks;
        LEAVE main_block;
    END IF;

    IF v_action NOT IN ('FINALIZE', 'UNFINALIZE') THEN
        SELECT 'N' AS status, CONCAT('Unknown action "', v_action, '". Use FINALIZE or UNFINALIZE.') AS remarks;
        LEAVE main_block;
    END IF;

    -- ---- who is calling: active ADMIN or HR -----------------------------
    SELECT MAX(UPPER(TRIM(user_category)))
      INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id)
       AND LOWER(TRIM(status)) = 'active';

    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status,
               IF(v_action = 'UNFINALIZE',
                  'Access denied: only active ADMIN or HR users can unfinalize attendance.',
                  'Access denied: only active ADMIN or HR users can finalize attendance.') AS remarks;
        LEAVE main_block;
    END IF;

    -- ---- the attendance of the month ------------------------------------
    SELECT COUNT(*), COALESCE(SUM(is_finalized = 'Y'), 0)
      INTO v_total_records, v_finalized_records
      FROM payroll_attendance_summary
     WHERE payroll_month = p_month
       AND payroll_year  = p_year;

    IF v_total_records = 0 THEN
        SELECT 'N' AS status,
               'Attendance not generated. No payroll attendance summaries exist for this month and year.' AS remarks;
        LEAVE main_block;
    END IF;

    -- the payroll cycle of the month (newest), if any
    SELECT payroll_cycle_id, cycle_code, cycle_status
      INTO v_audit_cycle, v_cycle_code, v_cycle_status
      FROM payroll_cycles
     WHERE payroll_month = p_month
       AND payroll_year  = p_year
     ORDER BY payroll_cycle_id DESC
     LIMIT 1;

    IF v_action = 'FINALIZE' THEN

        SELECT COUNT(*)
          INTO v_duplicate_groups
          FROM (SELECT emp_id
                  FROM payroll_attendance_summary
                 WHERE payroll_month = p_month
                   AND payroll_year  = p_year
                 GROUP BY emp_id
                HAVING COUNT(*) > 1) AS duplicate_employees;

        IF v_duplicate_groups > 0 THEN
            SELECT 'N' AS status,
                   CONCAT('Finalization blocked. ', v_duplicate_groups,
                          ' employee(s) have duplicate attendance summaries. ',
                          'Resolve the duplicates before finalizing.') AS remarks;
            LEAVE main_block;
        END IF;

        IF v_finalized_records = v_total_records THEN
            SELECT 'N' AS status, 'Attendance is already finalized for the selected month and year.' AS remarks;
            LEAVE main_block;
        END IF;

    ELSE   -- UNFINALIZE

        IF v_finalized_records = 0 THEN
            SELECT 'N' AS status, 'Attendance is not finalized for the selected month and year.' AS remarks;
            LEAVE main_block;
        END IF;

        IF v_cycle_status IN ('FINALIZED', 'PARTIALLY_PAID', 'PAID', 'CLOSED') THEN
            SELECT 'N' AS status,
                   CONCAT('Attendance cannot be unfinalized: payroll ', v_cycle_code, ' is ', v_cycle_status,
                          ' and was paid with this attendance.') AS remarks;
            LEAVE main_block;
        END IF;

        IF v_cycle_status IS NOT NULL
           AND v_cycle_status NOT IN ('OPEN', 'ATTENDANCE_VERIFIED', 'STRUCTURE_VERIFIED') THEN
            SELECT 'N' AS status,
                   CONCAT('Attendance cannot be unfinalized: payroll ', v_cycle_code, ' is ', v_cycle_status,
                          ' and salaries are already calculated from it. Go back on the payroll cycle page ',
                          '(to Structures verified or earlier) or delete the cycle, then unfinalize.') AS remarks;
            LEAVE main_block;
        END IF;

    END IF;

    -- ---- change ---------------------------------------------------------
    SET v_audit_old = hrms_audit_attendance_json(p_month, p_year);
    START TRANSACTION;

    IF v_action = 'FINALIZE' THEN
        UPDATE payroll_attendance_summary
           SET is_finalized = 'Y', updated_at = NOW()
         WHERE payroll_month = p_month
           AND payroll_year  = p_year
           AND (is_finalized IS NULL OR is_finalized <> 'Y');
    ELSE
        UPDATE payroll_attendance_summary
           SET is_finalized = 'N', updated_at = NOW()
         WHERE payroll_month = p_month
           AND payroll_year  = p_year
           AND is_finalized = 'Y';
    END IF;
    SET v_changed = ROW_COUNT();

    -- the cycle had verified this attendance but calculated nothing yet: back to OPEN
    IF v_action = 'UNFINALIZE' AND v_cycle_status IN ('ATTENDANCE_VERIFIED', 'STRUCTURE_VERIFIED') THEN
        UPDATE payroll_cycles SET cycle_status = 'OPEN' WHERE payroll_cycle_id = v_audit_cycle;
        CALL hrms_payroll_log(v_audit_cycle, NULL, NULL, 'ATTENDANCE_UNFINALIZED', v_cycle_status, 'OPEN',
             CONCAT('Attendance of ', LPAD(p_month, 2, '0'), '/', p_year,
                    ' was unfinalized, so the cycle went back to OPEN. Verify attendance again after finalizing.'),
             p_emp_id);
        SET v_cycle_reset = 1;
    END IF;

    -- audit trail
    SET v_audit_new = hrms_audit_attendance_json(p_month, p_year);
    CALL hrms_payroll_audit_add('ATTENDANCE', v_action, 'payroll_attendance_summary',
         CONCAT(p_year, '-', LPAD(p_month, 2, '0')), NULL, v_audit_cycle, p_month, p_year, v_audit_old, v_audit_new,
         CONCAT('Attendance ', IF(v_action = 'FINALIZE', 'finalized', 'unfinalized'), ' for ',
                LPAD(p_month, 2, '0'), '/', p_year, ' (', v_changed, ' of ', v_total_records, ' employees).',
                IF(v_cycle_reset = 1, CONCAT(' Payroll ', v_cycle_code, ' moved back from ', v_cycle_status, ' to OPEN.'), '')),
         p_emp_id);
    COMMIT;

    SELECT 'Y' AS status,
           IF(v_action = 'FINALIZE',
              CONCAT('Payroll attendance finalized successfully for ', LPAD(p_month, 2, '0'), '/', p_year,
                     '. Total summary records: ', v_total_records, '.'),
              CONCAT('Payroll attendance unfinalized for ', LPAD(p_month, 2, '0'), '/', p_year,
                     '. ', v_changed, ' summary record(s) can be corrected or generated again; finalize again when done.',
                     IF(v_cycle_reset = 1,
                        CONCAT(' Payroll ', v_cycle_code, ' moved back from ', v_cycle_status,
                               ' to OPEN: verify attendance again there.'), ''))
           ) AS remarks;

END$$

DELIMITER ;
