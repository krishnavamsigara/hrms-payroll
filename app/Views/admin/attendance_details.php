<?php
$attendance = $attendance ?? [];
$leave_balances = $leave_balances ?? [];
$employee_list = $employee_list ?? [];

$summary = $attendance[0] ?? [];

$selectedEmp = $selectedEmp ?? ($summary['emp_id'] ?? '');
$selectedMonth = (int)($selectedMonth ?? date('n'));
$selectedYear = (int)($selectedYear ?? date('Y'));

$employeeName = $summary['emp_name'] ?? 'Employee';
$employeeId = $summary['emp_id'] ?? $selectedEmp;
$companyName = $summary['company_name'] ?? '-';
$managerName = $summary['reporting_to_name'] ?? '-';
$designation = $summary['designation_name'] ?? $summary['designation'] ?? 'Employee';
$shiftName = $summary['shift_name'] ?? 'General';
$photoPath = $summary['profile_photo'] ?? '';

$periodStart = $summary['period_start'] ?? null;
$periodEnd = $summary['period_end'] ?? null;
$calculatedUntil = $summary['calculated_until'] ?? null;

$monthlyTotalHours = (float)($summary['monthly_total_hours_decimal'] ?? 0);
$monthlyWorkedDays = (int)($summary['monthly_total_worked_days'] ?? 0);

$totalDays = (int)($summary['total_days'] ?? count($attendance));
$workingDays = (int)($summary['working_days'] ?? 0);
$presentDays = (int)($summary['present_days'] ?? 0);
$absentDays = (int)($summary['absent_days'] ?? 0);
$holidayDays = (int)($summary['holidays'] ?? 0);
$leaveDays = (int)($summary['leave_days'] ?? 0);
$wfhDays = (int)($summary['wfh_days'] ?? 0);

$avgDailyHours = $monthlyWorkedDays > 0
    ? round($monthlyTotalHours / $monthlyWorkedDays, 1)
    : 0;

$attPct = $workingDays > 0
    ? round(($presentDays + $wfhDays) / $workingDays * 100)
    : 0;

$periodLabel = (!empty($periodStart) && !empty($periodEnd))
    ? date('M d', strtotime($periodStart)) . ' - ' . date('M d, Y', strtotime($periodEnd))
    : 'Period unavailable';

$plBalance = 0;
$slBalance = 0;
$clBalance = 0;

