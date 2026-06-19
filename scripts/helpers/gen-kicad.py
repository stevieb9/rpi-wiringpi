#!/usr/bin/env python3
"""
Scaffold a stand-alone, openable KiCad project for an RPi::WiringPi unit-test
platform board. This is a ONE-SHOT generator: it writes a complete starting
project into a target directory, then refuses to touch it again -- each board is
hand-managed in KiCad after scaffolding (it is NOT part of the every-run regen).

  python3 scripts/helpers/gen-kicad.py <output-project-dir> [project-name] [--model PATH]

writes, with <project> defaulting to the directory's basename and the board model
defaulting to board-model.py (--model selects a per-board model file):
  <dir>/<project>.kicad_sch    -- flat schematic, net-label style (Eeschema)
  <dir>/<project>.kicad_pro    -- KiCad project file
  <dir>/fp-lib-table           -- registers the project-local footprint library
  <dir>/<project>.pretty/      -- one .kicad_mod footprint per symbol

If any of those already exist the tool exits without writing, so a hand-finalized
board is never clobbered by a re-run.

Reuses the exact component/net model from board-model.py (imported as a
module, no duplication). The schematic is "net-label style": every component is
drawn as a labelled box and each connected pin carries a local net label, so
KiCad resolves connectivity by net name -- no wire routing required. Symbol
definitions are embedded in lib_symbols, so the file opens stand-alone with no
external symbol libraries to install.

Every symbol is assigned a footprint from the generated, project-local
test-platform.pretty library so that "Update PCB from Schematic" transfers all
parts with zero errors. Each footprint is a plain 2.54 mm through-hole header
whose pads carry the symbol's exact pin identifiers (numbers like "9" or names
like "SCL") -- that pad/pin correspondence is what makes the transfer clean.
The breakout/module parts have no standard KiCad footprint that matches their
named pins, so generating matching strips is the only way to a 0-error board;
they are honest stand-ins (these parts really are header strips on jumpers),
not true package outlines. Laying out the board itself is left to the user.

Keeping the footprint library in-repo (rather than referencing KiCad's stock
libraries) preserves the same stand-alone, deterministic property as the
embedded symbols: the project opens and transfers identically on any host,
independent of which KiCad footprint libs happen to be installed.

File format targets KiCad 7 (version 20230121); KiCad 8 opens it unchanged.
UUIDs are derived deterministically (uuid5, namespaced per project) so a given
board always scaffolds identically.
"""

import importlib.util
import json
import os
import sys
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))

# The data model lives in a board-model file (the single source of truth). The
# hyphen blocks a plain import, so load it by path. No side effects. The default
# is the whole-board board-model.py; a per-board model is selected with --model.
DEFAULT_MODEL = os.path.join(HERE, 'board-model.py')

