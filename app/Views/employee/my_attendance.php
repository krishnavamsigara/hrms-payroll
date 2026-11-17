
<?php
$attendance = $attendance ?? [];
$holiday = $holiday ?? [];

/*
 * $attendance contains all attendance rows.
 *
 * First row contains employee details + monthly summary.
 * Every row contains individual attendance details.
 */
$summary = !empty($attendance) ? $attendance[0] : [];

/* Employee Details */
$empId = $summary['emp_id'] ?? '-';
$empName = $summary['emp_name'] ?? '-';
$reportingToName = $summary['reporting_to_name'] ?? '-';
$companyName = $summary['company_name'] ?? '-';

/* Payroll Period */
$periodStart = $summary['period_start'] ?? null;
$periodEnd = $summary['period_end'] ?? null;
$calculatedUntil = $summary['calculated_until'] ?? null;

/* Monthly Summary */
$monthlyTotalHours = (float)($summary['monthly_total_hours_decimal'] ?? 0);
$monthlyWorkedDays = (int)($summary['monthly_total_worked_days'] ?? 0);

$totalDays = (int)($summary['total_days'] ?? 0);
$workingDays = (int)($summary['working_days'] ?? 0);
$presentDays = (int)($summary['present_days'] ?? 0);
$absentDays = (int)($summary['absent_days'] ?? 0);
$holidayDays = (int)($summary['holidays'] ?? 0);
$leaveDays = (int)($summary['leave_days'] ?? 0);
$wfhDays = (int)($summary['wfh_days'] ?? 0);

/* Average Daily Hours */
$avgDailyHours = $monthlyWorkedDays > 0
    ? round($monthlyTotalHours / $monthlyWorkedDays, 1)
    : 0;

