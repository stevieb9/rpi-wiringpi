#!/usr/bin/env python3
"""
Full electrical model of the RPi::WiringPi unit-test platform.
Emits:
  t/test-platform.net          -- KiCad-importable netlist (every connection)
  t/test-pinout-schematic.svg  -- rendered schematic (net-label style)
  t/test-pinout-schematic.jpg
Pinouts are datasheet-verified (see comments).  Normally invoked via
scripts/gen-test-platform.pl; to run standalone, from the repo root with the
schematic venv:  /tmp/sch-venv/bin/python scripts/helpers/gen-schematic.py
Style: bare ICs for logic (74HC595/MCP3008/MCP4922/MCP42010/MCP23017), module
blocks for sensor breakouts + level-shifter + stepper driver board.
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

# ------------------------------------------------------------------ SCHEMATIC (schemdraw, net-label style)
def render_schematic():
  try:
    import schemdraw, schemdraw.elements as e
    schemdraw.config(fontsize=10)
    # net name per (ref,pin)
    pinnet = {}
    for nm,nodes in NETS:
        for ref,pin in nodes: pinnet[(ref,pin)] = nm

    def ic_pins(ref, layout):
        """layout: {side: [pin,...]} -> list of IcPin with net label as name."""
        out=[]
        for side,pins in layout.items():
            for pin in pins:
                net = pinnet.get((ref,pin),'')
                nm = COMPONENTS[ref][2][pin]
                lbl = f'{nm}' + (f'  [{net}]' if net else '')
                out.append(e.IcPin(name=lbl, pin=pin, side=side))
        return out

    LAYOUT = {
     'U1':{'L':['12','13','18','9','10'],'R':['21','22','23','24','25','26','27','28'],'B':['5','6','7','8'],'T':['15','16','17']},
     'U6':{'L':['12','13','18','9','10'],'R':['21','22','23','24','25','26','27','28'],'B':['5','6','7','8'],'T':['15','16','17']},
     'U2':{'L':['14','11','12','13','10','16','8'],'R':['15','1','9']},
     'U3':{'L':['11','12','13','10','16','15','9','14'],'R':['1','2','3','4']},
     'U4':{'L':['3','4','5','1','8','9'],'R':['14','13','10','11','12']},
     'U5':{'L':['1','2','3','8','4','11','10'],'R':['13','12','14']},
    }
    MODL = {
     'M1':{'L':['VDD','GND','SCL','SDA','ADDR'],'R':['A0','A1']},
     'M3':{'L':['VCC','GND','SCL','SDA']},'M4':{'L':['VIN','GND','SCL','SDA']},
     'M5':{'L':['VCC','GND','SCL','SDA']},
     'M6':{'L':['LV','GND1','LV1','LV2'],'R':['HV','GND2','HV1','HV2']},
     'M7':{'L':['IN1','IN2','IN3','IN4','V+','GND']},
     'M8':{'L':['4','6','11','12','13','14','3','15','2','1','5','16']},
     'A1':{'L':['SDA','SCL','5V','GND']},'SV1':{'L':['SIG','V+','GND']},
    }
    # grid placement
    import math
    with schemdraw.Drawing(file='t/test-pinout-schematic.svg', show=False) as d:
        d.config(fontsize=9)
        d += e.Label().label('RPi::WiringPi unit-test platform — schematic', fontsize=20).at((30, 11))
        d += e.Label().label('net-label style: each pin tagged [NET]; trace connections by net name. Full wire-by-wire list: t/test-platform.net',
                             fontsize=11).at((30, 9))
        # J1 in its own far-left lane, full height
        jpins=[e.IcPin(name=f'{p}:{COMPONENTS["J1"][2][p]}'+(f' [{pinnet[("J1",p)]}]' if (("J1",p) in pinnet) else ' [-]'),
                       pin=p, side=('L' if int(p)%2 else 'R')) for p in (str(i) for i in range(1,41))]
        d += e.Ic(pins=jpins, w=6, h=34, pinspacing=1.6).at((-2, -19)).label('J1  Raspberry Pi 40-pin (J8)', loc='top', fontsize=11)
        # the rest in a 3-column grid to the right of J1
        order = ['U1','U6','U2','U3','U4','U5','M1','M3','M4','M5','M6','M7','M8','A1','SV1']
        cols, x0, dx, dy = 3, 12, 11.0, -12.0
        for idx,ref in enumerate(order):
            r,c = divmod(idx, cols)
            x,y = x0 + c*dx, 0 + r*dy
            lay = LAYOUT.get(ref) or MODL[ref]
            npins = sum(len(v) for v in lay.values())
            h = max(5.5, 0.95*max(len(lay.get('L',[])), len(lay.get('R',[]))))
            d += e.Ic(pins=ic_pins(ref,lay), w=4.2, h=h, pinspacing=1.0).at((x,y)).label(f'{ref}  {COMPONENTS[ref][0]}', loc='top', fontsize=10)
        d.save('t/test-pinout-schematic.svg')
    # schemdraw's SVG backend cannot save raster; render the JPG from the SVG.
    import cairosvg, io
    from PIL import Image
    png = cairosvg.svg2png(url='t/test-pinout-schematic.svg', dpi=120)
    img = Image.open(io.BytesIO(png)).convert('RGBA')
    bg = Image.new('RGB', img.size, 'white')
    bg.paste(img, mask=img.split()[3])
    bg.save('t/test-pinout-schematic.jpg', quality=90)
    print('wrote t/test-pinout-schematic.svg / .jpg')
  except Exception as ex:
    import traceback; traceback.print_exc()
    print('schematic render skipped:', ex)

# Importing this module yields only the data model (COMPONENTS / NETS / J1FUNC /
# DRIVER / POWER / SHEETS) and the writer functions, with no side effects, so
# gen-kicad.py can reuse the model. Running it as a script emits every artifact.
if __name__ == '__main__':
    write_netlist()
    write_nlsvg()  # full (power routed)
    write_nlsvg('t/test-platform.signals.nlsvg.json', exclude={'+5V','+3V3','GND'}, power=True)  # signals + power flags
    for snm, keep in SHEETS.items():
        write_nlsvg(f't/sheet-{snm}.nlsvg.json', keep=keep, power=True)
    render_schematic()
