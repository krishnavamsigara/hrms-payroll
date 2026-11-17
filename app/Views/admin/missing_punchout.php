<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Bloom Solutions | Exceptions Dashboard - Missing Punches</title>
 
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap%22">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">
 
  <style>
    :root {
      --bloom-purple: #4a00e0;
      --bloom-dark: #120038;
      --bloom-bg: #f8fafc;
      --text-dark: #1e293b;
      --border-color: #e2e8f0;
    }
    body {
      font-family: 'Plus Jakarta Sans', sans-serif;
      background-color: var(--bloom-bg);
      color: var(--text-dark);
      font-size: 13px;
    }
    .card-bloom {
      border-radius: 16px;
      border: 1px solid var(--border-color);
      box-shadow: 0 10px 30px rgba(0,0,0,0.03);
      overflow: hidden;
      background: #fff;
    }
    .card-bloom .card-header {
      background: #fff;
      border-bottom: 1px solid var(--border-color);
      padding: 16px 20px;
    }
    .avatar-circle {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: #4a00e0;
      color: #fff;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
      font-size: 12px;
      margin-right: 12px;
    }
    .badge-out-punch {
      background: #fef2f2;
      color: #ef4444;
      border: 1px solid #fca5a5;
      font-weight: 800;
      padding: 4px 10px;
      border-radius: 6px;
      font-size: 11px;
      letter-spacing: 0.5px;
    }
    .badge-in-punch {
      background: #eff6ff;
      color: #3b82f6;
      border: 1px solid #93c5fd;
      font-weight: 800;
      padding: 4px 10px;
      border-radius: 6px;
      font-size: 11px;
      letter-spacing: 0.5px;
    }
    .punch-tag-in {
      background: #f1f5f9;
      color: #334155;
      border-radius: 6px;
      padding: 4px 8px;
      font-weight: 700;
      font-size: 11px;
    }
    .punch-tag-out-missing {
      background: #fff1f2;
      color: #e11d48;
      border-radius: 6px;
      padding: 4px 8px;
      font-weight: 700;
      font-size: 11px;
      border: 1px dashed #fda4af;
    }
    .table td, .table th {
      padding: 14px 16px;
      vertical-align: middle;
    }
    .table th {
      text-transform: uppercase;
      font-size: 11px;
      letter-spacing: 0.5px;
      color: #64748b;
      font-weight: 700;
    }

    /* ================================
   MONTH FILTER
================================ */

.month-filter-form {
    display: flex;
    align-items: flex-end;
    flex-wrap: wrap;
    gap: 18px;
    width: 100%;
}

.filter-group {
    display: flex;
    flex-direction: column;
    min-width: 220px;
}

.employee-filter-group {
    min-width: 280px;
}

.filter-label {
    margin-bottom: 8px;
    font-size: 12px;
    font-weight: 700;
    color: #64748b;
    text-transform: uppercase;
    letter-spacing: 0.4px;
}

.filter-control {
    height: 42px;
    padding: 0 14px;
    border: 1px solid #e2e8f0;
    border-radius: 10px;
    background: #ffffff;
    color: #1e293b;
    font-family: 'Plus Jakarta Sans', sans-serif;
    font-size: 13px;
    font-weight: 500;
    box-shadow: none;
    transition: all 0.2s ease;
}

.filter-control:focus {
    border-color: #4a00e0;
    box-shadow: 0 0 0 3px rgba(74, 0, 224, 0.10);
    outline: none;
}

.employee-control {
    max-width: 280px;
    width: 280px;
}

.filter-action-group {
    display: flex;
    align-items: center;
    gap: 10px;
    padding-bottom: 0;
}

.bloom-primary-btn {
    height: 42px;
    padding: 0 18px;
    border: none;
    border-radius: 10px;
    background: #4a00e0;
    color: #ffffff !important;
    font-family: 'Plus Jakarta Sans', sans-serif;
    font-size: 13px;
    font-weight: 700;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 7px;
    transition: all 0.2s ease;
}

.bloom-primary-btn:hover {
    background: #2a0080;
    color: #ffffff !important;
    transform: translateY(-1px);
    box-shadow: 0 6px 14px rgba(74, 0, 224, 0.20);
}

