#!/usr/bin/env python3
"""
check-board-locks.py - freeze finalized KiCad boards against silent change.

THE RULE THIS ENFORCES
  Once a board is hand-finalized in KiCad it is the source of truth for that
  board, and NOTHING about it may change unless the change is explicitly asked
  for. This gate makes that mechanical: every design file of a blessed board is
  hashed into a committed manifest, and any later difference - a byte edited, a
  file added, a file removed - fails the check.

  The ONLY sanctioned way to change a locked board is to re-bless it on purpose:
      check-board-locks.py --bless <board>
  which re-snapshots that board's hashes. Nothing else writes the manifest, so a
  blessed board cannot drift by accident, by regeneration, or by a stray tool.

WHAT COUNTS AS A "BOARD" AND ITS DESIGN FILES
  Boards live under docs/test-platform/kicad/<board-dir>/. A board's locked
  files are exactly: fp-lib-table, sym-lib-table, *.kicad_pro, *.kicad_sch,
  *.kicad_pcb, and every .pretty/*.kicad_mod footprint. Transient KiCad state
  (.kicad_prl, fp-info-cache, *-backups/, *.bak, *~) is never locked.

  A board is "finalized/locked" iff it appears in the manifest. Unblessed boards
  (still in flux) are ignored by the check - you freeze a board the moment you
  bless it, not before.

MANIFEST
  docs/test-platform/kicad/board-locks.json - human-readable, diff-friendly,
  committed to git. Generated only by --bless; never hand-edit.

USAGE
  check-board-locks.py                 verify every locked board (CI / make test)
  check-board-locks.py --bless BOARD…  (re)snapshot one or more boards
  check-board-locks.py --list          list locked boards and file counts
  check-board-locks.py --names         print locked board names, one per line
                                       (machine-readable; the single source the
                                       test suite and gen-kicad.py consult)

  BOARD may be a directory name, a path, or just its number (e.g. "2" ->
  rpi-wiringpi-unit-test-platform-board-2).

Pure stdlib - no KiCad, no deps - so it runs anywhere, including the Pi CI host.
Exits 0 when every locked board matches; non-zero on any drift.
"""

import glob
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
KICAD_DIR = os.path.normpath(os.path.join(HERE, '..', '..', 'docs', 'test-platform', 'kicad'))
MANIFEST = os.path.join(KICAD_DIR, 'board-locks.json')

# Design files that define a board (locked). Everything else is ignored.
LOCK_NAMES = {'fp-lib-table', 'sym-lib-table'}
LOCK_GLOBS = ('*.kicad_pro', '*.kicad_sch', '*.kicad_pcb')
FOOTPRINT_GLOB = os.path.join('*.pretty', '*.kicad_mod')


def board_dir(board):
    """Resolve a board argument (number, name, or path) to its directory."""
    if os.path.isdir(board):
        return os.path.normpath(board)
    name = board
    if board.isdigit():
        name = f'rpi-wiringpi-unit-test-platform-board-{board}'
    cand = os.path.join(KICAD_DIR, name)
    return os.path.normpath(cand) if os.path.isdir(cand) else None


def design_files(bdir):
    """Sorted board-relative paths of the design files that get locked."""
    found = set()
    for n in LOCK_NAMES:
        p = os.path.join(bdir, n)
        if os.path.isfile(p):
            found.add(n)
    for g in LOCK_GLOBS:
        for p in glob.glob(os.path.join(bdir, g)):
            found.add(os.path.relpath(p, bdir))
    for p in glob.glob(os.path.join(bdir, FOOTPRINT_GLOB)):
        found.add(os.path.relpath(p, bdir))
    return sorted(found)


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()


def hash_board(bdir):
    """{relpath: sha256} for every design file of a board."""
    return {rel: sha256(os.path.join(bdir, rel)) for rel in design_files(bdir)}


