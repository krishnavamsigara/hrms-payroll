<!DOCTYPE html>
<html lang="en">

<head>

    <meta charset="utf-8">

    <meta name="viewport" content="width=device-width, initial-scale=1">

    <title>BloomHR | Employee Timesheet</title>

    <!-- Google Font -->
    <link rel="stylesheet"
        href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">

    <!-- Font Awesome -->
    <link rel="stylesheet"
        href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">

    <!-- Bootstrap -->
    <link rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/css/bootstrap.min.css">


    <style>

        :root {
            --bloom-purple: #4a00e0;
            --bloom-dark: #2a0080;
            --bloom-success: #10b981;
            --bloom-danger: #dc2626;
            --bloom-warning: #f59e0b;

            --page-bg: #f8fafc;
            --border: #e2e8f0;
            --text-dark: #1e293b;
            --text-muted: #64748b;
        }


        * {
            box-sizing: border-box;
        }


        body {
            margin: 0;
            background: #f8fafc;
            color: #334155;
            font-family: 'Plus Jakarta Sans', sans-serif;
            font-size: 13px;
        }


        /* =====================================================
           MAIN PAGE
        ===================================================== */

        .timesheet-page {
    width: 100%;
    padding: 10px 0 25px 0;
    background: #f8fafc;
}


        /* =====================================================
           PAGE HEADER
        ===================================================== */

        .page-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 20px;
        }


        .page-title h3 {
            margin: 0 0 5px;
            color: #111827;
            font-size: 25px;
            font-weight: 800;
        }


        .page-title p {
            margin: 0;
            color: #64748b;
            font-size: 13px;
            font-weight: 500;
        }


        /* =====================================================
           FILTERS
        ===================================================== */

        .top-filters {
            display: flex;
            align-items: center;
            gap: 10px;
        }


        .search-box {
            position: relative;
        }


        .search-box i {
            position: absolute;
            left: 13px;
            top: 12px;
            color: #64748b;
            font-size: 12px;
        }


        .search-input {
            width: 240px;
            height: 36px;
            padding: 0 12px 0 34px;
            border: 1px solid #cbd5e1;
            border-radius: 6px;
            background: #fff;
            color: #334155;
            font-size: 12px;
            outline: none;
        }


        .search-input:focus {
            border-color: #4a00e0;
            box-shadow: 0 0 0 2px rgba(74, 0, 224, .08);
        }


        .department-select,
        .period-select {
            height: 36px;
            padding: 0 12px;
            border: 1px solid #cbd5e1;
            border-radius: 6px;
            background: #fff;
            color: #334155;
            font-size: 12px;
            outline: none;
        }


        .department-select {
            width: 180px;
        }


        .period-select {
            width: 190px;
        }


        .department-select:focus,
        .period-select:focus {
            border-color: #4a00e0;
            box-shadow: 0 0 0 2px rgba(74, 0, 224, .08);
        }


        /* =====================================================
           EMPLOYEE + SUMMARY SECTION
        ===================================================== */

        .summary-grid {
            display: grid;
            grid-template-columns: 300px repeat(4, 1fr);
            gap: 14px;
            margin-bottom: 14px;
        }


        /* =====================================================
           EMPLOYEE CARD
        ===================================================== */

        .employee-card {
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 22px;
            box-shadow: 0 3px 8px rgba(15, 23, 42, 0.03);
            min-height: 190px;
        }


        .employee-profile {
            display: flex;
            flex-direction: column;
            align-items: center;
            text-align: center;
        }


        .employee-avatar {
    width: 78px;
    height: 78px;
    border-radius: 50%;
    display: block;
    object-fit: cover;
    margin-bottom: 10px;
    border: 3px solid #e0e7ff;
}


        .employee-avatar i {
            color: #94a3b8;
            font-size: 42px;
        }


        .employee-name {
            margin: 0;
            color: #111827;
            font-size: 17px;
            font-weight: 800;
        }


        .employee-id {
            margin-top: 3px;
            color: #174dcc;
            font-size: 12px;
            font-weight: 700;
        }


        .employee-role {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            margin-top: 8px;
            padding: 5px 11px;
            border-radius: 15px;
            background: #eef0f7;
            color: #475569;
            font-size: 10px;
            font-weight: 700;
        }


        .employee-info {
            display: flex;
            width: 100%;
            margin-top: 17px;
            padding-top: 13px;
            border-top: 1px solid #cbd5e1;
            justify-content: space-between;
            text-align: left;
        }


        .info-block {
            width: 48%;
        }


        .info-label {
            display: block;
            margin-bottom: 4px;
            color: #475569;
            font-size: 9px;
            font-weight: 800;
            text-transform: uppercase;
        }


        .info-value {
            color: #1e293b;
            font-size: 10px;
            font-weight: 600;
        }


        /* =====================================================
           STAT CARDS
        ===================================================== */

        .stat-card {
            position: relative;
            min-height: 190px;
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 19px;
            box-shadow: 0 3px 8px rgba(15, 23, 42, 0.03);
            overflow: hidden;
        }


        .stat-icon {
            width: 38px;
            height: 38px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 7px;
            background: #e0e7ff;
            color: #4a00e0;
            font-size: 16px;
            margin-bottom: 17px;
        }


        .stat-icon.green {
            background: #dcfce7;
            color: #15803d;
        }


        .stat-icon.orange {
            background: #ffedd5;
            color: #ea580c;
        }


        .stat-icon.blue {
            background: #dbeafe;
            color: #2563eb;
        }


        .stat-label {
            color: #475569;
            font-size: 10px;
            font-weight: 800;
            text-transform: uppercase;
            line-height: 1.4;
        }


        .stat-value {
            margin-top: 6px;
            color: #111827;
            font-size: 24px;
            font-weight: 800;
        }


        .stat-unit {
            margin-left: 3px;
            color: #64748b;
            font-size: 11px;
            font-weight: 600;
        }


        .stat-badge {
            position: absolute;
            top: 19px;
            right: 15px;
            padding: 5px 8px;
            border-radius: 4px;
            background: #e0e7ff;
            color: #4338ca;
            font-size: 9px;
            font-weight: 800;
        }


        .stat-badge.green {
            background: #dcfce7;
            color: #15803d;
        }


        /* =====================================================
           PERIOD ACTION CARD
        ===================================================== */

        .period-card {
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 14px;
            margin-bottom: 14px;
            box-shadow: 0 3px 8px rgba(15, 23, 42, 0.03);

            display: flex;
            justify-content: space-between;
            align-items: center;
        }


        .period-text {
            color: #334155;
            font-size: 12px;
            font-weight: 600;
        }


        .period-actions {
            display: flex;
            gap: 10px;
        }


        .btn-export {
            height: 34px;
            padding: 0 15px;
            background: #fff;
            border: 1px solid #cbd5e1;
            border-radius: 6px;
            color: #334155;
            font-size: 11px;
            font-weight: 700;
        }


        .btn-export:hover {
            border-color: #4a00e0;
            color: #4a00e0;
            background: #faf8ff;
        }


        .btn-print {
            height: 34px;
            padding: 0 16px;
            background: linear-gradient(
                135deg,
                #4a00e0 0%,
                #2a0080 100%
            );
            border: none;
            border-radius: 6px;
            color: #fff;
            font-size: 11px;
            font-weight: 700;
        }


        .btn-print:hover {
            box-shadow: 0 5px 12px rgba(74, 0, 224, 0.20);
        }


        /* =====================================================
           LOWER CARDS
        ===================================================== */

        .details-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 14px;
            margin-bottom: 14px;
        }


        .details-card {
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 18px;
            min-height: 105px;
            box-shadow: 0 3px 8px rgba(15, 23, 42, 0.03);
        }


        .details-card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }


        .details-title {
            display: flex;
            align-items: center;
            gap: 10px;
        }


        .details-icon {
            width: 35px;
            height: 35px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 6px;
            background: #e0e7ff;
            color: #4a00e0;
        }


        .details-icon.gray {
            background: #e2e8f0;
            color: #64748b;
        }


        .details-heading {
            color: #1e293b;
            font-size: 11px;
            font-weight: 800;
            text-transform: uppercase;
        }


        .details-badge {
            padding: 5px 8px;
            border-radius: 4px;
            background: #eef0f7;
            color: #475569;
            font-size: 9px;
            font-weight: 800;
        }


        .leave-values {
            display: flex;
            justify-content: space-around;
            text-align: center;
        }


        .leave-item {
            min-width: 70px;
        }


        .leave-label {
            color: #64748b;
            font-size: 9px;
            font-weight: 700;
            text-transform: uppercase;
        }


        .leave-value {
            margin-top: 4px;
            color: #1e293b;
            font-size: 17px;
            font-weight: 800;
        }


        .shift-details {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding-top: 4px;
        }


        .shift-item {
            width: 48%;
        }


        .shift-label {
            color: #64748b;
            font-size: 9px;
            font-weight: 800;
            text-transform: uppercase;
        }


        .shift-value {
            margin-top: 5px;
            color: #1e293b;
            font-size: 11px;
            font-weight: 700;
        }


        /* =====================================================
           ATTENDANCE TABLE CARD
        ===================================================== */

        .attendance-card {
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 3px 8px rgba(15, 23, 42, 0.03);
        }


        .attendance-table {
            width: 100%;
            margin: 0 !important;
        }


        .attendance-table thead th {
            background: #eef0f8;
            border-top: none !important;
            border-bottom: 1px solid #dbe1eb !important;
            color: #475569;
            padding: 11px 14px;
            font-size: 9px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: .4px;
            white-space: nowrap;
        }


        .attendance-table tbody td {
            padding: 13px 14px;
            border-top: 1px solid #eef2f7 !important;
            vertical-align: middle;
            color: #334155;
            font-size: 11px;
            font-weight: 500;
        }


        .attendance-table tbody tr:hover {
            background: #fafbff;
        }


        .date-main {
            color: #1e293b;
            font-weight: 700;
        }


        .status-badge {
            display: inline-block;
            padding: 5px 8px;
            border-radius: 4px;
            font-size: 8px;
            font-weight: 800;
            text-transform: uppercase;
        }


        .status-present {
            background: #dcfce7;
            color: #15803d;
        }


        .status-late {
            background: #fee2e2;
            color: #dc2626;
        }


        .status-leave {
            background: #fef3c7;
            color: #b45309;
        }


        .status-off {
            background: #e2e8f0;
            color: #475569;
        }


        .time-value {
            color: #334155;
            font-family: monospace;
            font-size: 11px;
            font-weight: 600;
        }


        .late-value {
            color: #dc2626;
            font-weight: 700;
        }


        .empty-value {
            color: #94a3b8;
        }


        .action-icon {
            color: #174dcc;
            font-size: 13px;
            margin-left: 8px;
            cursor: pointer;
        }


        .action-icon:hover {
            color: #4a00e0;
        }


        /* =====================================================
           RESPONSIVE
        ===================================================== */

        @media (max-width: 1200px) {

            .summary-grid {
                grid-template-columns: 280px repeat(2, 1fr);
            }

            .employee-card {
                grid-row: span 2;
            }

            .top-filters {
                flex-wrap: wrap;
            }

        }


        @media (max-width: 900px) {

            .timesheet-page {
                padding: 15px;
            }

            .page-header {
                flex-direction: column;
                gap: 15px;
            }

            .top-filters {
                width: 100%;
            }

            .search-input,
            .department-select,
            .period-select {
                width: 100%;
            }

            .summary-grid {
                grid-template-columns: 1fr 1fr;
            }

            .employee-card {
                grid-column: span 2;
                grid-row: auto;
            }

            .details-grid {
                grid-template-columns: 1fr;
            }

        }


        @media (max-width: 600px) {

            .summary-grid {
                grid-template-columns: 1fr;
            }

            .employee-card {
                grid-column: auto;
            }

            .period-card {
                flex-direction: column;
                align-items: flex-start;
                gap: 12px;
            }

            .period-actions {
                width: 100%;
            }

            .period-actions button {
                flex: 1;
            }

            .attendance-card {
                overflow-x: auto;
            }

            .attendance-table {
                min-width: 950px;
            }

        }

            .summary-grid {
        display: grid;
        grid-template-columns: 300px 1fr;
        gap: 14px;
        margin-bottom: 14px;
        align-items: stretch;
    }

    .employee-card {
        height: 100%;
        min-height: 0;
    }

    .summary-right {
        display: grid;
        grid-template-rows: auto auto auto;
        gap: 14px;
        min-width: 0;
    }

    .stats-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 14px;
    }

    .period-card {
        margin: 0;
    }

    .details-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 14px;
        margin: 0;
    }

    .stat-card {
        min-height: 150px;
    }

    </style>

