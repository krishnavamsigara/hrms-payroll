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
        ];
        return $map[$path] ?? $path;
    }
}

if (!function_exists('site_url')) {
    function site_url($path = '')
    {
        return base_url($path);
    }
}

if (!function_exists('esc')) {
    function esc($data)
    {
        return htmlspecialchars((string) $data, ENT_QUOTES, 'UTF-8');
    }
}

// Variables passed from controller step4() or request GET/POST - same as rest of the steps
$selectedMonth = isset($selectedMonth) ? (int) $selectedMonth : (int) ($_GET['month'] ?? ($_POST['month'] ?? date('n')));
$selectedYear = isset($selectedYear) ? (int) $selectedYear : (int) ($_GET['year'] ?? ($_POST['year'] ?? date('Y')));

if ($selectedMonth < 1 || $selectedMonth > 12) {
    $selectedMonth = (int) date('n');
}

if ($selectedYear < 2000 || $selectedYear > 2100) {
    $selectedYear = (int) date('Y');
}

$monthNames = [
    1 => 'January',
    2 => 'February',
    3 => 'March',
    4 => 'April',
    5 => 'May',
    6 => 'June',
    7 => 'July',
    8 => 'August',
    9 => 'September',
    10 => 'October',
    11 => 'November',
    12 => 'December',
];

$monthLabel = $monthNames[$selectedMonth] . ' ' . $selectedYear;

$periodStart = new DateTime(
    sprintf('%04d-%02d-01', $selectedYear, $selectedMonth)
);

$periodEnd = clone $periodStart;
$periodEnd->modify('last day of this month');

$targetPayDate = clone $periodEnd;
$targetPayDate->modify('+1 day');

// Procedure result parsing
$generatePayslip = $generate_payslip ?? null;
$payslipResult = [];

if (is_array($generatePayslip)) {
    // Supports a single associative result row or a list of rows.
    $payslipResult = isset($generatePayslip['status'])
        ? $generatePayslip
        : ($generatePayslip[0] ?? []);
}

$payslipStatus = strtoupper(
    trim((string) ($payslip_status ?? ($payslipResult['status'] ?? '')))
);

$payslipRemarks = (string) (
    $payslip_remarks ?? ($payslipResult['remarks'] ?? ($payslipResult['message'] ?? ''))
);

