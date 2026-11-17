<?php
/**
 * Payroll popup box (in the page, no browser confirm / prompt / alert).
 * Include once per page:  <?= view('payroll/_dialog') ?>
 *
 * JavaScript:
 *   const r = await payrollDialog.ask({
 *       title: 'Hold salary',                 // heading
 *       message: 'Text\nwith line breaks',    // plain text, \n = new line
 *       input: { label: 'Reason', required: true, placeholder: '...', multiline: true },  // optional
 *       okText: 'Hold salary', cancelText: 'Cancel', danger: false
 *   });
 *   if (r.ok) { use r.value }                 // r.value = text typed in the field ('' when no field)
 *
 *   await payrollDialog.message({ title: 'Payslip', message: 'PDF download failed.' });   // one OK button
 */
?>
<style>
  .pdlg-backdrop { position: fixed; inset: 0; background: rgba(15, 23, 42, .45); z-index: 2050;
                   display: none; align-items: center; justify-content: center; padding: 16px; }
  .pdlg-backdrop.pdlg-open { display: flex; }
  .pdlg-box { background: #fff; border-radius: 14px; width: 100%; max-width: 460px; box-shadow: 0 20px 50px rgba(15, 23, 42, .25);
              overflow: hidden; font-family: inherit; }
  .pdlg-head { padding: 14px 18px; background: #4a00e0; color: #fff; font-weight: 700; font-size: 15px; display: flex;
               align-items: center; gap: 8px; }
  .pdlg-box.pdlg-danger .pdlg-head { background: #b91c1c; }
  .pdlg-body { padding: 16px 18px 8px; color: #334155; font-size: 13.5px; line-height: 1.55; }
  .pdlg-msg { white-space: pre-line; margin-bottom: 10px; }
  .pdlg-label { display: block; font-weight: 700; font-size: 12px; color: #475569; margin: 4px 0 4px; }
  .pdlg-label .pdlg-opt { font-weight: 400; color: #94a3b8; }
  .pdlg-input { width: 100%; border: 1px solid #cbd5e1; border-radius: 9px; padding: 8px 10px; font-size: 13px; color: #0f172a;
                outline: none; resize: vertical; font-family: inherit; }
  .pdlg-input:focus { border-color: #4a00e0; box-shadow: 0 0 0 3px rgba(74, 0, 224, .12); }
  .pdlg-input.pdlg-bad { border-color: #dc2626; }
  .pdlg-err { color: #dc2626; font-size: 12px; min-height: 16px; margin-top: 3px; }
  .pdlg-foot { padding: 10px 18px 16px; display: flex; justify-content: flex-end; gap: 8px; }
  .pdlg-btn { border: 1px solid #cbd5e1; border-radius: 9px; background: #fff; color: #334155; padding: 8px 16px;
              font-size: 12.5px; font-weight: 700; cursor: pointer; }
  .pdlg-btn:hover { background: #f1f5f9; }
  .pdlg-btn-ok { background: #4a00e0; border-color: #4a00e0; color: #fff; }
  .pdlg-btn-ok:hover { background: #2d0a8c; }
  .pdlg-box.pdlg-danger .pdlg-btn-ok { background: #dc2626; border-color: #dc2626; }
  .pdlg-box.pdlg-danger .pdlg-btn-ok:hover { background: #b91c1c; }
</style>
<div class="pdlg-backdrop" id="pdlgBackdrop" role="dialog" aria-modal="true" aria-labelledby="pdlgTitle">
  <div class="pdlg-box" id="pdlgBox">
    <div class="pdlg-head"><i class="fas fa-info-circle" id="pdlgIcon"></i><span id="pdlgTitle"></span></div>
    <div class="pdlg-body">
      <div class="pdlg-msg" id="pdlgMsg"></div>
      <div id="pdlgField" style="display: none;">
        <label class="pdlg-label" for="pdlgInput" id="pdlgLabel"></label>
        <textarea class="pdlg-input" id="pdlgInput" rows="2"></textarea>
        <div class="pdlg-err" id="pdlgErr"></div>
      </div>
    </div>
    <div class="pdlg-foot">
      <button type="button" class="pdlg-btn" id="pdlgCancel">Cancel</button>
      <button type="button" class="pdlg-btn pdlg-btn-ok" id="pdlgOk">OK</button>
    </div>
  </div>
</div>
<script>
  window.payrollDialog = (function () {
    const $ = (id) => document.getElementById(id);
    let resolver = null, opts = {};

    function close(result) {
      $('pdlgBackdrop').classList.remove('pdlg-open');
      document.removeEventListener('keydown', onKey, true);
      const r = resolver; resolver = null;
      if (r) r(result);
    }
    function confirmNow() {
      const field = opts.input;
      const value = field ? $('pdlgInput').value.trim() : '';
      if (field && field.required && value === '') {
        $('pdlgErr').textContent = field.requiredText || ('Enter ' + (field.label || 'a value').toLowerCase() + '.');
        $('pdlgInput').classList.add('pdlg-bad');
        $('pdlgInput').focus();
        return;
      }
      close({ ok: true, value: value });
    }
    function onKey(e) {
      if (e.key === 'Escape') { e.preventDefault(); close({ ok: false, value: '' }); }
      else if (e.key === 'Enter' && !(opts.input && opts.input.multiline) && !e.shiftKey) { e.preventDefault(); confirmNow(); }
    }
    $('pdlgOk').addEventListener('click', confirmNow);
    $('pdlgCancel').addEventListener('click', () => close({ ok: false, value: '' }));
    $('pdlgBackdrop').addEventListener('click', (e) => { if (e.target.id === 'pdlgBackdrop') close({ ok: false, value: '' }); });
    $('pdlgInput').addEventListener('input', () => { $('pdlgErr').textContent = ''; $('pdlgInput').classList.remove('pdlg-bad'); });

    function ask(o) {
      if (resolver) close({ ok: false, value: '' });     // only one box at a time
      opts = o || {};
      $('pdlgTitle').textContent = opts.title || 'Please confirm';
      $('pdlgMsg').textContent = opts.message || '';
      $('pdlgMsg').style.display = opts.message ? '' : 'none';
      $('pdlgBox').classList.toggle('pdlg-danger', !!opts.danger);
      $('pdlgIcon').className = 'fas ' + (opts.danger ? 'fa-exclamation-triangle' : (opts.icon || 'fa-info-circle'));
      $('pdlgOk').textContent = opts.okText || 'OK';
      $('pdlgCancel').textContent = opts.cancelText || 'Cancel';
      $('pdlgCancel').style.display = opts.noCancel ? 'none' : '';
      const f = opts.input;
      $('pdlgField').style.display = f ? '' : 'none';
      $('pdlgErr').textContent = '';
      $('pdlgInput').classList.remove('pdlg-bad');
      if (f) {
        $('pdlgLabel').innerHTML = '';
        $('pdlgLabel').appendChild(document.createTextNode(f.label || 'Value'));
        if (!f.required) { const s = document.createElement('span'); s.className = 'pdlg-opt'; s.textContent = ' (optional)'; $('pdlgLabel').appendChild(s); }
        $('pdlgInput').value = f.value || '';
        $('pdlgInput').placeholder = f.placeholder || '';
        $('pdlgInput').rows = f.multiline ? 3 : 1;
      }
      $('pdlgBackdrop').classList.add('pdlg-open');
      document.addEventListener('keydown', onKey, true);
      setTimeout(() => (f ? $('pdlgInput') : $('pdlgOk')).focus(), 30);
      return new Promise((resolve) => { resolver = resolve; });
    }
    function message(o) {
      return ask(Object.assign({ okText: 'OK', noCancel: true }, o || {}));
    }
    return { ask: ask, message: message };
  })();
</script>
