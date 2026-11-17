<?php
$selectedYear = $selectedYear ?? date('Y');
$payroll_cycles = is_array($payroll_cycles ?? null) ? $payroll_cycles : [];
?>

<!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>BloomHR | Payroll Dashboard</title>

  <link rel="stylesheet"href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
  <link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/dataTables.bootstrap4.min.css">

  <style>
    :root {
      --bloom-purple: #4a00e0;
      --bloom-dark: #120038;
      --bloom-blue: #4a8cff;
      --bloom-orange: #ff7a45;
      --bloom-success: #10b981;
      --bloom-danger: #dc2626;
      --bloom-warning: #f59e0b;
      --mtn-deep: #120038;
      --soft-gray: #f8fafc;
      --border-color: #e2e8f0;
      --text-dark: #1e293b;
      --text-muted: #64748b;
    }

    body {
      font-family: 'Plus Jakarta Sans', sans-serif;
      background-color: var(--soft-gray);
      font-size: 13px;
      color: #334155;
    }

    .content-wrapper {
      min-height: calc(100vh - 57px) !important;
      padding-bottom: 25px !important;
      background-color: var(--soft-gray);
    }

    .content {
      padding-bottom: 10px !important;
    }

    .main-footer {
      margin-top: 0 !important;
      padding: 10px 1.5rem !important;
      background: #fff !important;
      border-top: 1px solid var(--border-color) !important;
      color: #64748b;
      font-size: 12px;
    }

    .card-bloom {
      transition: transform 0.2s ease, box-shadow 0.2s ease;
      border: 1px solid var(--border-color) !important;
      border-radius: 16px !important;
      background: #fff;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.03) !important;
      margin-bottom: 1.25rem;
    }

    .card-bloom:hover {
      transform: translateY(-2px);
      box-shadow: 0 10px 20px -3px rgba(18, 0, 56, 0.06) !important;
    }

    .hero-disbursement-card {
      background: linear-gradient(135deg, var(--bloom-purple), var(--bloom-dark));
      color: #fff;
      border-radius: 16px;
      padding: 1.35rem;
      position: relative;
      overflow: hidden;
    }

    .hero-disbursement-card::after {
      content: '';
      position: absolute;
      top: -30px;
      right: -30px;
      width: 120px;
      height: 120px;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.08);
      pointer-events: none;
    }

    .pulse-dot {
      width: 8px;
      height: 8px;
      background-color: #38bdf8;
      border-radius: 50%;
      box-shadow: 0 0 8px #38bdf8;
      animation: pulseAnim 2s infinite;
    }

    @keyframes pulseAnim {

      0%,
      100% {
        opacity: 1;
        transform: scale(1);
      }

      50% {
        opacity: 0.5;
        transform: scale(1.3);
      }
    }

    .badge-soft-primary {
      background: #eef2ff;
      color: var(--bloom-purple);
    }

    .badge-soft-success {
      background: #dcfce7;
      color: #15803d;
    }

    .badge-soft-warning {
      background: #fef3c7;
      color: #b45309;
    }

    .badge-soft-info {
      background: #e0f2fe;
      color: #0369a1;
    }

    .badge-soft-danger {
      background: #fee2e2;
      color: #b91c1c;
    }

    .badge-soft-secondary {
      background: #f1f5f9;
      color: #475569;
    }

    .icon-square {
      width: 40px;
      height: 40px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 16px;
      flex-shrink: 0;
    }

    .table-custom th {
      border-top: none;
      border-bottom: 1px solid var(--border-color);
      color: #64748b;
      font-weight: 700;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      background: #f8fafc;
      padding: 12px 14px;
      white-space: nowrap;
    }

    .table-custom td {
      vertical-align: middle;
      border-top: 1px solid #f1f5f9;
      font-size: 12.5px;
      padding: 12px 14px;
    }

    .quick-link-card {
      display: flex;
      align-items: center;
      padding: 0.85rem 1rem;
      border-radius: 12px;
      background: #fff;
      border: 1px solid var(--border-color);
      text-decoration: none !important;
      color: #334155;
      transition: all 0.2s ease;
      font-weight: 600;
    }

    .quick-link-card:hover {
      background: #f8fafc;
      border-color: #cbd5e1;
      color: var(--bloom-purple);
      transform: translateX(3px);
    }

    .footer-link {
      color: var(--bloom-purple);
      font-weight: 600;
      text-decoration: none;
    }

    .cycle-search {
      border-radius: 7px !important;
      border-color: var(--border-color) !important;
      height: 32px !important;
      font-size: 12px !important;
    }

    .cycle-search:focus {
      border-color: #a78bfa !important;
      box-shadow: 0 0 0 2px rgba(74, 0, 224, 0.08) !important;
    }

    .modal-content {
      border-radius: 16px !important;
      border: none !important;
      overflow: hidden;
      box-shadow: 0 15px 40px rgba(0, 0, 0, 0.2);
    }

    .modal-header-payroll {
      background: linear-gradient(135deg, var(--bloom-purple), var(--bloom-dark));
      padding: 16px 22px;
    }

    .modal-body-payroll {
      background: #fafbfc;
    }

    .modal-input {
      border-radius: 9px !important;
      height: 40px !important;
      border-color: var(--border-color) !important;
      font-size: 13px;
    }

    .modal-input:focus {
      border-color: #a78bfa !important;
      box-shadow: 0 0 0 2px rgba(74, 0, 224, 0.08) !important;
    }

    .modal-submit {
      background: linear-gradient(135deg, var(--bloom-purple), var(--bloom-dark));
      border-radius: 8px;
      border: none;
    }

    @media (max-width: 767.98px) {
      .content-wrapper {
        padding: 10px !important;
      }

      .card-bloom {
        margin-bottom: 1rem;
      }

      .cycle-tools {
        width: 100%;
      }

      .cycle-tools .input-group {
        flex: 1;
      }
    }

    /* =========================================================
       SALARY STRUCTURE THEME & TABLE STYLING
    ========================================================= */
    .pc-card {
      background: #fff;
      border: 1px solid var(--border-color) !important;
      border-radius: 16px !important;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.03) !important;
      margin-bottom: 1.25rem;
      overflow: hidden;
      transition: transform 0.2s ease, box-shadow 0.2s ease;
    }

    .pc-card:hover {
      box-shadow: 0 10px 20px -3px rgba(18, 0, 56, 0.06) !important;
    }

    .pc-body {
      padding: 16px 20px;
    }

    .pc-btn {
      border: 1px solid var(--border-color);
      border-radius: 9px;
      background: #fff;
      color: var(--text-dark);
      padding: 7px 13px;
      font-size: 11.5px;
      font-weight: 700;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      cursor: pointer;
      text-decoration: none !important;
      transition: all 0.2s ease;
      white-space: nowrap;
    }

    .pc-btn:hover {
      background: #f1f5f9;
      color: var(--bloom-purple);
      border-color: #cbd5e1;
    }

    .pc-btn-primary {
      background: var(--bloom-purple) !important;
      border-color: var(--bloom-purple) !important;
      color: #ffffff !important;
      box-shadow: 0 3px 8px rgba(74, 0, 224, 0.2);
    }

    .pc-btn-primary:hover {
      background: var(--bloom-dark) !important;
      border-color: var(--bloom-dark) !important;
      color: #ffffff !important;
      transform: translateY(-1px);
    }

    .pc-control {
      height: 38px;
      padding: 7px 12px;
      border: 1px solid var(--border-color);
      border-radius: 9px;
      background: #fff;
      color: var(--text-dark);
      font-family: inherit;
      font-size: 12px;
      outline: none;
      transition: border-color 0.2s, box-shadow 0.2s;
    }

    .pc-control:focus {
      border-color: var(--bloom-purple);
      box-shadow: 0 0 0 3px rgba(74, 0, 224, .1);
    }

    .master-grid-container {
      position: relative;
      max-height: 480px;
      overflow-y: auto;
      overflow-x: auto;
      border-radius: 0 0 16px 16px;
    }

    .master-grid-container::-webkit-scrollbar {
      width: 6px;
      height: 6px;
    }

    .master-grid-container::-webkit-scrollbar-track {
      background: #f8fafc;
    }

    .master-grid-container::-webkit-scrollbar-thumb {
      background: #cbd5e1;
      border-radius: 4px;
    }

    .master-grid-container::-webkit-scrollbar-thumb:hover {
      background: #94a3b8;
    }

    .table-master {
      width: 100% !important;
      border-collapse: separate;
      border-spacing: 0;
      font-size: 13px;
      margin-bottom: 0 !important;
    }

    .table-master thead th {
      position: sticky;
      top: 0;
      z-index: 10;
      background: #f8fafc !important;
      color: #64748b !important;
      font-size: 11px !important;
      font-weight: 700 !important;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      padding: 10px 14px !important;
      border-top: none !important;
      border-bottom: 1px solid #e2e8f0 !important;
      white-space: nowrap;
      vertical-align: middle;
    }

    .table-master thead th .col-category {
      display: block;
      font-size: 9px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: #94a3b8;
      margin-bottom: 2px;
      line-height: 1.1;
    }

    .table-master td {
      padding: 12px 14px !important;
      vertical-align: middle !important;
      border-top: 1px solid #f1f5f9 !important;
      font-size: 12.5px;
      color: #334155;
      white-space: nowrap;
    }

    .table-master tbody tr:hover td {
      background-color: #f8fafc !important;
    }

    .cell-currency {
      text-align: right;
      font-variant-numeric: tabular-nums;
      font-weight: 600;
    }

    .cell-bold {
      font-weight: 700;
      color: var(--text-dark);
    }
  </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed">
  <div class="wrapper">
    <div class="content-wrapper">
      <section class="content pt-3">
        <div class="container-fluid px-2 px-md-3">
          <!-- Dashboard Header -->
          <div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between mb-3">
            <div>
              <div class="d-flex align-items-center gap-2 mb-1 flex-wrap">
                <span class="badge badge-soft-primary font-weight-bold px-2 py-1"
                  style="border-radius: 6px; font-size: 11px;">
                  <i class="fas fa-money-check-alt mr-1"></i>
                  Payroll Management
                </span>
                <span class="badge badge-soft-secondary font-weight-bold px-2 py-1"
                  style="border-radius: 6px; font-size: 11px;">
                  FY 2026-27
                </span>
              </div>
              <h4 class="font-weight-bold mb-0" style="color: var(--mtn-deep);">
                Payroll Operations Dashboard
              </h4>
              <small class="text-muted">
                Manage salary cycles, regularize dispatches, review 35-col master grids,
                and release payslips.
              </small>
            </div>

            <div class="d-flex align-items-center mt-2 mt-md-0 flex-wrap" style="gap: 8px;">
              <div class="btn btn-sm btn-white bg-white border font-weight-bold text-secondary px-3 py-2 shadow-sm"
                style="border-radius: 10px;">
                <i class="far fa-calendar-alt text-primary mr-2"></i>
                Active Cycle:
                <strong class="text-dark">
                  <?= !empty($activeCycle)
                    ? esc(substr((string) ($activeCycle['month_name'] ?? ''), 0, 3) . ' ' . ($activeCycle['payroll_year'] ?? ''))
                    : 'None' ?>
                </strong>
              </div>
              <div class="btn btn-sm btn-white bg-white border font-weight-bold text-secondary px-3 py-2 shadow-sm"
                style="border-radius: 10px;">
                <i class="fas fa-coins text-warning mr-2"></i>
                Currency:
                <strong class="text-dark">INR (₹)</strong>
              </div>
            </div>
          </div>

          <!-- Metrics Row -->
          <div class="row">
            <!-- Total Workforce -->
            <div class="col-lg-3 col-md-6 mb-3">
              <div class="card card-bloom h-100 p-3">
                <div class="d-flex justify-content-between align-items-center mb-2">
                  <small class="text-muted font-weight-bold text-uppercase" style="font-size: 11px;">
                    Total Workforce
                  </small>
                  <div class="icon-square text-primary" style="background: #e0e7ff; width: 36px; height: 36px;">
                    <i class="fas fa-users"></i>
                  </div>
                </div>
                <h2 class="font-weight-bold mb-1" style="color: var(--mtn-deep);">
                  122
                </h2>
                <small class="text-primary font-weight-bold">
                  <i class="fas fa-circle mr-1" style="font-size: 8px;"></i>
                  122 Active on Payroll
                </small>
              </div>
            </div>

            <!-- Current Cycle -->
            <div class="col-lg-3 col-md-6 mb-3">
              <div class="card card-bloom h-100 p-3">
                <div class="d-flex justify-content-between align-items-center mb-1">
                  <small class="text-muted font-weight-bold text-uppercase" style="font-size: 11px;">
                    Current Cycle
                  </small>
                  <span class="badge badge-soft-warning px-2 py-1 font-weight-bold">
                    IN PROGRESS
                  </span>
                </div>
                <h3 class="font-weight-bold mb-0" style="color: var(--mtn-deep);">
                  ₹ 48,25,000
                </h3>
                <small class="text-muted d-block mb-2">
                  01 Oct 2026 – 31 Oct 2026
                </small>
                <div class="d-flex justify-content-between align-items-center small border-top pt-2">
                  <span class="text-muted">
                    Attendance Lock Status
                  </span>
                  <span class="font-weight-bold text-warning">
                    96% Completed
                  </span>
                </div>
              </div>
            </div>

            <!-- Previous Cycle -->
            <div class="col-lg-3 col-md-6 mb-3">
              <div class="card card-bloom h-100 p-3">
                <div class="d-flex justify-content-between align-items-center mb-1">
                  <small class="text-muted font-weight-bold text-uppercase" style="font-size: 11px;">
                    Previous Cycle
                  </small>
                  <span class="badge badge-soft-success px-2 py-1 font-weight-bold">
                    COMPLETED
                  </span>
                </div>
                <h3 class="font-weight-bold mb-0" style="color: var(--mtn-deep);">
                  ₹ 47,80,500
                </h3>
                <small class="text-muted d-block mb-2">
                  01 Sep 2026 – 30 Sep 2026
                </small>
                <div class="border-top pt-2">
                  <small class="text-success font-weight-bold">
                    <i class="fas fa-check-circle mr-1"></i>
                    Disbursed on 01 Oct 2026
                  </small>
                </div>
              </div>
            </div>

            <!-- Initiate Cycle -->
            <div class="col-lg-3 col-md-6 mb-3">
              <div class="hero-disbursement-card h-100 d-flex flex-column justify-content-between shadow-sm">
                <div>
                  <div class="d-flex justify-content-between align-items-center mb-1">
                    <small class="text-white-50 font-weight-bold text-uppercase" style="font-size: 10px;">
                      Initiate Cycle
                    </small>
                    <span class="pulse-dot"></span>
                  </div>
                  <?php
                  $active = $activeCycle ?? [];
                  $activeLabels = [
                    'OPEN' => 'Open', 'ATTENDANCE_VERIFIED' => 'Attendance verified', 'STRUCTURE_VERIFIED' => 'Structures verified',
                    'PROCESSING' => 'Calculating', 'CALCULATED' => 'Calculated', 'APPROVED' => 'Approved', 'FINALIZED' => 'Finalized',
                    'PARTIALLY_PAID' => 'Partially paid', 'PAID' => 'Paid',
                  ];
                  ?>
                  <?php if (!empty($active)): ?>
                    <h5 class="font-weight-bold mb-1 text-white">
                      Active Cycle: <?= esc(($active['month_name'] ?? '') . ' ' . ($active['payroll_year'] ?? '')) ?>
                    </h5>
                    <p class="text-white-50 small mb-3">
                      <?= esc($active['cycle_code'] ?? '') ?> &middot;
                      <?= esc($activeLabels[strtoupper($active['cycle_status'] ?? '')] ?? ($active['cycle_status'] ?? '')) ?>.
                      Finish or delete it before starting another payroll.
                    </p>
                  <?php else: ?>
                    <h5 class="font-weight-bold mb-1 text-white">
                      No payroll in progress
                    </h5>
                    <p class="text-white-50 small mb-3">
                      Configure cycle date range &amp; start payroll processing.
                    </p>
                  <?php endif; ?>
                </div>
                <?php if (!empty($active)): ?>
                  <a href="<?= site_url('payroll/cycle/' . (int) $active['payroll_cycle_id']) ?>"
                    class="btn btn-white bg-white text-primary font-weight-bold btn-block shadow-sm py-2" style="border-radius: 10px;">
                    <i class="fas fa-play-circle mr-1"></i>
                    Continue <?= esc(($active['month_name'] ?? '') . ' ' . ($active['payroll_year'] ?? '')) ?> payroll &rarr;
                  </a>
                <?php else: ?>
                  <button type="button"
                    class="btn btn-white bg-white text-primary font-weight-bold btn-block shadow-sm py-2"
                    data-toggle="modal" data-target="#processPayrollModal" style="border-radius: 10px;">
                    <i class="fas fa-cogs mr-1"></i>
                    Process Payroll &rarr;
                  </button>
                <?php endif; ?>
              </div>
            </div>
          </div>

          <!-- Messages from the last action (create / delete) -->
          <?php $flashError = session()->getFlashdata('error'); $flashSuccess = session()->getFlashdata('success'); ?>
          <?php if (!empty($flashError)): ?>
            <div class="alert alert-danger font-weight-bold small mb-3" role="alert" style="border-radius: 10px;">
              <i class="fas fa-exclamation-triangle mr-1"></i> <?= esc($flashError) ?>
            </div>
          <?php endif; ?>
          <?php if (!empty($flashSuccess)): ?>
            <div class="alert alert-success font-weight-bold small mb-3" role="alert" style="border-radius: 10px;">
              <i class="fas fa-check-circle mr-1"></i> <?= esc($flashSuccess) ?>
            </div>
          <?php endif; ?>

          <!-- Bottom Split Row -->
          <div class="row">

            <!-- Pay Cycles History -->
            <div class="col-lg-8 mb-3">
              <div class="pc-card h-100">

                <!-- Table Header Toolbar -->
                <div class="pc-body py-3 px-3 border-bottom d-flex align-items-center justify-content-between flex-wrap"
                  style="gap: 12px; background: #ffffff;">

                  <!-- Left: Badges & Title -->
                  <div class="d-flex align-items-center flex-wrap" style="gap: 10px;">
                    <span class="badge badge-soft-primary px-3 py-2 font-weight-bold" style="border-radius: 20px; font-size: 12px;">
                      <i class="fas fa-history mr-1"></i> Pay Cycles History
                    </span>
                    <span class="badge badge-soft-success px-3 py-2 font-weight-bold" style="border-radius: 20px; font-size: 12px;">
                      <i class="fas fa-check-circle mr-1"></i> <?= count($payroll_cycles) ?> Cycles Configured
                    </span>
                  </div>

                  <!-- Right: Search Box + Year Filter (Firmly on right side of the table) -->
                  <div class="d-flex align-items-center ml-auto flex-wrap" style="gap: 10px;">

                    <!-- Quick Live Search -->
                    <div class="position-relative" style="min-width: 200px;">
                      <i class="fas fa-search position-absolute text-muted"
                        style="left: 12px; top: 50%; transform: translateY(-50%); font-size: 12px; pointer-events: none;"></i>
                      <input type="text" id="payrollCycleSearch" class="pc-control" placeholder="Search cycles..."
                        style="padding-left: 32px; padding-right: 28px; height: 38px; width: 210px; font-size: 12px;">
                      <button type="button" id="clearCycleSearch" class="btn btn-link p-0 position-absolute text-muted d-none"
                        style="right: 10px; top: 50%; transform: translateY(-50%); text-decoration: none; font-size: 12px;"
                        title="Clear search">
                        <i class="fas fa-times-circle"></i>
                      </button>
                    </div>

                    <!-- Year Filter -->
                    <form method="POST" action="<?= site_url('payroll/payroll_dashboard') ?>" id="yearFilterForm" class="m-0">
                      <?php if (function_exists('csrf_field')): ?>
                        <?= csrf_field() ?>
                      <?php endif; ?>
                      <div class="d-flex align-items-center bg-light border px-2 py-1" style="border-radius: 9px; height: 38px; gap: 6px;">
                        <label for="yearSelect" class="small font-weight-bold text-muted mb-0" style="font-size: 11px; white-space: nowrap;">
                          <i class="far fa-calendar-alt text-primary mr-1"></i> Year:
                        </label>
                        <select class="custom-select custom-select-sm border-0 bg-transparent font-weight-bold text-dark"
                          name="year" id="yearSelect" onchange="this.form.submit();"
                          style="width: 78px; height: 30px; font-size: 12px; padding: 2px 18px 2px 4px; cursor: pointer; box-shadow: none;">
                          <?php for ($y = date('Y') + 1; $y >= date('Y') - 4; $y--): ?>
                            <option value="<?= $y ?>" <?= ((int) $selectedYear === $y) ? 'selected' : '' ?>>
                              <?= $y ?>
                            </option>
                          <?php endfor; ?>
                        </select>
                      </div>
                    </form>

                  </div>

                </div>

                <!-- Table inside master-grid-container with sticky headers & scrolling -->
                <div class="master-grid-container">
                  <table id="payrollCycleTable" class="table-master table-hover mb-0">
                    <thead>
                      <tr class="table-header">
                        <th class="pl-3"><span class="col-category">Period</span>Pay Cycle</th>
                        <th><span class="col-category">Timeline</span>Date Range</th>
                        <th><span class="col-category">Coverage</span>Employees</th>
                        <th class="cell-currency"><span class="col-category" style="color: #15803d;">Disbursement</span>Total Payout</th>
                        <th><span class="col-category">Lifecycle</span>Status</th>
                        <th class="text-center no-sort pr-3"><span class="col-category">Action</span>Actions</th>
                      </tr>
                    </thead>

                    <tbody>
                      <?php if (!empty($payroll_cycles)): ?>
                        <?php foreach ($payroll_cycles as $cycle): ?>
                          <?php
                          $monthNum = str_pad(
                            $cycle['payroll_month'] ?? '0',
                            2,
                            '0',
                            STR_PAD_LEFT
                          );

                          $cycleStatus = strtoupper(
                            trim($cycle['cycle_status'] ?? 'OPEN')
                          );

                          $runStatus = strtoupper(
                            trim($cycle['run_status'] ?? 'DRAFT')
                          );

                          $startDate = !empty($cycle['period_start'])
                            ? date('d M Y', strtotime($cycle['period_start']))
                            : '-';

                          $endDate = !empty($cycle['period_end'])
                            ? date('d M Y', strtotime($cycle['period_end']))
                            : '-';

                          $netPayValue = (float) ($cycle['total_net_pay'] ?? 0);
                          $netPay = number_format($netPayValue, 2);
                          $employees = (int) ($cycle['total_employees'] ?? 0);
                          ?>
                          <tr>
                            <!-- Pay Cycle -->
                            <td class="pl-3">
                              <div class="d-flex align-items-center">
                                <span class="badge badge-light border font-weight-bold <?= ($cycleStatus === 'OPEN') ? 'text-primary' : 'text-secondary' ?> mr-2 px-2 py-1" style="border-radius: 6px;">
                                  <?= esc($monthNum) ?>
                                </span>
                                <div>
                                  <strong class="text-dark d-block" style="font-size: 13px;">
                                    <?= esc($cycle['month_name'] ?? '') ?> <?= esc($cycle['payroll_year'] ?? '') ?>
                                  </strong>
                                  
                                </div>
                              </div>
                            </td>

                            <!-- Date Range -->
                            <td>
                              <span class="text-dark font-weight-bold d-block" style="font-size: 12px;">
                                <?= esc($startDate) ?> &ndash; <?= esc($endDate) ?>
                              </span>
                              <!-- <?php if (!empty($cycle['payment_date'])): ?>
                                <small class="text-muted" style="font-size: 11px;">
                                  <i class="far fa-credit-card mr-1"></i>Pay Date: <?= date('d M Y', strtotime($cycle['payment_date'])) ?>
                                </small>
                              <?php endif; ?> -->
                            </td>

                            <!-- Employees -->
                            <td>
                              <span class="badge badge-light border font-weight-bold px-2 py-1 text-dark" style="border-radius: 6px; font-size: 12px;">
                                <i class="fas fa-users text-muted mr-1"></i> <?= esc($employees) ?>
                              </span>
                            </td>

                            <!-- Total Payout -->
                            <td class="cell-currency">
                              <strong class="d-block text-dark font-weight-bold" style="font-size: 13px;">
                                ₹ <?= esc($netPay) ?>
                              </strong>
                              <!-- <?php if ($runStatus === 'PAID' || $cycleStatus === 'CLOSED'): ?>
                                <small class="text-success font-weight-bold">
                                  <i class="fas fa-check-circle mr-1"></i>Fully Disbursed
                                </small>
                              <?php elseif ($netPayValue > 0): ?>
                                <small class="text-primary font-weight-bold">
                                  <i class="fas fa-check mr-1"></i>Net Calculated
                                </small>
                              <?php else: ?>
                                <small class="text-muted">
                                  Draft Ledger
                                </small>
                              <?php endif; ?> -->
                            </td>

                            <!-- Status -->
                            <td>
                              <?php
                              $statusStyles = [
                                'OPEN'                => ['badge-soft-primary', 'fa-folder-open', 'Open'],
                                'ATTENDANCE_VERIFIED' => ['badge-soft-primary', 'fa-user-check', 'Attendance verified'],
                                'STRUCTURE_VERIFIED'  => ['badge-soft-primary', 'fa-sitemap', 'Structures verified'],
                                'PROCESSING'          => ['badge-soft-warning', 'fa-spinner', 'Calculating'],
                                'CALCULATED'          => ['badge-soft-warning', 'fa-calculator', 'Calculated'],
                                'APPROVED'            => ['badge-soft-info', 'fa-thumbs-up', 'Approved'],
                                'FINALIZED'           => ['badge-soft-info', 'fa-lock', 'Finalized'],
                                'PARTIALLY_PAID'      => ['badge-soft-danger', 'fa-pause-circle', 'Partially paid'],
                                'PAID'                => ['badge-soft-success', 'fa-check-circle', 'Paid'],
                                'CLOSED'              => ['badge-soft-secondary', 'fa-archive', 'Closed'],
                              ];
                              [$badgeClass, $badgeIcon, $badgeText] = $statusStyles[$cycleStatus] ?? ['badge-soft-secondary', 'fa-circle', $cycleStatus];
                              $onHold = (int) ($cycle['on_hold_count'] ?? 0);
                              ?>
                              <span class="badge <?= $badgeClass ?> px-2 py-1 font-weight-bold" style="border-radius: 6px;">
                                <i class="fas <?= $badgeIcon ?> mr-1"></i> <?= esc($badgeText) ?>
                              </span>
                              <?php if ($onHold > 0): ?>
                                <small class="d-block text-danger font-weight-bold mt-1"><?= $onHold ?> on hold</small>
                              <?php endif; ?>
                            </td>

                            <!-- Actions -->
                            <td class="text-center pr-3">
                              <a href="<?= site_url('payroll/cycle/' . (int) ($cycle['payroll_cycle_id'] ?? 0)) ?>"
                                class="pc-btn <?= $cycleStatus === 'CLOSED' ? '' : 'pc-btn-primary' ?>">
                                <i class="fas <?= $cycleStatus === 'CLOSED' ? 'fa-eye text-primary' : 'fa-cogs' ?>"></i>
                                <?= $cycleStatus === 'CLOSED' ? 'View' : 'Process' ?>
                              </a>
                              <?php if (in_array($cycleStatus, \App\Models\PayrollCycleModel::DELETABLE, true)): ?>
                                <button type="button" class="pc-btn mt-1 btn-delete-cycle" style="color:#b91c1c;border-color:#fecaca;"
                                  data-id="<?= (int) ($cycle['payroll_cycle_id'] ?? 0) ?>"
                                  data-name="<?= esc(($cycle['month_name'] ?? '') . ' ' . ($cycle['payroll_year'] ?? ''), 'attr') ?>"
                                  data-code="<?= esc($cycle['cycle_code'] ?? '', 'attr') ?>">
                                  <i class="fas fa-trash-alt"></i> Delete
                                </button>
                              <?php endif; ?>
                              <?php if (in_array($cycleStatus, ['FINALIZED', 'PARTIALLY_PAID', 'PAID', 'CLOSED'], true)): ?>
                                <a href="<?= site_url('payroll/payroll_summary') ?>?month=<?= esc($cycle['payroll_month'] ?? '') ?>&year=<?= esc($cycle['payroll_year'] ?? '') ?>"
                                  class="pc-btn mt-1">
                                  <i class="fas fa-file-invoice text-primary"></i> Summary
                                </a>
                              <?php endif; ?>
                            </td>
                          </tr>
                        <?php endforeach; ?>
                      <?php endif; ?>
                    </tbody>
                  </table>
                </div>

                <!-- Footer: Showing entries (Show Entities) -->
                <!-- <div class="pc-body py-2 px-3 border-top d-flex align-items-center justify-content-between flex-wrap"
                  style="gap: 10px; background: #ffffff;">
                  <div id="payrollTableInfo" class="text-muted font-weight-bold" style="font-size: 12px;"></div>
                  <div class="small text-muted d-flex align-items-center" style="gap: 8px;">
                    <span class="badge badge-soft-secondary font-weight-bold px-3 py-1" style="border-radius: 12px;">
                      <i class="fas fa-layer-group mr-1 text-primary"></i> <?= count($payroll_cycles) ?> Total Entries
                    </span>
                  </div>
                </div> -->
              </div>
            </div>

            <!-- Right Column -->
            <div class="col-lg-4 mb-3">
              <!-- Generate Payslips -->
              <div class="p-3 mb-3 text-white d-flex align-items-center justify-content-between shadow-sm"
                style="background: linear-gradient(135deg, var(--bloom-purple), var(--bloom-dark)); border-radius: 16px;">
                <div class="d-flex align-items-center">
                  <div class="icon-square text-primary bg-white rounded-circle mr-3" style="width: 42px; height: 42px;">
                    <i class="fas fa-file-invoice"></i>
                  </div>
                  <div>
                    <h6 class="font-weight-bold mb-0 text-white">
                      Generate Payslips
                      <span class="badge badge-light text-primary font-weight-bold ml-1" style="font-size: 10px;">
                        BATCH
                      </span>
                    </h6>

                    <small class="text-white-50">
                      Batch release for eligible employees
                    </small>
                  </div>
                </div>

                <a href="<?= base_url('payroll/payslips') ?>"
                  class="btn btn-sm btn-white bg-white text-primary rounded-circle p-2" title="Go to Batch Dispatch">
                  <i class="fas fa-arrow-right"></i>
                </a>
              </div>

              <!-- Payroll Tools -->
              <div class="card card-bloom p-3">
                <h6 class="font-weight-bold mb-3" style="color: var(--mtn-deep);">
                  <i class="fas fa-bolt text-warning mr-2"></i>
                  Payroll Navigation &amp; Tools
                </h6>

                <div class="d-flex flex-column" style="gap: 8px;">
                  <!-- Salary Components -->
                  <a href="<?= base_url('payroll/salary_components') ?>" class="quick-link-card shadow-sm">
                    <div class="icon-square text-primary mr-3" style="background: #e0e7ff; width: 36px; height: 36px;">
                      <i class="fas fa-layer-group"></i>
                    </div>

                    <div class="flex-grow-1">
                      <div class="font-weight-bold">
                        Salary Components Master
                      </div>
                      <small class="text-muted">
                        Earnings, deductions &amp; formulas
                      </small>
                    </div>
                    <i class="fas fa-chevron-right text-muted small"></i>
                  </a>

                  <!-- Salary Structure -->
                  <a href="<?= base_url('payroll/salary_structure') ?>" class="quick-link-card shadow-sm">
                    <div class="icon-square text-info mr-3" style="background: #e0f2fe; width: 36px; height: 36px;">
                      <i class="fas fa-sitemap"></i>
                    </div>
                    <div class="flex-grow-1">
                      <div class="font-weight-bold">
                        Salary Structures &amp; CTC
                      </div>
                      <small class="text-muted">
                        Band structures &amp; employee assignments
                      </small>
                    </div>
                    <i class="fas fa-chevron-right text-muted small"></i>
                  </a>

                  <!-- Attendance -->
                  <a href="<?= base_url('admin/attendance_overview') ?>" class="quick-link-card shadow-sm">
                    <div class="icon-square text-success mr-3" style="background: #dcfce7; width: 36px; height: 36px;">
                      <i class="fas fa-calendar-check"></i>
                    </div>

                    <div class="flex-grow-1">
                      <div class="font-weight-bold">
                        Payroll Attendance
                      </div>
                      <small class="text-muted">
                        Biometric logs, LOPs &amp; attendance status
                      </small>
                    </div>
                    <i class="fas fa-chevron-right text-muted small"></i>
                  </a>

                  <!-- Payslips -->
                  <a href="<?= base_url('payroll/payslips_new') ?>" class="quick-link-card shadow-sm">
                    <div class="icon-square mr-3"
                      style="background: #eef2ff; color: var(--bloom-purple); width: 36px; height: 36px;">
                      <i class="fas fa-file-invoice-dollar"></i>
                    </div>
                    <div class="flex-grow-1">
                      <div class="font-weight-bold">
                        Payslips
                      </div>
                      <small class="text-muted">
                        Employee payslips vault &amp; batch release
                      </small>
                    </div>
                    <i class="fas fa-chevron-right text-muted small"></i>
                  </a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>


  <!-- =========================================================
     PROCESS PAYROLL MODAL