def load_model(path):
    spec = importlib.util.spec_from_file_location('board_model', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

S = load_model(DEFAULT_MODEL)

# Project (board) name; set per-run from argv in main(). Used in symbol lib_ids,
# footprint refs, the fp-lib-table nickname and the output filenames.
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
    # Namespace every id under the project name so distinct boards never share
    # UUIDs, while a given board always scaffolds identically.
    return str(uuid.uuid5(NS, ':'.join((PROJECT, *parts))))

# Set per-run in main(), once PROJECT is known.
ROOT_UUID = None

def build_pinnet(model):
    # net name per (ref, pin), from the model
    pinnet = {}
    for nm, nodes in model.NETS:
        for ref, pin in nodes:
            pinnet[(ref, pin)] = nm
    return pinnet

PINNET = build_pinnet(S)

def fnum(v):
    # Fixed 4-dp formatting keeps a pin tip and its label byte-identical, which
    # is how KiCad decides the label connects to the pin.
    return f'{v:.4f}'

def is_pi_header(ref):
    # The Raspberry Pi 2x20 header gets header-specific pin naming/placement;
    # recognise it by its footprint hint so the tool stays board-agnostic (a
    # satellite board has no Pi header and reuses J* refs for its connectors).
    return S.COMPONENTS[ref][1] == 'PinHeader_2x20'

def pi_header_ref():
    """The board's Pi-header ref, or None if the board has no Pi header."""
    for ref in S.COMPONENTS:
        if is_pi_header(ref):
            return ref
    return None

def pin_name(ref, pin):
    if is_pi_header(ref):
        return S.J1FUNC[int(pin)]
    return S.COMPONENTS[ref][2][pin]

def split_pins(ref):
    """Return (left_pins, right_pins) as ordered lists of pin-number strings."""
    pins = list(S.COMPONENTS[ref][2].keys())
    if is_pi_header(ref):
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
    out.append(f'      (property "Footprint" "{PROJECT}:{ref}" (at 0 0 0)')
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

    A Pi header (if the board has one) gets its own tall left lane; everything
    else flows top-to-bottom in columns to the right. A board with no Pi header
    just flows all parts in columns from the left margin. Returns {ref: (sx, sy)}
    and the page extent.
    """
    refs = list(S.COMPONENTS.keys())
    margin = 25.0
    pos = {}
    hub = pi_header_ref()

    if hub is not None:
        # Pi-header lane down the left; columns start to its right.
        _, hub_half = pin_geom(hub)
        hub_x = margin + 45.0
        hub_y = margin + hub_half
        pos[hub] = (hub_x, hub_y)
        max_bottom = hub_y + hub_half
        col_x = hub_x + 110.0
    else:
        max_bottom = margin
        col_x = margin + 45.0

    # Remaining parts in columns.
    col_pitch = 100.0
    col_top = margin
    col_limit = max(max_bottom, 360.0)
    cur_x = col_x
    for ref in refs:
        if ref == hub:
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
    out.append(f'    (property "Footprint" "{PROJECT}:{ref}" (at {fnum(sx)} {fnum(sy)} 0)')
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

# Footprint geometry (mm): a plain 2.54 mm through-hole header. Each pad carries
# the symbol's exact pin identifier so "Update PCB from Schematic" maps every pin
# to a pad with zero errors. These are generic strips, NOT true package outlines
# -- the test platform is breakout modules on jumpers, so there is no real board
# to be faithful to.
FP_PITCH = 2.54
FP_PAD = 1.7
FP_DRILL = 1.0
DIP_WIDTH = 7.62               # 0.3" row spacing for the IC (DIP) footprints
FP_VERSION = 20221018          # KiCad 7 footprint format

def pad_layout(ref):
    """Pad placement as [(pad_name, x, y), ...] in millimetres.

    Three shapes:
      Pi header -- a physical 2x20 header (pins 1/2 adjacent, odd/even columns).
      U*        -- a DIP IC: pads run down the left side and back up the right,
              placed by the part's real package pin numbers so the two rows
              mirror the physical chip (gaps where a pin number is unused).
      rest -- a single-row strip (connectors, modules, LEDs, resistors, switches).
    """
    pins = list(S.COMPONENTS[ref][2].keys())
    out = []
    if is_pi_header(ref):
        for p in pins:
            n = int(p)
            out.append((p, (n - 1) % 2 * FP_PITCH, (n - 1) // 2 * FP_PITCH))
    elif ref.startswith('U'):
        maxpin = max(int(p) for p in pins)
        half = maxpin // 2          # pins 1..half on the left, rest on the right
        for p in pins:
            n = int(p)
            if n <= half:
                out.append((p, 0.0, (n - 1) * FP_PITCH))
            else:
                out.append((p, DIP_WIDTH, (maxpin - n) * FP_PITCH))
    else:
        for i, p in enumerate(pins):
            out.append((p, 0.0, i * FP_PITCH))
    return out

def footprint(ref):
    val = S.COMPONENTS[ref][0]
    pads = pad_layout(ref)
    xs = [x for _, x, _ in pads]
    ys = [y for _, _, y in pads]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    cx = (minx + maxx) / 2         # body centre, for the silk/fab text
    silk = FP_PAD / 2 + 0.3        # outline margin past the pad edge
    crt = FP_PAD / 2 + 0.7         # courtyard margin
    pad1 = '1' if any(n == '1' for n, _, _ in pads) else pads[0][0]
    out = []
    out.append(f'(footprint "{ref}"')
    out.append(f'  (version {FP_VERSION})')
    out.append('  (generator "rpi-wiringpi")')
    out.append('  (layer "F.Cu")')
    out.append('  (descr "Auto-generated 2.54mm through-hole footprint for the '
               'RPi::WiringPi test platform; pads mirror the schematic pins. '
               'Generic outline, not a true package.")')
    out.append('  (attr through_hole)')
    out.append(f'  (fp_text reference "{ref}" '
               f'(at {fnum(cx)} {fnum(miny - silk - 1.0)} 0) (layer "F.SilkS")')
    out.append(f'    (effects (font (size {FONT} {FONT}) (thickness 0.15))))')
    out.append(f'  (fp_text value "{val}" '
               f'(at {fnum(cx)} {fnum(maxy + silk + 1.0)} 0) (layer "F.Fab")')
    out.append(f'    (effects (font (size {FONT} {FONT}) (thickness 0.15))))')
    out.append(f'  (fp_rect (start {fnum(minx - silk)} {fnum(miny - silk)}) '
               f'(end {fnum(maxx + silk)} {fnum(maxy + silk)})')
    out.append('    (stroke (width 0.12) (type solid)) (fill none) (layer "F.SilkS"))')
    out.append(f'  (fp_rect (start {fnum(minx - crt)} {fnum(miny - crt)}) '
               f'(end {fnum(maxx + crt)} {fnum(maxy + crt)})')
    out.append('    (stroke (width 0.05) (type solid)) (fill none) (layer "F.CrtYd"))')
    for name, x, y in pads:
        shape = 'rect' if name == pad1 else 'circle'   # square pad marks pin 1
        out.append(f'  (pad "{name}" thru_hole {shape} (at {fnum(x)} {fnum(y)}) '
                   f'(size {FP_PAD} {FP_PAD}) (drill {FP_DRILL}) '
                   '(layers "*.Cu" "*.Mask"))')
    out.append(')')
    return '\n'.join(out) + '\n'

def write_footprints(dirpath):
    os.makedirs(dirpath, exist_ok=True)
    for ref in S.COMPONENTS:
        with open(os.path.join(dirpath, f'{ref}.kicad_mod'), 'w') as fh:
            fh.write(footprint(ref))

def write_fp_lib_table(path):
    # Project-local footprint table; ${KIPRJMOD} resolves to the .kicad_pro dir.
    text = (
        '(fp_lib_table\n'
        '  (version 7)\n'
        f'  (lib (name "{PROJECT}")(type "KiCad")'
        f'(uri "${{KIPRJMOD}}/{PROJECT}.pretty")(options "")'
        '(descr "RPi::WiringPi test-platform footprints"))\n'
        ')\n'
    )
    with open(path, 'w') as fh:
        fh.write(text)

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

def main(argv=None):
    global PROJECT, ROOT_UUID, S, PINNET
    argv = list(sys.argv[1:] if argv is None else argv)

    # Optional --model PATH selects the board model file (default: the
    # whole-board board-model.py). Each board has its own model.
    model_path = DEFAULT_MODEL
    if '--model' in argv:
        i = argv.index('--model')
        if i + 1 >= len(argv):
            sys.exit('--model requires a path argument')
        model_path = os.path.abspath(argv[i + 1])
        del argv[i:i + 2]

    if not argv:
        sys.exit(
            'usage: gen-kicad.py <output-project-dir> [project-name] [--model PATH]\n'
            '  Scaffold a stand-alone KiCad project (schematic + project file +\n'
            '  footprint library) into <output-project-dir>. project-name\n'
            "  defaults to the directory's basename; --model selects the board\n"
            '  model (default board-model.py). Refuses to overwrite an existing\n'
            '  project -- boards are scaffolded once, then hand-managed.')

    S = load_model(model_path)
    PINNET = build_pinnet(S)

    outdir = os.path.abspath(argv[0])
    PROJECT = argv[1] if len(argv) > 1 else os.path.basename(outdir.rstrip(os.sep))
    if not PROJECT:
        sys.exit('cannot determine a project name from the output directory')
    ROOT_UUID = uid('root-sheet')

    sch = os.path.join(outdir, f'{PROJECT}.kicad_sch')
    pro = os.path.join(outdir, f'{PROJECT}.kicad_pro')
    fptbl = os.path.join(outdir, 'fp-lib-table')
    fpdir = os.path.join(outdir, f'{PROJECT}.pretty')

    # One-shot: never clobber a project that may already be hand-finalized.
    existing = [p for p in (sch, pro, fptbl, fpdir) if os.path.exists(p)]
    if existing:
        sys.exit('refusing to overwrite existing project files:\n  '
                 + '\n  '.join(existing))

    try:
        os.makedirs(outdir, exist_ok=True)
        pos, page_w, page_h = place_all()
        write_schematic(sch, pos, page_w, page_h)
        write_project(pro)
        write_fp_lib_table(fptbl)
        write_footprints(fpdir)
    except OSError as e:
        sys.exit(f'failed writing KiCad project: {e}')
    n_lbl = sum(1 for r in S.COMPONENTS for p in S.COMPONENTS[r][2] if (r, p) in PINNET)
    print(f'scaffolded {PROJECT} -> {outdir}: {len(S.COMPONENTS)} symbols, '
          f'{len(S.NETS)} nets, {n_lbl} net labels, '
          f'{len(S.COMPONENTS)} footprints')

if __name__ == '__main__':
    main()
