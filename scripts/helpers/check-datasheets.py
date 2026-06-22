#!/usr/bin/env python3
"""
check-datasheets.py - the ALL-STOP datasheet-consistency gate.

The board models (board-model.py and the per-board board-N-model.py) carry each
bare IC's pin map. Those names/numbers are only as trustworthy as the human who
typed them - and a wrong pin map can agree with the schematic, the PCB, the docs
and the tests yet still contradict the silicon (this is exactly how the MCP42010
right-column reversal slipped in once). The datasheet is the only external ground
truth.

datasheet-pinouts.json holds the pinouts extracted INDEPENDENTLY from the cited
manufacturer datasheets. This script diffs every board model's IC pin maps against
that file. Any disagreement is treated as an EMERGENCY: the datasheet contradicts
the design, so the build STOPS and the operator is told exactly where.

A component is matched to a datasheet part when a part key (e.g. "MCP23017") is a
substring of the component's model value (e.g. "MCP23017_0x20") - so address-tagged
and renumbered per-board copies are all covered. Modules with named (non-numeric)
pins are addressed/labelled parts, not pin-number-critical DIPs, and are skipped.

Pure stdlib. Exit 0 when every IC pin matches its datasheet; non-zero on any
contradiction.
"""

import glob
import importlib.util
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATASHEETS = os.path.join(HERE, 'datasheet-pinouts.json')


def load_model(path):
    name = os.path.basename(path)[:-3].replace('-', '_')
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def model_files():
    """board-model.py plus every board-N-model.py present, sorted."""
    files = []
    canonical = os.path.join(HERE, 'board-model.py')
    if os.path.isfile(canonical):
        files.append(canonical)
    files += sorted(glob.glob(os.path.join(HERE, 'board-*-model.py')))
    return files


def match_part(value, parts):
    """Datasheet part key whose name appears in the component value, or None.

    Longest key wins, so 'MCP42010' is never shadowed by a shorter key.
    """
    hits = [k for k in parts if k.upper() in value.upper()]
    return max(hits, key=len) if hits else None


def nets_index(mod):
    """{(ref, pin): net-name} from a model's NETS."""
    idx = {}
    for name, nodes in getattr(mod, 'NETS', []):
        for ref, pin in nodes:
            idx[(ref, pin)] = name
    return idx


def declared_addr(value):
    """The 0xNN address baked into a component value, or None."""
    m = re.search(r'0x([0-9a-fA-F]{2})', value)
    return int(m.group(1), 16) if m else None


def check_pins(parts, problems):
    """Diff every model's numeric IC pin maps against the datasheet pinouts."""
    checked = 0
    for path in model_files():
        mod = load_model(path)
        model_name = os.path.basename(path)
        for ref, spec in getattr(mod, 'COMPONENTS', {}).items():
            if not (isinstance(spec, (list, tuple)) and len(spec) >= 3):
                continue
            value, _fp, pinmap = spec[0], spec[1], spec[2]
            if not any(str(p).isdigit() for p in pinmap):
                continue
            key = match_part(value, parts)
            if not key:
                continue
            ds = parts[key]['pins']
            checked += 1
            for pin, name in pinmap.items():
                if pin not in ds:
                    problems.append(
                        f'{model_name} {ref} ({value}) pin {pin}={name!r}: '
                        f'pin not in {key} datasheet ({parts[key]["datasheet"]})')
                elif ds[pin] != name:
                    problems.append(
                        f'{model_name} {ref} ({value}) pin {pin}: model {name!r} '
                        f'vs {key} datasheet {ds[pin]!r} ({parts[key]["datasheet"]})')
    return checked


