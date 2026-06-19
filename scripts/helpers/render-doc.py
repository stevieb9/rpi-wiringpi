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

import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
TEMPLATE = os.path.join(ROOT, 'docs', 'test-platform', 'test-pinout-doc.tmpl.md')
OUTPUT = os.path.join(ROOT, 'docs', 'test-platform', 'test-pinout-doc.md')
RPITEST = os.path.join(ROOT, 't', 'RPiTest.pm')


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


PLACEHOLDERS = {
    'default_states_pi5': gen_default_states_pi5,
}


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
    rendered = render()

    # --check: fail (without writing) if the committed doc is out of date with
    # its template + generated sources, so a stale doc fails the build.
    if '--check' in sys.argv[1:]:
        current = open(OUTPUT).read() if os.path.exists(OUTPUT) else None
        if current == rendered:
            print('test-pinout-doc.md is up to date with its template + sources.')
            return 0
        print('test-pinout-doc.md is STALE - re-run scripts/helpers/render-doc.py '
              '(its template or a generated source changed).')
        return 1

    with open(OUTPUT, 'w') as fh:
        fh.write(rendered)
    print(f'wrote {os.path.relpath(OUTPUT, ROOT)} '
          f'({len(PLACEHOLDERS)} generated block(s))')
    return 0


if __name__ == '__main__':
    sys.exit(main())
