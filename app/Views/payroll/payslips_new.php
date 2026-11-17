<?php
$selectedMonth = (int)($selectedMonth ?? $month ?? date('n'));
$selectedYear  = (int)($selectedYear ?? $year ?? date('Y'));
$selectedEmpId = $selectedEmpId ?? '';
$isSingle      = !empty($isSingle);
$payslips      = $payslips ?? [];

$months = [
    1  => "January",
    2  => "February",
    3  => "March",
    4  => "April",
    5  => "May",
    6  => "June",
    7  => "July",
    8  => "August",
    9  => "September",
    10 => "October",
    11 => "November",
    12 => "December"
];
$currentMonthName = $months[$selectedMonth] ?? date('F');
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Bloom Solutions | Manage Payslips</title>

    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap"
        rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/toastr.js/latest/toastr.min.css">

    <style>
        .toast-top-right {
            top: 24px !important;
            right: 24px !important;
            z-index: 999999 !important;
        }

        #toast-container > div {
            opacity: 1 !important;
            border-radius: 12px !important;
            box-shadow: 0 10px 25px rgba(0, 0, 0, 0.25) !important;
            font-family: 'Plus Jakarta Sans', sans-serif !important;
            font-size: 13px !important;
            padding: 15px 15px 15px 50px !important;
        }

        :root {
            --bloom-purple: #4a00e0;
            --soft-gray: #f8fafc;
            --border-color: #e2e8f0;
            --bloom-success: #10b981;
            --bloom-danger: #ef4444;
            --bloom-info: #0ea5e9;
        }

        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: var(--soft-gray);
            font-size: 13px;
            color: #334155;
        }

        /* Card Styling */
        .card-bloom {
            border: 1px solid var(--border-color) !important;
            border-radius: 20px !important;
            background: #fff;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.04);
            overflow: hidden;
        }

        .avatar-list {
            width: 38px;
            height: 38px;
            border-radius: 10px;
            object-fit: cover;
        }

        /* Status Badges */
        .status-active, .badge-finalized {
            color: #10b981;
            background: #ecfdf5;
            padding: 4px 10px;
            border-radius: 8px;
            font-weight: 600;
            font-size: 11px;
            border: 1px solid #a7f3d0;
        }

        .status-leave, .badge-pending {
            color: #d97706;
            background: #fef3c7;
            padding: 4px 10px;
            border-radius: 8px;
            font-weight: 600;
            font-size: 11px;
            border: 1px solid #fde68a;
        }

        /* Header & Sidebar */
        .main-header {
            border-bottom: 1px solid #e2e8f0 !important;
            background: rgba(255, 255, 255, 0.75) !important;
            backdrop-filter: blur(12px);
        }

        .nav-pills .nav-link.active {
            background: #007bff !important;
            color: #fff !important;
        }

        /* Action Buttons */
        .action-btn {
            width: 32px;
            height: 32px;
            padding: 0;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            border-radius: 8px !important;
            transition: all 0.2s;
            border: 1px solid var(--border-color);
            background: #fff;
            color: #64748b;
        }

        .btn-view {
            color: var(--bloom-info);
        }

        .btn-edit {
            color: var(--bloom-purple);
        }

        .btn-delete {
            color: var(--bloom-danger);
        }

        .action-btn:hover {
            background: #f1f5f9;
            transform: translateY(-1px);
        }

        .btn-view:hover {
            background: #e0f2fe;
            border-color: #bae6fd;
            color: #0284c7;
        }

        .btn-edit:hover {
            background: #ede9fe;
            border-color: #ddd6fe;
            color: #4a00e0;
        }

        .btn-delete:hover {
            background: #fee2e2;
            border-color: #fecaca;
            color: var(--bloom-danger);
        }

        .employee-row:hover {
            background-color: #f8fafc;
        }

        /* Pagination Styling */
        .dataTables_paginate .paginate_button {
            margin: 0 3px !important;
        }

        .dataTables_paginate .paginate_button .page-link,
        .dataTables_paginate .page-link {
            border-radius: 10px !important;
            border: 1px solid #e2e8f0 !important;
            color: #64748b !important;
            font-weight: 600;
        }

        /* Active Page */
        .dataTables_paginate .page-item.active .page-link {
            background: linear-gradient(135deg, #4a00e0 0%, #2a0080 100%) !important;
            border-color: #4a00e0 !important;
            color: #fff !important;
        }

        /* Hover */
        .dataTables_paginate .page-link:hover {
            background: #f8faff !important;
            color: #4a00e0 !important;
            border-color: #4a00e0 !important;
        }

        /* Info Text */
        .dataTables_info {
            color: #64748b !important;
            font-size: 12px;
            font-weight: 600;
            padding-left: 15px;
        }

        .dataTables_length {
            margin: 15px;
            font-size: 13px;
            font-weight: 600;
            color: #64748b;
        }

        .dataTables_length select {
            height: 34px !important;
            min-width: 65px;
            border: 1px solid #e2e8f0 !important;
            border-radius: 10px !important;
            padding: 4px 8px !important;
        }

        .dataTables_paginate {
            padding-right: 15px;
        }

        /* Keep Show Entries and Search on same row */
        .dataTables_wrapper .dataTables_length {
            float: left;
            margin: 15px;
        }

        .dataTables_wrapper .dataTables_filter {
            float: right;
            margin: 15px;
            text-align: right;
        }

        .dataTables_wrapper .row:first-child {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .dataTables_wrapper .dataTables_filter input {
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 6px 12px;
            margin-left: 5px;
            outline: none;
        }

        .dataTables_wrapper .dataTables_filter input:focus {
            border-color: var(--bloom-purple);
            box-shadow: 0 0 0 2px rgba(74, 0, 224, 0.1);
        }

        /* Sorting arrows */
        table.dataTable thead .sorting:before,
        table.dataTable thead .sorting:after,
        table.dataTable thead .sorting_asc:before,
        table.dataTable thead .sorting_asc:after,
        table.dataTable thead .sorting_desc:before,
        table.dataTable thead .sorting_desc:after {
            top: 50% !important;
            transform: translateY(-50%);
            font-size: 10px !important;
            color: #4a00e0 !important;
        }

        .emp-badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 8px;
            font-size: 12px;
            font-weight: 600;
            letter-spacing: 0.3px;
        }

        .emp-purple {
            background: #ede9fe;
            color: #5b21b6;
            border: 1px solid #d8b4fe;
        }

        .emp-green {
            background: #ecfdf5;
            color: #059669;
            border: 1px solid #a7f3d0;
        }

        .emp-blue {
            background: #EEF4FF;
            color: #1D4ED8;
            border: 1px solid #BFDBFE;
        }

        .emp-magenta {
            background: #FDF2FF;
            color: #A21CAF;
            border: 1px solid #e879f9;
        }

        /* Filter bar */
        .filter-container {
            background: #ffffff;
            border: 1px solid var(--border-color);
            border-radius: 14px;
            padding: 6px 14px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.02);
        }

        /* Single Payslip Card Banner */
        .single-payslip-card {
            background: linear-gradient(135deg, #ffffff 0%, #f9f8ff 100%);
            border: 1px solid #ddd6fe;
            border-left: 5px solid var(--bloom-purple);
            border-radius: 16px;
            padding: 18px 24px;
            margin-bottom: 24px;
            box-shadow: 0 4px 15px rgba(74, 0, 224, 0.05);
        }

        /* Modal styling */
        .modal-content {
            border-radius: 18px;
            border: 1px solid var(--border-color);
            overflow: hidden;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
        }

        .modal-header {
            background: #f8fafc;
            border-bottom: 1px solid var(--border-color);
            padding: 16px 24px;
        }

        .modal-footer {
            background: #f8fafc;
            border-top: 1px solid var(--border-color);
            padding: 12px 24px;
        }

        /* Print styles */
        @media print {
            .main-header, .main-sidebar, .filter-container, .btn, .action-btn, .dataTables_filter, .dataTables_length, .dataTables_paginate, .dataTables_info {
                display: none !important;
            }
            .content-wrapper {
                margin: 0 !important;
                padding: 0 !important;
                background: #fff !important;
            }
            .card-bloom {
                border: none !important;
                box-shadow: none !important;
            }
        }

        /* Responsive */
        @media (max-width: 768px) {
            body, .content { font-size: 12px; }
            h4 { font-size: 18px !important; }
            .table th { font-size: 10px !important; }
            .table td { font-size: 11px !important; }
            .emp-badge { font-size: 10px !important; padding: 4px 8px !important; }
            .action-btn { width: 28px; height: 28px; font-size: 10px !important; }
            .dataTables_length, .dataTables_filter, .dataTables_info { font-size: 10px !important; }
            .dataTables_paginate .page-link { font-size: 10px !important; }
        }

        @media (max-width: 576px) {
            body, .content { font-size: 11px; padding: 10px !important; }
            h4 { font-size: 16px !important; }
            .table th { font-size: 9px !important; }
            .table td { font-size: 10px !important; }
            .emp-badge { font-size: 9px !important; padding: 3px 6px !important; }
            .action-btn { width: 25px; height: 25px; font-size: 9px !important; }
        }

        .dataTables_wrapper .top {
            padding-top: 0 !important;
            padding-bottom: 0 !important;
            margin: 0 !important;
        }

        .dataTables_wrapper .dataTables_length,
        .dataTables_wrapper .dataTables_filter {
            margin-top: 0 !important;
            margin-bottom: 0 !important;
        }
    </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed layout-navbar-fixed layout-footer-fixed">
    <div class="wrapper">

        <div class="content-wrapper">
            <section class="content p-4">

                <!-- Page Header with Title and Common Month/Year Filters -->
                <div class="d-flex flex-wrap justify-content-between align-items-center mb-4">
                    <div class="mb-2 mb-md-0">
                        <h4 class="font-weight-bold mb-1" style="color: #0f172a;">
                            <i class="fas fa-file-invoice-dollar mr-2" style="color: var(--bloom-purple);"></i>Manage Payslips
                        </h4>
                        <div class="text-muted small">
                            <?php if ($isSingle && !empty($selectedEmpId)): ?>
                                Viewing payslip details for Employee <strong class="text-dark"><?= esc($selectedEmpId) ?></strong> for <strong><?= $currentMonthName ?> <?= esc($selectedYear) ?></strong>
                            <?php else: ?>
                                Overview and actions for employee payslips &bull; Period: <strong class="text-dark"><?= $currentMonthName ?> <?= esc($selectedYear) ?></strong>
                            <?php endif; ?>
                        </div>
                    </div>

                    <!-- Common Month and Year Filters -->
                    <form id="commonFilterForm" method="GET" action="<?= base_url('payroll/payslips_new') ?>" class="d-flex flex-wrap align-items-center filter-container">
                        <!-- Keep emp_id empty on common filter changes unless user specifically wants all -->
                        <div class="d-flex align-items-center mr-3 py-1">
                            <span class="text-muted font-weight-bold mr-2 small"><i class="far fa-calendar-alt mr-1"></i> Month:</span>
                            <select name="month" id="commonMonthFilter" class="custom-select custom-select-sm" style="width: 125px; border-radius: 8px;">
                                <?php foreach ($months as $num => $name): ?>
                                    <option value="<?= $num ?>" <?= (int)$selectedMonth === (int)$num ? 'selected' : '' ?>>
                                        <?= $name ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>

                        <div class="d-flex align-items-center mr-3 py-1">
                            <span class="text-muted font-weight-bold mr-2 small"><i class="fas fa-calendar mr-1"></i> Year:</span>
                            <select name="year" id="commonYearFilter" class="custom-select custom-select-sm" style="width: 95px; border-radius: 8px;">
                                <?php for ($y = date('Y') + 1; $y >= 2024; $y--): ?>
                                    <option value="<?= $y ?>" <?= (int)$selectedYear === (int)$y ? 'selected' : '' ?>>
                                        <?= $y ?>
                                    </option>
                                <?php endfor; ?>
                            </select>
                        </div>

                        <div class="d-flex align-items-center py-1">
                            <button type="submit" class="btn btn-sm text-white rounded-pill px-3 shadow-sm mr-2" style="background: var(--bloom-purple); border: none;">
                                <i class="fas fa-filter mr-1"></i> Filter
                            </button>

                            <?php if ($isSingle && !empty($selectedEmpId)): ?>
                                <a href="<?= base_url('payroll/payslips_new?month=' . $selectedMonth . '&year=' . $selectedYear) ?>" class="btn btn-sm btn-outline-secondary rounded-pill px-3 shadow-sm" title="Show All Employees">
                                    <i class="fas fa-users mr-1"></i> View All
                                </a>
                            <?php endif; ?>
                        </div>
                    </form>
                </div>

                <!-- Single Employee Payslip Info Banner (Case 2: Specific Employee View) -->
                <?php if ($isSingle && !empty($payslips)): ?>
                    <?php 
                    $singleRow = $payslips[0];
                    $singleEmpId = $singleRow['emp_id'] ?? $selectedEmpId;
                    $singleEmpName = $singleRow['emp_name'] ?? 'N/A';
                    $singleCtc = (float)($singleRow['monthly_ctc'] ?? 0);
                    $singleRunStatus = strtoupper(trim((string)($singleRow['run_status'] ?? 'FINALIZED')));
                    $singleRemarks = $singleRow['remarks'] ?? 'Payslip retrieved successfully';
                    ?>
                    <div class="single-payslip-card">
                        <div class="d-flex flex-wrap justify-content-between align-items-center">
                            <div class="d-flex align-items-center mb-2 mb-md-0">
                                <div class="avatar-list d-inline-flex align-items-center justify-content-center text-white mr-3 font-weight-bold shadow-sm" style="background: linear-gradient(135deg, #4a00e0 0%, #2a0080 100%); width: 46px; height: 46px; border-radius: 12px; font-size: 18px;">
                                    <i class="fas fa-user-check"></i>
                                </div>
                                <div>
                                    <h5 class="font-weight-bold mb-1 text-dark">
                                        <?= esc($singleEmpName) ?>
                                        <span class="emp-badge emp-purple ml-2"><?= esc($singleEmpId) ?></span>
                                    </h5>
                                    <div class="d-flex flex-wrap align-items-center text-muted small">
                                        <span class="mr-3">
                                            <i class="far fa-calendar-alt text-primary mr-1"></i> 
                                            Period: <strong><?= $currentMonthName ?> <?= esc($selectedYear) ?></strong>
                                        </span>
                                        <span class="mr-3">
                                            <i class="fas fa-money-check-alt text-success mr-1"></i> 
                                            Monthly CTC: <strong class="text-dark">₹<?= number_format($singleCtc, 2) ?></strong>
                                        </span>
                                        <span class="mr-3">
                                            Status: 
                                            <span class="<?= $singleRunStatus === 'FINALIZED' ? 'badge-finalized' : 'badge-pending' ?>">
                                                <?= esc($singleRunStatus) ?>
                                            </span>
                                        </span>
                                        <span>
                                            <i class="fas fa-info-circle text-info mr-1"></i> <?= esc($singleRemarks) ?>
                                        </span>
                                    </div>
                                </div>
                            </div>
                            <div class="d-flex align-items-center">
                                <button type="button" class="btn btn-sm btn-outline-primary rounded-pill px-3 mr-2 shadow-sm" onclick="window.print();">
                                    <i class="fas fa-print mr-1"></i> Print
                                </button>
                                <a href="<?= base_url('payroll/payslips_new?month=' . $selectedMonth . '&year=' . $selectedYear) ?>" class="btn btn-sm btn-secondary rounded-pill px-3 shadow-sm">
                                    <i class="fas fa-arrow-left mr-1"></i> All Employees
                                </a>
                            </div>
                        </div>
                    </div>
                <?php endif; ?>

                <!-- Table Card -->
                <div class="card-bloom">
                    <div class="p-3 d-flex flex-wrap justify-content-between align-items-center bg-white border-bottom">
                        <div>
                            <h6 class="font-weight-bold mb-0 text-dark">
                                <?= $isSingle ? 'Selected Employee Payslip Record' : 'Employee Payslips Directory' ?>
                            </h6>
                            <small class="text-muted">
                                Total <?= !empty($payslips) ? count($payslips) : 0 ?> record(s) found for <?= $currentMonthName ?> <?= esc($selectedYear) ?>
                            </small>
                        </div>
                        <?php if ($isSingle): ?>
                            <div>
                                <span class="badge badge-info px-2 py-1" style="font-size: 11px;">
                                    <i class="fas fa-filter mr-1"></i> Filtered by Employee: <?= esc($selectedEmpId) ?>
                                </span>
                            </div>
                        <?php endif; ?>
                    </div>

                    <div class="table-responsive">
                        <table id="payslipsTable" class="table table-hover mb-0">
                            <thead class="bg-light">
                                <tr class="small text-uppercase text-muted">
                                    <th class="pl-4 border-0" style="width: 80px;">SNO</th>
                                    <th class="border-0" style="width: 200px;">EMPID</th>
                                    <th class="border-0">EMP NAME</th>
                                    <th class="text-right pr-4 border-0" style="width: 140px;">ACTION</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (!empty($payslips)): ?>
                                    <?php $i = 1; ?>
                                    <?php foreach ($payslips as $row): ?>
                                        <?php
                                        $colors = ['emp-purple', 'emp-green', 'emp-blue', 'emp-magenta'];
                                        $badge = $colors[($i - 1) % 4];

                                        $empId       = $row['emp_id'] ?? '';
                                        $empName     = $row['emp_name'] ?? '';
                                        $monthlyCtc  = $row['monthly_ctc'] ?? '0.00';
                                        $runStatus   = $row['run_status'] ?? 'FINALIZED';
                                        $payMonth    = $row['payroll_month'] ?? $selectedMonth;
                                        $payYear     = $row['payroll_year'] ?? $selectedYear;
                                        $remarks     = $row['remarks'] ?? 'Payslip retrieved successfully';
                                        $status      = $row['status'] ?? 'Y';
                                        ?>
                                        <tr class="employee-row">
                                            <!-- Column 1: SNO -->
                                            <td class="pl-4 align-middle font-weight-bold text-muted"><?= $i++; ?></td>

                                            <!-- Column 2: EMPID -->
                                            <td class="align-middle">
                                                <span class="emp-badge <?= $badge ?>">
                                                    <?= !empty($empId) ? esc($empId) : '-' ?>
                                                </span>
                                            </td>

                                            <!-- Column 3: EMP NAME -->
                                            <td class="align-middle">
                                                <span class="font-weight-600 text-dark">
                                                    <?= !empty($empName) ? esc($empName) : '-' ?>
                                                </span>
                                            </td>

                                            <!-- Column 4: ACTION (View, Edit, Delete) -->
                                            <td class="text-right pr-4 align-middle">
                                                <!-- View Icon -->
                                                <a href="javascript:void(0)" class="action-btn btn-view viewPayslip mr-1"
                                                    data-emp="<?= esc($empId); ?>"
                                                    data-name="<?= esc($empName); ?>"
                                                    data-ctc="<?= esc($monthlyCtc); ?>"
                                                    data-status="<?= esc($runStatus); ?>"
                                                    data-month="<?= esc($payMonth); ?>"
                                                    data-year="<?= esc($payYear); ?>"
                                                    data-remarks="<?= esc($remarks); ?>"
                                                    title="View Payslip">
                                                    <i class="fas fa-eye"></i>
                                                </a>

                                                <!-- Edit Icon -->
                                                <a href="javascript:void(0)" class="action-btn btn-edit editPayslip mr-1"
                                                    data-emp="<?= esc($empId); ?>"
                                                    data-name="<?= esc($empName); ?>"
                                                    data-ctc="<?= esc($monthlyCtc); ?>"
                                                    title="Edit">
                                                    <i class="fas fa-edit"></i>
                                                </a>

                                                <!-- Delete Icon -->
                                                <button type="button" class="action-btn btn-delete deletePayslip"
                                                    data-emp="<?= esc($empId); ?>"
                                                    data-name="<?= esc($empName); ?>"
                                                    title="Delete">
                                                    <i class="fas fa-trash-alt"></i>
                                                </button>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                <?php else: ?>
                                    <tr>
                                        <td colspan="4" class="text-center text-muted py-5">
                                            <i class="fas fa-folder-open fa-2x mb-2 text-muted d-block"></i>
                                            No Payslips Found for <?= $currentMonthName ?> <?= esc($selectedYear) ?>
                                        </td>
                                    </tr>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

            </section>
        </div>
    </div>

    <!-- View Payslip Quick Modal -->
    <div class="modal fade" id="viewPayslipModal" tabindex="-1" role="dialog" aria-labelledby="viewPayslipModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered" role="document">
            <div class="modal-content">
                <div class="modal-header d-flex justify-content-between align-items-center">
                    <h6 class="modal-title font-weight-bold" id="viewPayslipModalLabel" style="color: #0f172a;">
                        <i class="fas fa-receipt text-primary mr-2"></i>Payslip Overview
                    </h6>
                    <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <div class="modal-body p-4">
                    <div class="text-center mb-4 pb-3 border-bottom">
                        <h5 class="font-weight-bold mb-1" id="modalEmpName">-</h5>
                        <span class="emp-badge emp-purple" id="modalEmpId">-</span>
                    </div>

                    <div class="row">
                        <div class="col-6 mb-3">
                            <span class="text-muted small d-block">Payroll Month</span>
                            <strong id="modalMonth" class="text-dark">-</strong>
                        </div>
                        <div class="col-6 mb-3">
                            <span class="text-muted small d-block">Payroll Year</span>
                            <strong id="modalYear" class="text-dark">-</strong>
                        </div>
                        <div class="col-6 mb-3">
                            <span class="text-muted small d-block">Monthly CTC</span>
                            <strong id="modalCtc" class="text-success" style="font-size: 15px;">-</strong>
                        </div>
                        <div class="col-6 mb-3">
                            <span class="text-muted small d-block">Run Status</span>
                            <span id="modalStatus" class="badge-finalized">-</span>
                        </div>
                        <div class="col-12">
                            <span class="text-muted small d-block">Remarks</span>
                            <p id="modalRemarks" class="text-muted mb-0 small">-</p>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-sm btn-secondary rounded-pill px-3" data-dismiss="modal">Close</button>
                    <button type="button" class="btn btn-sm btn-primary rounded-pill px-3" onclick="window.print();" style="background: var(--bloom-purple); border: none;">
                        <i class="fas fa-print mr-1"></i> Print Payslip
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- Edit Payslip Modal -->
    <div class="modal fade" id="editPayslipModal" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered" role="document">
            <div class="modal-content">
                <div class="modal-header">
                    <h6 class="modal-title font-weight-bold">
                        <i class="fas fa-edit text-primary mr-2"></i>Edit Payslip Details
                    </h6>
                    <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <div class="modal-body p-4">
                    <p class="text-muted small mb-3">Modify payroll parameters for the selected employee.</p>
                    <div class="form-group">
                        <label class="small font-weight-bold">Employee</label>
                        <input type="text" id="editEmpDisplay" class="form-control form-control-sm" readonly>
                    </div>
                    <div class="form-group">
                        <label class="small font-weight-bold">Monthly CTC (₹)</label>
                        <input type="number" step="0.01" id="editMonthlyCtc" class="form-control form-control-sm" placeholder="Enter updated CTC">
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-sm btn-secondary rounded-pill px-3" data-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-sm btn-primary rounded-pill px-3" id="saveEditBtn" style="background: var(--bloom-purple); border: none;">Save Changes</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Delete Confirmation Modal -->
    <div class="modal fade" id="deletePayslipModal" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered" role="document">
            <div class="modal-content">
                <div class="modal-header">
                    <h6 class="modal-title font-weight-bold text-danger">
                        <i class="fas fa-exclamation-triangle mr-2"></i>Confirm Deletion
                    </h6>
                    <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <div class="modal-body p-4 text-center">
                    <i class="fas fa-trash-alt fa-3x text-danger mb-3"></i>
                    <h6 class="font-weight-bold mb-2">Are you sure you want to delete this payslip?</h6>
                    <p class="text-muted small mb-0" id="deleteConfirmMessage">This will remove the payslip record for the selected employee.</p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-sm btn-secondary rounded-pill px-3" data-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-sm btn-danger rounded-pill px-3" id="confirmDeleteBtn">Delete</button>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/toastr.js/latest/toastr.min.js"></script>

    <script>
        toastr.options = {
            closeButton: true,
            debug: false,
            newestOnTop: true,
            progressBar: true,
            positionClass: "toast-top-right",
            preventDuplicates: false,
            timeOut: 6000,
            extendedTimeOut: 2000,
            showMethod: "fadeIn",
            hideMethod: "fadeOut"
        };

        function showToast(title, message, type = 'success') {
            const t = (type || 'success').toString().toUpperCase();
            if (typeof toastr !== 'undefined') {
                toastr.options.positionClass = "toast-top-right";
                if (t === 'SUCCESS' || t === 'Y') {
                    toastr.success(message, title || 'Success');
                } else if (t === 'ERROR' || t === 'DANGER' || t === 'N') {
                    toastr.error(message, title || 'Notice');
                } else if (t === 'WARNING') {
                    toastr.warning(message, title || 'Warning');
                } else {
                    toastr.info(message, title || 'Notification');
                }
            }
        }

        $(document).ready(function () {
            <?php if (function_exists('session') && session()->getFlashdata('error')): ?>
                showToast('Error', <?= json_encode(session()->getFlashdata('error')) ?>, 'error');
            <?php endif; ?>

            <?php if (function_exists('session') && session()->getFlashdata('success')): ?>
                showToast('Success', <?= json_encode(session()->getFlashdata('success')) ?>, 'success');
            <?php endif; ?>

            <?php if (function_exists('session') && session()->getFlashdata('warning')): ?>
                showToast('Warning', <?= json_encode(session()->getFlashdata('warning')) ?>, 'warning');
            <?php endif; ?>

            <?php if (function_exists('session') && session()->getFlashdata('info')): ?>
                showToast('Info', <?= json_encode(session()->getFlashdata('info')) ?>, 'info');
            <?php endif; ?>
        });
    </script>

    <script>
        // Month name map for quick JS formatting
        const monthNames = {
            1: "January", 2: "February", 3: "March", 4: "April",
            5: "May", 6: "June", 7: "July", 8: "August",
            9: "September", 10: "October", 11: "November", 12: "December"
        };

        // VIEW ACTION:
        // Redirects to payroll/payslips_new with the emp_id of the selected row,
        // and the month & year from the common filters.
        $(document).on('click', '.viewPayslip', function () {
            var empid = $(this).data('emp');
            var month = $('#commonMonthFilter').val();
            var year  = $('#commonYearFilter').val();

            if (!empid) {
                showToast('Warning', 'Employee ID not found', 'warning');
                return;
            }

            // Redirects to employee/new_emp_payslip with empid, month, and year
            window.location.href = "<?= base_url('employee/new_emp_payslip') ?>/" 
                + encodeURIComponent(empid) 
                + "/" + encodeURIComponent(month) 
                + "/" + encodeURIComponent(year);
        });

        // EDIT ACTION:
        $(document).on('click', '.editPayslip', function () {
            var empid = $(this).data('emp');
            var empname = $(this).data('name');
            var ctc = $(this).data('ctc');

            $('#editEmpDisplay').val(empname + ' (' + empid + ')');
            $('#editMonthlyCtc').val(ctc);
            $('#editPayslipModal').modal('show');
        });

        $('#saveEditBtn').on('click', function () {
            showToast('Success', 'Salary parameters updated for review.', 'success');
            $('#editPayslipModal').modal('hide');
        });

        // DELETE ACTION:
        $(document).on('click', '.deletePayslip', function () {
            var empid = $(this).data('emp');
            var empname = $(this).data('name');

            $('#deleteConfirmMessage').text('Are you sure you want to remove payslip record for ' + empname + ' (' + empid + ')?');
            $('#deletePayslipModal').modal('show');
        });

        $('#confirmDeleteBtn').on('click', function () {
            showToast('Success', 'Payslip record removed successfully.', 'success');
            $('#deletePayslipModal').modal('hide');
        });

        // Auto-submit filter on common month or year change if desired
        $('#commonMonthFilter, #commonYearFilter').on('change', function () {
            $('#commonFilterForm').submit();
        });

        // Initialize DataTable
        $('#payslipsTable').DataTable({
            paging: true,
            ordering: true,
            searching: true,
            info: true,
            lengthChange: true,
            pageLength: 10,
            dom: '<"top"lf>rt<"bottom"ip><"clear">',
            language: {
                search: "_INPUT_",
                searchPlaceholder: "Search employee ID or name..."
            }
        });
    </script>
</body>

</html>

