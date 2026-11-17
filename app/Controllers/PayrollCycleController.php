<?php

namespace App\Controllers;

use App\Models\PayrollCycleModel;

/**
 * Payroll cycle page: one page that walks a cycle through
 * attendance -> salary structures -> calculation -> approval -> finalize ->
 * payment -> payslips -> close, with holds. Every rule is enforced by the
 * hrms_payroll_* procedures; this controller only passes data through.
 */
class PayrollCycleController extends BaseController
{
    private function loggedIn(): bool
    {
        return (bool) session()->get('logged_in');
    }

    private function me(): string
    {
        return (string) session()->get('emp_id');
    }

    private function denied()
    {
        return $this->response->setJSON([
            'status'  => false,
            'message' => 'Session expired. Please log in again.',
        ])->setStatusCode(401);
    }

    /** First row of a procedure result, or [] */
    private function first($rows): array
    {
        return (is_array($rows) && isset($rows[0]) && is_array($rows[0])) ? $rows[0] : [];
    }

    private function ok(array $row): bool
    {
        return strtoupper(trim((string) ($row['status'] ?? 'N'))) === 'Y';
    }

    /** Rows of a list procedure without its status columns; [] when the call was refused. */
    private function rows($rows, string $key): array
    {
        $first = $this->first($rows);
        if (!$this->ok($first)) {
            return [];
        }
        $out = [];
        foreach ($rows as $r) {
            if (!isset($r[$key]) || $r[$key] === null || $r[$key] === '') {
                continue;
            }
            unset($r['status'], $r['remarks']);
            $out[] = $r;
        }
        return $out;
    }

    private function json(array $row, array $extra = [])
    {
        return $this->response->setJSON(array_merge([
            'status'     => $this->ok($row),
            'message'    => $row['remarks'] ?? ($this->ok($row) ? 'Done.' : 'The request could not be completed.'),
            'data'       => $row,
            'csrf_token' => csrf_hash(),
        ], $extra));
    }

    # GET payroll/cycle/{id}
    public function view($cycleId = null)
    {
        if (!$this->loggedIn()) {
            return redirect()->to(base_url('/'));
        }
        $cycleId = (int) $cycleId;
        $model = new PayrollCycleModel();
        $cycle = $this->first($model->cycle_get($this->me(), $cycleId));
        if (!$this->ok($cycle)) {
            return redirect()->to(base_url('payroll/payroll_dashboard'))
                ->with('error', $cycle['remarks'] ?? 'Payroll cycle not found.');
        }

        return view('Layouts/Header')
            . view('Layouts/Sidebar')
            . view('payroll/cycle_run', [
                'cycleId'          => $cycleId,
                'cycle'            => $cycle,
                'manualComponents' => $model->manual_components(),
            ])
            . view('Layouts/Footer');
    }

    # GET payroll/cycle_data/{id} : everything the page shows, as JSON
    public function data($cycleId = null)
    {
        if (!$this->loggedIn()) {
            return $this->denied();
        }
        $cycleId = (int) $cycleId;
        $model = new PayrollCycleModel();
        $cycle = $this->first($model->cycle_get($this->me(), $cycleId));
        if (!$this->ok($cycle)) {
            return $this->json($cycle);
        }

        return $this->response->setJSON([
            'status'     => true,
            'cycle'      => $cycle,
            'readiness'  => $this->rows($model->cycle_readiness($this->me(), $cycleId), 'emp_id'),
            'attendance' => $model->attendance_summary($this->me(), (int) $cycle['payroll_month'], (int) $cycle['payroll_year']),
            'employees'  => $this->rows($model->cycle_employees($this->me(), $cycleId), 'payroll_detail_id'),
            'inputs'     => $this->rows($model->manual_inputs($this->me(), $cycle['payroll_month'], $cycle['payroll_year']), 'input_id'),
            'log'        => $this->rows($model->cycle_log($this->me(), $cycleId), 'log_id'),
            'csrf_token' => csrf_hash(),
        ]);
    }

    # GET payroll/cycle_breakdown/{id} : salary breakdown table of the salary structures step
    public function breakdown($cycleId = null)
    {
        if (!$this->loggedIn()) {
            return $this->denied();
        }
        $model = new PayrollCycleModel();
        $rows  = $model->cycle_breakdown($this->me(), (int) $cycleId);
        $first = $this->first($rows);
        if (!$this->ok($first)) {
            return $this->json($first);
        }

        // compact: columns once, then one entry per employee with amount per component code
        $columns = [];
        $emps = [];
        foreach ($rows as $r) {
            $id = $r['emp_id'];
            if (!isset($emps[$id])) {
                $emps[$id] = [
                    'emp_id'       => $id,
                    'emp_name'     => $r['emp_name'],
                    'structure_id' => $r['structure_id'],
                    'from'         => $r['effective_from'],
                    'to'           => $r['effective_to'],
                    'ctc'          => (float) $r['monthly_ctc'],
                    'a'            => [],   // amounts by code
                    'own'          => [],   // employee's own setting by code (text)
                ];
            }
            $code = $r['component_code'];
            if ($code === null || $code === '') {
                continue;
            }
            if (!isset($columns[$code])) {
                $columns[$code] = [
                    'code'  => $code,
                    'name'  => $r['component_name'],
                    'type'  => $r['component_type'],
                    'scope' => $r['calculation_scope'],
                    'order' => (int) $r['calculation_order'],
                ];
            }
            $emps[$id]['a'][$code] = (float) $r['monthly_amount'];
            if ((int) $r['is_overridden'] === 1) {
                $t = strtoupper((string) $r['own_calculation_type']);
                $emps[$id]['own'][$code] = $t === 'PERCENTAGE' ? ((float) $r['own_value']) . '% of ' . $r['own_base']
                    : ($t === 'FORMULA' ? '= ' . $r['own_formula']
                    : ($t === 'MANUAL' ? 'Manual ' . number_format((float) $r['own_value'], 2) : 'Fixed ' . number_format((float) $r['own_value'], 2)));
            }
        }
        $columns = array_values($columns);
        usort($columns, fn($x, $y) => $x['order'] <=> $y['order']);

        return $this->response->setJSON([
            'status'     => true,
            'columns'    => $columns,
            'employees'  => array_values($emps),
            'csrf_token' => csrf_hash(),
        ]);
    }

