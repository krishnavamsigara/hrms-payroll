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
      'payroll/manage_sal_comp' => 'payroll/manage_sal_comp',
    ];
    return $map[$path] ?? $path;
  }
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>BloomHR | Salary Component Master</title>
  <?php if (function_exists('csrf_token') && function_exists('csrf_hash')): ?>
    <meta name="csrf-token-name" content="<?= csrf_token() ?>">
    <meta name="csrf-token-hash" content="<?= csrf_hash() ?>">
  <?php endif; ?>

  <!-- Google Font: Plus Jakarta Sans -->
  <link rel="stylesheet"
    href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
  <!-- Font Awesome -->
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <!-- AdminLTE 3 -->
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
  <!-- DataTables Bootstrap 4 -->
  <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/toastr.js/latest/toastr.min.css">

  <style>
    .toast-top-right {
      top: 24px !important;
      right: 24px !important;
      z-index: 999999 !important;
    }

    #toast-container > div {
      opacity: 1 !important;
      border-radius: 12px !important;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.25) !important;
      font-family: 'Plus Jakarta Sans', sans-serif !important;
      font-size: 13px !important;
      padding: 15px 15px 15px 50px !important;
    }

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
      padding-bottom: 30px !important;
      background-color: var(--soft-gray);
    }

    /* CARD STYLING */
    .card-bloom {
      transition: transform 0.2s ease, box-shadow 0.2s ease;
      border: 1px solid var(--border-color) !important;
      border-radius: 16px !important;
      background: #fff;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.03) !important;
      margin-bottom: 1.25rem;
    }

    .card-bloom:hover {
      box-shadow: 0 10px 20px -3px rgba(18, 0, 56, 0.06) !important;
    }

    /* BUTTONS */
    .pc-btn {
      border: 1px solid var(--border-color);
      border-radius: 9px;
      background: #ffffff;
      color: #334155;
      padding: 8px 14px;
      font-size: 12px;
      font-weight: 700;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 7px;
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
    }

    .pc-btn-success {
      background: var(--bloom-success) !important;
      border-color: var(--bloom-success) !important;
      color: #ffffff !important;
    }

    .pc-btn-success:hover {
      background: #059669 !important;
      color: #ffffff !important;
    }

    /* BADGES */
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

    .badge-soft-danger {
      background: #fee2e2;
      color: #b91c1c;
    }

    .badge-soft-secondary {
      background: #f1f5f9;
      color: #475569;
    }

    .badge-soft-info {
      background: #e0f2fe;
      color: #0369a1;
    }

    /* TABLE - MATCHING STEP 2 THEME */
    .table-custom {
      width: 100%;
      border-collapse: separate;
      border-spacing: 0;
      margin-bottom: 0;
    }

    .table-custom thead {
      background: #f8fafc;
    }

    .table-custom thead th {
      border: none;
      border-bottom: 1px solid #e2e8f0;
      color: #64748b;
      font-size: 11px;
      text-transform: uppercase;
      font-weight: 700;
      padding: 13px 16px;
      letter-spacing: 0.5px;
      white-space: nowrap;
      vertical-align: middle;
      background: #f8fafc;
    }

    .table-custom tbody tr {
      transition: background-color 0.15s ease;
    }

    .table-custom tbody tr:hover {
      background-color: #f8fafc;
    }

    .table-custom tbody td {
      vertical-align: middle !important;
      border-top: 1px solid #f1f5f9;
      font-size: 13px;
      padding: 13px 16px;
      color: #334155;
      white-space: nowrap;
    }

    /* DATATABLES - MATCHING STEP 2 THEME */
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

    /* Pagination Styling from Step 2 Theme */
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

    /* WORKFLOW ACTION BAR - SCROLLS WITH PAGE CONTENT */
    .pc-bottom-bar {
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

    .pc-bottom-bar:hover {
      box-shadow: 0 10px 20px -3px rgba(18, 0, 56, 0.06) !important;
    }

    /* MODAL */
    .modal-overlay {
      position: fixed;
      inset: 0;
      background: rgba(18, 0, 56, 0.6);
      backdrop-filter: blur(4px);
      z-index: 9999;
      display: none;
      align-items: center;
      justify-content: center;
      padding: 15px;
    }

    .modal-card {
      background: #ffffff;
      border-radius: 16px;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2);
      width: 100%;
      max-width: 640px;
      overflow: hidden;
      animation: modalFadeIn 0.2s ease-out;
    }

    @keyframes modalFadeIn {
      from {
        opacity: 0;
        transform: scale(0.96);
      }

      to {
        opacity: 1;
        transform: scale(1);
      }
    }

    .modal-header-bloom {
      background: linear-gradient(135deg, var(--bloom-purple), var(--bloom-dark));
      color: #ffffff;
      padding: 16px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }

    /* FORM CONTROLS */
    .form-control-bloom {
      border-radius: 8px;
      border: 1px solid var(--border-color);
      padding: 8px 12px;
      font-size: 12.5px;
      color: var(--text-dark);
      background-color: #ffffff;
      transition: border-color 0.2s ease, box-shadow 0.2s ease;
      width: 100%;
    }

    .form-control-bloom:focus {
      outline: none;
      border-color: var(--bloom-purple);
      box-shadow: 0 0 0 3px rgba(74, 0, 224, 0.12);
    }

    @media (max-width: 767.98px) {
      .content-wrapper {
        padding: 10px !important;
        padding-bottom: 120px !important;
      }

      .pc-bottom-bar {
        position: sticky;
        left: 0;
        bottom: 0;
        flex-direction: column;
        align-items: stretch;
        margin-top: 20px;
        border-radius: 12px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06);
      }

      .pc-bottom-bar .d-flex {
        width: 100%;
        justify-content: stretch;
      }

      .pc-bottom-bar .pc-btn {
        flex: 1;
      }
    }
  </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed">
  <div class="wrapper">

    <!-- Content Wrapper -->
    <div class="content-wrapper">
      <section class="content pt-3">
        <div class="container-fluid px-2 px-md-3">

          <!-- Header Section with Direct Actions -->
          <div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between mb-3"
            style="gap: 12px;">
            <div class="d-flex align-items-center gap-3">
              <div class="d-flex align-items-center justify-content-center text-white shadow-sm"
                style="width: 44px; height: 44px; border-radius: 12px; background: linear-gradient(135deg, var(--bloom-purple), var(--bloom-dark)); font-size: 20px;">
                <i class="fas fa-calculator"></i>
              </div>
              <div>
                <div class="d-flex align-items-center gap-2 flex-wrap">
                  <h4 class="font-weight-bold mb-1" style="color: var(--mtn-deep);">Salary Component Master</h4>
                </div>
              </div>
            </div>

            <div class="d-flex align-items-center gap-2 flex-wrap">
              <a href="<?= base_url('payroll/payroll_dashboard') ?>" class="pc-btn shadow-sm">
                <i class="fas fa-arrow-left text-muted"></i> Dashboard
              </a>
              <a href="<?= base_url('payroll/salary_structure') ?>" class="pc-btn shadow-sm">
                <i class="fas fa-sitemap text-primary"></i> View Salary Structures
              </a>
              <button class="pc-btn pc-btn-primary" id="btnOpenAddModal" type="button">
                <i class="fas fa-plus-circle"></i> Add New Component
              </button>
            </div>
          </div>

          <!-- RULE CHECK: hrms_component_rules_check over every component (errors / warnings / info) -->
          <?php
          $ruleRows = $component_findings ?? [];
          $ruleCount = ['ERROR' => 0, 'WARNING' => 0, 'INFO' => 0];
          foreach ($ruleRows as $f) { $ruleCount[$f['level']] = ($ruleCount[$f['level']] ?? 0) + 1; }
          $ruleClean = $ruleCount['ERROR'] === 0 && $ruleCount['WARNING'] === 0;
          ?>
          <div class="card-custom mb-3 p-3" id="ruleCheckPanel"
               style="border-left: 4px solid <?= $ruleCount['ERROR'] ? '#dc2626' : ($ruleCount['WARNING'] ? '#d97706' : '#059669') ?>; border-radius: 0;">
            <div class="d-flex align-items-center justify-content-between flex-wrap" style="gap: 8px;">
              <div class="font-weight-bold" style="color: var(--mtn-deep);">
                <i class="fas <?= $ruleClean ? 'fa-check-circle text-success' : 'fa-exclamation-triangle text-warning' ?> mr-1"></i>
                Rule check:
                <?php if ($ruleClean): ?>
                  every component, slab and total is consistent
                <?php else: ?>
                  <?= $ruleCount['ERROR'] ?> error(s), <?= $ruleCount['WARNING'] ?> warning(s)
                <?php endif; ?>
              </div>
              <?php if ($ruleRows): ?>
                <button type="button" class="pc-btn" id="btnToggleRules" style="padding: 3px 10px; font-size: 12px;">
                  <i class="fas fa-list mr-1"></i> <span>Show details (<?= count($ruleRows) ?>)</span>
                </button>
              <?php endif; ?>
            </div>
            <div class="small text-muted mt-1">
              Checked: names used are active, calculation order, slab ranges, gaps and dates, totals, and payroll months still to be calculated.
            </div>
            <ul class="mb-0 mt-2 pl-3 small" id="ruleCheckList" style="display: <?= $ruleClean ? 'none' : 'block' ?>;">
              <?php foreach ($ruleRows as $f): ?>
                <li class="mb-1 <?= $f['level'] === 'ERROR' ? 'text-danger' : ($f['level'] === 'WARNING' ? 'text-warning' : 'text-muted') ?>">
                  <span class="font-weight-bold"><?= esc($f['level']) ?></span> &middot; <?= esc($f['message']) ?>
                </li>
              <?php endforeach; ?>
            </ul>
          </div>

          <!-- KPI Metrics Row -->
          <?php
          $firstRow = !empty($salary_components) ? (object) reset($salary_components) : null;

          $totalComponents = $firstRow->total_components ?? 0;
          $earningsCount = $firstRow->earnings_count ?? 0;

          $deductions = (int) ($firstRow->deductions_count ?? 0);
          $employerContribution = (int) ($firstRow->employer_contribution_count ?? 0);
          $totalDeductionsStatutory = $deductions + $employerContribution;
          ?>

          <div class="row mb-2">
            <!-- Card 1: Total Components -->
            <div class="col-md-4 mb-3">
              <div class="card card-bloom p-3 h-100">
                <div class="d-flex align-items-center justify-content-between mb-2">
                  <span class="text-muted font-weight-bold text-uppercase" style="font-size: 11px;">Total Master
                    Components</span>
                  <div class="d-flex align-items-center justify-content-center rounded-circle"
                    style="width: 36px; height: 36px; background: #eef2ff; color: var(--bloom-purple, #6366f1);">
                    <i class="fas fa-sliders-h"></i>
                  </div>
                </div>
                <h3 class="font-weight-bold mb-1" id="kpiTotalComponents" style="color: var(--mtn-deep, #1e293b);">
                  <?= str_pad((string) $totalComponents, 2, '0', STR_PAD_LEFT) ?>
                </h3>
                <small class="text-success font-weight-bold">
                  <i class="fas fa-check-circle mr-1"></i> <?= $totalComponents ?> Active Master Rules Loaded
                </small>
              </div>
            </div>

            <!-- Card 2: Earnings Pool -->
            <div class="col-md-4 mb-3">
              <div class="card card-bloom p-3 h-100">
                <div class="d-flex align-items-center justify-content-between mb-2">
                  <span class="text-muted font-weight-bold text-uppercase" style="font-size: 11px;">Earnings Pool</span>
                  <div class="d-flex align-items-center justify-content-center rounded-circle"
                    style="width: 36px; height: 36px; background: #dcfce7; color: #15803d;">
                    <i class="fas fa-wallet"></i>
                  </div>
                </div>
                <h3 class="font-weight-bold mb-1" style="color: var(--mtn-deep, #1e293b);">
                  <?= str_pad((string) $earningsCount, 2, '0', STR_PAD_LEFT) ?>
                </h3>
                <small class="text-muted text-truncate d-block">Basic, HRA, Conveyance, Medical &amp; Allowances</small>
              </div>
            </div>

            <!-- Card 3: Deductions & Statutory -->
            <div class="col-md-4 mb-3">
              <div class="card card-bloom p-3 h-100">
                <div class="d-flex align-items-center justify-content-between mb-2">
                  <span class="text-muted font-weight-bold text-uppercase" style="font-size: 11px;">Deductions &amp;
                    Statutory</span>
                  <div class="d-flex align-items-center justify-content-center rounded-circle"
                    style="width: 36px; height: 36px; background: #fee2e2; color: #b91c1c;">
                    <i class="fas fa-shield-alt"></i>
                  </div>
                </div>
                <h3 class="font-weight-bold mb-1" style="color: var(--mtn-deep, #1e293b);">
                  <?= str_pad((string) $totalDeductionsStatutory, 2, '0', STR_PAD_LEFT) ?>
                </h3>
                <small class="text-danger font-weight-bold">
                  <i class="fas fa-check mr-1"></i> PF, ESI, PT, TDS &amp; LOP Enabled
                </small>
              </div>
            </div>
          </div>

          <!-- Filters & Search Toolbar
          <div class="card card-bloom p-3 mb-3">
            <div class="d-flex flex-column flex-lg-row align-items-center justify-content-between" style="gap: 10px;">
              <div class="w-100" style="max-width: 420px;">
                <div class="input-group input-group-sm">
                  <div class="input-group-prepend">
                    <span class="input-group-text bg-white border-right-0"><i
                        class="fas fa-search text-muted"></i></span>
                  </div>
                  <input class="form-control border-left-0" id="componentSearch"
                    placeholder="Search by code, component name, or basis..." type="text">
                </div>
              </div>

              <div class="d-flex align-items-center flex-wrap" style="gap: 10px;">
                <div class="d-flex align-items-center" style="gap: 6px;">
                  <span class="text-muted font-weight-bold text-uppercase" style="font-size: 11px;">Type:</span>
                  <select class="custom-select custom-select-sm" id="typeFilter"
                    style="width: 130px; border-radius: 8px;">
                    <option value="ALL">All Types</option>
                    <option value="EARNING">Earnings</option>
                    <option value="DEDUCTION">Deductions</option>
                    <option value="STATUTORY">Statutory</option>
                  </select>
                </div>

                <div class="d-flex align-items-center" style="gap: 6px;">
                  <span class="text-muted font-weight-bold text-uppercase" style="font-size: 11px;">Status:</span>
                  <select class="custom-select custom-select-sm" id="statusFilter"
                    style="width: 120px; border-radius: 8px;">
                    <option value="ALL">All Status</option>
                    <option value="ACTIVE">Active Only</option>
                    <option value="INACTIVE">Inactive Only</option>
                  </select>
                </div>

                <button class="pc-btn" onclick="resetTable()" title="Reset Filters" type="button">
                  <i class="fas fa-redo-alt text-muted"></i> Reset
                </button>
              </div>
            </div>
          </div> -->

          <!-- Master Data Table Container: every component and total in calculation order -->
          <div class="d-flex align-items-center flex-wrap mb-2" style="gap: 6px;" id="kindFilters">
            <span class="small text-muted mr-1">Show:</span>
            <button type="button" class="pc-btn pc-btn-primary kind-filter" data-filter="ALL" style="padding: 3px 10px; font-size: 12px;">All</button>
            <button type="button" class="pc-btn kind-filter" data-filter="COMPONENT" style="padding: 3px 10px; font-size: 12px;">Pay components</button>
            <button type="button" class="pc-btn kind-filter" data-filter="AGGREGATE" style="padding: 3px 10px; font-size: 12px;">Totals</button>
            <button type="button" class="pc-btn kind-filter" data-filter="INACTIVE" style="padding: 3px 10px; font-size: 12px;">Inactive</button>
            <span class="small text-muted ml-2">The salary engine works down this list in order; totals (tinted) come after everything they use.</span>
          </div>
          <div class="card card-bloom p-0 overflow-hidden mb-4">
            <table class="table-custom mb-0" id="masterSalaryTable">
              <thead>
                <tr class="table-header">
                  <th class="text-center" style="width: 64px;" title="Calculation order: the engine works down this list">Order</th>
                  <th>Code / Name</th>
                  <th>Kind</th>
                  <th>Type</th>
                  <th>How it is calculated</th>
                  <th>Uses</th>
                  <th>Used by</th>
                  <th class="text-center">Status</th>
                  <th class="text-right pr-4">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <?php
                // calculation-order view: kind of every code, and who uses whom (hrms_component_rules_check)
                $scopeByCode = [];
                $orderByCode = [];
                foreach (($salary_components ?? []) as $r0) {
                    $r0 = (array) $r0;
                    $c0 = strtoupper((string) ($r0['component_code'] ?? ''));
                    $scopeByCode[$c0] = strtoupper((string) ($r0['calculation_scope'] ?? 'COMPONENT'));
                    $orderByCode[$c0] = (int) ($r0['calculation_order'] ?? 0);
                }
                $usesMap = [];
                $usedByMap = [];
                foreach (($component_deps ?? []) as $d0) {
                    $usesMap[$d0['code']][$d0['uses']] = true;
                    $usedByMap[$d0['uses']][$d0['code']] = true;
                }
                $codeList = function (array $codes) use ($orderByCode) {
                    $out = [];
                    foreach (array_keys($codes) as $c1) {
                        $out[] = $c1 . (isset($orderByCode[$c1]) ? ' (' . $orderByCode[$c1] . ')' : '');
                    }
                    return $out;
                };
                ?>
                <?php if (!empty($salary_components) && (is_array($salary_components) || is_iterable($salary_components))): ?>
                  <?php foreach ($salary_components as $index => $row): ?>
                    <?php
                    $item = (object) $row;

                    $isEarning = strtoupper($item->component_type ?? '') === 'EARNING';
                    $isPercentage = strtoupper($item->calculation_type ?? '') === 'PERCENTAGE';
                    $isActive = (bool) ($item->is_active ?? false);
                    $isTaxable = (bool) ($item->is_taxable ?? false);

                    $formattedValue = number_format((float) ($item->percentage_value ?? 0), 2) . ($isPercentage ? ' %' : '');
                    $statutoryLabel = $isTaxable ? 'Yes' : 'No';
                    $statusLabel = $isActive ? 'ACTIVE' : 'INACTIVE';

                    // Dynamic engine fields
                    $calcOrder = (int) ($item->calculation_order ?? 100);
                    $slabCount = (int) ($item->slab_count ?? 0);
                    $formulaText = trim((string) ($item->formula_expression ?? ''));
                    $eligParam = trim((string) ($item->eligibility_parameter ?? ''));

                    // calculation-order view
                    $codeU = strtoupper((string) ($item->component_code ?? ''));
                    $isTotal = strtoupper($item->calculation_scope ?? '') === 'AGGREGATE';
                    $usesCodes = $usesMap[$codeU] ?? [];
                    $usedByCodes = $usedByMap[$codeU] ?? [];
                    $usesTotal = false;
                    foreach (array_keys($usesCodes) as $uc) {
                        if (($scopeByCode[$uc] ?? '') === 'AGGREGATE') { $usesTotal = true; }
                    }
                    $kindLabel = $isTotal ? ($usesTotal ? 'Total of totals' : 'Total') : 'Component';
                    $calcU = strtoupper((string) ($item->calculation_type ?? ''));
                    $baseU = strtoupper((string) ($item->percentage_base ?? ''));
                    if ($isTotal) {
                        $howText = '= ' . $formulaText;
                    } elseif (!empty($item->is_manual) || $calcU === 'MANUAL') {
                        $howText = 'Entered by hand each month';
                    } elseif ($slabCount > 0) {
                        $slabBases = [];
                        foreach (($component_deps ?? []) as $d1) {
                            if ($d1['code'] === $codeU && $d1['via'] === 'slab') { $slabBases[$d1['uses']] = true; }
                        }
                        $howText = $slabCount . ' slab' . ($slabCount > 1 ? 's' : '') . ($slabBases ? ' on ' . implode(', ', array_keys($slabBases)) : '');
                    } elseif ($calcU === 'PERCENTAGE') {
                        $howText = rtrim(rtrim(number_format((float) ($item->percentage_value ?? 0), 2), '0'), '.') . '% of ' . ($baseU ?: '?');
                    } elseif ($calcU === 'FIXED') {
                        $howText = 'Fixed ₹ ' . number_format((float) ($item->percentage_value ?? 0), 2);
                    } else {
                        $howText = $formulaText !== '' ? '= ' . $formulaText : $calcU;
                    }
                    $limits = [];
                    if ($eligParam !== '') { $limits[] = 'ESI employees only'; }
                    if ((float) ($item->minimum_amount ?? 0) > 0) { $limits[] = 'min ₹ ' . number_format((float) $item->minimum_amount, 0); }
                    if (($item->maximum_amount ?? '') !== '' && $item->maximum_amount !== null) { $limits[] = 'max ₹ ' . number_format((float) $item->maximum_amount, 0); }
                    $sortKey = ($isActive ? 0 : 100000) + $calcOrder;
                    ?>
                    <tr class="component-row" data-id="<?= esc($item->component_id) ?>"
                      style="<?= $isTotal ? 'background: #f5f7ff;' : '' ?><?= $isActive ? '' : 'opacity: .6;' ?>"
                      data-based="<?= esc($item->percentage_base ?? 'N/A') ?>"
                      data-calc="<?= esc($item->calculation_type ?? '') ?>"
                      data-code="<?= esc($item->component_code ?? '') ?>"
                      data-name="<?= esc($item->component_name ?? '') ?>" data-order="<?= $index + 1 ?>"
                      data-statutory="<?= $statutoryLabel ?>" data-type="<?= esc($item->component_type ?? '') ?>"
                      data-val="<?= esc($item->percentage_value ?? 0) ?>" data-status="<?= $statusLabel ?>"
                      data-formula="<?= esc($formulaText, 'attr') ?>"
                      data-min="<?= esc($item->minimum_amount ?? '') ?>" data-max="<?= esc($item->maximum_amount ?? '') ?>"
                      data-calcorder="<?= $calcOrder ?>" data-elig="<?= esc($eligParam, 'attr') ?>"
                      data-rounding="<?= (int) ($item->rounding_precision ?? 2) ?>" data-slabs="<?= $slabCount ?>"
                      data-scope="<?= esc(strtoupper($item->calculation_scope ?? 'COMPONENT'), 'attr') ?>"
                      data-manual="<?= !empty($item->is_manual) ? 1 : 0 ?>">

                      <td class="text-center font-weight-bold font-mono <?= $isActive ? 'text-dark' : 'text-muted' ?>" data-order="<?= $sortKey ?>"><?= $calcOrder ?></td>
                      <td>
                        <div class="font-weight-bold text-primary font-mono"><?= esc($item->component_code) ?></div>
                        <div class="small text-dark"><?= esc($item->component_name) ?></div>
                      </td>
                      <td>
                        <span class="badge <?= $isTotal ? 'badge-soft-primary' : 'badge-light border' ?> font-weight-bold px-2 py-1">
                          <i class="fas <?= $isTotal ? 'fa-equals' : 'fa-coins' ?> mr-1"></i><?= $kindLabel ?>
                        </span>
                      </td>
                      <td>
                        <span
                          class="badge <?= $isEarning ? 'badge-soft-success' : 'badge-soft-danger' ?> font-weight-bold px-2 py-1">
                          <i class="fas <?= $isEarning ? 'fa-plus-circle' : 'fa-minus-circle' ?> mr-1"></i>
                          <?= esc(ucfirst(strtolower(str_replace('_', ' ', $item->component_type ?? '')))) ?>
                        </span>
                      </td>
                      <td class="small" style="max-width: 240px;">
                        <div class="font-mono text-dark" title="<?= esc($howText, 'attr') ?>"
                          style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis;"><?= esc($howText) ?></div>
                        <?php if ($limits || ($isTaxable && !$isTotal)): ?>
                          <div class="text-muted"><?= esc(implode(' · ', array_merge($limits, ($isTaxable && !$isTotal) ? ['statutory'] : []))) ?></div>
                        <?php endif; ?>
                      </td>
                      <td class="small text-muted" style="max-width: 200px;"><?= esc(implode(', ', $codeList($usesCodes)) ?: '—') ?></td>
                      <td class="small text-muted" style="max-width: 180px;"><?= esc(implode(', ', $codeList($usedByCodes)) ?: '—') ?></td>
                      <td class="text-center">
                        <span
                          class="status-badge badge <?= $isActive ? 'badge-soft-success' : 'badge-soft-secondary' ?> font-weight-bold px-2 py-1">
                          <?= $statusLabel ?>
                        </span>
                      </td>
                      <td class="text-right pr-3">
                        <button type="button"
                          class="btn btn-xs btn-outline-primary mr-1 btn-edit font-weight-bold px-2 py-1"
                          data-id="<?= esc($item->component_id) ?>" style="border-radius: 6px;">
                          <i class="fas fa-edit mr-1"></i> Edit
                        </button>
                        <button type="button" class="btn btn-xs btn-outline-secondary btn-toggle-status px-2 py-1"
                          data-id="<?= esc($item->component_id) ?>" style="border-radius: 6px;" title="Toggle Status">
                          <i class="fas fa-power-off"></i>
                        </button>
                      </td>
                    </tr>
                  <?php endforeach; ?>
                <?php else: ?>
                  <tr>
                    <td colspan="9" class="text-center text-muted py-4">No salary components found.</td>
                  </tr>
                <?php endif; ?>
              </tbody>
            </table>
          </div>
        </div>
      </section>
    </div>

    <!-- MODAL FOR ADD / EDIT COMPONENT -->
    <div class="modal-overlay" id="salaryModalOverlay">
      <div class="modal-card" id="salaryModalCard" style="max-width: 1080px;">
        <div class="modal-header-bloom">
          <div class="d-flex align-items-center gap-2">
            <i class="fas fa-edit mr-2" id="modalIcon"></i>
            <h6 class="font-weight-bold mb-0 text-white" id="modalTitle">Edit Salary Component Master</h6>
          </div>
          <button type="button" class="btn btn-sm text-white" id="btnModalCloseCross"
            style="font-size: 18px; line-height: 1;">&times;</button>
        </div>

        <form id="salaryComponentForm" class="p-3 p-md-4" style="max-height: calc(85vh - 70px); overflow-y: auto;">
          <!-- Hidden Identifiers & Action Directive -->
          <input type="hidden" name="action" id="modalAction" value="INSERT">
          <input type="hidden" name="component_id" id="modalComponentId" value="">
          <?php if (function_exists('csrf_field')): ?>
            <?= csrf_field() ?>
          <?php elseif (function_exists('csrf_token') && function_exists('csrf_hash')): ?>
            <input type="hidden" name="<?= csrf_token() ?>" value="<?= csrf_hash() ?>" class="csrf-token-field">
          <?php endif; ?>

          <!-- 1. what is it: a pay component or a total (sets calculation_scope) -->
          <div class="form-group mb-3">
            <label class="font-weight-bold small text-muted mb-1">What are you adding?</label>
            <div class="d-flex flex-wrap" style="gap: 10px;" id="kindCards">
              <div class="kind-card border rounded p-2 flex-fill" data-kind="COMPONENT" style="cursor: pointer; min-width: 220px;">
                <div class="font-weight-bold"><i class="fas fa-coins text-primary mr-1"></i> Pay component</div>
                <div class="small text-muted">An amount paid, deducted or contributed, e.g. BASIC, PT, ER_NPS. It goes into its total.</div>
              </div>
              <div class="kind-card border rounded p-2 flex-fill" data-kind="AGGREGATE" style="cursor: pointer; min-width: 220px;">
                <div class="font-weight-bold"><i class="fas fa-equals text-primary mr-1"></i> Total</div>
                <div class="small text-muted">Adds up components or other totals, e.g. GROSS, NET_PAY. A formula, calculated after everything it uses.</div>
              </div>
            </div>
            <div class="small text-muted mt-1" id="kindLockedNote" style="display: none;">The kind of an existing component cannot be changed. Create a new one instead.</div>
          </div>

          <div class="form-group mb-2">
            <label class="font-weight-bold small text-muted mb-1">Component Code <span
                class="text-danger">*</span></label>
            <input type="text" name="code" class="form-control-bloom font-mono text-uppercase" id="modalComponentCode"
              placeholder="E.G. SPECIAL_ALLOWANCE" required>
          </div>

          <div class="form-group mb-2">
            <label class="font-weight-bold small text-muted mb-1">Component Name <span
                class="text-danger">*</span></label>
            <input type="text" name="name" class="form-control-bloom" id="modalComponentName"
              placeholder="e.g. Special Allowance" required>
          </div>

          <div class="row"> 
            <div class="col-sm-6 form-group mb-2">
              <label class="font-weight-bold small text-muted mb-1" id="typeLabel">Type <span class="text-danger">*</span></label>
              <select name="type" class="form-control-bloom" id="modalType" required>
                <option value="EARNING">EARNING</option>
                <option value="DEDUCTION">DEDUCTION</option>
                <option value="EMPLOYER_CONTRIBUTION">EMPLOYER_CONTRIBUTION</option>
              </select>
              <label class="small text-muted mt-1 mb-0" id="addToTotalLabel" style="cursor: pointer;">
                <input type="checkbox" name="add_to_total" value="1" id="modalAddToTotal" class="mr-1" checked>
                Include in <span class="font-weight-bold" id="addToTotalName">GROSS</span>
              </label>
            </div>
            <div class="col-sm-6 form-group mb-2 pay-only">
              <label class="font-weight-bold small text-muted mb-1">Calculation Type <span
                  class="text-danger">*</span></label>
              <select name="calculation_type" class="form-control-bloom" id="modalCalcType" required>
                <option value="PERCENTAGE">PERCENTAGE</option>
                <option value="FIXED">FIXED AMOUNT</option>
                <option value="FORMULA">FORMULA</option>
                <option value="MANUAL">MANUAL</option>
                <option value="STATUTORY">STATUTORY</option>
              </select>
            </div>
          </div>

          <div class="row">
            <div class="col-sm-6 form-group mb-2 pay-only">
              <label class="font-weight-bold small text-muted mb-1">Default Value (%) or (₹)</label>
              <input type="number" step="0.01" name="percentage" class="form-control-bloom font-mono"
                id="modalDefaultValue" placeholder="0.00">
            </div>
            <div class="col-sm-6 form-group mb-2 pay-only">
              <label class="font-weight-bold small text-muted mb-1">Based On</label>
              <select name="percentage_base" class="form-control-bloom" id="modalBasedOn">
                <option value="NONE">NONE</option>
                <option value="CTC">CTC (monthly CTC)</option>
                <option value="CTC1">CTC1 (CTC earned in the month)</option>
                <?php foreach (($salary_components ?? []) as $baseRow): ?>
                  <?php $baseItem = (object) $baseRow; ?>
                  <?php if (!empty($baseItem->component_code) && !empty($baseItem->is_active)
                            && !in_array(strtoupper($baseItem->component_code), ['CTC', 'CTC1'], true)): ?>
                    <option value="<?= esc(strtoupper($baseItem->component_code), 'attr') ?>">
                      <?= esc(strtoupper($baseItem->component_code)) ?> (order <?= (int) ($baseItem->calculation_order ?? 100) ?>)
                    </option>
                  <?php endif; ?>
                <?php endforeach; ?>
              </select>
            </div>
          </div>

          <!-- Formula (FORMULA and STATUTORY calculation types) -->
          <div class="form-group mb-2" id="formulaGroup" style="display: none;">
            <label class="font-weight-bold small text-muted mb-1">Formula</label>
            <textarea name="formula_expression" class="form-control-bloom font-mono text-uppercase" id="modalFormula"
              rows="2" maxlength="2000" placeholder="E.G. ROUND(LEAST(BASIC, 15000) * 12 / 100, 0)"></textarea>
            <div class="d-flex align-items-start mt-1" style="gap: 8px;">
              <button type="button" class="pc-btn" id="btnCheckFormula"><i class="fas fa-check-circle mr-1"></i> Check formula</button>
              <div class="small" id="formulaCheckResult" style="padding-top: 6px;"></div>
            </div>
            <div class="small text-muted mt-1">
              Use active component codes, CTC, CTC1, GROSS, TOTAL_DEDUCTIONS, numbers, + - * / ( ) and ROUND, LEAST, GREATEST, IF, CEIL, FLOOR, ABS.
              Give this component a higher calculation order than the components it uses; Check warns and suggests an order when it does not.
              A total may use pay components and other totals (NET_PAY = GROSS - TOTAL_DEDUCTIONS).
            </div>
            <div class="mt-1" id="formulaHelper">
              <div class="small text-muted mb-1">Click to insert (calculation order in brackets):</div>
              <div class="d-flex flex-wrap" style="gap: 4px; max-height: 92px; overflow-y: auto;" id="formulaChips"></div>
            </div>
            <div class="small mt-1" id="formulaUsesHint"></div>
          </div>

          <div class="row">
            <div class="col-sm-4 form-group mb-2">
              <label class="font-weight-bold small text-muted mb-1">Calculation Order</label>
              <input type="number" step="1" min="1" max="9999" name="calculation_order" class="form-control-bloom font-mono"
                id="modalCalcOrder" placeholder="Auto">
            </div>
            <div class="col-sm-4 form-group mb-2 pay-only">
              <label class="font-weight-bold small text-muted mb-1">Minimum Amount (₹)</label>
              <input type="number" step="0.01" min="0" name="minimum_amount" class="form-control-bloom font-mono"
                id="modalMinAmount" placeholder="No minimum">
            </div>
            <div class="col-sm-4 form-group mb-2 pay-only">
              <label class="font-weight-bold small text-muted mb-1">Maximum Amount (₹)</label>
              <input type="number" step="0.01" min="0" name="maximum_amount" class="form-control-bloom font-mono"
                id="modalMaxAmount" placeholder="No maximum">
            </div>
          </div>
          <!-- who this component uses and who uses it (hrms_component_rules_check, dependency list) -->
          <div class="small text-muted mb-2" id="compDepsLine" style="display: none;"></div>

          <div class="row">
            <div class="col-sm-8 form-group mb-2 pay-only">
              <label class="font-weight-bold small text-muted mb-1">Applies To</label>
              <select name="eligibility_parameter" class="form-control-bloom" id="modalEligibility">
                <option value="">All employees</option>
                <option value="EMPLOYEE_ESI_ELIGIBLE">Only employees with ESI applicable</option>
              </select>
            </div>
            <div class="col-sm-4 form-group mb-2">
              <label class="font-weight-bold small text-muted mb-1">Round To</label>
              <select name="rounding_precision" class="form-control-bloom" id="modalRounding">
                <option value="2">2 decimals</option>
                <option value="1">1 decimal</option>
                <option value="0">Whole rupee</option>
              </select>
            </div>
          </div>

          <div class="row">
            <div class="col-sm-6 form-group mb-2 pay-only">
              <label class="font-weight-bold small text-muted mb-1">Statutory Component?</label>
              <select name="taxable" class="form-control-bloom" id="modalStatutory">
                <option value="0">No</option>
                <option value="1">Yes</option>
              </select>
            </div>
            <div class="col-sm-6 form-group mb-2">
              <label class="font-weight-bold small text-muted mb-1">Status</label>
              <select name="active" class="form-control-bloom" id="modalStatus">
                <option value="1">ACTIVE</option>
                <option value="0">INACTIVE</option>
              </select>
            </div>
          </div>

          <div class="row">
            <div class="col-sm-4 form-group mb-2" style="display: none;">
              <label class="font-weight-bold small text-muted mb-1">Component Kind</label>
              <select name="calculation_scope" class="form-control-bloom" id="modalScope">
                <option value="COMPONENT">Pay component</option>
                <option value="AGGREGATE">Total (formula of other components)</option>
              </select>
            </div>
            <div class="col-sm-4 form-group mb-2 d-flex align-items-end pay-only">
              <label class="font-weight-bold small text-muted mb-2" style="cursor: pointer;">
                <input type="checkbox" name="is_manual" value="1" id="modalManual" class="mr-1">
                Manual amount (entered by hand)
              </label>
            </div>
            <div class="col-sm-4 form-group mb-2 d-flex align-items-end pay-only">
              <label class="font-weight-bold small text-muted mb-2" style="cursor: pointer;">
                <input type="checkbox" name="is_slab" value="1" id="modalIsSlab" class="mr-1">
                Slab component
              </label>
            </div>
          </div>

          <!-- Slabs of this component (saved together with the component) -->
          <div class="border rounded p-2 mb-2" id="slabSection" style="display: none; background: #f8fafc;">
            <div class="d-flex justify-content-between align-items-center mb-1">
              <span class="font-weight-bold small text-muted text-uppercase">Slabs</span>
              <button type="button" class="pc-btn" id="btnAddSlabRow"><i class="fas fa-plus mr-1"></i> Add slab</button>
            </div>
            <div class="small text-muted mb-2">
              The amount comes from the slab whose range contains the &ldquo;Based On&rdquo; value. Ranges may overlap:
              where they do, the lowest priority number wins. Leave &ldquo;To&rdquo; empty for no upper limit.
              A slab component uses its slabs only &mdash; its formula and percentage are not used.
              Check reports gaps between ranges, slabs that can never apply, and payroll months the slab dates do not cover.
            </div>
            <div class="table-responsive">
              <table class="table table-sm mb-1" id="slabTable" style="font-size: 12px;">
                <thead>
                  <tr class="table-header">
                    <th style="width: 70px;">Priority</th>
                    <th style="min-width: 120px;">Based On</th>
                    <th style="min-width: 100px;">From (₹)</th>
                    <th style="min-width: 100px;">To (₹)</th>
                    <th style="min-width: 110px;">Result</th>
                    <th style="min-width: 90px;">Value</th>
                    <th style="min-width: 120px;">% Of</th>
                    <th style="min-width: 130px;">Effective From</th>
                    <th style="min-width: 130px;">Effective To</th>
                    <th class="text-center" style="width: 55px;">Active</th>
                    <th style="width: 36px;"></th>
                  </tr>
                </thead>
                <tbody id="slabTableBody"></tbody>
              </table>
            </div>
            <div class="text-muted small" id="slabEmptyNote" style="display: none;">No slabs yet. Use &ldquo;Add slab&rdquo; to create the first one.</div>
          </div>

          <div class="small font-weight-bold mt-2" id="componentCheckResult"></div>
          <!-- rule checker findings and the before / after of the changed salaries (Check and Save) -->
          <div id="componentFindings" class="mt-2" style="display: none;"></div>
          <div id="componentImpact" class="mt-2" style="display: none;"></div>

          <div class="d-flex justify-content-end gap-2 pt-2 border-top mt-3">
            <button type="button" class="pc-btn mr-2" id="btnModalCancel">Cancel</button>
            <button type="button" class="pc-btn mr-2" id="btnCheckComponent"
              title="Validates the formula, slabs and calculation order and recalculates every employee without saving">
              <i class="fas fa-vial mr-1"></i> Check</button>
            <button type="submit" class="pc-btn pc-btn-primary" id="btnSaveComponent"><i class="fas fa-save mr-1"></i>
              Save Component</button>
          </div>
        </form>
      </div>
    </div>

  </div>

  <!-- Scripts -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
  <!-- DataTables JS -->
  <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
  <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/toastr.js/latest/toastr.min.js"></script>

  <script>
    toastr.options = {
      closeButton: true,
      debug: false,
      newestOnTop: true,
      progressBar: true,
      positionClass: "toast-top-right",
      preventDuplicates: false,
      timeOut: 6000,
      extendedTimeOut: 2000,
      showMethod: "fadeIn",
      hideMethod: "fadeOut"
    };

    function showToast(title, message, type = 'success') {
      const t = (type || 'success').toString().toUpperCase();
      if (typeof toastr !== 'undefined') {
        toastr.options.positionClass = "toast-top-right";
        if (t === 'SUCCESS' || t === 'Y') {
          toastr.success(message, title || 'Success');
        } else if (t === 'ERROR' || t === 'DANGER' || t === 'N') {
          toastr.error(message, title || 'Notice');
        } else if (t === 'WARNING') {
          toastr.warning(message, title || 'Warning');
        } else {
          toastr.info(message, title || 'Notification');
        }
      }
    }

    $(document).ready(function () {
      <?php if (function_exists('session') && session()->getFlashdata('error')): ?>
        showToast('Error', <?= json_encode(session()->getFlashdata('error')) ?>, 'error');
      <?php endif; ?>

      <?php if (function_exists('session') && session()->getFlashdata('success')): ?>
        showToast('Success', <?= json_encode(session()->getFlashdata('success')) ?>, 'success');
      <?php endif; ?>

      <?php if (function_exists('session') && session()->getFlashdata('warning')): ?>
        showToast('Warning', <?= json_encode(session()->getFlashdata('warning')) ?>, 'warning');
      <?php endif; ?>

      <?php if (function_exists('session') && session()->getFlashdata('info')): ?>
        showToast('Info', <?= json_encode(session()->getFlashdata('info')) ?>, 'info');
      <?php endif; ?>

      const modalOverlay = document.getElementById('salaryModalOverlay');
      const btnOpenAddModal = document.getElementById('btnOpenAddModal');
      const btnModalCancel = document.getElementById('btnModalCancel');
      const btnModalCloseCross = document.getElementById('btnModalCloseCross');
      const salaryForm = document.getElementById('salaryComponentForm');

      const modalTitle = document.getElementById('modalTitle');
      const modalAction = document.getElementById('modalAction');
      const modalComponentId = document.getElementById('modalComponentId');
      const modalComponentCode = document.getElementById('modalComponentCode');
      const modalComponentName = document.getElementById('modalComponentName');
      const modalType = document.getElementById('modalType');
      const modalCalcType = document.getElementById('modalCalcType');
      const modalDefaultValue = document.getElementById('modalDefaultValue');
      const modalBasedOn = document.getElementById('modalBasedOn');
      const modalStatutory = document.getElementById('modalStatutory');
      const modalStatus = document.getElementById('modalStatus');

      // Dynamic engine fields
      const modalFormula = document.getElementById('modalFormula');
      const modalCalcOrder = document.getElementById('modalCalcOrder');
      const modalMinAmount = document.getElementById('modalMinAmount');
      const modalMaxAmount = document.getElementById('modalMaxAmount');
      const modalEligibility = document.getElementById('modalEligibility');
      const modalRounding = document.getElementById('modalRounding');
      const formulaGroup = document.getElementById('formulaGroup');
      const formulaCheckResult = document.getElementById('formulaCheckResult');

      // The formula box is used by FORMULA and (optionally) STATUTORY components.
      function toggleFormulaGroup() {
        const calc = (modalCalcType.value || '').toUpperCase();
        formulaGroup.style.display = (calc === 'FORMULA' || calc === 'STATUTORY') ? '' : 'none';
        formulaCheckResult.textContent = '';
      }
      modalCalcType.addEventListener('change', toggleFormulaGroup);

      function openModal() {
        toggleFormulaGroup();
        toggleSlabSection();
        componentCheckResult.textContent = '';
        clearCheckOutput();
        document.getElementById('modalAddToTotal').checked = true;   // only adds when the component is not in its total yet
        refreshAddToTotal();
        showDeps();
        applyKind();
        modalOverlay.style.display = 'flex';
      }

      function closeModal() {
        modalOverlay.style.display = 'none';
      }

      // Initialize DataTables with Step 2 Theme & Custom DOM
      const dtConfig = {
        paging: true,
        ordering: true,
        order: [[0, 'asc']],
        searching: true,
        info: true,
        lengthChange: true,
        pageLength: 10,
        lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "All"]],
        dom: "<'row'<'col-md-6'l><'col-md-6'f>>" +
          "<'table-responsive'tr>" +
          "<'row'<'col-md-6'i><'col-md-6'p>>",
        columnDefs: [
          { orderable: false, targets: -1 }
        ],
        language: {
          paginate: {
            previous: "Previous",
            next: "Next"
          },
          search: "Search:",
          lengthMenu: "Show _MENU_ entries",
          info: "Showing _START_ to _END_ of _TOTAL_ master components",
          infoEmpty: "Showing 0 to 0 of 0 components",
          infoFiltered: "(filtered from _MAX_ total components)"
        }
      };

      const dtTable = $('#masterSalaryTable').DataTable(dtConfig);

      // Top Toolbar: Component Search sync
      $('#componentSearch').on('keyup input', function () {
        dtTable.search(this.value).draw();
      });

      // Top Toolbar: Type Filter
      $('#typeFilter').on('change', function () {
        const val = this.value;
        if (val === 'ALL') {
          dtTable.column(3).search('').draw();
        } else {
          dtTable.column(3).search(val).draw();
        }
      });

      // Top Toolbar: Status Filter
      $('#statusFilter').on('change', function () {
        const val = this.value;
        if (val === 'ALL') {
          dtTable.column(7).search('').draw();
        } else {
          dtTable.column(7).search('^' + val + '$', true, false).draw();
        }
      });

      // Top Toolbar: Reset Filters
      window.resetTable = function () {
        $('#componentSearch').val('');
        $('#typeFilter').val('ALL');
        $('#statusFilter').val('ALL');
        dtTable.search('').columns().search('').draw();
      };

      // 1. ADD NEW (Action: INSERT)
      if (btnOpenAddModal) {
        btnOpenAddModal.addEventListener('click', function () {
          modalAction.value = 'INSERT';
          modalComponentId.value = '';
          modalTitle.textContent = 'Add New Salary Component Master';
          modalComponentCode.value = '';
          modalComponentCode.readOnly = false;
          modalComponentName.value = '';
          modalType.value = 'EARNING';
          modalCalcType.value = 'PERCENTAGE';
          modalDefaultValue.value = '';
          modalBasedOn.value = 'CTC';
          modalStatutory.value = '0';
          modalStatus.value = '1';
          modalFormula.value = '';
          modalCalcOrder.value = '';
          modalMinAmount.value = '';
          modalMaxAmount.value = '';
          modalEligibility.value = '';
          modalRounding.value = '2';
          modalScope.value = 'COMPONENT';
          modalManual.checked = false;
          modalIsSlab.checked = false;
          clearSlabs();
          openModal();
        });
      }

      // 2. EDIT COMPONENT (Action: UPDATE)
      $('#masterSalaryTable').on('click', '.btn-edit', function () {
        const row = $(this).closest('tr.component-row')[0];
        if (!row) return;

        modalAction.value = 'UPDATE';
        modalComponentId.value = row.dataset.id || '';
        modalTitle.textContent = 'Edit Salary Component Master: ' + (row.dataset.code || '');
        modalComponentCode.value = row.dataset.code || '';
        modalComponentCode.readOnly = true;
        modalComponentName.value = row.dataset.name || '';
        modalType.value = row.dataset.type || 'EARNING';
        modalCalcType.value = row.dataset.calc || 'PERCENTAGE';
        modalDefaultValue.value = row.dataset.val || '0.00';
        modalBasedOn.value = row.dataset.based || 'CTC';
        modalStatutory.value = (row.dataset.statutory === 'Yes' || row.dataset.statutory === '1') ? '1' : '0';
        modalStatus.value = (row.dataset.status === 'ACTIVE' || row.dataset.status === '1') ? '1' : '0';
        modalFormula.value = row.dataset.formula || '';
        modalCalcOrder.value = row.dataset.calcorder || '';
        modalMinAmount.value = row.dataset.min || '';
        modalMaxAmount.value = row.dataset.max || '';
        modalEligibility.value = row.dataset.elig || '';
        modalRounding.value = row.dataset.rounding || '2';
        modalScope.value = row.dataset.scope || 'COMPONENT';
        modalManual.checked = row.dataset.manual === '1';
        modalIsSlab.checked = (parseInt(row.dataset.slabs, 10) || 0) > 0;
        clearSlabs();
        if (modalIsSlab.checked) loadSlabs(row.dataset.id);

        openModal();
      });

      const manageSalCompUrl = '<?= function_exists("site_url") ? site_url("payroll/manage_sal_comp") : base_url("payroll/manage_sal_comp") ?>';
      const validateFormulaUrl = '<?= site_url("payroll/validate_formula") ?>';
      const componentSlabsUrl = '<?= site_url("payroll/component_slabs") ?>';
      const saveComponentSlabsUrl = '<?= site_url("payroll/save_component_slabs") ?>';
      <?php
      $slabBaseCodes = [];
      foreach (($salary_components ?? []) as $slabBaseRow) {
          $slabBaseItem = (object) $slabBaseRow;
          if (!empty($slabBaseItem->component_code) && !empty($slabBaseItem->is_active)) {
              $slabBaseCodes[] = [
                  'code'  => strtoupper($slabBaseItem->component_code),
                  'order' => (int) ($slabBaseItem->calculation_order ?? 100),
              ];
          }
      }
      ?>
      const componentBaseCodes = <?= json_encode($slabBaseCodes) ?>;

      // Robust error message extractor for AJAX responses (JSON, HTML debug dumps, CI4 errors)
      function extractErrorMessage(xhr, fallback) {
        // 1. If standard JSON response
        if (xhr.responseJSON) {
          if (xhr.responseJSON.message) return xhr.responseJSON.message;
          if (xhr.responseJSON.error) return xhr.responseJSON.error;
          if (xhr.responseJSON.messages) {
            if (typeof xhr.responseJSON.messages === 'string') return xhr.responseJSON.messages;
            if (typeof xhr.responseJSON.messages === 'object') {
              return Object.values(xhr.responseJSON.messages).join(' ');
            }
          }
        }
        // 2. If raw responseText exists (could be print_r/echo debug output or PHP error)
        if (xhr.responseText) {
          const raw = xhr.responseText.trim();
          try {
            const parsed = JSON.parse(raw);
            if (parsed.message) return parsed.message;
            if (parsed.error) return parsed.error;
          } catch (e) {
            console.warn("Non-JSON Server Output:", raw);
            const tempDiv = document.createElement("div");
            tempDiv.innerHTML = raw;
            const text = (tempDiv.textContent || tempDiv.innerText || raw).trim();
            if (text.length > 0) {
              return text.length > 350 ? text.substring(0, 350) + '...' : text;
            }
          }
        }
        // 3. Status code-specific fallbacks
        if (xhr.status === 401) return 'Session expired or unauthorized. Please re-login.';
        if (xhr.status === 403) return 'Forbidden or CSRF token mismatch (403). Please refresh the page.';
        if (xhr.status === 404) return 'The requested endpoint was not found (404). Check your controller route.';
        if (xhr.status === 500) return 'Internal Server Error (500). Please check your controller or server error logs.';
        return fallback || 'Server error occurred (HTTP ' + xhr.status + ').';
      }

      function updateCsrf(newToken, newHash) {
        if (!newToken && !newHash) return;
        $('meta[name="csrf-token-name"]').attr('content', newToken);
        $('meta[name="csrf-token-hash"]').attr('content', newHash);
        $('.csrf-token-field, input[name="' + newToken + '"]').val(newHash);
      }

      // 3. TOGGLE STATUS (Action: ACTIVE)
      $('#masterSalaryTable').on('click', '.btn-toggle-status', function () {
        const row = $(this).closest('tr.component-row')[0];
        if (!row) return;

        const btn = $(this);
        const originalHtml = btn.html();
        const componentId = row.dataset.id;
        const currentStatus = (row.dataset.status || 'ACTIVE').toUpperCase();
        const newStatus = (currentStatus === 'ACTIVE' || currentStatus === '1') ? '0' : '1';

        const postData = {
          action: 'ACTIVE',
          component_id: componentId,
          active: newStatus
        };

        const csrfName = $('meta[name="csrf-token-name"]').attr('content');
        const csrfHash = $('meta[name="csrf-token-hash"]').attr('content');
        if (csrfName && csrfHash) {
          postData[csrfName] = csrfHash;
        }

        btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i>');

        $.ajax({
          url: manageSalCompUrl,
          type: 'POST',
          dataType: 'json',
          headers: {
            'X-Requested-With': 'XMLHttpRequest'
          },
          data: postData,
          success: function (res) {
            if (res.csrf_token || res.token) {
              updateCsrf(res.csrf_name || csrfName, res.csrf_token || res.token);
            }
            if (res.status) {
              const statusText = newStatus === '1' ? 'ACTIVE' : 'INACTIVE';
              row.dataset.status = statusText;
              const badge = row.querySelector('.status-badge');
              if (badge) {
                badge.className = newStatus === '1'
                  ? 'status-badge badge badge-soft-success font-weight-bold px-2 py-1'
                  : 'status-badge badge badge-soft-secondary font-weight-bold px-2 py-1';
                badge.textContent = statusText;
              }
              dtTable.row(row).invalidate().draw(false);
              showToast('Status Updated', 'Component status set to ' + statusText, 'success');
            } else {
              showToast('Status Update Failed', res.message || 'Failed to update component status.', 'error');
            }
          },
          error: function (xhr) {
            showToast('Error', extractErrorMessage(xhr, 'Server error occurred while toggling status.'), 'error');
          },
          complete: function () {
            btn.prop('disabled', false).html(originalHtml);
          }
        });
      });

      // 4. SUBMIT FORM (INSERT / UPDATE)
      salaryForm.addEventListener('submit', function (e) {
        e.preventDefault();

        const btnSave = $('#btnSaveComponent');
        const originalBtnHtml = btnSave.html();
        const formData = new FormData(salaryForm);
        formData.set('slabs', JSON.stringify(collectSlabs()));

        // Ensure CSRF token is present in FormData if available
        const csrfName = $('meta[name="csrf-token-name"]').attr('content');
        const csrfHash = $('meta[name="csrf-token-hash"]').attr('content');
        if (csrfName && csrfHash && !formData.has(csrfName)) {
          formData.append(csrfName, csrfHash);
        }

        btnSave.prop('disabled', true).html('<i class="fas fa-spinner fa-spin mr-1"></i> Saving...');

        $.ajax({
          url: manageSalCompUrl,
          type: 'POST',
          data: formData,
          processData: false,
          contentType: false,
          dataType: 'json',
          headers: {
            'X-Requested-With': 'XMLHttpRequest'
          },
          success: function (res) {
            if (res.csrf_token || res.token) {
              updateCsrf(res.csrf_name || csrfName, res.csrf_token || res.token);
            }
            if (res.status) {
              showToast('Component Saved', res.message || 'Salary component saved successfully.', 'success');
              closeModal();
              setTimeout(() => { location.reload(); }, 1500);
            } else {
              // nothing was saved: keep the form open and show why
              showToast('Operation Failed', res.message || 'Failed to save component.', 'error');
              componentCheckResult.className = 'small font-weight-bold mt-2 text-danger';
              componentCheckResult.textContent = res.message || 'Failed to save component.';
              renderFindings(res.findings);
              renderImpact(res.impact);
            }
          },
          error: function (xhr) {
            const errorMsg = extractErrorMessage(xhr, 'Server error occurred while saving component.');
            showToast('Save Failed', errorMsg, 'error');
          },
          complete: function () {
            btnSave.prop('disabled', false).html(originalBtnHtml);
          }
        });
      });

      if (btnModalCancel) btnModalCancel.addEventListener('click', closeModal);
      if (btnModalCloseCross) btnModalCloseCross.addEventListener('click', closeModal);
      modalOverlay.addEventListener('click', function (e) {
        if (e.target === modalOverlay) closeModal();
      });

      // 5. CHECK FORMULA (formula engine: syntax, names, calculation order)
      $('#btnCheckFormula').on('click', function () {
        const btn = $(this);
        const originalHtml = btn.html();
        const postData = {
          component_id: modalComponentId.value,
          code: modalComponentCode.value,
          calculation_order: modalCalcOrder.value,
          formula_expression: modalFormula.value
        };
        const csrfName = $('meta[name="csrf-token-name"]').attr('content');
        const csrfHash = $('meta[name="csrf-token-hash"]').attr('content');
        if (csrfName && csrfHash) postData[csrfName] = csrfHash;

        btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin mr-1"></i> Checking...');
        formulaCheckResult.textContent = '';

        $.ajax({
          url: validateFormulaUrl,
          type: 'POST',
          dataType: 'json',
          headers: { 'X-Requested-With': 'XMLHttpRequest' },
          data: postData,
          success: function (res) {
            if (res.csrf_token) updateCsrf(csrfName, res.csrf_token);
            formulaCheckResult.className = 'small font-weight-bold ' + (res.status ? 'text-success' : 'text-danger');
            formulaCheckResult.textContent = res.message || (res.status ? 'Formula is valid.' : 'Formula is not valid.');
          },
          error: function (xhr) {
            formulaCheckResult.className = 'small font-weight-bold text-danger';
            formulaCheckResult.textContent = extractErrorMessage(xhr, 'Formula could not be checked.');
          },
          complete: function () {
            btn.prop('disabled', false).html(originalHtml);
          }
        });
      });

      // 6. SLABS inside the component form (saved together with the component)
      const slabBody = document.getElementById('slabTableBody');
      const slabEmptyNote = document.getElementById('slabEmptyNote');
      const slabSection = document.getElementById('slabSection');
      const modalScope = document.getElementById('modalScope');
      const modalManual = document.getElementById('modalManual');
      const modalIsSlab = document.getElementById('modalIsSlab');
      const componentCheckResult = document.getElementById('componentCheckResult');

      function escapeHtml(value) {
        return String(value === null || value === undefined ? '' : value)
          .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
      }

      function todayIso() {
        const d = new Date();
        const pad = (n) => String(n).padStart(2, '0');
        return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
      }

      // A slab can be based on CTC, CTC1 or any other component (GROSS is a component too).
      function baseSelectHtml(cssClass, selected, withNone) {
        const sel = (selected || '').toUpperCase();
        const own = (modalComponentCode.value || '').toUpperCase();
        const codes = ['CTC', 'CTC1'];
        componentBaseCodes.forEach(function (c) {
          if (c.code !== own && codes.indexOf(c.code) === -1) codes.push(c.code);
        });
        if (sel && sel !== 'NONE' && codes.indexOf(sel) === -1) codes.push(sel);
        let html = '<select class="form-control-bloom ' + cssClass + '">';
        if (withNone) html += '<option value="NONE">—</option>';
        codes.forEach(function (code) {
          html += '<option value="' + escapeHtml(code) + '"' + (code === sel ? ' selected' : '') + '>' + escapeHtml(code) + '</option>';
        });
        return html + '</select>';
      }

      function refreshSlabEmptyNote() {
        slabEmptyNote.style.display = slabBody.children.length ? 'none' : '';
      }

      function syncSlabRow(tr) {
        const isPercent = tr.querySelector('.slab-rtype').value === 'PERCENTAGE';
        const pbase = tr.querySelector('.slab-pbase');
        pbase.disabled = !isPercent;
        if (!isPercent) pbase.value = 'NONE';
        else if (pbase.value === 'NONE') pbase.value = tr.querySelector('.slab-based').value;
      }

      function addSlabRow(slab) {
        const s = slab || {};
        let nextPriority = 1;
        slabBody.querySelectorAll('.slab-priority').forEach(function (inp) {
          nextPriority = Math.max(nextPriority, (parseInt(inp.value, 10) || 0) + 1);
        });
        const hasGross = componentBaseCodes.some(function (c) { return c.code === 'GROSS'; });
        const rtype = (s.result_type || 'FIXED').toUpperCase();
        const isActive = !(String(s.is_active) === '0');
        const tr = document.createElement('tr');
        tr.innerHTML =
          '<td><input type="number" min="1" max="999" step="1" class="form-control-bloom font-mono slab-priority" value="' + escapeHtml(s.priority || nextPriority) + '"></td>' +
          '<td>' + baseSelectHtml('slab-based', s.slab_based_on || (hasGross ? 'GROSS' : 'CTC'), false) + '</td>' +
          '<td><input type="number" min="0" step="0.01" class="form-control-bloom font-mono slab-min" value="' + escapeHtml(s.slab_min_value !== undefined ? s.slab_min_value : '') + '" placeholder="0.00"></td>' +
          '<td><input type="number" min="0" step="0.01" class="form-control-bloom font-mono slab-max" value="' + escapeHtml(s.slab_max_value) + '" placeholder="No limit"></td>' +
          '<td><select class="form-control-bloom slab-rtype">' +
            '<option value="FIXED"' + (rtype === 'FIXED' ? ' selected' : '') + '>Fixed ₹</option>' +
            '<option value="PERCENTAGE"' + (rtype === 'PERCENTAGE' ? ' selected' : '') + '>Percent %</option>' +
          '</select></td>' +
          '<td><input type="number" min="0" step="0.01" class="form-control-bloom font-mono slab-rvalue" value="' + escapeHtml(s.result_value !== undefined ? s.result_value : '') + '" placeholder="0.00"></td>' +
          '<td>' + baseSelectHtml('slab-pbase', s.percentage_base || 'NONE', true) + '</td>' +
          '<td><input type="date" class="form-control-bloom slab-from" value="' + escapeHtml(s.effective_from || todayIso()) + '"></td>' +
          '<td><input type="date" class="form-control-bloom slab-to" value="' + escapeHtml(s.effective_to) + '"></td>' +
          '<td class="text-center"><input type="checkbox" class="slab-active"' + (isActive ? ' checked' : '') + '></td>' +
          '<td><button type="button" class="btn btn-xs btn-outline-danger btn-remove-slab" title="Remove slab"><i class="fas fa-times"></i></button></td>';
        slabBody.appendChild(tr);
        syncSlabRow(tr);
        refreshSlabEmptyNote();
      }

      function clearSlabs() {
        slabBody.innerHTML = '';
        refreshSlabEmptyNote();
      }

      function loadSlabs(componentId) {
        $.ajax({
          url: componentSlabsUrl,
          type: 'GET',
          dataType: 'json',
          headers: { 'X-Requested-With': 'XMLHttpRequest' },
          data: { component_id: componentId },
          success: function (res) {
            if (!res.status) {
              showToast('Slabs', res.message || 'Slabs could not be loaded.', 'error');
              return;
            }
            clearSlabs();
            (res.slabs || []).forEach(addSlabRow);
          },
          error: function (xhr) {
            showToast('Error', extractErrorMessage(xhr, 'Slabs could not be loaded.'), 'error');
          }
        });
      }

      function collectSlabs() {
        const slabs = [];
        if (!modalIsSlab.checked) return slabs;
        slabBody.querySelectorAll('tr').forEach(function (tr) {
          const maxVal = tr.querySelector('.slab-max').value.trim();
          const toVal = tr.querySelector('.slab-to').value.trim();
          slabs.push({
            priority: tr.querySelector('.slab-priority').value.trim(),
            slab_based_on: tr.querySelector('.slab-based').value,
            slab_min_value: tr.querySelector('.slab-min').value.trim() || '0',
            slab_max_value: maxVal === '' ? null : maxVal,
            result_type: tr.querySelector('.slab-rtype').value,
            result_value: tr.querySelector('.slab-rvalue').value.trim(),
            percentage_base: tr.querySelector('.slab-pbase').value,
            effective_from: tr.querySelector('.slab-from').value,
            effective_to: toVal === '' ? null : toVal,
            is_active: tr.querySelector('.slab-active').checked ? 1 : 0
          });
        });
        return slabs;
      }

      // The slab table shows only for a slab component; a total is always a formula.
      function toggleSlabSection() {
        const isTotal = modalScope.value === 'AGGREGATE';
        if (isTotal) {
          modalCalcType.value = 'FORMULA';
          modalIsSlab.checked = false;
          modalManual.checked = false;
          toggleFormulaGroup();
        }
        modalIsSlab.disabled = isTotal;
        modalManual.disabled = isTotal;
        slabSection.style.display = modalIsSlab.checked ? '' : 'none';
        if (modalIsSlab.checked && !slabBody.children.length) addSlabRow();
      }
      modalIsSlab.addEventListener('change', toggleSlabSection);
      modalScope.addEventListener('change', toggleSlabSection);

      $('#btnAddSlabRow').on('click', function () { addSlabRow(); });

      $('#slabTableBody').on('click', '.btn-remove-slab', function () {
        $(this).closest('tr').remove();
        refreshSlabEmptyNote();
      });

      $('#slabTableBody').on('change', '.slab-rtype, .slab-based', function () {
        syncSlabRow($(this).closest('tr')[0]);
      });

      // 8. RULE CHECK OUTPUT: findings (errors / warnings / info) and the impact on salaries
      const COMPONENT_DEPS = <?= json_encode($component_deps ?? [], JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) ?>;
      const TOTAL_FOR_TYPE = { EARNING: 'GROSS', DEDUCTION: 'TOTAL_DEDUCTIONS', EMPLOYER_CONTRIBUTION: 'TOTAL_EMPLOYER_CONTRIBUTION' };
      const componentFindings = document.getElementById('componentFindings');
      const componentImpact = document.getElementById('componentImpact');
      const modalAddToTotal = document.getElementById('modalAddToTotal');

      function money(v) {
        return '₹ ' + Number(v || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      }

      function clearCheckOutput() {
        componentFindings.style.display = 'none';
        componentFindings.innerHTML = '';
        componentImpact.style.display = 'none';
        componentImpact.innerHTML = '';
      }

      // "Include in GROSS" follows the type; a total itself is never put into a total
      function refreshAddToTotal() {
        const label = document.getElementById('addToTotalLabel');
        document.getElementById('addToTotalName').textContent = TOTAL_FOR_TYPE[modalType.value] || 'its total';
        label.style.display = modalScope.value === 'AGGREGATE' ? 'none' : '';
      }
      modalType.addEventListener('change', refreshAddToTotal);
      modalScope.addEventListener('change', refreshAddToTotal);

      // what this component uses and which components use it
      function showDeps() {
        const line = document.getElementById('compDepsLine');
        const code = (modalComponentCode.value || '').toUpperCase();
        if (!code) { line.style.display = 'none'; return; }
        const uses = [...new Set(COMPONENT_DEPS.filter(d => d.code === code).map(d => d.uses + (d.uses_order ? ' (' + d.uses_order + ')' : '')))];
        const usedBy = [...new Set(COMPONENT_DEPS.filter(d => d.uses === code).map(d => d.code))];
        if (!uses.length && !usedBy.length) { line.style.display = 'none'; return; }
        line.innerHTML = '<i class="fas fa-project-diagram mr-1"></i>' +
          '<span class="font-weight-bold">Uses:</span> ' + escapeHtml(uses.join(', ') || 'nothing') +
          ' &nbsp;&middot;&nbsp; <span class="font-weight-bold">Used by:</span> ' + escapeHtml(usedBy.join(', ') || 'nothing');
        line.style.display = '';
      }

      function renderFindings(findings) {
        const list = Array.isArray(findings) ? findings : [];
        if (!list.length) { componentFindings.style.display = 'none'; return; }
        const own = (modalComponentCode.value || '').toUpperCase();
        const color = { ERROR: '#dc2626', WARNING: '#b45309', INFO: '#64748b' };
        let html = '<div class="border rounded p-2" style="background:#fffdf7;"><div class="small font-weight-bold text-muted text-uppercase mb-1">Rule check</div><ul class="mb-0 pl-3 small">';
        list.forEach(function (f) {
          html += '<li class="mb-1" style="color:' + (color[f.level] || '#334155') + ';"><span class="font-weight-bold">' +
            escapeHtml(f.level) + '</span> &middot; ' + escapeHtml(f.message);
          if (f.check === 'ORDER' && f.suggest_order && (f.component || '').toUpperCase() === own) {
            html += ' <button type="button" class="pc-btn btn-use-order" data-order="' + escapeHtml(f.suggest_order) +
              '" style="padding:1px 8px;font-size:11px;">Use order ' + escapeHtml(f.suggest_order) + '</button>';
          }
          html += '</li>';
        });
        componentFindings.innerHTML = html + '</ul></div>';
        componentFindings.style.display = '';
      }

      function renderImpact(impact) {
        if (!impact || !impact.structures) { componentImpact.style.display = 'none'; return; }
        const rows = impact.rows || [];
        let html = '<div class="border rounded p-2"><div class="small font-weight-bold text-muted text-uppercase mb-1">Impact on salaries</div>' +
          '<div class="small mb-1">' + escapeHtml(impact.changed) + ' of ' + escapeHtml(impact.structures) +
          ' salaries change' + (rows.length < impact.changed ? ' (biggest ' + rows.length + ' shown)' : '') + '.</div>';
        if (rows.length) {
          html += '<div class="table-responsive" style="max-height: 230px; overflow-y: auto;"><table class="table table-sm mb-0" style="font-size: 11.5px;">' +
            '<thead><tr class="table-header"><th>Employee</th><th class="text-right">Gross</th><th class="text-right">Deductions</th><th class="text-right">Net pay</th></tr></thead><tbody>';
          rows.forEach(function (r) {
            const diff = Number(r.net_after) - Number(r.net_before);
            html += '<tr><td><span class="font-weight-bold">' + escapeHtml(r.emp_id) + '</span> ' + escapeHtml(r.emp_name || '') +
              '<div class="text-muted" style="font-size:10.5px;">salary from ' + escapeHtml(r.from || '') + '</div></td>' +
              '<td class="text-right">' + money(r.gross_before) + ' &rarr; ' + money(r.gross_after) + '</td>' +
              '<td class="text-right">' + money(r.ded_before) + ' &rarr; ' + money(r.ded_after) + '</td>' +
              '<td class="text-right font-weight-bold" style="color:' + (diff < 0 ? '#dc2626' : '#059669') + ';">' +
              money(r.net_before) + ' &rarr; ' + money(r.net_after) + '</td></tr>';
          });
          html += '</tbody></table></div>';
        }
        componentImpact.innerHTML = html + '</div>';
        componentImpact.style.display = '';
      }

      $('#componentFindings').on('click', '.btn-use-order', function () {
        modalCalcOrder.value = $(this).data('order');
        $(this).replaceWith('<span class="text-success font-weight-bold">order set &mdash; Check again</span>');
      });

      $('#btnToggleRules').on('click', function () {
        const list = document.getElementById('ruleCheckList');
        const open = list.style.display !== 'none';
        list.style.display = open ? 'none' : 'block';
        $(this).find('span').text(open ? 'Show details' : 'Hide details');
      });

      // 9. KIND FIRST: pay component or total; fields that do not apply to a total are hidden
      const COMPONENT_LIST = <?= json_encode(array_values(array_map(function ($r) {
          $r = (array) $r;
          return ['code' => strtoupper((string) ($r['component_code'] ?? '')), 'order' => (int) ($r['calculation_order'] ?? 0),
                  'scope' => strtoupper((string) ($r['calculation_scope'] ?? 'COMPONENT')), 'active' => !empty($r['is_active'])];
      }, $salary_components ?? [])), JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) ?>;
      const SIDE_LABEL = 'Shown as <span class="text-muted font-weight-normal">(earning / deduction / employer side, a label only)</span>';
      const TYPE_LABEL = 'Type <span class="text-danger">*</span>';

      function applyKind() {
        const isTotal = modalScope.value === 'AGGREGATE';
        document.querySelectorAll('#salaryComponentForm .pay-only').forEach(function (el) { el.style.display = isTotal ? 'none' : ''; });
        document.querySelectorAll('#kindCards .kind-card').forEach(function (card) {
          const on = card.dataset.kind === modalScope.value;
          card.style.borderColor = on ? 'var(--bloom-purple, #4f46e5)' : '';
          card.style.borderWidth = on ? '2px' : '';
          card.style.background = on ? '#f5f7ff' : '';
          card.style.opacity = (modalAction.value === 'UPDATE' && !on) ? '.45' : '';
        });
        document.getElementById('kindLockedNote').style.display = modalAction.value === 'UPDATE' ? '' : 'none';
        document.getElementById('typeLabel').innerHTML = isTotal ? SIDE_LABEL : TYPE_LABEL;
        renderFormulaChips();
        refreshUsesHint();
      }

      $('#kindCards').on('click', '.kind-card', function () {
        if (modalAction.value === 'UPDATE') return;          // the kind of a saved component is fixed
        modalScope.value = this.dataset.kind;
        modalScope.dispatchEvent(new Event('change'));
        if (modalScope.value === 'COMPONENT' && modalCalcType.value === 'FORMULA' && !modalFormula.value.trim()) {
          modalCalcType.value = 'PERCENTAGE';
          toggleFormulaGroup();
        }
        applyKind();
      });
      modalScope.addEventListener('change', applyKind);

      // formula helper: every active component and total, in calculation order
      function renderFormulaChips() {
        const own = (modalComponentCode.value || '').toUpperCase();
        const box = document.getElementById('formulaChips');
        box.innerHTML = COMPONENT_LIST.filter(c => c.active && c.code !== own)
          .sort((a, b) => a.order - b.order)
          .map(c => '<button type="button" class="btn btn-xs formula-chip ' + (c.scope === 'AGGREGATE' ? 'btn-outline-primary' : 'btn-outline-secondary') +
                    '" data-code="' + escapeHtml(c.code) + '" style="font-size: 11px; padding: 1px 6px;">' +
                    escapeHtml(c.code) + ' <span class="text-muted">(' + c.order + ')</span></button>')
          .join('');
      }

      $('#formulaChips').on('click', '.formula-chip', function () {
        const code = this.dataset.code;
        const ta = modalFormula;
        const text = ta.value;
        const pos = ta.selectionStart !== undefined && document.activeElement === ta ? ta.selectionStart : text.length;
        const before = text.slice(0, pos).replace(/\s+$/, '');
        const after = text.slice(pos);
        const glue = before === '' || /[+\-*/(,]$/.test(before) ? (before === '' ? '' : ' ') : ' + ';
        ta.value = before + glue + code + (after.trim() ? ' ' + after.trim() : '');
        ta.focus();
        refreshUsesHint();
      });

      // live hint: what the formula uses and the order a total needs
      function refreshUsesHint() {
        const hint = document.getElementById('formulaUsesHint');
        const tokens = [...new Set(((modalFormula.value || '').toUpperCase().match(/[A-Z_][A-Z0-9_]*/g) || []))];
        const known = tokens.map(t => COMPONENT_LIST.find(c => c.code === t)).filter(Boolean);
        if (!known.length) { hint.innerHTML = ''; return; }
        const maxOrder = Math.max.apply(null, known.map(c => c.order));
        let html = '<span class="text-muted">Uses: ' + known.map(c => escapeHtml(c.code) + ' (' + c.order + ')').join(', ') + '.</span>';
        if (modalScope.value === 'AGGREGATE') {
          const mine = parseInt(modalCalcOrder.value, 10);
          const ok = !mine || mine > maxOrder;
          html += ' <span class="font-weight-bold ' + (ok ? 'text-success' : 'text-danger') + '">This total must be calculated after order ' +
                  maxOrder + (mine ? (ok ? ' &mdash; order ' + mine + ' is fine.' : ' &mdash; order ' + mine + ' is too early.') : ' (Auto picks it).') + '</span>';
        }
        hint.innerHTML = html;
      }
      modalFormula.addEventListener('input', refreshUsesHint);
      modalCalcOrder.addEventListener('input', refreshUsesHint);

      // list filters: all / pay components / totals / inactive
      let kindFilter = 'ALL';
      $.fn.dataTable.ext.search.push(function (settings, data, idx) {
        if (settings.nTable.id !== 'masterSalaryTable' || kindFilter === 'ALL') return true;
        const tr = settings.aoData[idx].nTr;
        if (kindFilter === 'INACTIVE') return tr.dataset.status !== 'ACTIVE';
        return tr.dataset.scope === kindFilter && tr.dataset.status === 'ACTIVE';
      });
      $('#kindFilters').on('click', '.kind-filter', function () {
        kindFilter = this.dataset.filter;
        $('#kindFilters .kind-filter').removeClass('pc-btn-primary');
        $(this).addClass('pc-btn-primary');
        dtTable.draw();
      });

      // 7. CHECK: validates formula, slabs and calculation order and recalculates
      //    every employee on the server, then saves nothing.
      $('#btnCheckComponent').on('click', function () {
        if (!salaryForm.reportValidity()) return;

        const btn = $(this);
        const originalHtml = btn.html();
        const formData = new FormData(salaryForm);
        formData.set('slabs', JSON.stringify(collectSlabs()));
        formData.set('dry_run', '1');
        const csrfName = $('meta[name="csrf-token-name"]').attr('content');
        const csrfHash = $('meta[name="csrf-token-hash"]').attr('content');
        if (csrfName && csrfHash && !formData.has(csrfName)) formData.append(csrfName, csrfHash);

        btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin mr-1"></i> Checking...');
        componentCheckResult.className = 'small font-weight-bold mt-2 text-muted';
        componentCheckResult.textContent = 'Checking against all employees...';

        $.ajax({
          url: manageSalCompUrl,
          type: 'POST',
          data: formData,
          processData: false,
          contentType: false,
          dataType: 'json',
          headers: { 'X-Requested-With': 'XMLHttpRequest' },
          success: function (res) {
            if (res.csrf_token) updateCsrf(csrfName, res.csrf_token);
            componentCheckResult.className = 'small font-weight-bold mt-2 ' + (res.status ? 'text-success' : 'text-danger');
            componentCheckResult.textContent = res.message || (res.status ? 'Check passed.' : 'Check failed.');
            renderFindings(res.findings);
            renderImpact(res.impact);
          },
          error: function (xhr) {
            componentCheckResult.className = 'small font-weight-bold mt-2 text-danger';
            componentCheckResult.textContent = extractErrorMessage(xhr, 'The check could not be run.');
            clearCheckOutput();
          },
          complete: function () {
            btn.prop('disabled', false).html(originalHtml);
          }
        });
      });
    });
  </script>
</body>

</html>