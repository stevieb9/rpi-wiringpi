#!/usr/bin/env python3
"""
sync-kicad-parts.py - push this checkout's KiCad parts catalog to rpi-tracker.

Machine-reads every placed symbol in the test platform board schematics
(docs/test-platform/kicad/*/*.kicad_sch) of THIS checkout plus the personal
board projects under ~/repos/kicad/boards and any KiCad projects living
inside ~/repos/scripts/arduino/<project>/ - the Mac working copies are the
source of truth; naranja's clones can lag - and replaces the source='kicad'
rows of the kicad_parts table in naranja's rpi-tracker db with the distinct
(symbol lib_id, footprint) pairs found, each with its placed reference count
and the boards it appears on (test platform boards by number, personal
projects by directory name). Rows hand-added on the tracker's /kicad page
(source='manual') are never touched.

Power symbols (power:* lib_ids, #-prefixed references) are netlist artifacts,
not parts, and are skipped, as are DNP instances. Multi-unit symbols count
once per reference.

Also runs ON naranja (from its rpi-wiringpi clone, via rpi-tracker's
sync.pl / the Update KiCAD button) with --db --add-only: there the naranja
clones are the source and only pairs missing from the table are added -
the Mac push remains the authority that replaces machine-read rows.

Usage: sync-kicad-parts.py [--dry-run] [--add-only] [--db PATH]
  --dry-run   print the catalog, write nothing
  --add-only  only INSERT (symbol, footprint) pairs not already present;
              never deletes/updates rows or the last-push stamp
  --db PATH   write straight into the SQLite db at PATH (for runs on the
              tracker host itself) instead of ssh-ing to naranja
"""

import glob
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
KICAD = os.path.normpath(os.path.join(HERE, '..', '..', 'docs', 'test-platform', 'kicad'))
BOARDS = os.path.expanduser('~/repos/kicad/boards')
SCRIPTS = os.path.expanduser('~/repos/scripts/arduino')

HOST = 'naranja'
DB = '~/repos/rpi-tracker/db/rpi-tracker.db'

# Mirrors db/schema.sql in rpi-tracker; created here too so a fresh db and a
# first push can happen in either order
DDL = """\
CREATE TABLE IF NOT EXISTS kicad_parts (
    id        INTEGER PRIMARY KEY,
    symbol    TEXT NOT NULL,
    type      TEXT,
    footprint TEXT,
    refs      INTEGER,
    boards    TEXT,
    source    TEXT NOT NULL DEFAULT 'manual'
);
CREATE TABLE IF NOT EXISTS sync_meta (
    key   TEXT PRIMARY KEY,
    value TEXT
)"""


# --- minimal s-expression reader (same shape as kicad-caps.py) ---------------

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


# Part-type classifier: first matching symbol rule wins; symbols from
# board-local / one-off libs fall through to the footprint rules, then to
# the known-parts table. Extend here when a new lib shows up as 'other'.
SYMBOL_TYPES = (
    (r'^Device:LED',             'LED'),
    (r'^Device:L',               'inductor'),
    (r'^Device:R_Potentiometer', 'potentiometer'),
    (r'^Device:R',               'resistor'),
    (r'^Device:C',               'capacitor'),
    (r'^Device:D',               'diode'),
    (r'^Device:Q',               'transistor'),
    (r'^Diode:',                 'diode'),
    (r'^Transistor',             'transistor'),
    (r'^Connector.*:TestPoint',  'test point'),
    (r'^Connector',              'connector'),
    (r'^Switch:',                'switch'),
    (r'^Relay',                  'relay'),
    (r'^Sensor',                 'sensor'),
    (r'^(?:RPi|Display):.*(?:OLED|LCD)', 'display'),
    (r'^RPi:',                   'module'),
    (r'^(?:RF_Module|MCU_Module)', 'module'),
    (r'^(?:74xx|4xxx|Analog|Interface|Driver|Memory|MCU|Logic|Amplifier|'
     r'Comparator|Regulator|Timer|Potentiometer_Digital|Reference|'
     r'Oscillator|Isolator)', 'IC'),
)

FOOTPRINT_TYPES = (
    (r'^Resistor_',      'resistor'),
    (r'^Capacitor_',     'capacitor'),
    (r'^LED_',           'LED'),
    (r'^Diode_',         'diode'),
    (r'^Inductor_',      'inductor'),
    (r'^Potentiometer_', 'potentiometer'),
    (r'^(?:Button_)?Switch', 'switch'),
    (r'^TestPoint',      'test point'),
    (r'^Connector_',     'connector'),
    (r'^Package_',       'IC'),
    (r'^RF_Module',      'module'),
)

KNOWN_TYPES = {
    'Outdoor-solar-lamp:QX5252F': 'IC',
}


def classify(lib_id, footprint):
    for pat, t in SYMBOL_TYPES:
        if re.match(pat, lib_id):
            return t
    for pat, t in FOOTPRINT_TYPES:
        if re.match(pat, footprint or ''):
            return t
    return KNOWN_TYPES.get(lib_id, 'other')


