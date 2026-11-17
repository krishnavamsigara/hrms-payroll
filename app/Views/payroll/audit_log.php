<?php
/**
 * Payroll Audit Log (C-130): who changed what in payroll, when, with the values before and after.
 * Rows come from hrms_payroll_audit_list (audit trail + payroll cycle log), newest first.
 *
 * @var array       $rows
 * @var string|null $error
 * @var array       $modules
 * @var array       $filters  module, emp, from, to, q
 * @var int         $page, $perPage, $total
 */
$moduleLabels = [
    'CYCLE'        => 'Payroll cycle',
    'COMPONENT'    => 'Component',
    'SLAB'         => 'Slabs',
    'SALARY'       => 'Salary',
    'MANUAL_INPUT' => 'Manual amount',
    'ATTENDANCE'   => 'Attendance',
    'PAYSLIP'      => 'Payslip',
    'SECURITY'     => 'Access denied',
];
$monthNames = [1 => 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
$pages      = max(1, (int) ceil($total / max(1, $perPage)));
$pageUrl    = static function (int $p) use ($filters) {
    $q = array_filter($filters + ['page' => $p], static fn ($v) => $v !== '' && $v !== null);
    return base_url('payroll/audit_log') . ($q ? '?' . http_build_query($q) : '');
};
$detailRows = array_map(static fn ($r) => [
    'old'     => $r['old_values'] ?? null,
    'new'     => $r['new_values'] ?? null,
    'title'   => ($moduleLabels[$r['module']] ?? $r['module']) . ' · ' . str_replace('_', ' ', $r['action']),
    'details' => $r['details'] ?? '',
], $rows);
?>
<style>
  .pa-page { padding: 20px; }
  .pa-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 16px; box-shadow: 0 4px 6px -1px rgba(0,0,0,.04); margin-bottom: 16px; }
  .pa-body { padding: 16px 18px; }
  .pa-title { font-size: 20px; font-weight: 700; color: #1e293b; margin: 0; }
  .pa-sub { color: #64748b; font-size: 12.5px; margin-top: 2px; }
  .pa-filters { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; align-items: end; }
  .pa-filters label { display: block; font-size: 11.5px; font-weight: 700; color: #475569; margin-bottom: 3px; }
  .pa-filters input, .pa-filters select { width: 100%; height: 34px; border: 1px solid #cbd5e1; border-radius: 8px; padding: 0 8px; font-size: 13px; background: #fff; }
  .pa-btn { height: 34px; border-radius: 8px; border: 1px solid #cbd5e1; background: #fff; color: #334155; padding: 0 12px; font-weight: 600; font-size: 13px; display: inline-flex; align-items: center; gap: 6px; text-decoration: none; cursor: pointer; }
  .pa-btn:hover { background: #f1f5f9; text-decoration: none; color: #334155; }
  .pa-btn-primary { background: #4a00e0; border-color: #4a00e0; color: #fff; }
  .pa-btn-primary:hover { background: #3a00b0; color: #fff; }
  .pa-btn[disabled], .pa-btn.pa-disabled { opacity: .45; pointer-events: none; }
  .pa-table-wrap { overflow-x: auto; }
  .pa-table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
  .pa-table th { background: #f8fafc; color: #475569; font-weight: 700; text-align: left; padding: 9px 10px; border-bottom: 1px solid #e2e8f0; white-space: nowrap; }
  .pa-table td { padding: 9px 10px; border-bottom: 1px solid #f1f5f9; vertical-align: top; color: #334155; }
  .pa-table tr:hover td { background: #fafaff; }
  .pa-when { white-space: nowrap; }
  .pa-when small, .pa-who small { display: block; color: #94a3b8; }
  .pa-chip { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: 11px; font-weight: 700; white-space: nowrap; }
  .pa-m-CYCLE { background: #ede9fe; color: #5b21b6; }
  .pa-m-COMPONENT, .pa-m-SLAB { background: #e0f2fe; color: #075985; }
  .pa-m-SALARY { background: #dcfce7; color: #166534; }
  .pa-m-MANUAL_INPUT { background: #fef3c7; color: #92400e; }
  .pa-m-ATTENDANCE { background: #ffedd5; color: #9a3412; }
  .pa-m-PAYSLIP { background: #f1f5f9; color: #334155; }
  .pa-m-SECURITY { background: #fee2e2; color: #991b1b; }
  .pa-action { font-weight: 700; color: #1e293b; white-space: nowrap; }
  .pa-details { max-width: 460px; }
  .pa-empty { text-align: center; color: #94a3b8; padding: 30px 10px; }
  .pa-error { background: #fef2f2; color: #991b1b; border: 1px solid #fecaca; border-radius: 10px; padding: 10px 12px; margin-bottom: 12px; }
  .pa-pager { display: flex; justify-content: space-between; align-items: center; gap: 10px; flex-wrap: wrap; padding: 12px 18px; border-top: 1px solid #f1f5f9; color: #64748b; }
  /* before / after box */
  .pa-modal { position: fixed; inset: 0; background: rgba(15,23,42,.45); z-index: 2040; display: none; align-items: center; justify-content: center; padding: 16px; }
  .pa-modal.pa-open { display: flex; }
  .pa-modal-box { background: #fff; border-radius: 14px; width: 100%; max-width: 860px; max-height: 88vh; display: flex; flex-direction: column; box-shadow: 0 20px 50px rgba(15,23,42,.25); overflow: hidden; }
  .pa-modal-head { padding: 13px 18px; background: #4a00e0; color: #fff; font-weight: 700; display: flex; justify-content: space-between; align-items: center; gap: 10px; }
  .pa-modal-head button { background: transparent; border: 0; color: #fff; font-size: 20px; line-height: 1; cursor: pointer; }
  .pa-modal-body { padding: 14px 18px; overflow: auto; }
  .pa-modal-note { color: #475569; margin-bottom: 10px; white-space: pre-line; }
  .pa-diff { width: 100%; border-collapse: collapse; font-size: 12.5px; }
  .pa-diff th { background: #f8fafc; text-align: left; padding: 7px 9px; border-bottom: 1px solid #e2e8f0; position: sticky; top: -14px; }
  .pa-diff td { padding: 6px 9px; border-bottom: 1px solid #f1f5f9; vertical-align: top; word-break: break-word; }
  .pa-diff td:first-child { color: #64748b; white-space: nowrap; }
  .pa-diff tr.pa-changed td { background: #fffbeb; }
  .pa-diff tr.pa-changed td.pa-new { color: #166534; font-weight: 700; }
  .pa-diff tr.pa-changed td.pa-old { color: #991b1b; }
  .pa-diff .pa-none { color: #cbd5e1; }
  .pa-toggle { display: inline-flex; align-items: center; gap: 6px; font-size: 12.5px; color: #475569; margin-bottom: 8px; cursor: pointer; }
</style>

<div class="content-wrapper">
  <div class="pa-page">

    <div class="pa-card">
      <div class="pa-body d-flex align-items-center justify-content-between flex-wrap" style="gap: 12px;">
        <div>
          <h1 class="pa-title"><i class="fas fa-history mr-2" style="color:#4a00e0"></i>Payroll Audit Log</h1>
          <div class="pa-sub">Who changed what in payroll and when, with the values before and after. Newest first.</div>
        </div>
        <a href="<?= base_url('payroll/payroll_dashboard') ?>" class="pa-btn"><i class="fas fa-arrow-left"></i> Payroll</a>
      </div>
    </div>

    <div class="pa-card">
      <form class="pa-body" method="get" action="<?= base_url('payroll/audit_log') ?>">
        <div class="pa-filters">
          <div>
            <label for="paModule">Area</label>
            <select id="paModule" name="module">
              <option value="">All areas</option>
              <?php foreach ($modules as $m): ?>
                <option value="<?= esc($m) ?>" <?= $filters['module'] === $m ? 'selected' : '' ?>><?= esc($moduleLabels[$m] ?? $m) ?></option>
              <?php endforeach; ?>
            </select>
          </div>
          <div>
            <label for="paEmp">Employee ID</label>
            <input id="paEmp" name="emp" value="<?= esc($filters['emp']) ?>" placeholder="Affected or done by">
          </div>
          <div>
            <label for="paFrom">From</label>
            <input id="paFrom" type="date" name="from" value="<?= esc($filters['from']) ?>">
          </div>
          <div>
            <label for="paTo">To</label>
            <input id="paTo" type="date" name="to" value="<?= esc($filters['to']) ?>">
          </div>
          <div>
            <label for="paQ">Search</label>
            <input id="paQ" name="q" value="<?= esc($filters['q']) ?>" placeholder="Action, code, name, remarks">
          </div>
          <div class="d-flex" style="gap: 8px;">
            <button type="submit" class="pa-btn pa-btn-primary"><i class="fas fa-filter"></i> Filter</button>
            <a href="<?= base_url('payroll/audit_log') ?>" class="pa-btn">Clear</a>
          </div>
        </div>
      </form>
    </div>

    <div class="pa-card">
      <div class="pa-body" style="padding-bottom: 0;">
        <?php if ($error): ?>
          <div class="pa-error"><i class="fas fa-lock mr-1"></i> <?= esc($error) ?></div>
        <?php endif; ?>
      </div>
      <div class="pa-table-wrap">
        <table class="pa-table">
          <thead>
            <tr>
              <th>When</th>
              <th>Done by</th>
              <th>Area</th>
              <th>Action</th>
              <th>Employee</th>
              <th>Payroll month</th>
              <th>Details</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <?php if (!$rows): ?>
              <tr><td colspan="8" class="pa-empty"><?= $error ? 'Nothing to show.' : 'No audit entries match these filters.' ?></td></tr>
            <?php endif; ?>
            <?php foreach ($rows as $i => $r): ?>
              <?php
                $ts   = strtotime((string) $r['performed_at']);
                $mon  = (int) ($r['payroll_month'] ?? 0);
                $hasValues = ($r['old_values'] ?? null) !== null || ($r['new_values'] ?? null) !== null;
              ?>
              <tr>
                <td class="pa-when"><?= esc(date('d M Y', $ts)) ?><small><?= esc(date('h:i:s A', $ts)) ?></small></td>
                <td class="pa-who"><?= esc($r['performed_by_name'] ?? $r['performed_by']) ?><small><?= esc($r['performed_by']) ?></small></td>
                <td><span class="pa-chip pa-m-<?= esc($r['module']) ?>"><?= esc($moduleLabels[$r['module']] ?? $r['module']) ?></span></td>
                <td class="pa-action"><?= esc(str_replace('_', ' ', $r['action'])) ?>
                  <?php if (!empty($r['ref_id'])): ?><small class="d-block text-muted" style="font-weight:400"><?= esc($r['ref_id']) ?></small><?php endif; ?>
                </td>
                <td class="pa-who">
                  <?php if (!empty($r['affected_emp_id'])): ?>
                    <?= esc($r['affected_name'] ?? $r['affected_emp_id']) ?><small><?= esc($r['affected_emp_id']) ?></small>
                  <?php else: ?><span class="text-muted">—</span><?php endif; ?>
                </td>
                <td class="pa-when"><?= $mon ? esc(($monthNames[$mon] ?? $mon) . ' ' . $r['payroll_year']) : '<span class="text-muted">—</span>' ?></td>
                <td class="pa-details"><?= esc($r['details'] ?? '') ?></td>
                <td>
                  <?php if ($hasValues): ?>
                    <button type="button" class="pa-btn" onclick="paShow(<?= (int) $i ?>)" title="Before and after"><i class="fas fa-exchange-alt"></i> Changes</button>
                  <?php endif; ?>
                </td>
              </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
      <div class="pa-pager">
        <span><?= $total ? esc(number_format($total)) . ' entr' . ($total === 1 ? 'y' : 'ies') . ' · page ' . $page . ' of ' . $pages : '' ?></span>
        <span class="d-flex" style="gap: 8px;">
          <a class="pa-btn <?= $page <= 1 ? 'pa-disabled' : '' ?>" href="<?= esc($pageUrl($page - 1)) ?>"><i class="fas fa-chevron-left"></i> Newer</a>
          <a class="pa-btn <?= $page >= $pages ? 'pa-disabled' : '' ?>" href="<?= esc($pageUrl($page + 1)) ?>">Older <i class="fas fa-chevron-right"></i></a>
        </span>
      </div>
    </div>

  </div>
</div>

<div class="pa-modal" id="paModal" role="dialog" aria-modal="true" aria-labelledby="paModalTitle">
  <div class="pa-modal-box">
    <div class="pa-modal-head"><span id="paModalTitle">Changes</span><button type="button" onclick="paClose()" aria-label="Close">&times;</button></div>
    <div class="pa-modal-body">
      <div class="pa-modal-note" id="paModalNote"></div>
      <label class="pa-toggle"><input type="checkbox" id="paOnlyChanged" checked onchange="paRender()"> Show only what changed</label>
      <table class="pa-diff">
        <thead><tr><th style="width:30%">Field</th><th style="width:35%">Before</th><th style="width:35%">After</th></tr></thead>
        <tbody id="paDiffBody"></tbody>
      </table>
    </div>
  </div>
</div>

<script>
  const paRows = <?= json_encode($detailRows, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE) ?>;
  let paCurrent = null;

  // {a:{b:1}, list:[{x:1}]} -> {"a.b":1, "list 1.x":1}
  function paFlatten(value, prefix, out) {
    if (value !== null && typeof value === 'object') {
      const keys = Array.isArray(value) ? value.map((_, i) => i) : Object.keys(value);
      if (!keys.length) { out[prefix || '(empty)'] = Array.isArray(value) ? '(none)' : '(none)'; }
      keys.forEach(k => {
        const name = Array.isArray(value) ? `${prefix} ${k + 1}` : (prefix ? `${prefix}.${k}` : k);
        paFlatten(value[k], name, out);
      });
    } else {
      out[prefix || 'value'] = value;
    }
    return out;
  }
  function paParse(text) {
    if (text === null || text === undefined || text === '') return null;
    try { return JSON.parse(text); } catch (e) { return text; }
  }
  function paCell(v, cls) {
    const td = document.createElement('td');
    if (cls) td.className = cls;
    if (v === undefined) { td.innerHTML = '<span class="pa-none">—</span>'; }
    else if (v === null) { td.innerHTML = '<span class="pa-none">empty</span>'; }
    else { td.textContent = String(v); }
    return td;
  }
  function paRender() {
    if (!paCurrent) return;
    const before = paFlatten(paParse(paCurrent.old) ?? {}, '', {});
    const after  = paFlatten(paParse(paCurrent.new) ?? {}, '', {});
    const only   = document.getElementById('paOnlyChanged').checked;
    const keys   = [...new Set([...Object.keys(before), ...Object.keys(after)])];
    const body   = document.getElementById('paDiffBody');
    body.innerHTML = '';
    let shown = 0;
    keys.forEach(k => {
      const a = before[k], b = after[k];
      const changed = paCurrent.old !== null && paCurrent.new !== null ? String(a) !== String(b) : true;
      if (only && !changed) return;
      const tr = document.createElement('tr');
      if (changed && paCurrent.old !== null && paCurrent.new !== null) tr.className = 'pa-changed';
      tr.appendChild(paCell(k.replace(/_/g, ' ')));
      tr.appendChild(paCell(paCurrent.old === null ? undefined : a, 'pa-old'));
      tr.appendChild(paCell(paCurrent.new === null ? undefined : b, 'pa-new'));
      body.appendChild(tr);
      shown++;
    });
    if (!shown) {
      body.innerHTML = '<tr><td colspan="3" class="pa-none" style="text-align:center;padding:16px">No values changed.</td></tr>';
    }
  }
  function paShow(i) {
    paCurrent = paRows[i];
    document.getElementById('paModalTitle').textContent = paCurrent.title;
    document.getElementById('paModalNote').textContent = paCurrent.details || '';
    document.getElementById('paOnlyChanged').checked = true;
    paRender();
    document.getElementById('paModal').classList.add('pa-open');
  }
  function paClose() { document.getElementById('paModal').classList.remove('pa-open'); paCurrent = null; }
  document.getElementById('paModal').addEventListener('click', e => { if (e.target.id === 'paModal') paClose(); });
  document.addEventListener('keydown', e => { if (e.key === 'Escape') paClose(); });
</script>
