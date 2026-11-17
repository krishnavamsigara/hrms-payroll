<?php

namespace App\Models;

/**
 * Payroll cycle: create, step through the statuses, calculate employees one
 * by one, hold / release / pay employees. All rules live in the hrms_payroll_*
 * stored procedures; every call returns rows that start with status (Y/N)
 * and remarks.
 */
class PayrollCycleModel extends SalaryModel
{
    public function cycle_list($emp_id, $year)
    {
        return $this->callProcedureRows('hrms_payroll_cycle_list', [$emp_id, $year]);
    }

    public function cycle_defaults($emp_id, $month, $year)
    {
        return $this->callProcedureRows('hrms_payroll_cycle_defaults', [$emp_id, $month, $year]);
    }

    public function cycle_create($emp_id, $month, $year, $code, $start, $end, $pay_date, $remarks)
    {
        return $this->callProcedureRows('hrms_payroll_cycle_create', [$emp_id, $month, $year, $code, $start, $end, $pay_date, $remarks]);
    }

    /** Full-month salary breakdown of every employee for the cycle's pay period (long format). */
    public function cycle_breakdown($emp_id, $cycle_id)
    {
        return $this->callProcedureRows('hrms_payroll_cycle_breakdown', [$emp_id, $cycle_id]);
    }

    public function cycle_delete($emp_id, $cycle_id, $reason)
    {
        return $this->callProcedureRows('hrms_payroll_cycle_delete', [$emp_id, $cycle_id, $reason]);
    }

    /** The cycle that is still in progress (any status except CLOSED), or [] */
    public function active_cycle($emp_id): array
    {
        foreach ($this->cycle_list($emp_id, null) as $row) {
            if (!empty($row['payroll_cycle_id']) && strtoupper((string) $row['cycle_status']) !== 'CLOSED') {
                return $row;
            }
        }
        return [];
    }

    /** Newest cycle id of a payroll month, or null when the month has no cycle (Q-001). */
    public function cycle_id_for($month, $year): ?int
    {
        $rows = $this->callProcedureRows('hrms_payroll_cycle_id_for', [(int) $month, (int) $year]);
        return !empty($rows[0]['id']) ? (int) $rows[0]['id'] : null;
    }

    /** Statuses in which a cycle may be deleted (the procedure checks again). */
    public const DELETABLE = ['OPEN', 'ATTENDANCE_VERIFIED', 'STRUCTURE_VERIFIED', 'PROCESSING', 'CALCULATED', 'APPROVED'];

    public function cycle_get($emp_id, $cycle_id)
    {
        return $this->callProcedureRows('hrms_payroll_cycle_get', [$emp_id, $cycle_id]);
    }

    public function cycle_readiness($emp_id, $cycle_id)
    {
        return $this->callProcedureRows('hrms_payroll_cycle_readiness', [$emp_id, $cycle_id]);
    }

    /** payroll_attendance_summary of the month, from the existing get_payroll_attendance_data_proc */
    public function attendance_summary($emp_id, $month, $year): array
    {
        $rows = $this->callProcedureRows('get_payroll_attendance_data_proc', [$emp_id, $month, $year]);
        $out = [];
        foreach ($rows as $r) {
            if (isset($r['emp_id']) && !isset($r['error_msg'])) {
                $out[] = $r;
            }
        }
        return $out;
    }

    public function cycle_employees($emp_id, $cycle_id, $filter = null)
    {
        return $this->callProcedureRows('hrms_payroll_cycle_employees', [$emp_id, $cycle_id, $filter]);
    }

    public function cycle_log($emp_id, $cycle_id)
    {
        return $this->callProcedureRows('hrms_payroll_cycle_log_list', [$emp_id, $cycle_id]);
    }

    public function cycle_action($emp_id, $cycle_id, $action, $remarks = null)
    {
        return $this->callProcedureRows('hrms_payroll_cycle_action', [$emp_id, $cycle_id, $action, $remarks]);
    }

    public function calculate_employee($emp_id, $cycle_id, $detail_id)
    {
        return $this->callProcedureRows('hrms_payroll_calculate_employee', [$emp_id, $cycle_id, $detail_id]);
    }

    public function employee_hold($emp_id, $detail_id, $action, $reason)
    {
        return $this->callProcedureRows('hrms_payroll_employee_hold', [$emp_id, $detail_id, $action, $reason]);
    }

    public function employee_pay($emp_id, $detail_id, $remarks)
    {
        return $this->callProcedureRows('hrms_payroll_employee_pay', [$emp_id, $detail_id, $remarks]);
    }

    public function manual_inputs($emp_id, $month, $year)
    {
        return $this->callProcedureRows('hrms_payroll_manual_inputs_list', [$emp_id, $month, $year]);
    }

    public function save_manual_input($emp_id, $target_emp_id, $month, $year, $component_id, $amount, $remarks)
    {
        return $this->callProcedureRows('hrms_save_payroll_manual_input', [$emp_id, $target_emp_id, $month, $year, $component_id, $amount, $remarks]);
    }

    /** Active manual components (TDS, ADVANCE, OTHER_EARNINGS ...) for the manual amount form. */
    public function manual_components(): array
    {
        return $this->db->query(
            "SELECT component_id, component_code, component_name, component_type
               FROM salary_component_master
              WHERE is_active = 1 AND calculation_scope = 'COMPONENT' AND (is_manual = 1 OR calculation_type = 'MANUAL')
              ORDER BY calculation_order, component_id"
        )->getResultArray();
    }
}
