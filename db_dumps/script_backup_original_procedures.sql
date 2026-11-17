-- Backup of procedures replaced by script.sql (taken 2026-11-13 10:30 from production_hrms_db).
-- Run this file to put the original procedures back.

DELIMITER $$

DROP PROCEDURE IF EXISTS `hrms_update_component_master`$$
CREATE PROCEDURE `hrms_update_component_master`(
    IN p_emp_id VARCHAR(20),
    IN p_action VARCHAR(20),
    IN p_component_id BIGINT,
    IN p_component_code VARCHAR(30),
    IN p_component_name VARCHAR(100),
    IN p_component_type VARCHAR(30),
    IN p_calculation_type VARCHAR(30),
    IN p_percentage_base VARCHAR(20),
    IN p_percentage_value DECIMAL(7,2),
    IN p_is_taxable TINYINT,
    IN p_is_active TINYINT
)
BEGIN
    DECLARE v_role VARCHAR(30);
    DECLARE v_actor_status VARCHAR(20);
    DECLARE v_component_exists INT DEFAULT 0;
    DECLARE v_affected INT DEFAULT 0;
    DECLARE v_master_updated INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    
    SELECT MAX(user_category), MAX(status)
    INTO v_role, v_actor_status
    FROM user_login_details
    WHERE emp_id = p_emp_id;

    IF v_role IS NULL
       OR LOWER(COALESCE(v_actor_status, '')) <> 'active'
       OR UPPER(v_role) NOT IN ('ADMIN', 'HR') THEN

        SELECT
            'N' AS status,
            'Only active ADMIN or HR users can manage components.'
                AS remarks;

    
    ELSEIF UPPER(COALESCE(p_action, '')) NOT IN
           ('INSERT', 'UPDATE', 'ACTIVE') THEN

        SELECT
            'N' AS status,
            'Invalid action. Use INSERT, UPDATE, or ACTIVE.'
                AS remarks;

    
    ELSEIF UPPER(p_action) = 'UPDATE'
       AND (
            p_component_id IS NULL
            OR p_component_id <= 0
            OR p_component_code IS NULL
            OR TRIM(p_component_code) = ''
            OR p_component_name IS NULL
            OR TRIM(p_component_name) = ''
            OR UPPER(COALESCE(p_component_type, '')) NOT IN
                ('EARNING', 'DEDUCTION', 'EMPLOYER_CONTRIBUTION')
            OR UPPER(COALESCE(p_calculation_type, '')) NOT IN
                ('FIXED', 'PERCENTAGE', 'FORMULA', 'MANUAL', 'STATUTORY')
            OR UPPER(COALESCE(p_percentage_base, '')) NOT IN
                ('BASIC', 'GROSS', 'CTC', 'NONE')
            OR p_percentage_value IS NULL
            OR p_is_taxable IS NULL
            OR p_is_taxable NOT IN (0, 1)
            OR p_is_active IS NULL
            OR p_is_active NOT IN (0, 1)
       ) THEN

        SELECT
            'N' AS status,
            'Invalid or missing component details.'
                AS remarks;

    ELSE

        START TRANSACTION;

        

        IF UPPER(p_action) = 'UPDATE' THEN

            SELECT COUNT(*)
            INTO v_component_exists
            FROM salary_component_master
            WHERE component_id = p_component_id;

            IF v_component_exists = 0 THEN

                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Component not found.';

            END IF;

            
            UPDATE salary_component_master
            SET
                component_code = p_component_code,
                component_name = p_component_name,
                component_type = UPPER(p_component_type),
                calculation_type = UPPER(p_calculation_type),
                percentage_base = UPPER(p_percentage_base),
                percentage_value = p_percentage_value,
                is_taxable = p_is_taxable,
                is_active = p_is_active
            WHERE component_id = p_component_id;

            SET v_master_updated = ROW_COUNT();

            

            UPDATE employee_salary_structure ess

            INNER JOIN salary_structure ss
                ON ss.structure_id = ess.structure_id

            LEFT JOIN
            (
                SELECT
                    basic_ess.structure_id,
                    MAX(basic_ess.monthly_amount) AS basic_amount
                FROM employee_salary_structure basic_ess

                INNER JOIN salary_component_master basic_scm
                    ON basic_scm.component_id =
                       basic_ess.component_id

                WHERE basic_scm.component_code = 'BASIC'

                GROUP BY basic_ess.structure_id

            ) basic_data
                ON basic_data.structure_id = ss.structure_id

            SET

                
                ess.calculation_type =
                    CASE
                        WHEN UPPER(p_calculation_type) = 'STATUTORY'
                            THEN 'MANUAL'
                        ELSE UPPER(p_calculation_type)
                    END,

                
                ess.component_value = p_percentage_value,

                
                ess.percentage_base = UPPER(p_percentage_base),

                
                ess.monthly_amount =
                    CASE

                        
                        WHEN UPPER(p_calculation_type) = 'PERCENTAGE'
                             AND UPPER(p_percentage_base) = 'CTC'
                        THEN ROUND(
                            ss.monthly_ctc
                            * p_percentage_value / 100,
                            2
                        )

                        
                        WHEN UPPER(p_calculation_type) = 'PERCENTAGE'
                             AND UPPER(p_percentage_base) = 'BASIC'
                        THEN ROUND(
                            COALESCE(basic_data.basic_amount, 0)
                            * p_percentage_value / 100,
                            2
                        )

                        
                        WHEN UPPER(p_calculation_type)
                             IN ('FIXED', 'MANUAL', 'STATUTORY')
                        THEN ess.monthly_amount

                        
                        WHEN UPPER(p_calculation_type) = 'FORMULA'
                        THEN ess.monthly_amount

                        
                        ELSE ess.monthly_amount

                    END,

                ess.updated_at = CURRENT_TIMESTAMP

            WHERE ess.component_id = p_component_id;

            SET v_affected = ROW_COUNT();

            COMMIT;

            SELECT
                'Y' AS status,
                'Master component updated and employee component settings synchronized.'
                    AS remarks,
                p_component_id AS component_id,
                v_master_updated AS master_rows_changed,
                v_affected AS employee_structure_rows_changed;

        ELSEIF UPPER(p_action) = 'ACTIVE' THEN

            IF p_component_id IS NULL
               OR p_component_id <= 0
               OR p_is_active IS NULL
               OR p_is_active NOT IN (0, 1) THEN

                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT =
                    'For ACTIVE, provide component_id and is_active (0 or 1).';

            END IF;

            UPDATE salary_component_master
            SET
                is_active = p_is_active,
                updated_at = CURRENT_TIMESTAMP
            WHERE component_id = p_component_id;

            IF ROW_COUNT() = 0 THEN

                SELECT COUNT(*)
                INTO v_component_exists
                FROM salary_component_master
                WHERE component_id = p_component_id;

                IF v_component_exists = 0 THEN

                    SIGNAL SQLSTATE '45000'
                        SET MESSAGE_TEXT = 'Component not found.';

                END IF;

            END IF;

            COMMIT;

            SELECT
                'Y' AS status,
                CASE
                    WHEN p_is_active = 1
                        THEN 'Component activated.'
                    ELSE 'Component deactivated.'
                END AS remarks,
                p_component_id AS component_id,
                p_is_active AS is_active;

        ELSEIF UPPER(p_action) = 'INSERT' THEN

            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Use your existing INSERT procedure branch for component creation.';

        END IF;

    END IF;

