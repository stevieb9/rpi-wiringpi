#!/usr/bin/env python3
# NEMA17 L-bracket generator - self-balancing robot (docs/engineering/robot).
# Produces robot-motor-bracket.stl: the motor-to-deck L-bracket. Print TWO
# (the part is symmetric - same STL serves left and right).
#
# Geometry (matches the mechanical drawing's stack-up):
#   - Vertical leg: NEMA17 face pattern - 4x M3 clearance on the 31 mm
#     square, Ø23 pass-through for the Ø22 pilot boss, shaft center 26.5 mm
#     above the deck. The boss hole gets a 45-degree teardrop crown so the
#     big horizontal bore prints sag-free.
#   - Base: 4x M4 SLOTS (10 mm fore-aft travel) - the adjustment that makes
#     the two motor shafts collinear at assembly; fender washers + nyloc per
#     the BOM. Slot columns 30 mm apart.
#   - Side gussets sit OUTSIDE the 42.3 mm motor width (motor body never
#     touches them), 45-degree hypotenuse = support-free.
#
# Verify against the actual motors before printing: NEMA17 standard assumed
# (42.3 face, 31.0 mm hole square, M3, Ø22 x 2 boss).
#
# Print: base down, NO supports, 4-5 perimeters, ~40 % infill. PETG
# preferred over PLA - steppers run warm and PLA creeps near 60 C.
#
# Regenerate:  python3 bracket.py [out.stl]  (needs: pip install manifold3d numpy)

import sys

from manifold3d import CrossSection, Manifold, set_circular_segments

from wheel import cyl, write_stl

P = {
    'leg_w':      50.0,   # Bracket width (> motor 42.3, hosts the gussets)
    'leg_t':      4.0,    # Vertical-leg thickness (motor face bolts to it)
    'leg_h':      48.0,   # Leg height (clears the top M3 holes at z=42)
    'base_d':     36.0,   # Base depth (fore-aft)
    'base_t':     4.0,    # Base thickness
    'shaft_z':    26.5,   # Shaft/boss center above the deck
    'nema_sq':    31.0,   # NEMA17 mounting-hole square
    'm3_d':       3.4,    # M3 clearance
    'boss_d':     23.0,   # Ø22 pilot boss + fit
    'gusset_t':   3.5,    # Gusset thickness (one per side, outboard)
    'gusset_l':   29.0,   # Gusset legs (45-degree hypotenuse)
    'slot_w':     4.5,    # M4 slot width
    'slot_travel': 5.5,   # Slot straight section (total travel ~10 mm)
    'slot_x':     15.0,   # Slot columns at +/- this x
    'slot_y':     (13.0, 27.0),   # Slot rows (fore-aft centers)
    'segments':   96,
}


def yhole(d, cx, cz, h):
    c = Manifold.cylinder(h, d / 2.0, d / 2.0)
    return c.rotate([-90.0, 0.0, 0.0]).translate([cx, -0.1, cz])


def build(p):
    set_circular_segments(p['segments'])
    hw = p['leg_w'] / 2.0

    base = Manifold.cube([p['leg_w'], p['base_d'], p['base_t']])
    base = base.translate([-hw, 0.0, 0.0])
    leg = Manifold.cube([p['leg_w'], p['leg_t'], p['leg_h']])
    leg = leg.translate([-hw, 0.0, 0.0])
    b = base + leg

    # Side gussets, 45-degree hypotenuse: square blank minus a diagonal
    # cutter whose plane is y + z = 2*leg_t + gusset_l (legs exactly
    # gusset_l long); the cutter touches only the gusset blank, never b
    g0 = p['leg_t']
    for xs in (-hw, hw - p['gusset_t']):
        g = Manifold.cube([p['gusset_t'], p['gusset_l'], p['gusset_l']])
        g = g.translate([xs, g0, g0])
        cut = Manifold.cube([p['gusset_t'] + 2.5, 120.0, 120.0], True)
        cut = cut.rotate([45.0, 0.0, 0.0])
        off = 120.0 / 2.0 * 1.4142 / 2.0 + (2.0 * g0 + p['gusset_l']) / 2.0
        cut = cut.translate([xs + p['gusset_t'] / 2.0, off, off])
        b += g - cut

    # Motor face: 4x M3 on the NEMA square + boss bore with teardrop crown
    s = p['nema_sq'] / 2.0
    for mx in (-s, s):
        for mz in (p['shaft_z'] - s, p['shaft_z'] + s):
            b -= yhole(p['m3_d'], mx, mz, p['leg_t'] + 0.2)
    b -= yhole(p['boss_d'], 0.0, p['shaft_z'], p['leg_t'] + 0.2)
    r = p['boss_d'] / 2.0
    t = r * 0.7071
    tri = CrossSection([[(-t, p['shaft_z'] + t), (t, p['shaft_z'] + t),
                         (0.0, p['shaft_z'] + r * 1.4142)]])
    b -= tri.extrude(p['leg_t'] + 0.2).rotate([90.0, 0.0, 0.0]) \
            .translate([0.0, p['leg_t'] + 0.1, 0.0])

    # Base: 4x M4 slots (rounded ends), fore-aft travel
    for sx in (-p['slot_x'], p['slot_x']):
        for sy in p['slot_y']:
            half = p['slot_travel'] / 2.0
            slot = Manifold.cube([p['slot_w'], p['slot_travel'],
                                  p['base_t'] + 0.2])
            slot = slot.translate([sx - p['slot_w'] / 2.0, sy - half, -0.1])
            slot += cyl(p['slot_w'], p['base_t'] + 0.2, -0.1) \
                .translate([sx, sy - half, 0.0])
            slot += cyl(p['slot_w'], p['base_t'] + 0.2, -0.1) \
                .translate([sx, sy + half, 0.0])
            b -= slot
    return b


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'robot-motor-bracket.stl'
    tris, vol, lo, hi = write_stl(build(P), out)
    cc = vol / 1000.0
    print(f'{out}: {tris} triangles')
    print(f'volume {cc:.1f} cm^3  (solid ~{cc * 1.24:.0f} g; printed ~{cc * 1.24 * 0.6:.0f} g each - print two)')
    print(f'bbox x [{lo[0]:.2f},{hi[0]:.2f}]  y [{lo[1]:.2f},{hi[1]:.2f}]  z [{lo[2]:.2f},{hi[2]:.2f}]')
