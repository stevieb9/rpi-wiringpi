#!/usr/bin/env python3
"""
render-doc.py - render docs/test-platform/test-pinout-doc.md from its template.

The pin doc is mostly hand-authored prose and ASCII art - its value is the
curation, and most sections carry hand-added annotations that are not in any
machine model. So this is a TEMPLATE renderer, not a doc generator:
test-pinout-doc.tmpl.md holds all of that prose verbatim, with {{placeholder}}
markers only where a block can be generated losslessly from a single source of
truth. A generated block cannot drift from its source.

Generated blocks:
  {{default_states_pi5}}  the Pi 5 / RP1 expected default pin states (BCM/alt/
                          state), parsed from t/RPiTest.pm's $pi5 hash. [sec 12]

To add a block later: write a gen_*() function and register it in PLACEHOLDERS.
Sections like the master GPIO map and the rail tables also carry hand notes that
are not in board-model.py; generating those would mean modelling those notes
first.
"""

import importlib.util
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
TEMPLATE = os.path.join(ROOT, 'docs', 'test-platform', 'test-pinout-doc.tmpl.md')
OUTPUT = os.path.join(ROOT, 'docs', 'test-platform', 'test-pinout-doc.md')
BUSMAP = os.path.join(ROOT, 'docs', 'test-platform', 'facts', 'bus-map.json')
FAQ_POD = os.path.join(ROOT, 'lib', 'RPi', 'WiringPi', 'FAQ.pod')
ADDED_HW = os.path.join(ROOT, 'docs', 'test-platform', 'added-hardware.txt')
RPITEST = os.path.join(ROOT, 't', 'RPiTest.pm')


