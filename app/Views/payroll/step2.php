
<?php
/*
|--------------------------------------------------------------------------
| URL helper fallback
|--------------------------------------------------------------------------
*/
if (!function_exists('base_url')) {
    function base_url($path = '')
    {
        $map = [
            'payroll/payroll_dashboard' => 'payroll_dashboard.php',
            'payroll/payslips'          => 'payslips.php',
            'payroll/salary_components' => 'salary_components.php',
            'payroll/salary_structure'  => 'salary_structure.php',
            'payroll/step1'             => 'step1.php',
            'payroll/step2'             => 'step2.php',
            'payroll/step3'             => 'step3.php',
            'payroll/step4'             => 'step4.php',
        ];

        if (function_exists('site_url')) {
            return site_url($path);
        }

        return $map[$path] ?? $path;
    }
}

/*
|--------------------------------------------------------------------------
| Escaping fallback
|--------------------------------------------------------------------------
*/
if (!function_exists('esc')) {
    function esc($data, $context = 'html')
    {
        return htmlspecialchars((string) $data, ENT_QUOTES, 'UTF-8');
    }
}

/*
|--------------------------------------------------------------------------
| Selected payroll period
|--------------------------------------------------------------------------
*/
$selectedMonth = (int) (
    $selectedMonth
    ?? $_GET['month']
    ?? date('m')
);

$selectedYear = (int) (
    $selectedYear
    ?? $_GET['year']
    ?? date('Y')
);

if ($selectedMonth < 1 || $selectedMonth > 12) {
    $selectedMonth = (int) date('m');
}

if ($selectedYear < 2000 || $selectedYear > 2100) {
    $selectedYear = (int) date('Y');
}

$monthName = date(
    'F',
    mktime(0, 0, 0, $selectedMonth, 1)
);

$periodStart = sprintf(
    '%04d-%02d-01',
    $selectedYear,
    $selectedMonth
);

$periodEnd = date(
    'Y-m-t',
    strtotime($periodStart)
);

/*
|--------------------------------------------------------------------------
| Salary data from controller
|--------------------------------------------------------------------------
| No sample or demo employees are inserted.
*/
$salary_data = $salary_structure ?? [];

if (is_object($salary_data)) {
    $salary_data = [(array) $salary_data];
} elseif (is_array($salary_data)) {
    if (isset($salary_data['emp_id'])) {
        $salary_data = [$salary_data];
    }
} else {
    $salary_data = [];
}

$salary_data = array_values(
    array_filter(
        array_map(
            static function ($row) {
                return is_object($row) ? (array) $row : $row;
            },
            $salary_data
        ),
        static function ($row) {
            return is_array($row);
        }
    )
);

/*
|--------------------------------------------------------------------------
| Dynamic component discovery
|--------------------------------------------------------------------------
*/
$dynEarnings  = [];
$dynEmployer  = [];
$dynDeductions = [];

foreach ($salary_data as $row) {
    if (empty($row['salary_components'])) {
        continue;
    }

    $raw = is_string($row['salary_components'])
        ? json_decode($row['salary_components'], true)
        : $row['salary_components'];

    if (!is_array($raw)) {
        continue;
    }

    foreach ($raw as $component) {
        $component = (array) $component;

        $code = strtoupper(
            trim($component['component_code'] ?? '')
        );

        $name = trim(
            $component['component_name'] ?? $code
        );

        $type = strtoupper(
            trim($component['component_type'] ?? '')
        );

        $calc = strtoupper(
            trim($component['calculation_type'] ?? 'MANUAL')
        );

        $componentId = $component['component_id']
            ?? ($component['comp_id'] ?? $code);

        if ($code === '') {
            continue;
        }

        $meta = [
            'name'               => $name,
            'calc_type'          => $calc,
            'component_id'       => $componentId,
            'percentage_base'    => $component['percentage_base'] ?? 'CTC',
            'formula_expression' => $component['formula_expression'] ?? '',
        ];

        if (
            $type === 'EARNING'
            && !isset($dynEarnings[$code])
        ) {
            $dynEarnings[$code] = $meta;
        } elseif (
            in_array($type, ['EMPLOYER_CONTRIBUTION', 'STATUTORY'], true)
            && !isset($dynEmployer[$code])
        ) {
            $dynEmployer[$code] = $meta;
        } elseif (
            $type === 'DEDUCTION'
            && !isset($dynDeductions[$code])
        ) {
            $dynDeductions[$code] = $meta;
        }
    }
}

