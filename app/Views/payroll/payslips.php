<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bloom Solutions | Pay Roll</title>
  
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">

  <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">

  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/toastr.js/latest/toastr.min.css">

  <style>
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
    }

    /* Card Styling */
    .card-bloom { 
      border: 1px solid var(--border-color) !important; 
      border-radius: 20px !important; 
      background: #fff; 
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.04); 
      overflow: hidden;
    }

    .avatar-list { width: 38px; height: 38px; border-radius: 10px; object-fit: cover; }

    /* Status Badges */
    .status-active { color: #10b981; background: #ecfdf5; padding: 4px 10px; border-radius: 8px; font-weight: 600; font-size: 11px; }
    .status-leave { color: #d97706; background: #fef3c7; padding: 4px 10px; border-radius: 8px; font-weight: 600; font-size: 11px; }

    /* Header & Sidebar */
    .main-header { 
      border-bottom: 1px solid #e2e8f0 !important; 
      background: rgba(255, 255, 255, 0.75) !important; 
      backdrop-filter: blur(12px); 
    }
    
   .nav-pills .nav-link.active{
background:#007bff!important;
color:#fff!important;
}


    /* Action Buttons */
    .action-btn {
      width: 30px;
      height: 30px;
      padding: 0;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border-radius: 8px !important;
      transition: all 0.2s;
      border: 1px solid var(--border-color);
      background: #fff;
    }
    .btn-view { color: var(--bloom-info); }
    .btn-edit { color: var(--bloom-purple); }
    .btn-delete { color: var(--bloom-danger); }
    
    .action-btn:hover { background: #f1f5f9; transform: translateY(-1px); }
    .btn-delete:hover { background: #fee2e2; border-color: #fecaca; }

    .employee-row:hover { background-color: #f8fafc; }

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

.emp-badge{
    display:inline-block;
    padding:6px 12px;
    border-radius:10px;
    font-size:13px;
    font-weight:600;
}

.emp-purple{
    background:#ede9fe;
    color:#5b21b6;
    border:1px solid #d8b4fe;
}

.emp-green{
    background:#ecfdf5;
    color:#059669;
    border:1px solid #a7f3d0;
}

.emp-blue{
    background:#EEF4FF;
    color:#1D4ED8;
    border:1px solid #BFDBFE;
}

.emp-magenta{
    background:#FDF2FF;
    color:#A21CAF;
    border:1px solid #6b09d4;
}

/* =========================================
   MOBILE TEXT RESPONSIVENESS
   Only reduces text size - keeps layout same
========================================= */

/* Tablet */
@media (max-width: 768px) {

    body {
        font-size: 12px;
    }

    .content {
        font-size: 12px;
    }

    h4 {
        font-size: 18px !important;
    }

    .table th {
        font-size: 10px !important;
    }

    .table td {
        font-size: 11px !important;
    }

    .emp-badge {
        font-size: 10px !important;
        padding: 4px 8px !important;
    }

    .custom-select {
        font-size: 10px !important;
    }

    .action-btn {
        width: 27px;
        height: 27px;
        font-size: 10px !important;
    }

    .dataTables_length,
    .dataTables_filter,
    .dataTables_info {
        font-size: 10px !important;
    }

    .dataTables_filter input {
        font-size: 10px !important;
    }

    .dataTables_paginate .page-link {
        font-size: 10px !important;
    }
}


/* Mobile */
@media (max-width: 576px) {

    body {
        font-size: 11px;
    }

    .content {
        padding: 10px !important;
        font-size: 11px;
    }

    h4 {
        font-size: 16px !important;
    }

    .table th {
        font-size: 9px !important;
    }

    .table td {
        font-size: 10px !important;
    }

    .emp-badge {
        font-size: 9px !important;
        padding: 3px 6px !important;
        border-radius: 7px;
    }

    .custom-select {
        font-size: 9px !important;
    }

    .action-btn {
        width: 25px;
        height: 25px;
        font-size: 9px !important;
        border-radius: 6px !important;
    }

    .dataTables_length,
    .dataTables_filter,
    .dataTables_info {
        font-size: 9px !important;
    }

    .dataTables_length select {
        font-size: 9px !important;
        height: 28px !important;
    }

    .dataTables_filter input {
        font-size: 9px !important;
        height: 28px !important;
    }

    .dataTables_paginate .page-link {
        font-size: 9px !important;
        min-width: 28px;
        height: 28px;
        padding: 4px 7px !important;
    }
}

/* Extra tight Show Entries / Search spacing */
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
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap" style="gap:10px;">
      <div>
        <h4 class="font-weight-bold mb-0">Payslips</h4>
        <small class="text-muted">Payslips of paid employees from the payroll cycles</small>
      </div>
      <div class="d-flex" style="gap:10px;">
        <select id="monthFilter" class="custom-select custom-select-sm" style="width:130px; border-radius:8px; font-weight:600;">
          <option value="ALL" <?= ($selectedMonth ?? 'ALL') === 'ALL' ? 'selected' : '' ?>>All months</option>
          <?php foreach (['January','February','March','April','May','June','July','August','September','October','November','December'] as $m): ?>
            <option value="<?= $m ?>" <?= ($selectedMonth ?? '') === $m ? 'selected' : '' ?>><?= $m ?></option>
          <?php endforeach; ?>
        </select>
        <select id="yearFilter" class="custom-select custom-select-sm" style="width:120px; border-radius:8px; font-weight:600;">
          <?php
          $fyNow = (int) date('n') >= 4 ? (int) date('Y') : (int) date('Y') - 1;
          for ($i = 0; $i < 5; $i++):
              $fy = ($fyNow - $i) . '-' . substr((string) ($fyNow - $i + 1), -2);
          ?>
            <option value="<?= $fy ?>" <?= ($selectedYear ?? '') === $fy ? 'selected' : '' ?>><?= $fy ?></option>
          <?php endfor; ?>
        </select>
      </div>
    </div>

    <div class="card-bloom">
      <div class="table-responsive">
       <table id="salaryTable" class="table table-hover mb-0">
          <thead class="bg-light">
            <tr class="small text-uppercase text-muted">
              <th class="pl-4 border-0">SL.NO</th>
              <th class="border-0">EMPLOYEE ID</th>
              <th class="border-0">EMPLOYEE NAME</th>
              <th class="border-0">DEPARTMENT</th>
              <th class="border-0">MONTH</th>
              <th class="border-0">PAYSLIP NO</th>
              <th class="border-0 text-right">NET PAY</th>
              <th class="text-right pr-4 border-0">Actions</th>
            </tr>
          </thead>
          <tbody>
<?php if (!empty($salary)) : ?>
  <?php $i = 1; $colors = ['emp-purple', 'emp-green', 'emp-blue', 'emp-magenta']; ?>
  <?php foreach ($salary as $row) : $badge = $colors[($i - 1) % 4]; ?>
            <tr>
              <td class="pl-4"><?= $i++ ?></td>
              <td><span class="emp-badge <?= $badge ?>"><?= esc($row['emp_id'] ?? '-') ?></span></td>
              <td><span class="emp-badge <?= $badge ?>"><?= esc($row['emp_name'] ?: '-') ?></span></td>
              <td><?= esc($row['department_name'] ?: '-') ?></td>
              <td class="text-nowrap" data-order="<?= (int) $row['year'] * 100 + (int) $row['month_no'] ?>"><?= esc($row['month'] . ' ' . $row['year']) ?></td>
              <td class="text-muted small text-nowrap"><?= esc($row['payslip_number'] ?? '') ?></td>
              <td class="text-right font-weight-bold text-nowrap">₹ <?= number_format((float) ($row['net_pay'] ?? 0), 2) ?></td>
              <td class="text-right pr-4">
                <a href="<?= base_url('employee/new_emp_payslip/' . rawurlencode($row['emp_id']) . '/' . (int) $row['month_no'] . '/' . (int) $row['year']) ?>"
                   class="action-btn btn-view" title="View payslip">
                  <i class="fas fa-eye"></i>
                </a>
              </td>
            </tr>
  <?php endforeach; ?>
<?php endif; ?>
          </tbody>
        
        </table>
      </div>  
    </div>

   
  </div>
</div>
  </section>
</div>

<script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>

<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>

<script src="https://cdnjs.cloudflare.com/ajax/libs/toastr.js/latest/toastr.min.js"></script>

<?php if (session()->getFlashdata('error')) : ?>
<script>
$(document).ready(function () {

    toastr.options = {
        closeButton: true,
        progressBar: true,
        positionClass: "toast-top-right",
        timeOut: 5000,
        extendedTimeOut: 1000
    };

    toastr.warning("<?= session()->getFlashdata('error'); ?>");
});
</script>
<?php endif; ?>
<script>
$('#monthFilter, #yearFilter').on('change', function () {
    window.location.href = "<?= base_url('payroll/payslips') ?>?month=" +
        encodeURIComponent($('#monthFilter').val()) + "&year=" + encodeURIComponent($('#yearFilter').val());
});
</script>
<script>
   $('#salaryTable').DataTable({
    paging: true,
    ordering: true,
    order: [],
    searching: true,
    info: true,
    lengthChange: true,
    pageLength: 10,
    language: { emptyTable: <?= json_encode(!empty($listMessage) ? $listMessage : 'No payslips found for the selected period.') ?> },
    dom: '<"top"lf>rt<"bottom"ip><"clear">'
});
</script>

</body>
</html>
