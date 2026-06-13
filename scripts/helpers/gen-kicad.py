#!/usr/bin/env python3
"""
Emit an openable KiCad project for the RPi::WiringPi unit-test platform:
  t/test-platform.kicad_sch    -- flat schematic, net-label style (Eeschema)
  t/test-platform.kicad_pro    -- KiCad project file

Reuses the exact component/net model from gen-schematic.py (imported as a
module, no duplication). The schematic is "net-label style": every component is
drawn as a labelled box and each connected pin carries a local net label, so
KiCad resolves connectivity by net name -- no wire routing required. Symbol
definitions are embedded in lib_symbols, so the file opens stand-alone with no
external symbol libraries to install.

The PCB is intentionally left out: the breakout/module parts have no standard
KiCad footprints, so a generated .kicad_pcb would be guesswork. Open the
schematic, assign footprints, then create the board from there.

File format targets KiCad 7 (version 20230121); KiCad 8 opens it unchanged.
UUIDs are derived deterministically (uuid5) so re-running produces no git churn.

Normally invoked via scripts/gen-test-platform.pl. Stand-alone, from the repo
root:  python3 scripts/helpers/gen-kicad.py
"""

import importlib.util
import json
import os
import sys
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))

# Reuse the data model from gen-schematic.py (hyphen in the name blocks a plain
# import, so load it by path). Importing has no side effects by design.
def load_model():
    path = os.path.join(HERE, 'gen-schematic.py')
    spec = importlib.util.spec_from_file_location('gen_schematic', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

S = load_model()

PROJECT = 'test-platform'
# Fixed namespace so uuid5-derived ids are stable across runs (no git churn).
NS = uuid.UUID('5f3e9a10-7c2b-5d4e-8a1f-0b1c2d3e4f50')

# Geometry (millimetres). Pins sit on a 2.54 mm pitch; the symbol body is fixed
# width and its height grows with the taller pin column.
PITCH = 2.54
PIN_LEN = 5.08
BODY_W = 20.32
FONT = 1.27

def uid(*parts):
    return str(uuid.uuid5(NS, ':'.join(parts)))

ROOT_UUID = uid('root-sheet')

# net name per (ref, pin), from the shared model
PINNET = {}
for _nm, _nodes in S.NETS:
    for _ref, _pin in _nodes:
        PINNET[(_ref, _pin)] = _nm

def fnum(v):
    # Fixed 4-dp formatting keeps a pin tip and its label byte-identical, which
    # is how KiCad decides the label connects to the pin.
    return f'{v:.4f}'

def pin_name(ref, pin):
    if ref == 'J1':
        return S.J1FUNC[int(pin)]
    return S.COMPONENTS[ref][2][pin]

def split_pins(ref):
    """Return (left_pins, right_pins) as ordered lists of pin-number strings."""
    pins = list(S.COMPONENTS[ref][2].keys())
    if ref == 'J1':
        # Mirror the physical 2x20 header: odd pins left, even pins right.
        left = [p for p in pins if int(p) % 2 == 1]
        right = [p for p in pins if int(p) % 2 == 0]
    else:
        half = (len(pins) + 1) // 2
        left, right = pins[:half], pins[half:]
    return left, right

def pin_geom(ref):
    """Symbol-local pin tip coordinates (Y up) keyed by pin number.

    Returns {pin: (x, y, angle)} plus the body half-height.
    """
    left, right = split_pins(ref)
    rows = max(len(left), len(right), 1)
    half_h = (rows + 1) * PITCH / 2
    tip_x = BODY_W / 2 + PIN_LEN
    geom = {}
    for i, p in enumerate(left):
        y = half_h - PITCH * (i + 1)
        geom[p] = (-tip_x, y, 0)      # angle 0: tip on the left, body to the right
    for i, p in enumerate(right):
        y = half_h - PITCH * (i + 1)
        geom[p] = (tip_x, y, 180)     # angle 180: tip on the right, body to the left
    return geom, half_h

def lib_symbol(ref):
    val = S.COMPONENTS[ref][0]
    geom, half_h = pin_geom(ref)
    name_y = half_h + PITCH
    out = []
    out.append(f'    (symbol "{PROJECT}:{ref}"')
    out.append('      (pin_names (offset 1.016))')
    out.append('      (in_bom yes) (on_board yes)')
    out.append(f'      (property "Reference" "{ref}" (at 0 {fnum(name_y)} 0)')
    out.append(f'        (effects (font (size {FONT} {FONT}))))')
    out.append(f'      (property "Value" "{val}" (at 0 {fnum(-name_y)} 0)')
    out.append(f'        (effects (font (size {FONT} {FONT}))))')
    out.append('      (property "Footprint" "" (at 0 0 0)')
    out.append(f'        (effects (font (size {FONT} {FONT})) hide))')
    out.append('      (property "Datasheet" "" (at 0 0 0)')
    out.append(f'        (effects (font (size {FONT} {FONT})) hide))')
    # graphic body (unit 0, common to all units)
    out.append(f'      (symbol "{ref}_0_1"')
    out.append(f'        (rectangle (start {fnum(-BODY_W / 2)} {fnum(half_h)})'
               f' (end {fnum(BODY_W / 2)} {fnum(-half_h)})')
    out.append('          (stroke (width 0.254) (type default)) (fill (type background)))')
    out.append('      )')
    # pins (unit 1)
    out.append(f'      (symbol "{ref}_1_1"')
    for p in S.COMPONENTS[ref][2]:
        x, y, ang = geom[p]
        nm = pin_name(ref, p)
        out.append(f'        (pin passive line (at {fnum(x)} {fnum(y)} {ang}) (length {PIN_LEN})')
        out.append(f'          (name "{nm}" (effects (font (size {FONT} {FONT}))))')
        out.append(f'          (number "{p}" (effects (font (size {FONT} {FONT})))))')
    out.append('      )')
    out.append('    )')
    return '\n'.join(out)

def place_all():
    """Assign a schematic position to every component.

    J1 gets its own tall left lane; everything else flows top-to-bottom in
    columns to the right. Returns {ref: (sx, sy)} and the page extent.
    """
    refs = list(S.COMPONENTS.keys())
    margin = 25.0
    pos = {}

    # J1 lane.
    _, j1_half = pin_geom('J1')
    j1_x = margin + 45.0
    j1_y = margin + j1_half
    pos['J1'] = (j1_x, j1_y)
    max_bottom = j1_y + j1_half

    # Remaining parts in columns to the right of J1.
    col_x = j1_x + 110.0
    col_pitch = 100.0
    col_top = margin
    col_limit = max(max_bottom, 360.0)
    cur_x = col_x
    for ref in refs:
        if ref == 'J1':
            continue
        _, half = pin_geom(ref)
        if col_top + 2 * half > col_limit and col_top > margin:
            cur_x += col_pitch          # start a new column
            col_top = margin
        sy = col_top + half
        pos[ref] = (cur_x, sy)
        col_top = sy + half + 18.0
        max_bottom = max(max_bottom, sy + half)

    page_w = cur_x + 70.0
    page_h = max_bottom + margin
    return pos, page_w, page_h

def symbol_instance(ref, sx, sy):
    val = S.COMPONENTS[ref][0]
    _, half_h = pin_geom(ref)
    out = []
    out.append(f'  (symbol (lib_id "{PROJECT}:{ref}") (at {fnum(sx)} {fnum(sy)} 0) (unit 1)')
    out.append('    (in_bom yes) (on_board yes) (dnp no)')
    out.append(f'    (uuid {uid("sym", ref)})')
    out.append(f'    (property "Reference" "{ref}" (at {fnum(sx)} {fnum(sy - half_h - PITCH)} 0)')
    out.append(f'      (effects (font (size {FONT} {FONT}))))')
    out.append(f'    (property "Value" "{val}" (at {fnum(sx)} {fnum(sy + half_h + PITCH)} 0)')
    out.append(f'      (effects (font (size {FONT} {FONT}))))')
    out.append(f'    (property "Footprint" "" (at {fnum(sx)} {fnum(sy)} 0)')
    out.append(f'      (effects (font (size {FONT} {FONT})) hide))')
    out.append(f'    (property "Datasheet" "" (at {fnum(sx)} {fnum(sy)} 0)')
    out.append(f'      (effects (font (size {FONT} {FONT})) hide))')
    for p in S.COMPONENTS[ref][2]:
        out.append(f'    (pin "{p}" (uuid {uid("pin", ref, p)}))')
    out.append('    (instances')
    out.append(f'      (project "{PROJECT}"')
    out.append(f'        (path "/{ROOT_UUID}" (reference "{ref}") (unit 1))')
    out.append('      )')
    out.append('    )')
    out.append('  )')
    return '\n'.join(out)

def net_labels(ref, sx, sy):
    """A local net label at every connected pin tip (schematic coords, Y down)."""
    geom, _ = pin_geom(ref)
    out = []
    for p in S.COMPONENTS[ref][2]:
        net = PINNET.get((ref, p))
        if not net:
            continue
        lx, ly, ang = geom[p]
        # Placement (angle 0, no mirror) flips symbol Y: schem = (sx+lx, sy-ly).
        tx, ty = sx + lx, sy - ly
        just = 'right' if ang == 0 else 'left'   # text sits outboard of the pin
        out.append(f'  (label "{net}" (at {fnum(tx)} {fnum(ty)} 0)')
        out.append(f'    (effects (font (size {FONT} {FONT})) (justify {just}))')
        out.append(f'    (uuid {uid("lbl", ref, p)}))')
    return '\n'.join(out)

def write_schematic(path, pos, page_w, page_h):
    parts = []
    parts.append('(kicad_sch')
    parts.append('  (version 20230121)')
    parts.append('  (generator "rpi-wiringpi")')
    parts.append(f'  (uuid {ROOT_UUID})')
    parts.append(f'  (paper "User" {fnum(page_w)} {fnum(page_h)})')
    parts.append('  (lib_symbols')
    for ref in S.COMPONENTS:
        parts.append(lib_symbol(ref))
    parts.append('  )')
    for ref in S.COMPONENTS:
        sx, sy = pos[ref]
        parts.append(symbol_instance(ref, sx, sy))
    for ref in S.COMPONENTS:
        sx, sy = pos[ref]
        labels = net_labels(ref, sx, sy)
        if labels:
            parts.append(labels)
    parts.append('  (sheet_instances')
    parts.append('    (path "/" (page "1"))')
    parts.append('  )')
    parts.append(')')
    text = '\n'.join(parts) + '\n'
    with open(path, 'w') as fh:
        fh.write(text)
    return text

def write_project(path):
    doc = {
        'board': {'design_settings': {}, 'layer_presets': [], 'viewports': []},
        'boards': [],
        'cvpcb': {'equivalence_files': []},
        'libraries': {'pinned_footprint_libs': [], 'pinned_symbol_libs': []},
        'meta': {'filename': f'{PROJECT}.kicad_pro', 'version': 1},
        'net_settings': {
            'classes': [{
                'name': 'Default', 'clearance': 0.2, 'track_width': 0.25,
                'via_diameter': 0.8, 'via_drill': 0.4,
                'microvia_diameter': 0.3, 'microvia_drill': 0.1,
                'wire_width': 6, 'bus_width': 12, 'line_style': 0,
                'pcb_color': 'rgba(0, 0, 0, 0.000)',
                'schematic_color': 'rgba(0, 0, 0, 0.000)',
            }],
            'meta': {'version': 3},
        },
        'pcbnew': {'last_paths': {}, 'page_layout_descr_file': ''},
        'schematic': {'legacy_lib_dir': '', 'legacy_lib_list': []},
        'sheets': [[ROOT_UUID, '']],
        'text_variables': {},
    }
    with open(path, 'w') as fh:
        json.dump(doc, fh, indent=2)

def main():
    pos, page_w, page_h = place_all()
    sch = 't/test-platform.kicad_sch'
    pro = 't/test-platform.kicad_pro'
    try:
        write_schematic(sch, pos, page_w, page_h)
        write_project(pro)
    except OSError as e:
        sys.exit(f'failed writing KiCad project: {e}')
    n_lbl = sum(1 for r in S.COMPONENTS for p in S.COMPONENTS[r][2] if (r, p) in PINNET)
    print(f'wrote {sch} / {pro} - {len(S.COMPONENTS)} symbols, '
          f'{len(S.NETS)} nets, {n_lbl} net labels')

if __name__ == '__main__':
    main()
