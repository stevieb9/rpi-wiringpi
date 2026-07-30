#!/usr/bin/env python3
# Robot mechanical-assembly drawing generator - self-balancing robot
# (docs/engineering/robot). Renders robot-mechanical.jpg: side elevation
# (near wheel ghosted), DETAIL A (wheel-hub-motor joint section), DETAIL B
# (rod-deck-ballast junction), balloon callouts + the BOM fastener schedule.
#
# Dimensions are approximate/illustrative (mm-ish); the authoritative specs
# live in bill-of-materials.md (fastener rows) and control-theory.md section 4
# (CoM / ballast) and section 6 (park stops).
#
# Regenerate:  python3 mechanical.py   (needs: pip install matplotlib pillow)

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle

INK = '#222222'
GHOST = '#c8c8c8'
FAST = '#8a1d10'    # Fastener accents
DIM = '#1f5fbf'     # Dimension/annotation accents

fig, ax = plt.subplots(figsize=(15.5, 14))
ax.set_xlim(0, 430)
ax.set_ylim(-52, 372)
ax.set_aspect('equal')
ax.axis('off')


def rect(x, y, w, h, ec=INK, lw=1.3, dashed=False, fc='none'):
    ax.add_patch(Rectangle((x, y), w, h, fill=(fc != 'none'), fc=fc, ec=ec,
                           lw=lw, ls='--' if dashed else '-'))


def balloon(n, bx, by, px, py):
    ax.plot([bx, px], [by, py], color='#999999', lw=0.8)
    ax.add_patch(Circle((bx, by), 6.5, fill=True, fc='white', ec=FAST, lw=1.2))
    ax.text(bx, by, str(n), ha='center', va='center', fontsize=8,
            color=FAST, fontweight='bold')


def nut(x, y, w=9, h=5):
    rect(x - w / 2, y, w, h, lw=1.1)
    ax.plot([x - w / 2 + 1.5, x - w / 2 + 1.5], [y, y + h], color=INK, lw=0.6)
    ax.plot([x + w / 2 - 1.5, x + w / 2 - 1.5], [y, y + h], color=INK, lw=0.6)


def washer(x, y, w=15, h=1.8):
    rect(x - w / 2, y, w, h, lw=1.0)


# ================= Side elevation =================
ax.text(120, 349, 'SIDE ELEVATION', ha='center', fontsize=11,
        fontweight='bold', color=INK)
ax.text(120, 341, 'near wheel ghosted for clarity', ha='center', fontsize=7,
        color='#666666', style='italic')

# Ground
ax.plot([12, 232], [0, 0], color=INK, lw=1.6)
for gx in range(14, 230, 8):
    ax.plot([gx, gx - 5], [0, -5], color=INK, lw=0.7)

# Ghosted near wheel (tread + rim)
ax.add_patch(Circle((120, 45.5), 45.5, fill=False, ec=GHOST, lw=3.2))
ax.add_patch(Circle((120, 45.5), 41.5, fill=False, ec=GHOST, lw=1.2))
ax.add_patch(Circle((120, 45.5), 11.3, fill=False, ec=GHOST, lw=1.2))
ax.text(90, 92, 'wheel Ø≈91 eff.\n(ghosted)', fontsize=6.5, color='#999999',
        ha='center')

# Motor (solid - near wheel removed) + face boss
rect(98.85, 24.35, 42.3, 42.3, lw=1.5)
ax.add_patch(Circle((120, 45.5), 11, fill=False, ec=INK, lw=1.0))
ax.text(120, 58, 'NEMA17', ha='center', fontsize=7.5, color=INK)

# L-bracket: vertical leg on the motor face, horizontal leg on the deck
rect(94.8, 24.35, 3.7, 28, lw=1.4)
rect(80, 21, 18.5, 3.35, lw=1.4)
ax.plot(96.7, 34, marker='o', ms=3.5, color=FAST)
ax.plot(96.7, 46, marker='o', ms=3.5, color=FAST)

# M4 through-bolt: head, deck penetration, washers both faces, nyloc below
ax.plot([86, 86], [10.5, 26.5], color=FAST, lw=1.6)
rect(83.5, 24.35, 5, 2.6, ec=FAST, lw=1.2)          # Bolt head
washer(86, 21.2)                                     # Washer on top face
washer(86, 12.8)                                     # Washer under deck
nut(86, 6.5)                                         # Nyloc

# Bottom deck (1/4" ply)
rect(40, 14.7, 160, 6.35, lw=1.6)
ax.text(206, 16.5, '1/4″ ply', fontsize=6.5, color='#666666')

