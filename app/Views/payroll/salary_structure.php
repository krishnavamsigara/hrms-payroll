<?php
if (!function_exists('base_url')) {
    function base_url($path = '')
    {
        return site_url($path);
    }
}

if (!function_exists('esc')) {
    function esc($data, $context = 'html')
    {
        return htmlspecialchars((string) $data, ENT_QUOTES, 'UTF-8');
    }
}

// 1. DATA INGESTION FROM CONTROLLER
$salary_data = $salary_structure ?? ($data['salary_structure'] ?? ($data ?? []));

if (is_object($salary_data)) {
    $salary_data = [(array) $salary_data];
} elseif (is_array($salary_data)) {
    if (isset($salary_data['emp_id'])) {
        $salary_data = [$salary_data];
    }
} else {
    $salary_data = [];
}

// 2. DYNAMIC COMPONENT DISCOVERY (CATALOG BUILDER)
$dynEarnings   = [];
$dynEmployer   = [];
$dynDeductions = [];
$employeesMap  = [];

foreach ($salary_data as $row) {
    $rowArr = (array) $row;
    if (!empty($rowArr['salary_components'])) {
        $raw = is_string($rowArr['salary_components'])
            ? json_decode($rowArr['salary_components'], true)
            : $rowArr['salary_components'];

        if (is_array($raw)) {
            foreach ($raw as $c) {
                $cArr    = (array) $c;
                $code    = strtoupper(trim($cArr['component_code'] ?? ''));
                $name    = trim($cArr['component_name'] ?? $code);
                $type    = strtoupper(trim($cArr['component_type'] ?? ''));
                $calc    = strtoupper(trim($cArr['calculation_type'] ?? 'MANUAL'));
                $compId  = $cArr['component_id'] ?? ($cArr['comp_id'] ?? $code);
                $pctBase = $cArr['percentage_base'] ?? 'CTC';
                $formula = $cArr['formula_expression'] ?? '';

                if ($code === '') continue;

                $meta = [
                    'name'               => $name,
                    'calc_type'          => $calc,
                    'component_id'       => $compId,
                    'percentage_base'    => $pctBase,
                    'formula_expression' => $formula
                ];

                if ($type === 'EARNING' && !isset($dynEarnings[$code])) {
                    $dynEarnings[$code] = $meta;
                } elseif (($type === 'EMPLOYER_CONTRIBUTION' || $type === 'STATUTORY') && !isset($dynEmployer[$code])) {
                    $dynEmployer[$code] = $meta;
                } elseif ($type === 'DEDUCTION' && !isset($dynDeductions[$code])) {
                    $dynDeductions[$code] = $meta;
                }
            }
        }
    }
}

