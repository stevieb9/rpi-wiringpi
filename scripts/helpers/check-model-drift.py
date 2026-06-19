#!/usr/bin/env python3
"""
check-model-drift.py - the test-platform model drift gate.

The board model is hand-curated in board-model.py (the single source of truth).
model-from-tests.py is an INDEPENDENT re-derivation from the test suite. If the
two disagree, one of them is stale: the schematic/KiCad/docs no longer match
what the tests actually exercise. This is exactly the failure that let the t/330
loopback rot unnoticed.

Compares COMPONENTS / NETS / J1FUNC / DRIVER / POWER / SHEETS (nets order-
independent). Prints a per-table report; exits 0 on match, 1 on drift.

Pure stdlib - no rendering, no KiCad, no heavy deps - so it is cheap enough to
run on every `make test`.
"""

import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def _load(filename):
    path = os.path.join(HERE, filename)
    spec = importlib.util.spec_from_file_location(filename.replace('-', '_'), path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _canon_nets(nets):
    # Order-independent: {net-name: frozenset of (ref, pin)}.
    return {nm: frozenset(nodes) for nm, nodes in nets}


def main():
    canonical = _load('board-model.py')
    rederived = _load('model-from-tests.py')

    drift = False

    for attr in ('COMPONENTS', 'J1FUNC', 'DRIVER', 'POWER', 'SHEETS'):
        a, b = getattr(canonical, attr), getattr(rederived, attr)
        if a == b:
            print(f'  {attr:11} MATCH')
            continue
        drift = True
        print(f'  {attr:11} DRIFT')
        for k in sorted(set(a) | set(b)):
            if a.get(k) != b.get(k):
                print(f'      {k}: canonical={a.get(k)} re-derived={b.get(k)}')

    a, b = _canon_nets(canonical.NETS), _canon_nets(rederived.NETS)
    if a == b:
        print(f'  {"NETS":11} MATCH ({len(canonical.NETS)} nets)')
    else:
        drift = True
        print(f'  {"NETS":11} DRIFT')
        for k in sorted(set(a) | set(b)):
            if a.get(k) != b.get(k):
                print(f'      {k}: canonical={sorted(a.get(k, []))} '
                      f're-derived={sorted(b.get(k, []))}')

    if drift:
        print('\nMODEL DRIFT: board-model.py and model-from-tests.py disagree.\n'
              'One is stale - reconcile them before the docs/schematic can be trusted.')
        return 1

    print('\nmodel OK: the re-derivation matches the canonical board-model.py.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