def check_addresses(i2c, problems, report):
    """Compute each addressable device's I2C address from how the model straps it,
    then check it against the datasheet scheme and the declared value address."""
    for path in model_files():
        mod = load_model(path)
        model_name = os.path.basename(path)
        idx = nets_index(mod)
        for ref, spec in getattr(mod, 'COMPONENTS', {}).items():
            if not (isinstance(spec, (list, tuple)) and len(spec) >= 3):
                continue
            value, _fp, pinmap = spec[0], spec[1], spec[2]
            # A value may bundle several I2C devices (e.g. the ZS042 module's
            # 'DS3231_0x68+AT24C32_0x57'); treat each '+'-joined segment as one.
            for seg in value.split('+'):
                key = match_part(seg, i2c)
                if not key:
                    continue
                scheme = i2c[key]
                decl = declared_addr(seg)
                computed, detail = _compute_addr(scheme, ref, pinmap, idx, model_name, problems)
                if computed is None:
                    continue
                report.append((model_name, ref, seg, computed, decl, detail, scheme['datasheet']))
                if decl is not None and decl != computed:
                    problems.append(
                        f'{model_name} {ref} ({seg}): value declares 0x{decl:02X} but '
                        f'straps/datasheet give 0x{computed:02X} [{detail}] ({scheme["datasheet"]})')


def _compute_addr(scheme, ref, pinmap, idx, model_name, problems):
    """Return (address:int|None, detail:str) for one device per its scheme."""
    t = scheme['type']
    if t in ('fixed', 'module'):
        return int(scheme['address'], 16), scheme.get('note', t)
    name_to_pin = {n: p for p, n in pinmap.items()}
    if t == 'strap':                       # base + binary weights on rail-tied pins
        addr = int(scheme['base'], 16)
        rails, bits = scheme['rails'], []
        for apin, weight in scheme['weights'].items():
            pin = name_to_pin.get(apin)
            if pin is None:
                problems.append(f'{model_name} {ref}: no pin named {apin} for addressing')
                return None, ''
            net = idx.get((ref, pin))
            if net not in rails:
                problems.append(f'{model_name} {ref}: {apin} strapped to {net!r}, '
                                f'not a rail ({"/".join(rails)})')
                return None, ''
            addr += weight * rails[net]
            bits.append(f'{apin}={net}')
        return addr, ', '.join(bits)
    if t == 'strap_net':                   # one pin whose tied net selects the address
        pin = name_to_pin.get(scheme['pin'])
        net = idx.get((ref, pin)) if pin else None
        if net in scheme['map']:
            return int(scheme['map'][net], 16), f'{scheme["pin"]}={net}'
        problems.append(f'{model_name} {ref}: {scheme["pin"]} strapped to {net!r}, '
                        f'not in datasheet map')
        return None, ''
    return None, ''


def check():
    with open(DATASHEETS) as fh:
        data = json.load(fh)
    problems, report = [], []
    checked = check_pins(data['parts'], problems)
    check_addresses(data.get('i2c', {}), problems, report)
    return checked, report, problems


def main():
    if not os.path.isfile(DATASHEETS):
        print(f'check-datasheets: missing {os.path.relpath(DATASHEETS)}')
        return 2

    checked, report, problems = check()

    # Show how each I2C device is addressed (deduped across models by ref+addr).
    if report:
        print('I2C addressing (computed from the model straps, datasheet-verified):')
        seen = set()
        for model_name, ref, value, addr, decl, detail, ds in sorted(report, key=lambda r: r[3]):
            tag = (ref, addr, detail)
            if tag in seen:
                continue
            seen.add(tag)
            d = f'  [{detail}]' if detail else ''
            print(f'  0x{addr:02X}  {ref:3} {value:<16} {ds}{d}')
        print()

    if problems:
        print('=' * 70)
        print('ALL STOP - DATASHEET CONTRADICTION')
        print('The board model disagrees with the manufacturer datasheet. Do NOT')
        print('proceed; a human must resolve each item below against the datasheet.')
        print('=' * 70)
        for p in problems:
            print(f'  - {p}')
        return 1

    print(f'check-datasheets OK: {checked} IC pin map(s) and '
          f'{len({(r[1], r[3]) for r in report})} I2C address(es) match their datasheets.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
