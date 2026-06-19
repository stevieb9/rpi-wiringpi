#!/usr/bin/env python3
"""
Regenerate the docs/test-platform-updated visuals from the TEST-DERIVED model
(scripts/helpers/model-from-tests.py), reusing the existing renderers unchanged.

It injects the re-derived model into gen-schematic.py (by overwriting its
module-level data), runs the netlist / netlistsvg-JSON / schematic / pinout-image
generators in a scratch tree, optionally drives netlistsvg + gen-pdf.py if
`netlistsvg` is on PATH, then files every artifact into docs/test-platform-updated.

(KiCad projects are no longer generated here -- each board is scaffolded once by
gen-kicad.py and then hand-managed in KiCad; see docs/test-platform/kicad/.)

It also DIFFS the re-derived model against the in-repo gen-schematic.py model and
prints whether the independent derivation matches (it should -- the in-repo model
was itself built from these tests).

Run with the schematic venv interpreter (needs schemdraw/cairosvg/PIL/pypdf):
    <venv>/bin/python scripts/helpers/gen-updated-visuals.py
"""

import importlib.util
import os
import runpy
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'docs', 'test-platform-updated')
SVG = os.path.join(OUT, 'svg')
FACTS = os.path.join(OUT, 'facts')
BUILD = os.path.join(ROOT, '.build-test-platform-updated')
BUILD_T = os.path.join(BUILD, 't')

NLSVG_MAP = [
    ('test-platform.signals.nlsvg.json', 'test-pinout-schematic-signals.svg'),
    ('test-platform.nlsvg.json',         'test-pinout-schematic-wired.svg'),
    ('sheet-i2c.nlsvg.json',             'sheet-i2c.svg'),
    ('sheet-spi.nlsvg.json',             'sheet-spi.svg'),
    ('sheet-stepper.nlsvg.json',         'sheet-stepper.svg'),
    ('sheet-display.nlsvg.json',         'sheet-display.svg'),
]

def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

def canon_nets(nets):
    # order-independent comparison: {netname: frozenset of (ref,pin)}
    return {nm: frozenset(nodes) for nm, nodes in nets}

def diff_against_repo_model(M):
    G0 = load(os.path.join(HERE, 'gen-schematic.py'), 'gen_schematic_repo')
    comp_match = M.COMPONENTS == G0.COMPONENTS
    a, b = canon_nets(M.NETS), canon_nets(G0.NETS)
    net_match = a == b
    print('--- re-derived model vs in-repo gen-schematic.py model ---')
    print(f'  components: {"MATCH" if comp_match else "DIFFER"} '
          f'({len(M.COMPONENTS)} vs {len(G0.COMPONENTS)})')
    print(f'  nets:       {"MATCH" if net_match else "DIFFER"} '
          f'({len(M.NETS)} vs {len(G0.NETS)})')
    if not net_match:
        for nm in sorted(set(a) | set(b)):
            if a.get(nm) != b.get(nm):
                print(f'    net {nm}: derived={sorted(a.get(nm, []))} '
                      f'repo={sorted(b.get(nm, []))}')
    if not comp_match:
        for ref in sorted(set(M.COMPONENTS) | set(G0.COMPONENTS)):
            if M.COMPONENTS.get(ref) != G0.COMPONENTS.get(ref):
                print(f'    comp {ref}: derived={M.COMPONENTS.get(ref)} '
                      f'repo={G0.COMPONENTS.get(ref)}')
    return comp_match and net_match

def inject(mod, M):
    for attr in ('COMPONENTS', 'NETS', 'J1FUNC', 'DRIVER', 'POWER', 'SHEETS'):
        if hasattr(mod, attr) and hasattr(M, attr):
            setattr(mod, attr, getattr(M, attr))

def classify(name):
    if name.endswith('.nlsvg.json'):
        return None
    if name.endswith('.svg'):
        return SVG
    if name.endswith('.net'):
        return FACTS
    if name.endswith(('.jpg', '.pdf')):
        return OUT
    return OUT

def main():
    M = load(os.path.join(HERE, 'model-from-tests.py'), 'model_from_tests')
    matched = diff_against_repo_model(M)

    if os.path.isdir(BUILD):
        shutil.rmtree(BUILD)
    os.makedirs(BUILD_T)
    for d in (OUT, SVG, FACTS):
        os.makedirs(d, exist_ok=True)

    # gen-schematic: inject model, render in the scratch tree (uses relative t/).
    G = load(os.path.join(HERE, 'gen-schematic.py'), 'gen_schematic_inj')
    inject(G, M)
    os.chdir(BUILD)
    G.write_netlist('t/test-platform.net')
    G.write_nlsvg('t/test-platform.nlsvg.json')
    G.write_nlsvg('t/test-platform.signals.nlsvg.json',
                  exclude={'+5V', '+3V3', 'GND'}, power=True)
    for snm, keep in M.SHEETS.items():
        G.write_nlsvg(f't/sheet-{snm}.nlsvg.json', keep=keep, power=True)

    # pinout JPEGs: self-contained generator (encodes the same test-derived map).
    runpy.run_path(os.path.join(HERE, 'gen-pinout-images.py'), run_name='__main__')

    # netlistsvg + PDFs, if the tool is available.
    cli = shutil.which('netlistsvg')
    if cli:
        for js, svg in NLSVG_MAP:
            if os.path.isfile(os.path.join('t', js)):
                r = subprocess.run([cli, os.path.join('t', js), '-o', os.path.join('t', svg)],
                                   capture_output=True, text=True)
                if r.returncode != 0:
                    print(f'  WARN netlistsvg {js}: {(r.stderr or r.stdout).strip()}')
        try:
            runpy.run_path(os.path.join(HERE, 'gen-pdf.py'), run_name='__main__')
        except Exception as ex:
            print(f'  WARN gen-pdf.py skipped: {ex}')
    else:
        print('  netlistsvg not on PATH - skipping wire-routed SVGs and PDFs')

    # File artifacts into docs/test-platform-updated.
    moved = {'svg': 0, 'facts': 0, 'doc': 0, 'drop': 0}
    for name in sorted(os.listdir(BUILD_T)):
        src = os.path.join(BUILD_T, name)
        if not os.path.isfile(src):
            continue
        dest_dir = classify(name)
        if dest_dir is None:
            moved['drop'] += 1
            continue
        shutil.move(src, os.path.join(dest_dir, name))
        moved['svg' if dest_dir == SVG else 'facts' if dest_dir == FACTS
              else 'doc'] += 1

    os.chdir(ROOT)
    shutil.rmtree(BUILD)
    print(f'filed: {moved["doc"]} artifacts -> docs/test-platform-updated, '
          f'{moved["svg"]} svg, {moved["facts"]} netlist, '
          f'{moved["drop"]} intermediates dropped')

    print('re-derivation', 'MATCHES in-repo model' if matched else 'DIVERGES from in-repo model')

if __name__ == '__main__':
    main()