def _load(filename):
    """Load a hyphenated helper module by path (a plain import can't)."""
    path = os.path.join(HERE, filename)
    spec = importlib.util.spec_from_file_location(filename[:-3].replace('-', '_'), path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _parse_pi5():
    """Extract the $pi5 default-pin-config hash from t/RPiTest.pm."""
    text = open(RPITEST).read()
    block = re.search(r'my \$pi5 = \{(.*?)\n\s*\};', text, re.S)
    if not block:
        raise SystemExit('render-doc: could not locate $pi5 in t/RPiTest.pm')
    pins = {}
    for e in re.finditer(
            r"'(\d+)'\s*=>\s*\{\s*'alt'\s*=>\s*(\d+)\s*,"
            r"\s*'state'\s*=>\s*(\d+|undef)",
            block.group(1)):
        bcm = int(e.group(1))
        state = e.group(3)
        pins[bcm] = (e.group(2), '*undef*' if state == 'undef' else state)
    if not pins:
        raise SystemExit('render-doc: parsed no pins from $pi5')
    return pins


def gen_default_states_pi5():
    pins = _parse_pi5()
    order = sorted(pins)
    ncols = 3
    rows = math.ceil(len(order) / ncols)
    cols = [order[i * rows:(i + 1) * rows] for i in range(ncols)]

    head = '|' + '| |'.join([' BCM | alt | state '] * ncols) + '|'
    sep = '|' + '| |'.join(['----:|----:|------:'] * ncols) + '|'
    lines = [head, sep]
    for r in range(rows):
        cells = []
        for c in range(ncols):
            if r < len(cols[c]):
                bcm = cols[c][r]
                alt, state = pins[bcm]
                cells.append(f' {bcm} | {alt} | {state} ')
            else:
                cells.append('   |   |   ')
        lines.append('|' + '| |'.join(cells) + '|')
    return '\n'.join(lines)


def build_bus_map():
    """The complete I2C/SPI bus map, derived from board-model.py BUS_DEVICES and
    board-facts.py BENCH_DEVICES. This is the single source of truth for every
    chip's address / chip-select; both the JSON export and the doc tables below
    are rendered from it, so they cannot drift from the model.

    Returns {'i2c': [...], 'spi': [...]} with rows sorted by address / CS GPIO.
    """
    model = _load('board-model.py')
    facts = _load('board-facts.py')

    nets = {nm: set(nodes) for nm, nodes in model.NETS}

    def i2c_side(ref):
        # 5V Arduino sits behind the level-shifter on ARD_*; everything else is 3V3.
        return '5V' if ref is not None and ('ARD_SDA' in {
            nm for nm, nodes in nets.items() if any(r == ref for r, _ in nodes)
        }) else '3V3'

    i2c, spi = [], []

    rows = [(k, v, 'onboard') for k, v in model.BUS_DEVICES.items()]
    rows += [(k, v, 'bench') for k, v in facts.BENCH_DEVICES.items()]
    rows += [(k, v, 'planned') for k, v in facts.PLANNED_DEVICES.items()]
    rows += [(k, v, 'optional') for k, v in facts.OPTIONAL_DEVICES.items()]

    for key, (ref, bus, value, driver, tests), ctx in rows:
        if bus == 'i2c':
            i2c.append({
                'address': f'0x{value:02x}',
                'address_int': value,
                'device': key,
                'ref': ref,
                'driver': driver,
                'bus_side': i2c_side(ref) if ctx == 'onboard' else '3V3',
                'context': ctx,
                'tests': tests,
            })
        elif bus == 'spi':
            gpio = int(re.fullmatch(r'GPIO(\d+)', str(value)).group(1))
            spi.append({
                'cs': value,
                'cs_gpio': gpio,
                'device': key,
                'ref': ref,
                'driver': driver,
                'context': ctx,
                'tests': tests,
            })

    ctx_rank = {'onboard': 0, 'planned': 1, 'bench': 2, 'optional': 3}
    i2c.sort(key=lambda r: (r['address_int'], ctx_rank[r['context']], r['device']))
    spi.sort(key=lambda r: (r['cs_gpio'], ctx_rank[r['context']], r['device']))
    return {'i2c': i2c, 'spi': spi}


def bus_map_json():
    """Canonical JSON text for facts/bus-map.json (stable, diff-friendly)."""
    data = build_bus_map()
    data = {
        'note': ('GENERATED from board-model.py BUS_DEVICES + board-facts.py '
                 'BENCH_DEVICES / PLANNED_DEVICES by scripts/helpers/render-doc.py. '
                 'Do not edit by hand; re-run render-doc.py. The drift gate '
                 'cross-checks the source against the netlist on every `make test`.'),
        **data,
    }
    return json.dumps(data, indent=2) + '\n'


def gen_i2c_table():
    rows = build_bus_map()['i2c']
    lines = ['| Addr | Bus | Device | Ref | Driver | Ctx | Test |',
             '|------|-----|--------|-----|--------|-----|------|']
    for r in rows:
        ref = r['ref'] or '—'
        lines.append(f"| `{r['address']}` | {r['bus_side']} | {r['device']} | "
                     f"{ref} | `{r['driver']}` | {r['context']} | {r['tests']} |")
    return '\n'.join(lines)


def gen_spi_table():
    rows = build_bus_map()['spi']
    lines = ['| CS | Device | Ref | Driver | Test |',
             '|----|--------|-----|--------|------|']
    for r in rows:
        ref = r['ref'] or '—'
        lines.append(f"| `{r['cs']}` | {r['device']} | {ref} | "
                     f"`{r['driver']}` | {r['tests']} |")
    return '\n'.join(lines)


PLACEHOLDERS = {
    'default_states_pi5': gen_default_states_pi5,
    'i2c_table': gen_i2c_table,
    'spi_table': gen_spi_table,
}


# --- marker-delimited generated blocks in otherwise hand-authored files -------
# Each file below keeps its own curated content but hands ONE region over to the
# bus map, fenced by sentinel lines. The renderer replaces only what sits between
# the sentinels (the sentinels themselves stay put), and --check fails the build
# if a committed file's fenced block is stale. So the addresses in the FAQ and
# the added-hardware checklist are generated from the same source as everything
# else and can no longer drift. In FAQ.pod the sentinels are POD `=begin comment`
# blocks (hidden by pod2markdown); in the plain-text checklist they are `#` lines.

def _tagged(row):
    """'onboard' -> 'onboard, t/xxx'; empty test -> just the context."""
    return f"{row['context']}, {row['tests']}" if row['tests'] else row['context']


def gen_faq_i2c_block():
    """The verbatim I2C address list for FAQ.pod (indented 4 spaces)."""
    rows = build_bus_map()['i2c']
    width = max(len(r['device']) for r in rows)
    return '\n'.join(
        f"    {r['address']}  {r['device']:<{width}}  ({_tagged(r)})" for r in rows)


def gen_added_hardware_block():
    """The I2C-address + SPI-CS inventory for added-hardware.txt."""
    m = build_bus_map()
    iw = max(len(r['device']) for r in m['i2c'])
    sw = max(len(r['device']) for r in m['spi'])
    lines = ['I2C (by address):']
    lines += [f"  {r['address']}  {r['device']:<{iw}}  {_tagged(r)}" for r in m['i2c']]
    lines += ['', 'SPI (by chip-select):']
    lines += [f"  {r['cs']:<7} {r['device']:<{sw}}  {_tagged(r)}" for r in m['spi']]
    return '\n'.join(lines)


# (path, begin-fence, end-fence, body-generator). The fences are matched
# verbatim and preserved; only the text between them is regenerated. In FAQ.pod
# the fences are `=begin comment` blocks (invisible to pod2markdown); in the
# plain-text checklist they are `#` lines.
MARKED_FILES = [
    (FAQ_POD,
     '=begin comment\n\nGEN:bus-map-i2c:begin (generated; do not edit the list '
     'below - re-run scripts/helpers/render-doc.py)\n\n=end comment',
     '=begin comment\n\nGEN:bus-map-i2c:end\n\n=end comment',
     gen_faq_i2c_block),
    (ADDED_HW,
     '# GEN:bus-map:begin (generated; do not edit below - re-run '
     'scripts/helpers/render-doc.py)',
     '# GEN:bus-map:end',
     gen_added_hardware_block),
]


def splice_marked(path, begin, end, body):
    """Return `path`'s text with the region between the two verbatim fences
    replaced by `body` (fences preserved). Raises if a fence is absent."""
    text = open(path).read()
    i, j = text.find(begin), text.find(end)
    if i == -1 or j == -1 or j < i:
        raise SystemExit(f'render-doc: bus-map fences for '
                         f'{os.path.relpath(path, ROOT)} not found')
    return text[:i + len(begin)] + '\n\n' + body + '\n\n' + text[j:]


def render():
    text = open(TEMPLATE).read()
    for name, gen in PLACEHOLDERS.items():
        token = '{{' + name + '}}'
        if token not in text:
            raise SystemExit(f'render-doc: {token} not found in the template')
        text = text.replace(token, gen())

    leftover = re.findall(r'\{\{(\w+)\}\}', text)
    if leftover:
        raise SystemExit(f'render-doc: unfilled placeholders: {leftover}')
    return text


def main():
    # (path, desired-content) for every artifact rendered from a single source.
    artifacts = [(OUTPUT, render()), (BUSMAP, bus_map_json())]
    for path, begin, end, body in MARKED_FILES:
        artifacts.append((path, splice_marked(path, begin, end, body())))

    # --check: fail (without writing) if any committed artifact is out of date
    # with its template + generated sources, so a stale artifact fails the build.
    if '--check' in sys.argv[1:]:
        stale = [os.path.relpath(p, ROOT) for p, want in artifacts
                 if (open(p).read() if os.path.exists(p) else None) != want]
        if not stale:
            print('pin doc, bus-map.json, FAQ + added-hardware bus lists are up '
                  'to date with their sources.')
            return 0
        print('STALE (re-run scripts/helpers/render-doc.py): ' + ', '.join(stale))
        return 1

    for path, want in artifacts:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as fh:
            fh.write(want)
    print(f'wrote {os.path.relpath(OUTPUT, ROOT)} '
          f'({len(PLACEHOLDERS)} generated block(s)), '
          + ', '.join(os.path.relpath(p, ROOT) for p, _ in artifacts[1:]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