</head>


<body>


<div class="content-wrapper">

  <section class="content pt-3">
    <!-- =====================================================
         PAGE HEADER
    ====================================================== -->

   <div class="container-fluid">

            <div class="page-header">

    <!-- LEFT SIDE -->
    <div class="page-title">

        <h3>Employee Timesheet</h3>

        <p>
            Review detailed attendance logs and timesheets.
        </p>

    </div>

    <!-- RIGHT SIDE -->
    <div class="top-filters">

        <!-- Search -->
        <div class="search-box">
            <i class="fas fa-search"></i>

            <input type="text"
                   id="employeeSearch"
                   class="search-input"
                   placeholder="Search Employee...">
        </div>

        <!-- Department -->
        <select class="department-select">

            <option>All Departments</option>
            <option>Business Analyst</option>
            <option>Designing</option>
            <option>Front-End Development</option>
            <option>Functional</option>
            <option>Human Resource</option>
            <option>Marketing</option>
            <option>Technical</option>

        </select>

        <!-- Period -->
        <select class="period-select">

            <option>Oct 25 - Nov 24, 2023</option>
            <option>Sep 25 - Oct 24, 2023</option>
            <option>Aug 25 - Sep 24, 2023</option>

        </select>

    </div>

</div>

    </div>


    <!-- =====================================================
         SUMMARY GRID
    ====================================================== -->

    <div class="summary-grid">

    <!-- LEFT: EMPLOYEE PROFILE -->
    <div class="employee-card">

        <div class="employee-profile">

            <img
    src="https://ui-avatars.com/api/?name=<?= urlencode($employee_name ?? 'Alex Mitchell') ?>&background=4a00e0&color=fff&bold=true"
    alt="<?= esc($employee_name ?? 'Alex Mitchell') ?>"
    class="employee-avatar">
            <h4 class="employee-name">
                Alex Mitchell
            </h4>

            <div class="employee-id">
                EMP-4921
            </div>

            <div class="employee-role">
                <i class="fas fa-user-tie"></i>
                Senior Frontend Engineer
            </div>

            <div class="employee-info">

                <div class="info-block">
                    <span class="info-label">Manager</span>
                    <span class="info-value">
                        Sarah Jenkins
                    </span>
                </div>

                <div class="info-block">
                    <span class="info-label">Shift</span>
                    <span class="info-value">
                        General (09:00 - 18:00)
                    </span>
                </div>

            </div>

        </div>

    </div>


    <!-- RIGHT SIDE -->
    <div class="summary-right">

        <!-- TOP 4 CARDS -->
        <div class="stats-grid">

            <!-- Total Hours -->
            <div class="stat-card">

            <div class="stat-icon">

                <i class="far fa-clock"></i>

            </div>


            <span class="stat-badge">
                22 DAYS
            </span>


            <div class="stat-label">
                Total Hours<br>
                Worked
            </div>


            <div class="stat-value">

                178.5

                <span class="stat-unit">
                    hrs
                </span>

            </div>

        </div>

            <!-- Avg Daily Hours -->
            <div class="stat-card">

            <div class="stat-icon green">

                <i class="fas fa-stopwatch"></i>

            </div>


            <div class="stat-label">
                Avg Daily Hours
            </div>


            <div class="stat-value">

                8.1

                <span class="stat-unit">
                    hrs
                </span>

            </div>

        </div>

            <!-- Total Overtime -->
            <div class="stat-card">

            <div class="stat-icon orange">

                <i class="fas fa-stopwatch"></i>

            </div>


            <div class="stat-label">
                Total Overtime
            </div>


            <div class="stat-value">

                12.5

                <span class="stat-unit">
                    hrs
                </span>

            </div>

        </div>



            <!-- Attendance -->
             <div class="stat-card">

            <div class="stat-icon blue">

                <i class="fas fa-clipboard-check"></i>

            </div>


            <span class="stat-badge green">
                ↗ 2%
            </span>


            <div class="stat-label">
                Attendance %
            </div>


            <div class="stat-value">
                98%
            </div>

        </div>


        </div>


        <!-- PERIOD -->
        <div class="period-card">

            <div class="period-text">
                Period:
                <strong>
                    Oct 25, 2023 - Nov 24, 2023
                </strong>
            </div>

            <div class="period-actions">

                <button class="btn-export">
                    <i class="fas fa-download mr-1"></i>
                    Export CSV
                </button>

                <button class="btn-print">
                    <i class="fas fa-print mr-1"></i>
                    Print Report
                </button>

            </div>

        </div>


        <!-- LEAVE + SHIFT -->
        <div class="details-grid">

             <!-- LEAVE BALANCE -->

        <div class="details-card">

            <div class="details-card-header">

                <div class="details-title">

                    <div class="details-icon">

                        <i class="far fa-calendar-check"></i>

                    </div>

                    <span class="details-heading">
                        Leave Balance
                    </span>

                </div>


                <span class="details-badge">
                    LEAVE BALANCE
                </span>

            </div>


            <div class="leave-values">


                <div class="leave-item">

                    <div class="leave-label">
                        PL
                    </div>

                    <div class="leave-value">
                        12
                    </div>

                </div>


                <div class="leave-item">

                    <div class="leave-label">
                        SL
                    </div>

                    <div class="leave-value">
                        05
                    </div>

                </div>


                <div class="leave-item">

                    <div class="leave-label">
                        CL
                    </div>

                    <div class="leave-value">
                        03
                    </div>

                </div>


            </div>

        </div>


           <!-- SHIFT DETAILS -->

        <div class="details-card">

            <div class="details-card-header">

                <div class="details-title">

                    <div class="details-icon gray">

                        <i class="far fa-clock"></i>

                    </div>

                    <span class="details-heading">
                        Shift Details
                    </span>

                </div>


                <span class="details-badge">
                    SHIFT DETAILS
                </span>

            </div>


            <div class="shift-details">


                <div class="shift-item">

                    <div class="shift-label">
                        Hours
                    </div>

                    <div class="shift-value">
                        09:00 - 18:00
                    </div>

                </div>


                <div class="shift-item">

                    <div class="shift-label">
                        Break
                    </div>

                    <div class="shift-value">
                        60 mins
                    </div>

                </div>


            </div>

        </div>



        </div>

    </div>

