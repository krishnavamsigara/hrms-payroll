<?php

namespace App\Models;

use App\Models\OnboardingModel; //Onbarding Model
use App\Models\ManagerModel; //ManagerModel
use CodeIgniter\Model;

class AdminModel extends Model
{

    protected $db;

    public function __construct()
    {
        parent::__construct();
        $this->db = \Config\Database::connect();
    }

    // Common Procedure Caller

    protected function callProcedure(
        string $procedureName,
        array $params = [],
        bool $isQuery = true
    ) {
        $placeholders = implode(',', array_fill(0, count($params), '?'));

        $sql = "CALL {$procedureName}({$placeholders})";

        $query = $this->db->query($sql, $params);

        if ($isQuery) {
            return $query->getResultArray();
        }

        return $this->db->affectedRows() > 0;
    }

    // Create Candidate

    public function createCandidate($candidate_type, $emp_name, $email, $mobile, $experience, $offerletter, $created_by)
    {
        return $this->callProcedure(
            'hr_create_candidate',
            [
                $candidate_type,
                $emp_name,
                $email,
                $mobile,
                $experience,
                $offerletter,
                $created_by
            ]
        );
    }

    public function getcandidate($hr,$onboarding_status,$offer_status ,$candidate_type)
    {
        return $this->callProcedure('get_candidate_list', [$hr,$onboarding_status,$offer_status ,$candidate_type]);
    }

    public function getmgr($emp_id, $null)
    {
        return $this->callProcedure('get_user_drop_down', [$emp_id, $null]);
    }

    public function updatecand($refid, $jsonData)
    {
        return $this->callProcedure('save_candidate_details', [$refid, $jsonData]);
    }

    public function finalsubmit($refid,$empid)
    {
        return $this->callProcedure('hr_approve_candidate', [$refid ,$empid]);
    }

    public function getholidaylist()
    {
        return $this->callProcedure('hr_get_holiday_master', []);
    
    }
   
    public function get_announcement($empid)
    {
        return $this->callProcedure('hr_announcement_get', [$empid]);
    
    }

    public function get_attendance_finalized($month, $year, $emp_id = null)
    {
        // who is calling is checked inside the procedure (active ADMIN or HR)
        return $this->callProcedure('sp_get_payroll_finalization_status', [$emp_id ?? session()->get('emp_id'), $month, $year]);
    
    }

    // Finalize or unfinalize the payroll attendance of a month (one procedure, C-136).
    // $action: FINALIZE (default) or UNFINALIZE.
    public function get_finalized($emp_id, $month, $year, $action = 'FINALIZE')
    {
        $rows = $this->callProcedure('finalize_payroll_attendance_proc', [$emp_id, $month, $year, $action]);
        (new SalaryModel())->payroll_audit_denied('finalize_payroll_attendance_proc', $rows);   // payroll audit trail
        return $rows;
    }

    
    public function save_announcement($mode,$announcement_id,$title,$message,$user_category, $status,$empid)
    {
    return $this->callProcedure(
        'hr_announcement_save',
        [
            $mode,
            $announcement_id,
            $title,
            $message,
            $user_category,
            $status,
            $empid
        ],false );
    }

    public function get_leave_balance($empid,$user_category,$month,$year)
    {
        return $this->callProcedure('get_employee_leave_summary', [$empid,$user_category,$month,$year]);
    
    }

    public function get_month_details($empid,$user_category,$month,$year)
    {
        return $this->callProcedure('hr_get_leave_detailed_report', [$empid,$user_category,$month,$year]);
    }

    public function update_user_details($emp_id, $jsonData)
    {
    return $this->callProcedure('hrms_update_user_details', [$emp_id, $jsonData]);
    }

    public function get_adm_dash($emp_id, $user_category)
    {
    return $this->callProcedure('get_admin_dashboard', [$emp_id, $user_category]);
    }

    public function get_departments()
    {
    return $this->callProcedure('hr_get_departments', []);
    }

