-- =====================================================================
-- cleanup_payroll_cycles_keep_one_month.sql
--   TEST DATA CLEANUP: deletes every payroll cycle except the cycle of
--   ONE month (set below: June 2026), so payroll can be tested again
--   from a clean start.
--
-- Database : production_hrms_db (MySQL 8) / hrmstest (MariaDB 10.11)
-- Run with : mysql --default-character-set=utf8mb4 -u <user> -p <database> < cleanup_payroll_cycles_keep_one_month.sql
-- BACK UP FIRST. This cannot be undone except from a backup:
--   mysqldump -u <user> -p <database> payroll_cycles payroll_runs employee_payroll_details
--       employee_payroll_component_details employee_payslips payroll_cycle_status_log
--       payroll_payments payroll_manual_inputs > backup_payroll_cycles.sql
--
-- DELETED (for every cycle that is not the month kept)
--   payroll_cycles, payroll_runs, employee_payroll_details,
--   employee_payroll_component_details, employee_payslips, payroll_payments,
--   payroll_cycle_status_log (also the history of cycles deleted earlier,
--   stored with a negative cycle id), payroll_manual_inputs of other months
--
-- NOT TOUCHED
--   the cycle of the month kept and everything under it
--   attendance (payroll_attendance_summary, attendance)
--   salary structures, components, slabs
--   hrms_payroll_audit (the audit trail is kept)
--
-- Safe : one transaction; if the month to keep has no cycle, nothing is
--        deleted. Re-run deletes nothing more.
-- =====================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS hrms_cleanup_keep_one_cycle$$
CREATE PROCEDURE hrms_cleanup_keep_one_cycle(IN p_keep_month INT, IN p_keep_year INT)
ck: BEGIN
    DECLARE v_keep       BIGINT DEFAULT NULL;
    DECLARE v_cycles     INT DEFAULT 0;
    DECLARE v_runs       INT DEFAULT 0;
    DECLARE v_details    INT DEFAULT 0;
    DECLARE v_components INT DEFAULT 0;
    DECLARE v_payslips   INT DEFAULT 0;
    DECLARE v_payments   INT DEFAULT 0;
    DECLARE v_logs       INT DEFAULT 0;
    DECLARE v_inputs     INT DEFAULT 0;
    DECLARE v_err        VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, CONCAT('Nothing deleted: ', COALESCE(v_err, 'error')) AS remarks;
    END;

    SELECT MAX(payroll_cycle_id) INTO v_keep
      FROM payroll_cycles
     WHERE payroll_month = p_keep_month AND payroll_year = p_keep_year;

    IF v_keep IS NULL THEN
        SELECT 'N' AS status,
               CONCAT('Nothing deleted: there is no payroll cycle for month ', p_keep_month, ' of ', p_keep_year, '.') AS remarks;
        LEAVE ck;
    END IF;

    START TRANSACTION;

    DELETE c FROM employee_payroll_component_details c
      JOIN employee_payroll_details d ON d.payroll_detail_id = c.payroll_detail_id
      JOIN payroll_runs r ON r.payroll_run_id = d.payroll_run_id
     WHERE r.payroll_cycle_id <> v_keep;
    SET v_components = ROW_COUNT();

    DELETE s FROM employee_payslips s
      JOIN employee_payroll_details d ON d.payroll_detail_id = s.payroll_detail_id
      JOIN payroll_runs r ON r.payroll_run_id = d.payroll_run_id
     WHERE r.payroll_cycle_id <> v_keep;
    SET v_payslips = ROW_COUNT();

    DELETE p FROM payroll_payments p
      JOIN employee_payroll_details d ON d.payroll_detail_id = p.payroll_detail_id
      JOIN payroll_runs r ON r.payroll_run_id = d.payroll_run_id
     WHERE r.payroll_cycle_id <> v_keep;
    SET v_payments = ROW_COUNT();

    DELETE d FROM employee_payroll_details d
      JOIN payroll_runs r ON r.payroll_run_id = d.payroll_run_id
     WHERE r.payroll_cycle_id <> v_keep;
    SET v_details = ROW_COUNT();

    DELETE FROM payroll_runs WHERE payroll_cycle_id <> v_keep;
    SET v_runs = ROW_COUNT();

    DELETE FROM payroll_cycle_status_log WHERE payroll_cycle_id <> v_keep;
    SET v_logs = ROW_COUNT();

    DELETE FROM payroll_manual_inputs
     WHERE NOT (payroll_month = p_keep_month AND payroll_year = p_keep_year);
    SET v_inputs = ROW_COUNT();

    DELETE FROM payroll_cycles WHERE payroll_cycle_id <> v_keep;
    SET v_cycles = ROW_COUNT();

    COMMIT;

    SELECT 'Y' AS status,
           CONCAT('Kept payroll cycle ', v_keep, ' (month ', p_keep_month, ' of ', p_keep_year, ').') AS remarks,
           v_cycles AS cycles_deleted, v_runs AS runs_deleted, v_details AS employee_rows_deleted,
           v_components AS component_rows_deleted, v_payslips AS payslips_deleted,
           v_payments AS payments_deleted, v_logs AS log_rows_deleted, v_inputs AS manual_inputs_deleted;
END$$

-- the month to keep: June 2026
CALL hrms_cleanup_keep_one_cycle(6, 2026)$$

DROP PROCEDURE IF EXISTS hrms_cleanup_keep_one_cycle$$

DELIMITER ;
