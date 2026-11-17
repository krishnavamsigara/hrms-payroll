
-- ---------------------------------------------------------------------
-- P3-006  hrms_component_set_flags (P1-007), set by the page after a
--         successful save:
--           p_is_statutory      1 = statutory (a label: PF, ESI, PT ...)
--           p_include_in_total  1 = counts in the total of its type
--           p_is_balancing      1 = this earning is the rest of the CTC;
--                               only one component can be it
--         When "counts in total" or "balancing" changes: totals are
--         rebuilt (P3-004), every salary is recalculated and checked
--         (C-101; an error cancels everything), calculated payroll cycles
--         go back (C-102) and the change is audited.
--         Who may call: active ADMIN or HR.
--         Returns: status, remarks, findings, impact.
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
    DECLARE v_code     VARCHAR(30);
    DECLARE v_type     VARCHAR(30);
    DECLARE v_scope    VARCHAR(20);
    DECLARE v_manual   TINYINT;
    DECLARE v_slab     TINYINT;
    DECLARE v_old_incl TINYINT;
    DECLARE v_old_bal  TINYINT;
    DECLARE v_incl     TINYINT;
    DECLARE v_bal      TINYINT;
    DECLARE v_other_bal VARCHAR(30) DEFAULT NULL;
    DECLARE v_tchanged INT DEFAULT 0;
    DECLARE v_tnote    VARCHAR(1000);
    DECLARE v_error    VARCHAR(500);
    DECLARE v_findings LONGTEXT;
    DECLARE v_impact   LONGTEXT;
    DECLARE v_structures INT DEFAULT 0;
    DECLARE v_changed  INT DEFAULT 0;
    DECLARE v_notice   VARCHAR(500);
    DECLARE v_err      VARCHAR(500);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'N' AS status, COALESCE(v_err, 'The settings could not be saved. Nothing was changed.') AS remarks,
               NULL AS findings, NULL AS impact;
    END;

    SELECT MAX(UPPER(TRIM(user_category))) INTO v_user_category
      FROM user_login_details
     WHERE emp_id = TRIM(p_emp_id) AND LOWER(TRIM(status)) = 'active';
    IF v_user_category IS NULL OR v_user_category NOT IN ('ADMIN', 'HR') THEN
        SELECT 'N' AS status, 'Access denied: only active ADMIN or HR users can manage salary components.' AS remarks,
               NULL AS findings, NULL AS impact;
        LEAVE sf;
    END IF;

    SELECT MAX(UPPER(component_code)), MAX(component_type), MAX(calculation_scope), MAX(is_manual), MAX(is_slab),
           MAX(include_in_total), MAX(is_balancing)
      INTO v_code, v_type, v_scope, v_manual, v_slab, v_old_incl, v_old_bal
      FROM salary_component_master WHERE component_id = p_component_id;
    IF v_code IS NULL THEN
        SELECT 'N' AS status, 'Salary component not found.' AS remarks, NULL AS findings, NULL AS impact;
        LEAVE sf;
    END IF;

    -- a total neither counts in a total nor balances
    SET v_incl = IF(v_scope = 'AGGREGATE', v_old_incl, IF(COALESCE(p_include_in_total, 1) = 1, 1, 0));
    SET v_bal  = IF(v_scope = 'AGGREGATE', 0, IF(COALESCE(p_is_balancing, 0) = 1, 1, 0));
    IF v_bal = 1 AND v_type <> 'EARNING' THEN
        SELECT 'N' AS status, 'Only an earning can be the balancing component (rest of CTC).' AS remarks,
               NULL AS findings, NULL AS impact;
        LEAVE sf;
    END IF;
    IF v_bal = 1 AND (v_manual = 1 OR v_slab = 1) THEN
        SELECT 'N' AS status, 'A monthly-entry or slab component cannot be the balancing component.' AS remarks,
               NULL AS findings, NULL AS impact;
        LEAVE sf;
    END IF;
    IF v_bal = 1 AND v_incl = 0 THEN
        SELECT 'N' AS status, 'The balancing component must count in gross.' AS remarks,
               NULL AS findings, NULL AS impact;
        LEAVE sf;
    END IF;

    START TRANSACTION;
    UPDATE salary_component_master
       SET is_statutory = IF(COALESCE(p_is_statutory, 0) = 1, 1, 0),
           include_in_total = v_incl,
           is_balancing = v_bal
     WHERE component_id = p_component_id;

    IF v_bal = 1 THEN
        -- only one balancing component; it has no rule of its own
        SELECT GROUP_CONCAT(component_code) INTO v_other_bal
          FROM salary_component_master WHERE is_balancing = 1 AND component_id <> p_component_id;
        UPDATE salary_component_master SET is_balancing = 0 WHERE is_balancing = 1 AND component_id <> p_component_id;
        UPDATE salary_component_master
           SET calculation_type = 'FIXED', percentage_value = 0, percentage_base = 'NONE', formula_expression = NULL
         WHERE component_id = p_component_id;
        UPDATE employee_salary_structure
           SET calculation_type = 'FIXED', component_value = 0, percentage_base = 'NONE', formula_expression = NULL
         WHERE component_id = p_component_id AND is_overridden = 0;
    END IF;

    CALL hrms_component_rebuild_totals(v_tchanged, v_tnote);

    IF v_incl <> v_old_incl OR v_bal <> v_old_bal OR v_tchanged > 0 THEN
        CALL hrms_component_change_finish(p_component_id, v_error, v_findings, v_impact, v_structures, v_changed);
        IF v_error IS NOT NULL THEN
            ROLLBACK;
            SELECT 'N' AS status, LEFT(CONCAT('Not saved: ', v_error), 500) AS remarks, v_findings AS findings, v_impact AS impact;
            LEAVE sf;
        END IF;
        IF v_changed > 0 THEN
            CALL hrms_component_cycle_guard(p_emp_id, CONCAT('Component ', v_code, ' totals / balancing changed'), v_notice);
        END IF;
        CALL hrms_payroll_audit_add('COMPONENT', 'UPDATE', 'salary_component_master', p_component_id, NULL, NULL, NULL, NULL,
             JSON_OBJECT('code', v_code, 'include_in_total', v_old_incl, 'is_balancing', v_old_bal),
             JSON_OBJECT('code', v_code, 'include_in_total', v_incl, 'is_balancing', v_bal),
             LEFT(CONCAT(v_code, ': counts in total ', v_incl, ', balancing ', v_bal, '.',
                         IF(v_other_bal IS NULL, '', CONCAT(' No longer balancing: ', v_other_bal, '.')),
                         IF(v_tnote IS NULL, '', CONCAT(' ', v_tnote)),
                         ' Employee amounts changed: ', v_changed, '.'), 1000), p_emp_id);
    END IF;
    COMMIT;

    SELECT 'Y' AS status,
           CONCAT('Settings saved.',
                  IF(v_tnote IS NULL, '', CONCAT(' ', v_tnote)),
                  IF(v_other_bal IS NULL, '', CONCAT(' ', v_other_bal, ' is no longer the balancing component.')),
                  IF(v_structures > 0, CONCAT(' Salaries recalculated; amounts changed: ', v_changed, '.'), ''),
                  IF(v_notice IS NULL, '', CONCAT(' ', v_notice))) AS remarks,
           v_findings AS findings, v_impact AS impact;
END$$

-- ---------------------------------------------------------------------
-- P3-009  totals rebuilt from the ticks, every salary recalculated
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_phase_recalc$$
CREATE PROCEDURE hrms_phase_recalc()
BEGIN
    DECLARE v_tchanged   INT DEFAULT 0;
    DECLARE v_tnote      VARCHAR(1000);
    DECLARE v_structures INT DEFAULT 0;
    DECLARE v_changed    INT DEFAULT 0;
    DECLARE v_errors     INT DEFAULT 0;
    DECLARE v_text       VARCHAR(500);
    DECLARE v_signal     VARCHAR(128);
    CALL hrms_component_rebuild_totals(v_tchanged, v_tnote);
    CALL hrms_recalculate_all_structures(v_structures, v_changed, v_errors, v_text);
    IF v_errors > 0 THEN
        SET v_signal = LEFT(CONCAT('Recalculation failed: ', COALESCE(v_text, '?')), 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_signal;
    END IF;
    SELECT v_tchanged AS totals_rebuilt, v_tnote AS totals, v_structures AS salaries_recalculated, v_changed AS amounts_changed;
END$$
CALL hrms_phase_recalc()$$
DROP PROCEDURE IF EXISTS hrms_phase_recalc$$

DELIMITER ;
