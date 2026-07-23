#!/usr/bin/env python3
"""
check-bypass-coverage.py - coverage gate for the per-IC decoupling audit.

The bypass audit (board-facts.py BYPASS -> facts/bypass.json + facts/conflicts.json,
via render-doc.py) is only as complete as the BYPASS table. This check ties that
table back to the canonical model so a newly-added chip cannot slip into the
design without a datasheet decoupling decision. It walks board-model.py
COMPONENTS and requires that

  - every bare IC   (DIP/SOIC/QFN/... footprint) has a BYPASS entry of kind 'ic',
  - every module    ('Module' footprint) has a BYPASS entry of kind 'module'/'na',
  - no BYPASS entry references a ref absent from the model (orphan), and
  - nothing carries a footprint this check cannot classify - an unknown footprint
    is treated as a possible IC and must be resolved (fail-closed).

Planned board-1 parts (BYPASS ref None) are exempt - they are not in COMPONENTS
yet. A gap is an ALL-STOP: add the part to BYPASS with its datasheet-recommended
cap (or, for a genuine passive, extend PASSIVE_FP below), then re-run
scripts/helpers/render-doc.py.

A second, board-walk pass anchors the same rule to the fabbed boards
themselves: every placed IC/module footprint on every board .kicad_pcb must
have a BYPASS entry matched on (board, pcb_ref) - pcb_ref being the refdes on
the board's silkscreen, a per-board namespace distinct from the model's
platform-unique refs - and every recorded pcb_ref must actually be placed on
its board. So a NEW board cannot land without a datasheet decoupling decision
for each of its chips, no matter whether it ever enters the model.
"""

import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# Footprint-hint prefixes that identify a bare IC (needs a datasheet bypass
# decision) vs. a passive / connector / mechanical part (no supply pin to
# decouple). Classification order is IC, then the lone 'Module', then passive;
# anything left over is unclassified and fails closed.
IC_FP = ('DIP', 'PDIP', 'SPDIP', 'SOIC', 'SOP', 'SSOP', 'TSSOP', 'MSOP',
         'QFN', 'QFP', 'LQFP', 'TQFP', 'DFN', 'BGA')
PASSIVE_FP = ('PinHeader', 'Header', 'Conn', 'Pot', 'SW', 'LED', 'R', 'C', 'L',
              'Crystal', 'Resonator', 'Fuse', 'Ferrite', 'TestPoint', 'Jumper',
              'Mounting', 'Hole', 'Screw', 'Diode')

# Board-walk classification by KiCad footprint-library nickname (the part
# before the ':'). 'Package_*' are bare-IC packages; 'RPi' is this project's
# own breakout/module footprint library; the rest are passives/mechanical.
# Anything unlisted fails closed, same as the model pass.
IC_LIB = ('Package_',)
MODULE_LIB = ('RPi',)
PASSIVE_LIB = ('Capacitor_', 'Resistor_', 'LED_', 'Connector_', 'Diode_',
               'Button_Switch_', 'Potentiometer_', 'MountingHole', 'TestPoint',
               'Jumper', 'Fuse', 'Crystal', 'Inductor_', 'Relay_', 'Switch_')


def _kind_for_lib(nickname):
    """'ic' | 'module' | 'passive' | None (unclassifiable -> fail closed)."""
    if nickname.startswith(IC_LIB):
        return 'ic'
    if nickname in MODULE_LIB:
        return 'module'
    if nickname.startswith(PASSIVE_LIB):
        return 'passive'
    return None


def _kind_for_footprint(fp):
    """'ic' | 'module' | 'passive' | None (unclassifiable -> fail closed)."""
    if fp.startswith(IC_FP):
        return 'ic'
    if fp == 'Module':
        return 'module'
    if fp.startswith(PASSIVE_FP):
        return 'passive'
    return None


