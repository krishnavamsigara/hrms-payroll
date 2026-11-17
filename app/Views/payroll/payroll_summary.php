<?php

$month = filter_input(INPUT_GET, 'month', FILTER_VALIDATE_INT);
$year  = filter_input(INPUT_GET, 'year', FILTER_VALIDATE_INT);

if (
    $month === false || $month === null ||
    $year === false || $year === null ||
    $month < 1 || $month > 12 ||
    $year < 2020 || $year > 2100
) {
    http_response_code(400);
    exit('Invalid or missing payroll month/year.');
}

$monthName = date('F', mktime(0, 0, 0, $month, 1, $year));

?>
<?php
if (!function_exists('esc')) {
    function esc($data, $context = 'html')
    {
        return htmlspecialchars((string) $data, ENT_QUOTES, 'UTF-8');
    }
}

// 1. DATA INGESTION FROM CONTROLLER step3()
// The controller passes the stored-procedure result as payroll_month_details.
$payroll_data = [];
foreach (['payroll_month_details', 'payroll_data', 'payroll_records', 'payroll_details'] as $sourceName) {
    if (isset($$sourceName) && is_array($$sourceName) && !empty($$sourceName)) {
        $payroll_data = $$sourceName;
        break;
    }
}

if (is_object($payroll_data)) {
    $payroll_data = [(array) $payroll_data];
} elseif (!is_array($payroll_data)) {
    $payroll_data = [];
}

// A single associative employee row is normalized to a list of rows.
if (isset($payroll_data['emp_id']) || isset($payroll_data['employee_id']) || isset($payroll_data['employee_code'])) {
    $payroll_data = [$payroll_data];
} elseif (isset($payroll_data[0]) && is_object($payroll_data[0])) {
    $payroll_data = array_map(static fn($row) => (array) $row, $payroll_data);
}

// Keep only employee payroll rows. Procedure status/remarks-only rows are not employees.
$payroll_data = array_values(array_filter($payroll_data, static function ($row) {
    return is_array($row) && !empty($row['emp_id'] ?? $row['employee_id'] ?? $row['employee_code'] ?? '');
}));

// 2. DYNAMIC COMPONENT DISCOVERY (CATALOG BUILDER)
// Exactly like salary_structure.php catalog discovery
$dynEarnings = [];
$dynEmployer = [];
$dynDeductions = [];
$employeesMap = [];

$hasPayrollRows = !empty($payroll_data);
$firstRow = $hasPayrollRows ? (array) $payroll_data[0] : [];
$payrollCycleId = $firstRow['payroll_cycle_id'] ?? ''; 
$payrollMonth = $firstRow['payroll_month'] ?? ($selectedMonth ?? date('n')); 
$payrollMonthName = $firstRow['month_name'] ?? date('F', mktime(0, 0, 0, (int) $payrollMonth, 1));
$payrollYear = $firstRow['payroll_year'] ?? ($selectedYear ?? date('Y')); 
$periodStart = $firstRow['period_start'] ?? ''; 
$periodEnd = $firstRow['period_end'] ?? ''; 
$paymentDate = $firstRow['payment_date'] ?? ''; 
$payrollCycleStatus = strtoupper(trim((string) ($firstRow['payroll_cycle_status'] ?? ''))); 
$requesterEmpId = $sessionId ?? ''; 

