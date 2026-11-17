<?php
$content = $content ?? [];
$cnt = !empty($content[0]) ? $content[0] : (!empty($payslip) ? $payslip : []);

$monthNames = [
    1  => "January",
    2  => "February",
    3  => "March",
    4  => "April",
    5  => "May",
    6  => "June",
    7  => "July",
    8  => "August",
    9  => "September",
    10 => "October",
    11 => "November",
    12 => "December"
];

$monthRaw = $cnt['payroll_month'] ?? $month ?? date('n');
$yearRaw  = $cnt['payroll_year'] ?? $year ?? date('Y');

if (is_numeric($monthRaw)) {
    $monthNum  = (int) $monthRaw;
    $monthName = $monthNames[$monthNum] ?? date('F');
} else {
    $monthName = !empty($monthRaw) ? trim($monthRaw) : date('F');
    $monthNum  = array_search(ucfirst(strtolower($monthName)), $monthNames) ?: (int) date('n');
}
$yearNum = (int) $yearRaw;

if (!function_exists('convertNumberToWords')) {
    function convertNumberToWords($number)
    {
        $number = (float) $number;
        if (class_exists('NumberFormatter')) {
            try {
                $fmt = new NumberFormatter("en_IN", NumberFormatter::SPELLOUT);
                return ucwords($fmt->format($number));
            } catch (\Exception $e) {
                return (string) $number;
            }
        }
        return (string) $number;
    }
}

if (!function_exists('number_format_indian')) {
    function number_format_indian($number)
    {
        $number = (string) round((float) $number);
        $length = strlen($number);

        if ($length <= 3) {
            return $number;
        }

        $lastThree = substr($number, -3);
        $restUnits = substr($number, 0, $length - 3);
        $restUnits = preg_replace("/\B(?=(\d{2})+(?!\d))/", ",", $restUnits);

        return $restUnits . "," . $lastThree;
    }
}

// ==========================================
// DYNAMIC COMPONENTS EXTRACTION
// ==========================================
$componentsRaw = $cnt['components'] ?? '[]';
if (is_string($componentsRaw)) {
    $componentsList = json_decode($componentsRaw, true);
    if (!is_array($componentsList)) {
        $componentsList = [];
    }
} elseif (is_array($componentsRaw)) {
    $componentsList = $componentsRaw;
} else {
    $componentsList = [];
}

// Categorize all components dynamically
$earningsList              = [];
$deductionsList            = [];
$employerContributionsList = [];

if (!empty($componentsList)) {
    foreach ($componentsList as $item) {
        $cType = strtoupper(trim((string) ($item['component_type'] ?? '')));
        $cName = trim((string) ($item['component_name'] ?? ''));
        $cAmt  = (float) ($item['calculated_amount'] ?? 0);

        if ($cType === 'EARNING') {
            $earningsList[] = [
                'name'   => $cName,
                'amount' => $cAmt
            ];
        } elseif ($cType === 'DEDUCTION') {
            $deductionsList[] = [
                'name'   => $cName,
                'amount' => $cAmt
            ];
        } elseif ($cType === 'EMPLOYER_CONTRIBUTION' || $cType === 'CONTRIBUTION') {
            $employerContributionsList[] = [
                'name'   => $cName,
                'amount' => $cAmt
            ];
        }
    }
}

// Totals of the month (GROSS, NET_PAY, TOTAL_CTC ...) from hrms_get_payslip.totals.
// Gross, deductions, employer contribution and net pay already have their own rows;
// any other total (TOTAL_CTC or a total added later) is listed under "Other totals".
$totalsRaw = $cnt['totals'] ?? '[]';
$totalsList = is_string($totalsRaw) ? (json_decode($totalsRaw, true) ?: []) : (is_array($totalsRaw) ? $totalsRaw : []);
$otherTotals = [];
foreach ($totalsList as $t) {
    $tCode = strtoupper(trim((string) ($t['component_code'] ?? '')));
    if ($tCode !== '' && !in_array($tCode, ['GROSS', 'TOTAL_DEDUCTIONS', 'TOTAL_EMPLOYER_CONTRIBUTION', 'NET_PAY'], true)) {
        $otherTotals[] = ['name' => trim((string) ($t['component_name'] ?? $tCode)), 'amount' => (float) ($t['calculated_amount'] ?? 0)];
    }
}

