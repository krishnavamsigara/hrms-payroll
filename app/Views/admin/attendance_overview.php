<?php
// Capture is_s1 flag passed from controller or fallback to query param
$is_s1 = !empty($is_s1) ? 1 : (!empty($_GET['s1']) ? 1 : 0);
$month = (int) ($selectedMonth ?? date('n'));
$year  = (int) ($selectedYear ?? date('Y'));

// Build target URL for Finalize page with s1 preserved
$finalizeUrl = base_url('admin/attendance_finalize') . '?month=' . $month . '&year=' . $year;
if ($is_s1) {
    $finalizeUrl .= '&s1=1';
}

// Opened from a payroll cycle (?cycle=ID): keep it, so finalizing returns to that cycle
$return_cycle = (int) ($return_cycle ?? ($_GET['cycle'] ?? 0));
if ($return_cycle > 0) {
    $finalizeUrl .= '&cycle=' . $return_cycle;
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bloom Solutions | Attendance Overview</title>

  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
  <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">

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
      padding-bottom: 30px !important;
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

    .filter-card {
      background: #ffffff;
      border: 1px solid var(--slate-200);
      border-radius: 16px;
      padding: 16px 20px;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02);
      margin-bottom: 20px;
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
      transition: all 0.2s ease;
    }

    .filter-input:focus {
      border-color: var(--bloom-purple);
      box-shadow: 0 0 0 3px rgba(74, 0, 224, 0.1);
      outline: none;
    }

    .ts-card {
      background: #ffffff;
      border: 1px solid var(--slate-200);
      border-radius: 16px;
      padding: 20px;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02);
      margin-bottom: 20px;
    }

    .emp-avatar-sm {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: var(--bloom-purple-light);
      color: var(--bloom-purple);
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
      font-size: 13px;
    }

    .emp-id-badge {
      width: 90px;
      padding: 6px 0;
      text-align: center;
      border-radius: 10px;
      font-weight: 700;
      font-size: 11px;
      display: inline-block;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      background: var(--bloom-purple-light);
      color: var(--bloom-purple);
    }

    .table-overview thead th {
      background-color: #f8fafc;
      color: var(--slate-500);
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      border-bottom: 1px solid var(--slate-200);
      padding: 12px 16px;
    }

    .table-overview tbody td {
      padding: 14px 16px;
      vertical-align: middle;
      font-size: 13px;
      border-bottom: 1px solid var(--slate-100);
    }

    .table-overview tbody tr:hover {
      background-color: #f8fafc;
    }

    .btn-view-ts {
      background: linear-gradient(135deg, #4a00e0 0%, #2a0080 100%);
      color: #ffffff;
      border: none;
      font-weight: 600;
      font-size: 12px;
      padding: 7px 14px;
      border-radius: 8px;
      transition: all 0.2s ease;
      display: inline-flex !important;
      align-items: center !important;
      justify-content: center !important;
      gap: 6px !important;
      white-space: nowrap !important;
    }

    .btn-view-ts:hover {
      color: #ffffff;
      transform: translateY(-1px);
      box-shadow: 0 4px 10px rgba(74, 0, 224, 0.25);
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
      background: linear-gradient(135deg, #4a00e0 0%, #2a0080 100%) !important;
      border-color: #4a00e0 !important;
      color: #fff !important;
    }

    .dataTables_paginate .page-link:hover {
      background: #f8faff !important;
      color: #4a00e0 !important;
      border-color: #4a00e0 !important;
    }

    .dataTables_info {
      color: #64748b !important;
      font-size: 12px;
      font-weight: 600;
      padding-left: 15px;
    }

    .dataTables_length {
      margin: 8px 15px !important;
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
      margin: 8px 15px !important;
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

    .bloom-btn-primary {
      height: 38px;
      border-radius: 10px;
      background: linear-gradient(135deg, #4a00e0 0%, #2a0080 100%);
      color: #ffffff;
      border: none;
      transition: all 0.2s ease;
    }

    .bloom-btn-primary:hover {
      background: linear-gradient(135deg, #2a0080 0%, #4a00e0 100%);
      color: #ffffff;
      transform: translateY(-1px);
      box-shadow: 0 4px 10px rgba(74, 0, 224, 0.25);
    }

    .badge-present {
      width: 90px;
      padding: 6px 0;
      text-align: center;
      border-radius: 10px;
      font-weight: 700;
      font-size: 11px;
      display: inline-block;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      background: #ecfdf5;
      color: #10b981;
    }

    .filter-label {
      color: #475569;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.4px;
    }

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
      margin-bottom: 20px !important;
      position: relative;
      z-index: 5;
    }

    .btn-bloom-back:hover {
      background: linear-gradient(135deg, var(--bloom-purple) 0%, var(--bloom-dark) 100%);
      color: #fff !important;
      border-color: var(--bloom-purple);
      transform: translateY(-1px);
      box-shadow: 0 4px 10px rgba(74, 0, 224, 0.20);
    }
  </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed">
  <div class="wrapper">
    <div class="content-wrapper">
      <div class="content-header pt-4 pb-2">
        <div class="container-fluid">
          <div class="d-flex align-items-center justify-content-between flex-wrap gap-3 mb-3">
            <div>
              <h1 class="page-title">Employee Attendance Overview</h1>
              <p class="page-subtitle">Minimal employee details with monthly attendance summaries and direct timesheet access</p>
            </div>
          </div>

          <!-- Filter Bar -->
          <div class="filter-card">
            <form method="get" action="<?= base_url('admin/attendance_overview') ?>" class="row align-items-end gy-2 gx-3">
              <!-- MONTH -->
              <div class="col-auto d-flex align-items-center">
                <label class="filter-label mb-0 mr-2">MONTH:</label>
                <select name="month" class="form-control filter-input">
                  <?php
                  $months = [
                    1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April',
                    5 => 'May', 6 => 'June', 7 => 'July', 8 => 'August',
                    9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December'
                  ];

                  foreach ($months as $mNum => $mName) {
                    $sel = ($selectedMonth == $mNum) ? 'selected' : '';
                    echo "<option value=\"$mNum\" $sel>$mName</option>";
                  }
                  ?>
                </select>
              </div>

              <!-- YEAR -->
              <div class="col-auto d-flex align-items-center">
                <label class="filter-label mb-0 mr-2">YEAR:</label>
                <select name="year" class="form-control filter-input">
                  <?php
                  $currY = (int)date('Y');
                  for ($y = $currY - 2; $y <= $currY + 1; $y++) {
                    $sel = ($selectedYear == $y) ? 'selected' : '';
                    echo "<option value=\"$y\" $sel>$y</option>";
                  }
                  ?>
                </select>
              </div>

              <!-- Preserves s1 flag when submitting the filter form -->
              <?php if ($is_s1): ?>
                <input type="hidden" name="s1" value="1">
              <?php endif; ?>

              <!-- SUBMIT BUTTON -->
              <div class="col-auto">
                <button type="submit" class="btn btn-primary font-weight-bold px-3" style="height:38px; border-radius:10px; background:var(--bloom-purple); border:none; font-size:13px;">
                  Submit
                </button>
              </div>

              <!-- SAVE / FINALIZE ATTENDANCE BUTTONS -->
              <div class="col-auto ml-auto">
                <?php
                $attendanceStatus = 'N';

                if (is_array($att_gen ?? null)) {
                  if (isset($att_gen['attendance_status'])) {
                    $attendanceStatus = $att_gen['attendance_status'];
                  } elseif (isset($att_gen[0]['attendance_status'])) {
                    $attendanceStatus = $att_gen[0]['attendance_status'];
                  }
                } elseif (is_object($att_gen ?? null)) {
                  $attendanceStatus = $att_gen->attendance_status ?? 'N';
                }

                $isFinalized = strtoupper(trim((string) $attendanceStatus)) === 'Y';
                ?>

                <div class="d-flex align-items-center flex-wrap" style="gap: 10px;">
                  <button type="button"
                    class="btn font-weight-bold px-3 <?= $isFinalized ? 'btn-success' : 'bloom-btn-primary' ?>"
                    <?= $isFinalized ? 'disabled' : 'onclick="$(\'#payrollModal\').modal(\'show\')"' ?>
                    style="font-size: 13px;">
                    <i class="fas <?= $isFinalized ? 'fa-check-circle' : 'fa-calculator' ?> mr-1"></i>
                    <?= $isFinalized ? 'Attendance Finalized' : 'Generate Attendance' ?>
                  </button>

                  <a href="<?= $finalizeUrl ?>" class="btn btn-outline-primary font-weight-bold px-3" style="font-size:13px;">
                    <i class="fas fa-arrow-right mr-1"></i>
                    Attendance Finalize
                  </a>
                </div>
              </div>
            </form>
          </div>

          <!-- Main Table Card -->
          <div class="ts-card p-0 overflow-hidden">
            <div class="table-responsive">
              <table id="overviewTable" class="table table-overview mb-0">
                <thead>
                  <tr>
                    <th>Employee Name</th>
                    <th>Emp ID</th>
                    <th>Department</th>
                    <th>Designation</th>
                    <th class="text-center">Present Days</th>
                    <th class="text-center">Total Worked Hours</th>
                    <th class="text-right">Action</th>
                  </tr>
                </thead>
                <tbody>
                  <?php if (!empty($employees)) : ?>
                    <?php foreach ($employees as $emp) : ?>
                      <tr>
                        <td>
                          <div class="d-flex align-items-center gap-2">
                            <div class="emp-avatar-sm mr-2">
                              <?= strtoupper(substr($emp['emp_name'] ?? 'E', 0, 1)) ?>
                            </div>
                            <div>
                              <strong class="text-dark d-block"><?= esc($emp['emp_name']) ?></strong>
                            </div>
                          </div>
                        </td>
                        <td>
                          <span class="emp-id-badge"><?= esc($emp['emp_id']) ?></span>
                        </td>
                        <td><?= esc($emp['department_name'] ?? 'General') ?></td>
                        <td><?= esc($emp['designation_name'] ?? 'Employee') ?></td>
                        <td class="text-center">
                          <span class="badge-present">
                            <?= esc($emp['total_present'] ?? 0) ?> Days
                          </span>
                        </td>
                        <td class="text-center">
                          <span class="badge badge-light border px-2 py-1 text-dark" style="width: 90px; padding: 6px 0 !important; text-align: center; border-radius: 10px; font-weight: 700; font-size: 11px; display: inline-block; text-transform: uppercase; letter-spacing: 0.5px;">
                            <?= esc($emp['total_hours_fmt'] ?? '00h 00m') ?>
                          </span>
                        </td>
                        <td class="text-right">
                          <a href="<?= base_url('admin/attendance_details?emp_id=' . urlencode($emp['emp_id']) . '&month=' . $selectedMonth . '&year=' . $selectedYear) ?>" class="btn-view-ts" title="View Full Timesheet">
                            <i class="fas fa-calendar-alt"></i> View Timesheet
                          </a>
                        </td>
                      </tr>
                    <?php endforeach; ?>
                  <?php else : ?>
                    <tr>
                      <td colspan="7" class="text-center py-4 text-muted">No employee records found.</td>
                    </tr>
                  <?php endif; ?>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Back Navigation: Returns to step1 if s1 active, otherwise history.back -->
          <div class="d-flex justify-content-start mb-3">
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

  <!-- Payroll Calculation Modal -->
  <div class="modal fade" id="payrollModal" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered" role="document">
      <div class="modal-content" style="border-radius: 16px;">
        <div class="modal-header border-bottom">
          <h5 class="modal-title font-weight-bold text-dark">
            <i class="fas fa-calculator mr-1" style="color:#4a00e0;"></i> Generate Payroll Attendance
          </h5>
          <button type="button" class="close" data-dismiss="modal" aria-label="Close">
            <span aria-hidden="true">&times;</span>
          </button>
        </div>
        <div class="modal-body text-center p-4">
          <p class="text-muted mb-4">
            Are you sure you want to calculate and save the attendance summary for 
            <strong class="text-dark"><?= date('F Y', mktime(0, 0, 0, $selectedMonth, 10, $selectedYear)) ?></strong>? 
            <br><small>This will calculate paid/unpaid days for all employees and overwrite any previously saved summary for this month.</small>
          </p>
          
          <button type="button" class="btn btn-light border font-weight-bold px-4 py-2 mr-2" data-dismiss="modal" style="border-radius:10px;">Cancel</button>
          <button type="button" class="btn font-weight-bold px-4 py-2" id="btnRunPayroll" onclick="generatePayrollAttendance()" style="border-radius:10px; background:linear-gradient(135deg, #4a00e0 0%, #2a0080 100%); color:#fff; border:none;">
            Yes, Generate Payroll Data
          </button>
        </div>
      </div>
    </div>
  </div>

  <!-- Toast Notification -->
  <div id="payrollToast" style="position:fixed; bottom:28px; right:28px; min-width:300px; max-width:420px; z-index:99999; border-radius:14px; padding:14px 18px; font-size:13px; font-weight:600; box-shadow:0 8px 30px rgba(0,0,0,0.18); display:none; align-items:center; gap:10px;">
    <i id="pToastIcon" class="fas fa-check-circle" style="font-size:18px;"></i>
    <span id="pToastMsg">Saved.</span>
    <button onclick="$('#payrollToast').hide()" style="margin-left:auto; background:none; border:none; cursor:pointer; font-size:16px; opacity:0.6;">&#x2715;</button>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
  <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
  <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>

  <script>
    $(document).ready(function () {
      if (!$.fn.DataTable.isDataTable('#overviewTable')) {
        $('#overviewTable').DataTable({
          responsive: true,
          paging: true,
          ordering: true,
          order: [],
          searching: true,
          info: true,
          lengthChange: true,
          pageLength: 10,
          dom: "<'row'<'col-md-6'l><'col-md-6'f>>t<'row'<'col-md-6'i><'col-md-6'p>>"
        });
      }
    });
    
    function generatePayrollAttendance() {
      var btn = $('#btnRunPayroll');
      var origHtml = btn.html();
      btn.html('<i class="fas fa-spinner fa-spin mr-1"></i> Generating...').prop('disabled', true);

      $.ajax({
        url: '<?= base_url('admin/generate_payroll_attendance') ?>',
        type: 'POST',
        data: {
          month: $('select[name="month"]').val(),
          year: $('select[name="year"]').val(),
          <?= json_encode(csrf_token()) ?>: <?= json_encode(csrf_hash()) ?>
        },
        dataType: 'json',
        success: function(res) {
          $('#payrollModal').modal('hide');
          btn.html(origHtml).prop('disabled', false);

          if (res.status === 'Y') {
            showPToast(res.message || 'Attendance generated successfully.', true);
            // If originating from Step 1, navigate to the Finalization screen with s1 attached
            setTimeout(function() {
              window.location.href = '<?= $finalizeUrl ?>';
            }, 1200);
          } else {
            showPToast(res.message || 'Failed to generate attendance.', false);
          }
        },
        error: function(xhr) {
          var message = xhr.responseJSON?.message || 'Unable to generate payroll attendance.';
          showPToast(message, false);
          btn.html(origHtml).prop('disabled', false);
        }
      });
    }

    function showPToast(msg, success) {
      var $t = $('#payrollToast');
      $t.css({
        background: success ? '#d1fae5' : '#fee2e2',
        color: success ? '#065f46' : '#991b1b',
        border: success ? '1px solid #6ee7b7' : '1px solid #fca5a5'
      });
      $('#pToastMsg').text(msg);
      $('#pToastIcon').attr('class', success ? 'fas fa-check-circle' : 'fas fa-exclamation-circle');
      $t.css('display', 'flex');
      setTimeout(function(){ $t.hide(); }, 5000);
    }
  </script>
</body>
</html>