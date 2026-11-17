
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Bloom Solutions | Attendance cycles</title>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
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
        .content-wrapper {
            min-height: calc(100vh - 110px) !important;
            height: auto !important;
            overflow-y: visible !important;
            overflow-x: hidden;
            padding-bottom: 20px !important;
            background-color: #f8fafc;
        }
        .content {
            padding-top: 0 !important;
            padding-bottom: 12px !important;
        }
        .table-responsive {
            width: 100%;
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
        }
        .table {
            min-width: 650px;
        }
        .main-header {
            border-bottom: 1px solid #e2e8f0 !important;
            background: var(--glass) !important;
            backdrop-filter: blur(10px);
        }
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
        .badge-in-progress {
            background-color: #fef3c7;
            color: #d97706;
            border-radius: 50rem;
            padding: 0.35rem 0.75rem;
            font-weight: 600;
        }
        .badge-finalized {
            background-color: #d1fae5;
            color: #059669;
            border-radius: 50rem;
            padding: 0.35rem 0.75rem;
            font-weight: 600;
        }
        .badge-current {
            background-color: #fef3c7;
            color: #b45309;
            font-size: 10px;
            padding: 2px 6px;
            border-radius: 4px;
            margin-left: 6px;
            font-weight: 700;
            text-transform: uppercase;
        }
        .table td,
        .table th {
            vertical-align: middle !important;
            border-top: 1px solid #f1f5f9 !important;
        }
        .row:last-of-type,
        .row:last-of-type .col-lg-12,
        .row:last-of-type .card {
            margin-bottom: 0 !important;
        }
        .cycle-footer {
            width: 100%;
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            justify-content: space-between;
            gap: 10px 20px;
            margin-top: 20px;
            padding: 14px 10px 4px;
            border-top: 1px solid #e2e8f0;
            color: #64748b;
            font-family: 'Plus Jakarta Sans', sans-serif;
            font-size: 12px;
            box-sizing: border-box;
        }
        .cycle-footer-info,
        .cycle-footer-sort {
            display: flex;
            align-items: center;
            flex-wrap: wrap;
            gap: 4px;
            line-height: 1.7;
        }
        .cycle-footer-info i {
            color: #64748b;
        }
        .cycle-footer-sort strong {
            color: #1e293b;
            font-weight: 700;
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
        .btn-bloom-back i {
            font-size: 11px;
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
        @media (max-width: 767px) {
            .content-header h4 {
                font-size: 20px !important;
            }
            .card-bloom {
                border-radius: 12px !important;
            }
            .cycle-footer {
                flex-direction: column;
                align-items: flex-start;
            }
        }
    </style>
</head>
<body class="hold-transition sidebar-mini layout-fixed">
    <div class="wrapper">
        <div class="content-wrapper">
            <div class="content-header pb-1">
                <div class="container-fluid">
                    <div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between mb-4">
                        <div>
                            <small class="text-muted font-weight-semibold" style="font-size: 11.5px;">
                                HR &nbsp;<i class="fas fa-chevron-right" style="font-size: 9px;"></i>&nbsp;
                                Attendance Management &nbsp;<i class="fas fa-chevron-right" style="font-size: 9px;"></i>&nbsp;
                                <span style="color: var(--bloom-purple); font-weight: 600;">Attendance Cycles</span>
                            </small>
                            <h4 class="font-weight-bold mb-1 mt-1 text-dark" style="font-size: 22px;">Attendance Cycle Status</h4>
                            <small class="text-muted">Track and review monthly attendance cycle finalization, cutoff dates, and audit readiness.</small>
                        </div>
                        <div class="card card-bloom mb-0 px-3 py-2 shadow-sm d-inline-block mt-3 mt-md-0">
                            <div class="d-flex align-items-center">
                                <span class="mr-2" style="color: var(--bloom-purple);">
                                    <i class="far fa-calendar-alt"></i>
                                </span>
                                <span class="text-muted font-weight-bold mr-2" style="font-size: 12px;">Financial Year:</span>
                                <select id="yearFilter" name="year" class="form-control form-control-sm font-weight-bold text-dark border-0 bg-light rounded" style="width: 135px; cursor: pointer;" onchange="window.location.href='?year=' + encodeURIComponent(this.value);">
                                    <?php
                                    $currentYear = (int) date('Y');
                                    $currentMonth = (int) date('n');
                                    $financialStartYear = ($currentMonth >= 4) ? $currentYear : $currentYear - 1;
                                    $selectedYear = $selectedYear ?? ($financialStartYear . '-' . ($financialStartYear + 1));
                                    for ($i = 0; $i < 5; $i++):
                                        $startYear = $financialStartYear - $i;
                                        $endYear = $startYear + 1;
                                        $value = $startYear . '-' . $endYear;
                                    ?>
                                        <option value="<?= esc($value) ?>" <?= ($selectedYear == $value) ? 'selected' : '' ?>>
                                            FY <?= esc($startYear) ?> - <?= esc($endYear) ?>
                                        </option>
                                    <?php endfor; ?>
                                </select>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <section class="content pt-0">
                <div class="container-fluid">
                    <div class="row">
                        <div class="col-lg-12">
                            <div class="card card-bloom p-3">
                                <div class="d-flex align-items-center justify-content-between p-2 mb-2 border-bottom pb-3">
                                    <div class="d-flex align-items-center">
                                        <div class="mr-3 d-flex align-items-center justify-content-center" style="width: 40px; height: 40px; background: #f1f5f9; border-radius: 10px; color: var(--bloom-purple);">
                                            <i class="fas fa-calendar-alt"></i>
                                        </div>
                                        <div>
                                            <h6 class="font-weight-bold text-dark mb-0" style="font-size: 15px;">Attendance Cycles Registry</h6>
                                        </div>
                                    </div>
                                    <div>
                                        <span class="badge px-3 py-2 font-weight-bold" style="background: #eff6ff; color: var(--bloom-purple); border-radius: 20px; font-size: 12px;">
                                            <?= count($cycle ?? []) ?> Cycles Loaded
                                        </span>
                                    </div>
                                </div>
                                <div class="card-body p-0 table-responsive">
                                    <table class="table mb-0" style="border-collapse: separate; border-spacing: 0;">
                                        <thead>
                                            <tr class="text-uppercase text-muted" style="font-size: 11px; letter-spacing: 0.5px;">
                                                <th class="border-top-0 pl-3 font-weight-bold" style="padding: 12px;">CYCLE NAME</th>
                                                <th class="border-top-0 font-weight-bold" style="padding: 12px;">DATES (FROM – TO)</th>
                                                <th class="border-top-0 font-weight-bold" style="padding: 12px;">FINALIZED STATUS</th>
                                                <th class="border-top-0 text-right pr-3 font-weight-bold" style="padding: 12px;">ACTION</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <?php if (($cycleStatus ?? '') === 'N' || empty($cycle)): ?>
                                                <tr>
                                                    <td colspan="4" class="text-center text-muted py-4">
                                                        <i class="fas fa-info-circle mr-2"></i>
                                                        <?= esc($cycleRemarks ?? 'Data not available') ?>
                                                    </td>
                                                </tr>
                                            <?php else: ?>
                                                <?php foreach ($cycle as $row): ?>
                                                    <?php
                                                    $status = strtoupper(trim($row['attendance_status'] ?? ''));
                                                    $isFinalized = ($status === 'FINALIZED');
                                                    $startDate = $row['cycle_start_date'] ?? '';
                                                    $endDate = $row['cycle_end_date'] ?? '';
                                                    ?>
                                                    <tr style="border-top: 1px solid #f1f5f9;">
                                                        <td class="pl-3 font-weight-bold text-dark" style="padding: 14px 12px;">
                                                            <span class="mr-2" style="color: <?= $isFinalized ? '#10b981' : '#f59e0b' ?>;">
                                                                <i class="fas <?= $isFinalized ? 'fa-check-circle' : 'fa-ellipsis-h' ?>"></i>
                                                            </span>
                                                            <?= esc($row['cycle_name'] ?? '-') ?>
                                                        </td>
                                                        <td style="padding: 14px 12px;">
                                                            <span class="text-muted">
                                                                <i class="far fa-calendar-alt mr-1 text-secondary"></i>
                                                                <?= $startDate && strtotime($startDate) ? date('jS \o\f F', strtotime($startDate)) : '-' ?>
                                                                &ndash;
                                                                <?= $endDate && strtotime($endDate) ? date('jS \o\f F', strtotime($endDate)) : '-' ?>
                                                            </span>
                                                        </td>
                                                        <td style="padding: 14px 12px;">
                                                            <?php if ($isFinalized): ?>
                                                                <span class="badge badge-finalized" style="padding: 6px 12px;">
                                                                    <i class="fas fa-circle mr-1" style="font-size: 6px; vertical-align: middle;"></i>
                                                                    Finalized
                                                                </span>
                                                            <?php else: ?>
                                                                <span class="badge badge-in-progress" style="padding: 6px 12px;">
                                                                    <i class="fas fa-circle mr-1" style="font-size: 6px; vertical-align: middle;"></i>
                                                                    <?= esc(($row['attendance_status'] ?? '') ?: 'In Progress') ?>
                                                                </span>
                                                            <?php endif; ?>
                                                        </td>
                                                        <td class="text-right pr-3" style="padding: 14px 12px;">
                                                        <?php
                                                        $cycleDate = $row['cycle_end_date'] ?? '';
                                                        $cycleMonth = $cycleDate ? date('m', strtotime($cycleDate)) : '';
                                                        $cycleYear = $cycleDate ? date('Y', strtotime($cycleDate)) : '';
                                                        ?>
                                                        <a href="<?= base_url('admin/attendance_finalize') . '?month=' . esc($cycleMonth) . '&year=' . esc($cycleYear) ?>"
                                                        class="btn btn-light btn-sm rounded-circle"
                                                        style="width: 32px; height: 32px; display: inline-flex; align-items: center; justify-content: center; background: #f8fafc; border: 1px solid #e2e8f0; color: var(--bloom-purple);"
                                                        title="View Attendance"
                                                        aria-label="View Attendance">
                                                            <i class="far fa-eye"></i>
                                                        </a>
                                                    </td>
                                                    </tr>
                                                <?php endforeach; ?>
                                            <?php endif; ?>
                                        </tbody>
                                    </table>
                                </div>
                                <div class="cycle-footer">
                                    <div class="cycle-footer-info">
                                        <i class="fas fa-info-circle mr-1"></i>
                                        Cycles cut off automatically on the 24th of each calendar month at 23:59 IST.
                                    </div>
                                    
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="d-flex justify-content-start mt-3 mb-2">
                        <button type="button" class="btn btn-bloom-back" onclick="window.history.back();">
                            <i class="fas fa-arrow-left mr-1"></i> Back
                        </button>
                    </div>
                </div>
            </section>
        </div>
    </div>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
</body>
</html>
