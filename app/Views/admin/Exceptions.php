<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <title>BloomHR | Exceptions Dashboard</title>

    <!-- Google Font -->
    <link rel="stylesheet"
        href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">

    <!-- Font Awesome -->
    <link rel="stylesheet"
        href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">

    <!-- Bootstrap -->
    <link rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/css/bootstrap.min.css">

    <!-- AdminLTE -->
    <link rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">

    <!-- DataTables -->
    <link rel="stylesheet"
        href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">


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


        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: #f8fafc;
            color: #334155;
            font-size: 13px;
            margin: 0;
        }


        /* =========================
           MAIN PAGE
        ========================= */

        .exceptions-page {
            min-height: 100vh;
            padding: 25px;
            background: #f8fafc;
        }


        /* =========================
           PAGE HEADER
        ========================= */

        .page-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 18px;
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


        /* =========================
           HEADER BUTTONS
        ========================= */

        .header-actions {
            display: flex;
            gap: 10px;
        }

        .btn-export {
            background: #fff;
            border: 1px solid #cbd5e1;
            color: #334155;
            border-radius: 8px;
            padding: 9px 16px;
            font-size: 12px;
            font-weight: 700;
        }

        .btn-export:hover {
            border-color: var(--bloom-purple);
            color: var(--bloom-purple);
            background: #faf8ff;
        }

        .btn-bulk {
            background: linear-gradient(
                135deg,
                #4a00e0 0%,
                #2a0080 100%
            );
            color: #fff !important;
            border: none;
            border-radius: 8px;
            padding: 9px 17px;
            font-size: 12px;
            font-weight: 700;
        }

        .btn-bulk:hover {
            box-shadow: 0 5px 12px rgba(74, 0, 224, 0.20);
        }


        /* =========================
           FILTER CARD
        ========================= */

        .filter-card {
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 18px;
            margin-bottom: 18px;
            box-shadow: 0 3px 8px rgba(15, 23, 42, 0.03);
        }

        .filter-row {
            display: flex;
            gap: 16px;
        }

        .filter-item {
            flex: 1;
        }

        .filter-label {
            display: block;
            margin-bottom: 7px;
            color: #334155;
            font-size: 11px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: .4px;
        }

        .filter-select {
            width: 100%;
            height: 40px;
            padding: 0 12px;
            border: 1px solid #cbd5e1;
            border-radius: 6px;
            background: #fff;
            color: #334155;
            font-size: 13px;
            outline: none;
        }

        .filter-select:focus {
            border-color: #4a00e0;
            box-shadow: 0 0 0 2px rgba(74, 0, 224, .08);
        }


        /* =========================
           FILTER BOTTOM
        ========================= */

        .filter-bottom {
            display: flex;
            align-items: center;
            gap: 12px;
            border-top: 1px solid #e2e8f0;
            margin-top: 13px;
            padding-top: 13px;
        }

        .current-week {
            display: inline-flex;
            align-items: center;
            gap: 5px;
            padding: 6px 11px;
            border-radius: 18px;
            background: #dbeafe;
            color: #475569;
            font-size: 12px;
            font-weight: 600;
        }

        .current-week i {
            font-size: 10px;
            color: #64748b;
        }

        .clear-filter {
            border: none;
            background: transparent;
            color: #4a00e0;
            font-size: 12px;
            font-weight: 700;
            cursor: pointer;
        }


        /* =========================
           EXCEPTION CARD
        ========================= */

        .exception-card {
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            margin-bottom: 18px;
            overflow: hidden;
            box-shadow: 0 3px 8px rgba(15, 23, 42, 0.03);
        }

        .exception-card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px 18px;
            border-bottom: 1px solid #e2e8f0;
        }

        .section-title {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .section-title i {
            color: #dc2626;
            font-size: 18px;
        }

        .section-title h5 {
            margin: 0;
            color: #111827;
            font-size: 19px;
            font-weight: 800;
        }

        .action-count {
            background: #fee2e2;
            color: #b91c1c;
            border-radius: 8px;
            padding: 6px 10px;
            font-size: 10px;
            font-weight: 800;
        }

        .pending-count {
            background: #dbeafe;
            color: #475569;
        }


        /* =========================
           TABLE
        ========================= */

        .exception-table {
            width: 100%;
            margin: 0 !important;
        }

        .exception-table thead th {
            background: #eef0f8;
            border-top: none !important;
            border-bottom: 1px solid #dbe1eb !important;
            color: #475569;
            padding: 11px 14px;
            font-size: 10px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: .5px;
            white-space: nowrap;
        }

        .exception-table tbody td {
            padding: 12px 14px;
            border-top: 1px solid #eef2f7 !important;
            vertical-align: middle;
            font-size: 12px;
            color: #334155;
        }

        .exception-table tbody tr:hover {
            background: #fafbff;
        }


        /* =========================
           CHECKBOX
        ========================= */

        .custom-check {
            width: 16px;
            height: 16px;
            cursor: pointer;
        }


        /* =========================
           EMPLOYEE
        ========================= */

        .employee-wrapper {
            display: flex;
            align-items: center;
        }

        .avatar-circle {
            width: 34px;
            height: 34px;
            margin-right: 10px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #e0e7ff;
            color: #4338ca;
            font-size: 10px;
            font-weight: 800;
            flex-shrink: 0;
        }

        .avatar-orange {
            background: #ffedd5;
            color: #c2410c;
        }

        .employee-name {
            display: block;
            color: #1e293b;
            font-size: 12px;
            font-weight: 700;
        }

        .employee-code {
            display: block;
            margin-top: 2px;
            color: #64748b;
            font-size: 10px;
        }


        /* =========================
           TIME BADGES
        ========================= */

        .time-badge {
            display: inline-block;
            margin-right: 4px;
            padding: 4px 7px;
            border-radius: 4px;
            background: #eef0f7;
            color: #475569;
            font-size: 10px;
            font-weight: 600;
        }

        .missing-time {
            background: #fff1f2;
            border: 1px solid #fecaca;
            color: #ef4444;
        }


        /* =========================
           MISSING BADGE
        ========================= */

        .missing-badge {
            display: inline-block;
            padding: 5px 8px;
            border-radius: 4px;
            background: #dc2626;
            color: #fff;
            font-size: 9px;
            font-weight: 800;
        }


        /* =========================
           RESOLVE
        ========================= */

        .resolve-link {
            color: #174dcc;
            text-decoration: none;
            font-size: 12px;
            font-weight: 600;
        }

        .resolve-link:hover {
            color: #4a00e0;
            text-decoration: underline;
        }


        /* =========================
           SEARCH
        ========================= */

        .search-wrapper {
            position: relative;
        }

        .search-wrapper i {
            position: absolute;
            left: 11px;
            top: 10px;
            color: #64748b;
            font-size: 12px;
        }

        .request-search {
            width: 275px;
            height: 35px;
            padding-left: 34px;
            padding-right: 10px;
            border: 1px solid #cbd5e1;
            border-radius: 6px;
            font-size: 12px;
            outline: none;
        }

        .request-search:focus {
            border-color: #4a00e0;
        }


        /* =========================
           SYSTEM LOG
        ========================= */

        .system-log {
            color: #475569;
            font-size: 11px;
        }

        .requested-update {
            color: #174dcc;
            font-size: 12px;
            font-weight: 700;
        }

        .update-type {
            display: inline-block;
            margin-top: 4px;
            padding: 3px 6px;
            border-radius: 3px;
            background: #eef0f7;
            color: #64748b;
            font-size: 9px;
            font-weight: 700;
        }


        /* =========================
           ACTION BUTTONS
        ========================= */

        .action-buttons {
            display: flex;
            justify-content: flex-end;
            gap: 8px;
        }

        .btn-reject,
        .btn-approve {
            width: 31px;
            height: 31px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 4px;
            cursor: pointer;
        }

        .btn-reject {
            background: #fff;
            color: #dc2626;
            border: 1px solid #ef4444;
        }

        .btn-reject:hover {
            background: #fee2e2;
        }

        .btn-approve {
            background: #4a00e0;
            color: #fff;
            border: 1px solid #4a00e0;
        }

        .btn-approve:hover {
            background: #2a0080;
        }


        /* =========================
           RESPONSIVE
        ========================= */

        @media (max-width: 900px) {

            .page-header {
                flex-direction: column;
                gap: 15px;
            }

            .filter-row {
                flex-direction: column;
            }

            .header-actions {
                width: 100%;
            }

            .header-actions button {
                flex: 1;
            }

        }

        @media (max-width: 600px) {

            .exceptions-page {
                padding: 15px;
            }

            .page-title h3 {
                font-size: 21px;
            }

            .exception-card {
                overflow-x: auto;
            }

            .exception-card-header {
                min-width: 800px;
            }

            .exception-table {
                min-width: 900px;
            }

        }

    </style>

</head>


<body>

<div class="content-wrapper">
     <section class="content pt-3">

        <div class="container-fluid">


    <!-- =========================================
         PAGE HEADER
    ========================================== -->

    <div class="page-header">

        <div class="page-title">

            <h3>
                Exceptions Dashboard
            </h3>

            <p>
                Review and resolve anomalies for the current week.
            </p>

        </div>

<!-- 
        <div class="header-actions">

            <button class="btn btn-export">

                <i class="fas fa-download mr-1"></i>

                Export Report

            </button>


            <button class="btn btn-bulk">

                <i class="fas fa-check-double mr-1"></i>

                Bulk Approve Selected

            </button>

        </div> -->

    </div>



    <!-- =========================================
         FILTER CARD
    ========================================== -->

    <div class="filter-card">

        <div class="filter-row">


            <div class="filter-item">

                <label class="filter-label">
                    Department
                </label>

                <select class="filter-select">

                    <option>
                        All Departments
                    </option>

                    <option>
                        Business Analyst
                    </option>

                    <option>
                        Designing
                    </option>

                    <option>
                        Front-End Development
                    </option>

                    <option>
                        Functional
                    </option>

                    <option>
                        Human Resource
                    </option>

                    <option>
                        Marketing
                    </option>

                    <option>
                        Technical
                    </option>

                </select>

            </div>



            <div class="filter-item">

                <label class="filter-label">
                    Manager
                </label>

                <select class="filter-select">

                    <option>
                        All Managers
                    </option>

                    <option>
                        Manager 1
                    </option>

                    <option>
                        Manager 2
                    </option>

                    <option>
                        Manager 3
                    </option>

                </select>

            </div>



            <div class="filter-item">

                <label class="filter-label">
                    Exception Type
                </label>

                <select class="filter-select">

                    <option>
                        All Types
                    </option>

                    <option>
                        Missing In-Punch
                    </option>

                    <option>
                        Missing Out-Punch
                    </option>

                    <option>
                        Regularization
                    </option>

                    <option>
                        Late Punch
                    </option>

                </select>

            </div>

        </div>


        <div class="filter-bottom">

            <span class="current-week">

                Current Week

                <i class="fas fa-times"></i>

            </span>


            <button class="clear-filter">
                Clear All
            </button>

        </div>

    </div>



    <!-- =========================================
         MISSING PUNCHES
    ========================================== -->

    <div class="exception-card">

        <div class="exception-card-header">

            <div class="section-title">

                <i class="fas fa-fingerprint"></i>

                <h5>
                    Missing Punches
                </h5>

                <span class="action-count">
                    12 Action Required
                </span>

            </div>


            <div>

                <i class="fas fa-filter mr-3 text-muted"
                   style="cursor:pointer;"></i>

                <i class="fas fa-expand-alt text-muted"
                   style="cursor:pointer;"></i>

            </div>

        </div>



        <div class="table-responsive">

            <table class="table exception-table"
                   id="missingPunchTable">

                <thead>

                    <tr>

                        <th width="45">
                            <input type="checkbox"
                                   class="custom-check"
                                   id="selectAllMissing">
                        </th>

                        <th>
                            Employee
                        </th>

                        <th>
                            Date
                        </th>

                        <th>
                            Shift
                        </th>

                        <th>
                            Recorded Punches
                        </th>

                        <th>
                            Missing
                        </th>

                        <th class="text-right">
                            Action
                        </th>

                    </tr>

                </thead>


                <tbody>


                    <!-- ROW 1 -->

                    <tr>

                        <td>

                            <input type="checkbox"
                                   class="custom-check missing-check">

                        </td>


                        <td>

                            <div class="employee-wrapper">

                                <div class="avatar-circle">
                                    MJ
                                </div>

                                <div>

                                    <span class="employee-name">
                                        Michael Johnson
                                    </span>

                                    <span class="employee-code">
                                        ENG-40
                                    </span>

                                </div>

                            </div>

                        </td>


                        <td>
                            Oct 24, 2023
                        </td>


                        <td>
                            09:00 - 18:00
                        </td>


                        <td>

                            <span class="time-badge">
                                08:55 IN
                            </span>

                            <span class="time-badge missing-time">
                                --:-- OUT
                            </span>

                        </td>


                        <td>

                            <span class="missing-badge">
                                OUT-PUNCH
                            </span>

                        </td>


                        <td class="text-right">

                            <a href="#"
                               class="resolve-link">
                                Resolve
                            </a>

                        </td>

                    </tr>



                    <!-- ROW 2 -->

                    <tr>

                        <td>

                            <input type="checkbox"
                                   class="custom-check missing-check">

                        </td>


                        <td>

                            <div class="employee-wrapper">

                                <div class="avatar-circle avatar-orange">
                                    AL
                                </div>

                                <div>

                                    <span class="employee-name">
                                        Amanda Lee
                                    </span>

                                    <span class="employee-code">
                                        MKT-118
                                    </span>

                                </div>

                            </div>

                        </td>


                        <td>
                            Oct 23, 2023
                        </td>


                        <td>
                            10:00 - 19:00
                        </td>


                        <td>

                            <span class="time-badge missing-time">
                                --:-- IN
                            </span>

                            <span class="time-badge">
                                19:05 OUT
                            </span>

                        </td>


                        <td>

                            <span class="missing-badge">
                                IN-PUNCH
                            </span>

                        </td>


                        <td class="text-right">

                            <a href="#"
                               class="resolve-link">
                                Resolve
                            </a>

                        </td>

                    </tr>

                </tbody>

            </table>

        </div>


        <div class="p-3 border-top">

            <span class="text-muted"
                  style="font-size:12px;font-weight:600;">

                Showing 1 to 2 of 12 entries

            </span>

            <div class="float-right">

                <button class="btn btn-sm btn-light border">
                    Prev
                </button>

                <button class="btn btn-sm"
                        style="background:#4a00e0;color:#fff;">
                    1
                </button>

                <button class="btn btn-sm btn-light border">
                    2
                </button>

                <button class="btn btn-sm btn-light border">
                    Next
                </button>

            </div>

        </div>

    </div>



    <!-- =========================================
         REGULARIZATION REQUESTS
    ========================================== -->

    <div class="exception-card">

        <div class="exception-card-header">

            <div class="section-title">

                <i class="fas fa-clipboard-clock"
                   style="color:#4a00e0;"></i>

                <h5>
                    Regularization Requests
                </h5>

                <span class="action-count pending-count">
                    5 Pending
                </span>

            </div>


            <div class="search-wrapper">

                <i class="fas fa-search"></i>

                <input type="text"
                       id="requestSearch"
                       class="request-search"
                       placeholder="Search requests...">

            </div>

        </div>



        <div class="table-responsive">

            <table class="table exception-table"
                   id="regularizationTable">

                <thead>

                    <tr>

                        <th width="45">

                            <input type="checkbox"
                                   class="custom-check"
                                   id="selectAllRegularization">

                        </th>

                        <th>
                            Employee
                        </th>

                        <th>
                            Date & Reason
                        </th>

                        <th>
                            System Log
                        </th>

                        <th>
                            Requested Update
                        </th>

                        <th class="text-right">
                            Actions
                        </th>

                    </tr>

                </thead>


                <tbody>


                    <!-- ROW 1 -->

                    <tr>

                        <td>

                            <input type="checkbox"
                                   class="custom-check regularization-check">

                        </td>


                        <td>

                            <div class="employee-wrapper">

                                <div class="avatar-circle">
                                    DC
                                </div>

                                <div>

                                    <span class="employee-name">
                                        David Chen
                                    </span>

                                    <span class="employee-code">
                                        Sales Exec • SI-992
                                    </span>

                                </div>

                            </div>

                        </td>


                        <td>

                            <strong>
                                Oct 22, 2023
                            </strong>

                            <div class="text-muted"
                                 style="font-size:10px;margin-top:3px;">

                                Client meeting ran late, forgot to pu...

                            </div>

                        </td>


                        <td>

                            <span class="system-log">

                                <s>
                                    OUT: 17:00 (Auto)
                                </s>

                            </span>

                        </td>


                        <td>

                            <span class="requested-update">
                                OUT: 19:30
                            </span>

                            <br>

                            <span class="update-type">
                                LATE OUT
                            </span>

                        </td>


                        <td>

                            <div class="action-buttons">

                                <button class="btn-reject">

                                    <i class="fas fa-times"></i>

                                </button>


                                <button class="btn-approve">

                                    <i class="fas fa-check"></i>

                                </button>

                            </div>

                        </td>

                    </tr>



                    <!-- ROW 2 -->

                    <tr>

                        <td>

                            <input type="checkbox"
                                   class="custom-check regularization-check">

                        </td>


                        <td>

                            <div class="employee-wrapper">

                                <div class="avatar-circle avatar-orange">
                                    ER
                                </div>

                                <div>

                                    <span class="employee-name">
                                        Elena Rostova
                                    </span>

                                    <span class="employee-code">
                                        Designer • DS-104
                                    </span>

                                </div>

                            </div>

                        </td>


                        <td>

                            <strong>
                                Oct 25, 2023
                            </strong>

                            <div class="text-muted"
                                 style="font-size:10px;margin-top:3px;">

                                Biometric scanner at main gate was ...

                            </div>

                        </td>


                        <td>

                            <span class="system-log">

                                <s>
                                    IN: 09:45 (Late)
                                </s>

                            </span>

                        </td>


                        <td>

                            <span class="requested-update">
                                IN: 08:50
                            </span>

                            <br>

                            <span class="update-type">
                                MANUAL ENTRY
                            </span>

                        </td>


                        <td>

                            <div class="action-buttons">

                                <button class="btn-reject">

                                    <i class="fas fa-times"></i>

                                </button>


                                <button class="btn-approve">

                                    <i class="fas fa-check"></i>

                                </button>

                            </div>

                        </td>

                    </tr>

                </tbody>

            </table>

        </div>

    </div>


</div>



<!-- =========================
     SCRIPTS
========================= -->

<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/fullcalendar@5.11.3/main.min.js"></script>

<script>

$(document).ready(function () {


    /* ==========================
       SELECT ALL MISSING
    ========================== */

    $('#selectAllMissing').on('change', function () {

        $('.missing-check')
            .prop('checked', this.checked);

    });



    /* ==========================
       SELECT ALL REGULARIZATION
    ========================== */

    $('#selectAllRegularization').on('change', function () {

        $('.regularization-check')
            .prop('checked', this.checked);

    });



    /* ==========================
       SEARCH
    ========================== */

    $('#requestSearch').on('keyup', function () {

        var value = $(this).val().toLowerCase();

        $('#regularizationTable tbody tr').filter(function () {

            $(this).toggle(
                $(this).text().toLowerCase().indexOf(value) > -1
            );

        });

    });



    /* ==========================
       CLEAR FILTER
    ========================== */

    $('.clear-filter').on('click', function () {

        $('.filter-select').val('');

    });



    /* ==========================
       CLOSE CURRENT WEEK
    ========================== */

    $('.current-week i').on('click', function () {

        $('.current-week').fadeOut(200);

    });



    /* ==========================
       RESOLVE
    ========================== */

    $('.resolve-link').on('click', function (e) {

        e.preventDefault();

        alert('Resolve action clicked.');

    });



    /* ==========================
       APPROVE
    ========================== */

    $('.btn-approve').on('click', function () {

        alert('Request approved.');

    });



    /* ==========================
       REJECT
    ========================== */

    $('.btn-reject').on('click', function () {

        alert('Request rejected.');

    });



    /* ==========================
       BULK APPROVE
    ========================== */

    $('.btn-bulk').on('click', function () {

        var selected =
            $('.missing-check:checked, .regularization-check:checked').length;

        if (selected === 0) {

            alert('Please select at least one request.');

        } else {

            alert(
                selected +
                ' selected request(s) ready for approval.'
            );

        }

    });


});

</script>


</body>

</html>