#!/usr/bin/env python3
# Robot control-board schematic generator - self-balancing robot
# (docs/engineering/robot). Renders robot-board-schematic.jpg: the signal-level
# schematic of the new on-robot board, the four tether signals, and their
# landing on board 1 (Pi host / fan-out - planned, not yet designed).
#
# Deliberately excluded (by design brief): all power rails, grounds,
# decoupling, VMOT wiring, and physical connectors. Switch commons and the
# MPU AD0 / MCP23017 address straps are annotated as text instead of drawn.
#
# Regenerate:  python3 schematic.py   (needs: pip install matplotlib pillow)

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

I2C   = '#1f5fbf'   # I2C bus nets
STEP  = '#b8321f'   # Hardware-PWM step-clock nets
STAT  = '#777777'   # Expander-driven static lines
COIL  = '#1a1a1a'   # Motor coil nets
SWNET = '#0e7a6e'   # Park-switch nets
BOX   = '#222222'

fig, ax = plt.subplots(figsize=(17, 10.5))
ax.set_xlim(0, 104)
ax.set_ylim(0, 64)
ax.axis('off')


def box(x, y, w, h, title, sub=None, dashed=False, lw=1.4, tfs=10.5):
    ax.add_patch(Rectangle((x, y), w, h, fill=False, ec=BOX, lw=lw,
                           ls='--' if dashed else '-'))
    ax.text(x + w / 2, y + h - 1.6, title, ha='center', va='center',
            fontsize=tfs, fontweight='bold', color=BOX)
    if sub:
        ax.text(x + w / 2, y + h - 3.3, sub, ha='center', va='center',
                fontsize=7.5, color='#666666', style='italic')


def pin(x, y, label, side='r', color=BOX, fs=7.5):
    d = 1.4 if side == 'r' else -1.4
    ax.plot([x, x + d], [y, y], color=color, lw=1.1)
    ax.text(x - 0.5 * (d / abs(d)), y, label,
            ha='right' if side == 'r' else 'left', va='center',
            fontsize=fs, color=BOX)
    return x + d


def net(pts, color, lw=1.3):
    xs, ys = zip(*pts)
    ax.plot(xs, ys, color=color, lw=lw, solid_capstyle='round')


# ---------------- Board 1 (planned) + off-robot Pi ----------------
box(1.5, 22, 20, 26, 'BOARD 1', 'Pi host + signal fan-out (planned)',
    dashed=True)
box(3.5, 25, 16, 18.5, 'Raspberry Pi 5', tfs=10)
ax.text(11.5, 26.3, 'off-robot (RP1)', ha='center', fontsize=7,
        color='#666666', style='italic')
p12 = pin(19.5, 39.5, 'GPIO12  PWM0', color=STEP)
p13 = pin(19.5, 36.5, 'GPIO13  PWM1', color=STEP)
psda = pin(19.5, 31.5, 'GPIO2  SDA1', color=I2C)
pscl = pin(19.5, 28.5, 'GPIO3  SCL1', color=I2C)
ax.text(11.5, 23.2, 'routing decided at board-1 design (F5)',
        ha='center', fontsize=7, color='#666666', style='italic')

# ---------------- Tether zone ----------------
ax.add_patch(Rectangle((24, 3), 5.5, 53, fill=True, fc='#efefef', ec='none'))
ax.text(26.75, 57.6, 'umbilical /\ntether', ha='center', fontsize=8.5,
        color='#444444', fontweight='bold')
ax.text(26.75, 54.6, '4 signals\n(power not shown)', ha='center',
        fontsize=6.5, color='#666666', style='italic')

# ---------------- Robot board ----------------
box(31, 2, 57, 57, '', lw=2)
ax.text(86.5, 57.4, 'ROBOT BOARD (new)', ha='right', fontsize=12,
        fontweight='bold', color=BOX)

# MPU-6050
box(35, 46, 15, 9, 'MPU-6050', 'I2C 0x69')
m_sda = pin(35, 49.8, 'SDA', side='l', color=I2C)
m_scl = pin(35, 48.0, 'SCL', side='l', color=I2C)
ax.text(42.5, 46.6, 'AD0 high = 0x69 (0x68 = board-4 DS3231)',
        ha='center', fontsize=5.8, color='#666666')