</div>

    <!-- =====================================================
         ATTENDANCE TABLE
    ====================================================== -->

    <div class="attendance-card">

        <div class="table-responsive">

            <table class="table attendance-table"
                   id="attendanceTable">


                <thead>

                    <tr>

                        <th>
                            Date
                        </th>

                        <th>
                            Status
                        </th>

                        <th>
                            First In
                        </th>

                        <th>
                            Last Out
                        </th>

                        <th>
                            Total Hrs
                        </th>

                        <th>
                            Late (M)
                        </th>

                        <th>
                            Early (M)
                        </th>

                        <th>
                            OT (Hrs)
                        </th>

                        <th class="text-right">
                            Actions
                        </th>

                    </tr>

                </thead>


                <tbody>


                    <!-- =================================================
                         ROW 1
                    ================================================== -->

                    <tr>

                        <td>
                            <span class="date-main">
                                01 Nov, Wed
                            </span>
                        </td>


                        <td>

                            <span class="status-badge status-present">
                                Present
                            </span>

                        </td>


                        <td>

                            <span class="time-value">
                                08:55 AM
                            </span>

                        </td>


                        <td>

                            <span class="time-value">
                                06:15 PM
                            </span>

                        </td>


                        <td>

                            <strong>
                                08:20
                            </strong>

                        </td>


                        <td>
                            <span class="empty-value">
                                -
                            </span>
                        </td>


                        <td>
                            <span class="empty-value">
                                -
                            </span>
                        </td>


                        <td>
                            0.3
                        </td>


                        <td class="text-right">

                            <i class="far fa-calendar-alt action-icon"
                               title="Attendance"></i>

                            <i class="far fa-eye action-icon"
                               title="View Details"></i>

                        </td>

                    </tr>


                    <!-- =================================================
                         ROW 2
                    ================================================== -->

                    <tr>

                        <td>

                            <span class="date-main">
                                02 Nov, Thu
                            </span>

                        </td>


                        <td>

                            <span class="status-badge status-late">
                                Late
                            </span>

                        </td>


                        <td>

                            <span class="time-value late-value">
                                09:45 AM
                            </span>

                        </td>


                        <td>

                            <span class="time-value">
                                06:30 PM
                            </span>

                        </td>


                        <td>

                            <strong>
                                07:45
                            </strong>

                        </td>


                        <td>

                            <span class="late-value">
                                45
                            </span>

                        </td>


                        <td>

                            <span class="empty-value">
                                -
                            </span>

                        </td>


                        <td>

                            <span class="empty-value">
                                -
                            </span>

                        </td>


                        <td class="text-right">

                            <i class="far fa-calendar-alt action-icon"></i>

                            <i class="far fa-eye action-icon"></i>

                        </td>

                    </tr>


                    <!-- =================================================
                         ROW 3
                    ================================================== -->

                    <tr>

                        <td>

                            <span class="date-main">
                                03 Nov, Fri
                            </span>

                        </td>


                        <td>

                            <span class="status-badge status-leave">
                                Leave (PL)
                            </span>

                        </td>


                        <td colspan="6">

                            <span style="color:#64748b;font-style:italic;">
                                Approved Annual Leave
                            </span>

                        </td>


                        <td class="text-right">

                            <i class="far fa-calendar-alt action-icon"></i>

                            <i class="far fa-eye-slash action-icon"
                               style="color:#94a3b8;"></i>

                        </td>

                    </tr>


                    <!-- =================================================
                         ROW 4
                    ================================================== -->

                    <tr>

                        <td>

                            <span class="date-main">
                                04 Nov, Sat
                            </span>

                        </td>


                        <td>

                            <span class="status-badge status-off">
                                Weekly Off
                            </span>

                        </td>


                        <td colspan="6">

                            <span class="empty-value">
                                -
                            </span>

                        </td>


                        <td class="text-right">

                            <i class="far fa-calendar-alt action-icon"></i>

                            <i class="far fa-eye-slash action-icon"
                               style="color:#94a3b8;"></i>

                        </td>

                    </tr>


                    <!-- =================================================
                         ROW 5
                    ================================================== -->

                    <tr>

                        <td>

                            <span class="date-main">
                                05 Nov, Sun
                            </span>

                        </td>


                        <td>

                            <span class="status-badge status-off">
                                Weekly Off
                            </span>

                        </td>


                        <td colspan="6">

                            <span class="empty-value">
                                -
                            </span>

                        </td>


                        <td class="text-right">

                            <i class="far fa-calendar-alt action-icon"></i>

                            <i class="far fa-eye-slash action-icon"
                               style="color:#94a3b8;"></i>

                        </td>

                    </tr>


                </tbody>

            </table>

        </div>

    </div>

  </section>

