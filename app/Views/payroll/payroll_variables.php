<?php
/**
 * Payroll variables: every name a formula, a percentage, a slab or an "applies only when"
 * condition can use that is not a component.
 *   SYSTEM    calculated by the engine (CTC, CTC1, PAYABLE_DAYS ...), read only
 *   TOTAL     the sum of a type when no component has that code, read only
 *   EMPLOYEE  added here; every employee has the default unless their own value is set
 *             (on the employee's salary page)
 * Data: $variables (hrms_payroll_variable_list). Saving: POST payroll/variables/save.
 */
$vars  = $variables ?? [];
$kinds = ['EMPLOYEE' => 'Added by HR', 'SYSTEM' => 'Built-in', 'TOTAL' => 'Built-in total'];
$fmt   = fn($v, $type) => $type === 'FLAG' ? ((float) $v != 0 ? 'Yes' : 'No') : rtrim(rtrim(number_format((float) $v, 4, '.', ''), '0'), '.');
$jsonFlags = JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP;
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>BloomHR | Payroll variables</title>
    <link rel="icon" type="image/jpeg" href="<?= base_url('public/dist/img/bloom.jpg') ?>">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
    <?= view('payroll/_salary_page_styles') ?>
    <style>
        table.vars { width: 100%; font-size: 12.5px; }
        table.vars th { font-size: 10.5px; text-transform: uppercase; color: var(--text-muted); font-weight: 800; padding: 8px 10px; border-bottom: 1px solid var(--border-color); }
        table.vars td { padding: 9px 10px; border-bottom: 1px solid #f1f5f9; vertical-align: top; }
        table.vars code { color: var(--bloom-dark); font-weight: 700; }
        .row-off { opacity: .5; }
    </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed">
    <div class="content-wrapper">
        <div class="payroll-page">
            <div class="d-flex flex-wrap justify-content-between align-items-center mb-3" style="gap: 10px;">
                <div>
                    <div class="small" style="color: var(--text-muted);"><a href="<?= base_url('payroll/salary_components') ?>">Salary components</a> / Payroll variables</div>
                    <h1 class="pc-heading">Payroll variables</h1>
                    <div class="pc-section-help">Values a formula can use besides the components. Add your own, for example PF applies, metro city or a shift allowance rate.</div>
                </div>
                <a href="<?= base_url('payroll/salary_components') ?>" class="pc-btn"><i class="fas fa-arrow-left"></i> Back to components</a>
            </div>

            <div class="row">
                <div class="col-xl-4">
                    <div class="pc-card"><div class="pc-body">
                        <p class="pc-section-title mb-1" id="formTitle">Add a variable</p>
                        <p class="pc-section-help mb-3">Every employee gets the default value. Give one employee another value on their salary page.</p>
                        <label class="pc-label" for="vCode">Code (used in formulas)</label>
                        <input class="pc-control w-100 mb-2" id="vCode" maxlength="40" placeholder="PF_APPLICABLE" style="font-family: ui-monospace, Consolas, monospace; text-transform: uppercase;">
                        <label class="pc-label" for="vName">Name</label>
                        <input class="pc-control w-100 mb-2" id="vName" maxlength="100" placeholder="PF applies">
                        <label class="pc-label" for="vDesc">Description</label>
                        <input class="pc-control w-100 mb-2" id="vDesc" maxlength="500" placeholder="Yes when the employee is in PF">
                        <div class="row">
                            <div class="col-6"><label class="pc-label" for="vType">Type</label>
                                <select class="pc-control w-100 mb-2" id="vType"><option value="FLAG">Yes / No</option><option value="NUMBER">Number</option></select></div>
                            <div class="col-6"><label class="pc-label" for="vDefault">Default</label>
                                <select class="pc-control w-100 mb-2" id="vDefaultFlag"><option value="1">Yes</option><option value="0">No</option></select>
                                <input type="number" step="0.0001" class="pc-control w-100 mb-2" id="vDefaultNum" value="0" style="display: none;"></div>
                        </div>
                        <label class="d-flex align-items-center mb-3" style="gap: 6px; cursor: pointer;"><input type="checkbox" id="vActive" checked> Active</label>
                        <div class="d-flex" style="gap: 8px;">
                            <button type="button" class="pc-btn pc-btn-primary flex-fill" id="btnSave"><i class="fas fa-save"></i> Save variable</button>
                            <button type="button" class="pc-btn" id="btnNew" title="Clear the form"><i class="fas fa-plus"></i> New</button>
                        </div>
                        <div class="small mt-2" style="color: var(--text-muted);">Changing the default of a variable in use recalculates every salary. A Yes/No variable used in "applies only when" stays Yes/No.</div>
                    </div></div>
                </div>
                <div class="col-xl-8">
                    <div class="pc-card"><div class="table-responsive">
                        <table class="vars">
                            <thead><tr><th>Code</th><th>Name</th><th>Kind</th><th>Type</th><th>Default</th><th>Used by</th><th>Own values</th><th></th></tr></thead>
                            <tbody>
                            <?php if (!$vars): ?>
                                <tr><td colspan="8" class="text-center py-4" style="color: var(--text-muted);">No variables, or you do not have access.</td></tr>
                            <?php endif; ?>
                            <?php foreach ($vars as $v): ?>
                                <tr class="<?= (int) $v['is_active'] === 1 ? '' : 'row-off' ?>">
                                    <td><code><?= esc($v['var_code']) ?></code></td>
                                    <td><?= esc($v['var_name']) ?><?php if (!empty($v['description'])): ?><div class="small" style="color: var(--text-muted);"><?= esc($v['description']) ?></div><?php endif; ?></td>
                                    <td><span class="chip <?= $v['var_kind'] === 'EMPLOYEE' ? 'badge-soft-primary' : 'badge-soft-secondary' ?>"><?= esc($kinds[$v['var_kind']] ?? $v['var_kind']) ?></span></td>
                                    <td><?= $v['data_type'] === 'FLAG' ? 'Yes / No' : 'Number' ?></td>
                                    <td><?= $v['var_kind'] === 'EMPLOYEE' ? esc($fmt($v['default_value'], $v['data_type'])) : '<span style="color: var(--text-muted);">calculated</span>' ?></td>
                                    <td class="small"><?= esc($v['used_by'] ?: '—') ?></td>
                                    <td><?= $v['var_kind'] === 'EMPLOYEE' ? (int) $v['employees_set'] : '' ?></td>
                                    <td class="text-right"><?php if ($v['var_kind'] === 'EMPLOYEE'): ?>
                                        <button type="button" class="pc-btn pc-btn-sm" data-edit="<?= esc($v['var_code'], 'attr') ?>"><i class="fas fa-edit"></i> Edit</button>
                                    <?php endif; ?></td>
                                </tr>
                            <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div></div>
                </div>
            </div>
        </div>
    </div>

    <div id="toastBox"></div>
    <?= csrf_field() ?>
    <script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
    <script>
        (function () {
            'use strict';
            const VARS = <?= json_encode(array_values($vars), $jsonFlags) ?>;
            const CFG = { saveUrl: '<?= site_url('payroll/variables/save') ?>', csrfName: '<?= csrf_token() ?>',
                          flashOk: <?= json_encode(session()->getFlashdata('success')) ?>, flashBad: <?= json_encode(session()->getFlashdata('error')) ?> };
            const $ = (id) => document.getElementById(id);
            function toast(msg, kind) {
                const el = document.createElement('div');
                el.className = 'toast-msg ' + (kind === 'bad' ? 'toast-bad' : 'toast-ok');
                el.textContent = msg;
                $('toastBox').appendChild(el);
                setTimeout(() => el.remove(), kind === 'bad' ? 9000 : 5000);
            }
            function syncType() {
                const flag = $('vType').value === 'FLAG';
                $('vDefaultFlag').style.display = flag ? '' : 'none';
                $('vDefaultNum').style.display = flag ? 'none' : '';
            }
            function reset() {
                $('formTitle').textContent = 'Add a variable';
                $('vCode').value = ''; $('vCode').readOnly = false;
                $('vName').value = ''; $('vDesc').value = '';
                $('vType').value = 'FLAG'; $('vDefaultFlag').value = '1'; $('vDefaultNum').value = '0';
                $('vActive').checked = true;
                syncType();
            }
            document.addEventListener('click', (e) => {
                const b = e.target.closest('[data-edit]');
                if (!b) return;
                const v = VARS.find((x) => x.var_code === b.dataset.edit);
                if (!v) return;
                $('formTitle').textContent = 'Edit ' + v.var_code;
                $('vCode').value = v.var_code; $('vCode').readOnly = true;
                $('vName').value = v.var_name || ''; $('vDesc').value = v.description || '';
                $('vType').value = v.data_type;
                $('vDefaultFlag').value = parseFloat(v.default_value) !== 0 ? '1' : '0';
                $('vDefaultNum').value = parseFloat(v.default_value);
                $('vActive').checked = Number(v.is_active) === 1;
                syncType();
                window.scrollTo({ top: 0, behavior: 'smooth' });
            });
            $('vType').addEventListener('change', syncType);
            $('vCode').addEventListener('input', (e) => { e.target.value = e.target.value.toUpperCase().replace(/[^A-Z0-9_]/g, ''); });
            $('btnNew').addEventListener('click', reset);
            $('btnSave').addEventListener('click', () => {
                const code = $('vCode').value.trim();
                if (!/^[A-Z][A-Z0-9_]{1,39}$/.test(code)) { toast('The code must start with a letter and use letters, numbers and _.', 'bad'); return; }
                if (!$('vName').value.trim()) { toast('Enter the name.', 'bad'); return; }
                const fd = new FormData();
                fd.append('var_code', code);
                fd.append('var_name', $('vName').value.trim());
                fd.append('description', $('vDesc').value.trim());
                fd.append('data_type', $('vType').value);
                fd.append('default_value', $('vType').value === 'FLAG' ? $('vDefaultFlag').value : $('vDefaultNum').value);
                fd.append('is_active', $('vActive').checked ? '1' : '0');
                const csrf = document.querySelector('input[name="' + CFG.csrfName + '"]');
                if (csrf) fd.append(CFG.csrfName, csrf.value);
                $('btnSave').disabled = true;
                fetch(CFG.saveUrl, { method: 'POST', body: fd, headers: { 'X-Requested-With': 'XMLHttpRequest' } })
                    .then((r) => r.json())
                    .catch((e) => ({ status: false, message: 'The server did not answer (' + e.message + ').' }))
                    .then((r) => {
                        if (r.csrf_token && csrf) csrf.value = r.csrf_token;
                        if (r.status) { window.location.reload(); return; }
                        $('btnSave').disabled = false;
                        toast(r.message || 'Not saved.', 'bad');
                    });
            });
            reset();
            if (CFG.flashOk) toast(CFG.flashOk, 'ok');
            if (CFG.flashBad) toast(CFG.flashBad, 'bad');
        })();
    </script>
</body>

</html>
