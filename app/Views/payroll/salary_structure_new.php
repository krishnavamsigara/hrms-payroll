<?php
/**
 * Add a salary for one employee (a new joiner, or a gap in the salary history).
 * Data: $employee (name, department, joining date ...), $periods (existing salaries, if any),
 *       $components (company rules of every active component), $defaultFrom,
 *       $returnParam ('' or 'cycle/{id}'), $returnUrl.
 * Every active component is attached automatically with the company rule; amounts come
 * from the salary engine (hrms_preview_new_salary). Create = hrms_create_employee_salary.
 */
$empId   = (string) ($employee['emp_id'] ?? '');
$empName = (string) ($employee['emp_name'] ?? $empId);
$fmtDate = fn($d) => $d ? date('d M Y', strtotime($d)) : '';
$backLabel = $returnParam !== '' ? 'Back to payroll' : 'Salary structures';
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>BloomHR | Add salary for <?= esc($empName) ?></title>
    <link rel="icon" type="image/jpeg" href="<?= base_url('public/dist/img/bloom.jpg') ?>">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
    <?= view('payroll/_salary_page_styles') ?>
</head>

<body class="hold-transition sidebar-mini layout-fixed">
    <div class="content-wrapper">
        <div class="payroll-page">

            <!-- EMPLOYEE HEADER -->
            <div class="emp-hero d-flex flex-wrap align-items-center justify-content-between" style="gap: 14px;">
                <div class="d-flex align-items-center" style="gap: 14px;">
                    <span class="emp-avatar"><?= esc(strtoupper(substr(preg_replace('/[^A-Za-z]/', '', $empName) ?: 'E', 0, 2))) ?></span>
                    <div>
                        <div style="font-size: 20px; font-weight: 800;">Add salary for <?= esc($empName) ?></div>
                        <div class="meta">
                            <?= esc($empId) ?>
                            <?php if (!empty($employee['department'])): ?> &middot; <?= esc($employee['department']) ?><?php endif; ?>
                            <?php if (!empty($employee['designation'])): ?> &middot; <?= esc($employee['designation']) ?><?php endif; ?>
                            <?php if (!empty($employee['joining_date'])): ?> &middot; Joined <?= esc($fmtDate($employee['joining_date'])) ?><?php endif; ?>
                        </div>
                    </div>
                </div>
                <a href="<?= esc($returnUrl, 'attr') ?>" class="pc-btn"><i class="fas fa-arrow-left"></i> <?= esc($backLabel) ?></a>
            </div>

            <div class="row">
                <div class="col-xl-8 order-2 order-xl-1">

                    <?php if (!empty($periods)): ?>
                        <div class="pc-card"><div class="pc-body">
                            <p class="pc-section-title"><i class="fas fa-calendar-alt mr-1" style="color: var(--bloom-purple);"></i> Existing salaries</p>
                            <p class="pc-section-help mb-2">The new salary must start on a date none of these cover. If a later salary exists, the new one ends the day before it.</p>
                            <div class="d-flex flex-wrap" style="gap: 6px;">
                                <?php foreach ($periods as $p): ?>
                                    <a class="chip badge-soft-primary" style="text-decoration: none;"
                                       href="<?= base_url('payroll/salary_structure/edit/' . rawurlencode($empId)) ?>?period=<?= (int) $p['structure_id'] ?>">
                                        <?= esc($fmtDate($p['effective_from'])) ?> &ndash; <?= $p['effective_to'] ? esc($fmtDate($p['effective_to'])) : 'onwards' ?>
                                        &middot; &#8377; <?= number_format((float) $p['monthly_ctc'], 2) ?>
                                    </a>
                                <?php endforeach; ?>
                            </div>
                        </div></div>
                    <?php endif; ?>

                    <!-- 1. SALARY -->
                    <div class="pc-card">
                        <div class="pc-body">
                            <p class="pc-section-title"><span class="step-no">1</span>Salary</p>
                            <p class="pc-section-help mb-3">Enter the monthly cost to company. Everything else is calculated from it.</p>
                            <div class="row">
                                <div class="col-sm-4 mb-2">
                                    <label class="pc-label" for="inpCtc">Monthly CTC (&#8377;)</label>
                                    <input type="number" min="1" step="1" class="pc-control w-100 font-weight-bold" id="inpCtc" placeholder="e.g. 30000" autofocus>
                                    <div class="muted mt-1" style="font-size: 11.5px;">Annual: <b id="lblAnnual">&#8377; 0.00</b></div>
                                </div>
                                <div class="col-sm-4 mb-2">
                                    <label class="pc-label" for="inpFrom">Applies from</label>
                                    <input type="date" class="pc-control w-100" id="inpFrom" value="<?= esc($defaultFrom) ?>">
                                    <div class="muted mt-1" style="font-size: 11.5px;">
                                        <?= !empty($employee['joining_date']) ? 'Joining date: ' . esc($fmtDate($employee['joining_date'])) : 'No joining date recorded' ?>
                                    </div>
                                </div>
                                <div class="col-sm-4 mb-2">
                                    <label class="pc-label" for="inpEsi">ESI applicable</label>
                                    <select class="pc-control w-100" id="inpEsi">
                                        <option value="N">No</option>
                                        <option value="Y">Yes</option>
                                    </select>
                                    <div class="muted mt-1" style="font-size: 11.5px;" id="lblEsiHelp">Suggested from the gross pay (ESI applies up to &#8377; <?= number_format((float) ($esiLimit ?? 21000), 0) ?>).</div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- 2. COMPONENTS -->
                    <div class="pc-card">
                        <div class="pc-body pb-2">
                            <p class="pc-section-title"><span class="step-no">2</span>Components</p>
                            <p class="pc-section-help">
                                Every active component from <b>Salary Components</b> is added with the company rule. Amounts are calculated by the salary engine.
                                To give this employee something different for one component, use <b>Edit</b> after creating the salary.
                            </p>
                        </div>
                        <div id="cmpGroups"></div>
                    </div>
                </div>

                <!-- SUMMARY -->
                <div class="col-xl-4 order-1 order-xl-2">
                    <div class="pc-card summary">
                        <div class="pc-body">
                            <span class="pc-label mb-0">Net pay (take-home) per month</span>
                            <div class="net mt-1" id="sumNet">&#8377; 0.00</div>
                            <div class="mt-3">
                                <div class="row-line"><span>Gross earnings</span><b id="sumGross">&#8377; 0.00</b></div>
                                <div class="row-line"><span>Deductions</span><b id="sumDed" style="color:#b91c1c;">&#8377; 0.00</b></div>
                                <div class="row-line"><span>Employer contribution</span><b id="sumEr" style="color:#0369a1;">&#8377; 0.00</b></div>
                                <div class="row-line"><span>Total cost (gross + employer)</span><b id="sumTotal">&#8377; 0.00</b></div>
                            </div>
                            <div class="mt-2" id="sumCheck"></div>
                            <div class="mt-2 muted" style="font-size: 11.5px; min-height: 16px;" id="sumStatus">Enter the monthly CTC to see the salary.</div>
                            <button type="button" class="pc-btn pc-btn-primary w-100 mt-3" id="btnCreate" disabled><i class="fas fa-plus-circle"></i> Create salary</button>
                            <div class="muted mt-2" style="font-size: 11px;" id="sumHelp"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div id="toastBox"></div>
    <?= csrf_field() ?>

    <?= view('payroll/_dialog') ?>
    <script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
    <script>
        (function () {
            'use strict';
            const CFG = {
                empId: <?= json_encode($empId) ?>,
                returnParam: <?= json_encode($returnParam) ?>,
                previewUrl: '<?= site_url('payroll/salary_structure/new_preview') ?>',
                createUrl: '<?= site_url('payroll/salary_structure/create') ?>',
                csrfName: '<?= csrf_token() ?>',
                esiLimit: <?= json_encode((float) ($esiLimit ?? 21000)) ?>
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
                el.className = 'toast-msg ' + (kind === 'bad' ? 'toast-bad' : 'toast-ok');
                el.textContent = msg;
                $('toastBox').appendChild(el);
                setTimeout(() => el.remove(), kind === 'bad' ? 9000 : 5000);
            }
            function fmtDate(d) {
                if (!d) return '';
                return new Date(d + 'T00:00:00').toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
            }

            const pay = COMPS.filter((c) => c.calculation_scope !== 'AGGREGATE');
            const totals = COMPS.filter((c) => c.calculation_scope === 'AGGREGATE');
            let amounts = {};

            function ruleText(c) {
                const parts = [];
                const calc = String(c.rule_calculation_type || '').toUpperCase();
                if (num(c.is_manual) === 1 || calc === 'MANUAL') parts.push('Entered by hand (monthly manual amount)');
                else if (num(c.is_slab) === 1 && c.slab_text) parts.push('<b>Slabs</b><div class="rule-lines">' + String(c.slab_text).split('; ').map((x) => '<div>&bull; ' + esc(x) + '</div>').join('') + '</div>');
                else if ((calc === 'FORMULA' || calc === 'STATUTORY') && c.rule_formula) parts.push('<span class="f">= ' + esc(c.rule_formula) + '</span>');
                else if (calc === 'PERCENTAGE') parts.push(esc(num(c.rule_value)) + '% of ' + esc(c.rule_base));
                else if (calc === 'FIXED') parts.push(money(c.rule_value) + ' fixed');
                else parts.push(esc(calc || '-'));
                if (c.maximum_amount !== null && c.maximum_amount !== undefined && c.maximum_amount !== '') parts.push('max ' + money(c.maximum_amount));
                if (c.minimum_amount !== null && c.minimum_amount !== undefined && c.minimum_amount !== '') parts.push('min ' + money(c.minimum_amount));
                if (c.eligibility_parameter) parts.push('only if ESI applicable');
                return parts.join(' &middot; ');
            }

            function group(cls, title, list, totalCode) {
                if (!list.length) return '';
                return '<div class="group-head ' + cls + '"><span class="t">' + esc(title) + '</span>' +
                    (totalCode ? '<span class="sum" data-total="' + esc(totalCode) + '"></span>' : '') + '</div>' +
                    '<div class="table-responsive"><table class="cmp"><thead><tr><th style="padding-left:20px;">Component &amp; company rule</th>' +
                    '<th class="text-right" style="padding-right:20px;">Per month</th></tr></thead><tbody>' +
                    list.map((c) => '<tr><td class="cmp-main" style="padding-left:20px;"><div class="cmp-name">' + esc(c.component_name) + ' <span class="cmp-code">' +
                        esc(c.component_code) + '</span></div><div class="rule">' + (c.calculation_scope === 'AGGREGATE'
                        ? (c.rule_formula ? '<span class="f">= ' + esc(c.rule_formula) + '</span>' : '') : ruleText(c)) +
                        '</div></td><td class="amt" style="padding-right:20px;" data-amt="' + esc(c.component_code) + '"></td></tr>').join('') +
                    '</tbody></table></div>';
            }

            function render() {
                $('cmpGroups').innerHTML =
                    group('group-earn', 'Earnings (paid to the employee)', pay.filter((c) => c.component_type === 'EARNING'), 'GROSS') +
                    group('group-er', 'Employer contributions (paid by the company, part of CTC)', pay.filter((c) => c.component_type === 'EMPLOYER_CONTRIBUTION'), 'TOTAL_EMPLOYER_CONTRIBUTION') +
                    group('group-ded', 'Deductions (taken from gross pay)', pay.filter((c) => c.component_type === 'DEDUCTION'), 'TOTAL_DEDUCTIONS') +
                    group('group-tot', 'Totals (calculated from the components above)', totals, null);
                paint();
            }

            function paint() {
                document.querySelectorAll('[data-amt]').forEach((td) => { td.textContent = amounts[td.dataset.amt] === undefined ? '–' : money(amounts[td.dataset.amt]); });
                const sumType = (t) => pay.filter((c) => c.component_type === t).reduce((s, c) => s + num(amounts[c.component_code]), 0);
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
                $('lblAnnual').textContent = money(num($('inpCtc').value) * 12);
                const ctc = num($('inpCtc').value);
                $('sumCheck').innerHTML = !ctc || amounts.TOTAL_CTC === undefined ? ''
                    : (Math.abs(total - ctc) <= 0.05
                        ? '<span class="check-ok"><i class="fas fa-check-circle mr-1"></i>Gross + employer contribution = monthly CTC</span>'
                        : '<span class="check-bad"><i class="fas fa-exclamation-triangle mr-1"></i>Total cost is ' + money(Math.abs(total - ctc)) + (total > ctc ? ' more' : ' less') + ' than the monthly CTC</span>');
                return gross;
            }

            let timer = null, seq = 0, ready = false, busy = false, esiTouched = false;
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

            function updateButton() {
                const ok = ready && num($('inpCtc').value) > 0 && $('inpFrom').value !== '' && !busy;
                $('btnCreate').disabled = !ok;
                $('sumHelp').textContent = ok ? 'Creates the salary from ' + fmtDate($('inpFrom').value) + ' with ' + pay.length + ' components.' : '';
            }

            function schedule() {
                ready = false;
                updateButton();
                if (num($('inpCtc').value) <= 0) {
                    amounts = {};
                    paint();
                    $('sumStatus').textContent = 'Enter the monthly CTC to see the salary.';
                    return;
                }
                $('sumStatus').innerHTML = '<i class="fas fa-spinner fa-spin mr-1"></i>Calculating...';
                clearTimeout(timer);
                timer = setTimeout(() => runPreview(false), 350);
            }

            function runPreview(afterEsiSwitch) {
                const mySeq = ++seq;
                post(CFG.previewUrl, { emp_id: CFG.empId, monthly_ctc: num($('inpCtc').value), esi: $('inpEsi').value })
                    .then((r) => {
                        if (mySeq !== seq) return;
                        if (!r.status) {
                            $('sumStatus').innerHTML = '<span style="color:#b91c1c;font-weight:700;"><i class="fas fa-exclamation-triangle mr-1"></i>' + esc(r.message) + '</span>';
                            return;
                        }
                        amounts = Object.assign({}, r.amounts || {}, r.totals || {});
                        const gross = paint();
                        // ESI suggestion from the gross pay, until the user picks ESI themself
                        const suggest = gross > 0 && gross <= CFG.esiLimit ? 'Y' : 'N';
                        if (!esiTouched && !afterEsiSwitch && suggest !== $('inpEsi').value) {
                            $('inpEsi').value = suggest;
                            $('lblEsiHelp').innerHTML = 'Set to <b>' + (suggest === 'Y' ? 'Yes' : 'No') + '</b>: gross is ' + money(gross) + (suggest === 'Y' ? ' (up to ' : ' (above ') + '₹ 21,000).';
                            runPreview(true);
                            return;
                        }
                        ready = true;
                        updateButton();
                        $('sumStatus').innerHTML = '<i class="fas fa-check mr-1" style="color:#15803d;"></i>Calculated by the salary engine (not saved yet)';
                    });
            }

            $('inpCtc').addEventListener('input', schedule);
            $('inpFrom').addEventListener('input', updateButton);
            $('inpEsi').addEventListener('change', () => {
                esiTouched = true;
                $('lblEsiHelp').textContent = 'Chosen by you.';
                schedule();
            });
            $('btnCreate').addEventListener('click', async () => {
                const ctc = num($('inpCtc').value), from = $('inpFrom').value;
                const ans = await payrollDialog.ask({
                    title: 'Create salary',
                    message: 'Create a salary for ' + <?= json_encode($empName) ?> + ' from ' + fmtDate(from) + '?\n\nMonthly CTC ' + money(ctc) +
                             ', ESI ' + ($('inpEsi').value === 'Y' ? 'applicable' : 'not applicable') + ', net pay ' + $('sumNet').textContent + '.',
                    okText: 'Create salary'
                });
                if (!ans.ok) return;
                busy = true;
                updateButton();
                $('btnCreate').innerHTML = '<i class="fas fa-spinner fa-spin"></i> Creating...';
                post(CFG.createUrl, { emp_id: CFG.empId, monthly_ctc: ctc, effective_from: from, esi: $('inpEsi').value, return: CFG.returnParam })
                    .then((r) => {
                        if (r.status) {
                            toast(r.message, 'ok');
                            setTimeout(() => { window.location.href = r.redirect; }, 700);
                        } else {
                            busy = false;
                            $('btnCreate').innerHTML = '<i class="fas fa-plus-circle"></i> Create salary';
                            updateButton();
                            toast(r.message || 'The salary could not be created.', 'bad');
                        }
                    });
            });

            render();
        })();
    </script>
</body>

</html>