def _sch_files():
    """Yield (board label, sch path): test platform boards by number, then
    each project under ~/repos/kicad/boards by its top-level dir name.
    KiCad litter (.history, _restore_backup_*, _autosave-*) is skipped -
    dot-dirs already by glob, the rest explicitly."""
    for sch in sorted(glob.glob(os.path.join(KICAD, '*', '*.kicad_sch'))):
        m = re.search(r'board-(\d+)', os.path.basename(os.path.dirname(sch)))
        yield (int(m.group(1)) if m else 0), sch

    for sch in sorted(glob.glob(os.path.join(BOARDS, '*', '**', '*.kicad_sch'),
                                recursive=True)):
        rel = os.path.relpath(sch, BOARDS).split(os.sep)
        if any(p.startswith(('_restore_backup', '_autosave')) for p in rel):
            continue
        yield rel[0], sch

    for sch in sorted(glob.glob(os.path.join(SCRIPTS, '*', '**', '*.kicad_sch'),
                                recursive=True)):
        rel = os.path.relpath(sch, SCRIPTS).split(os.sep)
        if any(p.startswith(('_restore_backup', '_autosave')) for p in rel):
            continue
        yield rel[0], sch


def _boards_str(bset):
    """'2,3,5' / '2,LED-Frame' - numbers first, then project names."""
    ordered = sorted(bset, key=lambda b: (isinstance(b, str), b))
    return ','.join(str(b) for b in ordered)


def board_parts():
    """{(lib_id, footprint): {'refs': N placed, 'boards': set of labels}}"""
    parts = {}
    seen = set()    # (board label, ref) - refs are project-wide

    for board, sch in _sch_files():
        with open(sch, encoding='utf-8') as f:
            root = _parse(f.read())

        # Placed instances are direct children of the sheet; the symbol
        # DEFINITIONS under lib_symbols are one level deeper and never hit
        for sym in _kids(root, 'symbol'):
            lid = _kid(sym, 'lib_id')
            if not lid or len(lid) < 2:
                continue
            lib_id = lid[1]
            props = {p[1]: p[2] for p in _kids(sym, 'property') if len(p) >= 3}
            ref = props.get('Reference', '')
            dnp = _kid(sym, 'dnp')

            if lib_id.startswith('power:') or ref.startswith('#'):
                continue
            if dnp and len(dnp) > 1 and dnp[1] == 'yes':
                continue
            if (board, ref) in seen:    # multi-unit symbol: one part per ref
                continue
            seen.add((board, ref))

            slot = parts.setdefault((lib_id, props.get('Footprint', '')),
                                    {'refs': 0, 'boards': set()})
            slot['refs'] += 1
            slot['boards'].add(board)

    return parts


def _q(s):
    return "'" + s.replace("'", "''") + "'"


def _insert_sql(lib_id, fp, agg, guarded):
    """Plain INSERT for a full replace; with guarded=True an INSERT..SELECT
    that only fires when the (symbol, footprint) pair is not present."""
    vals = (f"{_q(lib_id)}, {_q(classify(lib_id, fp))}, {_q(fp) if fp else 'NULL'}, "
            f"{agg['refs']}, {_q(_boards_str(agg['boards']))}, 'kicad'")
    head = 'INSERT INTO kicad_parts (symbol, type, footprint, refs, boards, source)'
    if not guarded:
        return f'{head} VALUES ({vals})'
    return (f'{head} SELECT {vals} '
            'WHERE NOT EXISTS (SELECT 1 FROM kicad_parts '
            f"WHERE symbol = {_q(lib_id)} "
            f"AND COALESCE(footprint, '') = {_q(fp or '')})")


def main():
    argv = sys.argv[1:]
    dry = '--dry-run' in argv
    add_only = '--add-only' in argv
    db = None
    if '--db' in argv:
        i = argv.index('--db')
        if i + 1 >= len(argv):
            sys.exit('--db needs a path')
        db = argv[i + 1]

    parts = board_parts()
    if not parts:
        sys.exit('no placed symbols found under ' + KICAD)

    rows = sorted(parts.items(), key=lambda kv: (kv[0][0].lower(), kv[0][1].lower()))
    inserts = [_insert_sql(lib_id, fp, agg, add_only)
               for (lib_id, fp), agg in rows]

    if dry:
        for (lib_id, fp), agg in rows:
            print(f"{classify(lib_id, fp)}\t{lib_id}\t{fp or '-'}\t"
                  f"refs={agg['refs']}\tboards={_boards_str(agg['boards'])}")
        mode = 'add missing pairs only' if add_only else 'full replace'
        print(f'\n-- dry run ({mode}), nothing written --')
        return

    stamp = ("INSERT OR REPLACE INTO sync_meta (key, value) VALUES "
             "('last_kicad_push', datetime('now', 'localtime'))")

    if db:
        import sqlite3
        con = sqlite3.connect(db)
        con.isolation_level = None
        con.executescript(DDL)
        con.execute('BEGIN')
        if not add_only:
            con.execute("DELETE FROM kicad_parts WHERE source = 'kicad'")
        written = sum(con.execute(ins).rowcount for ins in inserts)
        if not add_only:
            con.execute(stamp)
        con.execute('COMMIT')
        con.close()
        print(f"{'added' if add_only else 'wrote'} {written} part(s) in {db}")
        return

    stmts = ['BEGIN', DDL]
    if not add_only:
        stmts.append("DELETE FROM kicad_parts WHERE source = 'kicad'")
    stmts += inserts
    if not add_only:
        stmts.append(stamp)
    stmts.append('COMMIT')
    sql = ';\n'.join(stmts) + ';\n'

    subprocess.run(('ssh', HOST, f'sqlite3 {DB}'), input=sql, text=True, check=True)
    print(f"{'checked' if add_only else 'pushed'} {len(rows)} parts to {HOST}")


if __name__ == '__main__':
    main()
