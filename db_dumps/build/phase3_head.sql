-- =====================================================================
-- component_phase3.sql : salary components, phase 3
--   Totals are built from a "counts in total" tick on every component, and
--   one earning can be the balancing component (rest of the CTC), so a new
--   earning never pushes the salary above the CTC.
--
-- Database : production_hrms_db (MySQL 8) and hrmstest (MariaDB 10.11)
-- Run with : mysql --default-character-set=utf8mb4 -u <user> -p <database> < component_phase3.sql
-- Order    : script.sql -> component_phase1.sql -> component_phase2.sql -> component_phase3.sql
--            (run script.sql again later? then run the phase files again too)
-- Re-run   : safe. Columns and the first data set-up happen once,
--            procedures are recreated, totals are rebuilt only when they
--            differ.
-- Built by : db_dumps/build/build_phase3.py
--
-- APPLICATION FILES (deploy with this phase)
--   changed app/Views/payroll/salary_structure_edit.php   rule text "Rest of CTC (balancing)"
--           (salary_component_form.php from phase 1 already has the "Rest of CTC"
--            method, the "Counts in total" tick and the read-only automatic totals)
--
-- CHANGE INDEX
--   P3-001  ALTER TABLE salary_component_master + include_in_total (1 = counts
--                       in the total of its type), + is_balancing
--           ALTER TABLE payroll_variables + total_of_type (GROSS = EARNING,
--                       TOTAL_DEDUCTIONS = DEDUCTION, TOTAL_EMPLOYER_CONTRIBUTION
--                       = EMPLOYER_CONTRIBUTION)
--           DATA (once) include_in_total from the current total formulas;
--                       the earning whose formula is "CTC1 ... minus
--                       TOTAL_EMPLOYER_CONTRIBUTION" (OTHERS) becomes the
--                       balancing component
--   P3-002  UPDATE FUNCTION  hrms_component_method: + BALANCING
--   P3-003  UPDATE PROCEDURE hrms_engine_run: balancing = CTC1 - other
--                       earnings counted in gross (not monthly entries) -
--                       employer contributions counted in their total
--   P3-004  NEW PROCEDURE    hrms_component_rebuild_totals: every total with
--                       a total_of_type and a plain-sum formula becomes the
--                       sum of the active components of that type that
--                       count in it
--   P3-005  UPDATE PROCEDURE hrms_component_save: + method BALANCING
--   P3-006  UPDATE PROCEDURE hrms_component_set_flags: statutory, counts in
--                       total, balancing; totals rebuilt; every salary
--                       recalculated; calculated payroll cycles go back
--   P3-007  UPDATE PROCEDURE hrms_formula_names: + auto_total
--   P3-008  UPDATE PROCEDURE hrms_salary_components_for_structure: + flags
--   P3-009  DATA        totals rebuilt, every salary recalculated
--
-- CALCULATION ORDER
--   Not re-sorted automatically: the engine already repeats its passes
--   until amounts settle, and re-numbering every component could change
--   how circles (ESI <-> GROSS <-> balancing) settle. A new component gets
--   its order automatically (C-106); the page hides the order under
--   "Advanced".
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- P3-001  columns and first set-up (once)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_phase3_columns$$
CREATE PROCEDURE hrms_phase3_columns()
BEGIN
    DECLARE v_bal BIGINT DEFAULT NULL;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = DATABASE() AND table_name = 'payroll_variables'
                      AND column_name = 'total_of_type') THEN
        ALTER TABLE payroll_variables
          ADD COLUMN total_of_type VARCHAR(30) NULL AFTER data_type;
    END IF;
    UPDATE payroll_variables SET total_of_type = 'EARNING'               WHERE var_code = 'GROSS'                       AND var_kind = 'TOTAL';
    UPDATE payroll_variables SET total_of_type = 'DEDUCTION'             WHERE var_code = 'TOTAL_DEDUCTIONS'            AND var_kind = 'TOTAL';
    UPDATE payroll_variables SET total_of_type = 'EMPLOYER_CONTRIBUTION' WHERE var_code = 'TOTAL_EMPLOYER_CONTRIBUTION' AND var_kind = 'TOTAL';

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = DATABASE() AND table_name = 'salary_component_master'
                      AND column_name = 'include_in_total') THEN
        ALTER TABLE salary_component_master
          ADD COLUMN include_in_total TINYINT(1) NOT NULL DEFAULT 1 AFTER is_statutory,
          ADD COLUMN is_balancing     TINYINT(1) NOT NULL DEFAULT 0 AFTER include_in_total;

        -- counts in total = it is in the formula of the total of its type today
        -- (a type without a total component: counts in the built-in sum)
        UPDATE salary_component_master c
          JOIN payroll_variables pv ON pv.total_of_type = c.component_type
          JOIN salary_component_master t ON UPPER(t.component_code) = pv.var_code AND t.calculation_scope = 'AGGREGATE'
           SET c.include_in_total =
               IF(CONCAT(' ', REGEXP_REPLACE(UPPER(COALESCE(t.formula_expression, '')), '[^A-Z0-9_]', ' '), ' ')
                      LIKE CONCAT('% ', UPPER(c.component_code), ' %'), 1, 0)
         WHERE c.calculation_scope = 'COMPONENT';

        -- the balancing component: an earning whose formula is CTC1 minus the
        -- employer contributions (OTHERS); the lowest id if there are several
        SELECT MIN(component_id) INTO v_bal
          FROM salary_component_master
         WHERE calculation_scope = 'COMPONENT' AND component_type = 'EARNING' AND is_active = 1
           AND calculation_type = 'FORMULA'
           AND CONCAT(' ', REGEXP_REPLACE(UPPER(COALESCE(formula_expression, '')), '[^A-Z0-9_]', ' '), ' ') LIKE '% CTC1 %'
           AND CONCAT(' ', REGEXP_REPLACE(UPPER(COALESCE(formula_expression, '')), '[^A-Z0-9_]', ' '), ' ') LIKE '% TOTAL_EMPLOYER_CONTRIBUTION %';
        IF v_bal IS NOT NULL THEN
            UPDATE salary_component_master
               SET is_balancing = 1, calculation_type = 'FIXED', percentage_value = 0,
                   percentage_base = 'NONE', formula_expression = NULL
             WHERE component_id = v_bal;
            UPDATE employee_salary_structure
               SET calculation_type = 'FIXED', component_value = 0, percentage_base = 'NONE', formula_expression = NULL
             WHERE component_id = v_bal AND is_overridden = 0;
        END IF;
    END IF;