// Fallback to legacy $earnings / $deductions if components JSON was empty
if (empty($earningsList) && !empty($earnings)) {
    foreach ($earnings as $e) {
        $earningsList[] = [
            'name'   => $e['allowance_name'] ?? $e['allowance'] ?? $e['name'] ?? $e['component_name'] ?? 'Earning',
            'amount' => (float) ($e['amount'] ?? $e['a_amount'] ?? $e['calculated_amount'] ?? 0)
        ];
    }
}
if (empty($deductionsList) && !empty($deductions)) {
    foreach ($deductions as $d) {
        $deductionsList[] = [
            'name'   => $d['deduction_name'] ?? $d['deduction'] ?? $d['name'] ?? $d['component_name'] ?? 'Deduction',
            'amount' => (float) ($d['d_amount'] ?? $d['amount'] ?? $d['calculated_amount'] ?? 0)
        ];
    }
}

// Totals calculation
$grossEarnings = isset($cnt['gross_earnings']) ? (float) $cnt['gross_earnings'] : 0;
if ($grossEarnings <= 0 && !empty($earningsList)) {
    foreach ($earningsList as $e) {
        $grossEarnings += (float) $e['amount'];
    }
}

$totalDeductions = isset($cnt['total_deductions']) ? (float) $cnt['total_deductions'] : 0;
if ($totalDeductions <= 0 && !empty($deductionsList)) {
    foreach ($deductionsList as $d) {
        $totalDeductions += (float) $d['amount'];
    }
}

$employerContributionsTotal = isset($cnt['employer_contributions']) ? (float) $cnt['employer_contributions'] : 0;
if ($employerContributionsTotal <= 0 && !empty($employerContributionsList)) {
    foreach ($employerContributionsList as $ec) {
        $employerContributionsTotal += (float) $ec['amount'];
    }
}

$netPay = isset($cnt['net_pay']) ? (float) $cnt['net_pay'] : max(0, $grossEarnings - $totalDeductions);