.bloom-primary-btn:focus {
    outline: none;
    box-shadow: 0 0 0 3px rgba(74, 0, 224, 0.12);
}

.bloom-reset-btn {
    height: 42px;
    padding: 0 18px;
    border: 1px solid #e2e8f0;
    border-radius: 10px;
    background: #ffffff;
    color: #64748b !important;
    font-family: 'Plus Jakarta Sans', sans-serif;
    font-size: 13px;
    font-weight: 700;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 7px;
    transition: all 0.2s ease;
}

.bloom-reset-btn:hover {
    background: #f8fafc;
    border-color: #cbd5e1;
    color: #1e293b !important;
    text-decoration: none;
}


/* ================================
   RESPONSIVE
================================ */

@media (max-width: 991px) {

    .month-filter-form {
        align-items: stretch;
    }

    .filter-group,
    .employee-filter-group {
        min-width: 100%;
        width: 100%;
    }

    .employee-control {
        max-width: 100%;
        width: 100%;
    }

    .filter-action-group {
        width: 100%;
    }
}


@media (max-width: 575px) {

    .filter-action-group {
        flex-direction: column;
        width: 100%;
    }

    .bloom-primary-btn,
    .bloom-reset-btn {
        width: 100%;
    }

}

/* ================================
   EXACT DATE FILTER
================================ */

.date-filter-form {
    display: flex;
    align-items: flex-end;
    flex-wrap: wrap;
    gap: 18px;
    width: 100%;
}

.date-filter-group {
    min-width: 220px;
}

.date-filter-group .filter-control {
    min-width: 220px;
}


/* ================================
   RESPONSIVE
================================ */

@media (max-width: 991px) {

    .date-filter-form {
        align-items: stretch;
    }

    .date-filter-group,
    .employee-filter-group {
        min-width: 100%;
        width: 100%;
    }

    .date-filter-group .filter-control {
        width: 100%;
    }
}

/* ================================
   BLOOM FILTER TABS
================================ */

.bloom-filter-tabs {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    margin: 0 0 18px 0;
    padding: 5px;
    list-style: none;
    background: #f1f5f9;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    font-family: 'Plus Jakarta Sans', sans-serif;
}


/* Tab item */

.bloom-filter-tabs .nav-item {
    margin: 0;
}


/* Tab */

.bloom-filter-tabs .nav-link {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 9px 16px;
    border-radius: 8px;
    border: none;
    background: transparent;
    color: #64748b;
    font-size: 12px;
    font-weight: 700;
    line-height: 1.2;
    text-decoration: none;
    white-space: nowrap;
    transition: all 0.2s ease;
}


/* Tab icon */

.bloom-filter-tabs .nav-link i {
    font-size: 12px;
}


/* Hover */

.bloom-filter-tabs .nav-link:hover {
    background: #ffffff;
    color: #4a00e0;
}


/* Active tab */

.bloom-filter-tabs .nav-link.active {
    background: #4a00e0;
    color: #ffffff;
    box-shadow: 0 4px 10px rgba(74, 0, 224, 0.18);
}


/* Active hover */

.bloom-filter-tabs .nav-link.active:hover {
    background: #2a0080;
    color: #ffffff;
}


/* ================================
   RESPONSIVE
================================ */

@media (max-width: 575px) {

    .bloom-filter-tabs {
        display: flex;
        width: 100%;
    }

    .bloom-filter-tabs .nav-item {
        flex: 1;
    }

    .bloom-filter-tabs .nav-link {
        width: 100%;
        padding: 9px 10px;
        font-size: 11px;
    }

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
    border-radius: 10px !important;   /* Less rounded */
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
    padding: 6px 10px;
    margin-left: 5px;
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

/* =========================================
   EXCEPTIONS DASHBOARD HEADING
========================================= */

.exceptions-heading {
    width: 100%;
    margin-bottom: 22px;
}


/* Title + Badge */

.exceptions-title-row {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 12px;
}


/* Dashboard Title */

.exceptions-title {
    margin: 0;
    color: #120038;
    font-family: 'Plus Jakarta Sans', sans-serif;
    font-size: 22px;
    font-weight: 800;
    line-height: 1.3;
    letter-spacing: -0.3px;
}


/* Action Required Badge */

.action-required-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    padding: 7px 13px;
    border-radius: 999px;
    background: #fff1f2;
    border: 1px solid #fecdd3;
    color: #e11d48;
    font-family: 'Plus Jakarta Sans', sans-serif;
    font-size: 11px;
    font-weight: 800;
    line-height: 1;
    white-space: nowrap;
}