END$$
CALL hrms_phase3_columns()$$
DROP PROCEDURE IF EXISTS hrms_phase3_columns$$

-- ---------------------------------------------------------------------
-- P3-002  hrms_component_method (P1-003) + BALANCING
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS hrms_component_method$$
CREATE FUNCTION hrms_component_method(p_component_id BIGINT) RETURNS VARCHAR(10)
READS SQL DATA
BEGIN
    DECLARE v_method VARCHAR(10);
    SELECT CASE
             WHEN m.calculation_scope = 'AGGREGATE' THEN 'TOTAL'
             WHEN m.is_balancing = 1 THEN 'BALANCING'
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
-- P3-004  hrms_component_rebuild_totals
--   For every payroll variable with a total_of_type (GROSS, TOTAL_DEDUCTIONS,
--   TOTAL_EMPLOYER_CONTRIBUTION) that is also a total component with a plain
--   sum formula (codes and + only): the formula becomes the active components
--   of that type that count in the total, in calculation order ("0" when
--   none). A total with any other formula (written by hand) is left alone.
--   Runs inside the caller's transaction; recalculating is up to the caller.
--   p_changed: how many totals got a new formula.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS hrms_component_rebuild_totals$$
CREATE PROCEDURE hrms_component_rebuild_totals(OUT p_changed INT, OUT p_note VARCHAR(1000))
BEGIN
    DECLARE v_code    VARCHAR(40) DEFAULT '';
    DECLARE v_type    VARCHAR(30);
    DECLARE v_tid     BIGINT;
    DECLARE v_formula TEXT;
    DECLARE v_new     TEXT;
    SET p_changed = 0;
    SET p_note = NULL;
    SET SESSION group_concat_max_len = 100000;
    rb: LOOP
        SET v_code = (SELECT MIN(var_code) FROM payroll_variables
                       WHERE total_of_type IS NOT NULL AND var_code > v_code);
        IF v_code IS NULL THEN LEAVE rb; END IF;
        SET v_type = (SELECT total_of_type FROM payroll_variables WHERE var_code = v_code);
        SET v_tid = NULL, v_formula = NULL;
        SELECT MAX(component_id), MAX(formula_expression) INTO v_tid, v_formula
          FROM salary_component_master
         WHERE UPPER(component_code) = v_code AND calculation_scope = 'AGGREGATE';
        IF v_tid IS NOT NULL THEN
            IF UPPER(TRIM(COALESCE(v_formula, '0'))) NOT REGEXP '^[A-Z0-9_ +]+$' THEN
                SET p_note = LEFT(CONCAT(COALESCE(CONCAT(p_note, ' '), ''), v_code,
                                         ' has its own formula and is not rebuilt from the ticks.'), 1000);
            ELSE
                SELECT GROUP_CONCAT(UPPER(component_code) ORDER BY calculation_order, component_id SEPARATOR ' + ')
                  INTO v_new
                  FROM salary_component_master
                 WHERE calculation_scope = 'COMPONENT' AND is_active = 1
                   AND component_type = v_type AND include_in_total = 1;
                SET v_new = COALESCE(v_new, '0');
                IF REPLACE(UPPER(COALESCE(v_formula, '')), ' ', '') <> REPLACE(v_new, ' ', '') THEN
                    UPDATE salary_component_master SET formula_expression = v_new WHERE component_id = v_tid;
                    SET p_changed = p_changed + 1;
                    SET p_note = LEFT(CONCAT(COALESCE(CONCAT(p_note, ' '), ''), v_code, ' = ', v_new, '.'), 1000);
                END IF;
            END IF;
        END IF;
    END LOOP;
END$$
