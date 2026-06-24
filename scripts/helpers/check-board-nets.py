#!/usr/bin/env python3
"""
check-board-nets.py - verify a finalized board's NETS match its board model.

check-kicad.py proves footprints resolve and cover their pins. check-model-drift.py
proves the whole-board model still matches the tests. NEITHER proves that a
hand-finalized board's actual pin-to-pin connectivity still implements its
per-board electrical model (board-4-model.py, ...). That is the
gap this script closes - the failure mode where someone edits the schematic/PCB in
KiCad and silently moves a net off the pin the tests expect.

For every board that has BOTH a built .kicad_pcb and a matching board-N-model.py:

  1. PCB layer (always, pure-stdlib): parse the .kicad_pcb, read each pad's
     resolved net, and confirm every model net is realised on exactly the right
     pins with the right name - and that no model pin is left unconnected.
  2. Schematic layer (when kicad-cli is on PATH): export the schematic netlist
     with KiCad's own parser and run the identical comparison. This independently
     confirms the schematic - and catches a schematic that has drifted out of
     sync with the PCB. Skipped with a notice when kicad-cli is absent.

The model is the source of truth; the KiCad files must implement it pin-for-pin.

Usage:
  check-board-nets.py [BOARD ...]
BOARD may be a number, dir name, or path; with no args every board that has a
model + PCB is checked. Exit 0 when all match; non-zero on any net discrepancy.
"""

import glob
import importlib.util
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
KICAD_DIR = os.path.normpath(os.path.join(HERE, '..', '..', 'docs', 'test-platform', 'kicad'))

# --- s-expression reader (shared shape with check-kicad.py) ----------------

def tokenize(text):
    return re.findall(r'"(?:[^"\\]|\\.)*"|\(|\)|[^\s()]+', text)

def parse(text):
    tokens = tokenize(text)
    pos = 0
    def walk():
        nonlocal pos
        node = []
        pos += 1
        while pos < len(tokens):
            tok = tokens[pos]
            if tok == '(':
                node.append(walk())
            elif tok == ')':
                pos += 1
                return node
            else:
                if len(tok) >= 2 and tok[0] == '"' and tok[-1] == '"':
                    node.append(tok[1:-1].replace('\\"', '"'))
                else:
                    node.append(tok)
                pos += 1
        return node
    while pos < len(tokens) and tokens[pos] != '(':
        pos += 1
    return walk() if pos < len(tokens) else []

def head(n):
    return n[0] if isinstance(n, list) and n and isinstance(n[0], str) else None

def kids(n, name):
    return [c for c in n if isinstance(c, list) and head(c) == name]

def kid(n, name):
    f = kids(n, name)
    return f[0] if f else None

# --- net-name normalisation ------------------------------------------------

def norm(net):
    """Strip KiCad's leading '/' so '/PWM18' and 'PWM18' compare equal."""
    if net is None:
        return None
    return net[1:] if net.startswith('/') else net

def is_unconnected(net):
    return net is None or net.startswith('unconnected') or net.startswith('Net-')

# --- board <-> model resolution -------------------------------------------

def board_dir(board):
    if os.path.isdir(board):
        return os.path.normpath(board)
    name = board
    if board.isdigit():
        name = f'rpi-wiringpi-unit-test-platform-board-{board}'
    cand = os.path.join(KICAD_DIR, name)
    return os.path.normpath(cand) if os.path.isdir(cand) else None

