<?php
if (!function_exists('base_url')) {
    function base_url($path = '')
    {
        $map = [
            'payroll/payroll_dashboard' => 'payroll_dashboard.php',
            'payroll/payslips' => 'payslips.php',
            'payroll/salary_components' => 'salary_components.php',
            'payroll/salary_structure' => 'salary_structure.php',
            'payroll/step1' => 'step1.php',
            'payroll/step2' => 'step2.php',
            'payroll/step3' => 'step3.php',
            'payroll/step4' => 'step4.php',
            'admin/attendance_overview' => 'attendance_finalize.php',
        ];
        return $map[$path] ?? $path;
    }
}

if (!function_exists('esc')) {
    function esc($data)
    {
        return htmlspecialchars((string) $data, ENT_QUOTES, 'UTF-8');
    }
}

// Variables passed from controller step1()
$selectedMonth = isset($selectedMonth) ? (int) $selectedMonth : (int) ($_GET['month'] ?? date('m'));
$selectedYear = isset($selectedYear) ? (int) $selectedYear : (int) ($_GET['year'] ?? date('Y'));
$records = isset($records) ? $records : [];
$attendanceFinalizeUrl = $attendanceFinalizeUrl ?? (base_url('admin/attendance_finalize') . '?month=' . urlencode($selectedMonth) . '&year=' . urlencode($selectedYear));
// Check attendance status:
// If status is true / 'Y', records are populated and table is shown in readonly mode.
$attendanceStatus = strtoupper(trim((string) ($attendance_status ?? ($att_gen[0]['attendance_status'] ?? 'N'))));
$is_status_true = in_array($attendanceStatus, ['Y', '1', 'TRUE'], true);
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>BloomHR | Step 1: Attendance Verification &amp; Ingestion</title>
    <link rel="icon" type="image/jpeg" href="<?= base_url('public/dist/img/bloom.jpg') ?>">

    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">

    <style>
        :root {
            --bloom-purple: #4a00e0;
            --bloom-dark: #120038;
            --bloom-orange: #e46c44;
            --bloom-success: #10b981;
            --bloom-danger: #dc2626;
            --mtn-deep: #120038;
            --soft-gray: #f8fafc;
            --border-color: #e2e8f0;
        }

        /* BODY */
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: var(--soft-gray);
            font-size: 13px;
            color: #334155;
        }

        /* NAVBAR */
        .main-header {
            border-bottom: 1px solid #e2e8f0 !important;
            background: #ffffff !important;
            height: 55px;
        }

        /* SIDEBAR */
        .main-sidebar {
            background: #111c43 !important;
        }

        /* SIDEBAR BRAND */
        .brand-link {
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
            padding: 14px 18px;
        }

        /* SIDEBAR NAV LINKS */
        .nav-sidebar .nav-link {
            display: flex;
            align-items: center;
            height: 42px;
            padding: 0 14px;
            font-size: 13px;
        }

        .nav-sidebar .nav-link i {
            width: 24px;
            text-align: center;
            margin-right: 10px;
            font-size: 14px;
        }

        .nav-sidebar .nav-link p {
            margin: 0;
        }

        /* ACTIVE MENU */
        .nav-pills .nav-link.active,
        .nav-sidebar>.nav-item>.nav-link.active {
            background: #007bff !important;
            color: #fff !important;
        }

        /* HOVER */
        .nav-sidebar .nav-link:hover:not(.active) {
            background: rgba(255, 255, 255, 0.08);
        }

        /* CONTENT */
        .content {
            padding-top: 10px !important;
        }

        /* ROW FIX */
        .row {
            margin-bottom: 6px;
        }

        /* CARD */
        .card-bloom {
            border: 1px solid var(--border-color) !important;
            border-radius: 16px !important;
            background: #fff;
            box-shadow: 0 3px 6px rgba(0, 0, 0, 0.04);
            margin-bottom: 12px;
            transition: all .3s;
        }

        .card-bloom:hover {
            transform: translateY(-4px);
            box-shadow: 0 10px 20px rgba(0, 0, 0, 0.08);
        }

        /* MINI STAT CARDS */
        .stat-mini {
            padding: 18px;
        }

        .stat-mini strong {
            font-size: 1.4rem;
            color: var(--mtn-deep);
        }

        .stat-icon-circle {
            width: 42px;
            height: 42px;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 17px;
            margin-bottom: 10px;
        }

        /* STATUS GRID */
        .status-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            text-align: center;
        }

        .fulltime {
            grid-column: 1/span 2;
        }

        .status-item {
            background: #f4f6f9;
            padding: 10px;
            border-radius: 6px;
        }

        .status-item strong {
            font-size: 1.2rem;
        }

        /* PROGRESS MULTI */
        .progress-multi {
            display: flex;
            height: 8px;
            overflow: hidden;
            border-radius: 4px;
            background: #f1f5f9;
        }

        .progress-multi div {
            height: 100%;
        }

        /* AVATAR */
        .avatar-sm {
            width: 38px;
            height: 38px;
            border-radius: 10px;
        }

        /* FOOTER */
        .main-footer {
            background: #fff !important;
            border-top: 1px solid #e2e8f0 !important;
            font-size: 12px;
            padding: 10px 20px !important;
        }

        /* FOOTER LINK */
        .footer-link {
            color: var(--bloom-purple);
            font-weight: 600;
            text-decoration: none;
        }

        .payroll-page {
            --bp: #4a00e0;
            --bd: #120038;
            --bl: #eef2ff;
            --bs: #10b981;
            --be: #dc2626;
            --bt: #334155;
            --bm: #64748b;
            --bb: #e2e8f0;
            color: var(--bt);
            padding: 12px 0 85px;
        }

        .payroll-page * {
            box-sizing: border-box;
        }

        .payroll-page .pc-card {
            background: #fff;
            border: 1px solid var(--bb);
            border-radius: 16px;
            box-shadow: 0 3px 8px rgba(18, 0, 56, .04);
            margin-bottom: 18px;
            overflow: hidden;
        }

        .payroll-page .pc-body {
            padding: 20px;
        }

        .payroll-page .pc-heading {
            font-size: 22px;
            font-weight: 700;
            color: var(--bd);
            margin: 0 0 7px;
        }

        .payroll-page .pc-title {
            font-size: 16px;
            font-weight: 700;
            color: var(--bd);
            margin: 0;
        }

        .payroll-page .pc-muted {
            font-size: 12px;
            color: var(--bm);
            margin-bottom: 0;
        }

        .payroll-page .pc-label {
            font-size: 10px;
            text-transform: uppercase;
            letter-spacing: .06em;
            color: var(--bm);
            font-weight: 700;
        }

        .payroll-page .pc-top,
        .payroll-page .pc-flex,
        .payroll-page .pc-actions {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
        }

        .payroll-page .pc-top {
            align-items: flex-start;
            margin-bottom: 20px;
        }

        .payroll-page .pc-actions {
            justify-content: flex-start;
        }

        .payroll-page .pc-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 10px;
            border-radius: 30px;
            font-size: 10px;
            font-weight: 700;
            white-space: nowrap;
        }

        .payroll-page .pc-purple {
            background: #eef2ff;
            color: var(--bp);
        }

        .payroll-page .pc-green {
            background: #dcfce7;
            color: #15803d;
        }

        .payroll-page .pc-yellow {
            background: #fef3c7;
            color: #92400e;
        }

        .payroll-page .pc-red {
            background: #fee2e2;
            color: #b91c1c;
        }

        .payroll-page .pc-btn {
            border: 1px solid var(--bb);
            border-radius: 9px;
            background: #fff;
            color: var(--bt);
            padding: 9px 13px;
            font-size: 12px;
            font-weight: 600;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 7px;
            cursor: pointer;
            text-decoration: none;
            transition: .2s;
        }

        .payroll-page .pc-btn:hover {
            background: var(--bl);
            color: var(--bp);
            border-color: #c4b5fd;
        }

        .payroll-page .pc-btn-primary {
            background: var(--bp);
            border-color: var(--bp);
            color: #fff;
        }

        .payroll-page .pc-btn-primary:hover {
            background: var(--bd);
            color: #fff;
        }

        .payroll-page .pc-icon {
            width: 44px;
            height: 44px;
            border-radius: 12px;
            background: var(--bl);
            color: var(--bp);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 19px;
            flex-shrink: 0;
        }

        .payroll-page .pc-title-group {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .payroll-page .pc-meta {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            align-items: center;
            margin-bottom: 10px;
        }

        .payroll-page .pc-stepper {
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 18px;
        }

        .payroll-page .pc-step-top {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 12px;
        }

        .payroll-page .pc-step-number {
            width: 35px;
            height: 35px;
            flex-shrink: 0;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #f1f5f9;
            color: var(--bm);
            font-weight: 700;
        }

        .payroll-page .pc-step.active .pc-step-number {
            background: var(--bp);
            color: #fff;
            box-shadow: 0 0 0 4px var(--bl);
        }

        .payroll-page .pc-step-line {
            flex: 1;
            height: 3px;
            border-radius: 10px;
            background: var(--bb);
        }

        .payroll-page .pc-step.active .pc-step-line {
            background: var(--bp);
        }

        .payroll-page .pc-step-title {
            font-size: 12px;
            font-weight: 700;
            line-height: 1.5;
            margin: 5px 0;
        }

        .payroll-page .pc-control {
            height: 38px;
            padding: 7px 11px;
            border: 1px solid var(--bb);
            border-radius: 9px;
            background: #fff;
            color: var(--bt);
            font-family: inherit;
            font-size: 12px;
            outline: none;
        }

        .payroll-page .pc-control:focus {
            border-color: var(--bp);
            box-shadow: 0 0 0 3px rgba(74, 0, 224, .08);
        }

        .payroll-page .pc-card-header {
            padding: 18px 20px;
            border-bottom: 1px solid var(--bb);
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 14px;
        }

        .payroll-page .pc-bottom-actions {
            display: flex;
            align-items: center;
            flex-wrap: wrap;
            gap: 10px;
        }

        /* WORKFLOW ACTION BAR - SCROLLS WITH PAGE CONTENT */
        .payroll-page .pc-bottom-bar {
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

        .payroll-page .pc-bottom-bar:hover {
            box-shadow: 0 10px 20px -3px rgba(18, 0, 56, 0.06) !important;
        }

        @media (max-width: 767.98px) {
            .payroll-page .pc-bottom-bar {
                padding: 14px 16px !important;
                flex-direction: column;
                align-items: stretch;
                gap: 12px;
            }

            .payroll-page .pc-bottom-actions {
                width: 100%;
                justify-content: stretch;
            }

            .payroll-page .pc-bottom-actions .pc-btn {
                flex: 1;
                text-align: center;
            }
        }

        .payroll-page {
            padding-bottom: 20px !important;
        }

        /* Summary Stat Cards */
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 14px;
            margin-bottom: 20px;
        }

        .stat-card {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
            min-height: 100px;
            padding: 16px 18px;
            background: #fff;
            border: 1px solid var(--border-color);
            border-radius: 14px;
            box-shadow: 0 2px 6px rgba(18, 0, 56, .03);
            transition: transform 0.2s, box-shadow 0.2s;
        }

        .stat-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 16px rgba(18, 0, 56, .06);
        }

        .stat-card .stat-label {
            color: #64748b;
            font-size: 10px;
            font-weight: 800;
            letter-spacing: .4px;
            text-transform: uppercase;
        }

        .stat-card .stat-value {
            margin-top: 4px;
            color: #172033;
            font-size: 24px;
            font-weight: 800;
        }

        .stat-card .stat-value small {
            color: #64748b;
            font-size: 11px;
            font-weight: 600;
        }

        .stat-card .stat-note {
            margin-top: 5px;
            color: #64748b;
            font-size: 10px;
        }

        .stat-card .stat-note.green {
            color: #059669;
        }

        .stat-card .stat-icon {
            width: 40px;
            height: 40px;
            display: grid;
            place-items: center;
            flex: 0 0 40px;
            background: #eef2ff;
            border-radius: 12px;
            color: var(--bloom-purple);
            font-size: 16px;
        }

        .stat-card:nth-child(2) .stat-icon {
            background: #faf0ff;
            color: #a855f7;
        }

        .stat-card:nth-child(3) .stat-icon {
            background: #eef2ff;
            color: #4f46e5;
        }

        .stat-card:nth-child(4) .stat-icon {
            background: #fff8e7;
            color: #d97706;
        }

        /* =========================================================
           DATA TABLE & ADMINLTE THEME (MATCHING REST OF THE PAGES)
           ========================================================= */
        .table-custom {
            width: 100% !important;
            border-collapse: separate;
            border-spacing: 0;
            margin-bottom: 0;
        }

        .table-custom thead th {
            border-top: none;
            border-bottom: 1px solid var(--border-color);
            color: #64748b;
            font-size: 11px;
            text-transform: uppercase;
            font-weight: 700;
            padding: 13px 14px;
            letter-spacing: 0.5px;
            white-space: nowrap;
            vertical-align: middle;
        }

        .table-custom tbody tr {
            transition: background-color 0.15s ease;
        }

        .table-custom tbody tr:hover {
            background-color: #f8fafc !important;
        }

        .table-custom tbody td {
            vertical-align: middle !important;
            border-top: 1px solid #f1f5f9;
            font-size: 13px;
            padding: 13px 14px;
            color: #334155;
            white-space: nowrap;
        }

        /* Read-Only Attendance Table */
        #attendanceTable {
            width: 100% !important;
            margin: 0 !important;
            border-collapse: collapse;
        }

        #attendanceTable thead th {
            padding: 12px 14px;
            border-bottom: 1px solid #e2e8f0;
            border-right: 1px solid #edf1f7;
            color: #475569;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: .4px;
            text-align: center;
            text-transform: uppercase;
            white-space: nowrap;
            vertical-align: middle;
        }

        #attendanceTable thead tr.group-head th {
            padding: 9px 12px !important;
            font-size: 11px !important;
            font-weight: 800 !important;
            cursor: default !important;
            pointer-events: none;
        }

        #attendanceTable thead tr.group-head th::before,
        #attendanceTable thead tr.group-head th::after {
            display: none !important;
        }

        #attendanceTable thead .baseline {
            background: #ede9fe !important;
            color: #6d28d9 !important;
        }

        #attendanceTable thead .activity {
            background: #dbeafe !important;
            color: #1d4ed8 !important;
        }

        #attendanceTable thead .payroll {
            background: #dcfce7 !important;
            color: #047857 !important;
        }

        #attendanceTable thead tr.labels th {
            background: #f8fafc;
            color: #475569;
            font-size: 10.5px !important;
            font-weight: 700 !important;
            padding-top: 12px !important;
            padding-bottom: 12px !important;
            border-bottom: 1px solid #e2e8f0 !important;
        }

        #attendanceTable thead tr.labels th:first-child {
            text-align: left !important;
            padding-left: 18px !important;
        }

        #attendanceTable thead tr.labels th:nth-child(2),
        #attendanceTable thead tr.labels th:nth-child(3) {
            background: #fbfaff !important;
        }

        #attendanceTable thead tr.labels th:nth-child(4),
        #attendanceTable thead tr.labels th:nth-child(5),
        #attendanceTable thead tr.labels th:nth-child(6),
        #attendanceTable thead tr.labels th:nth-child(7),
        #attendanceTable thead tr.labels th:nth-child(8) {
            background: #f4f8ff !important;
        }

        #attendanceTable thead tr.labels th:nth-child(9),
        #attendanceTable thead tr.labels th:nth-child(10) {
            background: #f4fbf7 !important;
        }

        #attendanceTable tbody td {
            padding: 13px 12px !important;
            border-bottom: 1px solid #f0f3f8;
            border-right: 1px solid #f8fafc;
            font-size: 12.5px !important;
            text-align: center;
            vertical-align: middle;
            white-space: nowrap;
        }

        #attendanceTable tbody td:first-child {
            padding-left: 18px !important;
            text-align: left;
        }

        #attendanceTable tbody td:nth-child(2),
        #attendanceTable tbody td:nth-child(3) {
            background: #fdfcff !important;
        }

        #attendanceTable tbody td:nth-child(4),
        #attendanceTable tbody td:nth-child(5),
        #attendanceTable tbody td:nth-child(6),
        #attendanceTable tbody td:nth-child(7),
        #attendanceTable tbody td:nth-child(8) {
            background: #fafcff !important;
        }

        #attendanceTable tbody td:nth-child(9),
        #attendanceTable tbody td:nth-child(10) {
            background: #fafffc !important;
        }

        /* Sorting icons and active state */
        table.dataTable thead th.sorting,
        table.dataTable thead th.sorting_asc,
        table.dataTable thead th.sorting_desc {
            position: relative;
            cursor: pointer;
            padding-right: 26px !important;
        }

        table.dataTable thead th.sorting:hover {
            background-color: #f1f5f9;
        }

        /* DATATABLES WRAPPER & CONTROLS (MATCHING ADMINLTE & STEP 2) */
        .dataTables_wrapper {
            width: 100% !important;
        }

        .dataTables_wrapper .row:first-child {
            display: flex;
            justify-content: space-between;
            align-items: center;
            width: 100%;
            margin: 0;
            padding: 12px 18px;
            background: #fff;
            border-bottom: 1px solid #f1f5f9;
        }

        .dataTables_wrapper .row:last-child {
            display: flex;
            justify-content: space-between;
            align-items: center;
            width: 100%;
            margin: 0;
            padding: 12px 18px;
            background: #fff;
            border-top: 1px solid #f1f5f9;
        }

        .dataTables_wrapper .dataTables_length {
            float: left;
            margin: 0;
            font-size: 13px;
            font-weight: 600;
            color: #64748b;
        }

        .dataTables_wrapper .dataTables_length label {
            margin-bottom: 0;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }

        .dataTables_length select {
            height: 34px !important;
            min-width: 65px;
            border: 1px solid #e2e8f0 !important;
            border-radius: 10px !important;
            padding: 4px 8px !important;
            outline: none;
            color: #334155;
            font-weight: 600;
            font-size: 13px;
        }

        .dataTables_wrapper .dataTables_filter {
            float: right;
            margin: 0;
            text-align: right;
            font-size: 13px;
            font-weight: 600;
            color: #64748b;
        }

        .dataTables_wrapper .dataTables_filter label {
            margin-bottom: 0;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }

        .dataTables_wrapper .dataTables_filter input {
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 6px 12px;
            margin-left: 5px;
            height: 34px;
            outline: none;
            font-size: 13px;
            color: #334155;
            transition: all 0.2s ease;
        }

        .dataTables_wrapper .dataTables_filter input:focus,
        .dataTables_wrapper .dataTables_length select:focus {
            border-color: var(--bloom-purple);
            box-shadow: 0 0 0 3px rgba(74, 0, 224, 0.1);
        }

        /* Pagination Styling from AdminLTE / Employee Theme */
        .dataTables_paginate {
            padding-right: 0;
        }

        .dataTables_paginate ul.pagination {
            margin: 0 !important;
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
            padding: 6px 12px !important;
            font-size: 12.5px;
            transition: all 0.2s ease;
        }

        /* Active Page: Gradient Purple */
        .dataTables_paginate .page-item.active .page-link {
            background: linear-gradient(135deg, #4a00e0 0%, #2a0080 100%) !important;
            border-color: #4a00e0 !important;
            color: #fff !important;
            box-shadow: 0 2px 6px rgba(74, 0, 224, 0.25) !important;
        }

        /* Hover */
        .dataTables_paginate .page-link:hover {
            background: #f8faff !important;
            color: #4a00e0 !important;
            border-color: #4a00e0 !important;
        }

        .dataTables_paginate .page-item.disabled .page-link {
            color: #cbd5e1 !important;
            background: #fff !important;
            border-color: #e2e8f0 !important;
        }

        /* Info Text */
        .dataTables_info {
            color: #64748b !important;
            font-size: 12px !important;
            font-weight: 600 !important;
            padding-left: 0;
        }

        .employee {
            display: flex;
            align-items: center;
            gap: 10px;
            min-width: 170px;
        }

        .avatar {
            width: 34px;
            height: 34px;
            display: grid;
            place-items: center;
            flex: 0 0 34px;
            background: #ede9fe;
            border-radius: 50%;
            color: #6d28d9;
            font-size: 11px;
            font-weight: 800;
        }

        .employee-details {
            display: flex;
            flex-direction: column;
            gap: 2px;
        }

        .emp-name {
            color: #1e293b;
            font-size: 12.5px;
            font-weight: 700;
        }

        .emp-id {
            color: #64748b;
            font-size: 11px;
        }

        .number {
            color: #334155;
            font-weight: 700;
        }

        .present,
        .paid {
            color: #059669;
            font-weight: 800;
        }

        .leave,
        .unpaid {
            color: #dc2626;
            font-weight: 800;
        }

        .wfh {
            color: #2563eb;
            font-weight: 800;
        }

        @media (max-width: 1100px) {
            .summary-grid {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        @media (max-width: 600px) {
            .summary-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed">
    <div class="wrapper">

        <!-- Content Wrapper -->
        <div class="content-wrapper">
            <section class="content pt-3">
                <div class="container-fluid">

                    <div class="payroll-page">

                        <!-- PAGE HEADING -->
                        <div class="pc-top">
                            <div>
                                <div class="pc-meta">
                                    <span class="pc-badge pc-purple">
                                        <i class="fas fa-fingerprint"></i> PR-<?= $selectedYear ?>-<?= str_pad((string) $selectedMonth, 2, '0', STR_PAD_LEFT) ?>-REG01
                                    </span>

                                    <?php if ($is_status_true): ?>
                                        <span class="pc-badge pc-green">
                                            <i class="fas fa-check-circle"></i> Attendance Finalized &amp; Locked
                                        </span>
                                    <?php else: ?>
                                        <span class="pc-badge pc-yellow" style="background:#fff8e7; color:#a16207; border:1px solid #fce7b0;">
                                            <i class="fas fa-clock"></i> Attendance In Review (Pending Finalization)
                                        </span>
                                    <?php endif; ?>

                                    <span class="pc-muted">Payroll Cycle: <?= date('F Y', mktime(0, 0, 0, $selectedMonth, 1, $selectedYear)) ?></span>
                                </div>

                                <h1 class="pc-heading">Step 1: Attendance Verification &amp; Ingestion</h1>
                                <p class="pc-muted">Period: <?= date('01 M Y', mktime(0, 0, 0, $selectedMonth, 1, $selectedYear)) ?> – <?= date('t M Y', mktime(0, 0, 0, $selectedMonth, 1, $selectedYear)) ?></p>
                            </div>

                            <div class="pc-actions">
                                <?php
                                    $overviewUrl = base_url('admin/attendance_overview') . '?month=' . urlencode($selectedMonth) . '&year=' . urlencode($selectedYear);
                                    if (!empty($_GET['s1'])) {
                                        $overviewUrl .= '&s1=1';
                                    }
                                    ?>
                                    <a href="<?= $overviewUrl ?>" class="pc-btn" target="_blank">
                                        <i class="fas fa-external-link-alt"></i> Attendance Module
                                    </a>
                                <button type="button" class="pc-btn pc-btn-primary" id="saveDraftBtn">
                                    <i class="far fa-bookmark"></i> Save Checkpoint
                                </button>
                            </div>
                        </div>

                        <!-- PAYROLL STEPS -->
                        <div class="pc-card">
                            <div class="pc-body">
                                <div class="pc-stepper">
                                    <div class="pc-step active">
                                        <div class="pc-step-top">
                                            <span class="pc-step-number">1</span>
                                            <span class="pc-step-line"></span>
                                        </div>
                                        <span class="pc-label" style="color:#4a00e0;">Step 01 · Active</span>
                                        <p class="pc-step-title">Attendance Verification &amp; Ingestion</p>
                                        <p class="pc-muted">Gate sync, biometric logs &amp; LOPs</p>
                                    </div>

                                    <div class="pc-step">
                                        <div class="pc-step-top">
                                            <span class="pc-step-number">2</span>
                                            <span class="pc-step-line"></span>
                                        </div>
                                        <span class="pc-label">Step 02 · Queued</span>
                                        <p class="pc-step-title">Salary Structure &amp; Pre-Calculation</p>
                                        <p class="pc-muted">CTC splits, allowances &amp; perks</p>
                                    </div>

                                    <div class="pc-step">
                                        <div class="pc-step-top">
                                            <span class="pc-step-number">3</span>
                                            <span class="pc-step-line"></span>
                                        </div>
                                        <span class="pc-label">Step 03 · Queued</span>
                                        <p class="pc-step-title">35-Column Master Calculation Grid</p>
                                        <p class="pc-muted">Deductions, TDS &amp; Gross-to-Net</p>
                                    </div>

                                    <div class="pc-step">
                                        <div class="pc-step-top">
                                            <span class="pc-step-number">4</span>
                                        </div>
                                        <span class="pc-label">Step 04 · Queued</span>
                                        <p class="pc-step-title">Final Summary &amp; Cycle Completion</p>
                                        <p class="pc-muted">Bank NACH &amp; payslip dispatch</p>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- PERIOD FILTER -->
                        <div class="pc-card">
                            <div class="pc-body">
                                <div class="pc-flex">
                                    <div class="pc-actions">
                                        <strong>
                                            <i class="far fa-calendar-alt" style="color:#4a00e0;"></i>
                                            Payroll Cycle Period:
                                        </strong>

                                        <select id="selectMonth" name="month" class="pc-control">
                                            <?php for ($m = 1; $m <= 12; $m++): ?>
                                                <option value="<?= $m ?>" <?= ($selectedMonth === $m) ? 'selected' : '' ?>>
                                                    <?= date('F', mktime(0, 0, 0, $m, 1)) ?>
                                                </option>
                                            <?php endfor; ?>
                                        </select>

                                        <select id="selectYear" name="year" class="pc-control">
                                            <?php
                                            $currentYear = (int) date('Y');
                                            for ($y = $currentYear - 2; $y <= $currentYear + 2; $y++):
                                            ?>
                                                <option value="<?= $y ?>" <?= ($selectedYear === $y) ? 'selected' : '' ?>>
                                                    <?= $y ?>
                                                </option>
                                            <?php endfor; ?>
                                        </select>
                                    </div>

                                    <div>
                                        <span class="pc-label">Verification State</span><br>
                                        <?php if ($is_status_true): ?>
                                            <span class="pc-badge pc-green mt-2">
                                                <i class="fas fa-check-circle" style="font-size:8px;"></i>
                                                Attendance Finalized &amp; Locked
                                            </span>
                                        <?php else: ?>
                                            <span class="pc-badge pc-yellow mt-2" style="background:#fff8e7; color:#a16207; border:1px solid #fce7b0;">
                                                <i class="fas fa-exclamation-triangle" style="font-size:8px;"></i>
                                                Attendance Not Finalized
                                            </span>
                                        <?php endif; ?>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <?php if ($is_status_true): ?>
                            <!-- 4 SUMMARY STAT CARDS (from attendance_finalize.php) -->
                            <div class="summary-grid">
                                <div class="stat-card">
                                    <div>
                                        <div class="stat-label">Total Staff in Cycle</div>
                                        <div class="stat-value"><?= !empty($records) ? count($records) : 0 ?></div>
                                        <div class="stat-note green">
                                            <i class="fas fa-check-circle"></i> Attendance Records
                                        </div>
                                    </div>
                                    <div class="stat-icon"><i class="fas fa-users"></i></div>
                                </div>

                                <div class="stat-card">
                                    <div>
                                        <div class="stat-label">Total Period</div>
                                        <div class="stat-value">
                                            <?= !empty($records) ? floatval($records[0]['total_days'] ?? 0) : 0 ?>
                                            <small>Days</small>
                                        </div>
                                        <div class="stat-note">Attendance Cycle</div>
                                    </div>
                                    <div class="stat-icon"><i class="far fa-calendar"></i></div>
                                </div>

                                <div class="stat-card">
                                    <div>
                                        <div class="stat-label">Working Days</div>
                                        <div class="stat-value">
                                            <?= !empty($records) ? floatval($records[0]['working_days'] ?? 0) : 0 ?>
                                            <small>Days</small>
                                        </div>
                                        <div class="stat-note">Excludes off-days</div>
                                    </div>
                                    <div class="stat-icon"><i class="fas fa-calendar-check"></i></div>
                                </div>

                                <div class="stat-card">
                                    <div>
                                        <div class="stat-label">Holidays &amp; Offs</div>
                                        <div class="stat-value">
                                            <?= !empty($records)
                                                ? (floatval($records[0]['holiday_days'] ?? 0) + floatval($records[0]['weekly_off_days'] ?? 0))
                                                : 0 ?>
                                            <small>Days</small>
                                        </div>
                                        <div class="stat-note">Holidays + Weekly Offs</div>
                                    </div>
                                    <div class="stat-icon"><i class="fas fa-umbrella-beach"></i></div>
                                </div>
                            </div>

                            <!-- READ-ONLY ATTENDANCE MASTER TABLE (ADMINLTE / BLOOM THEME) -->
                            <div class="pc-card">
                                <div class="pc-card-header">
                                    <div class="pc-title-group">
                                        <div class="pc-icon"><i class="fas fa-clipboard-check"></i></div>
                                        <div>
                                            <h2 class="pc-title">Finalized Attendance Master Registry</h2>
                                            <p class="pc-muted mt-1">Verified attendance biometrics, activity breakdown, and payroll reconciliation for <?= date('F Y', mktime(0, 0, 0, $selectedMonth, 1, $selectedYear)) ?>.</p>
                                        </div>
                                    </div>

                                    <div class="pc-actions">
                                        <span class="pc-badge pc-purple">
                                            <i class="fas fa-lock"></i> Read-Only Mode (Locked)
                                        </span>
                                        <span class="pc-badge pc-green">
                                            <i class="fas fa-check-double"></i> Ingestion Ready
                                        </span>
                                    </div>
                                </div>

                                <div class="pc-body p-0">
                                    <table id="attendanceTable" class="table table-custom table-hover mb-0" style="width:100%;">
                                        <thead>
                                            <tr class="group-head">
                                                <th style="vertical-align:middle;">EMPLOYEE PROFILE</th>
                                                <th colspan="2" class="baseline">CYCLE BASELINE</th>
                                                <th colspan="5" class="activity"><i class="far fa-calendar-check"></i>&nbsp; ATTENDANCE ACTIVITY BREAKDOWN</th>
                                                <th colspan="2" class="payroll"><i class="fas fa-money-check-alt"></i>&nbsp; PAYROLL RECONCILIATION</th>
                                            </tr>
                                            <tr class="labels">
                                                <th>Employee &amp; ID</th>
                                                <th>Total Period</th>
                                                <th>Holidays &amp; Offs</th>
                                                <th>Working Days</th>
                                                <th>Present</th>
                                                <th>Leave</th>
                                                <th>Absent</th>
                                                <th>WFH</th>
                                                <th>Paid Days</th>
                                                <th>Unpaid / LOP</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <?php if (!empty($records)): ?>
                                                <?php foreach ($records as $row):
                                                    $empId = trim($row['emp_id'] ?? '');
                                                    $empName = trim($row['emp_name'] ?? '');
                                                    $parts = preg_split('/\s+/', $empName, -1, PREG_SPLIT_NO_EMPTY) ?: [];
                                                    $initials = !empty($parts)
                                                        ? (count($parts) > 1
                                                            ? strtoupper(substr($parts[0], 0, 1) . substr(end($parts), 0, 1))
                                                            : strtoupper(substr($parts[0], 0, 2)))
                                                        : 'NA';
                                                ?>
                                                    <tr>
                                                        <td>
                                                            <div class="employee">
                                                                <span class="avatar"><?= esc($initials) ?></span>
                                                                <span class="employee-details">
                                                                    <span class="emp-name"><?= esc($empName) ?></span>
                                                                    <span class="emp-id"><?= esc($empId) ?></span>
                                                                </span>
                                                            </div>
                                                        </td>
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
                                            <?php endif; ?>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        <?php else: ?>
                            <!-- ATTENDANCE NOT FINALIZED ALERT CARD -->
                            <div class="pc-card">
                                <div class="pc-body text-center py-5">
                                    <div style="width:70px; height:70px; border-radius:50%; background:#fff8e7; color:#d97706; display:inline-flex; align-items:center; justify-content:center; font-size:32px; margin-bottom:16px;">
                                        <i class="fas fa-exclamation-triangle"></i>
                                    </div>

                                    <h3 style="font-size:18px; font-weight:800; color:#1e293b; margin-bottom:8px;">
                                        Attendance Cycle Not Finalized for <?= date('F Y', mktime(0, 0, 0, $selectedMonth, 1, $selectedYear)) ?>
                                    </h3>

                                    <p class="text-muted" style="max-width:540px; margin:0 auto 20px; font-size:13px; line-height:1.6;">
                                        The monthly attendance records for <strong><?= date('F Y', mktime(0, 0, 0, $selectedMonth, 1, $selectedYear)) ?></strong> have not been finalized yet.
                                        Payroll processing requires verified and locked attendance before calculating CTC splits and deductions.
                                    </p>

                                    <div class="d-flex align-items-center justify-content-center gap-3">
                                       <a href="<?= esc($attendanceFinalizeUrl) ?>" class="pc-btn pc-btn-primary">
                                            <i class="fas fa-external-link-alt mr-1"></i> Open Attendance Cycle &amp; Finalize
                                        </a>
                                    </div>
                                </div>
                            </div>
                        <?php endif; ?>

                        <!-- WORKFLOW ACTION BAR -->
                        <div class="pc-bottom-bar">
                            <div>
                                <?php if ($is_status_true): ?>
                                    <strong id="statusMessage" style="font-size: 13px; color: var(--bloom-success);">
                                        <i class="fas fa-check-circle mr-1"></i> Attendance Verified &amp; Ingested
                                    </strong>
                                    <div class="pc-muted">Cycle <?= date('M Y', mktime(0, 0, 0, $selectedMonth, 1, $selectedYear)) ?> · Ready for Step 2 Salary Review</div>
                                <?php else: ?>
                                    <strong id="statusMessage" style="font-size: 13px; color: #d97706;">
                                        <i class="fas fa-lock mr-1"></i> Step 2 Locked: Finalize Attendance First
                                    </strong>
                                    <div class="pc-muted">Cycle <?= date('M Y', mktime(0, 0, 0, $selectedMonth, 1, $selectedYear)) ?> · Status Pending</div>
                                <?php endif; ?>
                            </div>

                            <div class="pc-bottom-actions">
                                <a href="<?= base_url('payroll/payroll_dashboard') ?>" class="pc-btn">
                                    <i class="fas fa-arrow-left mr-1"></i> Dashboard
                                </a>

                                <?php if ($is_status_true): ?>
                                    <a href="<?= base_url('payroll/step2') ?>?month=<?= (int) $selectedMonth ?>&year=<?= (int) $selectedYear  ?>" id="proceedStep2Btn" class="pc-btn pc-btn-primary">
                                        Next: Step 2 Salary Review
                                        <i class="fas fa-arrow-right ml-1"></i>
                                    </a>
                                <?php else: ?>
                                    <button type="button" class="pc-btn pc-btn-primary" disabled style="opacity:0.55; cursor:not-allowed;" title="Attendance must be finalized before proceeding to Step 2">
                                        Next: Step 2 Salary Review
                                        <i class="fas fa-lock ml-1"></i>
                                    </button>
                                <?php endif; ?>
                            </div>
                        </div>

                    </div>

            </section>
        </div>

    </div>

    <script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>

    <script>
        $(document).ready(function () {
            if ($('#attendanceTable').length) {
                $('#attendanceTable').DataTable({
                    responsive: false,
                    paging: true,
                    ordering: true,
                    order: [],
                    orderCellsTop: false,
                    searching: true,
                    info: true,
                    lengthChange: true,
                    pageLength: 10,
                    lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, "All"]],
                    dom: "<'row'<'col-md-6'l><'col-md-6'f>>" +
                         "<'table-responsive'tr>" +
                         "<'row'<'col-md-6'i><'col-md-6'p>>",
                    language: {
                        search: 'Search:',
                        searchPlaceholder: 'Search employees...',
                        lengthMenu: 'Show _MENU_ entries',
                        info: 'Showing _START_ to _END_ of _TOTAL_ employees',
                        infoEmpty: 'No employees available',
                        emptyTable: 'No payroll attendance records available for this period.',
                        zeroRecords: 'No matching attendance records found',
                        paginate: {
                            previous: 'Previous',
                            next: 'Next'
                        }
                    }
                });
            }

            function reloadWithFilter() {
                const month = $('#selectMonth').val();
                const year = $('#selectYear').val();
                const url = new URL(window.location.origin + window.location.pathname);
                url.searchParams.set('month', month);
                url.searchParams.set('year', year);
                // Don't carry over stale completion tokens for a different period
                window.location.href = url.toString();
            }


            $('#selectMonth, #selectYear').on('change', function () {
                reloadWithFilter();
            });

            $('#saveDraftBtn').on('click', function () {
                const btn = $(this);
                const original = btn.html();
                btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Saving...');
                setTimeout(function () {
                    btn.prop('disabled', false).html('<i class="fas fa-check"></i> Saved');
                    setTimeout(function () {
                        btn.html(original);
                    }, 1500);
                }, 500);
            });
        });
    </script>
</body>

</html>