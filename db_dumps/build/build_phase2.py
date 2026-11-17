"""
Builds db_dumps/component_phase2.sql.

The procedures that phase 2 changes are taken from script.sql (their only
definition there) and patched with exact text replacements; every
replacement must match the expected number of times, otherwise the build
stops. Run from the V2 folder:  python db_dumps/build/build_phase2.py
"""
import io
import re
import sys

SRC = 'db_dumps/script.sql'
OUT = 'db_dumps/component_phase2.sql'

src = io.open(SRC, encoding='utf-8', newline='').read().replace('\r\n', '\n')


def block(name, kind='PROCEDURE'):
    """DROP ... name$$ up to the END$$ that closes the definition."""
    start = src.index('DROP %s IF EXISTS %s$$' % (kind, name))
    assert src.count('DROP %s IF EXISTS %s$$' % (kind, name)) == 1, name
    end = src.index('\nEND$$', start) + len('\nEND$$')
    return src[start:end]


def patch(text, old, new, count=1, regex=False):
    if regex:
        found = len(re.findall(old, text, flags=re.S))
        if found != count:
            sys.exit('pattern %r found %d times, expected %d' % (old[:60], found, count))
        return re.sub(old, new, text, flags=re.S)
    found = text.count(old)
    if found != count:
        sys.exit('text %r found %d times, expected %d' % (old[:60], found, count))
    return text.replace(old, new)


# the fixed lists of built-in names, e.g.  x NOT IN ('CTC','CTC1', ... )
BUILTIN_LIST = r"([A-Za-z_.]+) NOT IN \('CTC','CTC1',[^)]*\)"
TO_FUNCTION = r"hrms_is_variable(\1) = 0"

parts = []

# ---- formula check: 2 lists
p = block('hrms_formula_check')
p = patch(p, BUILTIN_LIST, TO_FUNCTION, 2, regex=True)
p = patch(p, "'. Use a component code or CTC, CTC1, GROSS, ESI_WAGE, STANDARD_ESI_WAGE, MANUAL_AMOUNT, PAYABLE_DAYS, LOP_DAYS.'",
          "'. Use a component code or a payroll variable (Payroll variables page).'")
parts.append(('P2-005', 'hrms_formula_check: names from payroll_variables (was a fixed list)', p))

# ---- slab check: 2 lists
p = block('hrms_component_slab_apply')
p = patch(p, BUILTIN_LIST, TO_FUNCTION, 2, regex=True)
parts.append(('P2-006', 'hrms_component_slab_apply: slab "based on" / "% of" from payroll_variables', p))

# ---- component save: reserved names, base list, eligibility
p = block('hrms_update_component_master')
p = patch(p, r"v_code IN \('CTC','CTC1',[^)]*\)",
          "(hrms_is_reserved_name(v_code) = 1\n"
          "                                   OR v_code IN ('ROUND','LEAST','GREATEST','IF','CEIL','FLOOR','ABS','AND','OR','NOT','NONE'))",
          1, regex=True)
p = patch(p, BUILTIN_LIST, TO_FUNCTION, 1, regex=True)
p = patch(p,
          "    IF v_msg IS NULL AND v_eparam IS NOT NULL AND v_eparam NOT IN ('EMPLOYEE_ESI_ELIGIBLE') THEN\n"
          "        SET v_msg = 'Eligibility must be empty or EMPLOYEE_ESI_ELIGIBLE.';\n"
          "    END IF;\n",
          "    -- P2: \"applies only when\" may use any active Yes/No payroll variable\n"
          "    IF v_eparam = 'EMPLOYEE_ESI_ELIGIBLE' THEN\n"
          "        SET v_eparam = 'ESI_APPLICABLE';\n"
          "    END IF;\n"
          "    IF v_msg IS NULL AND v_eparam IS NOT NULL\n"
          "       AND NOT EXISTS (SELECT 1 FROM payroll_variables\n"
          "                        WHERE var_code = v_eparam AND is_active = 1 AND data_type = 'FLAG') THEN\n"
          "        SET v_msg = CONCAT('\"Applies only when\" must be an active Yes/No payroll variable; ', v_eparam, ' is not one.');\n"
          "    END IF;\n")
parts.append(('P2-007', 'hrms_update_component_master: reserved names and bases from payroll_variables; '
              '"applies only when" accepts any Yes/No variable', p))

# ---- employee overrides: base list
p = block('hrms_update_employee_salary_component')
p = patch(p, BUILTIN_LIST, TO_FUNCTION, 1, regex=True)
parts.append(('P2-008', 'hrms_update_employee_salary_component: bases from payroll_variables', p))

p = block('hrms_save_employee_salary')
p = patch(p, BUILTIN_LIST, TO_FUNCTION, 1, regex=True)
p = patch(p, """'" is not CTC, CTC1, GROSS or a component code.'""",
          """'" is not a payroll variable or a component code.'""")
parts.append(('P2-009', 'hrms_save_employee_salary: bases from payroll_variables', p))

# ---- rule checker
p = block('hrms_component_rules_check')
p = patch(p, BUILTIN_LIST, TO_FUNCTION, 1, regex=True)
parts.append(('P2-010', 'hrms_component_rules_check: names from payroll_variables', p))

# ---- engine: generic "applies only when"
p = block('hrms_engine_run')
p = patch(p,
          "            ELSEIF TRIM(COALESCE(v_eparam, '')) <> ''\n"
          "               AND UPPER(v_eparam) IN ('EMPLOYEE_ESI_ELIGIBLE', 'ESI_APPLICABLE')\n"
          "               AND UPPER(v_esi) <> UPPER(COALESCE(NULLIF(TRIM(v_evalue), ''), 'Y')) THEN\n"
          "                SET v_new = 0;\n",
          "            -- P2: \"applies only when\" <Yes/No variable> = Y (or N); any variable, not only ESI\n"
          "            ELSEIF TRIM(COALESCE(v_eparam, '')) <> ''\n"
          "               AND (SELECT IF(UPPER(COALESCE(NULLIF(TRIM(v_evalue), ''), 'Y')) = 'N',\n"
          "                              COALESCE(MAX(fv.var_value), 0) <> 0,\n"
          "                              COALESCE(MAX(fv.var_value), 0) = 0)\n"
          "                      FROM tmp_hrms_formula_vars fv\n"
          "                     WHERE fv.var_code = IF(UPPER(TRIM(v_eparam)) = 'EMPLOYEE_ESI_ELIGIBLE', 'ESI_APPLICABLE',\n"
          "                                            UPPER(TRIM(v_eparam)))) = 1 THEN\n"
          "                SET v_new = 0;\n")
parts.append(('P2-004', 'hrms_engine_run: "applies only when" works for every Yes/No variable', p))

head = io.open('db_dumps/build/phase2_head.sql', encoding='utf-8').read()
tail = io.open('db_dumps/build/phase2_tail.sql', encoding='utf-8').read()

order = ['P2-004', 'P2-005', 'P2-006', 'P2-007', 'P2-008', 'P2-009', 'P2-010']
body = ''
for pid in order:
    item = [x for x in parts if x[0] == pid][0]
    body += ('\n-- ---------------------------------------------------------------------\n'
             '-- %s  %s\n'
             '--        (copied from script.sql and patched by db_dumps/build/build_phase2.py)\n'
             '-- ---------------------------------------------------------------------\n' % (item[0], item[1]))
    body += item[2] + '\n'

io.open(OUT, 'w', encoding='utf-8', newline='\n').write(head + body + tail)
print('written', OUT)
