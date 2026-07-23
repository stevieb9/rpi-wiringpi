#!/usr/bin/env python3
"""
kicad-caps.py - extract every supply-to-ground capacitor from each test
platform board's .kicad_pcb (pure stdlib, no kicad-cli).

This is the machine-read "as drawn" side of the bypass audit: render-doc.py
matches board-facts.py BYPASS required_uf (datasheet, curated) against the cap
pool extracted here, so a decoupler changed in KiCad regenerates the audit with
no second edit anywhere.

The per-IC cap->IC binding is placement-only: every decoupler on a board sits
on the shared supply net (all the ceramics and every IC VDD share it), so
*which* cap serves *which* IC is not in the netlist and cannot be
machine-derived. Extraction is therefore per-BOARD - the audit answers "does
the board carry the caps its chips require", never "which cap serves which
chip".

Polarized caps (CP_* / Polarized footprints) ARE included, flagged - a 10 uF
tantalum bulk requirement (MCP4922) is satisfied by a polarized cap, so
excluding them would make such requirements unsatisfiable.
"""

import glob
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
KICAD = os.path.normpath(os.path.join(HERE, '..', '..', 'docs', 'test-platform', 'kicad'))


# --- minimal s-expression reader (same shape as check-board-nets.py) ---------

def _tok(t):
    return re.findall(r'"(?:[^"\\]|\\.)*"|\(|\)|[^\s()]+', t)


def _parse(text):
    toks = _tok(text)
    pos = 0

    def walk():
        nonlocal pos
        node = []
        pos += 1
        while pos < len(toks):
            t = toks[pos]
            if t == '(':
                node.append(walk())
            elif t == ')':
                pos += 1
                return node
            else:
                node.append(t[1:-1].replace('\\"', '"')
                            if len(t) >= 2 and t[0] == '"' and t[-1] == '"' else t)
                pos += 1
        return node
    while pos < len(toks) and toks[pos] != '(':
        pos += 1
    return walk() if pos < len(toks) else []


def _kids(n, name):
    return [c for c in n if isinstance(c, list) and c and c[0] == name]


def _kid(n, name):
    f = _kids(n, name)
    return f[0] if f else None


def to_uf(val):
    """'1uF'->1.0, '0.1 µF'->0.1, '100nF'->0.1, '470µF'->470.0; None if unparsable."""
    m = re.match(r'\s*([\d.]+)\s*([pnuµμm]?)[fF]?\s*$', val or '')
    if not m:
        return None
    scale = {'p': 1e-6, 'n': 1e-3, 'u': 1, 'µ': 1, 'μ': 1, 'm': 1e3, '': 1}
    return round(float(m.group(1)) * scale[m.group(2)], 4)


def board_caps():
    """{board_n: [cap, ...]} for every board with a .kicad_pcb; each cap is
    {'ref', 'value', 'uf', 'polarized', 'nets'}, C* footprints with a pin on a
    supply rail (+3V3/+5V/VDD/VCC) and a pin on GND only. 'uf' is None when the
    value text is unparsable - callers must treat that as a hard error, never
    silently drop the cap."""
    boards = {}
    for bd in sorted(glob.glob(os.path.join(KICAD, '*'))):
        m = re.search(r'board-(\d+)$', bd)
        if not m:
            continue
        pcbs = glob.glob(os.path.join(bd, '*.kicad_pcb'))
        if not pcbs:
            continue
        root = _parse(open(pcbs[0]).read())
        caps = []
        for fp in _kids(root, 'footprint'):
            ref = val = None
            lib = fp[1] if len(fp) >= 2 and isinstance(fp[1], str) else ''
            for prop in _kids(fp, 'property'):
                if len(prop) >= 3 and prop[1] == 'Reference':
                    ref = prop[2]
                if len(prop) >= 3 and prop[1] == 'Value':
                    val = prop[2]
            if not ref or not ref.startswith('C'):
                continue
            nets = {net[-1] for pad in _kids(fp, 'pad')
                    if (net := _kid(pad, 'net')) and len(net) >= 2}
            supply = any(k in n for n in nets for k in ('3V3', '5V', 'VDD', 'VCC'))
            gnd = any('GND' in n for n in nets)
            if not (supply and gnd):
                continue
            caps.append({
                'ref': ref,
                'value': val,
                'uf': to_uf(val),
                'polarized': 'CP_' in lib or 'Polarized' in lib,
                'nets': sorted(nets),
            })
        boards[int(m.group(1))] = sorted(caps, key=lambda c: c['ref'])
    return boards


if __name__ == '__main__':
    for n, caps in sorted(board_caps().items()):
        print(f'board {n}:')
        for c in caps:
            kind = 'polarized' if c['polarized'] else 'ceramic'
            print(f"  {c['ref']:4} {c['value'] or '?':8} uf={c['uf']!s:7} "
                  f"{kind:9} nets={c['nets']}")