========================================================= -->

  <div class="modal fade" id="processPayrollModal" tabindex="-1" role="dialog"
    aria-labelledby="processPayrollModalLabel" aria-hidden="true">

    <div class="modal-dialog modal-dialog-centered" role="document" style="max-width: 540px;">
      <div class="modal-content">
        <!-- Modal Header -->
        <div class="modal-header d-flex justify-content-between align-items-center modal-header-payroll">
          <h5 class="modal-title font-weight-bold text-white d-flex align-items-center mb-0"
            id="processPayrollModalLabel" style="font-size: 16px;">
            <i class="fas fa-cogs mr-2"></i>
            Process Payroll Cycle
          </h5>
          <button type="button" class="close text-white" data-dismiss="modal" aria-label="Close" style="opacity: 0.9;">
            <span aria-hidden="true">
              &times;
            </span>
          </button>
        </div>

        <!-- Form -->
        <form action="<?= site_url('payroll/create_payroll_cycle') ?>" method="POST" id="processPayrollForm">
  <div class="modal-body p-4 modal-body-payroll">

    <!-- Information -->
    <div class="p-3 mb-3 border rounded"
      style="background:#ffffff;border-radius:12px !important;border-color:var(--border-color) !important;">
      <div class="d-flex align-items-center">
        <div class="icon-square text-primary mr-3"
          style="background:#eef2ff;width:38px;height:38px;border-radius:10px;">
          <i class="fas fa-calendar-alt"></i>
        </div>

        <div>
          <strong class="d-block text-dark" style="font-size:13px;">
            Initiate Payroll Cycle
          </strong>
          <small class="text-muted">
            Define cycle parameters to generate the ledger
            and proceed to Step 1 Attendance.
          </small>
        </div>
      </div>
    </div>

    <!-- Month / Year -->
    <div class="row">
      <div class="col-sm-6 mb-3">
        <label class="font-weight-bold small text-muted mb-1">
          Month
          <span class="text-danger">*</span>
        </label>

        <select
          class="form-control custom-select font-weight-bold modal-input"
          id="modalCycleMonth"
          name="month"
          onchange="syncCycleDates()"
          required>

          <?php for ($m = 1; $m <= 12; $m++): ?>
            <option value="<?= $m ?>" <?= ($m == date('n')) ? 'selected' : '' ?>>
              <?= date('F', mktime(0, 0, 0, $m, 1)) ?>
            </option>
          <?php endfor; ?>

        </select>
      </div>

      <div class="col-sm-6 mb-3">
        <label class="font-weight-bold small text-muted mb-1">
          Year
          <span class="text-danger">*</span>
        </label>

        <select
          class="form-control custom-select font-weight-bold modal-input"
          id="modalCycleYear"
          name="year"
          onchange="syncCycleDates()"
          required>

          <?php for ($y = date('Y') + 1; $y >= date('Y') - 4; $y--): ?>
            <option value="<?= $y ?>" <?= ($y == date('Y')) ? 'selected' : '' ?>>
              <?= $y ?>
            </option>
          <?php endfor; ?>

        </select>
      </div>
    </div>

    <!-- From / To -->
    <div class="row">
      <div class="col-sm-6 mb-3">
        <label class="font-weight-bold small text-muted mb-1">
          From Date
          <span class="text-danger">*</span>
        </label>

        <input
          type="date"
          class="form-control font-weight-bold modal-input"
          id="modalFromDate"
          name="from_date"
          required>
      </div>

      <div class="col-sm-6 mb-3">
        <label class="font-weight-bold small text-muted mb-1">
          To Date
          <span class="text-danger">*</span>
        </label>

        <input
          type="date"
          class="form-control font-weight-bold modal-input"
          id="modalToDate"
          name="to_date"
          required>
      </div>
    </div>

    <!-- Pay Date -->
    <div class="mb-3">
      <label class="font-weight-bold small text-muted mb-1">
        Pay Date
        <span class="badge badge-light border text-muted ml-1" style="font-size:10px;">
          Optional
        </span>
      </label>

      <input
        type="date"
        class="form-control font-weight-bold modal-input"
        id="modalPayDate"
        name="pay_date">
    </div>

    <!-- Cycle Code -->
    <div class="mb-3">
      <label class="font-weight-bold small text-muted mb-1 d-flex justify-content-between align-items-center">
        <span>
          Cycle Code
          <span class="text-danger">*</span>
        </span>

        <small
          class="text-primary font-weight-bold"
          style="cursor:pointer;"
          onclick="calculateCycleCode()">
          <i class="fas fa-sync-alt mr-1"></i>
          Auto-Generate
        </small>
      </label>

      <div class="input-group">
        <div class="input-group-prepend">
          <span
            class="input-group-text bg-light text-muted"
            style="border-radius:9px 0 0 9px;border-color:var(--border-color);">
            <i class="fas fa-barcode"></i>
          </span>
        </div>

        <input
          type="text"
          class="form-control font-weight-bold"
          id="modalCycleCode"
          name="cycle_code"
          required
          style="border-radius:0 9px 9px 0;font-family:monospace;font-size:13.5px;color:var(--bloom-purple);background:#ffffff;">
      </div>

      <small class="text-muted mt-1 d-block">
        Cycle format:
        <span class="text-dark font-weight-bold">
          pay-ddmm-ddmm-yyyy
        </span>
        <span class="ml-1">
          (e.g., pay-0110-3010-2026)
        </span>
      </small>
    </div>

    <!-- Remarks -->
    <div class="mb-2">
      <label class="font-weight-bold small text-muted mb-1">
        Remarks
        <span class="badge badge-light border text-muted ml-1" style="font-size:10px;">
          Optional
        </span>
      </label>

      <textarea
        class="form-control"
        id="modalRemarks"
        name="remarks"
        rows="2"
        placeholder="Optional notes, cutoff dates, or attendance adjustments..."
        style="border-radius:9px;font-size:12.5px;"></textarea>
    </div>

  </div>

  <!-- Footer -->
  <div class="modal-footer bg-white border-top d-flex justify-content-between px-4 py-3">

    <button
      type="button"
      class="btn btn-light border px-3 font-weight-bold text-muted"
      data-dismiss="modal"
      style="border-radius:8px;">
      Cancel
    </button>

    <button
      type="submit"
      class="btn text-white px-4 py-2 font-weight-bold shadow-sm modal-submit">
      Submit &amp; Proceed to Step 1
      <i class="fas fa-arrow-right ml-1"></i>
    </button>

  </div>
