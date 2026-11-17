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

-- ---------------------------------------------------------------------
-- P3-003  hrms_engine_run: the balancing component (rest of CTC1)
--        (copied from its last definition and patched by db_dumps/build/build_phase3.py)
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
    DECLARE v_bal_sum    DECIMAL(18,4);   -- P3
    DECLARE v_bal_ctc    DECIMAL(18,4);   -- P3
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
            -- P2: "applies only when" <Yes/No variable> = Y (or N); any variable, not only ESI
            ELSEIF TRIM(COALESCE(v_eparam, '')) <> ''
               AND (SELECT IF(UPPER(COALESCE(NULLIF(TRIM(v_evalue), ''), 'Y')) = 'N',
                              COALESCE(MAX(fv.var_value), 0) <> 0,
                              COALESCE(MAX(fv.var_value), 0) = 0)
                      FROM tmp_hrms_formula_vars fv
                     WHERE fv.var_code = IF(UPPER(TRIM(v_eparam)) = 'EMPLOYEE_ESI_ELIGIBLE', 'ESI_APPLICABLE',
                                            UPPER(TRIM(v_eparam)))) = 1 THEN
                SET v_new = 0;
            -- P3: the balancing component is what is left of CTC1 after the other
            --     earnings counted in gross (not monthly entries) and the employer
            --     contributions counted in their total, so the salary always adds
            --     up to the CTC. An employee's own setting still wins.
            ELSEIF v_overridden = 0
               AND (SELECT COALESCE(MAX(bm.is_balancing), 0) FROM salary_component_master bm
                     WHERE bm.component_id = v_cid) = 1 THEN
                SELECT COALESCE(SUM(CASE
                           WHEN bm.component_type = 'EARNING' AND bm.is_balancing = 0
                                AND bm.is_manual = 0 AND bm.calculation_type <> 'MANUAL' THEN bv.var_value
                           WHEN bm.component_type = 'EMPLOYER_CONTRIBUTION' THEN bv.var_value
                           ELSE 0 END), 0)
                  INTO v_bal_sum
                  FROM tmp_hrms_formula_vars bv
                  JOIN salary_component_master bm ON bm.component_id = bv.component_id
                 WHERE bm.calculation_scope = 'COMPONENT' AND bm.is_active = 1 AND bm.include_in_total = 1;
                SELECT COALESCE(MAX(var_value), 0) INTO v_bal_ctc FROM tmp_hrms_formula_vars WHERE var_code = 'CTC1';
                SET v_new = v_bal_ctc - v_bal_sum;
                SET v_limits = 1;
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
-- P3-005  hrms_component_save: + method BALANCING
--        (copied from its last definition and patched by db_dumps/build/build_phase3.py)
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
        WHEN 'BALANCING' THEN
            -- P3: rest of the CTC; the flag itself is set by hrms_component_set_flags
            SET v_calc = 'FIXED', v_value = 0;
            IF UPPER(TRIM(COALESCE(p_type, ''))) <> 'EARNING' THEN
                SET v_msg = 'Only an earning can be the balancing component (rest of CTC).';
            END IF;
        ELSE
            SET v_msg = 'Choose how the component is calculated: fixed, percent, formula, slabs, monthly entry or balancing.';
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
-- P3-007  hrms_formula_names: + auto_total
--        (copied from its last definition and patched by db_dumps/build/build_phase3.py)
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
            SELECT 'VARIABLE' AS kind, v.var_code AS code, v.var_name AS label, v.data_type,
                   NULL AS component_type, NULL AS component_id, 0 AS calculation_order, 1 AS is_active,
                   v.sort_order, v.var_kind, v.description, 0 AS auto_total
              FROM payroll_variables v
             WHERE v.is_active = 1
               AND NOT (v.var_kind = 'TOTAL'
                        AND EXISTS (SELECT 1 FROM salary_component_master m WHERE UPPER(m.component_code) = v.var_code))
            UNION ALL
            SELECT IF(m.calculation_scope = 'AGGREGATE', 'TOTAL', 'COMPONENT'), UPPER(m.component_code), m.component_name,
                   'NUMBER', m.component_type, m.component_id, m.calculation_order, m.is_active,
                   1000 + m.calculation_order, NULL, NULL,
                   IF(m.calculation_scope = 'AGGREGATE'
                      AND EXISTS (SELECT 1 FROM payroll_variables pv
                                   WHERE pv.var_code = UPPER(m.component_code) AND pv.total_of_type IS NOT NULL)
                      AND UPPER(TRIM(COALESCE(m.formula_expression, '0'))) REGEXP '^[A-Z0-9_ +]+$', 1, 0)
              FROM salary_component_master m
           ) x
     ORDER BY FIELD(x.kind, 'VARIABLE', 'COMPONENT', 'TOTAL'), x.sort_order, x.code;
END$$

-- ---------------------------------------------------------------------
-- P3-008  hrms_salary_components_for_structure: + is_balancing, include_in_total
--        (copied from its last definition and patched by db_dumps/build/build_phase3.py)
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
               m.is_slab, m.is_manual, m.is_taxable, m.is_balancing, m.include_in_total,
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
