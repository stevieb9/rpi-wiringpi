#!/usr/bin/env python3
"""
check-model-drift.py - the test-platform model drift gate.

The board model is hand-curated in board-model.py (the single source of truth).
model-from-tests.py is an INDEPENDENT re-derivation from the test suite. If the
two disagree, one of them is stale: the schematic/KiCad/docs no longer match
what the tests actually exercise. This is exactly the failure that let the t/355
loopback rot unnoticed.

Compares COMPONENTS / NETS / J1FUNC / DRIVER / POWER / SHEETS (nets order-
independent). Prints a per-table report; exits 0 on match, 1 on drift.

Pure stdlib - no rendering, no KiCad, no heavy deps - so it is cheap enough to
run on every `make test`.
"""

import importlib.util
import os
import re
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


def verify_bus_devices(model):
    """Cross-check BUS_DEVICES against the netlist itself (not the other model).

    Each row's declared address/CS must agree with how the chip is actually wired
    in NETS: an SPI CS GPIO with its CS_* net through J1FUNC, and an MCP23017
    address with its A0/A1/A2 strap. Returns a list of human-readable problems.
    """
    comps = model.COMPONENTS
    nets = {nm: set(nodes) for nm, nodes in model.NETS}

    def nets_with(ref, pin):
        return {nm for nm, nodes in nets.items() if (ref, pin) in nodes}

    def j1_gpio(pin):
        m = re.search(r'GPIO(\d+)', model.J1FUNC.get(int(pin), ''))
        return int(m.group(1)) if m else None

    problems = []

    for key, (ref, bus, value, driver, tests, board) in model.BUS_DEVICES.items():
        if ref not in comps:
            problems.append(f'{key}: ref {ref} is not in COMPONENTS')
            continue

        # First pin carrying each pin-name (SDA/SCL/CS/A0..).
        name_to_pin = {}
        for pin, nm in comps[ref][2].items():
            name_to_pin.setdefault(nm, pin)

        if bus == 'i2c':
            sda, scl = name_to_pin.get('SDA'), name_to_pin.get('SCL')
            on_main = bool(sda and scl
                           and 'I2C_SDA' in nets_with(ref, sda)
                           and 'I2C_SCL' in nets_with(ref, scl))
            on_ard = bool(sda and scl
                          and 'ARD_SDA' in nets_with(ref, sda)
                          and 'ARD_SCL' in nets_with(ref, scl))
            if not (on_main or on_ard):
                problems.append(f'{key} ({ref}): not wired to an I2C SDA/SCL net pair')

            # Strapped-address chips (MCP23017 base 0x20) must match their straps.
            if 'MCP23017' in comps[ref][0]:
                strap, ok = 0, True
                for bit, an in enumerate(('A0', 'A1', 'A2')):
                    ap = name_to_pin.get(an)
                    rails = nets_with(ref, ap) if ap else set()
                    if '+3V3' in rails:
                        strap |= (1 << bit)
                    elif 'GND' not in rails:
                        problems.append(f'{key} ({ref}): {an} not strapped to +3V3/GND')
                        ok = False
                        break
                if ok and value != 0x20 + strap:
                    problems.append(
                        f'{key} ({ref}): address 0x{value:02x} '
                        f'!= strap-derived 0x{0x20 + strap:02x}')

        elif bus == 'spi':
            m = re.fullmatch(r'GPIO(\d+)', str(value))
            cs = name_to_pin.get('CS')
            if not m:
                problems.append(f'{key} ({ref}): SPI value {value!r} is not a GPIOnn CS')
            elif cs is None:
                problems.append(f'{key} ({ref}): component has no CS pin')
            else:
                got = None
                for nm in nets_with(ref, cs):
                    for (r2, p2) in nets[nm]:
                        if r2 == 'J1':
                            got = j1_gpio(p2)
                if got is None:
                    problems.append(f'{key} ({ref}): CS net reaches no J1 header pin')
                elif got != int(m.group(1)):
                    problems.append(
                        f'{key} ({ref}): CS GPIO{got} (from net) '
                        f'!= declared {value}')
        else:
            problems.append(f'{key} ({ref}): unknown bus {bus!r}')

    return problems


def verify_electrical(model, facts):
    """Sanity-check board-facts.py ELECTRICAL: valid rail/context, refs that
    exist, numeric currents, and the deliberate scope (onboard + planned only -
    a bench or optional part must never leak into the power budget)."""
    comps = model.COMPONENTS
    problems = []
    for name, e in facts.ELECTRICAL.items():
        if e['rail'] not in ('+3V3', '+5V'):
            problems.append(f'{name}: bad rail {e["rail"]!r}')
        if e['context'] not in ('onboard', 'planned'):
            problems.append(f'{name}: context {e["context"]!r} out of scope '
                            f'(only onboard/planned belong in the budget)')
        if e['ref'] is not None and e['ref'] not in comps:
            problems.append(f'{name}: ref {e["ref"]} not in COMPONENTS')
        for k in ('typ_ma', 'peak_ma'):
            if not isinstance(e[k], (int, float)):
                problems.append(f'{name}: {k} is not numeric')
        if e['sleep_ma'] is not None and not isinstance(e['sleep_ma'], (int, float)):
            problems.append(f'{name}: sleep_ma is neither a number nor None')
    return problems


def main():
    canonical = _load('board-model.py')
    rederived = _load('model-from-tests.py')
    facts = _load('board-facts.py')

    drift = False

    for attr in ('COMPONENTS', 'J1FUNC', 'DRIVER', 'POWER', 'SHEETS', 'BUS_DEVICES'):
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

    # BUS_DEVICES cross-check: the declared addresses/CS must agree with the wiring.
    bus_problems = verify_bus_devices(canonical)
    if bus_problems:
        print(f'  {"BUS_DEVICES":11} INCONSISTENT with the netlist')
        for p in bus_problems:
            print(f'      {p}')
        print('\nBUS MAP INCONSISTENT: a declared I2C address or SPI CS in '
              'BUS_DEVICES\ndoes not match how the chip is wired in NETS.')
        return 1
    print(f'  {"BUS_DEVICES":11} MATCH (wiring cross-check: '
          f'{len(canonical.BUS_DEVICES)} devices)')

    # ELECTRICAL sanity + scope check.
    elec_problems = verify_electrical(canonical, facts)
    if elec_problems:
        print(f'  {"ELECTRICAL":11} INVALID')
        for p in elec_problems:
            print(f'      {p}')
        print('\nELECTRICAL INVALID: board-facts.py ELECTRICAL has a bad or '
              'out-of-scope row.')
        return 1
    print(f'  {"ELECTRICAL":11} OK ({len(facts.ELECTRICAL)} devices, '
          f'onboard + planned)')

    print('\nmodel OK: the re-derivation matches the canonical board-model.py.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