// Calculate maximum rows between Earnings and Deductions to keep side-by-side tables aligned
$maxTableRows = max(count($earningsList), count($deductionsList));
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Bloom Solutions | Employee Payslip</title>
    <link rel="icon" type="image/jpeg" href="<?= base_url('public/dist/img/bloom.jpg') ?>">

    <style>
        :root {
            --bloom-purple: #4a00e0;
            --bloom-dark: #120038;
            --text-dark: #111827;
            --border-grid: #475569;
            --deductions-header: #475569;
        }

        .print-trigger-bar {
            background: #ffffff;
            padding: 12px;
            text-align: right;
            border-bottom: 1px solid #e2e8f0;
        }

        .btn-action {
            background: #4A00E0;
            color: #fff;
            border: none;
            border-radius: 8px;
            padding: 10px 18px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: .3s;
            box-shadow: 0 4px 10px rgba(74, 0, 224, .25);
        }

        .btn-action:hover {
            background: #3600B3;
            transform: translateY(-2px);
        }

        .payslip-wrapper {
            width: 100%;
            display: flex;
            justify-content: center;
            align-items: flex-start;
            padding: 20px;
        }

        .payslip-main-sheet {
            width: 100%;
            max-width: 900px;
            margin: 0 auto;
            background: #ffffff;
            border: 2px solid var(--border-grid);
            border-radius: 12px;
            overflow: hidden;
            position: relative;
            z-index: 1;
            padding: 35px;
        }

        /* Watermark Layer setup */
        .watermark-layer {
            position: absolute;
            top: 52%;
            left: 50%;
            transform: translate(-50%, -50%) rotate(-5deg);
            width: 440px;
            height: 440px;
            pointer-events: none;
            opacity: 0.16;
            z-index: 0;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .watermark-img {
            width: 100%;
            height: 100%;
            object-fit: contain;
        }

        .office-header-container {
            text-align: center;
            margin-bottom: 25px;
            position: relative;
            z-index: 2;
        }

        .office-logo-img {
            width: 55px;
            height: 55px;
            object-fit: contain;
            margin-bottom: 8px;
        }

        .office-brand-title {
            font-size: 32px;
            font-weight: 700;
            margin: 0 0 6px 0;
            letter-spacing: -0.5px;
        }

        .brand-blue {
            color: #0056b3;
        }

        .brand-red {
            color: #d9383a;
        }

        .office-header-sub {
            font-size: 13px;
            color: #334155;
            margin: 0 0 10px 0;
            line-height: 1.4;
            font-weight: 400;
        }

        .office-document-title {
            font-size: 15px;
            font-weight: 700;
            color: #0f172a;
            margin-top: 5px;
            display: block;
        }

        /* Transparent Table Grid Structure */
        .matrix-table {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
            margin-bottom: 15px;
            position: relative;
            z-index: 2;
            background: transparent;
            border: 1px solid var(--border-grid);
            border-radius: 10px;
            overflow: hidden;
        }

        .matrix-table th,
        .matrix-table td {
            border-right: 1px solid var(--border-grid);
            border-bottom: 1px solid var(--border-grid);
            padding: 10px 14px;
            font-size: 13px;
            vertical-align: middle;
            background: transparent !important;
        }

        .matrix-table tr:last-child td {
            border-bottom: none;
        }

        .matrix-table tr td:last-child,
        .matrix-table tr th:last-child {
            border-right: none;
        }

        .field-label {
            font-weight: 600;
            color: #475569;
            width: 22%;
        }

        .field-value {
            color: var(--text-dark);
            font-weight: 500;
            width: 28%;
        }

        /* Clean Earnings Header */
        .earnings-header-heading {
            background-color: #f1f5f9 !important;
            color: var(--text-dark);
            font-weight: 700;
            font-size: 13px;
            letter-spacing: 0.3px;
        }

        .earnings-header-amount {
            background-color: #f1f5f9 !important;
            color: #475569;
            font-weight: 700;
            font-size: 13px;
            text-align: right;
        }

        /* Deductions Header Background */
        .deductions-header-heading {
            background-color: var(--deductions-header) !important;
            color: #ffffff !important;
            font-weight: 700;
            font-size: 13px;
            letter-spacing: 0.5px;
        }

        .deductions-header-amount {
            background-color: var(--deductions-header) !important;
            color: #ffffff !important;
            font-weight: 700;
            font-size: 13px;
            text-align: right;
        }

        .num-col {
            text-align: right;
            font-weight: 600;
            font-variant-numeric: tabular-nums;
        }

        .row-total-accent td {
            background-color: #f8fafc !important;
            color: var(--text-dark) !important;
            font-size: 13px;
            font-weight: 700 !important;
        }

        .net-pay-row td {
            background: #faf5ff !important;
            color: var(--bloom-purple) !important;
            font-size: 16px;
            font-weight: 800 !important;
        }

        .disclaimer-text {
            text-align: center;
            font-size: 11px;
            color: #64748b;
            margin-top: 25px;
            position: relative;
            z-index: 2;
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
            display: inline-flex;
            align-items: center;
            text-decoration: none;
        }

        .btn-bloom-back:hover {
            background: linear-gradient(135deg,
                    var(--bloom-purple) 0%,
                    var(--bloom-dark) 100%);
            color: #fff !important;
            border-color: var(--bloom-purple);
            transform: translateY(-1px);
            box-shadow: 0 4px 10px rgba(74, 0, 224, 0.20);
        }

        .btn-bloom-back i {
            font-size: 11px;
        }

        /* Print Media Styles */
        @media print {
            .btn-bloom-back, .print-trigger-bar, #pdfControls, .main-header, .main-sidebar, .main-footer {
                display: none !important;
            }
            .content-wrapper {
                margin: 0 !important;
                padding: 0 !important;
                background: #ffffff !important;
            }
            .payslip-wrapper {
                padding: 0 !important;
            }
            .payslip-main-sheet {
                border: none !important;
                padding: 10px !important;
                box-shadow: none !important;
                max-width: 100% !important;
            }
        }

        /* Mobile Responsiveness */
        @media (max-width: 767.98px) {
            .content-wrapper { padding: 10px !important; }
            .payslip-wrapper { padding: 10px !important; }
            .payslip-main-sheet { padding: 15px !important; border-radius: 10px !important; max-width: 100% !important; }
            .office-logo-img { width: 40px !important; height: 40px !important; }
            .office-brand-title { font-size: 22px !important; }
            .office-header-sub { font-size: 10px !important; line-height: 1.4; }
            .office-document-title { font-size: 12px !important; }
            .watermark-layer { width: 220px !important; height: 220px !important; opacity: 0.08 !important; }

            .matrix-table th, .matrix-table td { padding: 8px !important; font-size: 11px !important; }
            .field-label { min-width: 110px; font-size: 10px !important; }
            .field-value { min-width: 130px; font-size: 11px !important; }

            .row.no-gutters { display: block !important; }
            .row.no-gutters .col-6 { max-width: 100% !important; flex: 0 0 100% !important; padding: 0 !important; margin-bottom: 12px; }
            .row.no-gutters .matrix-table { display: table !important; overflow: visible !important; white-space: normal !important; }
            .btn-bloom-back { padding: 6px 12px !important; font-size: 11px !important; }
            .print-trigger-bar { text-align: center !important; padding: 10px !important; }
            .btn-action { width: 100% !important; max-width: 220px; font-size: 12px !important; }
        }
    </style>