$payslipSubmitted = ($generatePayslip !== null) || !empty($payslipStatus);
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <title>BloomHR | Step 4: Final Payroll Summary</title>

    <link rel="icon" type="image/jpeg"
          href="<?= base_url('public/dist/img/bloom.jpg') ?>">

    <link rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">

    <link rel="stylesheet"
          href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">

    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">

    <link rel="stylesheet"
          href="https://cdnjs.cloudflare.com/ajax/libs/toastr.js/latest/toastr.min.css">

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

        .payroll-page {
            color: #334155;
            padding: 14px 20px 24px;
        }

        .payroll-page * {
            box-sizing: border-box;
        }

        .pc-card,
        .card-bloom {
            background: #fff;
            border: 1px solid var(--border-color) !important;
            border-radius: 16px !important;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.03) !important;
            margin-bottom: 1.25rem;
            overflow: hidden;
            transition: box-shadow 0.2s ease;
        }

        .pc-card:hover,
        .card-bloom:hover {
            box-shadow: 0 10px 20px -3px rgba(18, 0, 56, 0.06) !important;
        }

        .pc-body {
            padding: 20px;
        }

        .pc-heading {
            font-size: 22px;
            font-weight: 700;
            color: var(--bloom-dark);
            margin: 0 0 4px;
        }

        .pc-title {
            font-size: 16px;
            font-weight: 700;
            color: var(--bloom-dark);
            margin: 0;
        }

        .pc-muted {
            font-size: 12px;
            color: var(--text-muted);
            margin-bottom: 0;
        }

        .pc-label {
            font-size: 10px;
            text-transform: uppercase;
            letter-spacing: .06em;
            color: var(--text-muted);
            font-weight: 700;
        }

        .pc-top,
        .pc-flex,
        .pc-actions {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
        }

        .pc-top {
            align-items: flex-start;
            margin-bottom: 18px;
        }

        .pc-actions {
            justify-content: flex-start;
        }

        .pc-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 5px 11px;
            border-radius: 30px;
            font-size: 11px;
            font-weight: 700;
            white-space: nowrap;
        }

        .pc-purple,
        .badge-soft-primary {
            background: #eef2ff !important;
            color: var(--bloom-purple) !important;
        }

        .pc-green,
        .badge-soft-success {
            background: #dcfce7 !important;
            color: #15803d !important;
        }

        .pc-yellow,
        .badge-soft-warning {
            background: #fef3c7 !important;
            color: #b45309 !important;
        }

        .pc-red,
        .badge-soft-danger {
            background: #fee2e2 !important;
            color: #b91c1c !important;
        }

        .badge-soft-secondary {
            background: #f1f5f9 !important;
            color: #475569 !important;
        }

        .badge-soft-info {
            background: #e0f2fe !important;
            color: #0369a1 !important;
        }

        .pc-btn {
            border: 1px solid var(--border-color);
            border-radius: 9px;
            background: #fff;
            color: var(--text-dark);
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

        .pc-btn:disabled {
            opacity: .7;
            cursor: not-allowed;
            transform: none;
        }

        .pc-btn-primary {
            background: var(--bloom-purple) !important;
            border-color: var(--bloom-purple) !important;
            color: #fff !important;
            box-shadow: 0 3px 8px rgba(74, 0, 224, 0.2);
        }

        .pc-btn-primary:hover {
            background: var(--bloom-dark) !important;
            border-color: var(--bloom-dark) !important;
            color: #fff !important;
            transform: translateY(-1px);
        }

        .pc-btn-success {
            background: #10b981 !important;
            border-color: #10b981 !important;
            color: #fff !important;
            box-shadow: 0 3px 8px rgba(16, 185, 129, 0.25);
        }

        .pc-btn-success:hover {
            background: #059669 !important;
            border-color: #059669 !important;
            color: #fff !important;
            transform: translateY(-1px);
        }

        .pc-control {
            height: 38px;
            padding: 7px 11px;
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

        .pc-stepper {
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 16px;
        }

        .pc-step {
            position: relative;
        }

        .pc-step-top {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 10px;
        }

        .pc-step-number {
            width: 32px;
            height: 32px;
            flex-shrink: 0;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #f1f5f9;
            color: var(--text-muted);
            font-weight: 800;
            font-size: 13px;
        }

        .pc-step.completed .pc-step-number {
            background: #dcfce7;
            color: #15803d;
        }

        .pc-step.active .pc-step-number {
            background: var(--bloom-purple);
            color: #fff;
            box-shadow: 0 0 0 4px #eef2ff;
        }

        .pc-step-line {
            flex: 1;
            height: 3px;
            border-radius: 10px;
            background: var(--border-color);
        }

        .pc-step.completed .pc-step-line,
        .pc-step.active .pc-step-line {
            background: var(--bloom-purple);
        }

        .pc-step-title {
            font-size: 12px;
            font-weight: 700;
            color: var(--text-dark);
            margin: 4px 0 2px;
            line-height: 1.3;
        }

        .stat-card-mini {
            background: #fff;
            border: 1px solid var(--border-color);
            border-radius: 14px;
            padding: 16px;
            height: 100%;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            transition: all 0.2s ease;
        }

        .stat-card-mini:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 15px rgba(18, 0, 56, 0.05);
        }

        .stat-icon {
            width: 36px;
            height: 36px;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 15px;
            flex-shrink: 0;
        }

        .hero-metric-card {
            background: #fff;
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 20px;
            height: 100%;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }

        .progress-bloom {
            height: 8px;
            border-radius: 10px;
            background-color: #f1f5f9;
            overflow: hidden;
            display: flex;
        }

        .pc-bottom-bar {
            position: static !important;
            width: 100% !important;
            min-height: 70px !important;
            padding: 16px 24px !important;
            background: #fff !important;
            border: 1px solid var(--border-color) !important;
            border-radius: 16px !important;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.03) !important;
            margin-top: 1.5rem !important;
            margin-bottom: .5rem !important;
            display: flex !important;
            align-items: center !important;
            justify-content: space-between !important;
            gap: 12px;
            flex-wrap: wrap;
        }

        .pc-bottom-bar:hover {
            box-shadow: 0 10px 20px -3px rgba(18, 0, 56, 0.06) !important;
        }

        .modal-bloom-dialog {
            border-radius: 16px !important;
            overflow: hidden;
            border: 1px solid var(--border-color);
            box-shadow: 0 20px 40px rgba(18, 0, 56, 0.2);
        }

        .modal-bloom-header {
            background: linear-gradient(135deg, var(--bloom-purple), var(--bloom-dark));
            color: #fff;
            padding: 18px 24px;
            border-bottom: none;
        }

        #toast-success {
            position: fixed;
            top: 24px;
            right: 24px;
            z-index: 9999;
            min-width: 300px;
            max-width: calc(100vw - 32px);
            background: var(--bloom-dark);
            color: #fff;
            padding: 16px 20px;
            border-radius: 12px;
            box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
            display: none;
            align-items: center;
            gap: 14px;
        }

        .pc-result {
            border-radius: 12px;
            border: 1px solid var(--border-color);
            padding: 14px 16px;
            margin-bottom: 18px;
            background: #fff;
        }

        .pc-result pre {
            white-space: pre-wrap;
            overflow-wrap: anywhere;
            font-size: 12px;
            margin-top: 10px;
        }

        @media (max-width: 991.98px) {
            .pc-stepper {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        @media (max-width: 767.98px) {
            .pc-stepper {
                grid-template-columns: 1fr;
            }

            .payroll-page {
                padding: 10px;
            }

            .pc-bottom-bar {
                padding: 14px 16px !important;
                flex-direction: column;
                align-items: stretch;
            }

            .pc-bottom-bar .pc-btn {
                width: 100%;
            }

            .pc-top {
                flex-direction: column;
            }

            .pc-top > div:last-child {
                width: 100%;
            }

            .pc-top > div:last-child > * {
                margin-bottom: 6px;
            }

            #generatePayslipsForm {
                width: 100%;
            }

            #generatePayslipsForm button {
                width: 100%;
            }

            #toast-success {
                top: 12px;
                right: 12px;
                min-width: 0;
            }
        }

        @media print {
            .pc-actions,
            .pc-bottom-bar,
            #cycleFilterCard,
            .no-print,
            #completionModal,
            #toast-success {
                display: none !important;
            }

            body,
            .content-wrapper {
                background: #fff !important;
            }

            .payroll-page {
                padding: 0;
            }

            .pc-card,
            .hero-metric-card,
            .stat-card-mini {
                box-shadow: none !important;
                break-inside: avoid;
            }
        }
    </style>