# MCP23017 expander
box(37, 10, 15, 32, 'MCP23017', 'I2C 0x23 (A2A1A0 strap)')
x_sda = pin(37, 38.2, 'SDA', side='l', color=I2C)
x_scl = pin(37, 36.4, 'SCL', side='l', color=I2C)
gpa_y = [37.5 - i * 1.9 for i in range(6)]
gpb_y = [25.0 - i * 1.9 for i in range(6)]
apins = [pin(52, y, f'GPA{i}', color=STAT) for i, y in enumerate(gpa_y)]
bpins = [pin(52, y, f'GPB{i}', color=STAT) for i, y in enumerate(gpb_y)]
# GPB6/7 park-switch inputs, spaced below the GPB0-5 bank
sw_f = pin(52, 13.2, 'GPB6', color=SWNET)
sw_a = pin(52, 11.4, 'GPB7', color=SWNET)
ax.text(53.8, 13.75, 'SW FORE', fontsize=5.2, color='#888888')
ax.text(53.8, 11.95, 'SW AFT', fontsize=5.2, color='#888888')

# Net name tags for the expander static lines
names_l = ['L DIR', 'L EN', 'L RS', 'L MS1', 'L MS2', 'L MS3']
names_r = ['R DIR', 'R EN', 'R RS', 'R MS1', 'R MS2', 'R MS3']
for y, n in zip(gpa_y, names_l):
    ax.text(53.8, y + 0.55, n, fontsize=5.2, color='#888888')
for y, n in zip(gpb_y, names_r):
    ax.text(53.8, y + 0.55, n, fontsize=5.2, color='#888888')

# A4988 drivers
box(64, 31, 14, 23.5, 'A4988 - LEFT', 'stepper driver')
box(64, 5, 14, 23.5, 'A4988 - RIGHT', 'stepper driver')
sig = ['STEP', 'DIR', 'EN', 'RESET-SLEEP', 'MS1', 'MS2', 'MS3']
l_in, r_in = {}, {}
for i, n in enumerate(sig):
    c = STEP if n == 'STEP' else STAT
    l_in[n] = 49.6 - i * 2.6
    pin(64, l_in[n], n, side='l', color=c)
    r_in[n] = 23.6 - i * 2.6
    pin(64, r_in[n], n, side='l', color=c)
l_out = [(pin(78, 51.5 - i * 3, n, color=COIL), 51.5 - i * 3)
         for i, n in enumerate(['1A', '1B', '2A', '2B'])]
r_out = [(pin(78, 25.5 - i * 3, n, color=COIL), 25.5 - i * 3)
         for i, n in enumerate(['1A', '1B', '2A', '2B'])]
ax.text(71, 29.6, 'RESET-SLEEP: on-board pull-down (inert by default)',
        ha='center', fontsize=5.8, color='#666666')
ax.text(71, 3.6, 'RESET-SLEEP: on-board pull-down (inert by default)',
        ha='center', fontsize=5.8, color='#666666')

# Park switches (lever microswitches - control-theory.md section 6),
# side by side below the expander
box(44.6, 5.2, 10.0, 4.0, 'SW FORE', tfs=8.5)
box(32.5, 5.2, 10.0, 4.0, 'SW AFT', tfs=8.5)
ax.text(49.6, 6.1, 'lever microswitch, NC', ha='center', fontsize=5.6,
        color='#666666', style='italic')
ax.text(37.5, 6.1, 'lever microswitch, NC', ha='center', fontsize=5.6,
        color='#666666', style='italic')
f_p = pin(54.6, 7.2, 'NC', color=SWNET)
a_p = pin(42.5, 7.2, 'NC', color=SWNET)

# ---------------- Motors (chassis, off-board) ----------------
box(92, 37.5, 11, 17, 'NEMA17', dashed=True, tfs=9.5)
ax.text(97.5, 38.7, 'LEFT wheel (chassis)', ha='center', fontsize=6.5,
        color='#666666', style='italic')
box(92, 9.5, 11, 17, 'NEMA17', dashed=True, tfs=9.5)
ax.text(97.5, 10.7, 'RIGHT wheel (chassis)', ha='center', fontsize=6.5,
        color='#666666', style='italic')
lm_y = [50.5, 47.5, 44.5, 41.5]
rm_y = [22.5, 19.5, 16.5, 13.5]
for y, c in zip(lm_y, ['coil A', "coil A'", 'coil B', "coil B'"]):
    pin(92, y, c, side='l', color=COIL)