END$$

DROP PROCEDURE IF EXISTS `hrms_get_salary_components`$$
CREATE PROCEDURE `hrms_get_salary_components`(
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

    
    SELECT COUNT(*)
    INTO v_user_found
    FROM user_login_details
    WHERE emp_id = p_emp_id;

    IF v_user_found = 0 THEN

        SELECT
            'N' AS status,
            'Employee not found' AS remarks,
            0 AS total_components,
            0 AS earnings_count,
            0 AS deductions_count,
            0 AS employer_contribution_count;

    ELSE

        SELECT user_category, status
        INTO v_user_category, v_user_status
        FROM user_login_details
        WHERE emp_id = p_emp_id
        LIMIT 1;

        IF LOWER(COALESCE(v_user_status, '')) <> 'active' THEN

            SELECT
                'N' AS status,
                'Employee account is inactive' AS remarks,
                0 AS total_components,
                0 AS earnings_count,
                0 AS deductions_count,
                0 AS employer_contribution_count;

        ELSEIF UPPER(COALESCE(v_user_category, ''))
               NOT IN ('ADMIN', 'HR') THEN

            SELECT
                'N' AS status,
                'Access denied. Only ADMIN or HR can view salary components'
                    AS remarks,
                0 AS total_components,
                0 AS earnings_count,
                0 AS deductions_count,
                0 AS employer_contribution_count;

        ELSE

            
            SELECT
                COUNT(*),
                COALESCE(SUM(component_type = 'EARNING'), 0),
                COALESCE(SUM(component_type = 'DEDUCTION'), 0),
                COALESCE(SUM(
                    component_type = 'EMPLOYER_CONTRIBUTION'
                ), 0)
            INTO
                v_total_components,
                v_earnings_count,
                v_deductions_count,
                v_employer_contribution_count
            FROM salary_component_master;
            

            IF v_total_components = 0 THEN

                SELECT
                    'N' AS status,
                    'No active salary components found' AS remarks,
                    v_total_components AS total_components,
                    v_earnings_count AS earnings_count,
                    v_deductions_count AS deductions_count,
                    v_employer_contribution_count
                        AS employer_contribution_count;

            ELSE

                
                SELECT
                    'Y' AS status,
                    'Salary components retrieved successfully' AS remarks,
                    v_total_components AS total_components,
                    v_earnings_count AS earnings_count,
                    v_deductions_count AS deductions_count,
                    v_employer_contribution_count
                        AS employer_contribution_count,
                    component_id,
                    component_code,
                    component_name,
                    component_type,
                    calculation_type,
                    percentage_base,
                    percentage_value,
                    is_taxable,
                    is_active
                FROM salary_component_master
                
                ORDER BY
                    FIELD(
                        component_type,
                        'EARNING',
                        'DEDUCTION',
                        'EMPLOYER_CONTRIBUTION'
                    ),
                    component_id;

            END IF;

        END IF;

    END IF;

END$$



DROP PROCEDURE IF EXISTS `hrms_create_payroll_cycle_complete`$$
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
        a.paid_days,
        0,
        a.unpaid_days,
        a.absent_days,

        ROUND(
            ss.monthly_ctc
            * LEAST(GREATEST(a.paid_days, 0), 30)
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


    

    INSERT INTO employee_payroll_component_details (
        payroll_detail_id,
        component_id,
        component_code,
        component_name,
        component_type,
        calculation_type,
        component_value,
        percentage_base,
        percentage_value,
        formula_expression,
        calculated_amount,
        is_taxable
    )
    SELECT
        epd.payroll_detail_id,
        scm.component_id,
        scm.component_code,
        scm.component_name,
        scm.component_type,

        COALESCE(
            ess.calculation_type,
            scm.calculation_type
        ),

        COALESCE(
            ess.component_value,
            0.00
        ),

        COALESCE(
            ess.percentage_base,
            scm.percentage_base,
            'NONE'
        ),

        COALESCE(
            scm.percentage_value,
            0.00
        ),

        ess.formula_expression,

        ROUND(
            COALESCE(ess.monthly_amount, 0.00)
            * LEAST(
                GREATEST(epd.payable_days, 0),
                30
            )
            / 30,
            2
        ),

        COALESCE(
            scm.is_taxable,
            1
        )

    FROM employee_payroll_details epd

    INNER JOIN salary_structure ss
        ON ss.structure_id = epd.structure_id

    INNER JOIN employee_salary_structure ess
        ON ess.structure_id = ss.structure_id

    INNER JOIN salary_component_master scm
        ON scm.component_id = ess.component_id
       AND scm.is_active = 1

    WHERE epd.payroll_run_id = v_payroll_run_id;


    SET v_total_components = ROW_COUNT();


    

    UPDATE employee_payroll_details epd

    SET
        epd.gross_earnings = (
            SELECT COALESCE(
                ROUND(SUM(
                    CASE
                        WHEN epc.component_type = 'EARNING'
                        THEN epc.calculated_amount
                        ELSE 0
                    END
                ), 2),
                0.00
            )
            FROM employee_payroll_component_details epc
            WHERE epc.payroll_detail_id = epd.payroll_detail_id
        ),

        epd.total_deductions = (
            SELECT COALESCE(
                ROUND(SUM(
                    CASE
                        WHEN epc.component_type = 'DEDUCTION'
                        THEN epc.calculated_amount
                        ELSE 0
                    END
                ), 2),
                0.00
            )
            FROM employee_payroll_component_details epc
            WHERE epc.payroll_detail_id = epd.payroll_detail_id
        ),

        epd.employer_contributions = (
            SELECT COALESCE(
                ROUND(SUM(
                    CASE
                        WHEN epc.component_type = 'EMPLOYER_CONTRIBUTION'
                        THEN epc.calculated_amount
                        ELSE 0
                    END
                ), 2),
                0.00
            )
            FROM employee_payroll_component_details epc
            WHERE epc.payroll_detail_id = epd.payroll_detail_id
        ),

        epd.net_pay = ROUND(
            (
                SELECT COALESCE(
                    SUM(
                        CASE
                            WHEN epc.component_type = 'EARNING'
                            THEN epc.calculated_amount
                            ELSE 0
                        END
                    ),
                    0.00
                )
                FROM employee_payroll_component_details epc
                WHERE epc.payroll_detail_id = epd.payroll_detail_id
            )
            -
            (
                SELECT COALESCE(
                    SUM(
                        CASE
                            WHEN epc.component_type = 'DEDUCTION'
                            THEN epc.calculated_amount
                            ELSE 0
                        END
                    ),
                    0.00
                )
                FROM employee_payroll_component_details epc
                WHERE epc.payroll_detail_id = epd.payroll_detail_id
            ),
            2
        ),

        epd.employee_payroll_status = 'CALCULATED',

        epd.calculation_remarks = CONCAT(
            COALESCE(epd.calculation_remarks, ''),
            ' Gross earnings, deductions, employer contributions, ',
            'and net pay calculated from payroll component snapshots.'
        )

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



DROP PROCEDURE IF EXISTS `hrms_get_payslip`$$
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

    

    IF p_requester_emp_id IS NULL
       OR TRIM(p_requester_emp_id) = '' THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Requester employee ID is required';

    END IF;

    

    SELECT COUNT(*)
    INTO v_user_found
    FROM user_login_details
    WHERE emp_id = TRIM(p_requester_emp_id);

    IF v_user_found = 0 THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Requester account not found';

    END IF;

    SELECT
        UPPER(TRIM(user_category)),
        UPPER(TRIM(status))
    INTO
        v_user_category,
        v_user_status
    FROM user_login_details
    WHERE emp_id = TRIM(p_requester_emp_id)
    LIMIT 1;

    IF COALESCE(v_user_status, '') <> 'ACTIVE' THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Access denied: Account is not active';

    END IF;

    

    IF COALESCE(v_user_category, '')
       NOT IN ('ADMIN', 'HR', 'EMP') THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Access denied: ADMIN, HR, or EMP role required';

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
        UPPER(pc.cycle_status) IN ('FINALIZED', 'CLOSED')

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

            JSON_ARRAY() AS components;

    ELSE

        

        SELECT

            

            'Y' AS status,

            'Payslip retrieved successfully' AS remarks,

            

           
            pc.payroll_month,
            pc.payroll_year,
           

            

            
            pr.run_status,
            
(
    SELECT ss.monthly_ctc
    FROM salary_structure ss
    WHERE ss.emp_id = epd.emp_id
      AND ss.structure_status = 'ACTIVE'
    ORDER BY ss.effective_from DESC, ss.structure_id DESC
    LIMIT 1
) AS monthly_ctc,

            

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
                ),
                JSON_ARRAY()
            ) AS components

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

            

            UPPER(pc.cycle_status) IN ('FINALIZED', 'CLOSED')

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