$totalDynamicCols = 2 + 3 + (count($dynEarnings) + 1) + count($dynEmployer) + (count($dynDeductions) + 1) + 1 + 4 + 1;
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>BloomHR | Master Salary Structures</title>
    <link rel="icon" type="image/jpeg" href="<?= base_url('public/dist/img/bloom.jpg') ?>">

    <!-- Google Font: Plus Jakarta Sans -->
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">

    <style>
        :root {
            --bloom-purple: #4a00e0;
            --bloom-dark: #120038;
            --bloom-blue: #4a8cff;
            --bloom-orange: #ff7a45;
            --bloom-success: #10b981;
            --bloom-danger: #dc2626;
            --bloom-warning: #f59e0b;
            --soft-gray: #f8fafc;
            --border-color: #e2e8f0;
            --text-dark: #1e293b;
            --text-muted: #64748b;
        }

        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: var(--soft-gray);
            font-size: 13px;
            color: #334155;
        }

        .content-wrapper {
            min-height: calc(100vh - 57px) !important;
            padding-bottom: 40px !important;
            background-color: var(--soft-gray);
        }

        .payroll-page {
            color: #334155;
            padding: 14px 20px 24px;
        }

        .payroll-page * {
            box-sizing: border-box;
        }

        .pc-card {
            background: #fff;
            border: 1px solid var(--border-color) !important;
            border-radius: 16px !important;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.03) !important;
            margin-bottom: 1.25rem;
            overflow: hidden;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }

        .pc-card:hover {
            box-shadow: 0 10px 20px -3px rgba(18, 0, 56, 0.06) !important;
        }

        .pc-body {
            padding: 20px;
        }

        .pc-heading {
            font-size: 22px;
            font-weight: 700;
            color: var(--bloom-dark);
            margin: 0 0 4px;
        }

        .badge-soft-primary {
            background: #eef2ff !important;
            color: var(--bloom-purple) !important;
        }

        .badge-soft-success {
            background: #dcfce7 !important;
            color: #15803d !important;
        }

        .badge-soft-info {
            background: #e0f2fe !important;
            color: #0369a1 !important;
        }

        .badge-soft-danger {
            background: #fee2e2 !important;
            color: #b91c1c !important;
        }

        .pc-btn {
            border: 1px solid var(--border-color);
            border-radius: 9px;
            background: #fff;
            color: var(--text-dark);
            padding: 8px 14px;
            font-size: 12px;
            font-weight: 700;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 7px;
            cursor: pointer;
            text-decoration: none !important;
            transition: all 0.2s ease;
            white-space: nowrap;
        }

        .pc-btn:hover {
            background: #f1f5f9;
            color: var(--bloom-purple);
            border-color: #cbd5e1;
        }

        .pc-btn-primary {
            background: var(--bloom-purple) !important;
            border-color: var(--bloom-purple) !important;
            color: #ffffff !important;
            box-shadow: 0 3px 8px rgba(74, 0, 224, 0.2);
        }

        .pc-btn-primary:hover {
            background: var(--bloom-dark) !important;
            border-color: var(--bloom-dark) !important;
            color: #ffffff !important;
            transform: translateY(-1px);
        }

        .pc-control {
            height: 38px;
            padding: 7px 11px;
            border: 1px solid var(--border-color);
            border-radius: 9px;
            background: #fff;
            color: var(--text-dark);
            font-family: inherit;
            font-size: 12px;
            outline: none;
            transition: border-color 0.2s, box-shadow 0.2s;
        }

        .pc-control:focus {
            border-color: var(--bloom-purple);
            box-shadow: 0 0 0 3px rgba(74, 0, 224, .1);
        }

        /* MASTER GRID & DYNAMIC COLUMN STYLING */
        .master-grid-container {
            position: relative;
            max-height: 620px;
            overflow: auto;
            border-radius: 0 0 16px 16px;
        }

        .table-master {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
            font-size: 13px;
            margin-bottom: 0;
        }

        .table-master thead th {
            position: sticky;
            top: 0;
            z-index: 10;
            background: #f8fafc;
            color: #64748b;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            padding: 10px 14px;
            border-top: none;
            border-bottom: 1px solid #e2e8f0;
            white-space: nowrap;
            vertical-align: middle;
        }

        .table-master thead th .col-category {
            display: block;
            font-size: 9px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: #94a3b8;
            margin-bottom: 2px;
            line-height: 1.1;
        }

        .border-right {
            border-right: 1px solid #e2e8f0 !important;
        }

        .table-master td {
            padding: 12px 14px;
            vertical-align: middle !important;
            border-top: 1px solid #f1f5f9;
            font-size: 13px;
            color: #334155;
            white-space: nowrap;
        }

        .table-master tbody tr:hover td {
            background-color: #f8fafc;
        }

        .table-master .highlight-col {
            background-color: #f0fdf4 !important;
            color: #15803d !important;
            font-weight: 700;
        }

        .cell-currency {
            text-align: right;
            font-variant-numeric: tabular-nums;
            font-weight: 500;
        }

        .cell-bold {
            font-weight: 700;
            color: var(--text-dark);
        }

        /* STICKY FROZEN COLUMNS */
        .freeze-col-id {
            position: sticky !important;
            left: 0 !important;
            z-index: 12 !important;
            background-color: #fff !important;
        }

        .freeze-col-name {
            position: sticky !important;
            left: 95px !important;
            z-index: 12 !important;
            background-color: #fff !important;
            box-shadow: 3px 0 6px -2px rgba(0, 0, 0, 0.08) !important;
        }

        .freeze-col-action {
            position: sticky !important;
            right: 0 !important;
            z-index: 12 !important;
            background-color: #fff !important;
            box-shadow: -3px 0 6px -2px rgba(0, 0, 0, 0.08) !important;
        }

        .table-master thead th.freeze-col-id,
        .table-master thead th.freeze-col-name,
        .table-master thead th.freeze-col-action {
            z-index: 25 !important;
            background-color: #f8fafc !important;
        }

        .table-master tbody tr:hover td.freeze-col-id,
        .table-master tbody tr:hover td.freeze-col-name,
        .table-master tbody tr:hover td.freeze-col-action {
            background-color: #f8faff !important;
        }

        /* DATATABLES TOOLBAR */
        .dataTables_wrapper {
            width: 100% !important;
        }

        .dataTables_wrapper .row:first-child,
        .dataTables_wrapper .row:last-child {
            display: flex;
            justify-content: space-between;
            align-items: center;
            width: 100%;
            margin: 0;
            padding: 14px 20px;
            background: #ffffff;
            border-bottom: 1px solid #f1f5f9;
        }

        .dataTables_wrapper .row:last-child {
            border-bottom: none;
            border-top: 1px solid #f1f5f9;
        }

        .dataTables_length select {
            height: 34px !important;
            min-width: 65px;
            border: 1px solid #e2e8f0 !important;
            border-radius: 10px !important;
            padding: 4px 8px !important;
        }

        .dataTables_filter input {
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 6px 12px;
            margin-left: 5px;
            height: 34px;
        }

        .dataTables_paginate .page-link {
            border-radius: 10px !important;
            border: 1px solid #e2e8f0 !important;
            color: #64748b !important;
            font-weight: 600;
            padding: 6px 12px !important;
            font-size: 12.5px;
        }

        .dataTables_paginate .page-item.active .page-link {
            background: linear-gradient(135deg, #4a00e0 0%, #2a0080 100%) !important;
            border-color: #4a00e0 !important;
            color: #fff !important;
        }

        /* MODAL STYLING */
        .modal-bloom-dialog {
            border: 1px solid var(--border-color);
            border-radius: 18px;
            box-shadow: 0 20px 40px rgba(18, 0, 56, 0.15);
            overflow: hidden;
        }

        .modal-bloom-header {
            background: linear-gradient(135deg, #120038 0%, #2a0080 100%);
            color: #fff;
            padding: 18px 24px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }

        .modal-bloom-footer {
            background: #f8fafc;
            border-top: 1px solid var(--border-color);
            padding: 16px 24px;
        }

        .component-edit-card {
            background: #ffffff;
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 12px;
            transition: all 0.2s ease;
        }

        .component-edit-card:hover {
            border-color: #cbd5e1;
        }

        .preset-chip {
            display: inline-flex;
            align-items: center;
            padding: 4px 10px;
            background: #f1f5f9;
            border: 1px solid #e2e8f0;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 600;
            color: #475569;
            cursor: pointer;
            transition: all 0.15s ease;
        }

        .preset-chip:hover {
            background: #eef2ff;
            color: var(--bloom-purple);
            border-color: var(--bloom-purple);
        }

        .btn-save-cmp {
            width: 36px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            border-top-right-radius: 4px !important;
            border-bottom-right-radius: 4px !important;
            transition: all 0.2s ease;
        }
    </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed">
    <div class="content-wrapper">
        <div class="payroll-page">

            <!-- PAGE HEADER -->
            <div class="pc-card">
                <div class="pc-body">
                    <div class="d-flex align-items-center justify-content-between flex-wrap" style="gap: 12px;">
                        <div>
                            <h1 class="pc-heading">Employee Salary Structures</h1>
                        </div>
                        <div class="d-flex align-items-center" style="gap: 8px;">
                            <a href="<?= base_url('payroll/payroll_dashboard') ?>" class="pc-btn">
                                <i class="fas fa-arrow-left"></i> Dashboard
                            </a>
                            <a href="<?= base_url('payroll/salary_components') ?>" class="pc-btn pc-btn-primary">
                                <i class="fas fa-calculator"></i> Salary Components
                            </a>
                        </div>
                    </div>
                </div>
            </div>

            <!-- NEW JOINERS: active employees without any salary -->
            <?php $withoutSalary = $without_salary ?? []; ?>
            <?php if (!empty($withoutSalary)): ?>
                <div class="pc-card" style="border-color: #fcd34d !important;">
                    <div class="pc-body py-3 d-flex align-items-center justify-content-between flex-wrap" style="gap: 10px; background: #fffbeb;">
                        <div>
                            <span class="badge badge-soft-danger px-3 py-2 font-weight-bold" style="border-radius: 20px;">
                                <i class="fas fa-user-plus mr-1"></i> Employees without a salary (<?= count($withoutSalary) ?>)
                            </span>
                            <div class="text-muted mt-1" style="font-size: 12px;">They are not paid until a salary is added. Every active component is attached automatically.</div>
                        </div>
                    </div>
                    <div class="table-responsive">
                        <table class="table-master mb-0">
                            <thead>
                                <tr>
                                    <th class="pl-3">Emp ID</th><th>Employee</th><th>Department</th><th>Designation</th><th>Joined</th>
                                    <th class="text-right pr-3">Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($withoutSalary as $w): ?>
                                    <tr>
                                        <td class="pl-3 font-weight-bold text-primary"><?= esc($w['emp_id']) ?></td>
                                        <td class="font-weight-bold text-dark"><?= esc($w['emp_name'] ?? '') ?></td>
                                        <td><?= esc($w['department'] ?? '-') ?></td>
                                        <td><?= esc($w['designation'] ?? '-') ?></td>
                                        <td><?= !empty($w['joining_date']) ? esc(date('d M Y', strtotime($w['joining_date']))) : '-' ?></td>
                                        <td class="text-right pr-3">
                                            <a class="pc-btn pc-btn-primary" style="padding: 4px 10px; font-size: 11px;"
                                               href="<?= base_url('payroll/salary_structure/new/' . rawurlencode($w['emp_id'])) ?>">
                                                <i class="fas fa-plus-circle mr-1"></i> Add salary
                                            </a>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            <?php endif; ?>

            <!-- ESI CHECK: current salaries with ESI off although GROSS is within the ESI wage limit -->
            <?php $esiReview = $esi_review ?? []; $esiLimit = (float) ($esi_limit ?? 21000); ?>
            <?php if (!empty($esiReview)): ?>
                <div class="pc-card" style="border-color: #fcd34d !important;">
                    <div class="pc-body py-3 d-flex align-items-center justify-content-between flex-wrap" style="gap: 10px; background: #fffbeb;">
                        <div>
                            <span class="badge badge-soft-warning px-3 py-2 font-weight-bold" style="border-radius: 20px; color: #92400e; background: #fef3c7;">
                                <i class="fas fa-shield-alt mr-1"></i> ESI check (<?= count($esiReview) ?>)
                            </span>
                            <div class="text-muted mt-1" style="font-size: 12px;">
                                ESI is off for these salaries, but their gross is within the ESI wage limit of
                                ₹ <?= number_format($esiLimit, 0) ?>, so no ESI is deducted. Open a salary and switch ESI on if it applies.
                            </div>
                        </div>
                        <button type="button" class="pc-btn" id="esiOnlyBtn" onclick="toggleEsiOnly()">
                            <i class="fas fa-filter mr-1"></i> <span>Show only these</span>
                        </button>
                    </div>
                </div>
            <?php endif; ?>

            <!-- MASTER SALARY STRUCTURE TABLE -->
            <div class="pc-card">
                <div class="pc-body py-3 border-bottom d-flex align-items-center justify-content-between flex-wrap"
                    style="gap: 12px; background: #ffffff;">
                    <div class="d-flex align-items-center flex-wrap" style="gap: 10px;">
                        <span class="badge badge-soft-primary px-3 py-2 font-weight-bold" style="border-radius: 20px;">
                            <i class="fas fa-table-columns mr-1"></i> Master Salary Structures &amp; CTC Breakdown
                        </span>
                        <span class="badge badge-soft-success px-3 py-2 font-weight-bold" style="border-radius: 20px;">
                            <i class="fas fa-check-circle mr-1"></i> <?= count($salary_data) ?> Profiles Configured
                        </span>
                    </div>
                    <div class="d-flex align-items-center" style="gap: 10px;">
                        <button class="pc-btn" type="button" onclick="exportGridCSV()">
                            <i class="fas fa-file-excel text-success mr-1"></i> Export CSV
                        </button>
                    </div>
                </div>

                <div class="master-grid-container">
                    <table class="table-master table-hover mb-0" id="gridTable">
                        <thead>
                            <tr class="table-header">
                                <th class="pl-3 freeze-col-id"><span class="col-category">Identity</span>Emp ID</th>
                                <th class="border-right freeze-col-name"><span class="col-category">Identity</span>Employee Name</th>
                                <th class="cell-currency"><span class="col-category">Attendance</span>Salary (CTC)</th>
                                <th class="cell-currency cell-bold"><span class="col-category" style="color: #4338ca;">Earnings</span>Gross</th>
                                <?php $eCount = 0; foreach ($dynEarnings as $code => $meta): $eCount++; ?>
                                    <th class="cell-currency <?= ($eCount === count($dynEarnings)) ? 'border-right' : '' ?>">
                                        <span class="col-category" style="color: #4338ca;">Earnings</span><?= esc($meta['name']) ?>
                                    </th>
                                <?php endforeach; ?>

                                <?php $erCount = 0; foreach ($dynEmployer as $code => $meta): $erCount++; ?>
                                    <th class="cell-currency <?= ($erCount === count($dynEmployer)) ? 'border-right' : '' ?>">
                                        <span class="col-category" style="color: #0369a1;">Employer</span><?= esc($meta['name']) ?>
                                    </th>
                                <?php endforeach; ?>

                                <?php foreach ($dynDeductions as $code => $meta): ?>
                                    <th class="cell-currency">
                                        <span class="col-category" style="color: #b91c1c;">Deductions</span><?= esc($meta['name']) ?>
                                    </th>
                                <?php endforeach; ?>
                                <th class="cell-currency cell-bold text-danger border-right">
                                    <span class="col-category" style="color: #b91c1c;">Deductions</span>Total Deductions
                                </th>

                                <th class="highlight-col cell-currency text-right pr-3">
                                    <span class="col-category" style="color: #15803d;">Payout</span>Net Pay
                                </th>

                                <!-- <th><span class="col-category">Banking</span>Bank Name</th>
                                <th><span class="col-category">Banking</span>Bank A/c No</th>
                                <th><span class="col-category">Banking</span>IFSC</th>
                                <th class="border-right"><span class="col-category">Banking</span>Mobile No</th> -->

                                <th class="text-center pr-3 no-sort freeze-col-action"><span class="col-category">Action</span>Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (!empty($salary_data) && is_array($salary_data)): ?>
                                <?php foreach ($salary_data as $row): ?>
                                    <?php
                                    $rowArr = (array) $row;
                                    $cmpAmounts = [];
                                    $cmpValues = [];
                                    $cmpMetaMap = [];
                                    $grossSalary = 0.00;
                                    $totalDeductions = 0.00;
                                    $monthlyCtc = isset($rowArr['monthly_ctc']) ? (float) $rowArr['monthly_ctc'] : 0.00;

                                    if (!empty($rowArr['salary_components'])) {
                                        $rawJson = is_string($rowArr['salary_components'])
                                            ? json_decode($rowArr['salary_components'], true)
                                            : $rowArr['salary_components'];

                                        if (is_array($rawJson)) {
                                            foreach ($rawJson as $c) {
                                                $cArr    = (array) $c;
                                                $code    = strtoupper(trim($cArr['component_code'] ?? ''));
                                                $name    = trim($cArr['component_name'] ?? $code);
                                                $amount  = (float) ($cArr['monthly_amount'] ?? ($cArr['amount'] ?? ($cArr['monthly_amt'] ?? ($cArr['comp_amount'] ?? 0.00))));
                                                $val     = (float) ($cArr['component_value'] ?? ($cArr['percentage_value'] ?? ($cArr['percentage'] ?? ($cArr['val'] ?? 0.00))));
                                                $type    = strtoupper(trim($cArr['component_type'] ?? ($cArr['type'] ?? '')));
                                                $calc    = strtoupper(trim($cArr['calculation_type'] ?? ($cArr['calc_type'] ?? 'MANUAL')));
                                                $pctBase = strtoupper(trim($cArr['percentage_base'] ?? ($cArr['based_on'] ?? 'CTC')));
                                                $formula = $cArr['formula_expression'] ?? '';

                                                if ($amount == 0.00 && $val > 0.00) {
                                                    if ($calc === 'PERCENTAGE' && $monthlyCtc > 0) {
                                                        $amount = round($monthlyCtc * ($val / 100), 2);
                                                    } else {
                                                        $amount = $val;
                                                    }
                                                } elseif ($val == 0.00 && $amount > 0.00 && $monthlyCtc > 0.00 && $calc === 'PERCENTAGE') {
                                                    $val = round(($amount / $monthlyCtc) * 100, 1);
                                                }

                                                if ($code !== '') {
                                                    $cmpAmounts[$code] = $amount;
                                                    $cmpValues[$code]  = $val;
                                                    $cmpMetaMap[$code] = [
                                                        'id'                 => $cArr['id'] ?? null,
                                                        'name'               => $name,
                                                        'component_id'       => $cArr['component_id'] ?? ($cArr['comp_id'] ?? $code),
                                                        'calculation_type'   => $calc,
                                                        'percentage_base'    => $pctBase,
                                                        'formula_expression' => $formula
                                                    ];
                                                }

                                                if ($type === 'EARNING') {
                                                    $grossSalary += $amount;
                                                } elseif ($type === 'DEDUCTION') {
                                                    $totalDeductions += $amount;
                                                }
                                            }
                                        }
                                    }

                                    if ($monthlyCtc == 0.00 && $grossSalary > 0.00) {
                                        $monthlyCtc = $grossSalary;
                                    }
                                    $netPay = max(0, $grossSalary - $totalDeductions);

                                    $empId     = $rowArr['emp_id'] ?? 'N/A';
                                    $empName   = $rowArr['emp_name'] ?? 'Unknown';
                                    $bankName  = $rowArr['bank_name'] ?? 'N/A';
                                    $bankAccNo = $rowArr['bank_acc_no'] ?? 'N/A';
                                    $ifsc      = $rowArr['ifsc'] ?? 'N/A';
                                    $mobileNo  = $rowArr['mobile_no'] ?? 'N/A';

                                    $employeesMap[$empId] = [
                                        'emp_id'          => $empId,
                                        'emp_name'        => $empName,
                                        'monthly_ctc'     => $monthlyCtc,
                                        'effective_from'  => $rowArr['effective_from'] ?? date('Y-m-d'),
                                        'amounts'         => $cmpAmounts,
                                        'values'          => $cmpValues,
                                        'components_meta' => $cmpMetaMap
                                    ];
                                    ?>
                                    <?php $esiFlag = isset($esiReview[$empId]); ?>
                                    <tr id="row-<?= esc($empId) ?>" data-esi-review="<?= $esiFlag ? '1' : '0' ?>">
                                        <td class="font-weight-bold text-primary font-monospace pl-3 freeze-col-id">
                                            <?= esc($empId) ?>
                                            <?php if ($esiFlag): ?>
                                                <div><span class="badge" style="background: #fef3c7; color: #92400e; font-size: 10px;" title="ESI is off but gross is within the ESI wage limit">ESI off</span></div>
                                            <?php endif; ?>
                                        </td>
                                        <td class="border-right freeze-col-name">
                                            <div class="font-weight-bold text-dark"><?= esc($empName) ?></div>
                                        </td>

                                        <td class="cell-currency font-weight-bold text-primary col-val-ctc">
                                            ₹ <?= number_format($monthlyCtc, 2) ?>
                                            <?php if (!empty($rowArr['effective_from'])): ?>
                                                <div class="text-muted font-weight-normal" style="font-size: 11px;">from <?= esc(date('d M Y', strtotime($rowArr['effective_from']))) ?></div>
                                            <?php endif; ?>
                                        </td>

                                        <td class="cell-currency cell-bold col-val-gross">
                                            ₹ <?= number_format($grossSalary, 2) ?>
                                        </td>

                                        <?php $eCount = 0; foreach ($dynEarnings as $code => $meta): $eCount++; ?>
                                            <td class="cell-currency <?= ($eCount === count($dynEarnings)) ? 'border-right' : '' ?> col-cmp-<?= esc($code) ?>">
                                                ₹ <?= number_format($cmpAmounts[$code] ?? 0.00, 2) ?>
                                            </td>
                                        <?php endforeach; ?>

                                        <?php $erCount = 0; foreach ($dynEmployer as $code => $meta): $erCount++; ?>
                                            <td class="cell-currency <?= ($erCount === count($dynEmployer)) ? 'border-right' : '' ?> col-cmp-<?= esc($code) ?>">
                                                ₹ <?= number_format($cmpAmounts[$code] ?? 0.00, 2) ?>
                                            </td>
                                        <?php endforeach; ?>

                                        <?php foreach ($dynDeductions as $code => $meta): ?>
                                            <td class="cell-currency col-cmp-<?= esc($code) ?>">
                                                ₹ <?= number_format($cmpAmounts[$code] ?? 0.00, 2) ?>
                                            </td>
                                        <?php endforeach; ?>
                                        <td class="cell-currency cell-bold text-danger border-right col-val-totded">
                                            ₹ <?= number_format($totalDeductions, 2) ?>
                                        </td>

                                        <td class="highlight-col cell-currency text-right pr-3 col-val-net">
                                            ₹ <?= number_format($netPay, 2) ?>
                                        </td>

                                        <!-- <td class="font-weight-bold text-dark"><?= esc($bankName) ?></td>
                                        <td class="font-monospace text-muted"><?= esc($bankAccNo) ?></td>
                                        <td class="font-monospace text-muted"><?= esc($ifsc) ?></td>
                                        <td class="font-monospace text-muted border-right"><?= esc($mobileNo) ?></td> -->

                                        <td class="text-center pr-3 freeze-col-action">
                                            <a class="pc-btn pc-btn-primary" style="padding: 4px 10px; font-size: 11px;"
                                                href="<?= base_url('payroll/salary_structure/edit/' . rawurlencode($empId)) ?>">
                                                <i class="fas fa-edit mr-1"></i> Edit
                                            </a>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            <?php else: ?>
                                <tr>
                                    <td colspan="<?= $totalDynamicCols ?>" class="text-center py-4 text-muted">
                                        <i class="fas fa-folder-open mb-2 text-secondary" style="font-size: 26px; display: block; opacity: 0.6;"></i>
                                        <strong><?= esc($salary_structure['remarks'] ?? 'No active salary structure configurations found.') ?></strong>
                                    </td>
                                </tr>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <!-- TOAST NOTIFICATION CONTAINER -->
    <div id="toastNotification" class="toast-notification" style="display: none; position: fixed; top: 24px; right: 24px; z-index: 99999; min-width: 320px; max-width: 420px; transition: all 0.3s ease;">
        <div class="alert alert-success shadow-lg border-0 d-flex align-items-center mb-0" id="toastAlertBox" style="border-radius: 12px; padding: 14px 18px; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.25);">
            <i class="fas fa-check-circle fa-2x mr-3 text-white" id="toastIcon"></i>
            <div class="mr-3" style="line-height: 1.35;">
                <strong class="d-block text-white" id="toastTitle" style="font-size: 14px;">Notification</strong>
                <small class="text-white-50" id="toastMessage" style="font-size: 12px;">Component updated successfully.</small>
            </div>
            <button type="button" class="close text-white ml-auto p-0" onclick="hideToast()" style="opacity: 0.85; font-size: 20px; line-height: 1; outline: none;">
                <span aria-hidden="true">&times;</span>
            </button>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>

    <script>
        let gridDt = null;
        let activeEmpId = null;
        let employeesData = <?= json_encode($employeesMap ?? [], JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) ?>;
        const dynEarnings = <?= json_encode($dynEarnings ?? []) ?>;
        const dynEmployer = <?= json_encode($dynEmployer ?? []) ?>;
        const dynDeductions = <?= json_encode($dynDeductions ?? []) ?>;

        let initialFieldValues = {};
        let initialCtcValue = 0;
        let initialEffectiveDate = '';

        function showToast(title, message, type = 'success') {
            const toast = document.getElementById('toastNotification');
            const alertBox = document.getElementById('toastAlertBox');
            const icon = document.getElementById('toastIcon');
            const titleElem = document.getElementById('toastTitle');
            const msgElem = document.getElementById('toastMessage');

            if (!toast || !alertBox) return;

            titleElem.textContent = title;
            msgElem.textContent = message;

            if (type === 'success') {
                alertBox.className = 'alert alert-success shadow-lg border-0 d-flex align-items-center mb-0';
                icon.className = 'fas fa-check-circle fa-2x mr-3 text-white';
            } else if (type === 'danger' || type === 'error') {
                alertBox.className = 'alert alert-danger shadow-lg border-0 d-flex align-items-center mb-0';
                icon.className = 'fas fa-times-circle fa-2x mr-3 text-white';
            } else if (type === 'warning') {
                alertBox.className = 'alert alert-warning shadow-lg border-0 d-flex align-items-center mb-0';
                icon.className = 'fas fa-exclamation-triangle fa-2x mr-3 text-white';
            } else {
                alertBox.className = 'alert alert-info shadow-lg border-0 d-flex align-items-center mb-0';
                icon.className = 'fas fa-info-circle fa-2x mr-3 text-white';
            }

            toast.style.display = 'block';
            toast.style.opacity = '1';

            if (window.toastTimeout) clearTimeout(window.toastTimeout);
            window.toastTimeout = setTimeout(() => {
                hideToast();
            }, 4500);
        }

        function hideToast() {
            const toast = document.getElementById('toastNotification');
            if (toast) {
                toast.style.opacity = '0';
                setTimeout(() => { toast.style.display = 'none'; }, 300);
            }
        }

        jQuery.extend(jQuery.fn.dataTableExt.oSort, {
            "currency-pre": function (a) {
                if (!a) return 0;
                var clean = a.replace(/<[^>]*>/g, '').replace(/[^\d\.\-]/g, '').trim();
                return clean === '' ? 0 : parseFloat(clean);
            },
            "currency-asc": function (a, b) {
                return a - b;
            },
            "currency-desc": function (a, b) {
                return b - a;
            }
        });

        // ESI check filter: show only the rows flagged by hrms_salary_esi_review
        var esiOnly = false;
        $.fn.dataTable.ext.search.push(function (settings, data, idx) {
            if (!esiOnly || settings.nTable.id !== 'gridTable') return true;
            var tr = settings.aoData[idx].nTr;
            return tr && tr.getAttribute('data-esi-review') === '1';
        });
        function toggleEsiOnly() {
            esiOnly = !esiOnly;
            $('#esiOnlyBtn span').text(esiOnly ? 'Show all' : 'Show only these');
            $('#esiOnlyBtn').toggleClass('pc-btn-primary', esiOnly);
            if (gridDt) gridDt.draw();
        }

        $(document).ready(function () {
            gridDt = $('#gridTable').DataTable({
                paging: true,
                ordering: true,
                order: [],
                searching: true,
                info: true,
                lengthChange: true,
                pageLength: 10,
                lengthMenu: [[5, 10, 25, 50, -1], [5, 10, 25, 50, "All"]],
                dom: "<'row'<'col-md-6'l><'col-md-6'f>>" +
                     "<'master-grid-container'tr>" +
                     "<'row'<'col-md-6'i><'col-md-6'p>>",
                columnDefs: [
                    { type: 'currency', targets: 'cell-currency' },
                    { orderable: false, targets: 'no-sort' }
                ]
            });

            <?php if (function_exists('session') && session()->getFlashdata('success')): ?>
                showToast('Success', '<?= esc(session()->getFlashdata('success'), 'js') ?>', 'success');
            <?php elseif (function_exists('session') && session()->getFlashdata('error')): ?>
                showToast('Error', '<?= esc(session()->getFlashdata('error'), 'js') ?>', 'danger');
            <?php endif; ?>
        });

        function syncEmployeeRowInGrid(empId) {
            const emp = employeesData[empId];
            const rowElem = document.getElementById('row-' + empId);
            if (!emp || !rowElem) return;

            const fmt = v => '₹ ' + Number(v).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

            const ctcCell = rowElem.querySelector('.col-val-ctc');
            if (ctcCell) ctcCell.innerText = fmt(emp.monthly_ctc);

            let updatedGross = 0;
            let updatedDeductions = 0;

            Object.keys(emp.amounts).forEach(k => {
                const amt = emp.amounts[k] || 0;
                const cell = rowElem.querySelector('.col-cmp-' + k);
                if (cell) cell.innerText = fmt(amt);

                if (dynEarnings[k]) updatedGross += amt;
                if (dynDeductions[k]) updatedDeductions += amt;
            });

            const grossCell = rowElem.querySelector('.col-val-gross');
            if (grossCell) grossCell.innerText = fmt(updatedGross);

            const dedCell = rowElem.querySelector('.col-val-totded');
            if (dedCell) dedCell.innerText = fmt(updatedDeductions);

            const netCell = rowElem.querySelector('.col-val-net');
            if (netCell) netCell.innerText = fmt(Math.max(0, updatedGross - updatedDeductions));

            if (gridDt) {
                gridDt.row(rowElem).invalidate().draw(false);
            }
        }

        function roundTo2(num) {
            return Math.round((num + Number.EPSILON) * 100) / 100;
        }

        function exportGridCSV() {
            let csv = [];
            const rows = document.querySelectorAll('#gridTable tr');

            rows.forEach(row => {
                let cols = row.querySelectorAll('td, th');
                let rowData = [];
                cols.forEach((col, idx) => {
                    if (idx < cols.length - 1) {
                        let text = col.innerText.replace(/(\r\n|\n|\r)/gm, ' ').replace(/,/g, '');
                        rowData.push('"' + text.trim() + '"');
                    }
                });
                if (rowData.length > 0) {
                    csv.push(rowData.join(','));
                }
            });

            const csvFile = new Blob([csv.join('\n')], { type: 'text/csv' });
            const downloadLink = document.createElement('a');
            downloadLink.download = 'Master_Salary_Structures.csv';
            downloadLink.href = window.URL.createObjectURL(csvFile);
            downloadLink.style.display = 'none';
            document.body.appendChild(downloadLink);
            downloadLink.click();
            document.body.removeChild(downloadLink);
        }
    </script>
</body>
</html>