</div>


<!-- =====================================================
     SCRIPTS
====================================================== -->

<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/fullcalendar@5.11.3/main.min.js"></script>

<script>

$(document).ready(function () {


    /* =====================================================
       EMPLOYEE SEARCH
    ===================================================== */

    $('#employeeSearch').on('keyup', function () {

        var value = $(this).val().toLowerCase();

        $('#attendanceTable tbody tr').filter(function () {

            $(this).toggle(
                $(this).text().toLowerCase().indexOf(value) > -1
            );

        });

    });


    /* =====================================================
       EXPORT CSV
    ===================================================== */

    $('#exportCsv').on('click', function () {

        var csv = [];

        var rows = document.querySelectorAll(
            '#attendanceTable tr'
        );

        rows.forEach(function (row) {

            var cols = row.querySelectorAll('th, td');

            var rowData = [];

            cols.forEach(function (col) {

                rowData.push(
                    '"' +
                    col.innerText
                        .replace(/"/g, '""')
                        .trim() +
                    '"'
                );

            });

            csv.push(rowData.join(','));

        });


        var csvFile = new Blob(
            [csv.join('\n')],
            {
                type: 'text/csv'
            }
        );


        var downloadLink =
            document.createElement('a');

        downloadLink.download =
            'Employee_Timesheet.csv';

        downloadLink.href =
            window.URL.createObjectURL(csvFile);

        downloadLink.style.display =
            'none';

        document.body.appendChild(
            downloadLink
        );

        downloadLink.click();

        document.body.removeChild(
            downloadLink
        );

    });


    /* =====================================================
       PRINT REPORT
    ===================================================== */

    $('#printReport').on('click', function () {

        window.print();

    });


});

</script>


</body>

</html>