</head>
<?php if ($generatePayslip !== null): ?>
        <div class="pc-result">
            <div class="d-flex align-items-start" style="gap: 12px;">
                <div class="stat-icon <?= $payslipStatus === 'Y'
                    ? 'badge-soft-success'
                    : 'badge-soft-danger' ?>">
                    <i class="fas <?= $payslipStatus === 'Y'
                        ? 'fa-check-circle'
                        : 'fa-exclamation-circle' ?>"></i>
                </div>

                <div class="flex-grow-1">
                    <h6 class="font-weight-bold text-dark mb-1">
                        Payslip Generation Result
                    </h6>

                    <span class="pc-badge <?= $payslipStatus === 'Y'
                        ? 'pc-green'
                        : 'pc-red' ?>">
                        Status: <?= esc($payslipStatus ?: 'UNKNOWN') ?>
                    </span>

                    <p class="mb-0 mt-2">
                        <?= esc($payslipRemarks ?: 'No remarks returned.') ?>
                    </p>
                </div>
            </div>
        </div>
<?php endif; ?>
<body class="hold-transition sidebar-mini layout-fixed">

<div class="content-wrapper">
    <div class="payroll-page">

        <!-- HEADER -->
        <div class="pc-top">
            <div>
                <div class="d-flex align-items-center flex-wrap"
                     style="gap: 8px; margin-bottom: 6px;">

                    <span class="pc-badge pc-purple">
                        <i class="fas fa-fingerprint"></i>
                        Payroll Summary
                    </span>

                    <span class="pc-badge pc-green">
                        <i class="fas fa-circle" style="font-size: 7px;"></i>
                        Final Review
                    </span>

                    <span class="pc-muted">Cycle Unit: Mumbai Regional HQ</span>
                </div>

                <h1 class="pc-heading">
                    Step 4: Final Summary, Dispatch &amp; Cycle Completion
                </h1>

                <p class="pc-muted">
                    <i class="far fa-calendar-alt text-primary mr-1"></i>
                    Period:
                    <strong>
                        <?= esc($periodStart->format('d M Y')) ?>
                        –
                        <?= esc($periodEnd->format('d M Y')) ?>
                    </strong>
                    &bull;
                    Target Pay Date:
                    <strong><?= esc($targetPayDate->format('d M Y')) ?></strong>
                </p>
            </div>

            <div class="pc-actions no-print">

                <button class="pc-btn"
                        type="button"
                        onclick="window.print()">
                    <i class="fas fa-print text-muted"></i>
                    Print Summary
                </button>

                <button class="pc-btn"
                        type="button"
                        id="saveDraftBtn">
                    <i class="fas fa-bookmark text-primary"></i>
                    Save Draft
                </button>

                <button class="pc-btn pc-btn-success"
                        type="button"
                        onclick="triggerCompletionModal()">
                    <i class="fas fa-lock mr-1"></i>
                    Authorize &amp; Seal
                </button>
            </div>
        </div>

        <!-- FOUR-STEP WORKFLOW -->
        <div class="pc-card">
            <div class="pc-body">
                <div class="pc-stepper">

                    <div class="pc-step completed">
                        <div class="pc-step-top">
                            <div class="pc-step-number">
                                <i class="fas fa-check"></i>
                            </div>
                            <div class="pc-step-line"></div>
                        </div>
                        <span class="pc-label text-success">Step 01 • Verified</span>
                        <div class="pc-step-title">Attendance Verification</div>
                        <p class="pc-muted">Attendance review</p>
                    </div>

                    <div class="pc-step completed">
                        <div class="pc-step-top">
                            <div class="pc-step-number">
                                <i class="fas fa-check"></i>
                            </div>
                            <div class="pc-step-line"></div>
                        </div>
                        <span class="pc-label text-success">Step 02 • Verified</span>
                        <div class="pc-step-title">Salary Structure Review</div>
                        <p class="pc-muted">Salary components review</p>
                    </div>

                    <div class="pc-step completed">
                        <div class="pc-step-top">
                            <div class="pc-step-number">
                                <i class="fas fa-check"></i>
                            </div>
                            <div class="pc-step-line"></div>
                        </div>
                        <span class="pc-label text-success">Step 03 • Verified</span>
                        <div class="pc-step-title">Master Calculation Grid</div>
                        <p class="pc-muted">Payroll calculation review</p>
                    </div>

                    <div class="pc-step active">
                        <div class="pc-step-top">
                            <div class="pc-step-number">4</div>
                        </div>
                        <span class="pc-label text-primary">Step 04 • Active</span>
                        <div class="pc-step-title">Final Summary &amp; Seal</div>
                        <p class="pc-muted">Final review</p>
                    </div>

                </div>
            </div>
        </div>

        <!-- CYCLE FILTER -->
        <div class="pc-card no-print" id="cycleFilterCard">
            <div class="pc-body py-3">
                <div class="d-flex align-items-center justify-content-between flex-wrap"
                     style="gap: 12px;">

                    <div class="d-flex align-items-center flex-wrap"
                         style="gap: 12px;">

                        <div class="d-flex align-items-center" style="gap: 6px;">
                            <i class="far fa-calendar-check text-primary"
                               style="font-size: 16px;"></i>
                            <span class="font-weight-bold" style="font-size: 13px;">
                                Cycle Period:
                            </span>
                        </div>

                        <select id="selectMonth"
                                class="pc-control"
                                style="width: 140px;">

                            <?php foreach ($monthNames as $number => $name): ?>
                                    <option value="<?= $number ?>"
                                        <?= $selectedMonth === $number ? 'selected' : '' ?>>
                                        <?= esc($name) ?>
                                    </option>
                            <?php endforeach; ?>
                        </select>

                        <select id="selectYear"
                                class="pc-control"
                                style="width: 110px;">

                            <?php
                            $currentYear = (int) date('Y');
                            $minYear = min(2020, $selectedYear);
                            $maxYear = max($currentYear + 1, $selectedYear);
                            ?>

                            <?php for ($y = $maxYear; $y >= $minYear; $y--): ?>
                                    <option value="<?= $y ?>"
                                        <?= $selectedYear === $y ? 'selected' : '' ?>>
                                        <?= $y ?>
                                    </option>
                            <?php endfor; ?>
                        </select>

                        <button type="button"
                                class="pc-btn pc-btn-primary"
                                id="applyCycleFilter">
                            <i class="fas fa-filter"></i>
                            Apply Filter
                        </button>
                    </div>

                    <div class="d-flex align-items-center" style="gap: 8px;">
                        <span class="pc-label">Cycle Run State:</span>
                        <span class="pc-badge pc-green">
                            <i class="fas fa-clipboard-check"></i>
                            <?= esc($monthLabel) ?> • Final Review
                        </span>
                    </div>
                </div>
            </div>
        </div>

        <!-- EXECUTIVE REVIEW KPI CARDS -->
        <div class="row mb-3">

            <!-- TOTAL PAYROLL SUMMARY -->
            <div class="col-xl-5 col-lg-6 mb-3 mb-xl-0">
                <div class="hero-metric-card">
                    <div class="d-flex align-items-center justify-content-between mb-2 flex-wrap"
                         style="gap: 8px;">

                        <div class="d-flex align-items-center" style="gap: 8px;">
                            <div class="stat-icon badge-soft-success">
                                <i class="fas fa-wallet text-success"></i>
                            </div>
                            <div>
                                <h6 class="font-weight-bold mb-0 text-dark">
                                    Total Net Disbursal Amount
                                </h6>
                                <small class="text-muted">
                                    Master Net Disbursal Pool
                                </small>
                            </div>
                        </div>

                        <span class="pc-badge pc-green">Net Payout</span>
                    </div>

                    <div class="my-3">
                        <div class="font-weight-bold text-success"
                             style="font-size: 32px; letter-spacing: -0.5px;">
                            ₹ 76,16,350
                        </div>
                        <small class="text-muted">
                            <?= esc($monthLabel) ?>
                        </small>
                    </div>

                    <div class="p-3 rounded"
                         style="background: #f8fafc; border: 1px solid var(--border-color);">

                        <div class="d-flex justify-content-between align-items-center mb-1">
                            <span class="text-muted" style="font-size: 12px;">
                                Total Gross Payroll Pool
                            </span>
                            <strong class="text-dark" style="font-size: 13px;">
                                ₹ 84,50,000
                            </strong>
                        </div>

                        <div class="progress-bloom mb-2">
                            <div style="width: 90.13%; background-color: #10b981;"
                                 title="Net Payout"></div>
                            <div style="width: 9.87%; background-color: #dc2626;"
                                 title="Total Deductions"></div>
                        </div>

                        <div class="d-flex justify-content-between align-items-center pt-1 border-top">
                            <div class="d-flex align-items-center" style="gap: 6px;">
                                <span style="width: 8px; height: 8px; border-radius: 50%; background: #dc2626; display: inline-block;"></span>
                                <span class="text-muted" style="font-size: 11.5px;">
                                    Total Deductions
                                </span>
                            </div>
                            <strong class="text-danger" style="font-size: 12px;">
                                ₹ 8,33,650
                            </strong>
                        </div>

                        <div class="d-flex justify-content-between align-items-center pl-3 mt-1">
                            <small class="text-muted">Statutory deductions</small>
                            <small class="text-dark font-weight-bold">₹ 7,85,450</small>
                        </div>

                        <div class="d-flex justify-content-between align-items-center pl-3">
                            <small class="text-muted">Loss of Pay deductions</small>
                            <small class="text-dark font-weight-bold">₹ 48,200</small>
                        </div>
                    </div>
                </div>
            </div>

            <!-- WORKFORCE SUMMARY -->
            <div class="col-xl-3 col-lg-6 col-sm-6 mb-3 mb-xl-0">
                <div class="stat-card-mini">
                    <div>
                        <div class="d-flex align-items-center justify-content-between mb-2 flex-wrap"
                             style="gap: 8px;">

                            <div class="d-flex align-items-center" style="gap: 8px;">
                                <div class="stat-icon badge-soft-primary">
                                    <i class="fas fa-users text-primary"></i>
                                </div>
                                <span class="font-weight-bold text-dark">
                                    Workforce Count
                                </span>
                            </div>

                            <span class="badge badge-soft-success">Review</span>
                        </div>

                        <div class="my-2">
                            <div class="font-weight-bold text-dark"
                                 style="font-size: 26px;">
                                123
                            </div>
                            <small class="text-muted">Employee Profiles</small>
                        </div>

                        <div class="p-2 rounded mt-3"
                             style="background: #f8fafc; font-size: 12px;">

                            <div class="d-flex justify-content-between py-1">
                                <span class="text-muted">Variance Errors:</span>
                                <span class="badge badge-soft-success">0 Errors</span>
                            </div>

                            <div class="d-flex justify-content-between py-1">
                                <span class="text-muted">LOP Adjustments:</span>
                                <span class="text-primary font-weight-bold">3 Profiles</span>
                            </div>

                            <div class="d-flex justify-content-between py-1">
                                <span class="text-muted">New Joinees:</span>
                                <span class="text-dark font-weight-bold">4 Profiles</span>
                            </div>
                        </div>
                    </div>

                    <div class="pt-2 border-top mt-2 d-flex align-items-center justify-content-between flex-wrap"
                         style="gap: 6px;">
                        <small class="text-muted">Bank Validation:</small>
                        <span class="text-success font-weight-bold" style="font-size: 11px;">
                            <i class="fas fa-check-circle mr-1"></i>
                            123/123 Valid IFSC
                        </span>
                    </div>
                </div>
            </div>

            <!-- ATTENDANCE CUTOFF -->
            <div class="col-xl-2 col-lg-6 col-sm-6 mb-3 mb-xl-0">
                <div class="stat-card-mini">
                    <div>
                        <div class="d-flex align-items-center"
                             style="gap: 8px; margin-bottom: 8px;">

                            <div class="stat-icon badge-soft-info">
                                <i class="far fa-calendar-alt text-info"></i>
                            </div>
                            <span class="font-weight-bold text-dark">Attendance</span>
                        </div>

                        <div class="my-2">
                            <h6 class="font-weight-bold mb-0">
                                <?= esc($monthLabel) ?>
                            </h6>
                            <span class="pc-label text-muted">Selected Period</span>
                        </div>

                        <div class="p-2 rounded mt-2 text-center"
                             style="background: #f8fafc;">

                            <div class="font-weight-bold" style="font-size: 12px;">
                                <?= esc($periodStart->format('d M Y')) ?>
                            </div>

                            <i class="fas fa-arrow-down text-muted my-1"
                               style="font-size: 11px;"></i>

                            <div class="font-weight-bold" style="font-size: 12px;">
                                <?= esc($periodEnd->format('d M Y')) ?>
                            </div>
                        </div>
                    </div>

                    <div class="pt-2 border-top mt-2 text-center">
                        <span class="pc-badge pc-green" style="font-size: 10.5px;">
                            <i class="fas fa-calendar-check"></i>
                            Period Selected
                        </span>
                    </div>
                </div>
            </div>

            <!-- PAYMENT SCHEDULE -->
            <div class="col-xl-2 col-lg-6 col-sm-6">
                <div class="stat-card-mini">
                    <div>
                        <div class="d-flex align-items-center"
                             style="gap: 8px; margin-bottom: 8px;">

                            <div class="stat-icon badge-soft-warning">
                                <i class="fas fa-calendar-check text-warning"></i>
                            </div>
                            <span class="font-weight-bold text-dark">Schedule</span>
                        </div>

                        <div class="my-2">
                            <h6 class="font-weight-bold mb-0">Disbursement</h6>
                            <span class="pc-label text-muted">Target Pay Date</span>
                        </div>

                        <div class="p-2 rounded mt-2 text-center"
                             style="background: #eef2ff;">

                            <div class="font-weight-bold text-primary"
                                 style="font-size: 18px;">
                                <?= esc($targetPayDate->format('d M')) ?>
                            </div>

                            <small class="text-muted">
                                <?= esc($targetPayDate->format('Y')) ?>
                            </small>
                        </div>
                    </div>

                    <div class="pt-2 border-top mt-2 text-center">
                        <small class="text-muted">
                            <i class="fas fa-calendar-alt text-primary mr-1"></i>
                            Planned Date
                        </small>
                    </div>
                </div>
            </div>
        </div>

        <!-- GENERATE PAYSLIPS ACTION SECTION (Placed directly after KPI Cards) -->
        <div class="pc-card mb-4 no-print" id="generatePayslipSection" style="border: 1px solid rgba(74, 0, 224, 0.18); box-shadow: 0 6px 24px rgba(74, 0, 224, 0.08); border-radius: 16px; overflow: hidden;">
            <div class="pc-body p-4" style="background: linear-gradient(180deg, #ffffff 0%, #faf8ff 100%);">
                <div class="d-flex align-items-center justify-content-between flex-wrap" style="gap: 16px;">
                    <div class="d-flex align-items-center" style="gap: 16px;">
                        <div class="stat-icon" style="background: linear-gradient(135deg, var(--bloom-purple), var(--bloom-dark)); color: #fff; width: 54px; height: 54px; border-radius: 14px; display: flex; align-items: center; justify-content: center; font-size: 22px; box-shadow: 0 8px 18px rgba(74, 0, 224, 0.28); flex-shrink: 0;">
                            <i class="fas fa-file-invoice-dollar"></i>
                        </div>
                        <div>
                            <h5 class="font-weight-bold mb-1" style="color: var(--bloom-dark); font-size: 17px;">
                                Generate &amp; Issue Payslips
                            </h5>
                            <p class="text-muted mb-0" style="font-size: 13px;">
                                Execute stored procedure to calculate and finalize employee payslips for <strong><?= esc($monthLabel) ?></strong>.
                            </p>
                        </div>
                    </div>

                    <div>
                        <form method="post" action="<?= site_url('payroll/step4') ?>" id="generatePayslipsForm" class="m-0">
                            <?= function_exists('csrf_field') ? csrf_field() : '' ?>
                            <input type="hidden" name="month" id="generateMonth" value="<?= esc((string) $selectedMonth) ?>">
                            <input type="hidden" name="year" id="generateYear" value="<?= esc((string) $selectedYear) ?>">

                            <button class="pc-btn pc-btn-primary" type="submit" id="generatePayslipsBtn" style="padding: 12px 28px; font-size: 14px; font-weight: 700; border-radius: 10px; box-shadow: 0 4px 14px rgba(74, 0, 224, 0.35);">
                                <i class="fas fa-file-invoice-dollar mr-2"></i>
                                Generate Payslip
                            </button>
                        </form>
                    </div>
                </div>

                <div id="procedureStatusBanner" style="<?= $payslipSubmitted ? '' : 'display: none;' ?> margin-top: 16px; padding: 12px 18px; border-radius: 10px; background: <?= $payslipStatus === 'Y' ? '#ecfdf5; border: 1px solid #a7f3d0; color: #065f46;' : '#fef2f2; border: 1px solid #fecaca; color: #991b1b;' ?> font-size: 13px;">
                    <div class="d-flex align-items-center justify-content-between flex-wrap" style="gap: 10px;">
                        <div class="d-flex align-items-center" style="gap: 10px;">
                            <i class="<?= $payslipStatus === 'Y' ? 'fas fa-check-circle text-success' : 'fas fa-exclamation-circle text-danger' ?>" style="font-size: 18px;" id="bannerStatusIcon"></i>
                            <span id="bannerStatusText">
                                <strong>Procedure Status (<?= esc($payslipStatus ?: 'RESPONSE') ?>):</strong>
                                <span id="bannerStatusRemarks"><?= esc($payslipRemarks ?: 'Payslips generated successfully.') ?></span>
                            </span>
                        </div>
                        <span class="badge <?= $payslipStatus === 'Y' ? 'badge-success' : 'badge-danger' ?> px-3 py-1 font-weight-bold" id="bannerStatusBadge" style="border-radius: 20px;">
                            <?= esc($payslipStatus === 'Y' ? 'SUCCESS' : 'STATUS ' . ($payslipStatus ?: 'NOTICE')) ?>
                        </span>
                    </div>
                </div>
            </div>
        </div>

        <!-- WORKFLOW ACTION BAR -->
        <div class="pc-bottom-bar">
            <div>
                <a href="<?= site_url('payroll/step3') ?>?month=<?= esc((string) $selectedMonth) ?>&amp;year=<?= esc((string) $selectedYear) ?>"
                   class="pc-btn">
                    <i class="fas fa-arrow-left mr-1"></i>
                    Back to Step 3: Master Calculation Grid
                </a>
            </div>

            <div class="d-none d-md-flex align-items-center" style="gap: 16px;">
                <div class="text-right">
                    <div class="font-weight-bold"
                         style="font-size: 13px; color: var(--bloom-dark);">
                        <i class="fas fa-clipboard-check text-success mr-1"></i>
                        Final Payroll Review
                    </div>
                    <small class="text-muted">
                        Selected period: <strong><?= esc($monthLabel) ?></strong>
                    </small>
                </div>
            </div>

            <div class="no-print">
                <button type="button"
                        class="pc-btn pc-btn-success"
                        onclick="triggerCompletionModal()">
                    <i class="fas fa-stamp mr-1"></i>
                    Authorize &amp; Seal Cycle
                </button>
            </div>
        </div>

    </div>