for y, c in zip(rm_y, ['coil A', "coil A'", 'coil B', "coil B'"]):
    pin(92, y, c, side='l', color=COIL)

# ---------------- Nets ----------------
# STEP clocks across the tether (top and bottom routing channels)
net([(p12, 39.5), (32.2, 39.5), (32.2, 56.2), (62.2, 56.2),
     (62.2, l_in['STEP']), (62.6, l_in['STEP'])], STEP, 1.6)
net([(p13, 36.5), (31.6, 36.5), (31.6, 2.6), (62.2, 2.6),
     (62.2, r_in['STEP']), (62.6, r_in['STEP'])], STEP, 1.6)
ax.text(47, 56.7, 'STEP L - RP1 hardware PWM0 (GPIO12)', fontsize=6.5,
        color=STEP, ha='center')
ax.text(47, 3.2, 'STEP R - RP1 hardware PWM1 (GPIO13)', fontsize=6.5,
        color=STEP, ha='center')

# I2C bus across the tether; trunk feeds MPU and expander (junction dots)
net([(psda, 31.5), (33.6, 31.5), (33.6, 49.8), (35 - 1.4, 49.8)], I2C)
net([(pscl, 28.5), (34.4, 28.5), (34.4, 48.0), (35 - 1.4, 48.0)], I2C)
net([(33.6, 38.2), (37 - 1.4, 38.2)], I2C)
net([(34.4, 36.4), (37 - 1.4, 36.4)], I2C)
ax.plot(33.6, 38.2, marker='o', ms=3.5, color=I2C)
ax.plot(34.4, 36.4, marker='o', ms=3.5, color=I2C)
ax.text(35.8, 44.0, 'I2C bus (shared with the platform)', fontsize=6,
        color=I2C, ha='left')

# Expander -> driver static lines via a vertical routing channel
chan = {'DIR': 56.8, 'EN': 57.35, 'RESET-SLEEP': 57.9,
        'MS1': 58.45, 'MS2': 59.0, 'MS3': 59.55}
for py, name in zip(gpa_y, ['DIR', 'EN', 'RESET-SLEEP', 'MS1', 'MS2', 'MS3']):
    net([(53.4, py), (chan[name], py), (chan[name], l_in[name]),
         (62.6, l_in[name])], STAT, 0.9)
for py, name in zip(gpb_y, ['DIR', 'EN', 'RESET-SLEEP', 'MS1', 'MS2', 'MS3']):
    net([(53.4, py), (chan[name], py), (chan[name], r_in[name]),
         (62.6, r_in[name])], STAT, 0.9)

# Switch nets: FORE up the right side; AFT drops below FORE's box and
# comes up outside it
net([(f_p, 7.2), (56.1, 7.2), (56.1, 13.2), (53.4, 13.2)], SWNET)
net([(a_p, 7.2), (43.9, 4.4), (55.6, 4.4), (55.6, 11.4), (53.4, 11.4)], SWNET)

# Coil nets
for (ox, oy), my in zip(l_out, lm_y):
    net([(ox, oy), (92 - 1.4, my)], COIL)
for (ox, oy), my in zip(r_out, rm_y):
    net([(ox, oy), (92 - 1.4, my)], COIL)

# ---------------- Title + footnotes ----------------
ax.text(52, 62.7, 'Self-balancing robot - control board (signal-level schematic)',
        fontsize=14, fontweight='bold', ha='center')
ax.text(52, 60.9,
        'Excluded by brief: power rails, grounds, decoupling, VMOT, connectors. '
        'Four signals cross the tether; all driver static lines stay on-board '
        'via the MCP23017 (F5).',
        fontsize=8, ha='center', color='#555555')
ax.text(2, 0.6,
        'Board 1 is unbuilt - the Pi lands there and its fan-out fixes the GPIO '
        'routing (F5).  No robot device lives on boards 2-5; the only cross-board '
        'dependencies are the shared I2C bus and the 0x69 MPU address forced by '
        'the board-4 DS3231 at 0x68.  Switch commons go to GND (not drawn); the '
        'switches are the park / auto-erect sensors (control-theory.md, section 6).',
        fontsize=7.5, color='#555555')

plt.savefig('/Users/steve/repos/rpi-wiringpi/docs/engineering/robot/robot-board-schematic.jpg',
            dpi=200, bbox_inches='tight', facecolor='white')
print('wrote robot-board-schematic.jpg')