$totalDynamicCols =
    2
    + 2
    + count($dynEarnings)
    + count($dynEmployer)
    + count($dynDeductions)
    + 1
    + 1;
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <title>BloomHR | Step 2: Salary Structure &amp; Pre-Calculation Review</title>

    <link rel="icon"
          type="image/jpeg"
          href="<?= base_url('public/dist/img/bloom.jpg') ?>">

    <link rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">

    <link rel="stylesheet"
          href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">

    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">

    <link rel="stylesheet"
          href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">

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
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, .03) !important;
            margin-bottom: 1.25rem;
            overflow: hidden;
            transition: transform .2s ease, box-shadow .2s ease;
        }

        .pc-card:hover {
            box-shadow: 0 10px 20px -3px rgba(18, 0, 56, .06) !important;
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

        .pc-title {
            font-size: 16px;
            font-weight: 700;
            color: var(--bloom-dark);
            margin: 0;
        }

        .pc-muted {
            font-size: 12px;
            color: var(--text-muted);
            margin-bottom: 0;
        }

        .pc-label {
            font-size: 10px;
            text-transform: uppercase;
            letter-spacing: .06em;
            color: var(--text-muted);
            font-weight: 700;
        }

        .pc-top,
        .pc-flex,
        .pc-actions {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
        }

        .pc-top {
            align-items: flex-start;
            margin-bottom: 18px;
        }

        .pc-actions {
            justify-content: flex-start;
        }

        .pc-meta {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            gap: 8px;
            margin-bottom: 10px;
        }

        .pc-stepper {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 16px;
            position: relative;
        }

        .pc-step {
            display: flex;
            flex-direction: column;
            gap: 4px;
            position: relative;
        }

        .pc-step-top {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 6px;
        }

        .pc-step-number {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 13px;
            font-weight: 700;
            background: #f1f5f9;
            color: #64748b;
            border: 2px solid #e2e8f0;
            flex-shrink: 0;
        }

        .pc-step.completed .pc-step-number {
            background: #10b981;
            color: #fff;
            border-color: #10b981;
        }

        .pc-step.active .pc-step-number {
            background: var(--bloom-purple);
            color: #fff;
            border-color: var(--bloom-purple);
            box-shadow: 0 0 0 4px rgba(74, 0, 224, .15);
        }

        .pc-step-line {
            flex-grow: 1;
            height: 2px;
            background: #e2e8f0;
        }

        .pc-step.completed .pc-step-line {
            background: #10b981;
        }

        .pc-step-title {
            font-size: 13px;
            font-weight: 700;
            color: var(--text-dark);
            margin: 0;
        }

        .pc-step.active .pc-step-title {
            color: var(--bloom-purple);
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

        .badge-soft-warning {
            background: #fef3c7 !important;
            color: #b45309 !important;
        }

        .pc-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 5px 11px;
            border-radius: 30px;
            font-size: 11px;
            font-weight: 700;
            white-space: nowrap;
        }

        .pc-purple {
            background: #eef2ff !important;
            color: var(--bloom-purple) !important;
        }

        .pc-green {
            background: #dcfce7 !important;
            color: #15803d !important;
        }

        .pc-yellow {
            background: #fef3c7 !important;
            color: #b45309 !important;
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
            transition: all .2s ease;
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
            color: #fff !important;
            box-shadow: 0 3px 8px rgba(74, 0, 224, .2);
        }

        .pc-btn-primary:hover {
            background: var(--bloom-dark) !important;
            border-color: var(--bloom-dark) !important;
            color: #fff !important;
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
            transition: border-color .2s, box-shadow .2s;
        }

        .pc-control:focus {
            border-color: var(--bloom-purple);
            box-shadow: 0 0 0 3px rgba(74, 0, 224, .1);
        }

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
            letter-spacing: .5px;
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
            letter-spacing: .5px;
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
            box-shadow: 3px 0 6px -2px rgba(0, 0, 0, .08) !important;
        }

        .table-master thead th.freeze-col-id,
        .table-master thead th.freeze-col-name {
            z-index: 25 !important;
            background-color: #f8fafc !important;
        }

        .table-master tbody tr:hover td.freeze-col-id,
        .table-master tbody tr:hover td.freeze-col-name {
            background-color: #f8faff !important;
        }

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
            background: #fff;
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
            background: var(--bloom-purple) !important;
            border-color: var(--bloom-purple) !important;
            color: #fff !important;
        }

        .pc-bottom-bar {
            position: static !important;
            width: 100% !important;
            min-height: 70px !important;
            padding: 16px 24px !important;
            background: #fff !important;
            border: 1px solid var(--border-color) !important;
            border-radius: 16px !important;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, .03) !important;
            margin-top: 1.5rem !important;
            margin-bottom: .5rem !important;
            display: flex !important;
            align-items: center !important;
            justify-content: space-between !important;
            gap: 12px;
            flex-wrap: wrap;
        }

        .pc-bottom-bar:hover {
            box-shadow: 0 10px 20px -3px rgba(18, 0, 56, .06) !important;
        }

        .empty-state {
            padding: 45px 20px !important;
            color: var(--text-muted) !important;
            white-space: normal !important;
            text-align: center;
        }

        .empty-state i {
            display: block;
            font-size: 30px;
            margin-bottom: 12px;
            color: #94a3b8;
        }

        @media (max-width: 991.98px) {
            .pc-stepper {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        @media (max-width: 767.98px) {
            .pc-stepper {
                grid-template-columns: 1fr;
            }

            .payroll-page {
                padding: 10px;
            }

            .pc-bottom-bar {
                padding: 12px 16px !important;
                flex-direction: column;
                align-items: stretch;
            }

            .pc-bottom-bar > div {
                justify-content: flex-start;
            }
        }
    </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed">

<div class="wrapper">

    <div class="content-wrapper">
        <section class="content pt-3">
            <div class="container-fluid px-2 px-md-3">

                <div class="payroll-page">

                    <!-- TOP BAR -->
                    <div class="pc-top">
                        <div>
                            <div class="pc-meta">
                                <span class="pc-badge pc-purple">
                                    <i class="fas fa-fingerprint"></i>
                                    Payroll Cycle
                                </span>

                                <span class="pc-badge pc-yellow">
                                    Draft · <?= esc($monthName . ' ' . $selectedYear) ?>
                                </span>

                                <!-- <span class="pc-muted">
                                    Cycle Unit: Mumbai Regional HQ
                                </span> -->
                            </div>

                            <h1 class="pc-heading">
                                Step 2: Salary Structure &amp; Pre-Calculation Review
                            </h1>

                            <p class="pc-muted">
                                Period:
                                <?= esc(date('d M Y', strtotime($periodStart))) ?>
                                –
                                <?= esc(date('d M Y', strtotime($periodEnd))) ?>
                                · Review CTC component mapping &amp; pre-statutory numbers
                            </p>
                        </div>

                        <div class="pc-actions">
                            <a href="<?= base_url('payroll/salary_structure') ?>"
                               class="pc-btn"
                               id="btnStructureMaster">
                                <i class="fas fa-sitemap text-primary"></i>
                                CTC Master Bands
                            </a>

                            <button type="button"
                                    class="pc-btn pc-btn-primary"
                                    id="saveDraftBtn">
                                <i class="far fa-bookmark"></i>
                                Save Draft
                            </button>
                        </div>
                    </div>

                    <!-- WORKFLOW STEPPER -->
                    <div class="pc-card">
                        <div class="pc-body">
                            <div class="pc-stepper">

                                <div class="pc-step completed">
                                    <div class="pc-step-top">
                                        <span class="pc-step-number">
                                            <i class="fas fa-check"></i>
                                        </span>
                                        <span class="pc-step-line"></span>
                                    </div>
                                    <span class="pc-label" style="color:#10b981;">
                                        Step 01 · Verified
                                    </span>
                                    <p class="pc-step-title">
                                        Attendance Verification &amp; Ingestion
                                    </p>
                                    <p class="pc-muted">
                                        Gate sync &amp; biometric locked
                                    </p>
                                </div>

                                <div class="pc-step active">
                                    <div class="pc-step-top">
                                        <span class="pc-step-number">2</span>
                                        <span class="pc-step-line"></span>
                                    </div>
                                    <span class="pc-label" style="color:#4a00e0;">
                                        Step 02 · Active
                                    </span>
                                    <p class="pc-step-title">
                                        Salary Structure &amp; Pre-Calculation
                                    </p>
                                    <p class="pc-muted">
                                        CTC splits, allowances &amp; perks
                                    </p>
                                </div>

                                <div class="pc-step">
                                    <div class="pc-step-top">
                                        <span class="pc-step-number">3</span>
                                        <span class="pc-step-line"></span>
                                    </div>
                                    <span class="pc-label">Step 03 · Queued</span>
                                    <p class="pc-step-title">
                                        Master Calculation Grid
                                    </p>
                                    <p class="pc-muted">
                                        Statutory deductions, TDS &amp; Gross-to-Net
                                    </p>
                                </div>

                                <div class="pc-step">
                                    <div class="pc-step-top">
                                        <span class="pc-step-number">4</span>
                                    </div>
                                    <span class="pc-label">Step 04 · Queued</span>
                                    <p class="pc-step-title">
                                        Final Summary &amp; Cycle Completion
                                    </p>
                                    <p class="pc-muted">
                                        Bank NACH output &amp; payslip dispatch
                                    </p>
                                </div>

                            </div>
                        </div>
                    </div>

                    <!-- PERIOD FILTER -->
                    <div class="pc-card">
                        <div class="pc-body py-3">
                            <div class="pc-flex">

                                <div class="pc-actions">
                                    <strong>
                                        <i class="far fa-calendar-alt text-primary mr-1"></i>
                                        Payroll Cycle Period:
                                    </strong>

                                    <select id="selectMonth" class="pc-control">
                                        <?php for ($m = 1; $m <= 12; $m++): ?>
                                            <option value="<?= $m ?>"
                                                <?= $selectedMonth === $m ? 'selected' : '' ?>>
                                                <?= esc(date('F', mktime(0, 0, 0, $m, 1))) ?>
                                            </option>
                                        <?php endfor; ?>
                                    </select>

                                    <select id="selectYear" class="pc-control">
                                        <?php
                                        $startYear = max(2020, $selectedYear - 5);
                                        $endYear = min(
                                            2100,
                                            max((int) date('Y'), $selectedYear) + 1
                                        );

                                        for ($y = $startYear; $y <= $endYear; $y++):
                                        ?>
                                            <option value="<?= $y ?>"
                                                <?= $selectedYear === $y ? 'selected' : '' ?>>
                                                <?= $y ?>
                                            </option>
                                        <?php endfor; ?>
                                    </select>

                                    <button type="button"
                                            id="applyPayrollFilter"
                                            class="pc-btn pc-btn-primary">
                                        Apply Filter
                                    </button>
                                </div>

                                <div>
                                    <span class="pc-badge pc-purple">
                                        <i class="fas fa-calendar-check mr-1"></i>
                                        Cycle · <?= esc($monthName . ' ' . $selectedYear) ?>
                                    </span>
                                </div>

                            </div>
                        </div>
                    </div>

                    <!-- SALARY STRUCTURE TABLE -->
                    <div class="pc-card">

                        <div class="pc-body py-3 border-bottom d-flex align-items-center justify-content-between flex-wrap"
                             style="gap:12px;background:#fff;">

                            <div class="d-flex align-items-center flex-wrap" style="gap:10px;">
                                <span class="badge badge-soft-primary px-3 py-2 font-weight-bold"
                                      style="border-radius:20px;">
                                    <i class="fas fa-table-columns mr-1"></i>
                                    Master Salary Structures &amp; CTC Breakdown
                                </span>

                                <span class="badge badge-soft-success px-3 py-2 font-weight-bold"
                                      style="border-radius:20px;">
                                    <i class="fas fa-check-circle mr-1"></i>
                                    <?= count($salary_data) ?> Profiles Configured
                                </span>
                            </div>

                            <div class="d-flex align-items-center" style="gap:10px;">
                                <button class="pc-btn"
                                        type="button"
                                        onclick="exportGridCSV()">
                                    <i class="fas fa-file-csv text-success mr-1"></i>
                                    Export CSV
                                </button>
                            </div>

                        </div>

                        <div class="master-grid-container">
                            <table class="table-master table-hover mb-0" id="gridTable">

                                <thead>
                                    <tr>
                                        <th class="pl-3 freeze-col-id">
                                            <span class="col-category">Identity</span>
                                            Emp ID
                                        </th>

                                        <th class="border-right freeze-col-name">
                                            <span class="col-category">Identity</span>
                                            Employee Name
                                        </th>

                                        <th class="cell-currency">
                                            <span class="col-category">Attendance</span>
                                            Salary (CTC)
                                        </th>

                                        <th class="cell-currency cell-bold">
                                            <span class="col-category" style="color:#4338ca;">
                                                Earnings
                                            </span>
                                            Gross
                                        </th>

                                        <?php $eCount = 0; ?>
                                        <?php foreach ($dynEarnings as $code => $meta): ?>
                                            <?php $eCount++; ?>
                                            <th class="cell-currency <?= $eCount === count($dynEarnings) ? 'border-right' : '' ?>">
                                                <span class="col-category" style="color:#4338ca;">
                                                    Earnings
                                                </span>
                                                <?= esc($meta['name']) ?>
                                            </th>
                                        <?php endforeach; ?>

                                        <?php $erCount = 0; ?>
                                        <?php foreach ($dynEmployer as $code => $meta): ?>
                                            <?php $erCount++; ?>
                                            <th class="cell-currency <?= $erCount === count($dynEmployer) ? 'border-right' : '' ?>">
                                                <span class="col-category" style="color:#0369a1;">
                                                    Employer
                                                </span>
                                                <?= esc($meta['name']) ?>
                                            </th>
                                        <?php endforeach; ?>

                                        <?php foreach ($dynDeductions as $code => $meta): ?>
                                            <th class="cell-currency">
                                                <span class="col-category" style="color:#b91c1c;">
                                                    Deductions
                                                </span>
                                                <?= esc($meta['name']) ?>
                                            </th>
                                        <?php endforeach; ?>

                                        <th class="cell-currency cell-bold text-danger border-right">
                                            <span class="col-category" style="color:#b91c1c;">
                                                Deductions
                                            </span>
                                            Total Deductions
                                        </th>

                                        <th class="highlight-col cell-currency text-right pr-3">
                                            <span class="col-category" style="color:#15803d;">
                                                Payout
                                            </span>
                                            Net Pay
                                        </th>
                                    </tr>
                                </thead>

                                <tbody>
                                    <?php if (!empty($salary_data)): ?>

                                        <?php foreach ($salary_data as $row): ?>
                                            <?php
                                            $cmpAmounts = [];
                                            $grossSalary = 0.00;
                                            $totalDeductions = 0.00;

                                            $monthlyCtc = (float) (
                                                $row['monthly_ctc'] ?? 0
                                            );

                                            $rawJson = $row['salary_components'] ?? [];

                                            if (is_string($rawJson)) {
                                                $rawJson = json_decode($rawJson, true);
                                            }

                                            if (is_array($rawJson)) {
                                                foreach ($rawJson as $component) {
                                                    $component = (array) $component;

                                                    $code = strtoupper(
                                                        trim($component['component_code'] ?? '')
                                                    );

                                                    $amount = (float) (
                                                        $component['monthly_amount']
                                                        ?? $component['amount']
                                                        ?? $component['monthly_amt']
                                                        ?? $component['comp_amount']
                                                        ?? 0
                                                    );

                                                    $value = (float) (
                                                        $component['component_value']
                                                        ?? $component['percentage_value']
                                                        ?? $component['percentage']
                                                        ?? $component['val']
                                                        ?? 0
                                                    );

                                                    $type = strtoupper(
                                                        trim(
                                                            $component['component_type']
                                                            ?? $component['type']
                                                            ?? ''
                                                        )
                                                    );

                                                    $calc = strtoupper(
                                                        trim(
                                                            $component['calculation_type']
                                                            ?? $component['calc_type']
                                                            ?? 'MANUAL'
                                                        )
                                                    );

                                                    if (
                                                        $amount == 0.00
                                                        && $value > 0
                                                        && $calc === 'PERCENTAGE'
                                                        && $monthlyCtc > 0
                                                    ) {
                                                        $amount = round(
                                                            $monthlyCtc * ($value / 100),
                                                            2
                                                        );
                                                    } elseif (
                                                        $amount == 0.00
                                                        && $value > 0
                                                        && $calc !== 'PERCENTAGE'
                                                    ) {
                                                        $amount = $value;
                                                    }

                                                    if ($code !== '') {
                                                        $cmpAmounts[$code] = $amount;
                                                    }

                                                    if ($type === 'EARNING') {
                                                        $grossSalary += $amount;
                                                    } elseif ($type === 'DEDUCTION') {
                                                        $totalDeductions += $amount;
                                                    }
                                                }
                                            }

                                            if ($monthlyCtc == 0 && $grossSalary > 0) {
                                                $monthlyCtc = $grossSalary;
                                            }

                                            $netPay = max(
                                                0,
                                                $grossSalary - $totalDeductions
                                            );

                                            $empId = $row['emp_id'] ?? 'N/A';
                                            $empName = $row['emp_name'] ?? 'Unknown';
                                            ?>

                                            <tr>
                                                <td class="font-weight-bold text-primary pl-3 freeze-col-id">
                                                    <?= esc($empId) ?>
                                                </td>

                                                <td class="border-right freeze-col-name">
                                                    <div class="font-weight-bold text-dark">
                                                        <?= esc($empName) ?>
                                                    </div>
                                                </td>

                                                <td class="cell-currency font-weight-bold text-primary">
                                                    ₹ <?= number_format($monthlyCtc, 2) ?>
                                                </td>

                                                <td class="cell-currency cell-bold">
                                                    ₹ <?= number_format($grossSalary, 2) ?>
                                                </td>

                                                <?php $eCount = 0; ?>
                                                <?php foreach ($dynEarnings as $code => $meta): ?>
                                                    <?php $eCount++; ?>
                                                    <td class="cell-currency <?= $eCount === count($dynEarnings) ? 'border-right' : '' ?>">
                                                        ₹ <?= number_format($cmpAmounts[$code] ?? 0, 2) ?>
                                                    </td>
                                                <?php endforeach; ?>

                                                <?php $erCount = 0; ?>
                                                <?php foreach ($dynEmployer as $code => $meta): ?>
                                                    <?php $erCount++; ?>
                                                    <td class="cell-currency <?= $erCount === count($dynEmployer) ? 'border-right' : '' ?>">
                                                        ₹ <?= number_format($cmpAmounts[$code] ?? 0, 2) ?>
                                                    </td>
                                                <?php endforeach; ?>

                                                <?php foreach ($dynDeductions as $code => $meta): ?>
                                                    <td class="cell-currency">
                                                        ₹ <?= number_format($cmpAmounts[$code] ?? 0, 2) ?>
                                                    </td>
                                                <?php endforeach; ?>

                                                <td class="cell-currency cell-bold text-danger border-right">
                                                    ₹ <?= number_format($totalDeductions, 2) ?>
                                                </td>

                                                <td class="highlight-col cell-currency text-right pr-3">
                                                    ₹ <?= number_format($netPay, 2) ?>
                                                </td>
                                            </tr>

                                        <?php endforeach; ?>

                                    <?php else: ?>

                                        <tr>
                                            <td colspan="<?= $totalDynamicCols ?>"
                                                class="empty-state">
                                                <i class="fas fa-folder-open"></i>
                                                <strong>No salary structure records found.</strong>
                                                <div class="mt-2">
                                                    No employee salary data was returned by the controller.
                                                    Configure salary structures or verify the model response.
                                                </div>
                                            </td>
                                        </tr>

                                    <?php endif; ?>
                                </tbody>

                            </table>
                        </div>
                    </div>

                    <!-- BOTTOM NAVIGATION -->
                    <div class="pc-bottom-bar">

                        <div class="d-flex align-items-center flex-wrap" style="gap:10px;">

                            <a href="<?= base_url('payroll/step1') ?>?month=<?= $selectedMonth ?>&amp;year=<?= $selectedYear ?>"
                               class="pc-btn">
                                <i class="fas fa-arrow-left mr-1"></i>
                                Back: Step 1 Attendance
                            </a>

                            <a href="<?= base_url('payroll/payroll_dashboard') ?>?month=<?= $selectedMonth ?>&amp;year=<?= $selectedYear ?>"
                               class="pc-btn">
                                <i class="fas fa-th-large mr-1"></i>
                                Dashboard
                            </a>

                        </div>

                        <div class="d-flex align-items-center flex-wrap" style="gap:10px;">

                            <button type="button"
                                    class="pc-btn"
                                    onclick="exportGridCSV()">
                                <i class="fas fa-file-csv text-success mr-1"></i>
                                Export CSV
                            </button>

                            <a href="<?= base_url('payroll/step3') ?>?month=<?= $selectedMonth ?>&amp;year=<?= $selectedYear ?>"
                               class="pc-btn pc-btn-primary">
                                Next: Step 3 Master Grid
                                <i class="fas fa-arrow-right ml-1"></i>
                            </a>

                        </div>
                    </div>

                </div>
            </div>
        </section>
    </div>
</div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>

<script>
    let gridDt = null;

    // Custom sorting for formatted currency values.
    jQuery.extend(jQuery.fn.dataTableExt.oSort, {
        "currency-pre": function (value) {
            if (!value) {
                return 0;
            }

            const clean = value
                .replace(/<[^>]*>/g, '')
                .replace(/[^\d.-]/g, '')
                .trim();

            return clean === '' ? 0 : parseFloat(clean);
        },

        "currency-asc": function (a, b) {
            return a - b;
        },

        "currency-desc": function (a, b) {
            return b - a;
        }
    });

    $(document).ready(function () {
        gridDt = $('#gridTable').DataTable({
            paging: true,
            ordering: true,
            order: [],
            searching: true,
            info: true,
            lengthChange: true,
            pageLength: 10,
            lengthMenu: [
                [5, 10, 25, 50, -1],
                [5, 10, 25, 50, "All"]
            ],
            dom:
                "<'row'<'col-md-6'l><'col-md-6'f>>" +
                "tr" +
                "<'row'<'col-md-6'i><'col-md-6'p>>",
            columnDefs: [
                {
                    targets: 'cell-currency',
                    type: 'currency'
                }
            ],
            language: {
                paginate: {
                    previous: "Previous",
                    next: "Next"
                },
                emptyTable: "No salary structure records found."
            }
        });
    });

    // Apply selected payroll month and year.
    document.getElementById('applyPayrollFilter')
        .addEventListener('click', function () {

            const month = document.getElementById('selectMonth').value;
            const year = document.getElementById('selectYear').value;

            const url = new URL(window.location.href);

            url.searchParams.set('month', month);
            url.searchParams.set('year', year);

            window.location.href = url.toString();
        });

    // Save Draft feedback only; persistence requires a backend endpoint.
    const saveDraftButton = document.getElementById('saveDraftBtn');

    if (saveDraftButton) {
        saveDraftButton.addEventListener('click', function () {
            alert(
                'The Save Draft interface is available, but no backend save action is connected yet.'
            );
        });
    }

    // Export all currently rendered table rows to CSV.
    function exportGridCSV() {
        const table = document.getElementById('gridTable');
        const rows = table.querySelectorAll('thead tr, tbody tr');
        const csv = [];

        rows.forEach(function (row) {
            const cells = row.querySelectorAll('th, td');
            const rowData = [];

            cells.forEach(function (cell) {
                const value = cell.innerText
                    .replace(/(\r\n|\n|\r)/gm, ' ')
                    .trim()
                    .replace(/"/g, '""');

                rowData.push('"' + value + '"');
            });

            csv.push(rowData.join(','));
        });

        const blob = new Blob(
            [csv.join('\r\n')],
            { type: 'text/csv;charset=utf-8;' }
        );

        const downloadLink = document.createElement('a');
        const objectUrl = URL.createObjectURL(blob);

        downloadLink.href = objectUrl;
        downloadLink.download =
            'Step2_Salary_Structures_<?= $selectedYear ?>_<?= sprintf('%02d', $selectedMonth) ?>.csv';

        document.body.appendChild(downloadLink);
        downloadLink.click();
        document.body.removeChild(downloadLink);

        URL.revokeObjectURL(objectUrl);
    }
</script>

</body>
</html>