def model_for(bdir):
    """Load the board-N-model.py matching this board dir, or None."""
    m = re.search(r'board-(\d+)$', os.path.basename(bdir))
    if not m:
        return None
    path = os.path.join(HERE, f'board-{m.group(1)}-model.py')
    if not os.path.isfile(path):
        return None
    spec = importlib.util.spec_from_file_location(f'board_{m.group(1)}_model', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

def pcb_path(bdir):
    hits = glob.glob(os.path.join(bdir, '*.kicad_pcb'))
    return hits[0] if hits else None

def sch_path(bdir):
    hits = glob.glob(os.path.join(bdir, '*.kicad_sch'))
    return hits[0] if hits else None

# --- extract (ref,pin)->net from PCB and from a kicad-cli netlist ----------

def pcb_nets(path):
    root = parse(open(path).read())
    out = {}
    for fp in kids(root, 'footprint'):
        ref = None
        for prop in kids(fp, 'property'):
            if len(prop) >= 3 and prop[1] == 'Reference':
                ref = prop[2]
        if not ref:
            continue
        for pad in kids(fp, 'pad'):
            if len(pad) < 2:
                continue
            net = kid(pad, 'net')
            if net and len(net) >= 2:
                out[(ref, pad[1])] = net[1]
    return out

def netlist_nets(path):
    """(ref,pin)->net from a kicad-cli 'export' netlist."""
    root = parse(open(path).read())
    nets = kid(root, 'nets')
    out = {}
    for net in kids(nets or [], 'net'):
        name = kid(net, 'name')
        nm = name[1] if name and len(name) >= 2 else None
        for node in kids(net, 'node'):
            r = kid(node, 'ref')
            p = kid(node, 'pin')
            if r and p and len(r) >= 2 and len(p) >= 2:
                out[(r[1], p[1])] = nm
    return out

# --- the comparison --------------------------------------------------------

def compare(model, actual, layer):
    """Diff model.NETS against an (ref,pin)->net map. Returns list of messages."""
    msgs = []
    model_refs = set(model.COMPONENTS)
    for name, nodes in model.NETS:
        want = {(r, p) for r, p in nodes}
        seen = {}
        for rp in want:
            seen.setdefault(norm(actual.get(rp)), set()).add(rp)
        names = set(seen)
        # every listed pin must sit on one and the same real net
        if len(names) != 1 or None in names or any(is_unconnected(n) for n in names if n):
            msgs.append(f'[{layer}] net {name!r} not realised cleanly:')
            for n, ps in sorted(seen.items(), key=lambda x: str(x[0])):
                shown = n if n is not None else '<no pad/net>'
                msgs.append(f'        {shown!r}: {sorted(ps)}')
            continue
        thenet = next(iter(names))
        if thenet != name:
            msgs.append(f'[{layer}] net {name!r} present but renamed to {thenet!r}')
        # no UNlisted model pins may share this net (a stray connection)
        extra = {rp for rp, n in actual.items()
                 if norm(n) == thenet and rp[0] in model_refs and rp not in want}
        if extra:
            msgs.append(f'[{layer}] net {name!r} has extra model pins: {sorted(extra)}')
    return msgs

def kicad_cli_netlist(sch, warnings):
    """Export a netlist via kicad-cli into a HOME-scoped temp (flatpak-safe)."""
    cli = shutil.which('kicad-cli')
    if not cli:
        return None
    out_dir = os.path.expanduser('~/.cache/rpi-wiringpi-netcheck')
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, 'netlist.net')
    proc = subprocess.run(
        [cli, 'sch', 'export', 'netlist', '--format', 'kicadsexpr', '-o', out, sch],
        capture_output=True, text=True)
    if proc.returncode != 0 or not os.path.isfile(out):
        warnings.append('kicad-cli netlist export failed: '
                        + (proc.stderr or proc.stdout).strip())
        return None
    return out

def check_board(bdir):
    """Returns (messages, did_sch_layer). messages empty == board OK."""
    model = model_for(bdir)
    pcb = pcb_path(bdir)
    name = os.path.basename(bdir)
    if not model:
        return ([f'{name}: no board-N-model.py - cannot verify nets'], False)
    if not pcb:
        return ([f'{name}: no .kicad_pcb - nothing to verify'], False)

    msgs = compare(model, pcb_nets(pcb), 'PCB')

    did_sch = False
    sch = sch_path(bdir)
    warnings = []
    if sch:
        nl = kicad_cli_netlist(sch, warnings)
        if nl:
            did_sch = True
            msgs += compare(model, netlist_nets(nl), 'SCH')
    for w in warnings:
        msgs.append(f'        note: {w}')
    return ([f'{name}: ' + m if not m.startswith('[') and not m.startswith(' ')
             else m for m in msgs], did_sch)

def main():
    argv = sys.argv[1:]
    if argv:
        dirs = [board_dir(a) for a in argv]
        if None in dirs:
            print('check-board-nets: unknown board(s):',
                  [a for a, d in zip(argv, dirs) if d is None])
            return 2
    else:
        dirs = sorted(d for d in glob.glob(os.path.join(KICAD_DIR, '*'))
                      if os.path.isdir(d) and model_for(d) and pcb_path(d))
        if not dirs:
            print('check-board-nets: no boards with both a model and a PCB.')
            return 0

    any_fail = False
    for bdir in dirs:
        name = os.path.basename(bdir)
        msgs, did_sch = check_board(bdir)
        if msgs:
            any_fail = True
            print(f'FAIL {name}:')
            for m in msgs:
                print(f'  {m}')
        else:
            layers = 'PCB + schematic' if did_sch else 'PCB (kicad-cli absent - schematic not cross-checked)'
            n = len(model_for(bdir).NETS)
            print(f'OK   {name}: {n} model nets realised, {layers}')
    if any_fail:
        print('\nNET CHECK FAILED - a board no longer implements its model.')
        return 1
    print('\ncheck-board-nets OK.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
