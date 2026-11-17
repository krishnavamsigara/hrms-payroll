-- =====================================================================
-- queries_to_procedures.sql : queries that the application ran directly
--                             on tables, moved into stored procedures
--
-- Database : production_hrms_db (MySQL 8) and hrmstest (MariaDB 10.11)
-- Run with : mysql --default-character-set=utf8mb4 -u <user> -p <database> < queries_to_procedures.sql
-- Run after: script.sql (nothing here depends on it, but the application
--            code that calls these procedures also needs script.sql)
-- Re-run   : safe. Each procedure is dropped and created again. No table
--            and no data is changed.
--
-- CHANGE INDEX
--   ID     PROCEDURE                    REPLACES (file : what it ran)
--   Q-001  hrms_payroll_cycle_id_for    app/Controllers/PayrollCycleController.php (cycleIdFor)
--                                       SELECT MAX(payroll_cycle_id) FROM payroll_cycles
--                                        WHERE payroll_month = ? AND payroll_year = ?
--   Q-002  hrms_employee_dropdown       app/Controllers/AdminController.php, two places
--                                       (missing punch-outs page, attendance details page)
--                                       $db->table('user_details')->select('emp_id, emp_name')
--
-- NO NEW PROCEDURE NEEDED
--   - app/Models/AdminModel.php get_settings(): the direct read of
--     company_settings was a fallback that ran the same SELECT as
--     sp_get_company_settings. The fallback is removed in the code.
--   - app/Controllers/AdminController.php: CALL get_emp_leave_balances was
--     already a procedure; the call moved from the controller to
--     EmployeeModel::get_emp_leave_balances().
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- Q-001  hrms_payroll_cycle_id_for
--        The payroll cycle of a month: the newest cycle id for that
--        payroll month and year, or NULL when the month has no cycle.
--        Used to send the old payroll step pages to the payroll cycle page.
--        Returns one row: id.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_payroll_cycle_id_for$$
CREATE PROCEDURE hrms_payroll_cycle_id_for(
    IN p_month INT,
    IN p_year  INT
)
BEGIN
    SELECT MAX(payroll_cycle_id) AS id
      FROM payroll_cycles
     WHERE payroll_month = p_month
       AND payroll_year  = p_year;
END$$

-- ---------------------------------------------------------------------
-- Q-002  hrms_employee_dropdown
--        Every employee for the employee filter of the attendance pages:
--        employee id and name, the same rows and columns the pages read
--        from user_details before.
--        Returns: emp_id, emp_name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_employee_dropdown$$
CREATE PROCEDURE hrms_employee_dropdown()
BEGIN
    SELECT emp_id, emp_name
      FROM user_details;
END$$

DELIMITER ;