DELIMITER ;

-- ---------------------------------------------------------------------
-- Original hrms_get_payroll_month_details (replaced by C-112 in script.sql)
-- ---------------------------------------------------------------------
DELIMITER $$
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

    

    SELECT COUNT(*)
    INTO v_requester_found
    FROM user_login_details
    WHERE emp_id = p_emp_id
      AND status = 'ACTIVE'
      AND user_category IN ('ADMIN', 'HR');

    IF v_requester_found = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Access denied: Active ADMIN or HR account required';
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
            ),
            JSON_ARRAY()
        ) AS salary_components

    FROM ranked_payroll rp

    LEFT JOIN user_details ud
        ON ud.emp_id = rp.emp_id

    WHERE rp.row_num = 1

    ORDER BY rp.emp_id;

END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- Original hrms_get_employee_salary_structure (replaced in script.sql, role check C-115..)
-- ---------------------------------------------------------------------
DELIMITER $$
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

    
    SELECT COUNT(*)
    INTO v_user_found
    FROM user_login_details
    WHERE emp_id = p_requester_emp_id;

    IF v_user_found = 0 THEN

        SELECT 'N' AS status,
               'Requesting employee not found' AS remarks;

    ELSE

        SELECT user_category, status
        INTO v_user_category, v_user_status
        FROM user_login_details
        WHERE emp_id = p_requester_emp_id
        LIMIT 1;

        IF LOWER(COALESCE(v_user_status, '')) <> 'active' THEN

            SELECT 'N' AS status,
                   'Requesting employee account is inactive' AS remarks;

        ELSEIF UPPER(COALESCE(v_user_category, ''))
               NOT IN ('ADMIN', 'HR') THEN

            SELECT 'N' AS status,
                   'Access denied. Only ADMIN or HR can view salary details'
                   AS remarks;

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

    END IF;

