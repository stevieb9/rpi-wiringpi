#!/usr/bin/env python3
"""
Schematic renderer for the RPi::WiringPi unit-test platform. The data model
itself lives in board-model.py (loaded at the top); this emits:
  t/test-platform.net    -- KiCad-importable netlist (every connection)
  t/*.nlsvg.json         -- netlistsvg inputs for the wire-routed sheets + PDF
Normally invoked via scripts/gen-test-platform.pl; to run standalone, from the
repo root with the schematic venv:
  /tmp/sch-venv/bin/python scripts/helpers/gen-schematic.py
"""

import sys

# ------------------------------------------------------------------ MODEL
# The data model is the single source of truth in board-model.py. Load it by
# path (the hyphen blocks a plain import) and expose its tables as our module
# globals, so the renderers below are unchanged. gen-updated-visuals.py may
# still override these (inject) with the test-derived model for the drift diff.
import importlib.util as _ilu
import os as _os

def _load_board_model():
    p = _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), 'board-model.py')
    spec = _ilu.spec_from_file_location('board_model', p)
    m = _ilu.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

_BM = _load_board_model()
COMPONENTS = _BM.COMPONENTS
NETS = _BM.NETS
J1FUNC = _BM.J1FUNC
DRIVER = _BM.DRIVER
POWER = _BM.POWER
SHEETS = _BM.SHEETS

# ------------------------------------------------------------------ NETLIST
def write_netlist(path='t/test-platform.net'):
    lines = ['(export (version "E")', '  (design (source "gen-schematic.py") (date "") (tool "rpi-wiringpi"))',
             '  (components']
    for ref,(val,fp,pins) in COMPONENTS.items():
        lines.append(f'    (comp (ref "{ref}") (value "{val}") (footprint "{fp}"))')
    lines.append('  )')
    lines.append('  (nets')
    for i,(nm,nodes) in enumerate(NETS, 1):
        lines.append(f'    (net (code "{i}") (name "{nm}")')
        for ref,pin in nodes:
            lines.append(f'      (node (ref "{ref}") (pin "{pin}"))')
        lines.append('    )')
    lines.append('  )')
    lines.append(')')
    try:
        with open(path, 'w') as fh:
            fh.write('\n'.join(lines)+'\n')
    except OSError as e:
        sys.exit(f'failed writing {path}: {e}')
    print('wrote', path, '-', len(COMPONENTS), 'components,', len(NETS), 'nets')

# ------------------------------------------------------------------ netlistsvg JSON (for wire-routed render)
# J1FUNC / DRIVER / POWER now come from board-model.py (loaded at the top).

def write_nlsvg(path='t/test-platform.nlsvg.json', exclude=(), keep=None, power=False):
    import json
    if keep is not None:
        nets = [(nm,nodes) for nm,nodes in NETS if nm in keep]
    else:
        nets = [(nm,nodes) for nm,nodes in NETS if nm not in exclude]
    netbit = {nm:i+2 for i,(nm,_) in enumerate(nets)}
    outs = {}
    for nm,nodes in nets:
        spec = DRIVER.get(nm)
        for ref,pin in nodes:
            o=False
            if spec and '*' in spec: o = (spec==f'{ref}*{pin}')
            elif spec: o = (ref==spec)
            outs[(ref,pin)] = o
    pinnet_local = {}
    for nm,nodes in nets:
        for ref,pin in nodes: pinnet_local[(ref,pin)] = nm
    cells = {}
    for ref,(val,fp,pins) in COMPONENTS.items():
        ports_dir, conns = {}, {}
        for pin in pins:
            if (ref,pin) not in pinnet_local: continue
            base = (f'{pin}:{J1FUNC[int(pin)]}' if ref=='J1' else pins[pin])
            name = base; k=2
            while name in conns: name=f'{base}#{k}'; k+=1
            conns[name] = [netbit[pinnet_local[(ref,pin)]]]
            ports_dir[name] = 'output' if outs[(ref,pin)] else 'input'
        if conns:
            cells[ref] = {'type': f'{ref} {val}', 'port_directions':ports_dir,
                          'connections':conns, 'attributes':{}}
    netnames = {nm:{'bits':[netbit[nm]],'hide_name':0} for nm,_ in nets}
    if power:                       # add a +3V3/+5V/GND flag at each device pin
        nb = max(netbit.values(), default=1) + 1
        for ref in list(cells):
            for pin,rail in POWER.get(ref,[]):
                pname = COMPONENTS[ref][2].get(pin, pin)
                nm2, k = pname, 2
                while nm2 in cells[ref]['connections']: nm2=f'{pname}#{k}'; k+=1
                cells[ref]['connections'][nm2]=[nb]
                cells[ref]['port_directions'][nm2]='input'
                rtype={'+3V3':'PWR_3V3','+5V':'PWR_5V','GND':'PWR_GND'}[rail]
                cells[f'PF_{ref}_{pin}']={'type':rtype,'port_directions':{'P':'output'},
                                          'connections':{'P':[nb]},'attributes':{}}
                nb+=1
    doc = {'modules':{'test_platform':{'ports':{},'cells':cells,'netnames':netnames}}}
    try:
        with open(path, 'w') as fh:
            fh.write(json.dumps(doc,indent=1))
    except OSError as e:
        sys.exit(f'failed writing {path}: {e}')
    print('wrote', path, '-', len(cells), 'cells,', len(nets), 'nets')

# per-subsystem sheets (cleaner reads)
# SHEETS now comes from board-model.py (loaded at the top).

# The net-label schematic (schemdraw) renderer was removed: the wire-routed
# netlistsvg sheets -> multi-page PDF are the schematic deliverable. The
# *.nlsvg.json emitted above are netlistsvg's inputs for those sheets.

# Importing this module yields only the data model (COMPONENTS / NETS / J1FUNC /
# DRIVER / POWER / SHEETS) and the writer functions, with no side effects, so
# gen-kicad.py can reuse the model. Running it as a script emits every artifact.
if __name__ == '__main__':
    write_netlist()
    write_nlsvg()  # full (power routed)
    write_nlsvg('t/test-platform.signals.nlsvg.json', exclude={'+5V','+3V3','GND'}, power=True)  # signals + power flags
    for snm, keep in SHEETS.items():
        write_nlsvg(f't/sheet-{snm}.nlsvg.json', keep=keep, power=True)