/* Badge Icon */

.action-required-badge i {
    font-size: 11px;
}


/* Subtitle */

.exceptions-subtitle {
    margin: 6px 0 0 0;
    color: #64748b;
    font-family: 'Plus Jakarta Sans', sans-serif;
    font-size: 12px;
    font-weight: 500;
    line-height: 1.6;
}


/* =========================================
   RESPONSIVE
========================================= */

@media (max-width: 575px) {

    .exceptions-title {
        font-size: 19px;
    }

    .exceptions-title-row {
        gap: 9px;
    }

    .action-required-badge {
        padding: 6px 11px;
        font-size: 10px;
    }

    .exceptions-subtitle {
        font-size: 11px;
    }

}
/* Bloom Purple - Set Out Time */

.set-out-label {
    display: block;
    color: #4a00e0;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: .4px;
    margin-bottom: 5px;
}

.set-out-time {
    width: 125px;
    height: 36px;
    border: 1px solid #d9ccff;
    border-radius: 8px;
    background: #faf8ff;
    color: #4a00e0;
    font-weight: 700;
}

.set-out-time:focus {
    border-color: #4a00e0;
    box-shadow: 0 0 0 0.15rem rgba(74, 0, 224, 0.12);
    background: #fff;
    color: #4a00e0;
}

.btn-save-resolve {
    background: #4a00e0;
    border: 1px solid #4a00e0;
    color: #fff;
    border-radius: 8px;
    font-size: 12px;
    font-weight: 700;
    padding: 8px 14px;
    box-shadow: 0 3px 8px rgba(74, 0, 224, 0.18);
}

.btn-save-resolve:hover {
    background: #2a0080;
    border-color: #2a0080;
    color: #fff;
}

.badge-soft-warning {
            background: #fef3c7;
            color: #b45309;
            font-size: 10px;
            font-weight: 700;
            letter-spacing: 0.5px;
            padding: 4px 8px;
            border-radius: 6px;
        }

        .badge-soft-info {
            background: #e0f2fe;
            color: #0369a1;
            font-size: 10px;
            font-weight: 700;
            letter-spacing: 0.5px;
            padding: 4px 8px;
            border-radius: 6px;
        }

        .action-btn-circle {
            width: 28px;
            height: 28px;
            border-radius: 6px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            border: 1px solid #cbd5e1;
            background: #fff;
            transition: all 0.2s ease;
        }

        .action-btn-circle:hover {
            background: #f8fafc;
        }

        .action-btn-approve {
            background: #10b981;
            color: #fff;
            border-color: #10b981;
        }

        .action-btn-approve:hover {
            background: #059669;
            color: #fff;
        }

        .action-btn-reject {
            color: #dc2626;
            border-color: #fecdd3;
        }

        .action-btn-reject:hover {
            background: #fee2e2;
            color: #dc2626;
        }
        .badge-soft-danger {
    background: #fff1f2;
    color: #e11d48;
    border: 1px solid #fecdd3;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.5px;
    padding: 5px 8px;
    border-radius: 6px;
}

/* Reduce gap between Show Entries, Search and Table */
#missingPunchTable_wrapper .dataTables_wrapper {
    margin: 0 !important;
    padding: 0 !important;
}

#missingPunchTable_wrapper .dataTables_length,
#missingPunchTable_wrapper .dataTables_filter {
    margin: 0 !important;
    padding: 0 !important;
}

#missingPunchTable_wrapper > .row:first-child {
    margin: 0 !important;
    padding: 8px 15px 4px !important;
    align-items: center;
}

#missingPunchTable_wrapper .dataTables_scroll,
#missingPunchTable_wrapper table.dataTable {
    margin-top: 0 !important;
}

#missingPunchTable_wrapper .dataTables_filter input {
    margin-left: 5px !important;
}

