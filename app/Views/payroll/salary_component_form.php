<?php
/**
 * Add / edit one salary component (full page; replaces the popup on the components list).
 * Data: $component (empty = new; every column of salary_component_master + method, slab_count, employee_rows),
 *       $slabs (slab rows), $names (hrms_formula_names: VARIABLE / COMPONENT / TOTAL),
 *       $deps (who uses whom: code, uses, via).
 * Saving: POST payroll/salary_components/save -> hrms_component_save, then hrms_component_set_flags.
 * "Check" sends the same form with dry_run = 1: every employee is calculated, nothing is saved.
 */
$c        = $component ?? [];
$isNew    = empty($c['component_id']);
$code     = strtoupper((string) ($c['component_code'] ?? ''));
$scope    = strtoupper((string) ($c['calculation_scope'] ?? 'COMPONENT'));
$method   = strtoupper((string) ($c['method'] ?? 'PERCENT'));
$autoTotal = false;
foreach ($names as $n) {
    if (!$isNew && $n['kind'] === 'TOTAL' && (int) ($n['component_id'] ?? 0) === (int) $c['component_id']) {
        $autoTotal = (int) ($n['auto_total'] ?? 0) === 1;
    }
}
$uses = [];
$usedBy = [];
foreach (($deps ?? []) as $d) {
    if ($code !== '' && strtoupper((string) $d['code']) === $code) {
        $uses[strtoupper((string) $d['uses'])] = true;
    }
    if ($code !== '' && strtoupper((string) $d['uses']) === $code) {
        $usedBy[strtoupper((string) $d['code'])] = true;
    }
}
$init = [
    'component_id'     => $isNew ? null : (int) $c['component_id'],
    'code'             => $code,
    'name'             => (string) ($c['component_name'] ?? ''),
    'type'             => strtoupper((string) ($c['component_type'] ?? 'EARNING')),
    'scope'            => $scope,
    'method'           => $scope === 'AGGREGATE' ? 'FORMULA' : ($method === 'TOTAL' ? 'FORMULA' : $method),
    'value'            => isset($c['percentage_value']) ? (float) $c['percentage_value'] : '',
    'base'             => strtoupper((string) ($c['percentage_base'] ?? 'CTC1')),
    'formula'          => (string) ($c['formula_expression'] ?? ''),
    'min'              => $c['minimum_amount'] ?? '',
    'max'              => $c['maximum_amount'] ?? '',
    'eligibility'      => strtoupper((string) ($c['eligibility_parameter'] ?? '')),
    'rounding'         => (string) ($c['rounding_precision'] ?? '2'),
    'taxable'          => (int) ($c['is_taxable'] ?? 1),
    'statutory'        => (int) ($c['is_statutory'] ?? 0),
    'active'           => (int) ($c['is_active'] ?? 1),
    'order'            => $isNew ? '' : (string) ($c['calculation_order'] ?? ''),
    'include_in_total' => (int) ($c['include_in_total'] ?? 1),
    'balancing'        => (int) ($c['is_balancing'] ?? 0),
    'employee_rows'    => (int) ($c['employee_rows'] ?? 0),
    'auto_total'       => $autoTotal,
];
if ($init['eligibility'] === 'EMPLOYEE_ESI_ELIGIBLE') {
    $init['eligibility'] = 'ESI_APPLICABLE';
}
$slabRows = array_map(fn($s) => [
    'slab_based_on'   => strtoupper((string) $s['slab_based_on']),
    'slab_min_value'  => $s['slab_min_value'],
    'slab_max_value'  => $s['slab_max_value'],
    'result_type'     => strtoupper((string) $s['result_type']),
    'result_value'    => $s['result_value'],
    'percentage_base' => strtoupper((string) $s['percentage_base']),
    'priority'        => (int) $s['priority'],
    'effective_from'  => $s['effective_from'],
    'effective_to'    => $s['effective_to'],
    'is_active'       => (int) $s['is_active'],
], $slabs ?? []);
$jsonFlags = JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP;
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>BloomHR | <?= $isNew ? 'New salary component' : 'Edit ' . esc($code) ?></title>
    <link rel="icon" type="image/jpeg" href="<?= base_url('public/dist/img/bloom.jpg') ?>">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">
    <?= view('payroll/_salary_page_styles') ?>
    <style>
        .opt-grid { display: grid; gap: 10px; }
        .opt-grid.c2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .opt-grid.c3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
        .opt-grid.c6 { grid-template-columns: repeat(auto-fill, minmax(130px, 1fr)); }
        .opt { border: 1px solid var(--border-color); border-radius: 12px; padding: 10px 12px; cursor: pointer; background: #fff; transition: all .15s; }
        .opt:hover { border-color: #c7d2fe; background: #fafaff; }
        .opt.on { border-color: var(--bloom-purple); box-shadow: 0 0 0 3px rgba(74, 0, 224, .12); background: #faf8ff; }
        .opt.off { opacity: .45; cursor: not-allowed; }
        .opt .t { font-weight: 800; color: var(--bloom-dark); font-size: 12.5px; }
        .opt .d { color: var(--text-muted); font-size: 11.5px; margin-top: 2px; }
        .fx-area { width: 100%; min-height: 70px; font-family: ui-monospace, Consolas, monospace; font-size: 13px; text-transform: uppercase;
                   border: 1px solid var(--border-color); border-radius: 10px; padding: 10px; outline: none; resize: vertical; }
        .fx-area:focus { border-color: var(--bloom-purple); box-shadow: 0 0 0 3px rgba(74, 0, 224, .1); }
        .fx-area[readonly] { background: #f1f5f9; }
        .ins-row { display: flex; flex-wrap: wrap; gap: 4px; align-items: center; margin-top: 6px; }
        .ins-row .lbl { font-size: 10.5px; font-weight: 800; text-transform: uppercase; color: var(--text-muted); width: 86px; }
        .ins { border: 1px solid var(--border-color); background: #f8fafc; border-radius: 7px; padding: 2px 8px; font-family: ui-monospace, Consolas, monospace;
               font-size: 11.5px; cursor: pointer; color: var(--text-dark); }
        .ins:hover { border-color: var(--bloom-purple); color: var(--bloom-purple); background: #fff; }
        .ins.v { background: #ecfeff; } .ins.t { background: #f0fdf4; } .ins.f { background: #fefce8; }
        .fx-msg { font-size: 12px; margin-top: 6px; min-height: 18px; }
        .ok-txt { color: #15803d; font-weight: 700; } .bad-txt { color: #b91c1c; font-weight: 700; }
        table.slabs { width: 100%; font-size: 12px; border-collapse: separate; border-spacing: 0 4px; }
        table.slabs th { font-size: 10.5px; text-transform: uppercase; color: var(--text-muted); font-weight: 800; padding: 0 4px; }
        table.slabs td { padding: 0 3px; }
        table.slabs .pc-control { height: 32px; width: 100%; padding: 4px 6px; font-size: 12px; }
        .side { position: sticky; top: 12px; }
        .summary-rule { font-family: ui-monospace, Consolas, monospace; background: #f8fafc; border-radius: 10px; padding: 10px; font-size: 12px; color: var(--bloom-dark); word-break: break-word; }
        .find { border-radius: 8px; padding: 6px 10px; font-size: 12px; margin-top: 6px; }
        .find.ERROR { background: #fee2e2; color: #7f1d1d; } .find.WARNING { background: #fef3c7; color: #78350f; } .find.INFO { background: #e0f2fe; color: #0c4a6e; }
        table.impact { width: 100%; font-size: 11.5px; margin-top: 6px; }
        table.impact td, table.impact th { padding: 3px 4px; border-bottom: 1px solid #f1f5f9; }
        table.impact th { color: var(--text-muted); font-weight: 800; text-transform: uppercase; font-size: 10px; }
        .num { text-align: right; font-variant-numeric: tabular-nums; }
        .tick { display: flex; gap: 8px; align-items: flex-start; font-size: 12.5px; margin: 6px 0; cursor: pointer; }
        .tick input { margin-top: 3px; }
        .tick .d { color: var(--text-muted); font-size: 11.5px; }
        @media (max-width: 991px) { .opt-grid.c3, .opt-grid.c2 { grid-template-columns: 1fr; } .side { position: static; } }
    </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed">
    <div class="content-wrapper">
        <div class="payroll-page">

            <div class="d-flex flex-wrap justify-content-between align-items-center mb-3" style="gap: 10px;">
                <div>
                    <div class="small muted"><a href="<?= base_url('payroll/salary_components') ?>">Salary components</a> / <?= $isNew ? 'New' : esc($code) ?></div>
                    <h1 class="pc-heading"><?= $isNew ? 'New salary component' : 'Edit ' . esc($c['component_name'] ?? $code) ?></h1>
                </div>
                <div class="d-flex" style="gap: 8px;">
                    <a href="<?= base_url('payroll/variables') ?>" class="pc-btn"><i class="fas fa-sliders-h"></i> Payroll variables</a>
                    <a href="<?= base_url('payroll/salary_components') ?>" class="pc-btn"><i class="fas fa-arrow-left"></i> Back to components</a>
                </div>
            </div>

            <div class="row">
                <div class="col-xl-8">

                    <!-- 1. BASICS -->
                    <div class="pc-card"><div class="pc-body">
                        <p class="pc-section-title mb-3"><span class="step-no">1</span>Basics</p>
                        <span class="pc-label">What is it</span>
                        <div class="opt-grid c2 mb-3" id="scopeOpts">
                            <div class="opt" data-scope="COMPONENT"><div class="t"><i class="fas fa-coins mr-1"></i> Pay component</div>
                                <div class="d">An amount paid, deducted or paid by the company: BASIC, PT, a bonus.</div></div>
                            <div class="opt" data-scope="AGGREGATE"><div class="t"><i class="fas fa-equals mr-1"></i> Aggregate</div>
                                <div class="d">Adds up other components: GROSS, NET_PAY, a PF wage.</div></div>
                        </div>
                        <div class="row">
                            <div class="col-md-6 mb-2">
                                <label class="pc-label" for="fName">Name</label>
                                <input class="pc-control w-100" id="fName" maxlength="100" placeholder="Special allowance">
                            </div>
                            <div class="col-md-6 mb-2">
                                <label class="pc-label" for="fCode">Code (used in formulas)</label>
                                <input class="pc-control w-100" id="fCode" maxlength="30" placeholder="SPECIAL_ALLOWANCE" style="font-family: ui-monospace, Consolas, monospace; text-transform: uppercase;">
                                <div class="small muted mt-1" id="codeHelp"></div>
                            </div>
                        </div>
                        <div id="typeBox">
                            <span class="pc-label mt-2">Type</span>
                            <div class="opt-grid c3" id="typeOpts">
                                <div class="opt" data-type="EARNING"><div class="t">Earning</div><div class="d">Paid to the employee; part of gross</div></div>
                                <div class="opt" data-type="DEDUCTION"><div class="t">Deduction</div><div class="d">Taken from gross pay</div></div>
                                <div class="opt" data-type="EMPLOYER_CONTRIBUTION"><div class="t">Employer contribution</div><div class="d">Paid by the company; part of CTC</div></div>
                            </div>
                        </div>
                    </div></div>

                    <!-- 2. HOW IT IS CALCULATED -->
                    <div class="pc-card"><div class="pc-body">
                        <p class="pc-section-title mb-1"><span class="step-no">2</span>How is it calculated</p>
                        <p class="pc-section-help mb-3" id="methodHelp">Choose one way. Only that rule is saved.</p>
                        <div class="opt-grid c6 mb-3" id="methodOpts">
                            <div class="opt" data-method="FIXED"><div class="t">Fixed</div><div class="d">Same amount (₹)</div></div>
                            <div class="opt" data-method="PERCENT"><div class="t">Percent</div><div class="d">% of a value</div></div>
                            <div class="opt" data-method="FORMULA"><div class="t">Formula</div><div class="d">Your own rule</div></div>
                            <div class="opt" data-method="SLAB"><div class="t">Slabs</div><div class="d">By range (PT, ESI)</div></div>
                            <div class="opt" data-method="MONTHLY"><div class="t">Monthly entry</div><div class="d">Typed each month</div></div>
                            <div class="opt" data-method="BALANCING"><div class="t">Rest of CTC</div><div class="d">Balancing earning</div></div>
                        </div>

                        <div data-panel="FIXED">
                            <div class="row"><div class="col-md-4">
                                <label class="pc-label" for="fFixed">Amount per month (₹)</label>
                                <input type="number" min="0" step="0.01" class="pc-control w-100" id="fFixed" placeholder="1500">
                            </div></div>
                        </div>
                        <div data-panel="PERCENT">
                            <div class="row">
                                <div class="col-md-4"><label class="pc-label" for="fPct">Percent (%)</label>
                                    <input type="number" min="0" step="0.01" class="pc-control w-100" id="fPct" placeholder="12"></div>
                                <div class="col-md-8"><label class="pc-label" for="fBase">Of</label>
                                    <select class="pc-control w-100" id="fBase"></select></div>
                            </div>
                        </div>
                        <div data-panel="FORMULA">
                            <label class="pc-label" for="fFormula">Formula</label>
                            <textarea class="fx-area" id="fFormula" maxlength="2000" spellcheck="false" placeholder="ROUND(CTC1 * 10 / 100, 0)"></textarea>
                            <div class="d-flex align-items-center mt-1" style="gap: 8px;">
                                <button type="button" class="pc-btn pc-btn-sm" id="btnCheckFx"><i class="fas fa-check-circle"></i> Check formula</button>
                                <div class="fx-msg" id="fxMsg"></div>
                            </div>
                            <div id="fxAutoNote" class="notice notice-info mt-2" style="display: none;"><i class="fas fa-magic"></i>
                                <div>This aggregate is built automatically from the <b>Counts in</b> tick of each component, so its formula is not edited here.</div></div>
                            <div id="insertBox">
                                <div class="ins-row"><span class="lbl">Operators</span>
                                    <?php foreach (['+', '-', '*', '/', '(', ')', ',', '<', '<=', '>', '>=', '=', '!='] as $o): ?>
                                        <button type="button" class="ins" data-ins=" <?= esc($o) ?> "><?= esc($o) ?></button>
                                    <?php endforeach; ?>
                                </div>
                                <div class="ins-row"><span class="lbl">Functions</span>
                                    <?php foreach (['ROUND(x, 0)' => 'ROUND(', 'LEAST(a, b)' => 'LEAST(', 'GREATEST(a, b)' => 'GREATEST(', 'IF(test, yes, no)' => 'IF(', 'CEIL(x)' => 'CEIL(', 'FLOOR(x)' => 'FLOOR(', 'ABS(x)' => 'ABS('] as $label => $ins): ?>
                                        <button type="button" class="ins f" data-ins="<?= esc($ins) ?>" title="<?= esc($label) ?>"><?= esc($label) ?></button>
                                    <?php endforeach; ?>
                                </div>
                                <div class="ins-row" id="insVars"><span class="lbl">Variables</span></div>
                                <div class="ins-row" id="insComps"><span class="lbl">Components</span></div>
                                <div class="ins-row" id="insTotals"><span class="lbl">Aggregates</span></div>
                            </div>
                        </div>
                        <div data-panel="SLAB">
                            <div class="d-flex justify-content-between align-items-center">
                                <span class="small muted">The first slab (lowest priority number) whose range contains the "based on" value gives the amount. Leave "To" empty for no upper limit.</span>
                                <button type="button" class="pc-btn pc-btn-sm" id="btnAddSlab"><i class="fas fa-plus"></i> Add slab</button>
                            </div>
                            <div class="table-responsive"><table class="slabs mt-2">
                                <thead><tr><th style="width:16%">Based on</th><th style="width:10%">From</th><th style="width:10%">To</th><th style="width:11%">Result</th>
                                    <th style="width:9%">Value</th><th style="width:14%">% of</th><th style="width:12%">Valid from</th><th style="width:12%">Valid to</th><th style="width:4%"></th><th style="width:2%"></th></tr></thead>
                                <tbody id="slabBody"></tbody>
                            </table></div>
                        </div>
                        <div data-panel="MONTHLY">
                            <div class="notice notice-info"><i class="fas fa-keyboard"></i>
                                <div>The amount is typed every month on the payroll cycle page (manual amounts), for example TDS, an advance or a bonus. With nothing typed it is 0.</div></div>
                        </div>
                        <div data-panel="BALANCING">
                            <div class="notice notice-info"><i class="fas fa-balance-scale"></i>
                                <div>This earning is what is left of the CTC: <b>CTC1 − the other earnings that count in gross</b> (monthly entries excluded) <b>− the employer contributions that count in their aggregate</b>.
                                    So the salary always adds up to the CTC, also when a new earning is added. Only one component can be the balancing one.</div></div>
                        </div>
                    </div></div>

                    <!-- 3. LIMITS AND CONDITIONS -->
                    <div class="pc-card" id="limitsCard"><div class="pc-body">
                        <p class="pc-section-title mb-3"><span class="step-no">3</span>Limits and conditions</p>
                        <div class="row">
                            <div class="col-md-3 mb-2"><label class="pc-label" for="fMin">Minimum (₹)</label>
                                <input type="number" min="0" step="0.01" class="pc-control w-100" id="fMin" placeholder="None"></div>
                            <div class="col-md-3 mb-2"><label class="pc-label" for="fMax">Maximum (₹)</label>
                                <input type="number" min="0" step="0.01" class="pc-control w-100" id="fMax" placeholder="None"></div>
                            <div class="col-md-3 mb-2"><label class="pc-label" for="fRound">Round to</label>
                                <select class="pc-control w-100" id="fRound"><option value="2">2 decimals</option><option value="1">1 decimal</option><option value="0">Whole rupee</option></select></div>
                            <div class="col-md-3 mb-2"><label class="pc-label" for="fElig">Applies only when</label>
                                <select class="pc-control w-100" id="fElig"></select></div>
                        </div>
                        <div class="small muted">"Applies only when" lists the Yes/No payroll variables. When it is No for an employee, the component is 0 for them.
                            Add one (PF applies, metro city ...) on the <a href="<?= base_url('payroll/variables') ?>">Payroll variables</a> page.</div>
                    </div></div>

                    <!-- 4. TOTALS AND TAX -->
                    <div class="pc-card"><div class="pc-body">
                        <p class="pc-section-title mb-2"><span class="step-no">4</span>Aggregates, tax and status</p>
                        <label class="tick" id="tickTotalBox"><input type="checkbox" id="fInclude">
                            <span><span id="tickTotalLbl">Counts in gross</span><div class="d">Untick for something that is paid but not part of the aggregate (for example a reimbursement).</div></span></label>
                        <label class="tick" id="tickTaxBox"><input type="checkbox" id="fTaxable">
                            <span>Taxable<div class="d">Counts as income for income tax.</div></span></label>
                        <label class="tick" id="tickStatBox"><input type="checkbox" id="fStatutory">
                            <span>Statutory<div class="d">Required by law: PF, ESI, PT, EPF admin. A label for reports.</div></span></label>
                        <label class="tick"><input type="checkbox" id="fActive">
                            <span>Active<div class="d">An inactive component is not calculated and is 0 for everyone.</div></span></label>
                        <details class="mt-2">
                            <summary class="small font-weight-bold" style="cursor: pointer;">Advanced: calculation order</summary>
                            <div class="row mt-2"><div class="col-md-4">
                                <input type="number" min="1" max="9999" class="pc-control w-100" id="fOrder" placeholder="Automatic">
                            </div><div class="col-md-8 small muted pt-2">Leave empty: a new component is placed after what it uses. Components that use each other are settled by the engine.</div></div>
                        </details>
                    </div></div>
                </div>

                <!-- SIDE: summary, check, save -->
                <div class="col-xl-4">
                    <div class="side">
                        <div class="pc-card"><div class="pc-body">
                            <p class="pc-section-title mb-2"><i class="fas fa-eye mr-1" style="color: var(--bloom-purple);"></i> Summary</p>
                            <div class="summary-rule" id="sumRule"></div>
                            <?php if (!$isNew): ?>
                                <div class="small mt-2"><b>Uses:</b> <?= $uses ? esc(implode(', ', array_keys($uses))) : '—' ?></div>
                                <div class="small"><b>Used by:</b> <?= $usedBy ? esc(implode(', ', array_keys($usedBy))) : '—' ?></div>
                                <div class="small"><b>On salaries:</b> <?= (int) $init['employee_rows'] ?> salary periods</div>
                            <?php endif; ?>
                        </div></div>

                        <div class="pc-card"><div class="pc-body">
                            <p class="pc-section-title mb-1"><i class="fas fa-users mr-1" style="color: var(--bloom-purple);"></i> Check before saving</p>
                            <p class="pc-section-help mb-2">Calculates every employee with this rule and shows what would change. Nothing is saved.</p>
                            <button type="button" class="pc-btn w-100" id="btnCheck"><i class="fas fa-vial"></i> Check all employees</button>
                            <div id="checkOut" class="mt-2"></div>
                        </div></div>

                        <div class="pc-card"><div class="pc-body">
                            <div class="d-flex" style="gap: 8px;">
                                <button type="button" class="pc-btn pc-btn-primary flex-fill" id="btnSave"><i class="fas fa-save"></i> <?= $isNew ? 'Create component' : 'Save changes' ?></button>
                                <a href="<?= base_url('payroll/salary_components') ?>" class="pc-btn">Cancel</a>
                            </div>
                            <div class="small muted mt-2">Saving recalculates every salary. Payroll cycles that are already calculated go back so they use the new rule; finalized payrolls never change.</div>
                        </div></div>
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
                saveUrl: '<?= site_url('payroll/salary_components/save') ?>',
                checkFormulaUrl: '<?= site_url('payroll/validate_formula') ?>',
                csrfName: '<?= csrf_token() ?>',
                isNew: <?= $isNew ? 'true' : 'false' ?>
            };
            const INIT = <?= json_encode($init, $jsonFlags) ?>;
            const NAMES = <?= json_encode(array_values($names), $jsonFlags) ?>;
            const SLABS = <?= json_encode(array_values($slabRows), $jsonFlags) ?>;
            const FUNCS = ['ROUND', 'LEAST', 'GREATEST', 'IF', 'CEIL', 'FLOOR', 'ABS', 'AND', 'OR', 'NOT'];
            const TOTAL_OF = { EARNING: 'gross', DEDUCTION: 'total deductions', EMPLOYER_CONTRIBUTION: 'total employer contribution' };

            const $ = (id) => document.getElementById(id);
            const esc = (v) => String(v === null || v === undefined ? '' : v).replace(/&/g, '&amp;').replace(/</g, '&lt;')
                .replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
            const inr = new Intl.NumberFormat('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
            const money = (v) => '₹ ' + inr.format(parseFloat(v || 0));
            function toast(msg, kind) {
                const el = document.createElement('div');
                el.className = 'toast-msg ' + (kind === 'bad' ? 'toast-bad' : 'toast-ok');
                el.textContent = msg;
                $('toastBox').appendChild(el);
                setTimeout(() => el.remove(), kind === 'bad' ? 9000 : 5000);
            }

            const state = Object.assign({}, INIT);
            const known = new Set(NAMES.filter((n) => Number(n.is_active) === 1).map((n) => String(n.code).toUpperCase()));
            const flagVars = NAMES.filter((n) => n.kind === 'VARIABLE' && n.data_type === 'FLAG');

            // ---------- fill the selects and the insert buttons ----------
            function fillBase() {
                const opts = NAMES.filter((n) => n.data_type !== 'FLAG' && Number(n.is_active) === 1 && n.code !== state.code)
                    .map((n) => '<option value="' + esc(n.code) + '">' + esc(n.code) + ' — ' + esc(n.label) + '</option>');
                $('fBase').innerHTML = opts.join('');
            }
            function fillElig() {
                $('fElig').innerHTML = '<option value="">All employees</option>' +
                    flagVars.map((n) => '<option value="' + esc(n.code) + '">' + esc(n.label) + ' (' + esc(n.code) + ') = Yes</option>').join('');
            }
            function fillInsert() {
                const btn = (n, cls) => '<button type="button" class="ins ' + cls + '" data-ins="' + esc(n.code) + '" title="' + esc(n.label) + '">' + esc(n.code) + '</button>';
                NAMES.filter((n) => n.kind === 'VARIABLE').forEach((n) => $('insVars').insertAdjacentHTML('beforeend', btn(n, 'v')));
                NAMES.filter((n) => n.kind === 'COMPONENT' && Number(n.is_active) === 1 && n.code !== state.code)
                    .forEach((n) => $('insComps').insertAdjacentHTML('beforeend', btn(n, '')));
                NAMES.filter((n) => n.kind === 'TOTAL' && Number(n.is_active) === 1 && n.code !== state.code)
                    .forEach((n) => $('insTotals').insertAdjacentHTML('beforeend', btn(n, 't')));
            }
            function slabNameOptions(sel) {
                return NAMES.filter((n) => n.data_type !== 'FLAG' && Number(n.is_active) === 1 && n.code !== state.code)
                    .map((n) => '<option value="' + esc(n.code) + '"' + (n.code === sel ? ' selected' : '') + '>' + esc(n.code) + '</option>').join('');
            }

            // ---------- slabs ----------
            function slabRow(s) {
                s = s || { slab_based_on: 'GROSS', slab_min_value: '', slab_max_value: '', result_type: 'FIXED', result_value: '', percentage_base: 'NONE',
                           effective_from: new Date().toISOString().slice(0, 10), effective_to: '', is_active: 1 };
                return '<tr>' +
                    '<td><select class="pc-control s-on">' + slabNameOptions(s.slab_based_on) + '</select></td>' +
                    '<td><input type="number" step="0.01" class="pc-control s-min" value="' + esc(s.slab_min_value) + '"></td>' +
                    '<td><input type="number" step="0.01" class="pc-control s-max" value="' + esc(s.slab_max_value === null ? '' : s.slab_max_value) + '" placeholder="No limit"></td>' +
                    '<td><select class="pc-control s-type"><option value="FIXED"' + (s.result_type === 'FIXED' ? ' selected' : '') + '>Fixed ₹</option>' +
                    '<option value="PERCENTAGE"' + (s.result_type === 'PERCENTAGE' ? ' selected' : '') + '>Percent</option></select></td>' +
                    '<td><input type="number" step="0.01" min="0" class="pc-control s-val" value="' + esc(s.result_value) + '"></td>' +
                    '<td><select class="pc-control s-pb"><option value="NONE">—</option>' + slabNameOptions(s.percentage_base) + '</select></td>' +
                    '<td><input type="date" class="pc-control s-from" value="' + esc(s.effective_from || '') + '"></td>' +
                    '<td><input type="date" class="pc-control s-to" value="' + esc(s.effective_to || '') + '"></td>' +
                    '<td class="text-center"><input type="checkbox" class="s-act"' + (Number(s.is_active) === 1 ? ' checked' : '') + ' title="Active"></td>' +
                    '<td><button type="button" class="pc-btn pc-btn-sm s-del" title="Remove"><i class="fas fa-times"></i></button></td></tr>';
            }
            function syncSlabRow(tr) {
                const pct = tr.querySelector('.s-type').value === 'PERCENTAGE';
                tr.querySelector('.s-pb').disabled = !pct;
                if (!pct) tr.querySelector('.s-pb').value = 'NONE';
            }
            function collectSlabs() {
                return Array.from($('slabBody').querySelectorAll('tr')).map((tr, i) => ({
                    slab_based_on: tr.querySelector('.s-on').value,
                    slab_min_value: tr.querySelector('.s-min').value === '' ? 0 : tr.querySelector('.s-min').value,
                    slab_max_value: tr.querySelector('.s-max').value === '' ? null : tr.querySelector('.s-max').value,
                    result_type: tr.querySelector('.s-type').value,
                    result_value: tr.querySelector('.s-val').value === '' ? 0 : tr.querySelector('.s-val').value,
                    percentage_base: tr.querySelector('.s-type').value === 'PERCENTAGE' ? tr.querySelector('.s-pb').value : 'NONE',
                    priority: i + 1,
                    effective_from: tr.querySelector('.s-from').value || null,
                    effective_to: tr.querySelector('.s-to').value || null,
                    is_active: tr.querySelector('.s-act').checked ? 1 : 0
                }));
            }

            // ---------- formula: local check (names, brackets) ----------
            function localFormulaCheck() {
                const f = $('fFormula').value.toUpperCase();
                if (!f.trim()) return '';
                if (/[^A-Z0-9_ .,()+*\/<>=!\-\n\r\t]/.test(f)) return 'Only names, numbers, + - * / ( ) , < > = ! are allowed.';
                let depth = 0;
                for (const ch of f) { if (ch === '(') depth++; if (ch === ')') depth--; if (depth < 0) break; }
                if (depth !== 0) return 'The brackets do not match.';
                const unknown = (f.match(/[A-Z_][A-Z0-9_]*/g) || []).filter((t) => !FUNCS.includes(t) && !known.has(t));
                if (state.code && (f.match(/[A-Z_][A-Z0-9_]*/g) || []).includes(state.code)) return 'A component cannot use itself.';
                if (unknown.length) return 'Unknown name: ' + Array.from(new Set(unknown)).join(', ') + '.';
                return '';
            }
            function paintFxMsg() {
                const m = localFormulaCheck();
                $('fxMsg').innerHTML = m ? '<span class="bad-txt"><i class="fas fa-exclamation-circle"></i> ' + esc(m) + '</span>' : '';
            }
            function insertAtCursor(text) {
                const ta = $('fFormula');
                if (ta.readOnly) return;
                const a = ta.selectionStart, b = ta.selectionEnd;
                ta.value = ta.value.slice(0, a) + text + ta.value.slice(b);
                ta.focus();
                ta.selectionStart = ta.selectionEnd = a + text.length;
                paintFxMsg();
                paint();
            }

            // ---------- state <-> form ----------
            function readForm() {
                state.name = $('fName').value.trim();
                state.code = $('fCode').value.trim().toUpperCase();
                state.min = $('fMin').value;
                state.max = $('fMax').value;
                state.rounding = $('fRound').value;
                state.eligibility = $('fElig').value;
                state.taxable = $('fTaxable').checked ? 1 : 0;
                state.statutory = $('fStatutory').checked ? 1 : 0;
                state.active = $('fActive').checked ? 1 : 0;
                state.include_in_total = $('fInclude').checked ? 1 : 0;
                state.order = $('fOrder').value;
            }
            function methodValue() {
                if (state.method === 'FIXED') return $('fFixed').value;
                if (state.method === 'PERCENT') return $('fPct').value;
                return '';
            }

            function paint() {
                const isTotal = state.scope === 'AGGREGATE';
                document.querySelectorAll('#scopeOpts .opt').forEach((o) => {
                    o.classList.toggle('on', o.dataset.scope === state.scope);
                    o.classList.toggle('off', !CFG.isNew && o.dataset.scope !== state.scope);
                });
                document.querySelectorAll('#typeOpts .opt').forEach((o) => o.classList.toggle('on', o.dataset.type === state.type));
                $('typeBox').style.display = isTotal ? 'none' : '';
                $('methodOpts').style.display = isTotal ? 'none' : '';
                $('methodHelp').textContent = isTotal ? 'An aggregate is a formula of other components and aggregates.' : 'Choose one way. Only that rule is saved.';
                if (isTotal) state.method = 'FORMULA';
                if (state.method === 'BALANCING' && state.type !== 'EARNING') state.method = 'FORMULA';
                document.querySelectorAll('#methodOpts .opt').forEach((o) => {
                    o.classList.toggle('on', o.dataset.method === state.method);
                    o.classList.toggle('off', o.dataset.method === 'BALANCING' && state.type !== 'EARNING');
                });
                document.querySelectorAll('[data-panel]').forEach((p) => { p.style.display = p.dataset.panel === state.method ? '' : 'none'; });
                const auto = isTotal && INIT.auto_total;
                $('fFormula').readOnly = auto;
                $('fxAutoNote').style.display = auto ? '' : 'none';
                $('insertBox').style.display = auto ? 'none' : '';
                $('limitsCard').style.display = isTotal ? 'none' : '';
                $('tickTotalBox').style.display = isTotal || state.method === 'BALANCING' ? 'none' : '';
                $('tickTaxBox').style.display = isTotal ? 'none' : '';
                $('tickStatBox').style.display = isTotal ? 'none' : '';
                $('tickTotalLbl').textContent = 'Counts in ' + (TOTAL_OF[state.type] || 'its aggregate');
                $('codeHelp').textContent = !CFG.isNew && state.code !== INIT.code ? 'Changing the code is refused while formulas, slabs or bases use it.' : '';
                $('sumRule').innerHTML = esc(summary());
            }

            function summary() {
                readForm();
                const who = (state.code || 'NEW') + ' = ';
                let r;
                switch (state.method) {
                    case 'FIXED': r = money(methodValue()) + ' every month'; break;
                    case 'PERCENT': r = (methodValue() || '0') + '% of ' + $('fBase').value; break;
                    case 'FORMULA': r = $('fFormula').value.toUpperCase() || '(formula)'; break;
                    case 'SLAB': r = 'slab table (' + $('slabBody').querySelectorAll('tr').length + ' slabs)'; break;
                    case 'MONTHLY': r = 'amount typed every month'; break;
                    case 'BALANCING': r = 'CTC1 − other earnings − employer contributions'; break;
                    default: r = '?';
                }
                const extra = [];
                if (state.scope !== 'AGGREGATE') {
                    if (state.min !== '') extra.push('at least ' + money(state.min));
                    if (state.max !== '') extra.push('at most ' + money(state.max));
                    if (state.eligibility) extra.push('only when ' + state.eligibility + ' = Yes');
                    if (state.method !== 'BALANCING') extra.push(state.include_in_total ? 'counts in ' + (TOTAL_OF[state.type] || 'aggregate') : 'not in any aggregate');
                }
                if (!state.active) extra.push('INACTIVE');
                return who + r + (extra.length ? '\n' + extra.join(' · ') : '');
            }

            // ---------- request ----------
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
            function payload(dry) {
                readForm();
                return {
                    component_id: state.component_id || '', code: state.code, name: state.name, type: state.type, scope: state.scope,
                    method: state.method, value: methodValue(), base: state.method === 'PERCENT' ? $('fBase').value : '',
                    formula: state.method === 'FORMULA' ? $('fFormula').value.toUpperCase() : '',
                    min: state.min, max: state.max, eligibility: state.eligibility, rounding: state.rounding,
                    taxable: state.taxable, statutory: state.statutory, active: state.active, order: state.order,
                    include_in_total: state.method === 'BALANCING' ? 1 : state.include_in_total,
                    balancing: state.method === 'BALANCING' ? 1 : 0,
                    slabs: state.method === 'SLAB' ? JSON.stringify(collectSlabs()) : '',
                    dry_run: dry ? 1 : 0
                };
            }
            function problems() {
                readForm();
                if (!state.name) return 'Enter the name.';
                if (!/^[A-Z][A-Z0-9_]{1,29}$/.test(state.code)) return 'The code must start with a letter and use letters, numbers and _ (2 to 30).';
                if (state.method === 'FIXED' && $('fFixed').value === '') return 'Enter the fixed amount.';
                if (state.method === 'PERCENT' && $('fPct').value === '') return 'Enter the percent.';
                if (state.method === 'FORMULA') { if (!$('fFormula').value.trim()) return 'Enter the formula.'; const m = localFormulaCheck(); if (m) return m; }
                if (state.method === 'SLAB' && !$('slabBody').querySelectorAll('tr').length) return 'Add at least one slab.';
                if (state.min !== '' && state.max !== '' && parseFloat(state.min) > parseFloat(state.max)) return 'The minimum is above the maximum.';
                return '';
            }
            function showResult(r) {
                let h = '<div class="' + (r.status ? 'ok-txt' : 'bad-txt') + '" style="font-size:12px;">' + esc(r.message) + '</div>';
                (r.findings || []).forEach((f) => {
                    h += '<div class="find ' + esc(f.level) + '"><b>' + esc(f.level) + '</b> ' + esc(f.message) +
                         (f.suggest_order ? ' (suggested order ' + esc(f.suggest_order) + ')' : '') + '</div>';
                });
                const im = r.impact;
                if (im && im.rows && im.rows.length) {
                    h += '<div class="small mt-2"><b>' + esc(im.changed) + '</b> of ' + esc(im.structures) + ' salaries change. Biggest changes in net pay:</div>' +
                        '<table class="impact"><tr><th>Employee</th><th class="num">Gross</th><th class="num">Net</th></tr>' +
                        im.rows.slice(0, 10).map((x) => '<tr><td>' + esc(x.emp_id) + ' ' + esc(x.emp_name || '') + '</td><td class="num">' +
                            inr.format(x.gross_before) + ' → ' + inr.format(x.gross_after) + '</td><td class="num">' +
                            inr.format(x.net_before) + ' → ' + inr.format(x.net_after) + '</td></tr>').join('') + '</table>';
                } else if (im && r.status) {
                    h += '<div class="small mt-1 muted">No employee net pay changes.</div>';
                }
                $('checkOut').innerHTML = h;
            }

            // ---------- events ----------
            document.addEventListener('click', (e) => {
                const so = e.target.closest('#scopeOpts .opt');
                if (so && CFG.isNew) { state.scope = so.dataset.scope; paint(); return; }
                const to = e.target.closest('#typeOpts .opt');
                if (to) { state.type = to.dataset.type; paint(); return; }
                const mo = e.target.closest('#methodOpts .opt');
                if (mo && !mo.classList.contains('off')) { state.method = mo.dataset.method; paint(); return; }
                const ins = e.target.closest('[data-ins]');
                if (ins) { insertAtCursor(ins.dataset.ins); return; }
                const del = e.target.closest('.s-del');
                if (del) { del.closest('tr').remove(); paint(); return; }
            });
            document.addEventListener('input', (e) => {
                if (e.target.id === 'fFormula') paintFxMsg();
                if (e.target.id === 'fCode') e.target.value = e.target.value.toUpperCase().replace(/[^A-Z0-9_]/g, '');
                paint();
            });
            document.addEventListener('change', (e) => {
                if (e.target.classList.contains('s-type')) syncSlabRow(e.target.closest('tr'));
                paint();
            });
            $('btnAddSlab').addEventListener('click', () => {
                $('slabBody').insertAdjacentHTML('beforeend', slabRow(null));
                syncSlabRow($('slabBody').lastElementChild);
                paint();
            });
            $('btnCheckFx').addEventListener('click', () => {
                const m = localFormulaCheck();
                if (m) { paintFxMsg(); return; }
                $('fxMsg').innerHTML = '<i class="fas fa-spinner fa-spin"></i> Checking…';
                post(CFG.checkFormulaUrl, { component_id: state.component_id || '', code: $('fCode').value.toUpperCase(),
                                            calculation_order: $('fOrder').value, formula_expression: $('fFormula').value.toUpperCase() })
                    .then((r) => {
                        $('fxMsg').innerHTML = r.status
                            ? '<span class="ok-txt"><i class="fas fa-check-circle"></i> ' + esc(r.message) + '</span>'
                            : '<span class="bad-txt"><i class="fas fa-exclamation-circle"></i> ' + esc(r.message) + '</span>';
                    });
            });
            $('btnCheck').addEventListener('click', () => {
                const p = problems();
                if (p) { toast(p, 'bad'); return; }
                $('btnCheck').disabled = true;
                $('checkOut').innerHTML = '<div class="small"><i class="fas fa-spinner fa-spin"></i> Calculating every employee…</div>';
                post(CFG.saveUrl, payload(true)).then((r) => { $('btnCheck').disabled = false; showResult(r); });
            });
            let saved = false, dirty = false;
            document.addEventListener('input', () => { dirty = true; });
            $('btnSave').addEventListener('click', async () => {
                const p = problems();
                if (p) { toast(p, 'bad'); return; }
                const ans = await payrollDialog.ask({
                    title: CFG.isNew ? 'Create component' : 'Save component',
                    message: summary() + '\n\nEvery salary is recalculated. Calculated payroll cycles go back so they use the new rule.',
                    okText: CFG.isNew ? 'Create' : 'Save'
                });
                if (!ans.ok) return;
                $('btnSave').disabled = true;
                $('btnSave').innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving…';
                post(CFG.saveUrl, payload(false)).then((r) => {
                    if (r.status && r.redirect) {
                        saved = true;
                        window.location.href = r.redirect;
                        return;
                    }
                    $('btnSave').disabled = false;
                    $('btnSave').innerHTML = '<i class="fas fa-save"></i> ' + (CFG.isNew ? 'Create component' : 'Save changes');
                    showResult(r);
                    toast(r.message || 'Not saved.', 'bad');
                });
            });
            window.addEventListener('beforeunload', (e) => { if (dirty && !saved) { e.preventDefault(); e.returnValue = ''; } });

            // ---------- start ----------
            fillBase();
            fillElig();
            fillInsert();
            $('fName').value = INIT.name;
            $('fCode').value = INIT.code;
            $('fFixed').value = INIT.method === 'FIXED' ? INIT.value : '';
            $('fPct').value = INIT.method === 'PERCENT' ? INIT.value : '';
            if (INIT.method === 'PERCENT' && INIT.base && INIT.base !== 'NONE') $('fBase').value = INIT.base;
            else if ([...$('fBase').options].some((o) => o.value === 'CTC1')) $('fBase').value = 'CTC1';
            $('fFormula').value = INIT.formula;
            $('fMin').value = INIT.min === null ? '' : INIT.min;
            $('fMax').value = INIT.max === null ? '' : INIT.max;
            $('fRound').value = INIT.rounding || '2';
            $('fElig').value = INIT.eligibility || '';
            $('fTaxable').checked = Number(INIT.taxable) === 1;
            $('fStatutory').checked = Number(INIT.statutory) === 1;
            $('fActive').checked = Number(INIT.active) === 1;
            $('fInclude').checked = Number(INIT.include_in_total) === 1;
            $('fOrder').value = INIT.order;
            if (Number(INIT.balancing) === 1) state.method = 'BALANCING';
            SLABS.forEach((s) => { $('slabBody').insertAdjacentHTML('beforeend', slabRow(s)); syncSlabRow($('slabBody').lastElementChild); });
            paintFxMsg();
            paint();
        })();
    </script>
</body>

</html>