    # GET payroll/cycle_defaults?month=&year=
    public function defaults()
    {
        if (!$this->loggedIn()) {
            return $this->denied();
        }
        $model = new PayrollCycleModel();
        return $this->json($this->first($model->cycle_defaults(
            session()->get('emp_id'),
            (int) $this->request->getGet('month'),
            (int) $this->request->getGet('year')
        )));
    }

    # POST payroll/cycle_create (form on the payroll dashboard)
    public function create()
    {
        if (!$this->loggedIn()) {
            return $this->request->isAJAX() ? $this->denied() : redirect()->to(base_url('/'));
        }
        $p = fn($k) => trim((string) ($this->request->getPost($k) ?? ''));
        $model = new PayrollCycleModel();
        $row = $this->first($model->cycle_create(
            $this->me(),
            (int) $p('month'),
            (int) $p('year'),
            $p('cycle_code'),
            $p('from_date') ?: null,
            $p('to_date') ?: null,
            $p('pay_date') ?: null,
            $p('remarks') ?: null
        ));

        if ($this->request->isAJAX()) {
            return $this->json($row);
        }
        if ($this->ok($row) && !empty($row['payroll_cycle_id'])) {
            return redirect()->to(base_url('payroll/cycle/' . (int) $row['payroll_cycle_id']))->with('success', $row['remarks']);
        }
        return redirect()->to(base_url('payroll/payroll_dashboard'))
            ->with('error', $row['remarks'] ?? 'Payroll cycle could not be created.');
    }

    # POST payroll/cycle_delete {cycle_id, reason}
    public function delete()
    {
        if (!$this->loggedIn()) {
            return $this->denied();
        }
        $model = new PayrollCycleModel();
        return $this->json($this->first($model->cycle_delete(
            $this->me(),
            (int) $this->request->getPost('cycle_id'),
            trim((string) ($this->request->getPost('reason') ?? ''))
        )), ['redirect' => base_url('payroll/payroll_dashboard')]);
    }

    # POST payroll/cycle_action {cycle_id, action, remarks}
    public function action()
    {
        if (!$this->loggedIn()) {
            return $this->denied();
        }
        $model = new PayrollCycleModel();
        return $this->json($this->first($model->cycle_action(
            $this->me(),
            (int) $this->request->getPost('cycle_id'),
            strtoupper(trim((string) $this->request->getPost('action'))),
            trim((string) ($this->request->getPost('remarks') ?? '')) ?: null
        )));
    }

    # POST payroll/cycle_calculate_employee {cycle_id, payroll_detail_id}
    public function calculateEmployee()
    {
        if (!$this->loggedIn()) {
            return $this->denied();
        }
        $model = new PayrollCycleModel();
        return $this->json($this->first($model->calculate_employee(
            $this->me(),
            (int) $this->request->getPost('cycle_id'),
            (int) $this->request->getPost('payroll_detail_id')
        )));
    }

    # POST payroll/cycle_hold {payroll_detail_id, action HOLD|RELEASE, reason}
    public function hold()
    {
        if (!$this->loggedIn()) {
            return $this->denied();
        }
        $model = new PayrollCycleModel();
        return $this->json($this->first($model->employee_hold(
            $this->me(),
            (int) $this->request->getPost('payroll_detail_id'),
            strtoupper(trim((string) $this->request->getPost('action'))),
            trim((string) ($this->request->getPost('reason') ?? ''))
        )));
    }

    # POST payroll/cycle_pay_employee {payroll_detail_id, remarks}
    public function payEmployee()
    {
        if (!$this->loggedIn()) {
            return $this->denied();
        }
        $model = new PayrollCycleModel();
        return $this->json($this->first($model->employee_pay(
            $this->me(),
            (int) $this->request->getPost('payroll_detail_id'),
            trim((string) ($this->request->getPost('remarks') ?? '')) ?: null
        )));
    }

    # POST payroll/cycle_manual_input {cycle_id, emp_id, component_id, amount, remarks}
    public function manualInput()
    {
        if (!$this->loggedIn()) {
            return $this->denied();
        }
        $model = new PayrollCycleModel();
        $cycle = $this->first($model->cycle_get($this->me(), (int) $this->request->getPost('cycle_id')));
        if (!$this->ok($cycle)) {
            return $this->json($cycle);
        }
        $amount = $this->request->getPost('amount');
        return $this->json($this->first($model->save_manual_input(
            $this->me(),
            strtoupper(trim((string) $this->request->getPost('emp_id'))),
            (int) $cycle['payroll_month'],
            (int) $cycle['payroll_year'],
            (int) $this->request->getPost('component_id'),
            ($amount === null || $amount === '') ? null : $amount,
            trim((string) ($this->request->getPost('remarks') ?? '')) ?: null
        )));
    }

    /** Cycle id for a month/year, or null (used to send the old step pages here). */
    public static function cycleIdFor($month, $year): ?int
    {
        return (new PayrollCycleModel())->cycle_id_for($month, $year);
    }
}