    public function get_birthday()
    {
    return $this->callProcedure('hr_get_upcoming_birthdays', []);
    }
    
    public function toggle_user_status($admin_emp_id, $admin_category, $target_emp_id)
    {
    return $this->callProcedure(
        'hr_toggle_user_status',
        [$admin_emp_id, $admin_category, $target_emp_id] );
    }

    public function add_new_employee($emp_id, $jsonData)
    {
    return $this->callProcedure('hr_add_new_employee', [$emp_id, $jsonData]);
    }

    public function get_attendence_to_admin($emp_id, $day, $month, $year)
    {  
    return $this->callProcedure('get_attendence_today_admin', [$emp_id, $day, $month, $year]);
    }

    public function get_attendence_everyday($emp_id, $day, $month, $year, $user_category)
    {  
    return $this->callProcedure('get_attendence_admin_every_day', [$emp_id, $day, $month, $year, $user_category]);
    }
    
    public function get_monthly_report($emp_id,$month, $year, $user_category)
    {  
    return $this->callProcedure('get_attendence_monthly_report',[$emp_id,$month, $year,$user_category]);
    }

    //07-10
    
    public function get_attendance_overview(string $emp_id,int $month,int $year,string $searchParam): array {
    $sql = "CALL get_attendance_overview_data(?, ?, ?, ?)";
    return $this->db->query(
        $sql,
        [$emp_id, $month, $year, $searchParam]
    )->getResultArray();
    }
  

    /**
     * Generate Payroll Attendance Summary for a specific month and year
     *
     * @param int $month
     * @param int $year
     * @param string $admin_emp_id
     * @return array
     */
  
public function generate_payroll_attendance(int $month, int $year, string $admin_emp_id): array
{
    try {
        // The stored procedure expects exactly 3 arguments.
        $sql = "CALL sp_generate_payroll_attendance(?, ?, ?)";

        $query = $this->db->query($sql, [
            $month,
            $year,
            $admin_emp_id
        ]);

        if ($query === false) {
            $error = $this->db->error();

            log_message(
                'error',
                'Payroll attendance procedure error: ' . json_encode($error)
            );

            return [
                'status'  => 'N',
                'message' => 'Database procedure failed. Check the application log.'
            ];
        }

        // The procedure answers with one row: status Y/N and message (it used to be ignored,
        // so a refused or failed run was reported as generated).
        $row = $query->getRowArray() ?? [];
        $query->freeResult();
        if ($this->db->connID instanceof \mysqli) {
            try {
                while (@mysqli_more_results($this->db->connID) && @mysqli_next_result($this->db->connID)) {
                }
            } catch (\Throwable $ex) {
            }
        }
        (new SalaryModel())->payroll_audit_denied('sp_generate_payroll_attendance', [$row]);   // payroll audit trail

        return [
            'status'  => strtoupper((string) ($row['status'] ?? 'N')) === 'Y' ? 'Y' : 'N',
            'message' => $row['message'] ?? $row['remarks'] ?? 'No response received from the payroll attendance procedure.'
        ];

    } catch (\Throwable $e) {
        log_message(
            'error',
            'Payroll attendance model error: ' . $e->getMessage()
        );

        return [
            'status'  => 'N',
            'message' => 'Unable to generate payroll attendance.'
        ];
    }
}


