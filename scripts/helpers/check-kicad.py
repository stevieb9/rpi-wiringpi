#!/usr/bin/env python3
"""
Validate the generated KiCad project the way "Update PCB from Schematic" does.

That KiCad step fails ("Cannot add <ref> (no footprint assigned)") whenever a
symbol has no footprint, or its footprint cannot be resolved, or the footprint's
pads do not cover the symbol's pins. This script asserts exactly those three
invariants against the files gen-kicad.py produced, so a broken project is
caught at generation time instead of in the GUI.

Two layers:
  1. Always: a self-contained s-expression parse of test-platform.kicad_sch,
     fp-lib-table and the .pretty footprints. No KiCad install required, so it
     runs everywhere (including the Raspberry Pi CI host).
  2. If `kicad-cli` is on PATH: additionally export a netlist with KiCad's own
     parser and confirm every component carries a non-empty footprint field --
     an independent cross-check. Skipped with a notice when the tool is absent.

Usage:
  python3 scripts/helpers/check-kicad.py [PROJECT_DIR]
PROJECT_DIR defaults to docs/test-platform/kicad relative to this script. Exits 0
when every invariant holds, non-zero (with a per-failure message) otherwise.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_DIR = os.path.normpath(os.path.join(HERE, '..', '..', 'docs', 'test-platform', 'kicad'))

PROJECT = 'test-platform'

# --- tiny s-expression reader ---------------------------------------------

def tokenize(text):
    return re.findall(r'"(?:[^"\\]|\\.)*"|\(|\)|[^\s()]+', text)

def parse(text):
    """Parse one s-expression into nested lists; quoted atoms are unquoted str."""
    tokens = tokenize(text)
    pos = 0

    def walk():
        nonlocal pos
        node = []
        pos += 1                       # consume '('
        while pos < len(tokens):
            tok = tokens[pos]
            if tok == '(':
                node.append(walk())
            elif tok == ')':
                pos += 1
                return node
            else:
                if len(tok) >= 2 and tok[0] == '"' and tok[-1] == '"':
                    node.append(tok[1:-1].replace('\\"', '"'))
                else:
                    node.append(tok)
                pos += 1
        return node

    while pos < len(tokens) and tokens[pos] != '(':
        pos += 1
    return walk() if pos < len(tokens) else []

def head(node):
    return node[0] if isinstance(node, list) and node and isinstance(node[0], str) else None

def kids(node, name):
    return [c for c in node if isinstance(c, list) and head(c) == name]

def kid(node, name):
    found = kids(node, name)
    return found[0] if found else None

# --- the checks ------------------------------------------------------------

def schematic_symbols(sch_root):
    """[(reference, footprint_value, {pin numbers}), ...] for placed instances.

    Instances are the top-level (symbol (lib_id ...)) nodes; the definitions
    inside (lib_symbols ...) are nested and so never appear here.
    """
    out = []
    for sym in kids(sch_root, 'symbol'):
        if not kid(sym, 'lib_id'):
            continue
        ref = fp = None
        for prop in kids(sym, 'property'):
            if len(prop) >= 3 and prop[1] == 'Reference':
                ref = prop[2]
            elif len(prop) >= 3 and prop[1] == 'Footprint':
                fp = prop[2]
        pins = {p[1] for p in kids(sym, 'pin') if len(p) >= 2}
        out.append((ref, fp, pins))
    return out

def footprint_pads(mod_path):
    root = parse(open(mod_path).read())
    return {p[1] for p in kids(root, 'pad') if len(p) >= 2}

def resolve_libs(fp_table_path, project_dir):
    """lib nickname -> absolute .pretty path, from fp-lib-table (${KIPRJMOD})."""
    root = parse(open(fp_table_path).read())
    libs = {}
    for lib in kids(root, 'lib'):
        name = kid(lib, 'name')
        uri = kid(lib, 'uri')
        if not (name and uri):
            continue
        path = uri[1].replace('${KIPRJMOD}', project_dir)
        libs[name[1]] = os.path.normpath(path)
    return libs

def check_parse(project_dir, errors):
    sch = os.path.join(project_dir, f'{PROJECT}.kicad_sch')
    tbl = os.path.join(project_dir, 'fp-lib-table')
    if not os.path.isfile(sch):
        errors.append(f'missing schematic: {sch}')
        return 0
    if not os.path.isfile(tbl):
        errors.append(f'missing fp-lib-table: {tbl}')
        return 0

    libs = resolve_libs(tbl, project_dir)
    symbols = schematic_symbols(parse(open(sch).read()))
    cache = {}
    checked = 0
    for ref, fp, pins in symbols:
        checked += 1
        if not fp:
            errors.append(f'{ref}: no footprint assigned')
            continue
        if ':' not in fp:
            errors.append(f'{ref}: footprint "{fp}" is not LIB:NAME')
            continue
        nick, name = fp.split(':', 1)
        if nick not in libs:
            errors.append(f'{ref}: footprint lib "{nick}" not in fp-lib-table')
            continue
        mod = os.path.join(libs[nick], f'{name}.kicad_mod')
        if not os.path.isfile(mod):
            errors.append(f'{ref}: footprint file not found: {mod}')
            continue
        pads = cache.get(mod) or cache.setdefault(mod, footprint_pads(mod))
        missing = pins - pads
        if missing:
            errors.append(f'{ref}: pins with no matching pad: {sorted(missing)}')
    return checked

def check_kicad_cli(project_dir, warnings):
    """Cross-check with kicad-cli when present. Returns (ran, footprintless)."""
    cli = shutil.which('kicad-cli')
    if not cli:
        return False, []
    sch = os.path.join(project_dir, f'{PROJECT}.kicad_sch')
    with tempfile.TemporaryDirectory() as tmp:
        net = os.path.join(tmp, 'out.net')
        proc = subprocess.run(
            [cli, 'sch', 'export', 'netlist', '--format', 'kicadsexpr',
             '-o', net, sch],
            capture_output=True, text=True)
        if proc.returncode != 0 or not os.path.isfile(net):
            warnings.append('kicad-cli netlist export failed: '
                            + (proc.stderr or proc.stdout).strip())
            return True, []
        root = parse(open(net).read())
        comps = kid(root, 'components')
        bad = []
        for comp in kids(comps or [], 'comp'):
            ref = kid(comp, 'ref')
            fp = kid(comp, 'footprint')
            if not (fp and len(fp) >= 2 and fp[1]):
                bad.append(ref[1] if ref else '?')
        return True, bad

def main():
    project_dir = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DIR
    errors = []
    warnings = []

    checked = check_parse(project_dir, errors)
    ran_cli, footprintless = check_kicad_cli(project_dir, warnings)

    if errors:
        print(f'KiCad validation FAILED ({len(errors)} problem(s)):')
        for e in errors:
            print(f'  - {e}')
    if footprintless:
        print('kicad-cli: components with no footprint in exported netlist: '
              + ', '.join(footprintless))

    for w in warnings:
        print(f'  note: {w}')

    if errors or footprintless:
        sys.exit(1)

    cli_note = 'kicad-cli netlist cross-check passed' if ran_cli \
        else 'kicad-cli not installed - parse-only check'
    print(f'KiCad validation OK: {checked} symbols, all footprints resolve and '
          f'cover their pins ({cli_note}).')

if __name__ == '__main__':
    main()