#missingPunchTable_wrapper .dataTables_info,
#missingPunchTable_wrapper .dataTables_paginate {
    padding-top: 8px !important;
}

/* --- BLOOM BACK BUTTON --- */
.btn-bloom-back {
    background: #fff;
    color: var(--bloom-purple) !important;
    border: 1px solid var(--bloom-purple);
    border-radius: 10px;
    font-weight: 700;
    font-size: 12px;
    padding: 8px 18px;
    transition: all 0.3s ease;
    box-shadow: 0 2px 4px rgba(74, 0, 224, 0.08);
}

.btn-bloom-back:hover {
    background: linear-gradient(
        135deg,
        var(--bloom-purple) 0%,
        var(--bloom-dark) 100%
    );
    color: #fff !important;
    border-color: var(--bloom-purple);
    transform: translateY(-1px);
    box-shadow: 0 4px 10px rgba(74, 0, 224, 0.20);
}

.btn-bloom-back i {
    font-size: 11px;
}

/* Back button outside card */
.btn-bloom-back {
    margin-bottom: 20px !important;
    position: relative;
    z-index: 5;
}
</style>
</head>
 
<body class="hold-transition sidebar-mini layout-fixed">
<div class="wrapper">
 
<div class="content-wrapper">
<section class="content pt-3">
<div class="container-fluid">
 
  <?php if(session()->getFlashdata('status') == 'Y') : ?>
<div class="alert alert-success alert-dismissible fade show mb-3" style="border-radius:10px;">
<i class="fas fa-check-circle mr-2"></i><?= session()->getFlashdata('remarks') ?>
<button type="button" class="close" data-dismiss="alert">&times;</button>
</div>
<?php endif; ?>
 
  <div class="row">
<div class="col-12">
<div class="card card-bloom">
<div class="card-header d-flex align-items-center justify-content-between flex-wrap">
    
<div>


    <div class="exceptions-title-row">

        <h4 class="exceptions-title">
            Exceptions Dashboard
        </h4>

        <?php
        $actionCount = !empty($missing_punchouts)
            ? count($missing_punchouts)
            : 0;
        ?>

        <span class="action-required-badge">
            <i class="fas fa-exclamation-circle"></i>
            <?= $actionCount ?> Action Required
        </span>

    </div>

    <p class="exceptions-subtitle">
        Review and resolve missing punch anomalies for the selected month
    </p>

</div>
 
          <!-- FILTER TABS -->
<div class="w-100 mt-3">

    <ul class="nav bloom-filter-tabs"
        id="filter-tab"
        role="tablist">

        <!-- By Exact Date -->
        <li class="nav-item">
            <a class="nav-link <?= !empty($selectedDate) ? 'active' : '' ?>"
               id="date-tab"
               data-toggle="pill"
               href="#date-filter"
               role="tab">

                <i class="fas fa-calendar-day mr-1"></i>
                By Exact Date

            </a>
        </li>


        <!-- By Payroll Month -->
        <li class="nav-item">
            <a class="nav-link <?= empty($selectedDate) ? 'active' : '' ?>"
               id="month-tab"
               data-toggle="pill"
               href="#month-filter"
               role="tab">

                <i class="fas fa-calendar-alt mr-1"></i>
                By Payroll Month

            </a>
        </li>

    </ul>


 
            <div class="tab-content bg-light p-3 rounded border" id="filter-tabContent">