/* Attendance Percentage */
$attendancePercentage = $workingDays > 0
    ? round(($presentDays + $wfhDays) / $workingDays * 100)
    : 0;
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <title>Bloom Solutions | Employee Timesheet</title>

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
            --bloom-purple-light: #eef2ff;
            --bloom-dark: #120038;
            --bloom-success: #10b981;
            --bloom-danger: #dc2626;
            --bloom-warning: #f59e0b;
            --bloom-blue: #2563eb;

            --slate-50: #f8fafc;
            --slate-100: #f1f5f9;
            --slate-200: #e2e8f0;
            --slate-300: #cbd5e1;
            --slate-400: #94a3b8;
            --slate-500: #64748b;
            --slate-600: #475569;
            --slate-700: #334155;
            --slate-800: #1e293b;
            --slate-900: #0f172a;
        }

        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: var(--slate-50);
            font-size: 13px;
            color: var(--slate-700);
        }

        .content-wrapper {
            background-color: var(--slate-50);
            padding-bottom: 25px !important;
        }

        .page-title {
            font-size: 22px;
            font-weight: 800;
            color: var(--slate-900);
            margin-bottom: 2px;
        }

        .page-subtitle {
            font-size: 12px;
            color: var(--slate-500);
            margin-bottom: 0;
        }

        .filter-input {
            border: 1px solid var(--slate-200);
            border-radius: 10px;
            height: 38px;
            font-size: 12px;
            font-weight: 500;
            color: var(--slate-700);
            background-color: #ffffff;
            padding: 0 12px;
        }

        .ts-card {
            background: #ffffff;
            border: 1px solid var(--slate-200);
            border-radius: 16px;
            padding: 18px;
            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02);
            height: 100%;
        }

        .ts-card:hover {
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.04);
        }

        .profile-avatar {
            width: 76px;
            height: 76px;
            border-radius: 50%;
            object-fit: cover;
            border: 3px solid #ffffff;
            box-shadow: 0 4px 10px rgba(0, 0, 0, 0.08);
        }

        .emp-id-badge {
            color: var(--bloom-purple);
            font-size: 12px;
            font-weight: 700;
        }

        .role-badge {
            background-color: var(--slate-100);
            color: var(--slate-600);
            font-size: 11px;
            font-weight: 600;
            padding: 5px 12px;
            border-radius: 20px;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }

        .profile-meta-title {
            font-size: 9px;
            font-weight: 700;
            color: var(--slate-400);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .profile-meta-value {
            font-size: 12px;
            font-weight: 700;
            color: var(--slate-800);
        }

        .stat-icon-box {
            width: 38px;
            height: 38px;
            border-radius: 10px;
            background-color: var(--bloom-purple-light);
            color: var(--bloom-purple);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
        }

        .stat-badge {
            background: var(--slate-100);
            color: var(--slate-600);
            font-weight: 700;
            font-size: 10px;
            padding: 3px 8px;
            border-radius: 6px;
        }

        .stat-label {
            font-size: 10px;
            font-weight: 700;
            color: var(--slate-400);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 2px;
        }

        .stat-value {
            font-size: 24px;
            font-weight: 800;
            color: var(--slate-900);
            line-height: 1.2;
        }

        .stat-unit {
            font-size: 13px;
            font-weight: 500;
            color: var(--slate-500);
        }

        .summary-title {
            font-size: 10px;
            font-weight: 700;
            color: var(--slate-400);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .summary-date-range {
            font-size: 11px;
            font-weight: 600;
            color: var(--slate-500);
        }

        .summary-grid {
            display: flex;
            justify-content: space-between;
            align-items: center;
            text-align: center;
            padding: 6px 0;
        }

        .summary-col {
            flex: 1;
            border-right: 1px solid var(--slate-200);
            padding: 0 4px;
        }

        .summary-col:last-child {
            border-right: none;
        }

        .summary-item-label {
            font-size: 9px;
            font-weight: 700;
            color: var(--slate-400);
            text-transform: uppercase;
            letter-spacing: 0.3px;
            margin-bottom: 4px;
        }

        .summary-item-val {
            font-size: 16px;
            font-weight: 800;
            color: var(--slate-800);
        }

        .text-present {
            color: #15803d !important;
        }

        .text-absent {
            color: #b91c1c !important;
        }

        .text-holiday {
            color: #6d28d9 !important;
        }

        .text-leave {
            color: #b45309 !important;
        }

        .text-wfh {
            color: #1d4ed8 !important;
        }

        .cal-header-title {
            font-size: 14px;
            font-weight: 700;
            color: var(--slate-800);
        }

        .cal-month-link {
            color: var(--bloom-blue);
            font-weight: 600;
            font-size: 13px;
        }

        .cal-grid {
            display: grid;
            grid-template-columns: repeat(7, 1fr);
            gap: 6px;
        }

        .cal-day-name {
            text-align: center;
            font-size: 11px;
            font-weight: 700;
            color: var(--slate-400);
            padding: 4px 0;
        }

        .cal-day-cell {
            height: 40px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 700;
            font-size: 12px;
            cursor: pointer;
            transition: all 0.2s ease;
            position: relative;
        }

        .cal-day-cell:hover {
            transform: scale(1.05);
        }

        .cal-day-cell.empty-cell {
            cursor: default;
            background: transparent;
        }

        .cal-day-cell.p-present {
            background-color: #dcfce7;
            color: #15803d;
        }

        .cal-day-cell.p-absent {
            background-color: #fee2e2;
            color: #b91c1c;
        }

        .cal-day-cell.p-holiday {
            background-color: #ede9fe;
            color: #6d28d9;
        }

        .cal-day-cell.p-leave {
            background-color: #fef3c7;
            color: #b45309;
        }

        .cal-day-cell.p-wfh {
            background-color: #dbeafe;
            color: #1d4ed8;
        }

        .cal-day-cell.p-late {
            background-color: #fee2e2;
            color: #b91c1c;
        }

        .legend-item {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 11px;
            font-weight: 600;
            color: var(--slate-600);
        }

        .legend-box {
            width: 12px;
            height: 12px;
            border-radius: 3px;
        }

        .bg-p-present {
            background-color: #dcfce7;
        }

        .bg-p-absent {
            background-color: #fee2e2;
        }

        .bg-p-holiday {
            background-color: #ede9fe;
        }

        .bg-p-leave {
            background-color: #fef3c7;
        }

        .bg-p-wfh {
            background-color: #dbeafe;
        }

        .ts-table {
            width: 100%;
            margin-bottom: 0;
        }

        .ts-table th {
            font-size: 10px;
            font-weight: 700;
            color: var(--slate-400);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            border-bottom: 1px solid var(--slate-200) !important;
            padding: 10px 12px;
            background: #fafafa;
        }

        .ts-table td {
            padding: 12px;
            vertical-align: middle;
            font-size: 12px;
            font-weight: 600;
            color: var(--slate-700);
            border-bottom: 1px solid var(--slate-100);
        }

        .ts-table tr {
            cursor: pointer;
            transition: background 0.15s ease;
        }

        .ts-table tr:hover {
            background-color: #f8fafc;
        }

        .ts-table tr.selected-row {
            background-color: #eff6ff !important;
        }

        .badge-status {
            font-size: 10px;
            font-weight: 700;
            padding: 4px 8px;
            border-radius: 6px;
            letter-spacing: 0.3px;
        }

        .badge-status.st-present {
            background-color: #dcfce7;
            color: #15803d;
        }

        .badge-status.st-absent {
            background-color: #fee2e2;
            color: #b91c1c;
        }

        .badge-status.st-holiday {
            background-color: #ede9fe;
            color: #6d28d9;
        }

        .badge-status.st-leave {
            background-color: #fef3c7;
            color: #b45309;
        }

        .badge-status.st-wfh {
            background-color: #dbeafe;
            color: #1d4ed8;
        }

        .badge-status.st-late {
            background-color: #fee2e2;
            color: #b91c1c;
        }

        .badge-status.st-off {
            background-color: #f1f5f9;
            color: #475569;
        }

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

        .dataTables_paginate .page-item.active .page-link {
            background: var(--bloom-purple) !important;
            border-color: var(--bloom-purple) !important;
            color: #fff !important;
        }

        .dataTables_paginate .page-link:hover {
            background: #f8faff !important;
            color: var(--bloom-purple) !important;
            border-color: var(--bloom-purple) !important;
        }

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
            padding: 6px 10px;
            margin-left: 5px;
        }

        table.dataTable thead .sorting:before,
        table.dataTable thead .sorting:after,
        table.dataTable thead .sorting_asc:before,
        table.dataTable thead .sorting_asc:after,
        table.dataTable thead .sorting_desc:before,
        table.dataTable thead .sorting_desc:after {
            top: 50% !important;
            transform: translateY(-50%);
            font-size: 10px !important;
            color: var(--bloom-purple) !important;
        }

        #attendanceTable_wrapper .dataTables_scrollBody {
            max-height: 300px !important;
            overflow-y: auto !important;
        }

        @media (max-width: 767px) {
            .summary-grid {
                flex-wrap: wrap;
            }

            .summary-col {
                flex: 0 0 33.33%;
                margin-bottom: 10px;
                border-right: none;
            }

            .dataTables_wrapper .dataTables_length,
            .dataTables_wrapper .dataTables_filter {
                float: none;
                text-align: left;
                margin: 10px 0;
            }
        }
    </style>