END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- Original finalize_payroll_attendance_proc (replaced in script.sql, role check C-115..)
-- ---------------------------------------------------------------------
DELIMITER $$
DROP PROCEDURE IF EXISTS finalize_payroll_attendance_proc$$
CREATE PROCEDURE `finalize_payroll_attendance_proc`(
    IN p_emp_id VARCHAR(20),
    IN p_month INT,
    IN p_year INT
)
main_block: BEGIN

    DECLARE v_user_category VARCHAR(20);

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
      AND UPPER(TRIM(status)) = 'ACTIVE';

    IF v_user_category IS NULL
       OR v_user_category NOT IN ('ADMIN', 'HR', 'SUPERADMIN') THEN

        SELECT
            'N' AS status,
            'Unauthorized: only active ADMIN, HR, or SUPERADMIN can finalize attendance.'
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

    

    START TRANSACTION;

    UPDATE payroll_attendance_summary
    SET
        is_finalized = 'Y',
        updated_at = NOW()
    WHERE payroll_month = p_month
      AND payroll_year = p_year
      AND (is_finalized IS NULL OR is_finalized <> 'Y');

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
DELIMITER ;

-- ---------------------------------------------------------------------
-- Original sp_generate_payroll_attendance (replaced in script.sql, role check C-115..)
-- ---------------------------------------------------------------------
DELIMITER $$
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
      AND UPPER(TRIM(status)) = 'ACTIVE';

    IF v_admin_category IS NULL
       OR v_admin_category NOT IN ('ADMIN', 'HR') THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Access denied. Only active ADMIN or HR can generate payroll attendance.';

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
DELIMITER ;