<!-- Exact Date Filter -->
<div class="tab-pane fade <?= !empty($selectedDate) ? 'show active' : '' ?>"
     id="date-filter"
     role="tabpanel">

    <form method="get"
          action="<?= base_url('admin/missing_punchout') ?>"
          class="date-filter-form">

        <!-- Date -->
        <div class="filter-group date-filter-group">

            <label class="filter-label">
                Date
            </label>

            <input type="date"
                   name="exact_date"
                   class="form-control filter-control"
                   value="<?= isset($selectedDate) ? esc($selectedDate) : '' ?>"
                   required>

        </div>


        <!-- Employee -->
        <div class="filter-group employee-filter-group">

            <label class="filter-label">
                Employee
            </label>

            <select name="emp_id"
                    class="form-control filter-control employee-control">

                <option value="">-- All Employees --</option>

                <?php if (!empty($employees)) : ?>

                    <?php foreach ($employees as $emp) : ?>

                        <?php
                        $selEmp = (
                            isset($selectedEmp) &&
                            $selectedEmp == $emp['emp_id']
                        ) ? 'selected' : '';
                        ?>

                        <option value="<?= esc($emp['emp_id']) ?>"
                                <?= $selEmp ?>>
                            <?= esc($emp['emp_id']) ?> -
                            <?= esc($emp['emp_name']) ?>
                        </option>

                    <?php endforeach; ?>

                <?php endif; ?>

            </select>

        </div>


        <!-- Buttons -->
        <div class="filter-action-group">

            <!-- Apply Date Filter -->
            <button type="submit"
                    class="btn bloom-primary-btn">
                <span>Submit</span>

            </button>


            <!-- Reset -->
            <a href="<?= base_url('admin/missing_punchout') ?>"
               class="btn bloom-reset-btn">

                <i class="fas fa-undo"></i>
                <span>Reset</span>

            </a>

        </div>

    </form>

</div>
<!-- Month Filter -->
<div class="tab-pane fade <?= empty($selectedDate) ? 'show active' : '' ?>"
     id="month-filter"
     role="tabpanel">

    <form method="get"
          action="<?= base_url('admin/missing_punchout') ?>"
          class="month-filter-form">

        <!-- Month -->
        <div class="filter-group">
            <label class="filter-label">
                Month
            </label>

            <select name="month"
                    class="form-control filter-control">

                <?php
                $months = [
                    1  => 'January (Dec 25 - Jan 24)',
                    2  => 'February (Jan 25 - Feb 24)',
                    3  => 'March (Feb 25 - Mar 24)',
                    4  => 'April (Mar 25 - Apr 24)',
                    5  => 'May (Apr 25 - May 24)',
                    6  => 'June (May 25 - Jun 24)',
                    7  => 'July (Jun 25 - Jul 24)',
                    8  => 'August (Jul 25 - Aug 24)',
                    9  => 'September (Aug 25 - Sep 24)',
                    10 => 'October (Sep 25 - Oct 24)',
                    11 => 'November (Oct 25 - Nov 24)',
                    12 => 'December (Nov 25 - Dec 24)'
                ];

                $curMonth = $selectedMonth ?? date('n');

                foreach ($months as $num => $name) {
                    $sel = ($curMonth == $num) ? 'selected' : '';
                    echo "<option value=\"$num\" $sel>$name</option>";
                }
                ?>

            </select>
        </div>


        <!-- Year -->
        <div class="filter-group">
            <label class="filter-label">
                Year
            </label>

            <select name="year"
                    class="form-control filter-control">

                <?php
                $curYr = $selectedYear ?? date('Y');

                for ($y = date('Y') - 1; $y <= date('Y') + 1; $y++) {
                    $sel = ($curYr == $y) ? 'selected' : '';
                    echo "<option value=\"$y\" $sel>$y</option>";
                }
                ?>

            </select>
        </div>


        <!-- Employee -->
        <div class="filter-group employee-filter-group">
            <label class="filter-label">
                Employee
            </label>

            <select name="emp_id"
                    class="form-control filter-control employee-control">

                <option value="">-- All Employees --</option>

                <?php if (!empty($employees)) : ?>

                    <?php foreach ($employees as $emp) : ?>

                        <?php
                        $selEmp = (
                            isset($selectedEmp) &&
                            $selectedEmp == $emp['emp_id']
                        ) ? 'selected' : '';
                        ?>

                        <option value="<?= esc($emp['emp_id']) ?>"
                                <?= $selEmp ?>>
                            <?= esc($emp['emp_id']) ?> -
                            <?= esc($emp['emp_name']) ?>
                        </option>

                    <?php endforeach; ?>

                <?php endif; ?>

            </select>
        </div>


        <!-- Apply Button -->
        <div class="filter-action-group">

            <button type="submit"
                    class="btn bloom-primary-btn">
                <span>Submit</span>

            </button>


            <!-- Reset -->
            <a href="<?= base_url('admin/missing_punchout') ?>"
               class="btn bloom-reset-btn">

                <i class="fas fa-undo"></i>
                <span>Reset</span>

            </a>

        </div>

    </form>