def _load(filename):
    path = os.path.join(HERE, filename)
    spec = importlib.util.spec_from_file_location(
        filename[:-3].replace('-', '_'), path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _board_walk(bypass):
    """Walk every fabbed board's .kicad_pcb: every placed IC/module footprint
    needs a BYPASS entry matched on (board, pcb_ref), and every recorded
    pcb_ref must be placed on its board. Returns (problems, boards, matched)."""
    import glob
    import re

    kcaps = _load('kicad-caps.py')
    kicad = os.path.normpath(
        os.path.join(HERE, '..', '..', 'docs', 'test-platform', 'kicad'))

    entries = {}
    for dev, b in bypass.items():
        if b.get('pcb_ref'):
            entries.setdefault((b['board'], b['pcb_ref']), set()).add(b['kind'])

    problems, seen = [], set()
    boards = matched = 0
    for bd in sorted(glob.glob(os.path.join(kicad, '*'))):
        m = re.search(r'board-(\d+)$', bd)
        pcbs = glob.glob(os.path.join(bd, '*.kicad_pcb'))
        if not m or not pcbs:
            continue
        n = int(m.group(1))
        boards += 1
        root = kcaps._parse(open(pcbs[0]).read())
        for fp in kcaps._kids(root, 'footprint'):
            ref = val = None
            lib = fp[1] if len(fp) >= 2 and isinstance(fp[1], str) else ''
            for prop in kcaps._kids(fp, 'property'):
                if len(prop) >= 3 and prop[1] == 'Reference':
                    ref = prop[2]
                if len(prop) >= 3 and prop[1] == 'Value':
                    val = prop[2]
            # Anonymous mechanical footprints (board-2's bare corner
            # mounting holes): no lib, no ref, no value AND electrically dead
            # (no pad on any net) - skip; anything anonymous but connected
            # still falls through and fails closed below.
            if not lib and not ref and not val:
                nets = [net for pad in kcaps._kids(fp, 'pad')
                        if (net := kcaps._kid(pad, 'net'))]
                if not nets:
                    continue
            nick = lib.split(':')[0]
            klass = _kind_for_lib(nick)
            if klass == 'passive':
                continue
            if klass is None:
                problems.append(
                    f"board {n} {ref} ({val}): footprint library {nick!r} is "
                    f"unclassified - if it is an IC/module add a BYPASS entry "
                    f"and classify the nickname, else extend PASSIVE_LIB")
                continue
            want = ('ic',) if klass == 'ic' else ('module', 'na')
            have = entries.get((n, ref))
            seen.add((n, ref))
            if not have:
                problems.append(
                    f"board {n} {ref} ({val}, {nick}) has NO BYPASS entry with "
                    f"pcb_ref={ref!r} - read the datasheet and add the "
                    f"decoupling decision")
            elif not have & set(want):
                problems.append(
                    f"board {n} {ref} ({val}): BYPASS kind(s) {sorted(have)} "
                    f"but a {klass} expects one of {want}")
            else:
                matched += 1

    for (n, ref), kinds in sorted(entries.items()):
        if (n, ref) not in seen:
            problems.append(
                f"BYPASS pcb_ref {ref!r} (board {n}) is not placed on that "
                f"board's PCB (typo or renamed part?)")

    return problems, boards, matched


def main():
    model = _load('board-model.py')
    facts = _load('board-facts.py')
    bypass = facts.BYPASS

    # ref -> set of BYPASS kinds recorded for it (a ref can appear twice, e.g. a
    # combined RTC+EEPROM breakout that carries two devices on one module).
    kinds_by_ref = {}
    for b in bypass.values():
        if b.get('ref'):
            kinds_by_ref.setdefault(b['ref'], set()).add(b['kind'])

    model_refs = set(model.COMPONENTS)
    problems = []

    # 1. Every modelled IC / module must be audited (and classified correctly).
    for ref, comp in model.COMPONENTS.items():
        value, fp = comp[0], str(comp[1])
        klass = _kind_for_footprint(fp)
        if klass == 'passive':
            continue
        if klass is None:
            problems.append(
                f"{ref} ({value}): footprint {fp!r} is unclassified - if it is "
                f"an IC add a BYPASS entry, else add its prefix to PASSIVE_FP")
            continue
        want = ('ic',) if klass == 'ic' else ('module', 'na')
        have = kinds_by_ref.get(ref)
        if not have:
            problems.append(
                f"{ref} ({value}, {fp}) has NO BYPASS entry - add one with its "
                f"datasheet decoupling cap")
        elif not have & set(want):
            problems.append(
                f"{ref} ({value}, {fp}): BYPASS kind(s) {sorted(have)} but a "
                f"{klass} expects one of {want}")

    # 2. No orphan BYPASS entry (ref set but not in the model). Planned parts
    #    (ref None) are exempt - they are not yet in COMPONENTS.
    for dev, b in bypass.items():
        ref = b.get('ref')
        if ref and ref not in model_refs:
            problems.append(
                f"BYPASS {dev!r} -> ref {ref} is absent from board-model.py "
                f"COMPONENTS (typo or removed part?)")

    walk_problems, walk_boards, walk_matched = _board_walk(bypass)
    problems += walk_problems

    if problems:
        print('BYPASS COVERAGE FAILED - the per-IC decoupling audit is incomplete:')
        for p in problems:
            print(f'  - {p}')
        print('\nEvery IC/module in board-model.py COMPONENTS must have a '
              'board-facts.py BYPASS entry; then re-run render-doc.py.')
        return 1

    n_ic = sum(1 for c in model.COMPONENTS.values()
               if _kind_for_footprint(str(c[1])) == 'ic')
    n_mod = sum(1 for c in model.COMPONENTS.values() if str(c[1]) == 'Module')
    print(f'bypass coverage OK: every modelled IC + module is audited '
          f'({n_ic} bare ICs, {n_mod} modules); board-walk: {walk_boards} '
          f'boards, {walk_matched} placed IC/module footprints matched.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