    /**
     * Admin edit of an ABSENT attendance record.
     * Supports WFH (with punch timings), PL/SL/CL (with balance deduction + leave_application),
     * or LOP (forced Loss of Pay).
     *
     * @param string      $emp_id
     * @param string      $att_date       Y-m-d
     * @param string      $edit_type      WFH | PL | SL | CL | LOP
     * @param string|null $punch_in       Y-m-d H:i:s  (required for WFH)
     * @param string|null $punch_out      Y-m-d H:i:s  (required for WFH)
     * @param string      $admin_emp_id
     * @return array ['status' => 'Y'|'N', 'message' => '...']
     */
    public function admin_edit_absent_attendance(
        string  $emp_id,
        string  $att_date,
        string  $edit_type,
        ?string $punch_in,
        ?string $punch_out,
        string  $admin_emp_id
    ): array {
        $pi = $punch_in  ?? 'NULL';
        $po = $punch_out ?? 'NULL';

        // Use session variables for OUT parameters (MySQL stored proc OUT params)
        $this->db->query("SET @p_status = '', @p_message = ''");

        $sql = "CALL sp_admin_edit_absent_attendance(?, ?, ?, ?, ?, ?, @p_status, @p_message)";
        $this->db->query($sql, [
            $emp_id,
            $att_date,
            strtoupper($edit_type),
            $admin_emp_id,
            $punch_in,
            $punch_out
        ]);

        $row = $this->db->query("SELECT @p_status AS status, @p_message AS message")->getRowArray();
        (new SalaryModel())->payroll_audit_denied('sp_admin_edit_absent_attendance', [$row ?? []]);   // payroll audit trail

        return [
            'status'  => $row['status']  ?? 'N',
            'message' => $row['message'] ?? 'Unknown error'
        ];
    }

     public function get_payroll_attendance_data(int $month, int $year, string $emp_id): array
    {
        $sql = "CALL get_payroll_attendance_data_proc(?, ?, ?)";
        return $this->db->query($sql, [$emp_id, $month, $year])->getResultArray();
    }



    // finalize_payroll_attendance() removed: it finalized a month with a raw UPDATE and no role check.
    // The finalize page uses get_finalized() -> finalize_payroll_attendance_proc (active ADMIN or HR only).

    public function save_department($mode, $department_id, $department_name, $status)
    {
        return $this->callProcedure(
            'sp_department_cud',
            [$mode, $department_id, $department_name, $status]
        );
    }

    public function get_designations()
    {
        return $this->callProcedure('hr_get_designations', []);
    }

    public function save_designation($mode, $designation_id, $designation_name, $status)
    {
        return $this->callProcedure(
            'sp_designation_cud',
            [$mode, $designation_id, $designation_name, $status]
        );
    }

     public function save_holiday($mode, $holiday_id, $holiday_date, $holiday_name, $holiday_type, $applicable_for, $status)
    {
        return $this->callProcedure(
            'sp_holiday_cud',
            [$mode, $holiday_id, $holiday_date, $holiday_name, $holiday_type, $applicable_for, $status]
        );
    }

    public function get_Attendance_cycle($year, $emp_id = null)
    {
        // who is calling is checked inside the procedure (active ADMIN or HR)
        return $this->callProcedure('sp_get_payroll_cycle_status', [$emp_id ?? session()->get('emp_id'), $year]);
    }

        public function get_Attendance_graph($emp_id,$month)
    {
        return $this->callProcedure('get_attendance_monthly_chart', [$emp_id,$month]);
    }