</div>
</div>
</div>
</div>
 
        <div class="card-body p-0">
             <div class="card-header bg-white border-bottom py-3 d-flex align-items-center justify-content-between">
    <div class="d-flex align-items-center">
        <i class="fas fa-fingerprint text-danger mr-2" style="font-size: 16px;"></i>
        <h6 class="font-weight-bold mb-0 text-dark mr-2">Missing Punches</h6>
        <span class="badge badge-soft-danger">
            <?= $actionCount ?> Action Required
        </span>
        <div>
        <button class="btn btn-xs btn-light text-muted mr-1"><i class="fas fa-sliders-h"></i></button>
        <button class="btn btn-xs btn-light text-muted"><i class="fas fa-expand-alt"></i></button>
    </div>
    </div>
</div>
<div class="table-responsive">
<table id="missingPunchTable" class="table table-hover mb-0">
<thead class="bg-light">
<tr>
<th>EMPLOYEE</th>
<th>DATE</th>
<th>RECORDED PUNCHES</th>
<th>MISSING</th>
<th>SET OUT TIME</th>
<th class="text-center">ACTION</th>
</tr>
</thead>
<tbody>
<?php if (!empty($missing_punchouts)) : ?>
<?php foreach ($missing_punchouts as $index => $row) : ?>
<tr>
<td>
<div class="d-flex align-items-center">
<div class="avatar-circle">
<?= strtoupper(substr($row['emp_name'] ?? $row['emp_id'], 0, 2)) ?>
</div>
<div>
<div class="font-weight-bold text-dark mb-0"><?= esc($row['emp_name'] ?? 'Employee') ?></div>
<small class="text-muted"><?= esc($row['emp_id']) ?></small>
</div>
</div>
</td>
 
                      <td class="font-weight-bold text-secondary">
<?= date('M d, Y', strtotime($row['attendance_date'])) ?>
<br><small class="text-muted"><?= esc($row['day_name'] ?? date('l', strtotime($row['attendance_date']))) ?></small>
</td>
 
                      <td>
<span class="punch-tag-in mr-2">
<?= !empty($row['punch_in']) ? date('H:i', strtotime($row['punch_in'])) : '09:30' ?> IN
</span>
<span class="punch-tag-out-missing">
                          --:-- OUT
</span>
</td>
 
                      <td>
<span class="badge-out-punch">
<i class="fas fa-arrow-circle-right mr-1"></i>OUT-PUNCH
</span>
</td>
 
                      <!-- INLINE FORM FOR DIRECT ROW SAVING -->
<td>
    <!-- <label class="set-out-label">
        <i class="fas fa-clock mr-1"></i> Set Out Time
    </label> -->

    <input type="time"
           name="last_out_time"
           form="form_punch_<?= $index ?>"
           class="form-control form-control-sm set-out-time"
           value="18:30"
           required>
</td>
 
                      <td class="text-center">
<form id="form_punch_<?= $index ?>" action="<?= base_url('admin/save_missing_punchout') ?>" method="post" class="form-inline m-0 justify-content-center">
<input type="hidden" name="target_emp_id" value="<?= esc($row['emp_id']) ?>">
<input type="hidden" name="attendance_date" value="<?= esc($row['attendance_date']) ?>">
<input type="hidden" name="first_in_time" value="<?= !empty($row['punch_in']) ? date('H:i', strtotime($row['punch_in'])) : '09:30' ?>">
 
                          <button type="submit" class="btn btn-save-resolve">
    <i class="fas fa-check-circle mr-1"></i>Update Punch Out
</button>
</form>
</td>
</tr>
<?php endforeach; ?>
<?php else : ?>
<tr>
    <td></td>
    <td></td>
    <td></td>
    <td class="text-center">
        No Missing Punch Outs found for the selected filter.
    </td>
    <td></td>
    <td></td>
</tr>
<?php endif; ?>
</tbody>
</table>
</div>
</div>
</div>
</div>
</div>

