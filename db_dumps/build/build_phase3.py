"""
Builds db_dumps/component_phase3.sql.

Procedures changed in phase 3 are taken from the file that defines them last
(component_phase2.sql, component_phase1.sql or script.sql) and patched with
exact text replacements; every replacement must match the expected number of
times, otherwise the build stops. Run from the V2 folder:
    python db_dumps/build/build_phase3.py
"""
import io
import sys

OUT = 'db_dumps/component_phase3.sql'


def read(path):
    return io.open(path, encoding='utf-8', newline='').read().replace('\r\n', '\n')


script = read('db_dumps/script.sql')
phase1 = read('db_dumps/component_phase1.sql')
phase2 = read('db_dumps/component_phase2.sql')


def block(src, name, kind='PROCEDURE'):
    tag = 'DROP %s IF EXISTS %s$$' % (kind, name)
    assert src.count(tag) == 1, (name, src.count(tag))
    start = src.index(tag)
    end = src.index('\nEND$$', start) + len('\nEND$$')
    return src[start:end]


def patch(text, old, new, count=1):
    found = text.count(old)
    if found != count:
        sys.exit('text %r found %d times, expected %d' % (old[:70], found, count))
    return text.replace(old, new)


parts = []

# ---- P3-003 engine: the balancing component (from the phase 2 version)
p = block(phase2, 'hrms_engine_run')
p = patch(p, "    DECLARE v_date       DATE;\n",
          "    DECLARE v_date       DATE;\n"
          "    DECLARE v_bal_sum    DECIMAL(18,4);   -- P3\n"
          "    DECLARE v_bal_ctc    DECIMAL(18,4);   -- P3\n")
p = patch(p, "            ELSEIF v_slab = 1 THEN\n",
          "            -- P3: the balancing component is what is left of CTC1 after the other\n"
          "            --     earnings counted in gross (not monthly entries) and the employer\n"
          "            --     contributions counted in their total, so the salary always adds\n"
          "            --     up to the CTC. An employee's own setting still wins.\n"
          "            ELSEIF v_overridden = 0\n"
          "               AND (SELECT COALESCE(MAX(bm.is_balancing), 0) FROM salary_component_master bm\n"
          "                     WHERE bm.component_id = v_cid) = 1 THEN\n"
          "                SELECT COALESCE(SUM(CASE\n"
          "                           WHEN bm.component_type = 'EARNING' AND bm.is_balancing = 0\n"
          "                                AND bm.is_manual = 0 AND bm.calculation_type <> 'MANUAL' THEN bv.var_value\n"
          "                           WHEN bm.component_type = 'EMPLOYER_CONTRIBUTION' THEN bv.var_value\n"
          "                           ELSE 0 END), 0)\n"
          "                  INTO v_bal_sum\n"
          "                  FROM tmp_hrms_formula_vars bv\n"
          "                  JOIN salary_component_master bm ON bm.component_id = bv.component_id\n"
          "                 WHERE bm.calculation_scope = 'COMPONENT' AND bm.is_active = 1 AND bm.include_in_total = 1;\n"
          "                SELECT COALESCE(MAX(var_value), 0) INTO v_bal_ctc FROM tmp_hrms_formula_vars WHERE var_code = 'CTC1';\n"
          "                SET v_new = v_bal_ctc - v_bal_sum;\n"
          "                SET v_limits = 1;\n"
          "            ELSEIF v_slab = 1 THEN\n")
parts.append(('P3-003', 'hrms_engine_run: the balancing component (rest of CTC1)', p))

# ---- P3-005 save: the BALANCING method (from the phase 1 version)
p = block(phase1, 'hrms_component_save')
p = patch(p, "        WHEN 'MONTHLY' THEN\n            SET v_calc = 'MANUAL', v_manual = 1;\n",
          "        WHEN 'MONTHLY' THEN\n            SET v_calc = 'MANUAL', v_manual = 1;\n"
          "        WHEN 'BALANCING' THEN\n"
          "            -- P3: rest of the CTC; the flag itself is set by hrms_component_set_flags\n"
          "            SET v_calc = 'FIXED', v_value = 0;\n"
          "            IF UPPER(TRIM(COALESCE(p_type, ''))) <> 'EARNING' THEN\n"
          "                SET v_msg = 'Only an earning can be the balancing component (rest of CTC).';\n"
          "            END IF;\n")
p = patch(p, "'Choose how the component is calculated: fixed, percent, formula, slabs or monthly entry.'",
          "'Choose how the component is calculated: fixed, percent, formula, slabs, monthly entry or balancing.'")
parts.append(('P3-005', 'hrms_component_save: + method BALANCING', p))

# ---- P3-007 names: auto_total (from the phase 2 version)
p = block(phase2, 'hrms_formula_names')
p = patch(p, "                   1000 + m.calculation_order, NULL, NULL, 0\n",
          "                   1000 + m.calculation_order, NULL, NULL,\n"
          "                   IF(m.calculation_scope = 'AGGREGATE'\n"
          "                      AND EXISTS (SELECT 1 FROM payroll_variables pv\n"
          "                                   WHERE pv.var_code = UPPER(m.component_code) AND pv.total_of_type IS NOT NULL)\n"
          "                      AND UPPER(TRIM(COALESCE(m.formula_expression, '0'))) REGEXP '^[A-Z0-9_ +]+$', 1, 0)\n")
parts.append(('P3-007', 'hrms_formula_names: + auto_total', p))

# ---- P3-008 employee salary page: the flags of each component (from script.sql)
p = block(script, 'hrms_salary_components_for_structure')
p = patch(p, "m.is_slab, m.is_manual, m.is_taxable,",
          "m.is_slab, m.is_manual, m.is_taxable, m.is_balancing, m.include_in_total,")
parts.append(('P3-008', 'hrms_salary_components_for_structure: + is_balancing, include_in_total', p))

head = read('db_dumps/build/phase3_head.sql')
tail = read('db_dumps/build/phase3_tail.sql')
body = ''
for pid, title, text in parts:
    body += ('\n-- ---------------------------------------------------------------------\n'
             '-- %s  %s\n'
             '--        (copied from its last definition and patched by db_dumps/build/build_phase3.py)\n'
             '-- ---------------------------------------------------------------------\n' % (pid, title))
    body += text + '\n'

io.open(OUT, 'w', encoding='utf-8', newline='\n').write(head + body + tail)
print('written', OUT)