</div>

<!-- AUTHORIZATION CONFIRMATION MODAL -->
<div class="modal fade"
     id="completionModal"
     tabindex="-1"
     role="dialog"
     aria-labelledby="completionModalTitle"
     aria-hidden="true">

    <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content modal-bloom-dialog">

            <div class="modal-bloom-header d-flex justify-content-between align-items-center">
                <div class="d-flex align-items-center" style="gap: 10px;">
                    <i class="fas fa-lock" style="font-size: 20px;"></i>
                    <h5 class="modal-title font-weight-bold mb-0 text-white"
                        id="completionModalTitle">
                        Authorize <?= esc($monthLabel) ?> Closure
                    </h5>
                </div>

                <button type="button"
                        class="close text-white"
                        data-dismiss="modal"
                        aria-label="Close"
                        style="opacity: .9;">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>

            <div class="modal-body p-4">
                <p class="text-muted mb-3" style="font-size: 12.5px;">
                    Confirm that you have reviewed the payroll details for
                    <strong><?= esc($monthLabel) ?></strong>.
                </p>

                <div class="p-3 rounded mb-3"
                     style="background: #f8fafc; border: 1px solid var(--border-color); font-size: 12.5px;">

                    <div class="d-flex justify-content-between py-1">
                        <span class="text-muted">Payroll Period:</span>
                        <strong class="text-dark"><?= esc($monthLabel) ?></strong>
                    </div>

                    <div class="d-flex justify-content-between py-1">
                        <span class="text-muted">Period End:</span>
                        <strong class="text-dark">
                            <?= esc($periodEnd->format('d M Y')) ?>
                        </strong>
                    </div>

                    <div class="d-flex justify-content-between py-1">
                        <span class="text-muted">Target Pay Date:</span>
                        <strong class="text-dark">
                            <?= esc($targetPayDate->format('d M Y')) ?>
                        </strong>
                    </div>
                </div>

                <div class="alert alert-warning py-2 px-3 mb-0"
                     style="font-size: 11.5px; border-radius: 8px;">
                    <i class="fas fa-exclamation-triangle mr-1"></i>
                    Payroll authorization may be irreversible. Ensure that the
                    attendance and salary calculations are correct before proceeding.
                </div>

                <p class="text-muted mt-3 mb-0" style="font-size: 11px;">
                    This confirmation dialog does not seal the payroll cycle by itself.
                    Connect it to your authorization backend before using it for a
                    real payroll closure.
                </p>
            </div>

            <div class="modal-footer px-4 py-3"
                 style="background: #fafbfe; border-top: 1px solid var(--border-color);">

                <button type="button"
                        class="pc-btn"
                        data-dismiss="modal">
                    Cancel &amp; Review
                </button>

                <button type="button"
                        id="confirm-lock-btn"
                        class="pc-btn pc-btn-success"
                        onclick="executeFinalLock()">
                    <i class="fas fa-stamp mr-1"></i>
                    Confirm &amp; Seal
                </button>
            </div>
        </div>
    </div>
