<?php
// Capture is_s1 flag passed from controller or query param
$is_s1 = !empty($is_s1) ? 1 : (!empty($_GET['s1']) ? 1 : 0);
$selectedMonth = isset($selectedMonth) ? (int) $selectedMonth : (int) ($_GET['month'] ?? date('m'));
$selectedYear  = isset($selectedYear) ? (int) $selectedYear : (int) ($_GET['year'] ?? date('Y'));
$records       = isset($records) ? $records : [];

// Generate Attendance URL (preserve s1 only if it exists)
$generateAttUrl = base_url('admin/attendance_overview') . '?month=' . (int) $selectedMonth . '&year=' . (int) $selectedYear;
if ($is_s1) {
    $generateAttUrl .= '&s1=1';
}

// Opened from a payroll cycle (?cycle=ID): after finalizing, go back to that cycle.
// The id is checked on the server (finalize_payroll_attendance) before it is used.
$return_cycle = (int) ($return_cycle ?? ($_GET['cycle'] ?? 0));
if ($return_cycle > 0) {
    $generateAttUrl .= '&cycle=' . $return_cycle;
}

$attendanceStatus = strtoupper(trim((string) ($attendance_status ?? 'N')));
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Bloom Solutions | Attendance Cycle Finalization</title>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <style>
        :root {
            --purple: #4a00e0;
            --dark: #2a0080;
            --bg: #f5f7fc;
            --text: #1e293b;
            --muted: #64748b;
            --line: #e2e8f0;
            --green: #059669;
            --red: #e11d48;
            --blue: #2563eb;
            --bloom-purple: #4a00e0;
            --bloom-dark: #2a0080;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            background: var(--bg);
            font-family: 'Plus Jakarta Sans', sans-serif;
            font-size: 12px;
            color: var(--text);
        }
        .content-wrapper {
            margin-left: 250px;
            min-height: 100vh;
        }
        .content-wrapper > .content-header,
        .content-wrapper > .content-header > .container-fluid {
            padding: 0 !important;
            margin: 0 !important;
            width: 100%;
            max-width: 100%;
        }
        .page {
            width: 100%;
            padding: 18px 16px 24px;
        }
        .top-panel {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 18px;
            flex-wrap: wrap;
            padding: 18px 20px;
            margin-bottom: 16px;
            background: #fff;
            border: 1px solid #edf0f6;
            border-radius: 16px;
            box-shadow: 0 3px 12px rgba(15, 23, 42, .025);
        }
        .title-wrap {
            display: flex;
            align-items: center;
            gap: 12px;
            min-width: 220px;
        }
        .title-icon {
            width: 42px;
            height: 42px;
            display: grid;
            place-items: center;
            flex: 0 0 42px;
            background: linear-gradient(135deg, #6d5dfc, var(--purple));
            border-radius: 12px;
            color: #fff;
            font-size: 17px;
        }
        .title-wrap h1 {
            margin: 0;
            color: #172033;
            font-size: 18px;
            line-height: 1.35;
            font-weight: 800;
        }
        .title-wrap p {
            margin: 4px 0 0;
            color: var(--muted);
            font-size: 11px;
        }
        .controls {
            display: flex;
            align-items: center;
            gap: 9px;
            flex-wrap: wrap;
        }
        .field-group {
            display: flex;
            align-items: center;
            gap: 7px;
            padding: 8px 10px;
            background: #f8fafc;
            border: 1px solid #eef2f7;
            border-radius: 9px;
            color: var(--muted);
            font-size: 11px;
        }
        .field-group label { margin: 0; color: #64748b; font-size: 10px; font-weight: 800; letter-spacing: .4px; }
        .field-group i { color: #7c6af4; }
        .field-group select {
            border: 0;
            outline: 0;
            background: transparent;
            color: #334155;
            font: 700 11px 'Plus Jakarta Sans';
        }
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            border-radius: 9px;
            padding: 10px 13px;
            font: 700 11px 'Plus Jakarta Sans';
            white-space: nowrap;
        }
        .btn-primary {
            background: linear-gradient(135deg, #6254f4, var(--purple));
            border-color: transparent;
            color: #fff;
        }
        .btn-bloom-back {
            padding: 8px 18px;
            background: #fff;
            border: 1px solid var(--bloom-purple);
            border-radius: 10px;
            color: var(--bloom-purple) !important;
            font-size: 12px;
            font-weight: 700;
        }
        .btn-bloom-back:hover {
            background: linear-gradient(135deg, var(--bloom-purple), var(--bloom-dark));
            color: #fff !important;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 12px;
            margin-bottom: 18px;
        }
        .stat {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
            min-height: 104px;
            padding: 15px;
            background: #fff;
            border: 1px solid #edf0f6;
            border-radius: 15px;
            box-shadow: 0 3px 10px rgba(15, 23, 42, .025);
        }
        .stat-label {
            max-width: 125px;
            color: var(--muted);
            font-size: 9px;
            font-weight: 800;
            letter-spacing: .35px;
            text-transform: uppercase;
        }
        .stat-value {
            margin-top: 5px;
            color: #172033;
            font-size: 24px;
            font-weight: 800;
        }
        .stat-value small {
            color: var(--muted);
            font-size: 11px;
            font-weight: 600;
        }
        .stat-note {
            margin-top: 6px;
            color: var(--muted);
            font-size: 9px;
        }
        .stat-note.green { color: var(--green); }
        .stat-icon {
            width: 38px;
            height: 38px;
            display: grid;
            place-items: center;
            flex: 0 0 38px;
            background: #eef2ff;
            border-radius: 12px;
            color: var(--purple);
        }
        .stat:nth-child(2) .stat-icon { background: #faf0ff; color: #a855f7; }
        .stat:nth-child(3) .stat-icon { background: #eef2ff; color: #4f46e5; }
        .stat:nth-child(4) .stat-icon { background: #fff8e7; color: #d97706; }
        .table-card {
            width: 100%;
            overflow: hidden;
            background: #fff;
            border: 1px solid #e8edf5;
            border-radius: 15px;
            box-shadow: 0 3px 12px rgba(15, 23, 42, .025);
        }
        .table-scroll {
            width: 100%;
            overflow-x: auto;
        }
        #attendanceTable {
            width: 100% !important;
            min-width: 1080px;
            margin: 0 !important;
        }
        #attendanceTable thead th {
            padding: 13px 10px;
            border-bottom: 1px solid #e6ebf3;
            border-right: 1px solid #edf1f7;
            color: #475569;
            font-size: 9px;
            font-weight: 800;
            letter-spacing: .35px;
            text-align: center;
            text-transform: uppercase;
            white-space: nowrap;
        }
        #attendanceTable thead tr.group-head th {
            padding: 8px 10px !important;
            font-size: 11px !important;
        }
        #attendanceTable thead .baseline {
            background: #ede9fe !important;
            color: #6d28d9 !important;
        }
        #attendanceTable thead .activity {
            background: #dbeafe !important;
            color: #2563eb !important;
        }
        #attendanceTable thead .payroll {
            background: #dcfce7 !important;
            color: #047857 !important;
        }
        #attendanceTable thead tr.labels th {
            padding-top: 14px !important;
            padding-bottom: 14px !important;
            font-size: 11px !important;
        }
        #attendanceTable thead tr.labels th:nth-child(2),
        #attendanceTable thead tr.labels th:nth-child(3) {
            background: #ede9fe !important;
        }
        #attendanceTable thead tr.labels th:nth-child(4),
        #attendanceTable thead tr.labels th:nth-child(5),
        #attendanceTable thead tr.labels th:nth-child(6),
        #attendanceTable thead tr.labels th:nth-child(7),
        #attendanceTable thead tr.labels th:nth-child(8) {
            background: #dbeafe !important;
        }
        #attendanceTable thead tr.labels th:nth-child(9),
        #attendanceTable thead tr.labels th:nth-child(10) {
            background: #dcfce7 !important;
        }
        #attendanceTable tbody td {
            padding: 12px 10px !important;
            border-bottom: 1px solid #f0f3f8;
            font-size: 12px !important;
            text-align: center;
            vertical-align: middle;
            white-space: nowrap;
        }
        #attendanceTable tbody td:first-child {
            padding-left: 17px !important;
            text-align: left;
        }
        #attendanceTable tbody td:nth-child(2),
        #attendanceTable tbody td:nth-child(3) {
            background: #f5f3ff !important;
        }
        #attendanceTable tbody td:nth-child(4),
        #attendanceTable tbody td:nth-child(5),
        #attendanceTable tbody td:nth-child(6),
        #attendanceTable tbody td:nth-child(7),
        #attendanceTable tbody td:nth-child(8) {
            background: #eff6ff !important;
        }
        #attendanceTable tbody td:nth-child(9),
        #attendanceTable tbody td:nth-child(10) {
            background: #f0fdf4 !important;
        }
        .employee {
            display: flex;
            align-items: center;
            gap: 9px;
            min-width: 165px;
        }
        .avatar {
            width: 30px;
            height: 30px;
            display: grid;
            place-items: center;
            flex: 0 0 30px;
            background: #ede9fe;
            border-radius: 50%;
            color: #6d28d9;
            font-size: 10px;
            font-weight: 800;
        }
        .employee-details {
            display: flex;
            flex-direction: column;
            gap: 2px;
        }
        .emp-name {
            color: #334155;
            font-size: 12px;
            font-weight: 700;
        }
        .emp-id {
            color: var(--muted);
            font-size: 11px;
        }
        .number { color: #334155; font-weight: 800; }
        .present, .paid { color: var(--green); font-weight: 800; }
        .leave, .unpaid { color: var(--red); font-weight: 800; }
        .wfh { color: var(--blue); font-weight: 800; }
        .dataTables_wrapper {
            width: 100%;
            margin: 0 !important;
            padding: 0 !important;
        }
        .dataTables_wrapper .row {
            margin: 0 !important;
        }
        .dataTables_wrapper .row:first-child {
            padding: 8px 12px !important;
        }
        .dataTables_length,
        .dataTables_filter {
            margin: 0 !important;
            color: var(--muted);
            font-size: 12px;
            font-weight: 600;
        }
        .dataTables_length select,
        .dataTables_filter input {
            height: 30px !important;
            border: 1px solid #e2e8f0 !important;
            border-radius: 8px !important;
        }
        .dataTables_length select {
            min-width: 58px;
            margin: 0 4px !important;
            padding: 3px 6px !important;
        }
        .dataTables_filter input {
            margin-left: 5px !important;
            padding: 4px 9px !important;
        }
        .dataTables_info {
            padding-left: 15px;
            color: var(--muted) !important;
            font-size: 12px;
            font-weight: 600;
        }
        .dataTables_paginate {
            padding-right: 15px;
        }
        .dataTables_paginate .paginate_button {
            margin: 0 3px !important;
        }
        .dataTables_paginate .page-link {
            border: 1px solid #e2e8f0 !important;
            border-radius: 10px !important;
            color: var(--muted) !important;
            font-weight: 600;
        }
        .dataTables_paginate .page-item.active .page-link {
            background: linear-gradient(135deg, var(--purple), var(--dark)) !important;
            border-color: var(--purple) !important;
            color: #fff !important;
        }
        .bloom-swal-popup {
            border-radius: 16px !important;
            font-family: 'Plus Jakarta Sans', sans-serif !important;
        }
        .bloom-swal-title {
            color: #172033 !important;
            font-size: 20px !important;
            font-weight: 800 !important;
        }
        .bloom-swal-text {
            color: var(--muted) !important;
            font-size: 12px !important;
        }
        .bloom-swal-confirm,
        .bloom-swal-cancel {
            border-radius: 9px !important;
            font-size: 12px !important;
            font-weight: 700 !important;
        }
        @media (max-width: 1100px) {
            .summary { grid-template-columns: repeat(2, 1fr); }
        }
        @media (max-width: 991.98px) {
            .content-wrapper { margin-left: 0 !important; }
        }
        @media (max-width: 700px) {
            .page { padding: 15px 12px 24px; }
            .summary { gap: 9px; }
            .stat { padding: 12px; min-height: 95px; }
            .stat-value { font-size: 21px; }
            .title-wrap h1 { font-size: 16px; }
            .controls { width: 100%; }
            .field-group, .controls .btn { flex: 1; }
            .dataTables_wrapper .row:first-child {
                flex-direction: column;
                gap: 8px;
            }
            .dataTables_filter { text-align: left !important; }
        }
    </style>
</head>
<body class="hold-transition sidebar-mini layout-fixed">
<div class="wrapper">
    <div class="content-wrapper">
        <div class="content-header">
            <div class="container-fluid">
                <div class="page">
                    
                    <!-- Header -->
                    <section class="top-panel">
                        <div class="title-wrap">
                            <div class="title-icon">
                                <i class="fa-solid fa-clipboard-check"></i>
                            </div>
                            <div>
                                <h1>Attendance Cycle<br>Finalization</h1>
                                <p>Review employee attendance before locking payroll inputs.</p>
                            </div>
                        </div>
                        <div class="controls">
                            <div class="field-group">
                                <label for="month">MONTH</label>
                                <select id="month" name="month" class="form-control">
                                    <?php for ($m = 1; $m <= 12; $m++): ?>
                                        <option value="<?= $m ?>"
                                            <?= ((int) $selectedMonth === $m) ? 'selected' : '' ?>>
                                            <?= date('F', mktime(0, 0, 0, $m, 1)) ?>
                                        </option>
                                    <?php endfor; ?>
                                </select>
                            </div>
                            <div class="field-group">
                                <label for="year">YEAR</label>
                                <select id="year" name="year" class="form-control">
                                    <?php
                                    $currentYear = (int) date('Y');
                                    for ($y = $currentYear - 2; $y <= $currentYear + 1; $y++):
                                    ?>
                                        <option value="<?= $y ?>"
                                            <?= ((int) $selectedYear === $y) ? 'selected' : '' ?>>
                                            <?= $y ?>
                                        </option>
                                    <?php endfor; ?>
                                </select>
                            </div>
                            <div>
                                <a href="<?= $generateAttUrl ?>" class="btn btn-primary">
                                    <i class="fas fa-calendar-plus mr-1"></i>
                                    Generate Attendance
                                </a>
                            </div>

                            <div class="col-auto ml-auto text-muted small">
                                <?php if ($attendanceStatus === 'Y' || !empty($is_finalized)): ?>
                                    <span class="badge badge-success px-3 py-2" style="font-size:14px;">
                                        <i class="fas fa-check-circle mr-1"></i> Finalized
                                    </span>
                                    <button type="button"
                                            class="btn font-weight-bold px-3 ml-2"
                                            style="border-radius:8px; background:#fff; border:1px solid #e11d48; color:#e11d48;"
                                            id="unfinalizeBtn"
                                            title="Unlock this month's attendance so it can be corrected or generated again">
                                        <i class="fas fa-lock-open mr-1"></i> Unfinalize
                                    </button>
                                <?php elseif (empty($records)): ?>
                                    <button type="button"
                                            class="btn font-weight-bold px-3"
                                            style="border-radius:8px; background:#cbd5e1; color:#475569; cursor:not-allowed;"
                                            disabled
                                            title="Generate attendance before finalizing">
                                        <i class="fas fa-lock mr-1"></i> Finalize Attendance
                                    </button>
                                <?php else: ?>
                                    <button type="button"
                                            class="btn font-weight-bold px-4"
                                            style="border-radius:8px; background:#f59e0b; border-color:#f59e0b; color:#fff;"
                                            id="finalizeBtn">
                                        <i class="fas fa-lock mr-1"></i> Finalize Attendance
                                    </button>
                                <?php endif; ?>
                            </div>
                        </div>
                    </section>

                    <!-- Summary -->
                    <section class="summary">
                        <div class="stat">
                            <div>
                                <div class="stat-label">Total Staff in Cycle</div>
                                <div class="stat-value"><?= !empty($records) ? count($records) : 0 ?></div>
                                <div class="stat-note green">
                                    <i class="fa-solid fa-circle-check"></i> Attendance Records
                                </div>
                            </div>
                            <div class="stat-icon"><i class="fa-solid fa-users"></i></div>
                        </div>
                        <div class="stat">
                            <div>
                                <div class="stat-label">Total Period</div>
                                <div class="stat-value">
                                    <?= !empty($records) ? floatval($records[0]['total_days'] ?? 0) : 0 ?>
                                    <small>Days</small>
                                </div>
                                <div class="stat-note">Attendance Cycle</div>
                            </div>
                            <div class="stat-icon"><i class="fa-regular fa-calendar"></i></div>
                        </div>
                        <div class="stat">
                            <div>
                                <div class="stat-label">Working Days</div>
                                <div class="stat-value">
                                    <?= !empty($records) ? floatval($records[0]['working_days'] ?? 0) : 0 ?>
                                    <small>Days</small>
                                </div>
                                <div class="stat-note">Excludes off-days</div>
                            </div>
                            <div class="stat-icon"><i class="fa-solid fa-calendar-check"></i></div>
                        </div>
                        <div class="stat">
                            <div>
                                <div class="stat-label">Holidays &amp; Offs</div>
                                <div class="stat-value">
                                    <?= !empty($records)
                                        ? floatval($records[0]['holiday_days'] ?? 0) + floatval($records[0]['weekly_off_days'] ?? 0)
                                        : 0 ?>
                                    <small>Days</small>
                                </div>
                                <div class="stat-note">Holidays + Weekly Offs</div>
                            </div>
                            <div class="stat-icon"><i class="fa-solid fa-umbrella-beach"></i></div>
                        </div>
                    </section>

                    <!-- Attendance Table -->
                    <section class="table-card">
                        <div class="table-scroll">
                            <table id="attendanceTable" class="table table-bordered table-hover">
                            <thead>
                                <tr class="group-head">
                                    <th>EMPLOYEE PROFILE</th>
                                    <th colspan="2" class="baseline">CYCLE BASELINE</th>
                                    <th colspan="5" class="activity"><i class="fa-regular fa-calendar-check"></i>&nbsp; ATTENDANCE ACTIVITY BREAKDOWN</th>
                                    <th colspan="2" class="payroll"><i class="fa-solid fa-money-check-dollar"></i>&nbsp; PAYROLL RECONCILIATION</th>
                                </tr>
                                <tr class="labels">
                                    <th>Employee &amp; ID</th><th>Total Period</th><th>Holidays &amp; Offs</th><th>Working Days</th><th>Present</th><th>Leave</th><th>Absent</th><th>WFH</th><th>Paid Days</th><th>Unpaid / LOP</th>
                                </tr>
                            </thead>
                            <tbody>
                            <?php if (!empty($records)): ?>
                                <?php foreach ($records as $row):
                                    $empName = trim($row['emp_name'] ?? '');
                                    $empId = trim($row['emp_id'] ?? '');
                                    $parts = preg_split('/\s+/', $empName);
                                    $initials = count($parts) > 1 ? strtoupper(substr($parts[0], 0, 1) . substr(end($parts), 0, 1)) : strtoupper(substr($empName, 0, 2));
                                ?>
                                    <tr>
                                        <td><div class="employee"><span class="avatar"><?= esc($initials) ?></span><span class="employee-details"><span class="emp-name"><?= esc($empName) ?></span><span class="emp-id"><?= esc($empId) ?></span></span></div></td>
                                        <td class="number"><?= floatval($row['total_days'] ?? 0) ?></td>
                                        <td><?= floatval($row['holiday_days'] ?? 0) + floatval($row['weekly_off_days'] ?? 0) ?></td>
                                        <td class="number"><?= floatval($row['working_days'] ?? 0) ?></td>
                                        <td class="present"><?= floatval($row['present_days'] ?? 0) ?></td>
                                        <td class="leave"><?= floatval($row['leave_days'] ?? 0) ?></td>
                                        <td><?= floatval($row['absent_days'] ?? 0) ?></td>
                                        <td class="wfh"><?= floatval($row['wfh_days'] ?? 0) ?></td>
                                        <td class="paid"><?= floatval($row['paid_days'] ?? 0) ?></td>
                                        <td class="unpaid"><?= floatval($row['unpaid_days'] ?? 0) ?></td>
                                    </tr>
                                <?php endforeach; ?>
                            <?php else: ?>
                                <tr>
                                    <td colspan="10" class="text-center py-4 text-muted">
                                        <i class="fas fa-info-circle mr-1"></i> No payroll attendance records found. 
                                        <a href="<?= $generateAttUrl ?>" class="text-primary font-weight-bold ml-1">Generate Attendance</a> first.
                                    </td>
                                </tr>
                            <?php endif; ?>
                        </tbody>
                        </table>
                        </div>
                    </section>

                    <!-- Back Button: routes back to step1 with s1 if active, or browser history if standard -->
                    <div class="mt-3">
                        <?php if ($return_cycle > 0): ?>
                            <a href="<?= base_url('payroll/cycle/' . $return_cycle) ?>" class="btn btn-bloom-back">
                                <i class="fas fa-arrow-left mr-1"></i> Back to payroll cycle
                            </a>
                        <?php elseif ($is_s1): ?>
                            <a href="<?= base_url('payroll/step1') ?>?month=<?= (int)$selectedMonth ?>&year=<?= (int)$selectedYear ?>&s1=1" class="btn btn-bloom-back">
                                <i class="fas fa-arrow-left mr-1"></i> Back to Step 1
                            </a>
                        <?php else: ?>
                            <button type="button" class="btn btn-bloom-back" onclick="window.history.back();">
                                <i class="fas fa-arrow-left mr-1"></i> Back
                            </button>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>

<script>
$(document).ready(function () {
    if ($('#attendanceTable tbody tr td').length > 1) {
        $('#attendanceTable').DataTable({
            responsive: false,
            paging: true,
            ordering: true,
            order: [],
            searching: true,
            info: true,
            lengthChange: true,
            pageLength: 10,
            lengthMenu: [[10, 25, 50, 100], [10, 25, 50, 100]],
            language: {
                search: 'Search:',
                lengthMenu: 'Show _MENU_ entries',
                info: 'Showing _START_ to _END_ of _TOTAL_ employees',
                infoEmpty: 'No employees available',
                emptyTable: 'No payroll attendance records available for this period.',
                zeroRecords: 'No matching attendance records found'
            },
            dom: "<'row'<'col-md-6'l><'col-md-6'f>>t<'row'<'col-md-6'i><'col-md-6'p>>"
        });
    }

    $('#finalizeBtn').on('click', function () {
        const button = $(this);
        Swal.fire({
            title: 'Finalize Attendance?',
            text: 'Are you sure you want to finalize attendance for this month? This action cannot be undone.',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#059669',
            cancelButtonColor: '#e11d48',
            confirmButtonText: 'Yes, Finalize',
            cancelButtonText: 'Cancel',
            reverseButtons: true,
            customClass: {
                popup: 'bloom-swal-popup',
                title: 'bloom-swal-title',
                htmlContainer: 'bloom-swal-text',
                confirmButton: 'bloom-swal-confirm',
                cancelButton: 'bloom-swal-cancel'
            }
        }).then(function (result) {
            if (!result.isConfirmed) return;
            button.prop('disabled', true)
                .html('<i class="fa-solid fa-spinner fa-spin"></i> Finalizing...');

            $.ajax({
                url: '<?= base_url('admin/finalize_payroll_attendance') ?>',
                type: 'POST',
                dataType: 'json',
                data: {
                    month: '<?= (int)$selectedMonth ?>',
                    year: '<?= (int)$selectedYear ?>',
                    s1: '<?= (int)$is_s1 ?>',
                    cycle: '<?= (int)$return_cycle ?>',
                    action: 'FINALIZE',
                    '<?= csrf_token() ?>': '<?= csrf_hash() ?>'
                },
                success: function (res) {
                    if (res && (res.status === 'Y' || res.status === true || res.status == 1)) {
                        button.removeClass('btn-primary')
                            .addClass('btn-success')
                            .html('<i class="fa-solid fa-check"></i> Attendance Finalized');

                        Swal.fire({
                            icon: 'success',
                            title: 'Finalized!',
                            text: res.message || 'Attendance has been finalized successfully.',
                            confirmButtonColor: '#059669'
                        }).then(function () {
                            // If returning from s1 flow, redirect back to step1 with complete=1
                            if (res.redirect_url) {
                                window.location.href = res.redirect_url;
                            } else {
                                // Normal flow: stay in attendance module
                                location.reload();
                            }
                        });
                    } else {
                        resetFinalizeButton(button);
                        Swal.fire({
                            icon: 'error',
                            title: 'Unable to Finalize',
                            text: res.message || 'Attendance could not be finalized.',
                            confirmButtonColor: '#4a00e0'
                        });
                    }
                },
                error: function (xhr) {
                    resetFinalizeButton(button);
                    Swal.fire({
                        icon: 'error',
                        title: 'Something went wrong',
                        text: xhr.responseJSON?.message || 'An error occurred while finalizing attendance.',
                        confirmButtonColor: '#4a00e0'
                    });
                }
            });
        });
    });

    // Unfinalize: the same procedure as finalize, with action UNFINALIZE
    $('#unfinalizeBtn').on('click', function () {
        const button = $(this);
        Swal.fire({
            title: 'Unfinalize Attendance?',
            html: 'Attendance for this month will be unlocked so it can be corrected or generated again. Finalize again when you are done.<br><br>' +
                  'If the payroll cycle of this month has verified attendance or salary structures, it goes back to <b>Open</b>.<br>' +
                  'It is refused once salaries are calculated (go back on the payroll cycle page first) or the payroll is finalized.',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#e11d48',
            cancelButtonColor: '#64748b',
            confirmButtonText: 'Yes, Unfinalize',
            cancelButtonText: 'Cancel',
            reverseButtons: true,
            customClass: {
                popup: 'bloom-swal-popup',
                title: 'bloom-swal-title',
                htmlContainer: 'bloom-swal-text',
                confirmButton: 'bloom-swal-confirm',
                cancelButton: 'bloom-swal-cancel'
            }
        }).then(function (result) {
            if (!result.isConfirmed) return;
            const original = button.html();
            button.prop('disabled', true)
                .html('<i class="fa-solid fa-spinner fa-spin"></i> Unfinalizing...');

            $.ajax({
                url: '<?= base_url('admin/finalize_payroll_attendance') ?>',
                type: 'POST',
                dataType: 'json',
                data: {
                    month: '<?= (int)$selectedMonth ?>',
                    year: '<?= (int)$selectedYear ?>',
                    s1: '<?= (int)$is_s1 ?>',
                    cycle: '<?= (int)$return_cycle ?>',
                    action: 'UNFINALIZE',
                    '<?= csrf_token() ?>': '<?= csrf_hash() ?>'
                },
                success: function (res) {
                    if (res && (res.status === 'Y' || res.status === true || res.status == 1)) {
                        Swal.fire({
                            icon: 'success',
                            title: 'Unfinalized',
                            text: res.message || 'Attendance has been unfinalized.',
                            confirmButtonColor: '#059669'
                        }).then(function () { location.reload(); });
                    } else {
                        button.prop('disabled', false).html(original);
                        Swal.fire({
                            icon: 'error',
                            title: 'Unable to Unfinalize',
                            text: res.message || 'Attendance could not be unfinalized.',
                            confirmButtonColor: '#4a00e0'
                        });
                    }
                },
                error: function (xhr) {
                    button.prop('disabled', false).html(original);
                    Swal.fire({
                        icon: 'error',
                        title: 'Something went wrong',
                        text: xhr.responseJSON?.message || 'An error occurred while unfinalizing attendance.',
                        confirmButtonColor: '#4a00e0'
                    });
                }
            });
        });
    });

    function resetFinalizeButton(button) {
        button.prop('disabled', false)
            .removeClass('btn-success')
            .addClass('btn-primary')
            .html('<i class="fa-solid fa-lock"></i> Finalize Attendance');
    }
});

$('#month, #year').on('change', function () {
    const month = $('#month').val();
    const year  = $('#year').val();
    const url   = new URL(window.location.origin + window.location.pathname);
    url.searchParams.set('month', month);
    url.searchParams.set('year', year);
    <?php if ($is_s1): ?>
    url.searchParams.set('s1', '1');
    <?php endif; ?>
    window.location.href = url.toString();
});
</script>
</body>
</html>