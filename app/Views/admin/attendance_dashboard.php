<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Bloom Solutions | Attendance</title>

    <!-- Google Font: Plus Jakarta Sans -->
    <link rel="stylesheet"
        href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
    <!-- Font Awesome -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <!-- AdminLTE 3 -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">

    <style>
        :root {
            --bloom-purple: #4a00e0;
            --bloom-dark: #2a0080;
            --mtn-deep: #120038;
            --bloom-orange: #e46c44;
            --bloom-success: #10b981;
            --bloom-danger: #dc2626;
            --glass: rgba(255, 255, 255, 0.95);
        }

        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: #f8fafc;
            font-size: 13px;
            color: #334155;
        }

        /* --- LAYOUT & SPACING FIXES --- */
     

.content-wrapper {
    min-height: calc(100vh - 110px) !important;
    height: auto !important;
    overflow-y: visible !important;
    overflow-x: hidden;
    padding-bottom: 20px !important;
    background-color: #f8fafc;
}


        .content {
            padding-bottom: 5px !important;
        }

        .row:last-of-type,
        .row:last-of-type .col-lg-12,
        .row:last-of-type .card {
            margin-bottom: 0px !important;
         }

.main-footer {
    position: relative !important;
    bottom: auto !important;
    margin-top: 0 !important;
    padding: 8px 1.5rem !important;
    background: #fff !important;
    border-top: 1px solid #e2e8f0 !important;
    color: #64748b;
    font-size: 12px;
    width: 100%;
    clear: both;
}


        /* --- NAVIGATION & SIDEBAR --- */
        .main-header {
            border-bottom: 1px solid #e2e8f0 !important;
            background: var(--glass) !important;
            backdrop-filter: blur(10px);
        }

        .custom-brand {
            display: flex;
            align-items: center;
            padding: 12px 16px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
        }

        .logo-circle {
            width: 42px;
            height: 42px;
            border-radius: 50%;
            object-fit: cover;
            border: 2px solid #fff;
            margin-right: 10px;
        }

        .brand-text {
            font-size: 18px;
            font-weight: 700;
        }

        .brand-blue {
            color: #4a8cff;
        }

        .brand-orange {
            color: #ff7a45;
        }

        /* --- BLOOM CARD STYLING --- */
        .card-bloom {
            transition: transform 0.2s ease;
            border: 1px solid #e2e8f0 !important;
            border-radius: 16px !important;
            background: #fff;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.03) !important;
            margin-bottom: 1rem;
        }

        .card-bloom:hover {
            transform: translateY(-2px);
        }

        /* --- DASHBOARD ACTION CARDS --- */
        .action-card {
            position: relative;
            padding: 1.25rem;
            border-radius: 16px;
            background: #fff;
            border: 1px solid #e2e8f0;
        }

        .action-card .badge-status {
            position: absolute;
            top: 16px;
            right: 16px;
            font-size: 10px;
            font-weight: 700;
            padding: 4px 8px;
            border-radius: 6px;
            text-transform: uppercase;
        }

        .icon-square {
        width: 34px;
        height: 34px;
        min-width: 34px;
        border-radius: 9px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 14px;
        margin-bottom: 10px;
    }

        /* --- QUICK LINK BUTTON CARDS --- */
        .quick-link-card {
    display: flex;
    align-items: center;
    padding: 0.55rem 0.75rem;
    border-radius: 10px;
    background: #fff;
    border: 1px solid #e2e8f0;
    text-decoration: none !important;
    color: #334155;
    transition: all 0.2s ease;
    font-weight: 600;
    font-size: 12px;
    min-height: 48px;
}

        .quick-link-card:hover {
            background: #f8fafc;
            border-color: #cbd5e1;
            color: var(--bloom-purple);
        }

        /* --- TABLES & BADGES --- */
        .table-custom th {
            border-top: none;
            border-bottom: 1px solid #f1f5f9;
            color: #64748b;
            font-weight: 600;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .table-custom td {
            vertical-align: middle;
            border-top: 1px solid #f1f5f9;
            font-size: 12.5px;
        }

        .avatar-circle {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            background: #e0e7ff;
            color: #4338ca;
            font-weight: 700;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 11px;
        }

        .badge-soft-success {
            background: #dcfce7;
            color: #15803d;
        }

        .badge-soft-warning {
            background: #fef3c7;
            color: #b45309;
        }

        .badge-soft-danger {
            background: #fee2e2;
            color: #b91c1c;
        }

        .badge-soft-secondary {
            background: #f1f5f9;
            color: #475569;
        }

        /* Equal-height dashboard layout */
@media (min-width: 992px) {
    .dashboard-main-row {
        align-items: stretch;
    }

    .dashboard-summary-card {
        width: 100%;
        min-height: 150px;
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
                    <!-- Dashboard Top Header Row -->
                    <form action="" method="GET" class="mb-4">
                        <div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between">

                            <!-- Title & Subtitle -->
                            <div class="mb-3 mb-md-0">
                                <h4 class="font-weight-bold mb-0" style="color: var(--mtn-deep, #1e293b);">Attendance Dashboard</h4>
                                <small class="text-muted">Overview of today's attendance and pending actions.</small>
                            </div>

                            <!-- Interactive Controls Group -->
                            <div class="d-flex align-items-center flex-wrap" style="gap: 10px;">
                                <!-- Functional Date Picker -->
                                <div class="input-group input-group-sm shadow-sm" style="width: 170px;">
                                    <div class="input-group-prepend">
                                        <span class="input-group-text bg-white border-right-0 text-muted"
                                            style="border-top-left-radius: 8px; border-bottom-left-radius: 8px;">
                                            <i class="far fa-calendar-alt"></i>
                                        </span>
                                    </div>
                                    <input type="date" name="filter_date"
                                        class="form-control border-left-0 font-weight-bold text-secondary pl-0"
                                        value="<?= $filterDate ?? date('Y-m-d') ?>"
                                        style="border-top-right-radius: 8px; border-bottom-right-radius: 8px;">
                                </div>

                                <!-- Submit Button -->
                                <button type="submit"
                                    class="btn btn-sm"
                                    style="
                                        height: 31px;
                                        background: var(--bloom-purple);
                                        color: #fff;
                                        border-radius: 8px;
                                        font-weight: 700;
                                        padding: 0 15px;
                                    ">
                                    Submit
                                </button>
                            </div>
                        </div>
                    </form>
                </div>

                <!-- MAIN DASHBOARD ROW -->
                <div class="row align-items-stretch dashboard-main-row">

                    <!-- LEFT SIDE: ACTION CARDS + ORGANIZATION SUMMARY -->
                    <div class="col-lg-8 d-flex flex-column mb-3">

                        <!-- TOP 3 ACTION CARDS -->
                        <div class="row">
                            <!-- Missing Out-Punches -->
                            <div class="col-lg-4 col-md-6 mb-3">
                                <div class="action-card shadow-sm h-100">
                                    <span class="badge-status bg-danger text-white">High Priority</span>
                                    <div class="icon-square text-danger" style="background: #fee2e2;">
                                        <i class="fas fa-user-slash"></i>
                                    </div>
                                    <small class="text-muted font-weight-bold d-block mb-1">Missing Out-Punches</small>
                                    <div class="d-flex align-items-baseline">
                                        <h2 class="font-weight-bold mb-0 mr-2" style="color: var(--bloom-danger);">12</h2>
                                        <small class="text-muted">requires review</small>
                                    </div>
                                </div>
                            </div>

                            <!-- Unapproved Absences -->
                            <div class="col-lg-4 col-md-6 mb-3">
                                <div class="action-card shadow-sm h-100">
                                    <span class="badge-status text-white" style="background: #d97706;">Pending</span>
                                    <div class="icon-square text-warning" style="background: #fef3c7;">
                                        <i class="fas fa-user-clock"></i>
                                    </div>
                                    <small class="text-muted font-weight-bold d-block mb-1">Unapproved Absences</small>
                                    <div class="d-flex align-items-baseline">
                                        <h2 class="font-weight-bold mb-0 mr-2" style="color: #d97706;">8</h2>
                                        <small class="text-muted">from yesterday</small>
                                    </div>
                                </div>
                            </div>

                            <!-- Leave Requests -->
                            <div class="col-lg-4 col-md-12 mb-3">
                                <div class="action-card shadow-sm h-100">
                                    <div class="icon-square text-primary" style="background: #e0e7ff;">
                                        <i class="fas fa-calendar-plus"></i>
                                    </div>
                                    <small class="text-muted font-weight-bold d-block mb-1">Leave Requests</small>
                                    <div class="d-flex align-items-baseline">
                                        <h2 class="font-weight-bold mb-0 mr-2" style="color: var(--bloom-purple);">5</h2>
                                        <small class="text-muted">awaiting approval</small>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- ORGANIZATION SUMMARY -->
                        <div class="row mb-0 dashboard-summary-row flex-grow-1">
                            <div class="col-12 d-flex">
                                <div class="card card-bloom mb-0 dashboard-summary-card flex-grow-1">
                                    <div class="card-body py-3 px-3 d-flex flex-column justify-content-center">
                                        <h6 class="font-weight-bold mb-2 text-dark" style="font-size: 16px;">
                                            Organization Summary
                                        </h6>
                                        <div class="row text-center py-1">
                                            <!-- Total Employees -->
                                            <div class="col-6 col-md border-right mb-3 mb-md-0">
                                                <small class="text-muted d-block font-weight-bold text-center">Total Employees</small>
                                                <h3 class="font-weight-bold my-2 text-center" style="font-size: 23px;">
                                                    <?= $attendance[0]['total_employees_count'] ?? 123 ?>
                                                </h3>
                                            </div>
                                            <!-- Present -->
                                            <div class="col-6 col-md border-right mb-3 mb-md-0">
                                                <small class="text-muted d-block font-weight-bold text-center">Present</small>
                                                <h3 class="font-weight-bold text-primary my-2 text-center" style="font-size: 28px;">
                                                    <?= $attendance[0]['today_present_count'] ?? 0 ?>
                                                </h3>
                                            </div>
                                            <!-- On Leave -->
                                            <div class="col-6 col-md border-right mb-3 mb-md-0">
                                                <small class="text-muted d-block font-weight-bold text-center">On Leave</small>
                                                <h3 class="font-weight-bold text-info my-2 text-center" style="font-size: 28px;">
                                                    <?= $attendance[0]['today_leave_count'] ?? 0 ?>
                                                </h3>
                                            </div>
                                            <!-- Absent -->
                                            <div class="col-6 col-md border-right mb-3 mb-md-0">
                                                <small class="text-muted d-block font-weight-bold text-center">Absent</small>
                                                <h3 class="font-weight-bold text-danger my-2 text-center" style="font-size: 28px;">
                                                    <?= $attendance[0]['today_absent_count'] ?? 0 ?>
                                                </h3>
                                            </div>
                                            <!-- WFH -->
                                            <div class="col-6 col-md mb-3 mb-md-0">
                                                <small class="text-muted d-block font-weight-bold text-center">WFH</small>
                                                <h3 class="font-weight-bold text-dark my-2 text-center" style="font-size: 28px;">
                                                    <?= $attendance[0]['today_wfh_count'] ?? 0 ?>
                                                </h3>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                    </div>

                    <!-- RIGHT SIDE: QUICK LINKS -->
                    <div class="col-lg-4 mb-3 d-flex flex-column">
                        <div class="card card-bloom mb-0 flex-grow-1">
                            <div class="card-header border-bottom d-flex align-items-center justify-content-between py-2 px-3">
                                <h6 class="font-weight-bold text-dark mb-0">
                                    <i class="fas fa-bolt text-warning mr-2"></i>
                                    Quick Links
                                </h6>
                            </div>
                            <div class="card-body p-3">
                                <div class="row">
                                    <!-- Timesheet Lookup -->
                                    <div class="col-12 mb-2">
                                        <a href="<?= base_url('admin/master_time_sheet?filter_date=' . ($filterDate ?? date('Y-m-d'))) ?>"
                                            class="quick-link-card shadow-sm">
                                            <div class="icon-square mb-0 mr-3 text-primary" style="background: #e0e7ff;">
                                                <i class="fas fa-search"></i>
                                            </div>
                                            <span>Timesheet Lookup</span>
                                        </a>
                                    </div>
                                    <!-- Exceptions -->
                                    <div class="col-12 mb-2">
                                        <a href="<?= base_url('admin/missing_punchout') ?>" class="quick-link-card shadow-sm">
                                            <div class="icon-square mb-0 mr-3 text-danger" style="background: #fee2e2;">
                                                <i class="fas fa-exclamation-triangle"></i>
                                            </div>
                                            <span>Exceptions</span>
                                        </a>
                                    </div>
                                    <!-- Edit Timesheet -->
                                    <div class="col-12 mb-2">
                                        <a href="<?= base_url('admin/attendance_overview') ?>" class="quick-link-card shadow-sm">
                                            <div class="icon-square mb-0 mr-3 text-info" style="background: #e0f2fe;">
                                                <i class="fas fa-sliders-h"></i>
                                            </div>
                                            <span>Edit TimeSheet</span>
                                        </a>
                                    </div>
                                    <!-- Finalize Attendance / Download Reports -->
                                    <div class="col-12 mb-2">
                                        <a href="<?= base_url('admin/attendance_cycle') ?>" class="quick-link-card shadow-sm">
                                            <div class="icon-square mb-0 mr-3 text-secondary" style="background: #f1f5f9;">
                                                <i class="fas fa-clipboard-check"></i>
                                            </div>
                                            <span>Finalize Attendance</span>
                                        </a>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                </div>
                <!-- END MAIN DASHBOARD ROW -->

                <!-- BOTTOM SECTION: TABLE & GRAPH SPLIT -->
                <div class="row">
                    
                    <!-- LEFT COLUMN: Today Attendance Table -->
                    <div class="col-lg-7 mb-3">
                        <div class="card card-bloom mb-0 h-100">
                            <div class="card-header bg-white border-bottom d-flex align-items-center py-3 px-3">
                                <h6 class="font-weight-bold mb-0 text-dark d-flex align-items-center">
                                    <i class="fas fa-users text-muted mr-2"></i>
                                    Today Attendance
                                </h6>
                                <div class="ml-auto d-flex align-items-center">
                                    <a href="<?= base_url('admin/attendance_adm?filter_date=' . ($filterDate ?? date('Y-m-d'))) ?>"
                                        class="btn btn-sm font-weight-bold px-3 py-1 shadow-sm"
                                        style="border-radius: 8px; font-size: 12px; background-color: #4a00e0; color: #fff; border-color: #4a00e0;">
                                        View All <i class="fas fa-arrow-right ml-1"></i>
                                    </a>
                                </div>
                            </div>
                            <div class="card-body p-0 table-responsive">
                                <table class="table table-custom mb-0">
                                    <thead>
                                        <tr>
                                            <th>Employee</th>
                                            <th>Department</th>
                                            <th>Status</th>
                                            <th>IN TIME</th>
                                            <th>PUNCH OUT</th>
                                            <th>TOTAL HOURS</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <?php
                                        $employees = $everyday ?? [];
                                        if (count($employees) > 5) {
                                            $randomKeys = array_rand($employees, 5);
                                            $randomEmployees = array_map(fn($key) => $employees[$key], $randomKeys);
                                        } else {
                                            $randomEmployees = $employees;
                                        }
                                        ?>

                                        <?php if(empty($randomEmployees)): ?>
                                            <!-- Fallback mock sample items if array is empty -->
                                            <?php 
                                            $randomEmployees = [
                                                ['employee_name' => 'Sudheer Kumar Lekkala', 'department_name' => 'Engineering', 'attendance_status' => 'ABSENT', 'punch_in' => '', 'punch_out' => '', 'total_hours' => '-'],
                                                ['employee_name' => 'Pradeep kumar Nath', 'department_name' => 'Operations', 'attendance_status' => 'ABSENT', 'punch_in' => '', 'punch_out' => '', 'total_hours' => '-'],
                                                ['employee_name' => 'Aishwarya Tanukonda', 'department_name' => 'HR', 'attendance_status' => 'ABSENT', 'punch_in' => '', 'punch_out' => '', 'total_hours' => '-'],
                                                ['employee_name' => 'Subhash Lankalapalli', 'department_name' => 'Finance', 'attendance_status' => 'ABSENT', 'punch_in' => '', 'punch_out' => '', 'total_hours' => '-'],
                                                ['employee_name' => 'Ramesh Varma', 'department_name' => 'Sales', 'attendance_status' => 'ABSENT', 'punch_in' => '', 'punch_out' => '', 'total_hours' => '-'],
                                            ];
                                            ?>
                                        <?php endif; ?>

                                        <?php foreach ($randomEmployees as $employee): ?>
                                            <?php
                                            $status = strtoupper($employee['attendance_status'] ?? 'ABSENT');
                                            $statusClass = 'badge-soft-secondary';
                                            if ($status === 'PRESENT') {
                                                $statusClass = 'badge-soft-success';
                                            } elseif ($status === 'LATE') {
                                                $statusClass = 'badge-soft-warning';
                                            } elseif ($status === 'ABSENT') {
                                                $statusClass = 'badge-soft-danger';
                                            } elseif ($status === 'LEAVE') {
                                                $statusClass = 'badge-soft-secondary';
                                            } elseif ($status === 'WFH') {
                                                $statusClass = 'badge-soft-info';
                                            }
                                            ?>
                                            <tr>
                                                <td>
                                                    <div class="d-flex align-items-center">
                                                        <div class="avatar-circle mr-2">
                                                            <?= strtoupper(substr($employee['employee_name'] ?? 'E', 0, 2)) ?>
                                                        </div>
                                                        <div>
                                                            <strong class="d-block text-dark">
                                                                <?= esc($employee['employee_name'] ?? 'Employee') ?>
                                                            </strong>
                                                        </div>
                                                    </div>
                                                </td>
                                                <td><?= esc($employee['department_name'] ?? '-') ?></td>
                                                <td>
                                                    <span class="badge <?= $statusClass ?> px-2 py-1">
                                                        <?= esc($status ?: '-') ?>
                                                    </span>
                                                </td>
                                                <td>
                                                    <?= !empty($employee['punch_in']) ? date('H:i:s', strtotime($employee['punch_in'])) : '-' ?>
                                                </td>
                                                <td>
                                                    <?= !empty($employee['punch_out']) ? date('H:i:s', strtotime($employee['punch_out'])) : '-' ?>
                                                </td>
                                                <td><?= esc($employee['total_hours'] ?? '-') ?></td>
                                            </tr>
                                        <?php endforeach; ?>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>

                    <!-- RIGHT COLUMN: Attendance Trends Graph -->
                    
                    <div class="col-lg-5 mb-3">
                        <div class="card card-bloom mb-0 h-100">
                            <div class="card-header bg-white border-bottom d-flex align-items-center justify-content-between flex-wrap py-3 px-3">
                                <h6 class="font-weight-bold mb-2 mb-md-0 text-dark">ATTENDANCE TRENDS</h6>
                                <div class="btn-group btn-group-toggle" id="trendFilters">
                                    <button type="button" class="btn btn-xs btn-outline-secondary active font-weight-bold px-2 py-1" data-period="DAY">Yesterday</button>
                                    <!-- <button type="button" class="btn btn-xs btn-outline-secondary font-weight-bold px-2 py-1" data-period="WEEK">Week</button> -->
                                    <!-- <button type="button" class="btn btn-xs btn-outline-secondary font-weight-bold px-2 py-1" data-period="MONTH">Month</button> -->
                                    <!-- <button type="button" class="btn btn-xs btn-outline-secondary font-weight-bold px-2 py-1" data-period="YEAR">Year</button> -->
                                </div>
                            </div>
                            <div class="card-body d-flex flex-column justify-content-between p-3">
                                <div id="attendanceGraphMessage" class="text-muted text-center d-none mb-2"></div>
                                <div class="position-relative" style="height:240px;width:100%;">
                                    <canvas id="attendanceTrendsChart"></canvas>
                                </div>
                                <div class="d-flex align-items-center justify-content-center flex-wrap mt-3 pt-2 border-top" style="font-size:12px;">
                                    <div class="d-flex align-items-center mr-4">
                                        <span style="width:12px;height:12px;background:#4a00e0;display:inline-block;border-radius:3px;margin-right:6px;"></span>
                                        <span id="currentPeriodLabel" class="text-secondary font-weight-bold">Current Period</span>
                                    </div>
                                    <div class="d-flex align-items-center">
                                        <span style="width:12px;height:12px;background:#cbd5e1;display:inline-block;border-radius:3px;margin-right:6px;"></span>
                                        <span id="previousPeriodLabel" class="text-secondary font-weight-bold">Previous Period</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>


            </section>
        </div>
    </div>

<!-- Scripts -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
<!-- Chart.js CDN -->
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<!-- Chart Initialization Script -->
    
<script>
document.addEventListener('DOMContentLoaded', function () {
    const canvas = document.getElementById('attendanceTrendsChart');
    const message = document.getElementById('attendanceGraphMessage');
    const filters = document.querySelectorAll('#trendFilters button');
    const currentLabel = document.getElementById('currentPeriodLabel');
    const previousLabel = document.getElementById('previousPeriodLabel');

    if (!canvas || typeof Chart === 'undefined') {
        console.error('Attendance chart canvas or Chart.js is missing.');
        return;
    }

    let selectedPeriod = 'DAY';
    const chart = new Chart(canvas.getContext('2d'), {
        type: 'bar',
        data: {
            labels: ['Present', 'Absent', 'WFH', 'Leave'],
            datasets: [
                {
                    label: 'Current Period',
                    data: [0, 0, 0, 0],
                    backgroundColor: '#4a00e0',
                    borderRadius: 6,
                    barPercentage: 0.6,
                    categoryPercentage: 0.7
                },
                {
                    label: 'Previous Period',
                    data: [0, 0, 0, 0],
                    backgroundColor: '#cbd5e1',
                    borderRadius: 6,
                    barPercentage: 0.6,
                    categoryPercentage: 0.7
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: '#1e293b',
                    padding: 10,
                    cornerRadius: 8
                }
            },
            scales: {
                x: {
                    grid: { display: false },
                    ticks: {
                        font: {
                            family: 'Plus Jakarta Sans',
                            size: 11,
                            weight: '600'
                        },
                        color: '#64748b'
                    }
                },
                y: {
                    beginAtZero: true,
                    ticks: {
                        precision: 0,
                        color: '#94a3b8'
                    },
                    grid: {
                        color: '#f1f5f9',
                        border: { dash: [4, 4] }
                    }
                }
            }
        }
    });

    function formatDate(date) {
        if (!date) return '';
        const parts = date.split('-');
        if (parts.length !== 3) return date;

        const parsed = new Date(
            Number(parts[0]),
            Number(parts[1]) - 1,
            Number(parts[2])
        );

        return parsed.toLocaleDateString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        });
    }

    function formatRange(start, end) {
        if (!start || !end) return 'Date range unavailable';
        return formatDate(start) + ' - ' + formatDate(end);
    }

    function showMessage(text) {
        if (!message) return;
        message.textContent = text;
        message.classList.remove('d-none');
    }

    function hideMessage() {
        if (!message) return;
        message.textContent = '';
        message.classList.add('d-none');
    }

    function setActivePeriod(period) {
        filters.forEach(function (button) {
            button.classList.toggle('active', button.dataset.period === period);
        });
    }

    function clearChart() {
        chart.data.datasets.forEach(function (dataset) {
            dataset.data = [0, 0, 0, 0];
        });
        chart.update();
        if (currentLabel) currentLabel.textContent = 'Current Period';
        if (previousLabel) previousLabel.textContent = 'Previous Period';
    }

    async function loadAttendanceGraph(period) {
        if (!['DAY', 'WEEK', 'MONTH', 'YEAR'].includes(period)) {
            period = 'DAY';
        }

        selectedPeriod = period;
        setActivePeriod(period);

        filters.forEach(function (button) {
            button.disabled = true;
        });

        showMessage('Loading attendance data...');

        try {
            const url = '<?= base_url('admin/attendance_dashboard') ?>'
                        + '?graph_only=1&period=' + encodeURIComponent(period);
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'X-Requested-With': 'XMLHttpRequest',
                    'Accept': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error('Unable to fetch attendance data. HTTP ' + response.status);
            }

            const result = await response.json();

            if (result.status !== 'Y' || !result.graph) {
                clearChart();
                showMessage(result.remarks || 'No attendance data available.');
                return;
            }

            const graph = result.graph;

            chart.data.datasets[0].data = [
                Number(graph.current_present) || 0,
                Number(graph.current_absent) || 0,
                Number(graph.current_wfh) || 0,
                Number(graph.current_leave) || 0
            ];

            chart.data.datasets[1].data = [
                Number(graph.previous_present) || 0,
                Number(graph.previous_absent) || 0,
                Number(graph.previous_wfh) || 0,
                Number(graph.previous_leave) || 0
            ];

            chart.update();

            if (currentLabel) {
                currentLabel.textContent = 'Current (' +
                    formatRange(graph.current_start_date, graph.current_end_date) + ')';
            }

            if (previousLabel) {
                previousLabel.textContent = 'Previous (' +
                    formatRange(graph.previous_start_date, graph.previous_end_date) + ')';
            }

            hideMessage();
        } catch (error) {
            console.error('Attendance graph error:', error);
            showMessage(error.message || 'Unable to load attendance data.');
        } finally {
            filters.forEach(function (button) {
                button.disabled = false;
            });
            setActivePeriod(selectedPeriod);
        }
    }

    filters.forEach(function (button) {
        button.addEventListener('click', function () {
            loadAttendanceGraph(button.dataset.period);
        });
    });

    loadAttendanceGraph('DAY');
});
</script>

</body>

</html>