def load_manifest():
    if not os.path.isfile(MANIFEST):
        return {'boards': {}}
    with open(MANIFEST) as fh:
        return json.load(fh)


def save_manifest(data):
    with open(MANIFEST, 'w') as fh:
        json.dump(data, fh, indent=2, sort_keys=True)
        fh.write('\n')


def diff_board(name, recorded, bdir):
    """Return a list of human-readable drift messages for one locked board."""
    if not os.path.isdir(bdir):
        return [f'{name}: locked board directory is missing ({bdir})']
    current = hash_board(bdir)
    rec = recorded.get('files', {})
    msgs = []
    for rel in sorted(set(rec) - set(current)):
        msgs.append(f'{name}: locked file REMOVED: {rel}')
    for rel in sorted(set(current) - set(rec)):
        msgs.append(f'{name}: file ADDED since bless (not locked): {rel}')
    for rel in sorted(set(rec) & set(current)):
        if rec[rel] != current[rel]:
            msgs.append(f'{name}: file CHANGED since bless: {rel}')
    return msgs


def cmd_verify():
    data = load_manifest()
    boards = data.get('boards', {})
    if not boards:
        print('board-locks: no boards are locked yet (nothing to verify).')
        print('             bless a finalized board with: '
              'check-board-locks.py --bless <board>')
        return 0
    all_msgs = []
    for name in sorted(boards):
        bdir = os.path.join(KICAD_DIR, name)
        msgs = diff_board(name, boards[name], bdir)
        if msgs:
            all_msgs.extend(msgs)
        else:
            n = len(boards[name].get('files', {}))
            print(f'  OK   {name} ({n} files frozen)')
    if all_msgs:
        print('\nBOARD LOCK VIOLATION - a finalized board changed without a bless:')
        for m in all_msgs:
            print(f'  - {m}')
        print('\nIf the change was intentional, re-bless it ON PURPOSE:')
        print('  python3 scripts/helpers/check-board-locks.py --bless <board>')
        return 1
    print(f'\nboard-locks OK: {len(boards)} board(s) frozen, no drift.')
    return 0


def cmd_bless(args):
    data = load_manifest()
    boards = data.setdefault('boards', {})
    rc = 0
    for arg in args:
        bdir = board_dir(arg)
        if not bdir:
            print(f'bless: no such board: {arg!r}')
            rc = 1
            continue
        files = hash_board(bdir)
        if not files:
            print(f'bless: {arg!r} has no design files to lock ({bdir})')
            rc = 1
            continue
        name = os.path.basename(bdir)
        existed = name in boards
        boards[name] = {'files': files}
        verb = 're-blessed' if existed else 'blessed'
        print(f'{verb} {name}: {len(files)} files frozen')
        for rel in sorted(files):
            print(f'    {rel}')
    if rc == 0:
        save_manifest(data)
        print(f'\nmanifest written: {os.path.relpath(MANIFEST)}')
    return rc


def cmd_list():
    data = load_manifest()
    boards = data.get('boards', {})
    if not boards:
        print('board-locks: no boards locked.')
        return 0
    for name in sorted(boards):
        print(f'  {name}: {len(boards[name].get("files", {}))} files frozen')
    return 0


def cmd_names():
    """Print each locked board's directory name, one per line.

    Machine-readable single source of "which boards are off-limits": t/04
    derives its %FROZEN skip-set from this, and gen-kicad.py refuses to
    scaffold any name it lists. Emits nothing when no board is locked.
    """
    data = load_manifest()
    for name in sorted(data.get('boards', {})):
        print(name)
    return 0


def main():
    argv = sys.argv[1:]
    if not argv:
        return cmd_verify()
    if argv[0] == '--bless':
        if len(argv) < 2:
            print('usage: check-board-locks.py --bless <board> [<board> ...]')
            return 2
        return cmd_bless(argv[1:])
    if argv[0] == '--list':
        return cmd_list()
    if argv[0] == '--names':
        return cmd_names()
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main())