</head>

<div class="content-wrapper">

    <section class="content pt-3">

        <div class="container-fluid">

            <!-- HEADER -->
            <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap">

                <div>
                    <h1 class="page-title">
                        Employee Timesheet
                    </h1>

                    <p class="page-subtitle">
                        Review detailed attendance logs and timesheets.
                    </p>
                </div>

                <!-- FILTER -->
                <div class="d-flex align-items-center mt-2 mt-md-0">

                    <form method="post"
                        action="<?= base_url('employee/my_attendance') ?>"
                        class="d-flex align-items-end">

                        <!-- MONTH -->
                        <div class="mr-2" style="width:150px;">

                            <label class="font-weight-bold mb-1">
                                Month
                            </label>

                            <select name="month"
                                class="form-control form-control-sm">

                                <?php
                                for ($m = 1; $m <= 12; $m++):
                                    $value = str_pad($m, 2, '0', STR_PAD_LEFT);
                                ?>

                                    <option value="<?= $value ?>"
                                        <?= ($selectedMonth == $value) ? 'selected' : '' ?>>

                                        <?= date('F', mktime(0, 0, 0, $m, 1)) ?>

                                    </option>

                                <?php endfor; ?>

                            </select>

                        </div>

                        <!-- YEAR -->
                        <div class="mr-2" style="width:110px;">

                            <label class="font-weight-bold mb-1">
                                Year
                            </label>

                            <select name="year"
                                class="form-control form-control-sm">

                                <?php
                                $currentYear = date('Y');

                                for ($y = $currentYear; $y >= 2023; $y--):
                                ?>

                                    <option value="<?= $y ?>"
                                        <?= ($selectedYear == $y) ? 'selected' : '' ?>>

                                        <?= $y ?>

                                    </option>

                                <?php endfor; ?>

                            </select>

                        </div>

                        <!-- SUBMIT -->
                        <button type="submit"
                            class="btn btn-sm"
                            style="
                                height:31px;
                                background:var(--bloom-purple);
                                color:#fff;
                                border-radius:8px;
                                font-weight:700;
                                padding:0 15px;
                            ">

                            Submit

                        </button>

                    </form>

                </div>

            </div>


            <!-- MAIN -->
            <div class="row">

                <div class="col-12">

                    <!-- TOP SECTION -->
                    <div class="row mb-3">

                        <!-- PROFILE -->
                        <div class="col-12 col-md-5 col-lg-4 mb-3 mb-md-0">

                            <div class="ts-card text-center d-flex flex-column justify-content-between">

                                <div>

                                    <?php
                                    $profilePhoto = $summary['profile_photo'] ?? '';
                                    ?>

                                    <?php if (!empty($profilePhoto)): ?>

                                        <img src="<?= base_url($profilePhoto) ?>"
                                            alt="<?= esc($empName) ?>"
                                            class="profile-avatar mb-2">

                                    <?php else: ?>

                                        <img
                                            src="https://ui-avatars.com/api/?name=<?= urlencode($empName) ?>&background=4a00e0&color=fff"
                                            alt="<?= esc($empName) ?>"
                                            class="profile-avatar mb-2">

                                    <?php endif; ?>

                                    <h3 class="font-weight-bold mb-0"
                                        style="font-size:17px;color:var(--slate-900);">

                                        <?= esc($empName) ?>

                                    </h3>

                                    <div class="emp-id-badge mb-2">

                                        <?= esc($empId) ?>

                                    </div>

                                    <div class="role-badge mb-3">

                                        <i class="far fa-user"></i>

                                        Employee

                                    </div>

                                </div>

                                <div class="border-top pt-2">

                                    <div class="row text-left">

                                        <div class="col-6 border-right">

                                            <div class="profile-meta-title text-center">
                                                MANAGER
                                            </div>

                                            <div class="profile-meta-value text-center">

                                                <?= esc($reportingToName) ?>

                                            </div>

                                        </div>

                                        <div class="col-6">

                                            <div class="profile-meta-title text-center">
                                                COMPANY
                                            </div>

                                            <div class="profile-meta-value text-center"
                                                style="font-size:10px;">

                                                <?= esc($companyName) ?>

                                            </div>

                                        </div>

                                    </div>

                                </div>

                            </div>

                        </div>


                        <!-- RIGHT SECTION -->
                        <div class="col-12 col-md-7 col-lg-8">

                            <div class="d-flex flex-column justify-content-between h-100"
                                style="gap:12px;">

                                <!-- STAT CARDS -->
                                <div class="row">

                                    <!-- TOTAL HOURS -->
                                    <div class="col-12 col-sm-4 mb-2 mb-sm-0">

                                        <div class="ts-card">

                                            <div class="d-flex justify-content-between align-items-center mb-2">

                                                <div class="stat-icon-box">

                                                    <i class="far fa-clock"></i>

                                                </div>

                                                <span class="stat-badge">

                                                    <?= $monthlyWorkedDays ?> DAYS

                                                </span>

                                            </div>

                                            <div class="stat-label">
                                                TOTAL HOURS WORKED
                                            </div>

                                            <div class="stat-value">

                                                <?= number_format($monthlyTotalHours, 2) ?>

                                                <span class="stat-unit">
                                                    hrs
                                                </span>

                                            </div>

                                        </div>

                                    </div>


                                    <!-- AVG DAILY HOURS -->
                                    <div class="col-12 col-sm-4 mb-2 mb-sm-0">

                                        <div class="ts-card">

                                            <div class="d-flex justify-content-between align-items-center mb-2">

                                                <div class="stat-icon-box">

                                                    <i class="fas fa-stopwatch"></i>

                                                </div>

                                            </div>

                                            <div class="stat-label">
                                                AVG DAILY HOURS
                                            </div>

                                            <div class="stat-value">

                                                <?= number_format($avgDailyHours, 1) ?>

                                                <span class="stat-unit">
                                                    hrs
                                                </span>

                                            </div>

                                        </div>

                                    </div>


                                    <!-- ATTENDANCE % -->
                                    <div class="col-12 col-sm-4">

                                        <div class="ts-card">

                                            <div class="d-flex justify-content-between align-items-center mb-2">

                                                <div class="stat-icon-box">

                                                    <i class="far fa-check-square"></i>

                                                </div>

                                            </div>

                                            <div class="stat-label">
                                                ATTENDANCE %
                                            </div>

                                            <div class="stat-value">

                                                <?= $attendancePercentage ?>%

                                            </div>

                                        </div>

                                    </div>

                                </div>


                                <!-- SUMMARY -->
                                <div class="ts-card">

                                    <div class="d-flex justify-content-between align-items-center border-bottom pb-2 mb-2">

                                        <span class="summary-title">
                                            SUMMARY PERIOD
                                        </span>

                                        <span class="summary-date-range">

                                            <?php if (!empty($periodStart) && !empty($periodEnd)): ?>

                                                <?= date('M d', strtotime($periodStart)) ?>
                                                -
                                                <?= date('M d, Y', strtotime($periodEnd)) ?>

                                            <?php else: ?>

                                                -

                                            <?php endif; ?>

                                        </span>

                                    </div>


                                    <div class="summary-grid py-1">

                                        <!-- TOTAL -->
                                        <div class="summary-col">

                                            <div class="summary-item-label">
                                                TOTAL DAYS
                                            </div>

                                            <div class="summary-item-val">

                                                <?= $totalDays ?>

                                            </div>

                                        </div>


                                        <!-- WORKING -->
                                        <div class="summary-col">

                                            <div class="summary-item-label">
                                                WORKING
                                            </div>

                                            <div class="summary-item-val">

                                                <?= $workingDays ?>

                                            </div>

                                        </div>


                                        <!-- PRESENT -->
                                        <div class="summary-col">

                                            <div class="summary-item-label">
                                                PRESENT
                                            </div>

                                            <div class="summary-item-val text-present">

                                                <?= $presentDays ?>

                                            </div>

                                        </div>


                                        <!-- ABSENT -->
                                        <div class="summary-col">

                                            <div class="summary-item-label">
                                                ABSENT
                                            </div>

                                            <div class="summary-item-val text-absent">

                                                <?= $absentDays ?>

                                            </div>

                                        </div>


                                        <!-- HOLIDAYS -->
                                        <div class="summary-col">

                                            <div class="summary-item-label">
                                                HOLIDAYS
                                            </div>

                                            <div class="summary-item-val text-holiday">

                                                <?= $holidayDays ?>

                                            </div>

                                        </div>


                                        <!-- LEAVE -->
                                        <div class="summary-col">

                                            <div class="summary-item-label">
                                                LEAVE
                                            </div>

                                            <div class="summary-item-val text-leave">

                                                <?= $leaveDays ?>

                                            </div>

                                        </div>


                                        <!-- WFH -->
                                        <div class="summary-col">

                                            <div class="summary-item-label">
                                                WFH
                                            </div>

                                            <div class="summary-item-val text-wfh">

                                                <?= $wfhDays ?>

                                            </div>

                                        </div>

                                    </div>

                                </div>

                            </div>

                        </div>

                    </div>


                    <!-- BOTTOM -->
                    <div class="row">

                        <!-- CALENDAR -->
                        <div class="col-12 col-lg-5 mb-3 mb-lg-0">

                            <div class="ts-card d-flex flex-column justify-content-between">

                                <?php

                                if (!empty($periodStart)) {
                                    $calendarStart = new DateTime($periodStart);
                                } else {
                                    $calendarStart = new DateTime();
                                }

                                if (!empty($periodEnd)) {
                                    $calendarEnd = new DateTime($periodEnd);
                                } else {
                                    $calendarEnd = new DateTime();
                                }

                                $periodDays = $calendarStart->diff($calendarEnd)->days + 1;

                                $startingDay = (int)$calendarStart->format('w');

                                /*
                                 * Attendance Lookup
                                 */
                                $attendanceByDate = [];

                                foreach ($attendance as $row) {

                                    if (!empty($row['attendance_date'])) {

                                        $attendanceByDate[$row['attendance_date']] =
                                            strtoupper(
                                                trim($row['status'] ?? '')
                                            );
                                    }
                                }

                                ?>

                                <!-- CALENDAR HEADER -->
                                <div class="d-flex justify-content-between align-items-center mb-3">

                                    <span class="cal-header-title">
                                        Attendance Calendar
                                    </span>

                                    <span class="cal-month-link">

                                        <?= $calendarStart->format('M d, Y') ?>

                                        -

                                        <?= $calendarEnd->format('M d, Y') ?>

                                    </span>

                                </div>


                                <!-- CALENDAR -->
                                <div class="cal-grid mb-3">

                                    <div class="cal-day-name">S</div>
                                    <div class="cal-day-name">M</div>
                                    <div class="cal-day-name">T</div>
                                    <div class="cal-day-name">W</div>
                                    <div class="cal-day-name">T</div>
                                    <div class="cal-day-name">F</div>
                                    <div class="cal-day-name">S</div>


                                    <!-- EMPTY CELLS -->
                                    <?php for ($i = 0; $i < $startingDay; $i++): ?>

                                        <div class="cal-day-cell empty-cell"></div>

                                    <?php endfor; ?>


                                    <!-- ATTENDANCE DAYS -->
                                    <?php

                                    $currentDate = clone $calendarStart;

                                    for ($i = 0; $i < $periodDays; $i++):

                                        $date = $currentDate->format('Y-m-d');

                                        $status = strtoupper(
                                            trim(
                                                $attendanceByDate[$date] ?? ''
                                            )
                                        );

                                        switch ($status) {

                                            case 'PRESENT':
                                                $statusClass = 'p-present';
                                                break;

                                            case 'ABSENT':
                                                $statusClass = 'p-absent';
                                                break;

                                            case 'HOLIDAY':
                                                $statusClass = 'p-holiday';
                                                break;

                                            case 'LEAVE':
                                                $statusClass = 'p-leave';
                                                break;

                                            case 'WFH':
                                                $statusClass = 'p-wfh';
                                                break;

                                            case 'LATE':
                                                $statusClass = 'p-late';
                                                break;

                                            default:
                                                $statusClass = '';
                                                break;
                                        }

                                    ?>

                                        <div
                                            class="cal-day-cell <?= $statusClass ?>"
                                            title="<?= esc($status ?: 'No Record') ?> - <?= $currentDate->format('d M Y') ?>">

                                            <?= $currentDate->format('d') ?>

                                        </div>

                                    <?php

                                        $currentDate->modify('+1 day');

                                    endfor;

                                    ?>

                                </div>


                                <!-- LEGEND -->
                                <div
                                    class="d-flex justify-content-between align-items-center pt-2 border-top flex-wrap"
                                    style="gap:6px;">

                                    <div class="legend-item">

                                        <span class="legend-box bg-p-present"></span>

                                        PRESENT

                                    </div>

                                    <div class="legend-item">

                                        <span class="legend-box bg-p-absent"></span>

                                        ABSENT

                                    </div>

                                    <div class="legend-item">

                                        <span class="legend-box bg-p-holiday"></span>

                                        HOLIDAY

                                    </div>

                                    <div class="legend-item">

                                        <span class="legend-box bg-p-leave"></span>

                                        LEAVE

                                    </div>

                                    <div class="legend-item">

                                        <span class="legend-box bg-p-wfh"></span>

                                        WFH

                                    </div>

                                </div>

                            </div>

                        </div>


                        <!-- ATTENDANCE TABLE -->
                        <div class="col-12 col-lg-7">

                            <div class="ts-card d-flex flex-column justify-content-between">

                                <div class="table-responsive">

                                    <table class="table ts-table"
                                        id="attendanceTable">

                                        <thead>

                                            <tr>

                                                <th>DATE</th>
                                                <th>STATUS</th>
                                                <th>FIRST IN</th>
                                                <th>LAST OUT</th>
                                                <th>TOTAL HRS</th>

                                            </tr>

                                        </thead>


                                        <tbody>

                                            <?php if (!empty($attendance)): ?>

                                                <?php foreach ($attendance as $index => $row): ?>

                                                    <?php

                                                    $status = strtoupper(
                                                        trim($row['status'] ?? '')
                                                    );

                                                    switch ($status) {

                                                        case 'PRESENT':
                                                            $badgeClass = 'st-present';
                                                            break;

                                                        case 'ABSENT':
                                                            $badgeClass = 'st-absent';
                                                            break;

                                                        case 'HOLIDAY':
                                                            $badgeClass = 'st-holiday';
                                                            break;

                                                        case 'LEAVE':
                                                            $badgeClass = 'st-leave';
                                                            break;

                                                        case 'WFH':
                                                            $badgeClass = 'st-wfh';
                                                            break;

                                                        case 'LATE':
                                                            $badgeClass = 'st-late';
                                                            break;

                                                        default:
                                                            $badgeClass = 'st-off';
                                                            break;
                                                    }

                                                    $attendanceDate = $row['attendance_date'] ?? '';

                                                    $formattedDate = !empty($attendanceDate)
                                                        ? date('d M Y, l', strtotime($attendanceDate))
                                                        : '-';

                                                    $displayDate = !empty($attendanceDate)
                                                        ? date('d M, D', strtotime($attendanceDate))
                                                        : '-';

                                                    $punchIn = !empty($row['punch_in'])
                                                        ? date('h:i A', strtotime($row['punch_in']))
                                                        : '-';

                                                    $punchOut = !empty($row['punch_out'])
                                                        ? date('h:i A', strtotime($row['punch_out']))
                                                        : '-';

                                                    $totalHours = !empty($row['daily_time_formatted'])
                                                        ? $row['daily_time_formatted']
                                                        : '-';

                                                    ?>

                                                    <tr
                                                        class="<?= $index === 0 ? 'selected-row' : '' ?>"
                                                        onclick="selectRow(
                                                            this,
                                                            '<?= esc($formattedDate, 'js') ?>',
                                                            '<?= esc($punchIn, 'js') ?>',
                                                            '<?= esc($punchOut, 'js') ?>'
                                                        )">

                                                        <!-- DATE -->
                                                        <td class="font-weight-bold">

                                                            <?= esc($displayDate) ?>

                                                        </td>


                                                        <!-- STATUS -->
                                                        <td>

                                                            <span class="badge-status <?= $badgeClass ?>">

                                                                <?= esc($status ?: '-') ?>

                                                            </span>

                                                        </td>


                                                        <!-- PUNCH IN -->
                                                        <td>

                                                            <?= esc($punchIn) ?>

                                                        </td>


                                                        <!-- PUNCH OUT -->
                                                        <td>

                                                            <?= esc($punchOut) ?>

                                                        </td>


                                                        <!-- TOTAL HOURS -->
                                                        <td class="font-weight-bold">

                                                            <?= esc($totalHours) ?>

                                                        </td>

                                                    </tr>

                                                <?php endforeach; ?>

                                            <?php else: ?>

                                                <tr>

                                                    <td colspan="5"
                                                        class="text-center text-muted">

                                                        <i class="far fa-calendar-times mr-1"></i>

                                                        No attendance records found
                                                        for the selected month.

                                                    </td>

                                                </tr>

                                            <?php endif; ?>

                                        </tbody>

                                    </table>

                                </div>

                            </div>

                        </div>

                    </div>

                </div>

            </div>

        </div>

    </section>

</div>


<!-- SCRIPTS -->

<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js"></script>

<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>

<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>

<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>


<script>
$(document).ready(function() {

    $('#attendanceTable').DataTable({

        responsive: true,

        paging: true,

        ordering: true,

        searching: true,

        info: true,

        lengthChange: true,

        pageLength: 5,

        lengthMenu: [
            [5, 10, 25, 50],
            [5, 10, 25, 50]
        ],

        order: [],

        scrollY: '300px',

        scrollCollapse: false,

        dom:
            "<'row'<'col-md-6'l><'col-md-6'f>>" +
            "t" +
            "<'row'<'col-md-6'i><'col-md-6'p>>"
    });

});
</script>


<script>
function selectRow(element, dateStr, firstIn, lastOut) {

    $('#attendanceTable tbody tr')
        .removeClass('selected-row');

    $(element)
        .addClass('selected-row');

    if ($('#selectedDateText').length) {

        $('#selectedDateText')
            .text(dateStr);

        $('#firstInTime')
            .text(firstIn);

        $('#lastOutTime')
            .text(lastOut);
    }
}
</script>

</html>