# Board 6 on standoffs + MPU low
ax.plot([150, 150], [21, 27], color=INK, lw=1.2)
ax.plot([185, 185], [21, 27], color=INK, lw=1.2)
rect(143, 27, 49, 3.2, lw=1.3)
for cx in (150, 160, 170, 181):
    rect(cx - 2.5, 30.2, 5, 3, lw=0.8)
ax.text(167, 37.5, 'board 6', ha='center', fontsize=7, color=INK)
rect(103, 21, 10, 4.5, lw=1.1)
ax.text(108, 28.6, 'MPU', ha='center', fontsize=6, color=INK)

# Threaded rods (fore + aft visible), nut + fender washer at every deck face
for rx in (55, 185):
    ax.plot([rx, rx], [7, 330], color=INK, lw=1.6)
    for ty in range(9, 329, 4):
        ax.plot([rx - 1.8, rx + 1.8], [ty, ty], color=INK, lw=0.4)
    washer(rx, 21.2)
    nut(rx, 23.0)
    washer(rx, 11.6)
    nut(rx, 6.5)
    washer(rx, 295.7)
    nut(rx, 297.5)
    washer(rx, 287.0)
    nut(rx, 281.9)

# Top deck
rect(40, 289.3, 160, 6.35, lw=1.6)

# Ballast stacks on the studs + spare stud
for rx in (55, 185):
    for i in range(6):
        washer(rx, 303.5 + i * 3.2, w=22, h=2.4)
ax.text(120, 311, '~380 g total', ha='center', fontsize=7, color='#666666')

# Park switches fore/aft: body under the deck ends, lever to near-ground,
# bumper screw = hard stop
rect(42, 8.2, 15, 6.5, lw=1.2)
ax.plot([43, 14], [9.5, 7.8], color=INK, lw=1.6)
ax.plot(14, 7.8, marker='o', ms=4, color=INK, mfc='white')
rect(183, 8.2, 15, 6.5, lw=1.2)
ax.plot([197, 226], [9.5, 7.8], color=INK, lw=1.6)
ax.plot(226, 7.8, marker='o', ms=4, color=INK, mfc='white')
ax.plot([64, 64], [14.7, 9.6], color=FAST, lw=1.8)   # Fore bumper screw
ax.plot([176, 176], [14.7, 9.6], color=FAST, lw=1.8)  # Aft bumper screw

# Tether
tx = [176, 190, 205, 213, 216]
ty = [30.2, 60, 140, 250, 345]
ax.plot(tx, ty, color='#666666', lw=1.8, ls=(0, (4, 2)))
ax.text(224, 340, 'umbilical - slack,\nfrom above', fontsize=6.5,
        color='#666666')

# CoM target + H dimension
ax.plot(120, 145.5, marker='x', ms=9, color=DIM, mew=2)
ax.text(128, 145.5, 'target CoM\n≈ 10 cm above axle', fontsize=6.5,
        color=DIM, va='center')
ax.annotate('', xy=(232, 292.5), xytext=(232, 45.5),
            arrowprops=dict(arrowstyle='<->', color=DIM, lw=1.1))
ax.text(238, 169, 'H ≈ 25 cm', fontsize=7, color=DIM, rotation=90,
        va='center')

# Side-view balloons
balloon(3, 74, 52, 96.7, 46)
balloon(4, 68, 33, 84.5, 25.5)
balloon(5, 24, 30, 53, 23.5)
balloon(6, 30, 308, 44, 306)
balloon(7, 30, 15.5, 43, 11.5)
balloon(8, 74, 6, 64.5, 10.5)
balloon(9, 143, 45, 150, 25)

# ================= DETAIL A: wheel-hub-motor joint =================
ax.text(330, 349, 'DETAIL A - wheel ↔ hub ↔ motor', ha='center',
        fontsize=10, fontweight='bold', color=INK)
ay = 280
rect(262, ay - 45, 8, 90, lw=1.5)
ax.text(266, ay - 53, 'motor\nface', ha='center', fontsize=6.5, color=INK)
ax.plot([270, 344], [ay + 2.5, ay + 2.5], color=INK, lw=1.1)   # Shaft Ø5
ax.plot([270, 344], [ay - 2.5, ay - 2.5], color=INK, lw=1.1)
ax.plot([270, 348], [ay, ay], color='#999999', lw=0.6, ls='-.')
ax.text(277, ay + 5.5, 'shaft', fontsize=5.2, color=INK, ha='center')
rect(292, ay - 10, 26, 20, lw=1.4)                              # Barrel Ø10
rect(303, ay + 10, 6, 6, ec=FAST, lw=1.3)                       # Set screw
rect(318, ay - 22, 5, 44, lw=1.4)                               # Flange Ø22
rect(323, ay - 32, 26, 64, lw=1.5)                              # Wheel boss
rect(318, ay - 22, 5, 44, lw=0.5)
ax.plot([323, 323], [ay - 22, ay + 22], color=INK, lw=0.5)      # Recess line
for sy in (ay + 16, ay - 16):                                   # M3 screws
    ax.plot([351, 320], [sy, sy], color=FAST, lw=1.8)
    rect(349, sy - 2.6, 4.5, 5.2, ec=FAST, lw=1.2)