-- ---------------------------------------------------------------------
-- Original sp_admin_edit_absent_attendance (replaced in script.sql, role check C-115..)
-- ---------------------------------------------------------------------
DELIMITER $$
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
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            @sq_errno = MYSQL_ERRNO,
            @sq_msg   = MESSAGE_TEXT;
        ROLLBACK;
        SET p_out_status  = 'N';
        SET p_out_message = CONCAT('DB Error [', IFNULL(@sq_errno,'?'), ']: ', IFNULL(@sq_msg, 'Unknown'));
    END;

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

    END main_block;

END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- Original get_payroll_attendance_data_proc (replaced in script.sql, role check C-115..)
-- ---------------------------------------------------------------------
DELIMITER $$
DROP PROCEDURE IF EXISTS get_payroll_attendance_data_proc$$
CREATE PROCEDURE `get_payroll_attendance_data_proc`(
    IN p_emp_id VARCHAR(20),
    IN p_month INT,
    IN p_year INT
)
BEGIN
    DECLARE v_user_category VARCHAR(20);
    
    SELECT user_category INTO v_user_category 
    FROM user_login_details 
    WHERE emp_id = p_emp_id LIMIT 1;
    
    IF v_user_category = 'ADMIN' THEN
        SELECT p.*, e.emp_name, 
               IFNULL(d.department_name, 'N/A') AS department, 
               IFNULL(dg.designation_name, 'N/A') AS designation 
        FROM payroll_attendance_summary p
        JOIN user_details e ON p.emp_id = e.emp_id
        LEFT JOIN department_master d ON e.department = d.department_id
        LEFT JOIN designation_master dg ON e.designation = dg.designation_id
        WHERE p.payroll_month = p_month AND p.payroll_year = p_year
        ORDER BY p.emp_id ASC;
    ELSE
        SELECT 'UNAUTHORIZED' AS error_msg;
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- Original sp_get_payroll_cycle_status (replaced in script.sql, role check C-115..)
-- ---------------------------------------------------------------------
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_get_payroll_cycle_status$$
CREATE PROCEDURE `sp_get_payroll_cycle_status`(
    IN p_financial_year VARCHAR(9)
)
BEGIN
    DECLARE v_start_year INT;
    DECLARE v_end_year INT;
    DECLARE v_cycle_start_day INT;
    DECLARE v_cycle_end_day INT;
    DECLARE v_total_records INT DEFAULT 0;

    
    SET time_zone = '+05:30';

    
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
DELIMITER ;

-- ---------------------------------------------------------------------
-- Original sp_get_payroll_finalization_status (replaced in script.sql, role check C-115..)
-- ---------------------------------------------------------------------
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_get_payroll_finalization_status$$
CREATE PROCEDURE `sp_get_payroll_finalization_status`(
    IN p_month INT,
    IN p_year INT
)
BEGIN

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
DELIMITER ;
