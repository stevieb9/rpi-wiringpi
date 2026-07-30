#!/usr/bin/env python3
# Robot wheel generator - self-balancing robot (docs/engineering/robot)
#
# Produces robot-wheel-90mm.stl: a 5-spoke wheel with a lipped flat tread
# channel for stretched inner-tube strips (2-3 butt-jointed layers, seams
# staggered, contact-cemented - NO overlaps, see robot docs), and a mounting
# interface for the common 5 mm-bore aluminium NEMA17 flange coupling.
#
# Hub: Amazon B0DZXP6XZL (Pitertul 5 mm guide-shaft support coupler), listing
# specs: bore 5, barrel Ø10 x 10, flange Ø22 x 2, overall 12, M3 flange
# holes. Hole count/bolt circle are NOT in the listing - modeled as the
# class-standard 4x M3 on a Ø16 circle, hedged with Ø4.0 oversized clearance
# holes (centering comes from the recess register, screws only clamp). If
# the real pattern differs: seat the flange in the recess and use it as its
# own drill jig - drill 3 mm through its holes, counterbore or use button
# heads. Two set screws onto the 5 mm D-shaft.
#   The hub mounts between motor and wheel: the flange seats in the INBOARD
#   recess, and M3x8 socket heads come down from the outboard counterbores
#   into the flange threads. Populate two of the four positions (opposite
#   pair); all four are printed so a wobbly seat can be pulled flat later.
#
# Tread: rubber build-up in the channel must total >= 2 mm so it stands proud
# of the Ø89.5 lips - otherwise PLA touches the ground. Effective rolling
# diameter ~90-91 mm (enter the measured value into the steps/s <-> m/s math
# at V1).
#
# Print: inboard face (flange recess) down, 3-4 perimeters, 20-30 % infill,
# PLA or PETG. No supports are required by design: the one downward span is
# the flange-recess ceiling, a fully-anchored Ø22.6 disc bridge (the membrane
# closes the bore so every chord lands on the recess wall). Supports are the
# operator's call - if adding them, set Support Placement = Touching
# Buildplate so they generate ONLY inside the flange pocket (the scar lands
# on the seat, hidden under the flange) and nowhere else. Top tread lip is
# 45-degree under-chamfered. Symmetric left/right; print two.
#
# Regenerate:  python3 wheel.py [out.stl]   (needs: pip install manifold3d numpy)

import struct
import sys

import numpy as np
from manifold3d import Manifold, set_circular_segments

P = {
    # Tread / rim
    'width':        14.0,   # Overall wheel width (z: 0 inboard .. 14 outboard)
    'lip_od':       89.5,   # Retention lip OD - the largest solid diameter
    'root_od':      87.0,   # Tread channel root OD (rubber wraps here)
    'channel_w':    10.0,   # Tread channel width, centered on the rim
    'rim_id':       78.0,   # Rim bore - leaves 4.5 mm wall under the channel

    # Spoked web
    'web_t':        4.0,    # Web thickness, flush with the inboard face
    'spoke_n':      5,      # Straight spokes
    'spoke_w':      8.0,    # Spoke width
    'web_hub_od':   36.0,   # Web hub collar OD (spokes spring from here)
    'web_rim_id':   74.0,   # Web rim collar ID (spokes land here)

    # Hub boss + flange-coupling interface
    'boss_od':      32.0,   # Hub boss OD
    'boss_l':       10.0,   # Hub boss length from the inboard face
    'recess_d':     22.6,   # Flange recess diameter (Ø22 flange + fit)
    'recess_t':     2.8,    # Flange recess depth, cut into the inboard face
    'bore_d':       8.0,    # Center clearance (shaft tip may pass the flange)
    'bore_membrane': 0.3,   # Sacrificial layer closing the bore at the recess
                            # ceiling so the flange seat bridges fully anchored;
                            # drill out Ø8 only if the shaft pokes past the flange
    'bolt_n':       4,      # M3 positions printed (populate 2, opposite)
    'bolt_bcd':     16.0,   # Flange coupling bolt-circle diameter
    'bolt_hole_d':  4.0,    # M3 clearance, oversized: absorbs ~±0.5 mm of
                            # bolt-circle guess error (recess registers centering)
    'cbore_d':      6.5,    # Socket-head counterbore diameter
    'cbore_depth':  3.0,    # Counterbore depth - M3x8 seats at boss_l - 3

    'segments':     160,    # Circle tessellation
}


def cyl(d, h, z=0.0):
    return Manifold.cylinder(h, d / 2.0, d / 2.0).translate([0.0, 0.0, z])


def ring(od, id_, h, z=0.0):
    return cyl(od, h, z) - cyl(id_, h + 0.2, z - 0.1)