ax.text(336, ay - 50, 'wheel boss\n(flange recess inboard,\ncounterbores '
        'outboard)', ha='center', fontsize=6, color=INK)
ax.text(305, ay - 20, 'hub barrel\n(5 mm D-shaft bore)', ha='center',
        fontsize=6, color=INK)
balloon(1, 372, ay + 30, 351.5, ay + 16)
balloon(2, 290, ay + 28, 306, ay + 14)

# ================= DETAIL B: rod-deck-ballast junction =================
ax.text(330, 165, 'DETAIL B - rod ↔ deck + ballast', ha='center',
        fontsize=10, fontweight='bold', color=INK)
bx = 330
ax.plot([bx, bx], [30, 150], color=INK, lw=2.0)
for ty in range(32, 149, 4):
    ax.plot([bx - 2.5, bx + 2.5], [ty, ty], color=INK, lw=0.5)
rect(292, 78, 76, 8, lw=1.5)                                    # Deck section
ax.text(374, 80.5, '1/4″ ply', fontsize=6.5, color=INK)
washer(bx, 86.4, w=24, h=2.4)                                   # Above deck
nut(bx, 89.2, w=13, h=7)
washer(bx, 73.2, w=24, h=2.4)                                   # Below deck
nut(bx, 65.8, w=13, h=7)
for i in range(5):                                              # Ballast
    washer(bx, 100 + i * 4.2, w=30, h=3.2)
ax.text(357, 108, 'ballast:\nstacked washers', fontsize=6.5, color=INK)
ax.annotate('', xy=(310, 150), xytext=(310, 124),
            arrowprops=dict(arrowstyle='->', color=DIM, lw=1.0))
ax.text(300, 140, '≥3 cm\nspare stud', fontsize=6, color=DIM,
        ha='right')
balloon(5, 288, 95, 322, 91)
balloon(6, 288, 112, 314, 106)

# ================= Fastener legend =================
LEGEND = [
    ('1', 'M3×8 SHCS ×2 per wheel → hub flange (opposite '
          'pair; 4 positions printed)'),
    ('2', 'Hub set screws ×2 - on the shaft flat, threadlocked'),
    ('3', 'M3×8 ×4 per motor → L-bracket (NEMA17 face '
          'pattern)'),
    ('4', 'M4×20 through-bolt + fender washers both faces + nyloc: '
          'bracket → deck (never wood screws in 1/4″ ply)'),
    ('5', '3/16″ rod: nut + fender washer above AND below each deck'),
    ('6', 'Ballast ≈380 g: washers/nuts stacked on the studs (tuning '
          'knob, V8)'),
    ('7', 'M2.5/M3 ×2 per switch - SLOTTED mount (park-angle tuning, '
          '§6)'),
    ('8', 'M3 bumper screw - the hard stop takes the park load; the switch '
          'lever is the sensor only'),
    ('9', 'M3 standoffs ×4: board 6 → deck'),
]
ax.plot([12, 418], [-8, -8], color='#bbbbbb', lw=0.8)
for i, (n, txt) in enumerate(LEGEND):
    col, row = divmod(i, 5)
    x0 = 16 + col * 212
    y0 = -15 - row * 6.5
    ax.add_patch(Circle((x0, y0), 2.6, fill=True, fc='white', ec=FAST, lw=1))
    ax.text(x0, y0, n, ha='center', va='center', fontsize=5.4, color=FAST,
            fontweight='bold')
    ax.text(x0 + 5.5, y0, txt, fontsize=6.2, color=INK, va='center')

ax.text(215, 370, 'Self-balancing robot - mechanical assembly (board 6 '
                  'chassis)', fontsize=13.5, fontweight='bold', ha='center')
ax.text(215, 362.5, 'Dimensions approximate (mm); authoritative specs: BOM '
                    'fastener rows, control-theory §4 (CoM/ballast) + '
                    '§6 (park stops). Rest lean ≈10° on the '
                    'bumper screws, switch levers pressed.',
        fontsize=7, ha='center', color='#555555')

plt.savefig('/Users/steve/repos/rpi-wiringpi/docs/engineering/robot/'
            'robot-mechanical.jpg', dpi=200, bbox_inches='tight',
            facecolor='white')
print('wrote robot-mechanical.jpg')