    public function get_settings(): array
    {
        try {
            $query = $this->db->query("CALL sp_get_company_settings()");
            $row = $query ? $query->getRowArray() : null;

            // Drain extra result sets left by stored proc
            if ($this->db->connID instanceof \mysqli) {
                try {
                    while (@mysqli_more_results($this->db->connID) && @mysqli_next_result($this->db->connID)) {
                        // drain
                    }
                } catch (\Throwable $ex) {
                    // suppress
                }
            }

            if ($row) {
                return $row;
            }
        } catch (\Throwable $e) {
            log_message('error', 'sp_get_company_settings error: ' . $e->getMessage());
        }

        // Default fallback values
        return [
            'id'                          => 1,
            'company_name'                => 'Bloom Solutions',
            'brand_title_primary'         => 'Bloom',
            'brand_title_secondary'       => 'Solutions',
            'company_address'             => 'H No. 6-2-981, Flat No. 501, 5th Floor, Maruthi Plaza, Khairatabad - 500004, Hyderabad, Telangana.',
            'city'                        => 'Hyderabad',
            'state'                       => 'Telangana',
            'pincode'                     => '500004',
            'country'                     => 'India',
            'email'                       => 'hr@bloomsolutions.com',
            'phone'                       => '+91 40 1234 5678',
            'website'                     => 'https://bloomsolutions.com',
            'logo_url'                    => 'public/dist/img/bloom.jpg',
            'watermark_url'               => 'public/dist/img/bloom.jpg',
            'payroll_cycle_start_day'     => 25,
            'payroll_cycle_end_day'       => 24,
            'salary_pay_day'              => 1,
            'standard_work_hours_per_day' => 9.00,
            'pan_number'                  => '',
            'tan_number'                  => '',
            'gstin'                       => '',
            'pf_establishment_code'       => '',
            'esic_code'                   => '',
            'cin'                         => '',
            'payslip_prefix'              => 'PS-',
            'payslip_signatory_title'     => 'Authorized Signatory',
            'payslip_footer_disclaimer'   => 'This is a computer-generated statement, and does not require a signature and stamp.',
        ];
    }




    public function save_settings(array $data, string $actor = 'ADMIN'): array
    {
        try {
            $this->db->query("SET @p_status = '', @p_message = ''");

            $sql = "CALL sp_save_company_settings(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, @p_status, @p_message)";
            $this->db->query($sql, [
                $data['company_name']            ?? 'Bloom Solutions',
                $data['brand_title_primary']     ?? 'Bloom',
                $data['brand_title_secondary']   ?? 'Solutions',
                $data['company_address']         ?? '',
                $data['city']                    ?? '',
                $data['state']                   ?? '',
                $data['pincode']                 ?? '',
                $data['country']                 ?? 'India',
                $data['email']                   ?? '',
                $data['phone']                   ?? '',
                $data['website']                 ?? '',
                $data['logo_url']                ?? null,
                $data['watermark_url']           ?? null,
                (int)($data['payroll_cycle_start_day'] ?? 25),
                (int)($data['payroll_cycle_end_day']   ?? 24),
                (int)($data['salary_pay_day']          ?? 1),
                (float)($data['standard_work_hours_per_day'] ?? 9.00),
                $data['pan_number']              ?? '',
                $data['tan_number']              ?? '',
                $data['gstin']                   ?? '',
                $data['pf_establishment_code']   ?? '',
                $data['esic_code']               ?? '',
                $data['cin']                     ?? '',
                $data['payslip_prefix']          ?? 'PS-',
                $data['payslip_signatory_title'] ?? 'Authorized Signatory',
                $data['payslip_footer_disclaimer'] ?? 'This is a computer-generated statement, and does not require a signature and stamp.',
                $actor
            ]);

            // Drain extra result sets left by stored proc
            if ($this->db->connID instanceof \mysqli) {
                try {
                    while (@mysqli_more_results($this->db->connID) && @mysqli_next_result($this->db->connID)) {
                        // drain
                    }
                } catch (\Throwable $ex) {
                    // suppress
                }
            }

            $res = $this->db->query("SELECT @p_status AS status, @p_message AS message")->getRowArray();
            return [
                'status'  => $res['status'] ?? 'Y',
                'message' => $res['message'] ?? 'Settings saved successfully.'
            ];
        } catch (\Throwable $e) {
            log_message('error', 'sp_save_company_settings error: ' . $e->getMessage());
            return [
                'status'  => 'N',
                'message' => 'Failed to save company settings: ' . $e->getMessage()
            ];
        }
    }

    /**
     * Get Company Settings (camelCase alias)
     */
    public function getSettings(): array
    {
        return $this->get_settings();
    }

    /**
     * Save Company Settings (camelCase alias)
     */
    public function saveSettings(array $data, string $actor = 'ADMIN'): array
    {
        return $this->save_settings($data, $actor);
    }


}