</form>
      </div>
    </div>
  </div>


 <?= view('payroll/_dialog') ?>
 <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
  <script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
  <script src="https://cdn.datatables.net/1.13.8/js/dataTables.bootstrap4.min.js"></script>

  <script>
    jQuery.extend(jQuery.fn.dataTableExt.oSort, {
      "currency-pre": function (a) {
        if (!a) return 0;
        var clean = a.replace(/<[^>]*>/g, '').replace(/[^\d\.\-]/g, '').trim();
        return clean === '' ? 0 : parseFloat(clean);
      },
      "currency-asc": function (a, b) {
        return a - b;
      },
      "currency-desc": function (a, b) {
        return b - a;
      }
    });

    $(document).ready(function () {
      var payrollDt = $('#payrollCycleTable').DataTable({
        responsive: false,
        paging: false,
        ordering: true,
        order: [],
        searching: true,
        info: true,
        lengthChange: false,
        dom: 'rt',
        columnDefs: [
          { type: 'currency', targets: 3 },
          { orderable: false, targets: 5 }
        ],
        language: {
          search: "",
          searchPlaceholder: "Search cycles...",
          info: "Showing _TOTAL_ entries",
          infoEmpty: "Showing 0 entries",
          infoFiltered: "(filtered from _MAX_ total entries)",
          zeroRecords: "No matching payroll cycles found",
          emptyTable: "No payroll cycles found for <?= esc($selectedYear) ?>"
        },
        drawCallback: function (settings) {
          var api = this.api();
          var pageInfo = api.page.info();
          var infoText = '';
          if (pageInfo.recordsDisplay === 0) {
            infoText = 'Showing 0 entries';
          } else if (pageInfo.recordsDisplay === pageInfo.recordsTotal) {
            infoText = 'Showing all ' + pageInfo.recordsTotal + ' entries';
          } else {
            infoText = 'Showing ' + pageInfo.recordsDisplay + ' of ' + pageInfo.recordsTotal + ' entries (filtered)';
          }
          $('#payrollTableInfo').html('<i class="fas fa-info-circle mr-1 text-primary"></i> ' + infoText);
        }
      });

      // Synchronize Live Search input
      $('#payrollCycleSearch').on('keyup input', function () {
        payrollDt.search(this.value).draw();
        $('#clearCycleSearch').toggleClass('d-none', !this.value);
      });

      $('#clearCycleSearch').on('click', function () {
        $('#payrollCycleSearch').val('').trigger('input').focus();
      });

      $('#payrollCycleSearch').on('keydown', function (e) {
        if (e.key === 'Escape') {
          $(this).val('').trigger('input');
        }
      });

      // Initialize default dates on page ready
      syncCycleDates();
    });

    function pad2(number) {
      return String(number).padStart(2, '0');
    }

    /*
    |--------------------------------------------------------------------------
    | Generate Cycle Code (Format: pay-ddmm-ddmm-yyyy)
    |--------------------------------------------------------------------------
    */
    function calculateCycleCode() {
      const fromVal = document.getElementById('modalFromDate').value;
      const toVal = document.getElementById('modalToDate').value;

      if (!fromVal || !toVal) {
        return;
      }

      const fromParts = fromVal.split('-');
      const toParts = toVal.split('-');

      if (fromParts.length !== 3 || toParts.length !== 3) {
        return;
      }

      const fromDDMM = fromParts[2] + fromParts[1];
      const toDDMM   = toParts[2] + toParts[1];
      const year     = toParts[0]; // Cycle belongs to the target payroll year

      document.getElementById('modalCycleCode').value =
        `pay-${fromDDMM}-${toDDMM}-${year}`;
    }

    /*
    |--------------------------------------------------------------------------
    | Sync Month / Year With Dates: pay period from company settings
    |--------------------------------------------------------------------------
    */
    function syncCycleDates() {
      const monthSelect = document.getElementById('modalCycleMonth');
      const yearSelect  = document.getElementById('modalCycleYear');

      if (!monthSelect || !yearSelect) return;

      const selectedMonth = parseInt(monthSelect.value, 10);
      const selectedYear  = parseInt(yearSelect.value, 10);

      if (!selectedMonth || !selectedYear) return;

      // Pay period, payment date and code come from the company settings
      // (payroll cycle start day, end day and salary pay day).
      fetch('<?= site_url('payroll/cycle_defaults') ?>?month=' + selectedMonth + '&year=' + selectedYear,
            { headers: { 'X-Requested-With': 'XMLHttpRequest' } })
        .then(function (res) { return res.json(); })
        .then(function (res) {
          if (!res.status || !res.data) return;
          document.getElementById('modalFromDate').value = res.data.period_start || '';
          document.getElementById('modalToDate').value   = res.data.period_end || '';
          const payDate = document.getElementById('modalPayDate');
          if (payDate) payDate.value = res.data.payment_date || '';
          calculateCycleCode();
        })
        .catch(function () { calculateCycleCode(); });
    }

    /*
    |--------------------------------------------------------------------------
    | Process Payroll Modal Handlers
    |--------------------------------------------------------------------------
    */
    $('#processPayrollModal').on('show.bs.modal', function (event) {
      const button   = $(event.relatedTarget);
      const month    = button.data('month');
      const year     = button.data('year');
      const fromDate = button.data('from');
      const toDate   = button.data('to');

      if (month && year) {
        $('#modalCycleMonth').val(String(parseInt(month, 10)));
        $('#modalCycleYear').val(String(year));

        if (fromDate && toDate) {
          $('#modalFromDate').val(fromDate);
          $('#modalToDate').val(toDate);
          calculateCycleCode();
        } else {
          syncCycleDates();
        }
      } else {
        syncCycleDates();
      }
    });

    /*
    |--------------------------------------------------------------------------
    | Prevent Invalid Date Range & Recalculate Code on Manual Date Edits
    |--------------------------------------------------------------------------
    */
    /*
    |--------------------------------------------------------------------------
    | Delete a payroll cycle (only cycles that are not finalized; the
    | procedure hrms_payroll_cycle_delete checks the rules again)
    |--------------------------------------------------------------------------
    */
    $(document).on('click', '.btn-delete-cycle', async function () {
      const btn = $(this);
      const name = btn.data('name');
      // in-page popup box (no browser prompt / confirm / alert)
      const del = await payrollDialog.ask({
        title: 'Delete payroll ' + name,
        message: 'Cycle ' + btn.data('code') + ' and its calculated employee results are removed. ' +
                 'Attendance, salary structures and manual amounts are kept. This cannot be undone.\n\n' +
                 'The month can be created again afterwards.',
        input: { label: 'Reason', required: true, multiline: true, placeholder: 'Why is this payroll deleted?' },
        okText: 'Delete payroll', danger: true
      });
      if (!del.ok) return;

      const fd = new FormData();
      fd.append('cycle_id', btn.data('id'));
      fd.append('reason', del.value);
      const csrf = document.querySelector('input[name="<?= csrf_token() ?>"]');
      if (csrf) fd.append('<?= csrf_token() ?>', csrf.value);
      btn.prop('disabled', true);
      fetch('<?= site_url('payroll/cycle_delete') ?>', { method: 'POST', body: fd, headers: { 'X-Requested-With': 'XMLHttpRequest' } })
        .then(function (res) { return res.json(); })
        .then(async function (res) {
          await payrollDialog.message({ title: res.status ? 'Payroll deleted' : 'Not deleted',
                                        message: res.message || (res.status ? 'Deleted.' : 'Not deleted.'), danger: !res.status });
          if (res.status) window.location.reload(); else btn.prop('disabled', false);
        })
        .catch(async function (e) {
          await payrollDialog.message({ title: 'Not deleted', message: 'The payroll cycle could not be deleted: ' + e.message, danger: true });
          btn.prop('disabled', false);
        });
    });

    $('#modalFromDate, #modalToDate').on('change', function () {
      const from = $('#modalFromDate').val();
      const to   = $('#modalToDate').val();

      if (from && to && to < from) {
        $('#modalToDate').val(from);
      }
      calculateCycleCode();
    });
  </script>
</body>
</html>