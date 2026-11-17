<?php
/**
 * One employee's salary (replaces the "Configure Salary Structure" popup).
 * Data: $employee (name, department ...), $periods (salary periods, newest first),
 *       $current (the period being edited), $components (rules, own settings, amounts),
 *       $returnParam ('' or 'cycle/{id}'), $returnUrl.
 * Amounts are always calculated by the salary engine (preview); saving goes through
 * hrms_save_employee_salary (all changes at once).
 */
$empId    = (string) ($employee['emp_id'] ?? '');
$empName  = (string) ($employee['emp_name'] ?? $empId);
$cur      = $current ?? null;
$fromCycle = $returnParam !== '';
$fmtDate  = fn($d) => $d ? date('d M Y', strtotime($d)) : '';
$cyclesOf = function ($p) {
    $out = [];
    foreach (array_filter(explode(';', (string) ($p['cycles'] ?? ''))) as $c) {
        [$id, $label, $status] = array_pad(explode('|', $c), 3, '');
        $out[] = ['id' => (int) $id, 'label' => $label, 'status' => $status];
    }
    return $out;
};
$curCycles = $cur ? $cyclesOf($cur) : [];
$statusText = [
    'OPEN' => 'Open', 'ATTENDANCE_VERIFIED' => 'Attendance verified', 'STRUCTURE_VERIFIED' => 'Structures verified',
    'PROCESSING' => 'Calculating', 'CALCULATED' => 'Calculated', 'APPROVED' => 'Approved', 'FINALIZED' => 'Finalized',
    'PARTIALLY_PAID' => 'Partially paid', 'PAID' => 'Paid', 'CLOSED' => 'Closed',
];
$locked = array_filter($curCycles, fn($c) => in_array($c['status'], ['FINALIZED', 'PARTIALLY_PAID', 'PAID', 'CLOSED'], true));
$recalc = array_filter($curCycles, fn($c) => in_array($c['status'], ['PROCESSING', 'CALCULATED', 'APPROVED'], true));
// Timeline (S-001): periods oldest first with the gaps between them and the lock flag.
// Without it (procedure not installed yet) the periods are shown oldest first, no gaps, no lock.
$timeline = is_array($timeline ?? null) ? $timeline : [];
$periodById = [];
foreach ($periods as $p) {
    $periodById[(int) $p['structure_id']] = $p;
}
if (!$timeline) {
    foreach (array_reverse($periods) as $p) {
        $timeline[] = ['row_type' => 'PERIOD', 'structure_id' => $p['structure_id'], 'date_from' => $p['effective_from'],
                       'date_to' => $p['effective_to'], 'monthly_ctc' => $p['monthly_ctc'], 'is_current' => $p['is_current'],
                       'locked' => 0, 'locked_cycles' => null, 'locked_until' => null];
    }
}
$curLock = null;
foreach ($timeline as $t) {
    if ($cur && $t['row_type'] === 'PERIOD' && (int) $t['structure_id'] === (int) $cur['structure_id']) {
        $curLock = $t;
    }
}
$curLocked    = $curLock && (int) $curLock['locked'] === 1;
$gapCount     = count(array_filter($timeline, fn($t) => $t['row_type'] === 'GAP'));
$returnQuery  = $returnParam !== '' ? 'return=' . rawurlencode($returnParam) : '';
$backLabel = 'Salary structures';
if ($fromCycle) {
    $backLabel = 'Back to payroll';
    foreach ($curCycles as $c) {
        if ('cycle/' . $c['id'] === $returnParam) {
            $backLabel = 'Back to payroll ' . $c['label'];
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>BloomHR | Salary of <?= esc($empName) ?></title>
    <link rel="icon" type="image/jpeg" href="<?= base_url('public/dist/img/bloom.jpg') ?>">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
    <?= view('payroll/_salary_page_styles') ?>
    <style>
        /* salary timeline: oldest on the left, newest on the right */
        .tl { display: flex; align-items: stretch; gap: 0; overflow-x: auto; padding: 4px 2px 10px; }
        .tl .period-card, .tl .tl-gap { flex: 0 0 232px; }
        .tl-arrow { flex: 0 0 26px; display: flex; align-items: center; justify-content: center; color: #94a3b8; font-size: 12px; }
        .tl-gap { border: 1.5px dashed #f87171; border-radius: 12px; padding: 12px 14px; background: #fef2f2; color: #7f1d1d; }
        .tl-gap .dates { font-weight: 800; font-size: 13px; }
        .tl-gap a { color: #b91c1c; font-weight: 800; font-size: 12px; text-decoration: underline; }
        .tl-lock { color: #64748b; font-size: 11.5px; font-weight: 700; }
        .notice-bad { background: #fee2e2; color: #7f1d1d; }
        .revise-box { border: 1px solid #c7d2fe; background: #f8f7ff; border-radius: 12px; padding: 14px 16px; }
        .pc-control[readonly], .pc-control:disabled { background: #f1f5f9; color: #475569; cursor: not-allowed; }
    </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed">
    <div class="content-wrapper">
        <div class="payroll-page">

            <!-- EMPLOYEE HEADER -->
            <div class="emp-hero d-flex flex-wrap align-items-center justify-content-between" style="gap: 14px;">
                <div class="d-flex align-items-center" style="gap: 14px;">
                    <span class="emp-avatar"><?= esc(strtoupper(substr(preg_replace('/[^A-Za-z]/', '', $empName) ?: 'E', 0, 2))) ?></span>
                    <div>
                        <div style="font-size: 20px; font-weight: 800;">Salary of <?= esc($empName) ?></div>
                        <div class="meta">
                            <?= esc($empId) ?>
                            <?php if (!empty($employee['department'])): ?> &middot; <?= esc($employee['department']) ?><?php endif; ?>
                            <?php if (!empty($employee['designation'])): ?> &middot; <?= esc($employee['designation']) ?><?php endif; ?>
                            <?php if ($cur): ?> &middot; ESI <?= ($cur['esi_applicable'] ?? 'N') === 'Y' ? 'applicable' : 'not applicable' ?><?php endif; ?>
                        </div>
                    </div>
                </div>
                <a href="<?= esc($returnUrl, 'attr') ?>" class="pc-btn" id="btnBack"><i class="fas fa-arrow-left"></i> <?= esc($backLabel) ?></a>
            </div>

            <?php if (!$cur): ?>
                <div class="pc-card"><div class="pc-body">
                    <div class="notice notice-warn"><i class="fas fa-exclamation-triangle"></i>
                        <div><b><?= esc($empName) ?> has no salary yet.</b> Add one: every active component is attached and calculated from the monthly CTC.</div>
                    </div>
                    <a class="pc-btn pc-btn-primary mt-3"
                       href="<?= base_url('payroll/salary_structure/new/' . rawurlencode($empId)) . ($returnParam !== '' ? '?return=' . rawurlencode($returnParam) : '') ?>">
                        <i class="fas fa-plus-circle"></i> Add salary
                    </a>
                </div></div>
            <?php else: ?>

            <div class="row">
                <div class="col-xl-8 order-2 order-xl-1">

                    <!-- SALARY PERIODS -->
                    <div class="pc-card">
                        <div class="pc-body">
                            <div class="d-flex justify-content-between align-items-start flex-wrap mb-3" style="gap: 10px;">
                                <div>
                                    <p class="pc-section-title"><i class="fas fa-calendar-alt mr-1" style="color: var(--bloom-purple);"></i> Salary periods</p>
                                    <p class="pc-section-help">Salary history, oldest first. Each period is the salary valid between two dates. Pick the one to open.</p>
                                </div>
                            </div>
                            <?php if ($gapCount): ?>
                                <div class="notice notice-bad mb-2"><i class="fas fa-exclamation-triangle"></i>
                                    <div><b><?= $gapCount ?> gap<?= $gapCount > 1 ? 's' : '' ?> with no salary.</b>
                                        Payroll cannot pay <?= esc($empName) ?> for those dates until a salary is added for them.</div></div>
                            <?php endif; ?>
                            <div class="tl">
                                <?php foreach ($timeline as $i => $t): ?>
                                    <?php if ($i > 0): ?><div class="tl-arrow"><i class="fas fa-chevron-right"></i></div><?php endif; ?>
                                    <?php if ($t['row_type'] === 'GAP'): ?>
                                        <div class="tl-gap">
                                            <div class="dates"><i class="fas fa-ban mr-1"></i><?= esc($fmtDate($t['date_from'])) ?> &ndash; <?= $t['date_to'] ? esc($fmtDate($t['date_to'])) : 'onwards' ?></div>
                                            <div class="mt-1" style="font-weight: 700; font-size: 13px;">No salary</div>
                                            <div class="mt-1">
                                                <a href="<?= esc(base_url('payroll/salary_structure/new/' . rawurlencode($empId)) . '?from=' . rawurlencode((string) $t['date_from'])
                                                    . ($returnQuery !== '' ? '&' . $returnQuery : ''), 'attr') ?>" data-period-link="1">
                                                    <i class="fas fa-plus-circle"></i> Add salary for this gap</a>
                                            </div>
                                        </div>
                                    <?php else: ?>
                                        <?php
                                        $p     = $periodById[(int) $t['structure_id']] ?? [];
                                        $isSel = (int) $t['structure_id'] === (int) $cur['structure_id'];
                                        $href  = base_url('payroll/salary_structure/edit/' . rawurlencode($empId)) . '?period=' . (int) $t['structure_id']
                                               . ($returnQuery !== '' ? '&' . $returnQuery : '');
                                        $pc    = $cyclesOf($p);
                                        ?>
                                        <a class="period-card <?= $isSel ? 'active' : '' ?>" href="<?= esc($href, 'attr') ?>" data-period-link="1">
                                            <div class="d-flex justify-content-between align-items-center">
                                                <span class="dates"><?= esc($fmtDate($t['date_from'])) ?> &ndash; <?= $t['date_to'] ? esc($fmtDate($t['date_to'])) : 'onwards' ?></span>
                                                <?php if ((int) $t['is_current'] === 1): ?><span class="chip badge-soft-success">In force today</span><?php endif; ?>
                                            </div>
                                            <div class="ctc mt-1">&#8377; <?= number_format((float) $t['monthly_ctc'], 2) ?> <span class="muted" style="font-size: 11px; font-weight: 600;">/ month</span></div>
                                            <div class="muted mt-1" style="font-size: 11.5px;">
                                                <?= $pc ? 'Payroll: ' . esc(implode(', ', array_map(fn($c) => $c['label'], $pc))) : 'Not used by any payroll yet' ?>
                                            </div>
                                            <?php if ((int) $t['locked'] === 1): ?>
                                                <div class="tl-lock mt-1" title="Payroll <?= esc($t['locked_cycles'], 'attr') ?> is finalized with this salary. Its CTC is changed with Revise CTC, from a new date.">
                                                    <i class="fas fa-lock"></i> Locked: <?= esc($t['locked_cycles']) ?> finalized</div>
                                            <?php endif; ?>
                                        </a>
                                    <?php endif; ?>
                                <?php endforeach; ?>
                            </div>

                            <?php if ($curCycles): ?>
                                <div class="mt-3 d-flex flex-wrap" style="gap: 6px;">
                                    <?php foreach ($curCycles as $c): ?>
                                        <?php $cls = in_array($c['status'], ['FINALIZED', 'PARTIALLY_PAID', 'PAID', 'CLOSED'], true) ? 'badge-soft-secondary'
                                                   : (in_array($c['status'], ['PROCESSING', 'CALCULATED', 'APPROVED'], true) ? 'badge-soft-warning' : 'badge-soft-info'); ?>
                                        <a class="chip <?= $cls ?>" href="<?= base_url('payroll/cycle/' . $c['id']) ?>" style="text-decoration: none;">
                                            <i class="fas fa-money-check-alt"></i> <?= esc($c['label']) ?>: <?= esc($statusText[$c['status']] ?? $c['status']) ?>
                                        </a>
                                    <?php endforeach; ?>
                                </div>
                            <?php endif; ?>
                            <?php if ($locked): ?>
                                <div class="notice notice-muted mt-2"><i class="fas fa-lock"></i>
                                    <div>Already finalized or paid with this salary: <b><?= esc(implode(', ', array_map(fn($c) => $c['label'], $locked))) ?></b>.
                                        Those payrolls keep their own copy and do not change.</div></div>
                            <?php endif; ?>
                            <?php if ($recalc): ?>
                                <div class="notice notice-warn mt-2"><i class="fas fa-redo"></i>
                                    <div>Already calculated with this salary: <b><?= esc(implode(', ', array_map(fn($c) => $c['label'] . ' (' . ($statusText[$c['status']] ?? $c['status']) . ')', $recalc))) ?></b>.
                                        After saving, recalculate the employee on that payroll (withdraw approval first if it is approved).</div></div>
                            <?php endif; ?>
                        </div>
                    </div>

                    <!-- 1. MONTHLY CTC -->
                    <div class="pc-card">
                        <div class="pc-body">
                            <p class="pc-section-title"><span class="step-no">1</span>Monthly CTC</p>
                            <p class="pc-section-help mb-3">The cost to company per month. Components below are calculated from it.</p>
                            <?php if ($curLocked): ?>
                                <div class="notice notice-muted mb-3"><i class="fas fa-lock"></i>
                                    <div><b>This salary period is locked.</b> Payroll <?= esc($curLock['locked_cycles']) ?> is already finalized with it, so its
                                        monthly CTC is not changed here. To give a new CTC, use <b>Revise CTC</b>: the new CTC starts on a date you choose and this period ends the day before.</div></div>
                            <?php endif; ?>
                            <div class="row">
                                <div class="col-sm-4 mb-2">
                                    <label class="pc-label" for="inpCtc">Monthly CTC (&#8377;)</label>
                                    <input type="number" min="1" step="1" class="pc-control w-100 font-weight-bold" id="inpCtc" value="<?= esc((float) $cur['monthly_ctc']) ?>"
                                        <?= $curLocked ? 'readonly title="Locked: use Revise CTC"' : '' ?>>
                                    <div class="muted mt-1" style="font-size: 11.5px;">Annual: <b id="lblAnnual"></b></div>
                                </div>
                                <div class="col-sm-4 mb-2">
                                    <label class="pc-label" for="inpFrom">This period applies from</label>
                                    <input type="date" class="pc-control w-100" id="inpFrom" value="<?= esc($cur['effective_from']) ?>" readonly
                                        title="The start of a salary period does not change. Use Revise CTC for a new CTC from a new date.">
                                    <div class="muted mt-1" style="font-size: 11.5px;">to <b><?= $cur['effective_to'] ? esc($fmtDate($cur['effective_to'])) : 'onwards' ?></b></div>
                                </div>
                                <div class="col-sm-4 mb-2 d-flex align-items-end">
                                    <div class="muted" style="font-size: 12px;" id="lblFromHelp"></div>
                                </div>
                            </div>

                            <!-- REVISE CTC: a new CTC from a new date = a new salary period -->
                            <div class="mt-2">
                                <button type="button" class="pc-btn pc-btn-primary" id="btnReviseOpen"><i class="fas fa-code-branch"></i> Revise CTC from a new date</button>
                                <span class="muted ml-2" style="font-size: 11.5px;">Keeps this salary as history and starts a new one.</span>
                            </div>
                            <div class="revise-box mt-3" id="reviseBox" style="display: none;">
                                <p class="pc-section-title mb-1"><i class="fas fa-code-branch mr-1" style="color: var(--bloom-purple);"></i> Revise CTC</p>
                                <p class="pc-section-help mb-3">The new CTC starts on the date you choose. This salary period (&#8377; <?= number_format((float) $cur['monthly_ctc'], 2) ?>)
                                    stays as it is and ends the day before. Components and this employee's own settings are copied to the new salary.</p>
                                <div class="row">
                                    <div class="col-sm-4 mb-2">
                                        <label class="pc-label" for="revCtc">New monthly CTC (&#8377;)</label>
                                        <input type="number" min="1" step="1" class="pc-control w-100 font-weight-bold" id="revCtc" placeholder="<?= esc((float) $cur['monthly_ctc']) ?>">
                                        <div class="muted mt-1" style="font-size: 11.5px;" id="revDiff"></div>
                                    </div>
                                    <div class="col-sm-4 mb-2">
                                        <label class="pc-label" for="revFrom">New CTC applies from</label>
                                        <input type="date" class="pc-control w-100" id="revFrom">
                                        <div class="muted mt-1" style="font-size: 11.5px;" id="revRange"></div>
                                    </div>
                                </div>
                                <div class="notice notice-info mt-1" id="revSummary" style="display: none;"><i class="fas fa-info-circle"></i><div id="revSummaryText"></div></div>
                                <div class="notice notice-warn mt-2" id="revWarn" style="display: none;"><i class="fas fa-exclamation-triangle"></i><div id="revWarnText"></div></div>
                                <div class="d-flex mt-3" style="gap: 8px;">
                                    <button type="button" class="pc-btn pc-btn-primary" id="btnReviseSave" disabled><i class="fas fa-save"></i> Save revised CTC</button>
                                    <button type="button" class="pc-btn" id="btnReviseCancel">Cancel</button>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- 2. COMPONENTS -->
                    <div class="pc-card">
                        <div class="pc-body pb-2">
                            <p class="pc-section-title"><span class="step-no">2</span>Components</p>
                            <p class="pc-section-help">
                                <b>Company rule</b> is the same for everyone (from Salary Components). Choose <b>This employee</b> only when this person needs something different.
                                Amounts are calculated by the salary engine as you type.
                            </p>
                        </div>
                        <div id="cmpGroups"></div>
                    </div>
                </div>

                <!-- SUMMARY -->
                <div class="col-xl-4 order-1 order-xl-2">
                    <div class="pc-card summary">
                        <div class="pc-body">
                            <div class="d-flex justify-content-between align-items-center">
                                <span class="pc-label mb-0">Net pay (take-home) per month</span>
                                <span class="chip badge-soft-primary" id="chipChanges" style="display: none;"></span>
                            </div>
                            <div class="net mt-1" id="sumNet">&#8377; 0.00</div>
                            <div class="mt-3">
                                <div class="row-line"><span>Gross earnings</span><b id="sumGross"></b></div>
                                <div class="row-line"><span>Deductions</span><b id="sumDed" style="color:#b91c1c;"></b></div>
                                <div class="row-line"><span>Employer contribution</span><b id="sumEr" style="color:#0369a1;"></b></div>
                                <div class="row-line"><span>Total cost (gross + employer)</span><b id="sumTotal"></b></div>
                            </div>
                            <div class="mt-2" id="sumCheck"></div>
                            <div class="mt-2 muted" style="font-size: 11.5px; min-height: 16px;" id="sumStatus"></div>
                            <div class="d-flex mt-3" style="gap: 8px;">
                                <button type="button" class="pc-btn pc-btn-primary flex-fill" id="btnSave" disabled><i class="fas fa-save"></i> Save changes</button>
                                <button type="button" class="pc-btn" id="btnDiscard" disabled title="Undo all unsaved changes"><i class="fas fa-undo"></i></button>
                            </div>
                            <div class="muted mt-2" style="font-size: 11px;" id="sumSaveHelp">Nothing changed yet.</div>
                        </div>
                    </div>
                </div>
            </div>
            <?php endif; ?>
        </div>
    </div>

    <div id="toastBox"></div>
    <?= csrf_field() ?>

    <?= view('payroll/_dialog') ?>
    <script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
    <?php if ($cur): ?>
    <script>
        (function () {
            'use strict';
            const CFG = {
                empId: <?= json_encode($empId) ?>,
                structureId: <?= (int) $cur['structure_id'] ?>,
                ctc: <?= json_encode((float) $cur['monthly_ctc']) ?>,
                from: <?= json_encode($cur['effective_from']) ?>,
                to: <?= json_encode($cur['effective_to']) ?>,
                returnParam: <?= json_encode($returnParam) ?>,
                previewUrl: '<?= site_url('payroll/salary_structure_preview') ?>',
                saveUrl: '<?= site_url('payroll/salary_structure/save') ?>',
                reviseUrl: '<?= site_url('payroll/salary_structure/revise') ?>',
                locked: <?= $curLocked ? 'true' : 'false' ?>,
                lockedCycles: <?= json_encode($curLock['locked_cycles'] ?? '') ?>,
                lockedUntil: <?= json_encode($curLock['locked_until'] ?? null) ?>,
                csrfName: '<?= csrf_token() ?>',
                flashSuccess: <?= json_encode(session()->getFlashdata('success')) ?>,
                flashError: <?= json_encode(session()->getFlashdata('error')) ?>
            };
            const COMPS = <?= json_encode(array_values($components), JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) ?>;

            const $ = (id) => document.getElementById(id);
            const inr = new Intl.NumberFormat('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
            const money = (v) => '₹ ' + inr.format(parseFloat(v || 0));
            const num = (v) => parseFloat(v || 0);
            function esc(v) {
                return String(v === null || v === undefined ? '' : v).replace(/&/g, '&amp;').replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
            }
            function toast(msg, kind) {
                const el = document.createElement('div');
                el.className = 'toast-msg ' + (kind === 'bad' ? 'toast-bad' : kind === 'info' ? 'toast-info' : 'toast-ok');
                el.textContent = msg;
                $('toastBox').appendChild(el);
                setTimeout(() => el.remove(), kind === 'bad' ? 9000 : 5000);
            }
            function fmtDate(d) {
                if (!d) return '';
                const t = new Date(d + 'T00:00:00');
                return t.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
            }
            function dayBefore(d) {
                const t = new Date(d + 'T00:00:00');
                t.setDate(t.getDate() - 1);
                return t.toISOString().slice(0, 10);
            }

            // ---- components ----
            const pay = COMPS.filter((c) => c.calculation_scope !== 'AGGREGATE');
            const totals = COMPS.filter((c) => c.calculation_scope === 'AGGREGATE');
            const amounts = {};
            COMPS.forEach((c) => { amounts[c.component_code] = num(c.monthly_amount); });
            const baseCodes = ['CTC', 'CTC1', 'GROSS'].concat(COMPS.map((c) => c.component_code).filter((c) => ['GROSS'].indexOf(c) < 0));

            // what the employee row is set to when the page opens
            const initial = {};
            pay.forEach((c) => {
                const own = num(c.is_overridden) === 1;
                initial[c.component_code] = {
                    mode: own ? String(c.own_calculation_type || 'FIXED').toUpperCase() : 'DEFAULT',
                    value: own ? String(num(c.own_value)) : '',
                    base: own ? String(c.own_base || 'NONE').toUpperCase() : 'CTC',
                    formula: own ? String(c.own_formula || '') : ''
                };
            });

            function ruleText(c) {
                const parts = [];
                const calc = String(c.rule_calculation_type || '').toUpperCase();
                if (num(c.is_manual) === 1 || calc === 'MANUAL') {
                    parts.push('Entered by hand (monthly manual amount)');
                } else if (num(c.is_slab) === 1 && c.slab_text) {
                    parts.push('<b>Slabs</b><div class="rule-lines">' + String(c.slab_text).split('; ').map((x) => '<div>&bull; ' + esc(x) + '</div>').join('') + '</div>');
                } else if ((calc === 'FORMULA' || calc === 'STATUTORY') && c.rule_formula) {
                    parts.push('<span class="f">= ' + esc(c.rule_formula) + '</span>');
                } else if (calc === 'PERCENTAGE') {
                    parts.push(esc(num(c.rule_value)) + '% of ' + esc(c.rule_base));
                } else if (calc === 'FIXED') {
                    parts.push(money(c.rule_value) + ' fixed');
                } else {
                    parts.push(esc(calc || '-'));
                }
                if (c.maximum_amount !== null && c.maximum_amount !== undefined && c.maximum_amount !== '') parts.push('max ' + money(c.maximum_amount));
                if (c.minimum_amount !== null && c.minimum_amount !== undefined && c.minimum_amount !== '') parts.push('min ' + money(c.minimum_amount));
                if (c.eligibility_parameter) parts.push('only if ESI applicable');
                return parts.join(' &middot; ');
            }

            function ownEditor(c) {
                const code = c.component_code;
                const s = initial[code];
                const opts = [['DEFAULT', 'Company rule'], ['FIXED', 'Fixed amount (₹)'], ['PERCENTAGE', 'Percentage (%)'], ['FORMULA', 'Formula'], ['MANUAL', 'Manual amount (₹)']];
                let h = '<div class="own-wrap" data-code="' + esc(code) + '">' +
                    '<select class="pc-control m">' + opts.map((o) => '<option value="' + o[0] + '"' + (s.mode === o[0] ? ' selected' : '') + '>' + o[1] + '</option>').join('') + '</select>' +
                    '<input type="number" min="0" step="0.01" class="pc-control v" placeholder="0.00" value="' + esc(s.value) + '">' +
                    '<span class="muted of">of</span><select class="pc-control b">' +
                    baseCodes.filter((b) => b !== code).map((b) => '<option value="' + esc(b) + '"' + (s.base === b ? ' selected' : '') + '>' + esc(b) + '</option>').join('') + '</select>' +
                    '<input type="text" class="pc-control fx" placeholder="e.g. ROUND(BASIC * 0.1, 0)" value="' + esc(s.formula) + '">' +
                    '</div>';
                return h;
            }

            function groupHtml(cls, title, list, totalCode, help) {
                if (!list.length) return '';
                let h = '<div class="group-head ' + cls + '"><span class="t">' + esc(title) + '</span>' +
                    (totalCode ? '<span class="sum" data-total="' + esc(totalCode) + '"></span>' : '') + '</div>';
                if (help) h += '<div class="px-4 pt-2 muted" style="font-size:11.5px;">' + help + '</div>';
                h += '<div class="table-responsive"><table class="cmp"><thead><tr><th style="padding-left:20px;">Component &amp; company rule</th><th>This employee</th>' +
                     '<th class="text-right">Per month</th><th></th></tr></thead><tbody>';
                h += list.map((c) => '<tr data-row="' + esc(c.component_code) + '"><td class="cmp-main" style="padding-left:20px;"><div class="cmp-name">' + esc(c.component_name) +
                    ' <span class="cmp-code">' + esc(c.component_code) + '</span></div><div class="rule">' + ruleText(c) + '</div></td><td>' + ownEditor(c) +
                    '</td><td class="amt" data-amt="' + esc(c.component_code) + '"></td><td style="width:40px;"><button type="button" class="pc-btn pc-btn-sm" data-reset="' +
                    esc(c.component_code) + '" title="Use the company rule"><i class="fas fa-undo"></i></button></td></tr>').join('');
                return h + '</tbody></table></div>';
            }

            function renderGroups() {
                const earn = pay.filter((c) => c.component_type === 'EARNING');
                const er = pay.filter((c) => c.component_type === 'EMPLOYER_CONTRIBUTION');
                const ded = pay.filter((c) => c.component_type === 'DEDUCTION');
                let h = groupHtml('group-earn', 'Earnings (paid to the employee)', earn, 'GROSS');
                h += groupHtml('group-er', 'Employer contributions (paid by the company, part of CTC)', er, 'TOTAL_EMPLOYER_CONTRIBUTION');
                h += groupHtml('group-ded', 'Deductions (taken from gross pay)', ded, 'TOTAL_DEDUCTIONS');
                if (totals.length) {
                    h += '<div class="group-head group-tot"><span class="t">Totals (calculated from the components above)</span></div><div class="table-responsive"><table class="cmp"><tbody>' +
                        totals.map((c) => '<tr><td class="cmp-main" style="padding-left:20px;"><div class="cmp-name">' + esc(c.component_name) + ' <span class="cmp-code">' + esc(c.component_code) +
                        '</span></div><div class="rule">' + (c.rule_formula ? '<span class="f">= ' + esc(c.rule_formula) + '</span>' : '') + '</div></td><td class="amt" data-amt="' +
                        esc(c.component_code) + '"></td></tr>').join('') + '</tbody></table></div>';
                }
                $('cmpGroups').innerHTML = h;
                document.querySelectorAll('.own-wrap').forEach(syncEditor);
            }

            function syncEditor(w) {
                const m = w.querySelector('.m').value;
                w.querySelector('.v').style.display = (m === 'FIXED' || m === 'PERCENTAGE' || m === 'MANUAL') ? '' : 'none';
                w.querySelector('.b').style.display = m === 'PERCENTAGE' ? '' : 'none';
                w.querySelector('.of').style.display = m === 'PERCENTAGE' ? '' : 'none';
                w.querySelector('.fx').style.display = m === 'FORMULA' ? '' : 'none';
            }

            function currentOf(code) {
                const w = document.querySelector('.own-wrap[data-code="' + code + '"]');
                return { mode: w.querySelector('.m').value, value: w.querySelector('.v').value.trim(), base: w.querySelector('.b').value,
                         formula: w.querySelector('.fx').value.trim() };
            }

            function isChanged(code) {
                const a = initial[code], b = currentOf(code);
                if (a.mode !== b.mode) return true;
                if (b.mode === 'DEFAULT') return false;
                if (b.mode === 'FORMULA') return a.formula.toUpperCase() !== b.formula.toUpperCase();
                if (num(a.value) !== num(b.value)) return true;
                return b.mode === 'PERCENTAGE' && a.base !== b.base;
            }

            function collectChanges() {
                return pay.filter((c) => isChanged(c.component_code)).map((c) => {
                    const s = currentOf(c.component_code);
                    return s.mode === 'DEFAULT'
                        ? { component_id: c.component_id, calculation_type: 'DEFAULT' }
                        : { component_id: c.component_id, calculation_type: s.mode, component_value: s.value === '' ? 0 : num(s.value),
                            percentage_base: s.base, formula_expression: s.formula };
                });
            }

            function ctcValue() { return num($('inpCtc').value); }
            function fromValue() { return $('inpFrom').value || CFG.from; }
            function headerChanged() { return ctcValue() !== num(CFG.ctc) || fromValue() !== CFG.from; }
            function changeCount() { return collectChanges().length + (ctcValue() !== num(CFG.ctc) ? 1 : 0) + (fromValue() !== CFG.from ? 1 : 0); }

            // ---- amounts and summary ----
            function paintAmounts() {
                document.querySelectorAll('[data-amt]').forEach((td) => { td.textContent = money(amounts[td.dataset.amt] || 0); });
                const sumType = (t) => pay.filter((c) => c.component_type === t).reduce((s, c) => s + (amounts[c.component_code] || 0), 0);
                const gross = amounts.GROSS !== undefined ? amounts.GROSS : sumType('EARNING');
                const ded = amounts.TOTAL_DEDUCTIONS !== undefined ? amounts.TOTAL_DEDUCTIONS : sumType('DEDUCTION');
                const er = amounts.TOTAL_EMPLOYER_CONTRIBUTION !== undefined ? amounts.TOTAL_EMPLOYER_CONTRIBUTION : sumType('EMPLOYER_CONTRIBUTION');
                const net = amounts.NET_PAY !== undefined ? amounts.NET_PAY : gross - ded;
                const total = amounts.TOTAL_CTC !== undefined ? amounts.TOTAL_CTC : gross + er;
                document.querySelectorAll('[data-total]').forEach((s) => {
                    s.textContent = money(s.dataset.total === 'GROSS' ? gross : s.dataset.total === 'TOTAL_DEDUCTIONS' ? ded : er);
                });
                $('sumGross').textContent = money(gross);
                $('sumDed').textContent = '− ' + money(ded);
                $('sumEr').textContent = money(er);
                $('sumTotal').textContent = money(total);
                $('sumNet').textContent = money(net);
                const diff = total - ctcValue();
                $('sumCheck').innerHTML = Math.abs(diff) <= 0.05
                    ? '<span class="check-ok"><i class="fas fa-check-circle mr-1"></i>Gross + employer contribution = monthly CTC</span>'
                    : '<span class="check-bad"><i class="fas fa-exclamation-triangle mr-1"></i>Total cost is ' + money(Math.abs(diff)) + (diff > 0 ? ' more' : ' less') +
                      ' than the monthly CTC (' + money(ctcValue()) + ')</span>';
            }

            function paintState() {
                pay.forEach((c) => {
                    const tr = document.querySelector('tr[data-row="' + c.component_code + '"]');
                    if (tr) tr.classList.toggle('changed', isChanged(c.component_code));
                });
                $('lblAnnual').textContent = money(ctcValue() * 12);
                const from = fromValue();
                $('lblFromHelp').innerHTML = from === CFG.from
                    ? '<i class="fas fa-pen mr-1"></i>Changes correct this salary period (' + fmtDate(CFG.from) + ' &ndash; ' + (CFG.to ? fmtDate(CFG.to) : 'onwards') + ').'
                    : '<i class="fas fa-code-branch mr-1" style="color:var(--bloom-purple);"></i><b>New salary from ' + fmtDate(from) + '.</b> The current one stays as it is and ends on ' + fmtDate(dayBefore(from)) + '.';
                const n = changeCount();
                $('chipChanges').style.display = n ? '' : 'none';
                $('chipChanges').textContent = n + ' unsaved change' + (n > 1 ? 's' : '');
                $('btnSave').disabled = n === 0 || busy;
                $('btnDiscard').disabled = n === 0 || busy;
                $('sumSaveHelp').textContent = n === 0 ? 'Nothing changed yet.'
                    : (from !== CFG.from ? 'Saving creates a new salary from ' + fmtDate(from) + '.' : 'Saving updates this salary period and recalculates it.');
            }

            let timer = null, seq = 0, busy = false;
            function schedulePreview() {
                paintState();
                $('sumStatus').innerHTML = '<i class="fas fa-spinner fa-spin mr-1"></i>Calculating...';
                clearTimeout(timer);
                timer = setTimeout(runPreview, 350);
            }

            function post(url, data) {
                const fd = new FormData();
                Object.keys(data).forEach((k) => fd.append(k, data[k] === null || data[k] === undefined ? '' : data[k]));
                const csrf = document.querySelector('input[name="' + CFG.csrfName + '"]');
                if (csrf) fd.append(CFG.csrfName, csrf.value);
                return fetch(url, { method: 'POST', body: fd, headers: { 'X-Requested-With': 'XMLHttpRequest' } })
                    .then((r) => r.json())
                    .then((j) => { if (j.csrf_token && csrf) csrf.value = j.csrf_token; return j; })
                    .catch((e) => ({ status: false, message: 'The server did not answer (' + e.message + ').' }));
            }

            function runPreview() {
                const mySeq = ++seq;
                post(CFG.previewUrl, { emp_id: CFG.empId, structure_id: CFG.structureId, monthly_ctc: ctcValue() > 0 ? ctcValue() : '',
                                       changes: JSON.stringify(collectChanges()) })
                    .then((r) => {
                        if (mySeq !== seq) return;
                        if (!r.status) {
                            $('sumStatus').innerHTML = '<span style="color:#b91c1c;font-weight:700;"><i class="fas fa-exclamation-triangle mr-1"></i>' + esc(r.message) + '</span>';
                            return;
                        }
                        Object.assign(amounts, r.amounts || {}, r.totals || {});
                        paintAmounts();
                        $('sumStatus').innerHTML = '<i class="fas fa-check mr-1" style="color:#15803d;"></i>Calculated by the salary engine' +
                            (changeCount() ? ' (not saved yet)' : '');
                    });
            }

            // ---- events ----
            document.addEventListener('input', (e) => {
                const w = e.target.closest('.own-wrap');
                if (w) { if (e.target.classList.contains('m')) syncEditor(w); schedulePreview(); return; }
                if (e.target.id === 'inpCtc' || e.target.id === 'inpFrom') schedulePreview();
            });
            document.addEventListener('change', (e) => {
                const w = e.target.closest('.own-wrap');
                if (w) { syncEditor(w); schedulePreview(); }
            });
            document.addEventListener('click', (e) => {
                const r = e.target.closest('[data-reset]');
                if (r) {
                    const w = document.querySelector('.own-wrap[data-code="' + r.dataset.reset + '"]');
                    w.querySelector('.m').value = 'DEFAULT';
                    syncEditor(w);
                    schedulePreview();
                }
            });
            $('btnDiscard').addEventListener('click', async () => {
                const ans = await payrollDialog.ask({ title: 'Discard changes', message: 'Undo all unsaved changes?',
                                                      okText: 'Discard', cancelText: 'Keep editing' });
                if (!ans.ok) return;
                $('inpCtc').value = CFG.ctc;
                $('inpFrom').value = CFG.from;
                renderGroups();
                schedulePreview();
            });
            $('btnSave').addEventListener('click', async () => {
                const from = fromValue();
                if (ctcValue() <= 0) { toast('Monthly CTC must be more than 0.', 'bad'); return; }
                const msg = from !== CFG.from
                    ? 'Save as a NEW salary from ' + fmtDate(from) + '?\n\nThe current salary stays as it is and ends on ' + fmtDate(dayBefore(from)) + '.'
                    : 'Save the changes to this salary period (' + fmtDate(CFG.from) + ' – ' + (CFG.to ? fmtDate(CFG.to) : 'onwards') + ')?';
                const ans = await payrollDialog.ask({ title: 'Save salary', message: msg, okText: 'Save' });
                if (!ans.ok) return;
                busy = true;
                paintState();
                $('btnSave').innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';
                post(CFG.saveUrl, { emp_id: CFG.empId, structure_id: CFG.structureId, monthly_ctc: ctcValue(), effective_from: from,
                                    changes: JSON.stringify(collectChanges()), return: CFG.returnParam })
                    .then((r) => {
                        if (r.status) {
                            saved = true;
                            toast(r.message, 'ok');
                            setTimeout(() => { window.location.href = r.redirect; }, 700);
                        } else {
                            busy = false;
                            $('btnSave').innerHTML = '<i class="fas fa-save"></i> Save changes';
                            paintState();
                            toast(r.message || 'The salary could not be saved.', 'bad');
                        }
                    });
            });
            let saved = false;
            window.addEventListener('beforeunload', (e) => {
                if (!saved && changeCount() > 0) { e.preventDefault(); e.returnValue = ''; }
            });

            // ---- Revise CTC: a new CTC from a new date (a new salary period) ----
            function dayAfter(d) {
                const t = new Date(d + 'T00:00:00');
                t.setDate(t.getDate() + 1);
                return new Date(t.getTime() - t.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
            }
            function localDayBefore(d) {
                const t = new Date(d + 'T00:00:00');
                t.setDate(t.getDate() - 1);
                return new Date(t.getTime() - t.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
            }
            const revMin = dayAfter(CFG.from);                 // the first day of the period cannot be the revise date
            const revMax = CFG.to || '';
            function reviseState() {
                const ctc = num($('revCtc').value), from = $('revFrom').value;
                let problem = '';
                if (!(ctc > 0)) problem = 'Enter the new monthly CTC.';
                else if (ctc === num(CFG.ctc)) problem = 'The new CTC is the same as the current one.';
                else if (!from) problem = 'Choose the date the new CTC applies from.';
                else if (from < revMin) problem = 'The date must be after ' + fmtDate(CFG.from) + ', the first day of this period.';
                else if (revMax && from > revMax) problem = 'This period ends on ' + fmtDate(revMax) + '. Open the later period to revise after that.';

                const diff = ctc - num(CFG.ctc);
                $('revDiff').textContent = ctc > 0 && diff !== 0
                    ? (diff > 0 ? '+ ' : '− ') + money(Math.abs(diff)) + ' (' + (diff > 0 ? '+' : '−') + (Math.abs(diff) / num(CFG.ctc) * 100).toFixed(1) + '%) · annual ' + money(ctc * 12)
                    : '';
                $('revRange').textContent = 'Between ' + fmtDate(revMin) + ' and ' + (revMax ? fmtDate(revMax) : 'any later date');

                const ok = problem === '';
                $('revSummary').style.display = ok ? '' : 'none';
                if (ok) {
                    $('revSummaryText').innerHTML = 'Current salary <b>' + esc(money(CFG.ctc)) + '</b>: ' + esc(fmtDate(CFG.from)) + ' &ndash; <b>' +
                        esc(fmtDate(localDayBefore(from))) + '</b> (ends the day before).<br>New salary <b>' + esc(money(ctc)) + '</b>: <b>' +
                        esc(fmtDate(from)) + '</b> &ndash; ' + (revMax ? esc(fmtDate(revMax)) : 'onwards') + '.';
                }
                const late = ok && CFG.lockedUntil && from <= CFG.lockedUntil;
                $('revWarn').style.display = (problem && (ctc > 0 || from)) || late ? '' : 'none';
                $('revWarnText').textContent = problem && (ctc > 0 || from) ? problem
                    : (late ? 'Payroll ' + CFG.lockedCycles + ' is already finalized (pay period up to ' + fmtDate(CFG.lockedUntil) +
                              '). It keeps the old salary and will not change. To leave paid months untouched, start the new CTC after that date.' : '');
                $('btnReviseSave').disabled = !ok || busy;
            }
            $('btnReviseOpen').addEventListener('click', () => {
                if (collectChanges().length || (!CFG.locked && ctcValue() !== num(CFG.ctc))) {
                    toast('Save or discard the unsaved changes on this page first.', 'bad');
                    return;
                }
                const today = new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 10);
                let def = today > revMin ? today : revMin;
                if (CFG.lockedUntil && def <= CFG.lockedUntil) def = dayAfter(CFG.lockedUntil);
                if (revMax && def > revMax) def = revMax;
                $('revFrom').min = revMin;
                if (revMax) $('revFrom').max = revMax;
                $('revFrom').value = def;
                $('revCtc').value = '';
                $('reviseBox').style.display = '';
                reviseState();
                $('revCtc').focus();
            });
            $('btnReviseCancel').addEventListener('click', () => { $('reviseBox').style.display = 'none'; });
            $('revCtc').addEventListener('input', reviseState);
            $('revFrom').addEventListener('input', reviseState);
            $('btnReviseSave').addEventListener('click', async () => {
                const ctc = num($('revCtc').value), from = $('revFrom').value;
                const ans = await payrollDialog.ask({
                    title: 'Revise CTC',
                    message: 'New monthly CTC ' + money(ctc) + ' from ' + fmtDate(from) + '?\n\nThe current salary (' + money(CFG.ctc) +
                             ') stays as it is and ends on ' + fmtDate(localDayBefore(from)) + '.',
                    okText: 'Revise CTC'
                });
                if (!ans.ok) return;
                busy = true;
                $('btnReviseSave').disabled = true;
                $('btnReviseSave').innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';
                post(CFG.reviseUrl, { emp_id: CFG.empId, structure_id: CFG.structureId, monthly_ctc: ctc, effective_from: from, return: CFG.returnParam })
                    .then((r) => {
                        if (r.status) {
                            saved = true;
                            toast(r.message, 'ok');
                            setTimeout(() => { window.location.href = r.redirect; }, 700);
                        } else {
                            busy = false;
                            $('btnReviseSave').innerHTML = '<i class="fas fa-save"></i> Save revised CTC';
                            reviseState();
                            toast(r.message || 'The CTC could not be revised.', 'bad');
                        }
                    });
            });

            renderGroups();
            paintAmounts();
            paintState();
            $('sumStatus').innerHTML = '<i class="fas fa-check mr-1" style="color:#15803d;"></i>Saved amounts';
            if (CFG.flashSuccess) toast(CFG.flashSuccess, 'ok');
            if (CFG.flashError) toast(CFG.flashError, 'bad');
        })();
    </script>
    <?php endif; ?>
</body>

</html>
