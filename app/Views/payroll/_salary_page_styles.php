<?php
// Shared look of the employee salary pages (salary_structure_edit, salary_structure_new):
// same theme as the salary structure list page.
?>
    <style>
        :root {
            --bloom-purple: #4a00e0;
            --bloom-dark: #120038;
            --bloom-success: #10b981;
            --bloom-danger: #dc2626;
            --bloom-warning: #f59e0b;
            --soft-gray: #f8fafc;
            --border-color: #e2e8f0;
            --text-dark: #1e293b;
            --text-muted: #64748b;
        }
        body { font-family: 'Plus Jakarta Sans', sans-serif; background-color: var(--soft-gray); font-size: 13px; color: #334155; }
        .content-wrapper { min-height: calc(100vh - 57px) !important; padding-bottom: 40px !important; background-color: var(--soft-gray); }
        .payroll-page { color: #334155; padding: 14px 20px 24px; }
        .payroll-page * { box-sizing: border-box; }
        .pc-card { background: #fff; border: 1px solid var(--border-color) !important; border-radius: 16px !important;
                   box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.03) !important; margin-bottom: 1.25rem; overflow: hidden; }
        .pc-body { padding: 20px; }
        .pc-heading { font-size: 22px; font-weight: 700; color: var(--bloom-dark); margin: 0 0 4px; }
        .pc-section-title { font-size: 14px; font-weight: 800; color: var(--bloom-dark); margin: 0; }
        .pc-section-help { font-size: 12px; color: var(--text-muted); margin: 2px 0 0; }
        .step-no { display: inline-flex; width: 24px; height: 24px; border-radius: 50%; background: var(--bloom-purple); color: #fff;
                   align-items: center; justify-content: center; font-size: 12px; font-weight: 800; margin-right: 8px; }
        .badge-soft-primary { background: #eef2ff !important; color: var(--bloom-purple) !important; }
        .badge-soft-success { background: #dcfce7 !important; color: #15803d !important; }
        .badge-soft-info { background: #e0f2fe !important; color: #0369a1 !important; }
        .badge-soft-danger { background: #fee2e2 !important; color: #b91c1c !important; }
        .badge-soft-warning { background: #fef3c7 !important; color: #b45309 !important; }
        .badge-soft-secondary { background: #f1f5f9 !important; color: #475569 !important; }
        .chip { display: inline-flex; align-items: center; gap: 5px; border-radius: 20px; padding: 4px 10px; font-size: 11.5px; font-weight: 700; }
        .pc-btn { border: 1px solid var(--border-color); border-radius: 9px; background: #fff; color: var(--text-dark); padding: 8px 14px;
                  font-size: 12px; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; gap: 7px;
                  cursor: pointer; text-decoration: none !important; transition: all 0.2s ease; white-space: nowrap; }
        .pc-btn:hover { background: #f1f5f9; color: var(--bloom-purple); border-color: #cbd5e1; }
        .pc-btn:disabled { opacity: .5; cursor: not-allowed; }
        .pc-btn-primary { background: var(--bloom-purple) !important; border-color: var(--bloom-purple) !important; color: #fff !important;
                          box-shadow: 0 3px 8px rgba(74, 0, 224, 0.2); }
        .pc-btn-primary:hover { background: var(--bloom-dark) !important; border-color: var(--bloom-dark) !important; color: #fff !important; }
        .pc-btn-sm { padding: 4px 10px; font-size: 11px; border-radius: 7px; }
        .pc-control { height: 36px; padding: 6px 10px; border: 1px solid var(--border-color); border-radius: 9px; background: #fff;
                      color: var(--text-dark); font-family: inherit; font-size: 12.5px; outline: none; transition: border-color .2s, box-shadow .2s; }
        .pc-control:focus { border-color: var(--bloom-purple); box-shadow: 0 0 0 3px rgba(74, 0, 224, .1); }
        .pc-label { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .4px; color: var(--text-muted); margin-bottom: 4px; display: block; }

        /* employee header */
        .emp-hero { background: linear-gradient(135deg, #120038 0%, #2a0080 100%); color: #fff; border-radius: 16px; padding: 18px 22px; margin-bottom: 1.25rem; }
        .emp-avatar { width: 46px; height: 46px; border-radius: 50%; background: rgba(255,255,255,.18); display: inline-flex; align-items: center;
                      justify-content: center; font-weight: 800; font-size: 16px; }
        .emp-hero .meta { color: rgba(255,255,255,.75); font-size: 12px; }
        .emp-hero .pc-btn { background: rgba(255,255,255,.12); border-color: rgba(255,255,255,.25); color: #fff; }
        .emp-hero .pc-btn:hover { background: rgba(255,255,255,.22); color: #fff; }

        /* salary periods */
        .period-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 10px; }
        .period-card { display: block; border: 1px solid var(--border-color); border-radius: 12px; padding: 12px 14px; color: inherit;
                       text-decoration: none !important; transition: all .15s ease; background: #fff; }
        .period-card:hover { border-color: #c7d2fe; background: #fafaff; color: inherit; }
        .period-card.active { border-color: var(--bloom-purple); box-shadow: 0 0 0 3px rgba(74, 0, 224, .12); background: #faf8ff; }
        .period-card .dates { font-weight: 800; color: var(--bloom-dark); font-size: 13px; }
        .period-card .ctc { font-variant-numeric: tabular-nums; font-weight: 700; font-size: 15px; color: var(--bloom-purple); }

        /* notices */
        .notice { border-radius: 12px; padding: 10px 14px; font-size: 12.5px; display: flex; gap: 10px; align-items: flex-start; }
        .notice i { margin-top: 2px; }
        .notice-info { background: #e0f2fe; color: #0c4a6e; }
        .notice-warn { background: #fef3c7; color: #78350f; }
        .notice-muted { background: #f1f5f9; color: #334155; }

        /* components */
        .group-head { display: flex; justify-content: space-between; align-items: center; padding: 10px 20px; border-top: 1px solid var(--border-color);
                      border-bottom: 1px solid var(--border-color); background: #f8fafc; }
        .group-head .t { font-weight: 800; font-size: 12px; text-transform: uppercase; letter-spacing: .5px; }
        .group-earn .t { color: #4338ca; } .group-er .t { color: #0369a1; } .group-ded .t { color: #b91c1c; } .group-tot .t { color: #15803d; }
        .group-head .sum { font-weight: 800; font-variant-numeric: tabular-nums; }
        table.cmp { width: 100%; border-collapse: separate; border-spacing: 0; }
        table.cmp th { font-size: 10.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .4px; color: #94a3b8; padding: 8px 12px; border-bottom: 1px solid #f1f5f9; }
        table.cmp td { padding: 10px 12px; border-bottom: 1px solid #f1f5f9; vertical-align: middle; }
        table.cmp tr.changed td { background: #fffbeb; }
        table.cmp td.amt { text-align: right; font-variant-numeric: tabular-nums; font-weight: 700; color: var(--text-dark); white-space: nowrap; width: 130px; }
        .cmp-name { font-weight: 700; color: var(--text-dark); }
        .cmp-code { font-size: 11px; color: #94a3b8; font-family: ui-monospace, monospace; }
        .rule { font-size: 12px; color: #475569; margin-top: 4px; }
        .rule .f { font-family: ui-monospace, monospace; font-size: 11.5px; background: #f8fafc; border: 1px solid #eef2f7; border-radius: 6px; padding: 1px 6px; word-break: break-all; }
        .own-wrap { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
        .own-wrap .pc-control { height: 32px; font-size: 12px; }
        .own-wrap .v { width: 110px; } .own-wrap .b { width: 120px; } .own-wrap .fx { width: 230px; font-family: ui-monospace, monospace; }

        /* summary */
        .summary { position: sticky; top: 70px; }
        @media (max-width: 1199.98px) { .summary { position: static; } }
        .rule-lines div { line-height: 1.45; }
        .cmp-main { min-width: 220px; }
        .summary .net { font-size: 28px; font-weight: 800; color: #15803d; font-variant-numeric: tabular-nums; line-height: 1.1; }
        .summary .row-line { display: flex; justify-content: space-between; padding: 7px 0; border-bottom: 1px dashed #e2e8f0; font-variant-numeric: tabular-nums; }
        .summary .row-line:last-child { border-bottom: none; }
        .summary .row-line b { color: var(--text-dark); }
        .check-ok { color: #15803d; font-weight: 700; font-size: 12px; }
        .check-bad { color: #b45309; font-weight: 700; font-size: 12px; }
        .muted { color: var(--text-muted); }
        #toastBox { position: fixed; top: 20px; right: 20px; z-index: 99999; display: flex; flex-direction: column; gap: 8px; max-width: 440px; }
        .toast-msg { border-radius: 12px; padding: 12px 16px; font-size: 13px; font-weight: 600; box-shadow: 0 10px 25px rgba(0,0,0,.18); color: #fff; }
        .toast-ok { background: #059669; } .toast-bad { background: #dc2626; } .toast-info { background: #334155; }
    </style>
