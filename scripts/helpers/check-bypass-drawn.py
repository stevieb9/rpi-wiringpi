#!/usr/bin/env python3
"""
check-bypass-drawn.py - verify each board's real decoupling caps match the
bypass audit's as-drawn values.

The per-IC cap->IC binding is placement-only: every decoupler on a board sits on
the shared supply net (look at the +3V3 node list in any board .kicad_pcb - all
the ceramics and every IC VDD share it), so *which* cap serves *which* IC is not
in the netlist and cannot be machine-derived. The audit therefore keeps drawn_uf
curated per IC. This check closes the remaining drift gap the other way round: it
reads each board's actual .kicad_pcb (pure stdlib, no kicad-cli) and confirms the
MULTISET of ceramic decoupling-cap values physically on the board equals what the
audit claims for it -

    board's ceramic decouplers (on a supply rail, to GND)
      == sum(BYPASS drawn_uf for that board) + RAIL_DECOUPLE for that board

So a decoupler changed in KiCad but not reflected in the audit (or the reverse)
fails the build. Electrolytic bulk/rail caps (CP_* footprints) are out of scope,
matching the audit. It cannot say WHICH cap changed (placement-only binding) - it
reports the multiset mismatch and shows both sides.
"""

import glob
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
KICAD = os.path.normpath(os.path.join(HERE, '..', '..', 'docs', 'test-platform', 'kicad'))


def _load(fn):
    p = os.path.join(HERE, fn)
    spec = importlib.util.spec_from_file_location(fn[:-3].replace('-', '_'), p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


# --- minimal s-expression reader (same shape as check-board-nets.py) --------

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


def _to_uf(val):
    """'1uF'->1.0, '0.1 µF'->0.1, '100nF'->0.1, '470µF'->470.0; None if unparsable."""
    m = re.match(r'\s*([\d.]+)\s*([pnuµμm]?)[fF]?\s*$', val or '')
    if not m:
        return None
    scale = {'p': 1e-6, 'n': 1e-3, 'u': 1, 'µ': 1, 'μ': 1, 'm': 1e3, '': 1}
    return round(float(m.group(1)) * scale[m.group(2)], 4)


def ceramic_decouplers(pcb_path):
    """(sorted [values uF], [unparsable (ref,value)]) for this board's ceramic
    decoupling caps: non-electrolytic footprint, a pin on a supply rail
    (+3V3/+5V/VDD/VCC) and a pin on GND."""
    root = _parse(open(pcb_path).read())
    vals, bad = [], []
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
        if 'CP_' in lib or 'Polarized' in lib:      # electrolytic bulk - out of scope
            continue
        nets = {net[-1] for pad in _kids(fp, 'pad')
                if (net := _kid(pad, 'net')) and len(net) >= 2}
        supply = any(k in n for n in nets for k in ('3V3', '5V', 'VDD', 'VCC'))
        gnd = any('GND' in n for n in nets)
        if not (supply and gnd):                    # not a supply decoupler
            continue
        uf = _to_uf(val)
        if uf is None:
            bad.append((ref, val))
        else:
            vals.append(uf)
    return sorted(vals), bad


def main():
    facts = _load('board-facts.py')
    rail = getattr(facts, 'RAIL_DECOUPLE', {})
    problems = []
    checked = 0

    for bd in sorted(glob.glob(os.path.join(KICAD, '*'))):
        m = re.search(r'board-(\d+)$', bd)
        if not m:
            continue
        n = int(m.group(1))
        pcbs = glob.glob(os.path.join(bd, '*.kicad_pcb'))
        if not pcbs:
            continue
        checked += 1
        actual, bad = ceramic_decouplers(pcbs[0])
        expected = sorted(
            [v for b in facts.BYPASS.values()
             if b.get('board') == n for v in (b.get('drawn_uf') or [])]
            + list(rail.get(n, [])))
        if bad:
            problems.append(f"board {n}: unparsable cap value(s): {bad}")
        if actual != expected:
            problems.append(
                f"board {n}: PCB decouplers {actual} != audit drawn {expected} - "
                f"a decoupler changed on the board; update the matching BYPASS "
                f"drawn_uf (or RAIL_DECOUPLE[{n}]) and re-run render-doc.py")

    if problems:
        print("BYPASS-DRAWN CHECK FAILED - the audit's as-drawn caps no longer "
              "match the boards:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"bypass-drawn OK: every board's ceramic decouplers match the audit "
          f"({checked} boards).")
    return 0


if __name__ == '__main__':
    sys.exit(main())