// Scan and categorize unique components
foreach ($payroll_data as $row) {
    $rowArr = (array) $row;
    $componentSource = $rowArr['salary_components'] ?? $rowArr['salary_component_details'] ?? $rowArr['components_json'] ?? null;
    if (!empty($componentSource)) {
        $raw = is_string($componentSource)
            ? json_decode($componentSource, true)
            : $componentSource;

        if (is_array($raw)) {
            foreach ($raw as $c) {
                $cArr = (array) $c;
                $code = strtoupper(trim($cArr['component_code'] ?? ''));
                $name = trim($cArr['component_name'] ?? $code);
                $type = strtoupper(trim($cArr['component_type'] ?? ''));
                $calc = strtoupper(trim($cArr['calculation_type'] ?? 'MANUAL'));
                $compId = $cArr['component_id'] ?? ($cArr['comp_id'] ?? $code);
                $pctBase = $cArr['percentage_base'] ?? 'CTC';
                $formula = $cArr['formula_expression'] ?? '';
                $isTaxable = (int) ($cArr['is_taxable'] ?? 0);

                if ($code === '')
                    continue;

                $meta = [
                    'name' => $name,
                    'calc_type' => $calc,
                    'component_id' => $compId,
                    'percentage_base' => $pctBase,
                    'formula_expression' => $formula,
                    'is_taxable' => $isTaxable
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

// If the controller separately supplies the database salary-component catalog,
// use it to render dynamic headings even when this period has no payroll rows.
$componentCatalog = [];
foreach (['salary_component_catalog', 'salary_components', 'component_catalog'] as $catalogName) {
    if (isset($$catalogName) && is_array($$catalogName) && !empty($$catalogName)) {
        $componentCatalog = $$catalogName;
        break;
    }
}

foreach ($componentCatalog as $catalogRow) {
    $cArr = (array) $catalogRow;
    $code = strtoupper(trim($cArr['component_code'] ?? $cArr['code'] ?? ''));
    $name = trim($cArr['component_name'] ?? $cArr['name'] ?? $code);
    $type = strtoupper(trim($cArr['component_type'] ?? $cArr['type'] ?? ''));
    if ($code === '' || $name === '') {
        continue;
    }

    $meta = [
        'name' => $name,
        'calc_type' => strtoupper(trim($cArr['calculation_type'] ?? 'MANUAL')),
        'component_id' => $cArr['component_id'] ?? ($cArr['id'] ?? $code),
        'percentage_base' => $cArr['percentage_base'] ?? 'CTC',
        'formula_expression' => $cArr['formula_expression'] ?? '',
        'is_taxable' => (int) ($cArr['is_taxable'] ?? 0),
    ];

    if ($type === 'EARNING') {
        $dynEarnings[$code] = $dynEarnings[$code] ?? $meta;
    } elseif (in_array($type, ['EMPLOYER_CONTRIBUTION', 'STATUTORY'], true)) {
        $dynEmployer[$code] = $dynEmployer[$code] ?? $meta;
    } elseif ($type === 'DEDUCTION') {
        $dynDeductions[$code] = $dynDeductions[$code] ?? $meta;
    }
}

$totalProfiles = count($payroll_data);

// Total dynamic columns in the visible payroll grid.
// 1(Check) + 2(Id, Name) + 5(Days) + 2(CTC, CTC1) + 1(Gross) + count(dynEarnings) + count(dynEmployer) + count(dynDeductions) + 1(TotDed) + 1(Net) + 4(Banking) + 7(Statutory) + 1(Action)
$totalDynamicCols = 2 + 5 + 2 + 1 + count($dynEarnings) + count($dynEmployer) + count($dynDeductions) + 1 + 1 + 4 + 7 + 1;
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>BloomHR | Step 3: Master Payroll Calculation &amp; Payout</title>
    <link rel="icon" type="image/jpeg" href="public/dist/img/bloom.jpg">

    <!-- Google Font: Plus Jakarta Sans -->
    <link rel="stylesheet"
        href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
    <!-- Font Awesome 6 -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <!-- AdminLTE 3 -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
    <!-- DataTables Bootstrap 4 -->
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">
    <!-- SweetAlert2 for Modern Confirmations & Alerts -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>

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

        /* LAYOUT & SPACING */
        .content-wrapper {
            min-height: calc(100vh - 57px) !important;
            padding-bottom: 30px !important;
            background-color: var(--soft-gray);
        }

        .payroll-page {
            color: #334155;
            padding: 14px 20px 24px;
        }

        .payroll-page * {
            box-sizing: border-box;
        }

        /* BLOOM CARDS */
        .pc-card,
        .card-bloom {
            background: #fff;
            border: 1px solid var(--border-color) !important;
            border-radius: 16px !important;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.03) !important;
            margin-bottom: 1.25rem;
            overflow: hidden;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }

        .pc-card:hover,
        .card-bloom:hover {
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

        /* BADGES */
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

        .pc-purple,
        .badge-soft-primary {
            background: #eef2ff !important;
            color: var(--bloom-purple) !important;
        }

        .pc-green,
        .badge-soft-success {
            background: #dcfce7 !important;
            color: #15803d !important;
        }

        .pc-yellow,
        .badge-soft-warning {
            background: #fef3c7 !important;
            color: #b45309 !important;
        }

        .pc-red,
        .badge-soft-danger {
            background: #fee2e2 !important;
            color: #b91c1c !important;
        }

        .pc-blue,
        .badge-soft-info {
            background: #e0f2fe !important;
            color: #0369a1 !important;
        }

        .badge-soft-secondary {
            background: #f1f5f9 !important;
            color: #475569 !important;
        }

        /* BUTTONS */
        .pc-btn {
            border: 1px solid var(--border-color);
            border-radius: 10px;
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
            background: linear-gradient(135deg, #4a00e0 0%, #2a0080 100%) !important;
            border-color: #4a00e0 !important;
            color: #ffffff !important;
            box-shadow: 0 3px 8px rgba(74, 0, 224, 0.2);
        }

        .pc-btn-primary:hover {
            background: linear-gradient(135deg, #3a00b0 0%, #1a0050 100%) !important;
            color: #ffffff !important;
            transform: translateY(-1px);
        }

        .pc-btn-success {
            background: linear-gradient(135deg, #10b981 0%, #059669 100%) !important;
            border-color: #10b981 !important;
            color: #ffffff !important;
            box-shadow: 0 3px 8px rgba(16, 185, 129, 0.25);
        }

        .pc-btn-success:hover {
            background: linear-gradient(135deg, #059669 0%, #047857 100%) !important;
            color: #ffffff !important;
            transform: translateY(-1px);
        }

        .pc-btn-warning {
            background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%) !important;
            border-color: #f59e0b !important;
            color: #ffffff !important;
            box-shadow: 0 3px 8px rgba(245, 158, 11, 0.25);
        }

        .pc-btn-warning:hover {
            background: linear-gradient(135deg, #d97706 0%, #b45309 100%) !important;
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

        /* 4-STEP PIPELINE STEPPER */

        .pc-step.completed .pc-step-line,
        .pc-step.active .pc-step-line {
            background: var(--bloom-purple);
        }


        /* MASTER GRID STYLING - EXACT MATCH WITH salary_structure.php */
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
            font-size: 12.5px;
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
            padding: 10px 12px;
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
            padding: 10px 12px;
            vertical-align: middle !important;
            border-top: 1px solid #f1f5f9;
            font-size: 12.5px;
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

        /* FROZEN STICKY COLUMNS WITH CHECKBOX */

        .freeze-col-id {
            position: sticky !important;
            left: 44px !important;
            z-index: 12 !important;
            background-color: #fff !important;
            width: 95px !important;
            min-width: 95px !important;
        }

        .freeze-col-name {
            position: sticky !important;
            left: 139px !important;
            z-index: 12 !important;
            background-color: #fff !important;
            min-width: 180px !important;
            box-shadow: 3px 0 6px -2px rgba(0, 0, 0, 0.08) !important;
        }

        .freeze-col-action {
            position: sticky !important;
            right: 0 !important;
            z-index: 12 !important;
            background-color: #fff !important;
            box-shadow: -3px 0 6px -2px rgba(0, 0, 0, 0.08) !important;
        }

        .table-master thead th.freeze-col-check,
        .table-master thead th.freeze-col-id,
        .table-master thead th.freeze-col-name,
        .table-master thead th.freeze-col-action {
            z-index: 25 !important;
            background-color: #f8fafc !important;
        }

        .table-master tbody tr:hover td.freeze-col-check,
        .table-master tbody tr:hover td.freeze-col-id,
        .table-master tbody tr:hover td.freeze-col-name,
        .table-master tbody tr:hover td.freeze-col-action {
            background-color: #f8faff !important;
        }

        .row-excluded td {
            color: #94a3b8 !important;
        }

        /* DATATABLES TOOLBAR (Exact from salary_structure.php) */
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
            outline: none;
        }

        .dataTables_filter input {
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 6px 12px;
            margin-left: 5px;
            height: 34px;
            outline: none;
        }

        .dataTables_filter input:focus,
        .dataTables_length select:focus {
            border-color: var(--bloom-purple);
            box-shadow: 0 0 0 3px rgba(74, 0, 224, 0.1);
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

        /* WORKFLOW BOTTOM BAR */
        .pc-bottom-bar {
            position: static !important;
            width: 100% !important;
            min-height: 70px !important;
            padding: 16px 24px !important;
            background: #ffffff !important;
            border: 1px solid var(--border-color) !important;
            border-radius: 16px !important;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.03) !important;
            margin-top: 1.5rem !important;
            margin-bottom: 0.5rem !important;
            display: flex !important;
            align-items: center !important;
            justify-content: space-between !important;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }

        .pc-bottom-bar:hover {
            box-shadow: 0 10px 20px -3px rgba(18, 0, 56, 0.06) !important;
        }

        /* MODAL DETAIL BREAKDOWN */
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
    </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed">
    <div class="wrapper">

        <!-- Content Wrapper -->
        <div class="content-wrapper">
            <section class="content pt-3">
                <div class="container-fluid px-2 px-md-3">

                    <div class="payroll-page">

                        <!-- TOP BAR / META CONTEXT -->
                        <div class="pc-top">
                            <div>
                                <div class="pc-meta mb-2 d-flex align-items-center flex-wrap" style="gap: 8px;">
                                    <span class="pc-badge pc-purple">
                                        <i class="fas fa-fingerprint"></i>
                                        CYCLE-<?= esc($payrollCycleId) ?>
                                    </span>
                                    <span
                                        class="pc-badge <?= $payrollCycleStatus === 'PAID' ? 'pc-green' : ($payrollCycleStatus === 'FINALIZE' || $payrollCycleStatus === 'FINALIZED' ? 'pc-blue' : 'pc-yellow') ?>"
                                        id="cycleStatusBadge">
                                        <i
                                            class="fas <?= $payrollCycleStatus === 'PAID' ? 'fa-check-circle' : ($payrollCycleStatus === 'FINALIZE' || $payrollCycleStatus === 'FINALIZED' ? 'fa-lock' : 'fa-clock') ?>"></i>
                                        Cycle Status: <strong id="cycleStatusText"
                                            class="ml-1"><?= esc($payrollCycleStatus ?: 'N/A') ?></strong>
                                    </span>
                                    <span class="pc-muted">Month: <strong><?= esc($payrollMonthName) ?>
                                            <?= esc($payrollYear) ?></strong></span>
                                </div>
                                <h1 class="pc-heading">Payroll Summary of <strong><?= esc($payrollMonthName) ?>
                                            <?= esc($payrollYear) ?></strong></h1>
                                <p class="pc-muted">
                                    <i class="far fa-calendar-alt text-primary mr-1"></i> Period:
                                    <strong><?= esc($periodStart) ?></strong> to <strong><?= esc($periodEnd) ?></strong>
                                    &bull; Payment Target: <strong><?= esc($paymentDate) ?></strong> &bull; Total
                                    Profiles: <strong><?= count($payroll_data) ?></strong>
                                </p>
                            </div>
                        </div>

                        <!-- PERIOD FILTER BAR -->
                        <div class="pc-card">
                            <div class="pc-body py-3">
                                <div class="pc-flex">
                                    <form method="GET" action="" class="pc-actions"
                                        id="filterForm">
                                        <strong>
                                            <i class="far fa-calendar-alt text-primary mr-1"></i>
                                            Payroll Month &amp; Cycle:
                                        </strong>

                                        <select name="month" id="selectMonth" class="pc-control" style="width: 140px;">
                                            <?php for ($m = 1; $m <= 12; $m++): ?>
                                                <option value="<?= $m ?>" <?= ((int) $payrollMonth === $m) ? 'selected' : '' ?>>
                                                    <?= date('F', mktime(0, 0, 0, $m, 10)) ?>
                                                </option>
                                            <?php endfor; ?>
                                        </select>

                                        <select name="year" id="selectYear" class="pc-control" style="width: 110px;">
                                            <?php for ($y = (int) $payrollYear - 2; $y <= (int) $payrollYear + 2; $y++): ?>
                                                <option value="<?= $y ?>" <?= ((int) $payrollYear === $y) ? 'selected' : '' ?>>
                                                    <?= $y ?>
                                                </option>
                                            <?php endfor; ?>
                                        </select>

                                        <button type="submit" class="pc-btn pc-btn-primary">
                                            <i class="fas fa-filter mr-1"></i> Apply Filter
                                        </button>
                                    </form>

                                </div>
                            </div>
                        </div>

                        <!-- MASTER DYNAMIC PAYROLL GRID CARD -->
                        <div class="pc-card">
                            <div class="pc-body py-3 border-bottom d-flex align-items-center justify-content-between flex-wrap"
                                style="gap: 12px; background: #ffffff;">
                                <div class="d-flex align-items-center flex-wrap" style="gap: 10px;">
                                    <span class="badge badge-soft-primary px-3 py-2 font-weight-bold"
                                        style="border-radius: 20px;">
                                        <i class="fas fa-table-columns mr-1"></i> Dynamic Master Calculation Grid
                                    </span>
                                    <!-- <span class="badge badge-soft-success px-3 py-2 font-weight-bold"
                                        style="border-radius: 20px;">
                                        <i class="fas fa-layer-group mr-1"></i> <?= count($dynEarnings) ?> Earnings
                                        &bull; <?= count($dynEmployer) ?> Employer &bull; <?= count($dynDeductions) ?>
                                        Deductions
                                    </span> -->
                                </div>
                                <div class="d-flex align-items-center" style="gap: 10px;">
                                    <button class="pc-btn" type="button" onclick="exportGridCSV()">
                                        <i class="fas fa-file-excel text-success mr-1"></i> Export CSV
                                    </button>
                                </div>
                            </div>

                            <div class="master-grid-container">
                                <table class="table-master table-hover mb-0" id="payrollGridTable">
                                    <thead>
                                        <tr class="table-header">

                                            <!-- Group 1: Identity (Frozen Left) -->
                                            <th class="pl-2 freeze-col-id">
                                                <span class="col-category">Identity</span>Emp ID
                                            </th>
                                            <th class="border-right freeze-col-name">
                                                <span class="col-category">Identity</span>Employee Name
                                            </th>

                                            <!-- Group 2: Attendance & Calendar Days -->
                                            <th class="text-center"><span class="col-category">Days</span>Total Days
                                            </th>
                                            <th class="text-center font-weight-bold"><span
                                                    class="col-category">Days</span>Payable</th>
                                            <th class="text-center"><span class="col-category">Days</span>Paid Leaves
                                            </th>
                                            <th class="text-center text-danger"><span
                                                    class="col-category">Days</span>Unpaid (LOP)</th>
                                            <th class="text-center border-right"><span
                                                    class="col-category">Days</span>Absent</th>

                                            <!-- Group 3: CTC Base -->
                                            <th class="cell-currency"><span class="col-category">CTC Base</span>Monthly
                                                CTC</th>
                                            <th class="cell-currency border-right"><span class="col-category">CTC
                                                    Base</span>CTC1</th>

                                            <!-- Group 4: Earnings (Gross & Dynamic Components) -->
                                            <th class="cell-currency cell-bold"><span class="col-category"
                                                    style="color: #4338ca;">Earnings</span>Gross Earnings</th>
                                            <?php $eCount = 0;
                                            foreach ($dynEarnings as $code => $meta):
                                                $eCount++; ?>
                                                <th class="cell-currency <?= ($eCount === count($dynEarnings)) ? 'border-right' : '' ?>"
                                                    title="<?= esc($meta['name']) ?>">
                                                    <span class="col-category">Earnings</span><?= esc($meta['name']) ?>
                                                </th>
                                            <?php endforeach; ?>

                                            <!-- Group 5: Employer Statutory Contributions (Dynamic) -->
                                            <?php $erCount = 0;
                                            foreach ($dynEmployer as $code => $meta):
                                                $erCount++; ?>
                                                <th class="cell-currency <?= ($erCount === count($dynEmployer)) ? 'border-right' : '' ?>"
                                                    title="<?= esc($meta['name']) ?>">
                                                    <span class="col-category">Employer</span><?= esc($meta['name']) ?>
                                                </th>
                                            <?php endforeach; ?>

                                            <!-- Group 6: Employee Deductions (Dynamic) -->
                                            <?php foreach ($dynDeductions as $code => $meta): ?>
                                                <th class="cell-currency" title="<?= esc($meta['name']) ?>">
                                                    <span class="col-category">Deductions</span><?= esc($meta['name']) ?>
                                                </th>
                                            <?php endforeach; ?>
                                            <th class="cell-currency cell-bold text-danger border-right">
                                                <span class="col-category">Deductions</span>Total Deductions
                                            </th>

                                            <!-- Group 7: Net Payout (Highlighted) -->
                                            <th class="highlight-col cell-currency text-right pr-3 border-right">
                                                <span class="col-category" style="color: #15803d;">Payout</span>Net Pay
                                            </th>

                                            <!-- Group 8: Banking Details -->
                                            <th><span class="col-category">Banking</span>Bank Name</th>
                                            <th><span class="col-category">Banking</span>Bank A/c No</th>
                                            <th><span class="col-category">Banking</span>IFSC</th>
                                            <th class="border-right"><span class="col-category">Banking</span>Account
                                                Type</th>

                                            <!-- Group 9: Statutory & Contact Identifiers -->
                                            <th><span class="col-category">Statutory</span>PAN</th>
                                            <th><span class="col-category">Statutory</span>UAN</th>
                                            <th><span class="col-category">Statutory</span>PF No</th>
                                            <th><span class="col-category">Statutory</span>ESIC No</th>
                                            <th><span class="col-category">Statutory</span>Aadhaar</th>
                                            <th><span class="col-category">Contact</span>Mobile</th>
                                            <th class="border-right"><span class="col-category">Contact</span>Email</th>

                                            <!-- Group 10: Action (Sticky Right) -->
                                            <th class="text-center pr-3 no-sort freeze-col-action">
                                                <span class="col-category">Action</span>View
                                            </th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <?php if (!empty($payroll_data) && is_array($payroll_data)): ?>
                                            <?php foreach ($payroll_data as $row): ?>
                                                <?php
                                                $rowArr = (array) $row;
                                                $empId = $rowArr['emp_id'] ?? $rowArr['employee_id'] ?? $rowArr['employee_code'] ?? ''; 
                                                $empName = $rowArr['emp_name'] ?? $rowArr['employee_name'] ?? $rowArr['name'] ?? ''; 
                                                $email = $rowArr['email'] ?? '';
                                                $mobile = $rowArr['mobile'] ?? '';
                                                $dept = $rowArr['department'] ?? '';
                                                $desig = $rowArr['designation'] ?? '';
                                                $monthlyCtc = (float) ($rowArr['monthly_ctc'] ?? 0);
                                                $ctc1 = (float) ($rowArr['ctc1'] ?? $monthlyCtc);
                                                $totalDays = (float) ($rowArr['total_days'] ?? 0);
                                                $payableDays = (float) ($rowArr['payable_days'] ?? 0);
                                                $paidLeave = (float) ($rowArr['paid_leave_days'] ?? 0);
                                                $unpaidLeave = (float) ($rowArr['unpaid_leave_days'] ?? 0);
                                                $absentDays = (float) ($rowArr['absent_days'] ?? 0);

                                                $bankName = $rowArr['bank_name'] ?? ''; 
                                                $bankAccNo = $rowArr['bank_account_no'] ?? ($rowArr['bank_acc_no'] ?? '');
                                                $ifsc = $rowArr['ifsc'] ?? ''; 
                                                $bankAccType = $rowArr['bank_account_type'] ?? ''; 
                                                $pan = $rowArr['pan'] ?? ''; 
                                                $uan = $rowArr['uan'] ?? ''; 
                                                $pfAccNo = $rowArr['pf_account_no'] ?? ''; 
                                                $esicNo = $rowArr['esic_no'] ?? ''; 
                                                $aadhaar = $rowArr['aadhaar'] ?? ''; 
                                                $calcRemarks = $rowArr['calculation_remarks'] ?? '';

                                                // Parse JSON salary components
                                                $cmpAmounts = [];
                                                $cmpValues = [];
                                                $cmpMetaMap = [];
                                                $calcGross = 0.00;
                                                $calcTotDeductions = 0.00;
                                                $calcEmployer = 0.00;

                                                $componentSource = $rowArr['salary_components'] ?? $rowArr['salary_component_details'] ?? $rowArr['components_json'] ?? null;
                                                if (!empty($componentSource)) {
                                                    $rawJson = is_string($componentSource)
                                                        ? json_decode($componentSource, true)
                                                        : $componentSource;

                                                    if (is_array($rawJson)) {
                                                        foreach ($rawJson as $c) {
                                                            $cArr = (array) $c;
                                                            $code = strtoupper(trim($cArr['component_code'] ?? ''));
                                                            $name = trim($cArr['component_name'] ?? $code);
                                                            $type = strtoupper(trim($cArr['component_type'] ?? ''));
                                                            $calc = strtoupper(trim($cArr['calculation_type'] ?? 'MANUAL'));
                                                            $pctBase = strtoupper(trim($cArr['percentage_base'] ?? 'CTC'));
                                                            $formula = $cArr['formula_expression'] ?? '';
                                                            $isTaxable = (int) ($cArr['is_taxable'] ?? 0);

                                                            // Check calculated_amount first as from stored procedure
                                                            $amount = (float) ($cArr['calculated_amount'] ?? ($cArr['monthly_amount'] ?? ($cArr['amount'] ?? 0.00)));
                                                            $val = (float) ($cArr['component_value'] ?? ($cArr['percentage_value'] ?? 0.00));

                                                            if ($code !== '') {
                                                                $cmpAmounts[$code] = $amount;
                                                                $cmpValues[$code] = $val;
                                                                $cmpMetaMap[$code] = [
                                                                    'name' => $name,
                                                                    'type' => $type,
                                                                    'calculation_type' => $calc,
                                                                    'percentage_base' => $pctBase,
                                                                    'formula_expression' => $formula,
                                                                    'amount' => $amount,
                                                                    'value' => $val,
                                                                    'is_taxable' => $isTaxable
                                                                ];
                                                            }

                                                            if ($type === 'EARNING') {
                                                                $calcGross += $amount;
                                                            } elseif ($type === 'DEDUCTION') {
                                                                $calcTotDeductions += $amount;
                                                            } elseif ($type === 'EMPLOYER_CONTRIBUTION' || $type === 'STATUTORY') {
                                                                $calcEmployer += $amount;
                                                            }
                                                        }
                                                    }
                                                }

                                                // Fallback to row fields if components didn't calculate
                                                $grossEarnings = array_key_exists('gross_earnings', $rowArr) ? (float) $rowArr['gross_earnings'] : $calcGross;
                                                $totalDeductions = array_key_exists('total_deductions', $rowArr) ? (float) $rowArr['total_deductions'] : $calcTotDeductions;
                                                $netPay = array_key_exists('net_pay', $rowArr) ? (float) $rowArr['net_pay'] : max(0, $grossEarnings - $totalDeductions);

                                                // Store in JS memory map for instant modal viewing
                                                $employeesMap[$empId] = [
                                                    'emp_id' => $empId,
                                                    'emp_name' => $empName,
                                                    'dept' => $dept,
                                                    'desig' => $desig,
                                                    'email' => $email,
                                                    'mobile' => $mobile,
                                                    'monthly_ctc' => $monthlyCtc,
                                                    'ctc1' => $ctc1,
                                                    'total_days' => $totalDays,
                                                    'payable_days' => $payableDays,
                                                    'paid_leave' => $paidLeave,
                                                    'unpaid_leave' => $unpaidLeave,
                                                    'absent_days' => $absentDays,
                                                    'gross_earnings' => $grossEarnings,
                                                    'total_deductions' => $totalDeductions,
                                                    'net_pay' => $netPay,
                                                    'bank_name' => $bankName,
                                                    'bank_account_no' => $bankAccNo,
                                                    'ifsc' => $ifsc,
                                                    'bank_account_type' => $bankAccType,
                                                    'pan' => $pan,
                                                    'uan' => $uan,
                                                    'pf_account_no' => $pfAccNo,
                                                    'esic_no' => $esicNo,
                                                    'aadhaar' => $aadhaar,
                                                    'remarks' => $calcRemarks,
                                                    'components' => $cmpMetaMap
                                                ];
                                                ?>
                                                <tr id="row-<?= esc($empId) ?>" data-empid="<?= esc($empId) ?>">

                                                    <!-- Emp ID -->
                                                    <td class="font-weight-bold text-primary font-monospace pl-2 freeze-col-id">
                                                        <?= esc($empId) ?>
                                                    </td>

                                                    <!-- Employee Name & Designation -->
                                                    <td class="border-right freeze-col-name">
                                                        <div class="font-weight-bold text-dark"><?= esc($empName) ?></div>
                                                    </td>

                                                    <!-- Attendance Days -->
                                                    <td class="text-center font-monospace"><?= number_format($totalDays, 1) ?>
                                                    </td>
                                                    <td class="text-center font-monospace font-weight-bold text-primary">
                                                        <?= number_format($payableDays, 1) ?></td>
                                                    <td class="text-center font-monospace text-muted">
                                                        <?= number_format($paidLeave, 1) ?></td>
                                                    <td
                                                        class="text-center font-monospace <?= $unpaidLeave > 0 ? 'text-danger font-weight-bold' : 'text-muted' ?>">
                                                        <?= number_format($unpaidLeave, 1) ?>
                                                    </td>
                                                    <td class="text-center font-monospace text-muted border-right">
                                                        <?= number_format($absentDays, 1) ?></td>

                                                    <!-- CTC Base -->
                                                    <td class="cell-currency font-weight-bold text-primary">
                                                        ₹ <?= number_format($monthlyCtc, 2) ?>
                                                    </td>
                                                    <td class="cell-currency text-muted border-right">
                                                        ₹ <?= number_format($ctc1, 2) ?>
                                                    </td>

                                                    <!-- Gross Earnings -->
                                                    <td class="cell-currency cell-bold">
                                                        ₹ <?= number_format($grossEarnings, 2) ?>
                                                    </td>

                                                    <!-- Dynamic Earnings Columns -->
                                                    <?php $eCount = 0;
                                                    foreach ($dynEarnings as $code => $meta):
                                                        $eCount++; ?>
                                                        <td
                                                            class="cell-currency <?= ($eCount === count($dynEarnings)) ? 'border-right' : '' ?>">
                                                            ₹ <?= number_format($cmpAmounts[$code] ?? 0.00, 2) ?>
                                                        </td>
                                                    <?php endforeach; ?>

                                                    <!-- Dynamic Employer Contribution Columns -->
                                                    <?php $erCount = 0;
                                                    foreach ($dynEmployer as $code => $meta):
                                                        $erCount++; ?>
                                                        <td
                                                            class="cell-currency <?= ($erCount === count($dynEmployer)) ? 'border-right' : '' ?>">
                                                            ₹ <?= number_format($cmpAmounts[$code] ?? 0.00, 2) ?>
                                                        </td>
                                                    <?php endforeach; ?>

                                                    <!-- Dynamic Employee Deduction Columns -->
                                                    <?php foreach ($dynDeductions as $code => $meta): ?>
                                                        <td class="cell-currency">
                                                            ₹ <?= number_format($cmpAmounts[$code] ?? 0.00, 2) ?>
                                                        </td>
                                                    <?php endforeach; ?>

                                                    <!-- Total Deductions -->
                                                    <td class="cell-currency cell-bold text-danger border-right">
                                                        ₹ <?= number_format($totalDeductions, 2) ?>
                                                    </td>

                                                    <!-- Net Pay Highlight -->
                                                    <td class="highlight-col cell-currency text-right pr-3 border-right">
                                                        ₹ <?= number_format($netPay, 2) ?>
                                                    </td>

                                                    <!-- Banking Details -->
                                                    <td class="font-weight-bold text-dark"><?= esc($bankName) ?></td>
                                                    <td class="font-monospace text-muted"><?= esc($bankAccNo) ?></td>
                                                    <td class="font-monospace text-muted"><?= esc($ifsc) ?></td>
                                                    <td class="text-muted border-right"><?= esc($bankAccType) ?></td>

                                                    <!-- Statutory Identifiers -->
                                                    <td class="font-monospace text-muted"><?= esc($pan) ?></td>
                                                    <td class="font-monospace text-muted"><?= esc($uan) ?></td>
                                                    <td class="font-monospace text-muted"><?= esc($pfAccNo) ?></td>
                                                    <td class="font-monospace text-muted"><?= esc($esicNo) ?></td>
                                                    <td class="font-monospace text-muted"><?= esc($aadhaar) ?></td>
                                                    <td class="font-monospace text-muted"><?= esc($mobile) ?></td>
                                                    <td class="font-monospace text-muted border-right"><?= esc($email) ?></td>

                                                    <!-- Action: View Detailed Breakdown Modal -->
                                                    <td class="text-center pr-3 freeze-col-action">
                                                        <button class="pc-btn pc-btn-primary"
                                                            style="padding: 4px 10px; font-size: 11px;"
                                                            onclick="openEmployeeBreakdown('<?= esc($empId) ?>')">
                                                            <i class="fas fa-eye mr-1"></i> View
                                                        </button>
                                                    </td>
                                                </tr>
                                            <?php endforeach; ?>
                                        <?php else: ?>
                                            <tr>
                                                <td colspan="<?= $totalDynamicCols ?>" class="text-center py-4 text-muted">
                                                    <i class="fas fa-folder-open mb-2 text-secondary"
                                                        style="font-size: 26px; display: block; opacity: 0.6;"></i>
                                                    <strong><?= esc($firstRow['remarks'] ?? 'No active payroll calculation records found for this period.') ?></strong>
                                                </td>
                                            </tr>
                                        <?php endif; ?>
                                    </tbody>
                                </table>
                            </div>
                        </div>

                        <!-- Standalone display page: dashboard navigation only -->
                        <div class="pc-bottom-bar d-flex justify-content-end">
                            <a href="<?= base_url('payroll/payroll_dashboard') ?>" class="pc-btn pc-btn-primary">
                                <i class="fas fa-th-large mr-1"></i> Back to Dashboard
                            </a>
                        </div>

                    </div>
                </div>
            </section>
        </div>

    </div>

    <!-- EMPLOYEE CALCULATION BREAKDOWN MODAL -->
    <div class="modal fade" id="empBreakdownModal" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
            <div class="modal-content modal-bloom-dialog">
                <div class="modal-bloom-header d-flex justify-content-between align-items-center">
                    <div class="d-flex align-items-center" style="gap: 12px;">
                        <div class="d-flex align-items-center justify-content-center rounded-circle text-white"
                            style="width: 42px; height: 42px; background: rgba(255, 255, 255, 0.2); font-size: 16px;">
                            <i class="fas fa-calculator"></i>
                        </div>
                        <div>
                            <div class="d-flex align-items-center" style="gap: 8px;">
                                <h5 class="modal-title font-weight-bold mb-0 text-white" id="modalEmpName">Employee
                                    Calculation Ledger</h5>
                                <span class="badge badge-light text-primary font-weight-bold font-monospace px-2 py-0.5"
                                    id="modalEmpId">-</span>
                            </div>
                            <small class="text-white-50" id="modalEmpDesignation">Designation &bull; Department</small>
                        </div>
                    </div>
                    <button type="button" class="close text-white p-0" data-dismiss="modal" aria-label="Close"
                        style="opacity: 0.9; font-size: 26px; line-height: 1;">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>

                <div class="modal-body p-4" style="max-height: calc(85vh - 120px); overflow-y: auto;">
                    <!-- Attendance & Days Strip -->
                    <div class="p-3 bg-light rounded-lg border mb-3">
                        <div class="row text-center">
                            <div class="col-3">
                                <span class="pc-label">Total Days</span>
                                <div class="font-weight-bold text-dark" id="modalDaysTotal">—</div>
                            </div>
                            <div class="col-3">
                                <span class="pc-label">Payable Days</span>
                                <div class="font-weight-bold text-primary" id="modalDaysPayable">—</div>
                            </div>
                            <div class="col-3">
                                <span class="pc-label">Paid Leaves</span>
                                <div class="font-weight-bold text-success" id="modalDaysPaidLeaves">—</div>
                            </div>
                            <div class="col-3">
                                <span class="pc-label">Unpaid (LOP)</span>
                                <div class="font-weight-bold text-danger" id="modalDaysUnpaid">—</div>
                            </div>
                        </div>
                    </div>

                    <!-- Earnings Table -->
                    <h6 class="font-weight-bold text-dark mb-2"><i class="fas fa-plus-circle text-success mr-1"></i>
                        Earnings Breakdown</h6>
                    <div class="table-responsive mb-3">
                        <table class="table table-sm table-bordered mb-0" id="modalEarningsTable">
                            <thead class="bg-light">
                                <tr>
                                    <th>Component</th>
                                    <th>Type</th>
                                    <th>Calculation Base</th>
                                    <th class="text-right">Calculated Amount</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                            <tfoot class="bg-light font-weight-bold">
                                <tr>
                                    <td colspan="3">Gross Total Earnings</td>
                                    <td class="text-right text-dark" id="modalGrossTotal">—</td>
                                </tr>
                            </tfoot>
                        </table>
                    </div>

                    <!-- Deductions Table -->
                    <h6 class="font-weight-bold text-dark mb-2"><i class="fas fa-minus-circle text-danger mr-1"></i>
                        Deductions Breakdown</h6>
                    <div class="table-responsive mb-3">
                        <table class="table table-sm table-bordered mb-0" id="modalDeductionsTable">
                            <thead class="bg-light">
                                <tr>
                                    <th>Component</th>
                                    <th>Type</th>
                                    <th>Calculation Base</th>
                                    <th class="text-right">Deduction Amount</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                            <tfoot class="bg-light font-weight-bold">
                                <tr>
                                    <td colspan="3">Total Deductions</td>
                                    <td class="text-right text-danger" id="modalDeductionsTotal">—</td>
                                </tr>
                            </tfoot>
                        </table>
                    </div>

                    <!-- Net Payout Box -->
                    <div class="p-3 rounded-lg border d-flex justify-content-between align-items-center"
                        style="background: #f0fdf4; border-color: #bbf7d0 !important;">
                        <div>
                            <span class="pc-label text-success">Net Take-Home Salary</span>
                            <div class="font-weight-bold text-success" id="modalNetPayTotal" style="font-size: 24px;">—</div>
                        </div>
                        <div class="text-right">
                            <span class="pc-label">Banking Route</span>
                            <div class="font-weight-bold text-dark" id="modalBankRoute">Bank &bull; A/c</div>
                            <small class="text-muted" id="modalIfscPan">IFSC &bull; PAN</small>
                        </div>
                    </div>

                    <!-- Calculation Remarks Note -->
                    <div class="mt-3 p-2 bg-light rounded text-muted" style="font-size: 11.5px;" id="modalRemarksBox">
                        <i class="fas fa-info-circle mr-1 text-primary"></i> <span id="modalRemarksText">Procedure
                            calculation verified.</span>
                    </div>
                </div>

                <div class="modal-bloom-footer d-flex justify-content-between align-items-center">
                    <button type="button" class="pc-btn" data-dismiss="modal">Close</button>
                    <span class="badge badge-soft-success px-3 py-2 font-weight-bold">
                        <i class="fas fa-check-circle mr-1"></i> Calculation Formula Verified
                    </span>
                </div>
            </div>
        </div>
    </div>

    <!-- Scripts -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>

    <script>
        // Global in-memory dataset serialized from PHP
        const employeesCatalog = <?= json_encode($employeesMap, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) ?>;
        let gridDt = null;

        // Custom DataTables sorting for Indian Rupee currency values
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

        // Initialize DataTable
        $(document).ready(function () {
            gridDt = $('#payrollGridTable').DataTable({
                paging: true,
                ordering: true,
                order: [],
                searching: true,
                info: true,
                lengthChange: true,
                pageLength: 10,
                lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, "All"]],
                dom: "<'row'<'col-md-6'l><'col-md-6'f>>" +
                    "<'master-grid-container'tr>" +
                    "<'row'<'col-md-6'i><'col-md-6'p>>",
                columnDefs: [
                    { orderable: false, targets: ['no-sort'] },
                    { type: 'currency', targets: 'cell-currency' }
                ],
                language: {
                    paginate: {
                        previous: "Previous",
                        next: "Next"
                    },
                    search: "Search:"
                }
            });

        });

        // Open detailed employee breakdown modal
        function openEmployeeBreakdown(empId) {
            const emp = employeesCatalog[empId];
            if (!emp) return;

            $('#modalEmpName').text(emp.emp_name);
            $('#modalEmpId').text(emp.emp_id);
            $('#modalEmpDesignation').text([emp.desig, emp.dept].filter(Boolean).join(' • ') || '—');

            $('#modalDaysTotal').text(emp.total_days);
            $('#modalDaysPayable').text(emp.payable_days);
            $('#modalDaysPaidLeaves').text(emp.paid_leave);
            $('#modalDaysUnpaid').text(emp.unpaid_leave);

            // Populate Earnings
            let earningsHtml = '';
            let dedHtml = '';

            if (emp.components) {
                for (const code in emp.components) {
                    const c = emp.components[code];
                    const amountFormatted = '₹ ' + (parseFloat(c.amount) || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
                    const baseInfo = c.calculation_type === 'PERCENTAGE' ? `${c.value}% of ${c.percentage_base}` : (c.formula_expression || c.calculation_type);

                    if (c.type === 'EARNING') {
                        earningsHtml += `
                            <tr>
                                <td class="font-weight-bold">${c.name} <small class="text-muted">(${code})</small></td>
                                <td><span class="badge badge-soft-success">Earning</span></td>
                                <td class="text-muted">${baseInfo}</td>
                                <td class="text-right font-weight-bold">${amountFormatted}</td>
                            </tr>
                        `;
                    } else if (c.type === 'DEDUCTION') {
                        dedHtml += `
                            <tr>
                                <td class="font-weight-bold">${c.name} <small class="text-muted">(${code})</small></td>
                                <td><span class="badge badge-soft-danger">Deduction</span></td>
                                <td class="text-muted">${baseInfo}</td>
                                <td class="text-right text-danger font-weight-bold">${amountFormatted}</td>
                            </tr>
                        `;
                    }
                }
            }

            $('#modalEarningsTable tbody').html(earningsHtml || '<tr><td colspan="4" class="text-muted text-center">No earnings configured.</td></tr>');
            $('#modalDeductionsTable tbody').html(dedHtml || '<tr><td colspan="4" class="text-muted text-center">No deductions configured.</td></tr>');

            $('#modalGrossTotal').text('₹ ' + (parseFloat(emp.gross_earnings) || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }));
            $('#modalDeductionsTotal').text('₹ ' + (parseFloat(emp.total_deductions) || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }));
            $('#modalNetPayTotal').text('₹ ' + (parseFloat(emp.net_pay) || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }));

            $('#modalBankRoute').text(`${emp.bank_name} • A/c: ${emp.bank_account_no} (${emp.bank_account_type})`);
            $('#modalIfscPan').text(`IFSC: ${emp.ifsc} | PAN: ${emp.pan} | UAN: ${emp.uan}`);
            $('#modalRemarksText').text(emp.remarks || 'Standard payroll calculation executed.');

            $('#empBreakdownModal').modal('show');
        }

        // Export entire table or selected rows to clean CSV
        function exportGridCSV() {
            let csv = [];
            const rows = document.querySelectorAll('#payrollGridTable tr');

            rows.forEach((row, rowIndex) => {
                let cols = row.querySelectorAll('td, th');
                let rowData = [];

                cols.forEach((col, colIndex) => {
                    // Skip only the Action column.
                    if (colIndex === cols.length - 1) return;

                    let text = col.innerText.replace(/(\r\n|\n|\r)/gm, ' ').replace(/,/g, '').replace(/₹/g, '').trim();
                    rowData.push('"' + text + '"');
                });

                if (rowData.length > 0) {
                    csv.push(rowData.join(','));
                }
            });

            const csvFile = new Blob([csv.join('\n')], { type: 'text/csv' });
            const downloadLink = document.createElement('a');
            downloadLink.download = `Payroll_Step3_Master_Grid_${payrollMonth}_${payrollYear}.csv`;
            downloadLink.href = window.URL.createObjectURL(csvFile);
            downloadLink.style.display = 'none';
            document.body.appendChild(downloadLink);
            downloadLink.click();
            document.body.removeChild(downloadLink);
        }
    </script>
</body>

</html>