</head>

<body>
    <div class="content-wrapper" style="padding: 20px 0; background: #f8fafc;">

        <!-- Top Navigation / Back Button Bar -->
        <div class="d-flex justify-content-between align-items-center mb-3" style="max-width: 900px; margin: 0 auto 15px auto; padding: 0 10px;">
            <a href="<?= base_url('payroll/payslips_new?month=' . urlencode($monthNum) . '&year=' . urlencode($yearNum)) ?>" class="btn btn-bloom-back">
                <i class="fas fa-arrow-left mr-1"></i> Back to Payslips
            </a>
            <div class="d-flex align-items-center">
                <span class="badge badge-pill badge-success px-3 py-2" style="font-size: 11px; font-weight: 600; letter-spacing: 0.5px;">
                    <i class="fas fa-check-circle mr-1"></i> <?= esc($cnt['payment_status'] ?? $cnt['run_status'] ?? 'FINALIZED') ?>
                </span>
            </div>
        </div>

        <div class="payslip-wrapper">
            <div id="statementCanvasContainer" class="payslip-main-sheet">

                <!-- Watermark Graphics Layer Section -->
                <div class="watermark-layer">
                    <img id="watermarkImg" src="<?= base_url('public/dist/img/bloom.jpg') ?>" class="watermark-img" alt="Watermark">
                </div>

                <!-- Corporate Header Section -->
                <div class="office-header-container">
                    <img id="headerLogoImg" src="<?= base_url('public/dist/img/bloom.jpg') ?>" alt="Company Logo" class="office-logo-img">
                    <h1 class="office-brand-title">
                        <span class="brand-blue">Bloom</span> <span class="brand-red">Solutions</span>
                    </h1>
                    <p class="office-header-sub">
                        H No. 6-2-981, Flat No. 501, 5th Floor, Maruthi Plaza, Khairatabad - 500004, Hyderabad, Telangana.
                    </p>
                    <b class="office-document-title">
                        Payslip for the month of <?= esc($monthName) ?> - <?= esc($yearNum) ?>
                    </b>
                </div>

                <!-- Profile Matrix Grid -->
                <table class="matrix-table">
                    <?php if (!empty($cnt)): ?>
                        <tr>
                            <td class="field-label">Employee Name</td>
                            <td class="field-value" style="color: var(--bloom-purple); font-weight:700;">
                                <?= esc($cnt['emp_name'] ?? $cnt['user_name'] ?? 'N/A'); ?>
                            </td>

                            <td class="field-label">Employee ID</td>
                            <td class="field-value" style="font-weight:700;">
                                <?= esc($cnt['emp_id'] ?? 'N/A'); ?>
                            </td>
                        </tr>

                        <tr>
                            <td class="field-label">Designation</td>
                            <td class="field-value">
                                <?= esc($cnt['designation_name'] ?? $cnt['designation'] ?? 'N/A'); ?>
                            </td>

                            <td class="field-label">Location</td>
                            <td class="field-value">
                                <?= esc($cnt['company_city'] ?? $cnt['location'] ?? 'Hyderabad'); ?>
                            </td>
                        </tr>

                        <tr>
                            <td class="field-label">Department</td>
                            <td class="field-value">
                                <?= esc($cnt['department_name'] ?? $cnt['department'] ?? 'N/A'); ?>
                            </td>

                            <td class="field-label">Date of Joining</td>
                            <td class="field-value">
                                <?php
                                $date = 'N/A';
                                if (!empty($cnt['joining_date'])) {
                                    $d = DateTime::createFromFormat('Y-m-d', $cnt['joining_date']);
                                    if (!$d) {
                                        $d = DateTime::createFromFormat('n/j/Y', $cnt['joining_date']);
                                    }
                                    if ($d) {
                                        $date = strtoupper($d->format('d-M-Y'));
                                    } else {
                                        $date = esc($cnt['joining_date']);
                                    }
                                }
                                echo esc($date);
                                ?>
                            </td>
                        </tr>

                        <tr>
                            <td class="field-label">PAN</td>
                            <td class="field-value">
                                <?= esc($cnt['pan'] ?? 'N/A'); ?>
                            </td>

                            <td class="field-label">PF Account No.</td>
                            <td class="field-value">
                                <?= esc($cnt['pf_account_no'] ?? 'N/A'); ?>
                            </td>
                        </tr>

                        <tr>
                            <td class="field-label">ESIC No.</td>
                            <td class="field-value">
                                <?= esc($cnt['esic_no'] ?? 'NA'); ?>
                            </td>

                            <td class="field-label">UAN</td>
                            <td class="field-value">
                                <?= esc($cnt['uan'] ?? 'N/A'); ?>
                            </td>
                        </tr>

                        <tr>
                            <td class="field-label">Bank Name</td>
                            <td class="field-value">
                                <?= esc($cnt['bank_name'] ?? 'N/A'); ?>
                            </td>

                            <td class="field-label">Bank Account No.</td>
                            <td class="field-value">
                                <?= esc($cnt['bank_account_no'] ?? 'N/A'); ?>
                            </td>
                        </tr>

                        <tr>
                            <td class="field-label">Monthly CTC</td>
                            <td class="field-value" style="font-weight:700;">
                                ₹<?= number_format_indian($cnt['monthly_ctc'] ?? 0); ?>/-
                            </td>

                            <td class="field-label">Mobile</td>
                            <td class="field-value">
                                <?= esc($cnt['mobile'] ?? 'N/A'); ?>
                            </td>
                        </tr>
                    <?php else: ?>
                        <tr>
                            <td colspan="4" class="text-center p-3 text-muted">No Employee Details Available</td>
                        </tr>
                    <?php endif; ?>
                </table>

                <!-- Dynamic Ledgers Row Layout Split (Earnings & Deductions) -->
                <div class="row no-gutters">
                    <!-- Left: Earnings Table -->
                    <div class="col-6 pr-2">
                        <table class="matrix-table">
                            <thead>
                                <tr>
                                    <th class="earnings-header-heading" style="width: 72%;">EARNINGS</th>
                                    <th class="earnings-header-amount" style="width: 28%;">Amount (₹)</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (!empty($earningsList)): ?>
                                    <?php for ($k = 0; $k < $maxTableRows; $k++): ?>
                                        <?php if (isset($earningsList[$k])): ?>
                                            <tr>
                                                <td style="width: 72%;"><?= esc($earningsList[$k]['name']); ?></td>
                                                <td class="num-col" style="width: 28%;">
                                                    <?= number_format($earningsList[$k]['amount'], 2); ?>
                                                </td>
                                            </tr>
                                        <?php else: ?>
                                            <!-- Alignment padding row -->
                                            <tr>
                                                <td style="width: 72%;">&nbsp;</td>
                                                <td class="num-col" style="width: 28%;">&nbsp;</td>
                                            </tr>
                                        <?php endif; ?>
                                    <?php endfor; ?>
                                <?php else: ?>
                                    <tr>
                                        <td style="width: 72%; color: #94a3b8;">No Earnings Listed</td>
                                        <td class="num-col" style="width: 28%;">0.00</td>
                                    </tr>
                                <?php endif; ?>

                                <!-- Total Earnings Row -->
                                <tr class="row-total-accent">
                                    <td style="font-weight: 700;">Total Earnings [Gross]</td>
                                    <td class="num-col" style="font-weight: 700;">
                                        <?= number_format($grossEarnings, 2); ?>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>

                    <!-- Right: Deductions Table -->
                    <div class="col-6 pl-2">
                        <table class="matrix-table">
                            <thead>
                                <tr>
                                    <th class="deductions-header-heading" style="width: 72%;">DEDUCTIONS</th>
                                    <th class="deductions-header-amount" style="width: 28%;">Amount (₹)</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (!empty($deductionsList)): ?>
                                    <?php for ($k = 0; $k < $maxTableRows; $k++): ?>
                                        <?php if (isset($deductionsList[$k])): ?>
                                            <tr>
                                                <td style="width: 72%;"><?= esc($deductionsList[$k]['name']); ?></td>
                                                <td class="num-col" style="width: 28%;">
                                                    <?= number_format($deductionsList[$k]['amount'], 2); ?>
                                                </td>
                                            </tr>
                                        <?php else: ?>
                                            <!-- Alignment padding row -->
                                            <tr>
                                                <td style="width: 72%;">&nbsp;</td>
                                                <td class="num-col" style="width: 28%;">&nbsp;</td>
                                            </tr>
                                        <?php endif; ?>
                                    <?php endfor; ?>
                                <?php else: ?>
                                    <tr>
                                        <td style="width: 72%; color: #94a3b8;">No Deductions Listed</td>
                                        <td class="num-col" style="width: 28%;">0.00</td>
                                    </tr>
                                <?php endif; ?>

                                <!-- Total Deductions Row -->
                                <tr class="row-total-accent">
                                    <td style="font-weight: 700;">Total Deductions</td>
                                    <td class="num-col" style="font-weight: 700;">
                                        <?= number_format($totalDeductions, 2); ?>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- Employer Contributions Section (if present) -->
                <?php if (!empty($employerContributionsList) || $employerContributionsTotal > 0): ?>
                    <table class="matrix-table mb-3">
                        <thead>
                            <tr>
                                <th class="earnings-header-heading" style="width: 72%;">
                                    <i class="fas fa-building text-primary mr-1"></i> EMPLOYER CONTRIBUTIONS
                                    <small class="text-muted font-weight-normal">(Not deducted from gross pay)</small>
                                </th>
                                <th class="earnings-header-amount" style="width: 28%;">Amount (₹)</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($employerContributionsList as $ec): ?>
                                <tr>
                                    <td style="width: 72%; color: #475569;"><?= esc($ec['name']); ?></td>
                                    <td class="num-col" style="width: 28%;"><?= number_format($ec['amount'], 2); ?></td>
                                </tr>
                            <?php endforeach; ?>
                            <tr class="row-total-accent">
                                <td style="font-weight: 700;">Total Employer Contribution</td>
                                <td class="num-col" style="font-weight: 700;"><?= number_format($employerContributionsTotal, 2); ?></td>
                            </tr>
                        </tbody>
                    </table>
                <?php endif; ?>

                <!-- Other totals of the month (e.g. Total CTC), from the payroll totals -->
                <?php if (!empty($otherTotals)): ?>
                    <table class="matrix-table mb-3">
                        <thead>
                            <tr>
                                <th class="earnings-header-heading" style="width: 72%;">
                                    <i class="fas fa-calculator text-primary mr-1"></i> OTHER TOTALS
                                </th>
                                <th class="earnings-header-amount" style="width: 28%;">Amount (₹)</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($otherTotals as $ot): ?>
                                <tr>
                                    <td style="width: 72%; color: #475569;"><?= esc($ot['name']); ?></td>
                                    <td class="num-col" style="width: 28%;"><?= number_format($ot['amount'], 2); ?></td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                <?php endif; ?>

                <!-- Totals Metric Block Grid (Net Pay) -->
                <table class="matrix-table">
                    <tr class="net-pay-row">
                        <td style="width: 25%; font-weight: 800; font-size: 15px;">Net Pay</td>
                        <td class="num-col" style="width: 75%; text-align: left; font-size: 17px; font-weight: 800;">
                            ₹ <?= number_format($netPay, 2); ?>/-
                        </td>
                    </tr>
                    <tr>
                        <td class="field-label">Net Salary in Words</td>
                        <td style="width: 75%; font-weight: 600; color: #1e293b;">
                            Indian Rupees <?= esc(convertNumberToWords($netPay)); ?> Only
                        </td>
                    </tr>
                </table>

                <div class="disclaimer-text">
                    <i class="fas fa-check-circle text-success mr-1"></i> This is a computer-generated statement, and does not require a physical signature or stamp.
                </div>

                <div id="pdfControls" class="print-trigger-bar">
                    <button id="pdfBtn" onclick="exportToCanvasPDF()" class="btn-action">
                        <i class="fas fa-file-pdf mr-2"></i> Export PDF
                    </button>
                </div>

            </div>
        </div>

        <script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>

        <script>
            const localImageSrc = "<?= base_url('public/dist/img/bloom.jpg') ?>";

            function loadAssetsSecurely() {
                const img = new Image();
                img.crossOrigin = "anonymous";
                img.src = localImageSrc;
                img.onload = function () {
                    const canvas = document.createElement("canvas");
                    canvas.width = img.width;
                    canvas.height = img.height;
                    const ctx = canvas.getContext("2d");
                    ctx.drawImage(img, 0, 0);
                    try {
                        const dataURL = canvas.toDataURL("image/jpeg");
                        const headerLogo = document.getElementById('headerLogoImg');
                        const watermark = document.getElementById('watermarkImg');
                        if (headerLogo) headerLogo.src = dataURL;
                        if (watermark) watermark.src = dataURL;
                    } catch (e) {
                        console.log("Local asset loaded.");
                    }
                };
            }

            window.addEventListener('DOMContentLoaded', loadAssetsSecurely);

            function exportToCanvasPDF() {
                const controls = document.getElementById("pdfControls");
                controls.style.display = "none";
                const btn = document.getElementById('pdfBtn');

                if (!window.html2canvas || !window.jspdf) {
                    payrollDialog.message({ title: 'Payslip PDF', message: 'The PDF tool is still loading. Please wait a moment and try again.' });
                    controls.style.display = "block";
                    return;
                }

                btn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i> Generating PDF...';
                btn.disabled = true;

                const { jsPDF } = window.jspdf;
                const element = document.getElementById('statementCanvasContainer');

                const options = {
                    scale: 2,
                    useCORS: true,
                    allowTaint: true,
                    logging: false,
                    backgroundColor: "#ffffff"
                };

                html2canvas(element, options).then((canvas) => {
                    const imgData = canvas.toDataURL('image/png');
                    const imgWidth = 210;
                    const imgHeight = (canvas.height * imgWidth) / canvas.width;

                    const pdf = new jsPDF({
                        orientation: 'portrait',
                        unit: 'mm',
                        format: [imgWidth, imgHeight]
                    });

                    const margin = 8;
                    pdf.addImage(
                        imgData,
                        'PNG',
                        margin,
                        margin,
                        imgWidth - (margin * 2),
                        imgHeight - (margin * 2)
                    );
                    const fileName = `${employeeName}_Payslip_${payMonth}_${payYear}.pdf`;
                    pdf.save(fileName);
                    recordPayslipDownload(fileName);
                    controls.style.display = "block";

                    btn.innerHTML = '<i class="fas fa-file-pdf mr-2"></i> Export PDF';
                    btn.disabled = false;
                }).catch((err) => {
                    console.error(err);
                    btn.innerHTML = '<i class="fas fa-file-pdf mr-2"></i> Export PDF';
                    btn.disabled = false;
                    controls.style.display = "block";
                    payrollDialog.message({ title: 'Payslip PDF', message: 'The PDF could not be created. Please try again.', danger: true });
                });
            }
        </script>
        <script>
            const employeeName = "<?= esc(str_replace(' ', '_', $cnt['emp_name'] ?? $cnt['user_name'] ?? 'Employee')); ?>";
            const payMonth = "<?= esc($monthName) ?>";
            const payYear = "<?= esc($yearNum) ?>";

            // Payroll audit trail: record who downloaded which payslip (never blocks the download)
            function recordPayslipDownload(fileName) {
                const body = new URLSearchParams({
                    emp_id: <?= json_encode((string) ($cnt['emp_id'] ?? '')) ?>,
                    month: <?= json_encode((string) $monthNum) ?>,
                    year: <?= json_encode((string) $yearNum) ?>,
                    payslip_id: <?= json_encode((string) ($cnt['payslip_id'] ?? '')) ?>,
                    file_name: fileName
                });
                fetch(<?= json_encode(base_url('payroll/audit_payslip_download')) ?>, {
                    method: 'POST',
                    headers: { 'X-Requested-With': 'XMLHttpRequest' },
                    body: body
                }).catch(() => {});
            }
        </script>
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
    </div>
    <?= view('payroll/_dialog') ?>
</body>

</html>