<!-- Regularization Requests Section -->
                    <!-- <div class="card card-bloom mb-3">
                        <div class="card-header bg-white border-bottom py-3 d-flex flex-column flex-md-row align-items-md-center justify-content-between">
                            <div class="d-flex align-items-center mb-2 mb-md-0">
                                <i class="fas fa-clipboard-check text-primary mr-2" style="font-size: 16px;"></i>
                                <h6 class="font-weight-bold mb-0 text-dark mr-2">Regularization Requests</h6>
                                <span class="badge badge-soft-info">5 Pending</span>
                            </div>
                            <div class="input-group input-group-sm" style="max-width: 240px;">
                                <div class="input-group-prepend">
                                    <span class="input-group-text bg-light border-right-0"><i class="fas fa-search text-muted"></i></span>
                                </div>
                                <input type="text" class="form-control border-left-0 pl-0" placeholder="Search requests...">
                            </div>
                        </div>
                        <div class="card-body p-0 table-responsive">
                            <table class="table table-custom mb-0">
                                <thead>
                                    <tr>
                                        <th style="width: 40px;" class="text-center">
                                            <div class="custom-control custom-checkbox">
                                                <input type="checkbox" class="custom-control-input" id="checkAllReg">
                                                <label class="custom-control-label" for="checkAllReg"></label>
                                            </div>
                                        </th>
                                        <th>Employee</th>
                                        <th>Date & Reason</th>
                                        <th>System Log</th>
                                        <th>Requested Update</th>
                                        <th class="text-center">Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr>
                                        <td class="text-center">
                                            <div class="custom-control custom-checkbox">
                                                <input type="checkbox" class="custom-control-input" id="checkReg1">
                                                <label class="custom-control-label" for="checkReg1"></label>
                                            </div>
                                        </td>
                                        <td>
                                            <strong class="d-block text-dark">David Chen</strong>
                                            <small class="text-muted">Sales Exec • SL-992</small>
                                        </td>
                                        <td>
                                            <span class="d-block font-weight-bold text-dark">Oct 22, 2023</span>
                                            <small class="text-muted">Client meeting ran late, forgot to pu...</small>
                                        </td>
                                        <td><span class="text-muted"><s>OUT: 17:00 (Auto)</s></span></td>
                                        <td>
                                            <strong class="text-primary d-block">OUT: 19:30</strong>
                                            <span class="badge badge-soft-warning">LATE OUT</span>
                                        </td>
                                        <td class="text-center">
                                            <button class="action-btn-circle action-btn-reject mr-1" title="Reject"><i class="fas fa-times"></i></button>
                                            <button class="action-btn-circle action-btn-approve" title="Approve"><i class="fas fa-check"></i></button>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td class="text-center">
                                            <div class="custom-control custom-checkbox">
                                                <input type="checkbox" class="custom-control-input" id="checkReg2">
                                                <label class="custom-control-label" for="checkReg2"></label>
                                            </div>
                                        </td>
                                        <td>
                                            <strong class="d-block text-dark">Elena Rostova</strong>
                                            <small class="text-muted">Designer • DS-104</small>
                                        </td>
                                        <td>
                                            <span class="d-block font-weight-bold text-dark">Oct 25, 2023</span>
                                            <small class="text-muted">Biometric scanner at main gate was ...</small>
                                        </td>
                                        <td><span class="text-muted"><s>IN: 09:45 (Late)</s></span></td>
                                        <td>
                                            <strong class="text-primary d-block">IN: 08:50</strong>
                                            <span class="badge badge-soft-secondary">MANUAL ENTRY</span>
                                        </td>
                                        <td class="text-center">
                                            <button class="action-btn-circle action-btn-reject mr-1" title="Reject"><i class="fas fa-times"></i></button>
                                            <button class="action-btn-circle action-btn-approve" title="Approve"><i class="fas fa-check"></i></button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div> -->

                     <div class="d-flex justify-content-start mb-3">
                                <button type="button"
                                    class="btn btn-bloom-back"
                                    onclick="window.history.back();">
                                    <i class="fas fa-arrow-left mr-1"></i> Back
                                </button>
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
  $(document).ready(function() {
    $('#missingPunchTable').DataTable({
      paging: true,
      ordering: true,
      searching: true,
      info: true,
      pageLength: 10,
      dom: '<"row"<"col-md-6"l><"col-md-6"f>>rt<"row"<"col-md-6"i><"col-md-6"p>>'
    });
  });
</script>
</body>
</html>