def build(p):
    set_circular_segments(p['segments'])
    w = p['width']

    # Rim shell + web: full disc minus the interior above the web plane
    wheel = cyl(p['lip_od'], w)
    wheel -= cyl(p['rim_id'], w - p['web_t'] + 0.1, p['web_t'])

    # Tread channel between the retention lips. The top lip gets a 45-degree
    # under-chamfer so its step-out prints with no overhang; the bottom lip's
    # step faces up, so it stays square. Flat root width is channel_w minus
    # the chamfer run (cut tread strips to the flat width).
    ch_z = (w - p['channel_w']) / 2.0
    cham = (p['lip_od'] - p['root_od']) / 2.0
    wheel -= ring(p['lip_od'] + 2.0, p['root_od'], p['channel_w'] - cham + 0.01, ch_z)
    cone_z = ch_z + p['channel_w'] - cham
    cone = Manifold.cylinder(cham, p['root_od'] / 2.0, p['lip_od'] / 2.0)
    wheel -= cyl(p['lip_od'] + 2.0, cham, cone_z) - cone.translate([0.0, 0.0, cone_z])

    # Hub boss
    wheel += cyl(p['boss_od'], p['boss_l'])

    # Flange recess in the inboard face; the center bore stops short of the
    # recess ceiling, leaving the sacrificial membrane so the seat face
    # bridges anchored on all sides
    wheel -= cyl(p['recess_d'], p['recess_t'], -0.1)
    z0 = p['recess_t'] + p['bore_membrane']
    wheel -= cyl(p['bore_d'], w - z0 + 0.1, z0)

    # M3 clearance holes + counterbores on the flange bolt circle
    r = p['bolt_bcd'] / 2.0
    for i in range(p['bolt_n']):
        a = 2.0 * np.pi * i / p['bolt_n']
        x, y = r * np.cos(a), r * np.sin(a)
        wheel -= cyl(p['bolt_hole_d'], w + 0.2, -0.1).translate([x, y, 0.0])
        cb_z = p['boss_l'] - p['cbore_depth']
        wheel -= cyl(p['cbore_d'], w - cb_z + 0.1, cb_z).translate([x, y, 0.0])

    # Spoked web: cut the annulus between the hub and rim collars, sparing
    # spoke_n straight bars
    cut = ring(p['web_rim_id'], p['web_hub_od'], p['web_t'] + 0.2, -0.1)
    half_len = p['web_rim_id'] / 2.0 + 1.0
    for i in range(p['spoke_n']):
        bar = Manifold.cube([half_len, p['spoke_w'], p['web_t'] + 0.4])
        bar = bar.translate([0.0, -p['spoke_w'] / 2.0, -0.2])
        cut -= bar.rotate([0.0, 0.0, 360.0 * i / p['spoke_n']])
    wheel -= cut

    return wheel


def write_stl(manifold, path):
    mesh = manifold.to_mesh()
    v = np.asarray(mesh.vert_properties, dtype=np.float64)[:, :3]
    t = np.asarray(mesh.tri_verts, dtype=np.int64)

    a, b, c = v[t[:, 0]], v[t[:, 1]], v[t[:, 2]]
    n = np.cross(b - a, c - a)
    vol = float(np.einsum('ij,ij->i', a, np.cross(b, c)).sum() / 6.0)
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    ln[ln == 0] = 1.0
    n = n / ln

    with open(path, 'wb') as f:
        f.write(b'robot-wheel-90mm (docs/engineering/robot/3d/wheel.py)'.ljust(80, b'\0'))
        f.write(struct.pack('<I', len(t)))
        rec = np.zeros((len(t), 12), dtype=np.float32)
        rec[:, 0:3], rec[:, 3:6], rec[:, 6:9], rec[:, 9:12] = n, a, b, c
        raw = np.zeros((len(t), 50), dtype=np.uint8)
        raw[:, :48] = rec.view(np.uint8).reshape(len(t), 48)
        f.write(raw.tobytes())

    return len(t), vol, v.min(axis=0), v.max(axis=0)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'robot-wheel-90mm.stl'
    tris, vol, lo, hi = write_stl(build(P), out)
    cc = vol / 1000.0
    print(f'{out}: {tris} triangles')
    print(f'volume {cc:.1f} cm^3  (solid PLA ~{cc * 1.24:.0f} g; printed ~{cc * 1.24 * 0.65:.0f} g)')
    print(f'bbox x [{lo[0]:.2f},{hi[0]:.2f}]  y [{lo[1]:.2f},{hi[1]:.2f}]  z [{lo[2]:.2f},{hi[2]:.2f}]')