foreach ($leave_balances as $lb) {
    $code = strtoupper(trim($lb['leave_code'] ?? ''));
    $balance = (float)($lb['balance_days'] ?? 0);

    if ($code === 'PL') {
        $plBalance = $balance;
    } elseif ($code === 'SL') {
        $slBalance = $balance;
    } elseif ($code === 'CL') {
        $clBalance = $balance;
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Bloom Solutions | Admin Employee Timesheet</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">
<style>
:root{--purple:#4a00e0;--purple-dark:#2a0080;--border:#e2e8f0;--border-dark:#cbd5e1;--text:#334155;--muted:#64748b;--dark:#111827;--page:#f8fafc}
*{box-sizing:border-box}body{font-family:'Plus Jakarta Sans',sans-serif;background:var(--page);color:var(--text);font-size:13px;overflow-x:hidden}.content-wrapper{background:var(--page)!important;padding-bottom:30px}.content-header{padding:20px 0 25px!important}.page-title{font-size:25px;font-weight:800;color:var(--dark);margin:0 0 4px}.page-subtitle{font-size:13px;color:var(--muted);margin:0}
.timesheet-filter-card,.attendance-profile-card,.attendance-stat-card,.attendance-summary-card,.ts-card{background:#fff;border:1px solid var(--border);box-shadow:0 3px 8px rgba(15,23,42,.03)}.timesheet-filter-card{border-radius:12px;padding:14px 16px;margin-bottom:20px}.timesheet-filter-form{display:flex;align-items:center;gap:14px;flex-wrap:wrap}.filter-group{display:flex;align-items:center;gap:8px;min-width:140px}.employee-filter{flex:1 1 380px}.filter-label{color:#475569;font-size:10px;font-weight:800;white-space:nowrap}.filter-input{height:36px!important;min-height:36px;border:1px solid var(--border-dark)!important;border-radius:6px!important;background:#fff!important;color:var(--text)!important;font-size:12px!important;font-weight:600;padding:0 10px!important;box-shadow:none!important}.filter-group:not(.employee-filter) .filter-input{width:150px}.filter-input:focus{border-color:var(--purple)!important;outline:none}.filter-sync{margin-left:auto}.filter-sync-btn{height:36px;padding:0 18px;border:0;border-radius:6px;background:var(--purple);color:#fff;font-size:12px;font-weight:700;cursor:pointer}.filter-sync-btn:hover{background:var(--purple-dark)}
.employee-dropdown{position:relative;width:100%;min-width:0}.employee-dropdown-toggle{width:100%;height:36px;border:1px solid var(--border-dark);border-radius:6px;background:#fff;color:var(--text);font-size:12px;font-weight:600;padding:0 10px;display:flex;align-items:center;justify-content:space-between;gap:8px;cursor:pointer;text-align:left}.employee-dropdown-toggle span{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.employee-dropdown-menu{display:none;position:absolute;top:calc(100% + 4px);left:0;width:100%;background:#fff;border:1px solid var(--border);border-radius:8px;box-shadow:0 8px 20px rgba(15,23,42,.12);z-index:9999;overflow:hidden}.employee-dropdown-menu.show{display:block}.employee-search-box{position:relative;padding:8px;border-bottom:1px solid var(--border)}.employee-search-box i{position:absolute;left:18px;top:50%;transform:translateY(-50%);color:var(--muted);font-size:11px}.employee-search-box input{width:100%;height:32px;border:1px solid var(--border-dark);border-radius:6px;padding:0 10px 0 30px;font-size:11px}.employee-list{max-height:220px;overflow-y:auto}.employee-option{padding:9px 12px;font-size:12px;cursor:pointer}.employee-option:hover{background:#eef2ff;color:var(--purple)}
.attendance-top-layout{display:grid;grid-template-columns:minmax(260px,1fr) minmax(0,2.08fr);gap:18px;margin-bottom:20px}.attendance-profile-card,.attendance-stat-card,.attendance-summary-card{border-radius:16px}.attendance-profile-card{min-height:300px;padding:24px 20px;display:flex;flex-direction:column;align-items:center;text-align:center}.attendance-profile-photo{width:90px;height:90px;object-fit:cover;border:3px solid #fff;border-radius:50%;box-shadow:0 3px 12px rgba(0,0,0,.12);margin-bottom:14px}.attendance-profile-name{font-size:17px;font-weight:800;color:var(--dark);margin:0 0 3px}.attendance-profile-code{color:var(--purple);font-size:13px;font-weight:800;margin-bottom:10px}.attendance-designation{display:flex;gap:8px;align-items:center;background:#f1f5f9;color:var(--muted);border-radius:30px;padding:8px 14px;font-size:12px}.attendance-profile-divider{width:100%;border-top:1px solid var(--border);margin-top:auto;margin-bottom:10px}.attendance-profile-meta{width:100%;display:grid;grid-template-columns:1fr 1fr}.attendance-profile-meta-item{padding:2px 8px;min-width:0}.attendance-profile-meta-item+.attendance-profile-meta-item{border-left:1px solid var(--border)}.attendance-meta-label,.attendance-stat-label,.attendance-summary-label{display:block;color:#8b9bb4;font-size:10px;font-weight:700;letter-spacing:.25px;text-transform:uppercase}.attendance-meta-value{display:block;color:var(--dark);font-size:13px;font-weight:800;overflow-wrap:anywhere}.attendance-right-layout{display:grid;grid-template-rows:auto 1fr;gap:15px;min-width:0}.attendance-stat-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}.attendance-stat-card{min-width:0;min-height:150px;padding:20px}.attendance-stat-icon{width:42px;height:42px;display:flex;align-items:center;justify-content:center;background:#eef2ff;color:var(--purple);border-radius:12px;font-size:18px;margin-bottom:10px}.attendance-stat-value{color:#050b18;font-size:28px;line-height:1.2;font-weight:800;white-space:nowrap}.attendance-stat-unit{color:var(--muted);font-size:13px;font-weight:500}.attendance-summary-card{padding:20px}.attendance-summary-heading{display:flex;align-items:center;justify-content:space-between;gap:12px;padding-bottom:12px;border-bottom:1px solid #d8e0ea}.attendance-summary-title{color:#8b9bb4;font-size:11px;font-weight:800;text-transform:uppercase}.attendance-summary-date{font-size:12px;font-weight:600;text-align:right}.attendance-summary-grid{display:grid;grid-template-columns:repeat(7,minmax(0,1fr));padding-top:15px}.attendance-summary-item{min-width:0;text-align:center;padding:0 4px}.attendance-summary-item+.attendance-summary-item{border-left:1px solid var(--border)}.attendance-summary-label{font-size:9px;margin-bottom:7px;white-space:nowrap}.attendance-summary-value{display:block;color:var(--dark);font-size:20px;font-weight:800}.attendance-summary-value.present{color:#009447}.attendance-summary-value.absent{color:#e11d48}.attendance-summary-value.holiday{color:#7c3aed}.attendance-summary-value.leave{color:#c24100}.attendance-summary-value.wfh{color:#1d4ed8}
.ts-card{border-radius:12px;overflow:hidden;padding:0!important}.table-responsive{width:100%;overflow-x:auto}.table-timesheet{width:100%;min-width:760px;margin:0!important;border-collapse:separate;border-spacing:0}.table-timesheet thead th{background:#fff!important;color:#64748b!important;border:0!important;border-bottom:1px solid #f1f5f9!important;padding:14px 15px!important;font-size:11px!important;font-weight:600!important;letter-spacing:.5px;text-transform:uppercase;white-space:nowrap}.table-timesheet tbody td{padding:14px 15px!important;vertical-align:middle!important;font-size:12.5px!important;color:#334155;border-top:1px solid #f1f5f9!important;white-space:nowrap}.table-timesheet tbody tr:hover>td{background:#f8fafc}.table-timesheet tbody td:nth-child(3),.table-timesheet tbody td:nth-child(4),.table-timesheet tbody td:nth-child(5){font-family:'Plus Jakarta Sans',sans-serif;font-weight:500!important}.st-present,.st-late,.st-leave,.st-wfh,.st-holiday,.st-off,.st-absent{display:inline-block;padding:5px 8px;border-radius:4px;font-size:9px;font-weight:800;line-height:1;text-transform:uppercase}.st-present{background:#dcfce7;color:#15803d}.st-late{background:#fef3c7;color:#b45309}.st-absent{background:#fee2e2;color:#b91c1c}.st-leave{background:#f1f5f9;color:#475569}.st-wfh{background:#dbeafe;color:#1d4ed8}.st-holiday{background:#f3e8ff;color:#7e22ce}.st-off{background:#f1f5f9;color:#475569}.absent-row td{background:#fffafa}.action-icon-btn{border:0;background:transparent;color:#174dcc;cursor:pointer;padding:4px 6px}.action-icon-btn:hover{color:var(--purple)}.edit-absent-btn{height:28px;padding:0 10px;border-radius:6px;background:#e0e7ff;color:var(--purple);border:1px solid #c7d2fe;font-size:10px;font-weight:800;cursor:pointer}.inline-edit-content{display:flex;align-items:center;flex-wrap:wrap;gap:14px;width:100%;white-space:normal}.inline-edit-content>div{flex-shrink:0}.inline-select,.inline-time{height:32px;border:1px solid var(--border-dark);border-radius:6px;background:#fff;color:var(--text);font-size:11px;padding:0 8px}.inline-save-btn,.inline-cancel-btn{height:32px;padding:0 12px;border-radius:6px;font-size:10px;font-weight:800;cursor:pointer}.inline-save-btn{background:var(--purple);color:#fff;border:0}.inline-save-btn:disabled{opacity:.5}.inline-cancel-btn{background:#fff;color:var(--muted);border:1px solid var(--border-dark)}
.dataTables_wrapper{padding:12px 15px 15px;font-size:12px}.dataTables_wrapper .row{align-items:center}.dataTables_wrapper .dataTables_filter label,.dataTables_wrapper .dataTables_length label{font-size:12px;color:#64748b;font-weight:600}.dataTables_wrapper .dataTables_filter input,.dataTables_wrapper .dataTables_length select{height:34px;border:1px solid #e2e8f0;border-radius:10px;padding:4px 10px;font-size:12px;outline:none;box-shadow:none}.dataTables_wrapper .dataTables_filter input:focus,.dataTables_wrapper .dataTables_length select:focus{border-color:#4a00e0}.dataTables_wrapper .dataTables_filter{float:right;text-align:right;margin:0 0 15px}.dataTables_wrapper .dataTables_length{float:left;margin:0 0 15px}.dataTables_wrapper .dataTables_info{font-size:12px;color:#64748b;padding-top:10px;font-weight:600}.dataTables_wrapper .pagination{margin-top:8px}.dataTables_wrapper .pagination .page-item{margin:0 3px}.dataTables_wrapper .page-item .page-link{border:1px solid #e2e8f0!important;border-radius:10px!important;color:#64748b;font-size:12px;font-weight:600;min-width:32px;height:32px;display:flex;align-items:center;justify-content:center;padding:4px 10px}.dataTables_wrapper .page-item.active .page-link{background:linear-gradient(135deg,#4a00e0 0%,#2a0080 100%)!important;border-color:#4a00e0!important;color:#fff!important}.dataTables_wrapper .page-item .page-link:hover{background:#f8faff;color:#4a00e0;border-color:#4a00e0}.dataTables_wrapper table.dataTable thead th:before,.dataTables_wrapper table.dataTable thead th:after{font-size:10px;color:#4a00e0!important}.dataTables_wrapper .dataTables_paginate{padding-right:0}.dataTables_wrapper .dataTables_info,.dataTables_wrapper .dataTables_paginate{padding-bottom:8px}
.btn-bloom-back{background:#fff;color:var(--purple)!important;border:1px solid var(--purple);border-radius:8px;font-weight:700;font-size:12px;padding:8px 18px;margin-bottom:20px}.btn-bloom-back:hover{background:var(--purple);color:#fff!important}.punch-drawer{position:fixed;top:0;right:-420px;width:400px;max-width:100%;height:100vh;background:#fff;box-shadow:-8px 0 30px rgba(15,23,42,.16);z-index:9999;transition:right .25s;display:flex;flex-direction:column}.punch-drawer.open{right:0}.drawer-overlay{position:fixed;inset:0;background:rgba(15,23,42,.4);z-index:9998;display:none}.drawer-overlay.show{display:block}.modal-content{border:1px solid var(--border);border-radius:12px}.modal-header,.modal-footer{border-color:var(--border)}#absEditToast{position:fixed;bottom:24px;right:24px;min-width:280px;max-width:420px;z-index:99999;border-radius:8px;padding:13px 16px;font-size:12px;display:none;gap:10px}#absEditToast.show{display:flex}#absEditToast.toast-success{background:#dcfce7;color:#15803d}#absEditToast.toast-error{background:#fee2e2;color:#dc2626}
@media(max-width:1000px){.attendance-top-layout{grid-template-columns:1fr}.attendance-profile-card{min-height:260px}.timesheet-filter-form{align-items:stretch}.employee-filter{flex-basis:100%}.filter-group:not(.employee-filter){flex:1}.filter-group:not(.employee-filter) .filter-input{width:100%}.attendance-stat-grid{gap:10px}.attendance-stat-card{padding:15px}.attendance-stat-value{font-size:24px}}
@media(max-width:600px){.content-header{padding-left:12px!important;padding-right:12px!important}.page-title{font-size:21px}.timesheet-filter-form{flex-direction:column;align-items:stretch}.filter-group,.employee-filter,.filter-sync{width:100%;flex-basis:100%}.filter-sync-btn{width:100%}.attendance-stat-grid{grid-template-columns:1fr 1fr}.attendance-summary-card{overflow-x:auto}.attendance-summary-grid{min-width:480px}.attendance-summary-heading{align-items:flex-start;flex-direction:column}.attendance-summary-date{text-align:left}.punch-drawer{width:100%}#absEditToast{left:12px;right:12px;bottom:12px;min-width:0}}
@media (max-width:600px){.dataTables_wrapper .dataTables_length,.dataTables_wrapper .dataTables_filter{float:none;text-align:left;width:100%;margin-bottom:10px}.dataTables_wrapper .dataTables_filter input{max-width:62%}.table-timesheet thead th,.table-timesheet tbody td{padding:11px 12px!important}}
</style>
</head>
<body class="hold-transition sidebar-mini layout-fixed">

  <div class="content-wrapper">
    <div class="content-header pt-4 pb-2">
        <div class="container-fluid">

            <?php if (session()->getFlashdata('status') === 'Y') : ?>
                <div class="alert alert-success alert-dismissible fade show" role="alert">
                    <i class="fas fa-check-circle mr-1"></i>
                    <?= esc(session()->getFlashdata('remarks')) ?>
                    <button type="button" class="close" data-dismiss="alert">
                        <span>&times;</span>
                    </button>
                </div>
            <?php endif; ?>

            <div class="mb-3">
                <h1 class="page-title">Employee Timesheet</h1>
                <p class="page-subtitle">Review detailed attendance logs and timesheets.</p>
            </div>

            <div class="timesheet-filter-card mb-4">
                <form method="get"
                      action="<?= base_url('admin/attendance_details') ?>"
                      class="timesheet-filter-form">

                    <div class="filter-group employee-filter d-flex align-items-center">
                        <label class="filter-label mb-0 mr-2">EMPLOYEE:</label>

                        <div class="employee-dropdown">
                            <button type="button"
                                    class="employee-dropdown-toggle"
                                    onclick="toggleEmployeeDropdown()">
                                <span id="selectedEmployeeText">
                                    <?php
                                    $selectedEmployeeName = $selectedEmp;

                                    foreach ($employee_list as $e) {
                                        if ($selectedEmp == $e['emp_id']) {
                                            $selectedEmployeeName = $e['emp_id'] . ' - ' . $e['emp_name'];
                                            break;
                                        }
                                    }

                                    echo esc($selectedEmployeeName);
                                    ?>
                                </span>
                                <i class="fas fa-chevron-down"></i>
                            </button>

                            <div id="employeeDropdownMenu" class="employee-dropdown-menu">
                                <div class="employee-search-box">
                                    <i class="fas fa-search"></i>
                                    <input type="text"
                                           id="employeeSearch"
                                           placeholder="Search employee..."
                                           autocomplete="off"
                                           onkeyup="searchEmployees()">
                                </div>

                                <div class="employee-list" id="employeeList">
                                    <?php foreach ($employee_list as $e) : ?>
                                        <div class="employee-option"
                                             data-value="<?= esc($e['emp_id']) ?>"
                                             data-name="<?= esc($e['emp_id'] . ' - ' . $e['emp_name']) ?>"
                                             onclick="selectEmployee(this)">
                                            <?= esc($e['emp_id']) ?> - <?= esc($e['emp_name']) ?>
                                        </div>
                                    <?php endforeach; ?>
                                </div>
                            </div>

                            <select name="emp_id" id="employeeSelect" style="display:none;">
                                <?php foreach ($employee_list as $e) : ?>
                                    <option value="<?= esc($e['emp_id']) ?>"
                                        <?= $selectedEmp == $e['emp_id'] ? 'selected' : '' ?>>
                                        <?= esc($e['emp_id']) ?> - <?= esc($e['emp_name']) ?>
                                    </option>
                                <?php endforeach; ?>

                                <?php if (!in_array($selectedEmp, array_column($employee_list, 'emp_id'))) : ?>
                                    <option value="<?= esc($selectedEmp) ?>" selected>
                                        <?= esc($selectedEmp) ?>
                                    </option>
                                <?php endif; ?>
                            </select>
                        </div>
                    </div>

                    <div class="filter-group d-flex align-items-center">
                        <label class="filter-label mb-0 mr-2">MONTH:</label>
                        <select name="month" class="form-control filter-input">
                            <?php
                            $months = [
                                1 => 'January', 2 => 'February', 3 => 'March',
                                4 => 'April', 5 => 'May', 6 => 'June',
                                7 => 'July', 8 => 'August', 9 => 'September',
                                10 => 'October', 11 => 'November', 12 => 'December'
                            ];

                            foreach ($months as $m => $name) :
                            ?>
                                <option value="<?= $m ?>" <?= $selectedMonth === $m ? 'selected' : '' ?>>
                                    <?= esc($name) ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="filter-group d-flex align-items-center">
                        <label class="filter-label mb-0 mr-2">YEAR:</label>
                        <select name="year" class="form-control filter-input">
                            <?php
                            $currentYear = (int)date('Y');

                            for ($y = $currentYear - 2; $y <= $currentYear + 1; $y++) :
                            ?>
                                <option value="<?= $y ?>" <?= $selectedYear === $y ? 'selected' : '' ?>>
                                    <?= $y ?>
                                </option>
                            <?php endfor; ?>
                        </select>
                    </div>

                    <div class="filter-sync">
                        <button type="submit" class="filter-sync-btn">Submit</button>
                    </div>

                </form>
            </div>

            <div class="attendance-top-layout">
                <div class="attendance-profile-card">
                    <?php if ($photoPath !== '') : ?>
                        <img src="<?= esc(base_url($photoPath)) ?>"
                             class="attendance-profile-photo"
                             alt="Employee profile">
                    <?php else : ?>
                        <img src="https://ui-avatars.com/api/?name=<?= urlencode($employeeName) ?>&background=4f00e8&color=fff&size=128"
                             class="attendance-profile-photo"
                             alt="Employee profile">
                    <?php endif; ?>

                    <h5 class="attendance-profile-name"><?= esc($employeeName) ?></h5>
                    <div class="attendance-profile-code"><?= esc($employeeId) ?></div>

                    <div class="attendance-designation">
                        <i class="far fa-user"></i>
                        <span><?= esc($designation) ?></span>
                    </div>

                    <div class="attendance-profile-divider"></div>

                    <div class="attendance-profile-meta">
                        <div class="attendance-profile-meta-item">
                            <span class="attendance-meta-label">Manager</span>
                            <span class="attendance-meta-value"><?= esc($managerName) ?></span>
                        </div>
                        <div class="attendance-profile-meta-item">
                            <span class="attendance-meta-label">Company</span>
                            <span class="attendance-meta-value"><?= esc($companyName) ?></span>
                        </div>
                    </div>
                </div>

                <div class="attendance-right-layout">
                    <div class="attendance-stat-grid">

                        <div class="attendance-stat-card">
                            <div class="attendance-stat-icon"><i class="far fa-clock"></i></div>
                            <div class="attendance-stat-label">Total Hours Worked</div>
                            <div class="attendance-stat-value">
                                <?= number_format($monthlyTotalHours, 2) ?>
                                <span class="attendance-stat-unit">hrs</span>
                            </div>
                        </div>

                        <div class="attendance-stat-card">
                            <div class="attendance-stat-icon"><i class="fas fa-stopwatch"></i></div>
                            <div class="attendance-stat-label">Avg Daily Hours</div>
                            <div class="attendance-stat-value">
                                <?= number_format($avgDailyHours, 1) ?>
                                <span class="attendance-stat-unit">hrs</span>
                            </div>
                        </div>

                        <div class="attendance-stat-card">
                            <div class="attendance-stat-icon"><i class="far fa-check-square"></i></div>
                            <div class="attendance-stat-label">Attendance %</div>
                            <div class="attendance-stat-value"><?= $attPct ?>%</div>
                        </div>

                    </div>

                    <div class="attendance-summary-card">
                        <div class="attendance-summary-heading">
                            <span class="attendance-summary-title">Summary Period</span>
                            <span class="attendance-summary-date"><?= esc($periodLabel) ?></span>
                        </div>

                        <div class="attendance-summary-grid">
                            <div class="attendance-summary-item">
                                <span class="attendance-summary-label">Total Days</span>
                                <span class="attendance-summary-value"><?= $totalDays ?></span>
                            </div>
                            <div class="attendance-summary-item">
                                <span class="attendance-summary-label">Working</span>
                                <span class="attendance-summary-value"><?= $workingDays ?></span>
                            </div>
                            <div class="attendance-summary-item">
                                <span class="attendance-summary-label">Present</span>
                                <span class="attendance-summary-value present"><?= $presentDays ?></span>
                            </div>
                            <div class="attendance-summary-item">
                                <span class="attendance-summary-label">Absent</span>
                                <span class="attendance-summary-value absent"><?= $absentDays ?></span>
                            </div>
                            <div class="attendance-summary-item">
                                <span class="attendance-summary-label">Holidays</span>
                                <span class="attendance-summary-value holiday"><?= $holidayDays ?></span>
                            </div>
                            <div class="attendance-summary-item">
                                <span class="attendance-summary-label">Leave</span>
                                <span class="attendance-summary-value leave"><?= $leaveDays ?></span>
                            </div>
                            <div class="attendance-summary-item">
                                <span class="attendance-summary-label">WFH</span>
                                <span class="attendance-summary-value wfh"><?= $wfhDays ?></span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

                        <div class="ts-card p-0 overflow-hidden">
                <div class="table-responsive">
                    <table id="timesheetTable" class="table table-timesheet mb-0">
                        <thead>
                            <tr>
                                <th>DATE</th>
                                <th>STATUS</th>
                                <th>FIRST IN</th>
                                <th>LAST OUT</th>
                                <th>TOTAL HRS</th>
                                <th class="text-right">ACTIONS</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (!empty($attendance)) : ?>
                                <?php foreach ($attendance as $index => $row) : ?>
                                    <?php
                                    $status = strtoupper(trim($row['status'] ?? $row['attendance_status'] ?? 'ABSENT'));

                                    $badgeMap = [
                                        'PRESENT' => 'st-present',
                                        'P' => 'st-present',
                                        'WFH' => 'st-wfh',
                                        'HOLIDAY' => 'st-holiday',
                                        'PL' => 'st-leave',
                                        'SL' => 'st-leave',
                                        'CL' => 'st-leave',
                                        'ML' => 'st-leave',
                                        'LOP' => 'st-absent',
                                        'ABSENT' => 'st-absent',
                                        'A' => 'st-absent',
                                        'WEEKLY OFF' => 'st-off',
                                        'WEEKOFF' => 'st-off',
                                        'OFF' => 'st-off'
                                    ];

                                    $badgeClass = $badgeMap[$status] ?? (
                                        strpos($status, 'LEAVE') !== false ? 'st-leave' : 'st-absent'
                                    );

                                    $isAbsent = in_array($status, ['ABSENT', 'A'], true);
                                    $attDate = $row['attendance_date'] ?? '';
                                    $formattedDate = $attDate !== ''
                                        ? date('d M, D', strtotime($attDate))
                                        : '-';

                                    $punchIn = $row['punch_in'] ?? '';
                                    $punchOut = $row['punch_out'] ?? '';

                                    $inTime = !empty($punchIn)
                                        ? date('h:i A', strtotime($punchIn))
                                        : '-';

                                    $outTime = !empty($punchOut)
                                        ? date('h:i A', strtotime($punchOut))
                                        : '-';

                                    $totalHours = $row['daily_time_formatted'] ?? '-';
                                    if ($totalHours === '' || $totalHours === null) {
                                        $totalHours = '-';
                                    }

                                    $rowEmpId = $row['emp_id'] ?? $selectedEmp;
                                    ?>

                                    <tr id="att-row-<?= $index ?>"
                                        class="<?= $isAbsent ? 'absent-row' : '' ?>">
                                        <td class="font-weight-bold text-dark">
                                            <?= esc($formattedDate) ?>
                                        </td>
                                        <td id="status-cell-<?= $index ?>">
                                            <span class="<?= esc($badgeClass) ?>"
                                                  id="status-badge-<?= $index ?>">
                                                <?= esc($status) ?>
                                            </span>
                                        </td>
                                        <td id="punchin-cell-<?= $index ?>"><?= esc($inTime) ?></td>
                                        <td id="punchout-cell-<?= $index ?>"><?= esc($outTime) ?></td>
                                        <td class="font-weight-bold text-dark" id="hrs-cell-<?= $index ?>">
                                            <?= esc($totalHours) ?>
                                        </td>
                                        <td class="text-right">
                                            <?php if ($isAbsent) : ?>
                                                <button type="button"
                                                        class="edit-absent-btn mr-1"
                                                        id="edit-btn-<?= $index ?>"
                                                        onclick="openInlineEdit(<?= $index ?>, '<?= esc($rowEmpId) ?>', '<?= esc($attDate) ?>')">
                                                    <i class="fas fa-pen mr-1"></i> Edit
                                                </button>
                                            <?php else : ?>
                                                <button type="button"
                                                        class="action-icon-btn mr-1"
                                                        title="Edit Punch Timings"
                                                        onclick="openEditModal('<?= esc($rowEmpId) ?>', '<?= esc($attDate) ?>', '<?= esc($punchIn) ?>', '<?= esc($punchOut) ?>')">
                                                    <i class="far fa-calendar-alt"></i>
                                                </button>
                                            <?php endif; ?>

                                            <button type="button"
                                                    class="action-icon-btn"
                                                    title="View Punch Details"
                                                    onclick="openPunchDrawer('<?= esc($formattedDate) ?>', '<?= esc($inTime) ?>', '<?= esc($outTime) ?>', '<?= esc($status) ?>')">
                                                <i class="far fa-eye"></i>
                                            </button>
                                        </td>
                                    </tr>

                                    <?php if ($isAbsent) : ?>
                                        <tr id="edit-row-<?= $index ?>"
                                            class="inline-edit-row"
                                            style="display:none;">
                                            <td colspan="6">
                                                <div class="inline-edit-content">
                                                    <div>
                                                        <div class="stat-label">DATE</div>
                                                        <div class="font-weight-bold text-dark">
                                                            <?= esc($formattedDate) ?>
                                                        </div>
                                                    </div>

                                                    <div>
                                                        <div class="stat-label">CHANGE TO</div>
                                                        <select class="inline-select"
                                                                id="etype-<?= $index ?>"
                                                                onchange="togglePunchFields(<?= $index ?>)">
                                                            <option value="">-- Select --</option>
                                                            <option value="WFH">WFH (Work From Home)</option>
                                                            <option value="PL">PL (Personal Leave)</option>
                                                            <option value="SL">SL (Sick Leave)</option>
                                                            <option value="ML">ML (Maternity Leave)</option>
                                                            <option value="LOP">LOP (Loss of Pay)</option>
                                                        </select>
                                                    </div>

                                                    <div id="wfh-times-<?= $index ?>"
                                                         style="display:none;"
                                                         class="d-flex align-items-center">
                                                        <div class="mr-2">
                                                            <div class="stat-label">PUNCH IN</div>
                                                            <input type="time"
                                                                   class="inline-time"
                                                                   id="pin-<?= $index ?>"
                                                                   value="09:30">
                                                        </div>
                                                        <div>
                                                            <div class="stat-label">PUNCH OUT</div>
                                                            <input type="time"
                                                                   class="inline-time"
                                                                   id="pout-<?= $index ?>"
                                                                   value="18:30">
                                                        </div>
                                                    </div>

                                                    <div id="leave-note-<?= $index ?>"
                                                         style="display:none;">
                                                        <small class="text-muted">
                                                            Balance will be deducted. If no balance, marked as LOP.
                                                        </small>
                                                    </div>

                                                    <div class="ml-auto d-flex" style="gap:6px;">
                                                        <button type="button"
                                                                class="inline-save-btn"
                                                                id="save-btn-<?= $index ?>"
                                                                onclick="saveAbsentEdit(<?= $index ?>, '<?= esc($rowEmpId) ?>', '<?= esc($attDate) ?>')"
                                                                disabled>
                                                            <i class="fas fa-save mr-1"></i> Save
                                                        </button>
                                                        <button type="button"
                                                                class="inline-cancel-btn"
                                                                onclick="cancelInlineEdit(<?= $index ?>)">
                                                            Cancel
                                                        </button>
                                                    </div>
                                                </div>
                                            </td>
                                        </tr>
                                    <?php endif; ?>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="d-flex justify-content-start mb-3 mt-3">
                <button type="button"
                        class="btn btn-bloom-back"
                        onclick="window.history.back();">
                    <i class="fas fa-arrow-left mr-1"></i> Back
                </button>
            </div>

<div id="drawerOverlay" class="drawer-overlay" onclick="closePunchDrawer()"></div>
<aside id="punchDrawer" class="punch-drawer" aria-label="Punch details">
  <div class="d-flex justify-content-between align-items-center p-3 border-bottom"><div><h5 class="mb-1">Punch Details</h5><small id="drawerDate" class="text-muted">Attendance details</small></div><button type="button" class="btn btn-light btn-sm" onclick="closePunchDrawer()" aria-label="Close"><i class="fas fa-times"></i></button></div>
  <div class="p-3"><div class="border rounded p-3 mb-3"><small class="text-muted d-block">FIRST IN</small><strong id="drawerFirstIn">N/A</strong></div><div class="border rounded p-3 mb-3"><small class="text-muted d-block">LAST OUT</small><strong id="drawerLastOut">N/A</strong></div><div class="border rounded p-3"><div class="mb-3"><small class="text-muted d-block">Punch-in log</small><strong id="drawerInLog">N/A</strong></div><div><small class="text-muted d-block">Punch-out log</small><strong id="drawerOutLog">N/A</strong></div></div></div>
</aside>
<div class="modal fade" id="editPunchModal" tabindex="-1" role="dialog" aria-hidden="true"><div class="modal-dialog modal-dialog-centered" role="document"><div class="modal-content"><form id="editPunchForm" onsubmit="return false;"><div class="modal-header"><h5 class="modal-title">Edit Punch Timings</h5><button type="button" class="close" data-dismiss="modal"><span>&times;</span></button></div><div class="modal-body"><input type="hidden" id="edit_emp_id"><input type="hidden" id="edit_att_date"><div class="form-group"><label>Employee ID</label><input type="text" id="display_emp_id" class="form-control" readonly></div><div class="form-group"><label>Attendance Date</label><input type="text" id="display_att_date" class="form-control" readonly></div><div class="form-row"><div class="form-group col-6"><label>First In</label><input type="time" id="edit_first_in" class="form-control" required></div><div class="form-group col-6"><label>Last Out</label><input type="time" id="edit_last_out" class="form-control" required></div></div><small class="text-muted">The save endpoint for punch-time edits must be connected before this form can persist changes.</small></div><div class="modal-footer"><button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button><button type="button" class="btn btn-primary" onclick="showToast('Punch edit save endpoint is not configured.', false)">Save Changes</button></div></form></div></div></div>
<div id="absEditToast" role="status" aria-live="polite"><i id="toastIcon" class="fas fa-info-circle"></i><span id="toastMsg"></span><button type="button" class="close ml-auto" onclick="hideToast()"><span>&times;</span></button></div>


<script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>
<script>
var timesheetTable;
var inlineEditTemplates = {};
$(function () {
    // Save each edit form, then remove its invalid hidden table row before DataTables starts.
    $('#timesheetTable tbody tr.inline-edit-row').each(function () {
        var index = this.id.replace('edit-row-', '');
        inlineEditTemplates[index] = $(this).children('td').html();
        $(this).remove();
    });
    timesheetTable = $('#timesheetTable').DataTable({
        responsive: false,
        autoWidth: false,
        paging: true,
        ordering: true,
        order: [],
        searching: true,
        info: true,
        lengthChange: true,
        pageLength: 10,
        lengthMenu: [[5, 10, 25, 50], [5, 10, 25, 50]],
        columnDefs: [{ orderable: false, targets: [5] }],
        language: { emptyTable: 'No attendance logs available for this period.' },
        dom: "<'row'<'col-sm-6'l><'col-sm-6'f>>t<'row'<'col-sm-6'i><'col-sm-6'p>>"
    });
});
function toggleEmployeeDropdown() {
    var menu = document.getElementById('employeeDropdownMenu');
    var search = document.getElementById('employeeSearch');
    menu.classList.toggle('show');
    if (menu.classList.contains('show')) { search.value = ''; searchEmployees(); search.focus(); }
}
function searchEmployees() {
    var value = document.getElementById('employeeSearch').value.toLowerCase().trim();
    document.querySelectorAll('#employeeList .employee-option').forEach(function (option) {
        option.style.display = (option.getAttribute('data-name') || option.textContent).toLowerCase().includes(value) ? 'block' : 'none';
    });
}
function selectEmployee(option) {
    var select = document.getElementById('employeeSelect');
    var value = option.getAttribute('data-value');
    if (!value) return;
    select.value = value;
    document.getElementById('selectedEmployeeText').textContent = option.getAttribute('data-name');
    document.getElementById('employeeDropdownMenu').classList.remove('show');
    select.form.submit();
}
document.addEventListener('click', function (event) {
    var dropdown = document.querySelector('.employee-dropdown');
    var menu = document.getElementById('employeeDropdownMenu');
    if (dropdown && menu && !dropdown.contains(event.target)) menu.classList.remove('show');
});
function openPunchDrawer(dateStr, inTime, outTime, statusStr) {
    $('#drawerDate').text(dateStr + ' - ' + statusStr);
    $('#drawerFirstIn').text(inTime !== '-' ? inTime : 'N/A');
    $('#drawerLastOut').text(outTime !== '-' ? outTime : 'N/A');
    $('#drawerInLog').text(inTime !== '-' ? inTime : 'N/A');
    $('#drawerOutLog').text(outTime !== '-' ? outTime : 'N/A');
    $('#drawerOverlay, #punchDrawer').addClass('show'); $('#punchDrawer').addClass('open');
}
function closePunchDrawer() { $('#drawerOverlay').removeClass('show'); $('#punchDrawer').removeClass('open'); }
function openEditModal(empId, attDate, inTimeFull, outTimeFull) {
    $('#edit_emp_id,#display_emp_id').val(empId); $('#edit_att_date,#display_att_date').val(attDate);
    var toTime = function (value) { if (!value) return ''; var match = value.match(/(?:T| )(\d{2}:\d{2})/); return match ? match[1] : ''; };
    $('#edit_first_in').val(toTime(inTimeFull) || '09:30'); $('#edit_last_out').val(toTime(outTimeFull) || '18:30'); $('#editPunchModal').modal('show');
}
function openInlineEdit(index) {
    var row = timesheetTable.row('#att-row-' + index);
    if (!inlineEditTemplates[index]) { showToast('Inline edit form is unavailable.', false); return; }
    // DataTables child content is outside the six-column table grid and does not corrupt sorting.
    row.child(inlineEditTemplates[index], 'inline-edit-child').show();
    $('#att-row-' + index + ' .edit-absent-btn').hide();
    $('#etype-' + index).val(''); $('#wfh-times-' + index).hide(); $('#leave-note-' + index).hide(); $('#save-btn-' + index).prop('disabled', true);
}
function cancelInlineEdit(index) { timesheetTable.row('#att-row-' + index).child.hide(); $('#att-row-' + index + ' .edit-absent-btn').show(); }
function togglePunchFields(index) {
    var type = $('#etype-' + index).val();
    $('#wfh-times-' + index).toggle(type === 'WFH'); $('#leave-note-' + index).toggle(['PL','SL','ML'].includes(type)); $('#save-btn-' + index).prop('disabled', type === '');
}
function saveAbsentEdit(index, empId, attDate) {
    var type = $('#etype-' + index).val(), punchIn = '', punchOut = '';
    if (!type) { showToast('Please select an edit type.', false); return; }
    if (type === 'WFH') {
        punchIn = $('#pin-' + index).val(); punchOut = $('#pout-' + index).val();
        if (!punchIn || !punchOut || punchOut <= punchIn) { showToast('Enter valid punch-in and punch-out times.', false); return; }
    }
    var button = $('#save-btn-' + index), originalHtml = button.html();
    button.prop('disabled', true).html('<i class="fas fa-spinner fa-spin mr-1"></i> Saving...');
    $.ajax({
        url: '<?= base_url('admin/save_absent_edit') ?>', type: 'POST', dataType: 'json',
        data: { emp_id: empId, att_date: attDate, edit_type: type, punch_in: punchIn, punch_out: punchOut, '<?= csrf_token() ?>': '<?= csrf_hash() ?>' },
        success: function (response) {
            if (response && response.status === 'Y') { showToast(response.message || 'Attendance updated.', true); window.location.reload(); }
            else { showToast((response && response.message) || 'Unable to update attendance.', false); button.prop('disabled', false).html(originalHtml); }
        },
        error: function () { showToast('Server error while updating attendance.', false); button.prop('disabled', false).html(originalHtml); }
    });
}
function showToast(message, success) {
    var toast = $('#absEditToast'); $('#toastMsg').text(message);
    $('#toastIcon').attr('class', success ? 'fas fa-check-circle' : 'fas fa-exclamation-circle');
    toast.removeClass('toast-success toast-error show').addClass(success ? 'toast-success' : 'toast-error').addClass('show');
    clearTimeout(window.attendanceToastTimer); window.attendanceToastTimer = setTimeout(hideToast, 5000);
}
function hideToast() { $('#absEditToast').removeClass('show'); }
</script>
</div>
</div>
</div>
</body>
</html>