</div>

<!-- SAVE DRAFT / STATUS TOAST -->
<div id="toast-success">
    <div style="width: 38px; height: 38px; border-radius: 50%; background: #10b981; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
        <i class="fas fa-check" style="font-size: 18px; color: #fff;"></i>
    </div>

    <div>
        <div class="font-weight-bold" style="font-size: 14px;" id="toast-title">
            Action completed
        </div>
        <div style="font-size: 12px; color: #cbd5e1;" id="toast-message">
            Your action has been processed.
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
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

    function triggerCompletionModal() {
        $('#completionModal').modal('show');
    }

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

    function reloadWithFilter() {
        const month = document.getElementById('selectMonth').value;
        const year = document.getElementById('selectYear').value;

        const url = new URL(
            <?= json_encode(site_url('payroll/step4')) ?>,
            window.location.origin
        );

        url.searchParams.set('month', month);
        url.searchParams.set('year', year);

        window.location.href = url.toString();
    }

    // Apply the selected month/year by reloading Step 4
    document.getElementById('applyCycleFilter').addEventListener('click', reloadWithFilter);
    document.getElementById('selectMonth').addEventListener('change', reloadWithFilter);
    document.getElementById('selectYear').addEventListener('change', reloadWithFilter);

    function updateStatusBanner(status, remarks) {
        const banner = $('#procedureStatusBanner');
        const icon = $('#bannerStatusIcon');
        const remarksElem = $('#bannerStatusRemarks');
        const badge = $('#bannerStatusBadge');

        const isSuccess = (status === 'Y' || status === 'SUCCESS');

        banner.show();
        if (isSuccess) {
            banner.css({ 'background': '#ecfdf5', 'border': '1px solid #a7f3d0', 'color': '#065f46' });
            icon.attr('class', 'fas fa-check-circle text-success');
            badge.attr('class', 'badge badge-success px-3 py-1 font-weight-bold').text('SUCCESS');
        } else {
            banner.css({ 'background': '#fef2f2', 'border': '1px solid #fecaca', 'color': '#991b1b' });
            icon.attr('class', 'fas fa-exclamation-circle text-danger');
            badge.attr('class', 'badge badge-danger px-3 py-1 font-weight-bold').text('STATUS ' + status);
        }
        remarksElem.text(remarks);
    }

    // Generate Payslips: submit via AJAX and show procedure status & remarks as toaster at top right
    $('#generatePayslipsForm').on('submit', function (event) {
        event.preventDefault();
        const btn = $('#generatePayslipsBtn');
        const originalHtml = btn.html();

        btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin mr-2"></i> Generating Payslips...');

        const formAction = $(this).attr('action') || window.location.href;
        const formData = $(this).serialize();

        $.ajax({
            url: formAction,
            type: 'POST',
            data: formData,
            dataType: 'json',
            headers: {
                'X-Requested-With': 'XMLHttpRequest'
            },
            success: function (res) {
                btn.prop('disabled', false).html(originalHtml);
                const status = (res.status || 'Y').toUpperCase();
                const remarks = res.remarks || res.message || 'Payslips generated successfully.';

                if (status === 'Y') {
                    showToast('Payslips Generated', remarks, 'success');
                } else {
                    showToast('Procedure Result (' + status + ')', remarks, 'error');
                }
                updateStatusBanner(status, remarks);
            },
            error: function (xhr) {
                btn.prop('disabled', false).html(originalHtml);
                const res = xhr.responseJSON || {};
                const status = (res.status || 'N').toUpperCase();
                const remarks = res.remarks || res.message || 'Server error occurred while executing procedure.';

                showToast('Procedure Execution Failed', remarks, 'error');
                updateStatusBanner(status, remarks);
            }
        });
    });

    // Save Draft feedback
    document.getElementById('saveDraftBtn').addEventListener('click', function () {
        showToast(
            'Draft Notice',
            'Payroll calculation draft state is cached for this review session.',
            'info'
        );
    });

    // Authorization seal dialog confirmation
   
    function executeFinalLock() {
        const month = <?= json_encode($selectedMonth) ?>;
        const year  = <?= json_encode($selectedYear) ?>;

        const confirmButton = $('#confirm-lock-btn');

        confirmButton
            .prop('disabled', true)
            .html('<i class="fas fa-spinner fa-spin mr-1"></i> Redirecting...');

        // Redirect to the payslips page for the selected payroll cycle.
        const payslipsUrl = new URL(
            <?= json_encode(site_url('payroll/payslips_new')) ?>,
            window.location.origin
        );

        payslipsUrl.searchParams.set('month', month);
        payslipsUrl.searchParams.set('year', year);

        $('#completionModal').modal('hide');

        window.location.href = payslipsUrl.toString();
    }


    $(document).ready(function () {
        <?php if ($payslipSubmitted): ?>
            const initialStatus = <?= json_encode($payslipStatus) ?>;
            const initialRemarks = <?= json_encode($payslipRemarks ?: 'Payslips generated successfully.') ?>;
            if (initialStatus === 'Y') {
                showToast('Payslips Generated', initialRemarks, 'success');
            } else if (initialStatus) {
                showToast('Procedure Result (' + initialStatus + ')', initialRemarks, 'error');
            }
        <?php endif; ?>

        <?php if (function_exists('session') && session()->getFlashdata('error')): ?>
            showToast('Error', <?= json_encode(session()->getFlashdata('error')) ?>, 'error');
        <?php endif; ?>

        <?php if (function_exists('session') && session()->getFlashdata('success')): ?>
            showToast('Success', <?= json_encode(session()->getFlashdata('success')) ?>, 'success');
        <?php endif; ?>
    });
</script>

</body>
</html>
