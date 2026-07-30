#!/usr/bin/env python3
# Board 6 (robot control board) schematic generator - self-balancing robot
# (docs/engineering/robot). Renders two sheets:
#
#   robot-board-schematic.jpg - signal-level schematic: MPU-6050 (0x69),
#     MCP23017 (0x23), ADS1015 (0x49) + ADXL335 (analog, B1 cross-check),
#     2x A4988, park switches, and the four tether signals landing on
#     board 1 (Pi host / fan-out - planned).
#
#   robot-board-power.jpg - power topology: 3V3 in via JST, 12 V in via
#     screw terminal, both from board 1; all grounds commoned on board 1;
#     bypass/bulk caps and the two mandatory 100 uF VMOT electrolytics.
#
#   robot-board-full.jpg - merged sheet: the signal schematic plus a power
#     strip (J1/J2, rails, bulk + VMOT caps) with per-IC power net flags.
#
# The 12 V source upstream of board 1 is out of scope. Physical connectors
# appear only on the power/full sheets (J1/J2), per the design brief.
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
ANA   = '#7a4fa3'   # ADXL335 analog axes
P3V3  = '#c77d0a'   # 3V3 rail (power sheet)
P12V  = '#a51d1d'   # 12 V rail (power sheet)
PGND  = '#1a1a1a'   # Ground (power sheet)
BOX   = '#222222'

OUT = '/Users/steve/repos/rpi-wiringpi/docs/engineering/robot/'


def mkbox(ax, x, y, w, h, title, sub=None, dashed=False, lw=1.4, tfs=10.5):
    ax.add_patch(Rectangle((x, y), w, h, fill=False, ec=BOX, lw=lw,
                           ls='--' if dashed else '-'))
    ax.text(x + w / 2, y + h - 1.6, title, ha='center', va='center',
            fontsize=tfs, fontweight='bold', color=BOX)
    if sub:
        ax.text(x + w / 2, y + h - 3.3, sub, ha='center', va='center',
                fontsize=7.5, color='#666666', style='italic')


def mkpin(ax, x, y, label, side='r', color=BOX, fs=7.5):
    d = 1.4 if side == 'r' else -1.4
    ax.plot([x, x + d], [y, y], color=color, lw=1.1)
    ax.text(x - 0.5 * (d / abs(d)), y, label,
            ha='right' if side == 'r' else 'left', va='center',
            fontsize=fs, color=BOX)
    return x + d


def mknet(ax, pts, color, lw=1.3):
    xs, ys = zip(*pts)
    ax.plot(xs, ys, color=color, lw=lw, solid_capstyle='round')


# =====================================================================
# Shared signal-level drawing (used by the signals sheet and the full sheet)
# =====================================================================
def draw_signals(ax, power=False):
    # Board 1 (planned) + off-robot Pi
    if power:
        mkbox(ax, 1.5, 13, 20, 35, 'BOARD 1',
              'Pi host + power/signal fan-out (planned)', dashed=True)
    else:
        mkbox(ax, 1.5, 22, 20, 26, 'BOARD 1',
              'Pi host + signal fan-out (planned)', dashed=True)
    mkbox(ax, 3.5, 25, 16, 18.5, 'Raspberry Pi 5', tfs=10)
    ax.text(11.5, 26.3, 'off-robot (RP1)', ha='center', fontsize=7,
            color='#666666', style='italic')
    p12 = mkpin(ax, 19.5, 39.5, 'GPIO12  PWM0', color=STEP)
    p13 = mkpin(ax, 19.5, 36.5, 'GPIO13  PWM1', color=STEP)
    psda = mkpin(ax, 19.5, 31.5, 'GPIO2  SDA1', color=I2C)
    pscl = mkpin(ax, 19.5, 28.5, 'GPIO3  SCL1', color=I2C)
    ax.text(11.5, 23.2, 'routing decided at board-1 design (F5)',
            ha='center', fontsize=7, color='#666666', style='italic')

    # Tether
    ax.add_patch(Rectangle((24, -8 if power else 3), 5.5, 64 if power else 53,
                           fill=True, fc='#efefef', ec='none'))
    ax.text(26.75, 57.6, 'umbilical /\ntether', ha='center', fontsize=8.5,
            color='#444444', fontweight='bold')
    if power:
        ax.text(26.75, 54.6, '4 signals +\n2 power pairs', ha='center',
                fontsize=6.5, color='#666666', style='italic')
    else:
        ax.text(26.75, 54.6, '4 signals\n(power: see\npower sheet)',
                ha='center', fontsize=6.5, color='#666666', style='italic')

    # Board 6 outline (extends down over the power strip on the full sheet)
    if power:
        mkbox(ax, 31, -8.5, 57, 67.5, '', lw=2)
    else:
        mkbox(ax, 31, 2, 57, 57, '', lw=2)
    ax.text(86.5, 57.4, 'ROBOT BOARD (board 6)', ha='right', fontsize=12,
            fontweight='bold', color=BOX)

    # MPU-6050
    mkbox(ax, 35, 46, 10, 9, 'MPU-6050', 'I2C 0x69', tfs=9)
    mkpin(ax, 35, 49.8, 'SDA', side='l', color=I2C)
    mkpin(ax, 35, 48.0, 'SCL', side='l', color=I2C)
    ax.text(40, 46.7, 'AD0 high = 0x69', ha='center', fontsize=5.6,
            color='#666666')

    # ADS1015
    mkbox(ax, 46.5, 46, 10, 9, 'ADS1015', 'I2C 0x49', tfs=9)
    mkpin(ax, 46.5, 50.8, 'SDA', side='l', color=I2C, fs=6.5)
    mkpin(ax, 46.5, 49.0, 'SCL', side='l', color=I2C, fs=6.5)
    a0 = mkpin(ax, 56.5, 51.0, 'A0', color=ANA, fs=6.5)
    a1 = mkpin(ax, 56.5, 49.2, 'A1', color=ANA, fs=6.5)
    a2 = mkpin(ax, 56.5, 47.4, 'A2', color=ANA, fs=6.5)
    ax.text(51.5, 46.7, 'ADDR to VDD = 0x49', ha='center', fontsize=5.6,
            color='#666666')

    # ADXL335 (analog, B1 redundant tilt cross-check)
    mkbox(ax, 59.5, 46, 10.5, 9, 'ADXL335', 'analog 3-axis accel', tfs=9)
    x_x = mkpin(ax, 59.5, 51.0, 'X', side='l', color=ANA, fs=6.5)
    x_y = mkpin(ax, 59.5, 49.2, 'Y', side='l', color=ANA, fs=6.5)
    x_z = mkpin(ax, 59.5, 47.4, 'Z', side='l', color=ANA, fs=6.5)
    ax.text(64.75, 46.7, 'Cx/Cy/Cz filter caps on breakout', ha='center',
            fontsize=5.4, color='#666666')

    # MCP23017 expander
    mkbox(ax, 37, 10, 15, 32, 'MCP23017', 'I2C 0x23 (A2A1A0 strap)')
    mkpin(ax, 37, 38.2, 'SDA', side='l', color=I2C)
    mkpin(ax, 37, 36.4, 'SCL', side='l', color=I2C)
    gpa_y = [37.5 - i * 1.9 for i in range(6)]
    gpb_y = [25.0 - i * 1.9 for i in range(6)]
    for i, y in enumerate(gpa_y):
        mkpin(ax, 52, y, f'GPA{i}', color=STAT)
    for i, y in enumerate(gpb_y):
        mkpin(ax, 52, y, f'GPB{i}', color=STAT)
    sw_f_pin = mkpin(ax, 52, 13.2, 'GPB6', color=SWNET)
    sw_a_pin = mkpin(ax, 52, 11.4, 'GPB7', color=SWNET)
    ax.text(53.8, 13.75, 'SW FORE', fontsize=5.2, color='#888888')
    ax.text(53.8, 11.95, 'SW AFT', fontsize=5.2, color='#888888')
    names_l = ['L DIR', 'L EN', 'L RS', 'L MS1', 'L MS2', 'L MS3']
    names_r = ['R DIR', 'R EN', 'R RS', 'R MS1', 'R MS2', 'R MS3']
    for y, n in zip(gpa_y, names_l):
        ax.text(53.8, y + 0.55, n, fontsize=5.2, color='#888888')
    for y, n in zip(gpb_y, names_r):
        ax.text(53.8, y + 0.55, n, fontsize=5.2, color='#888888')

    # A4988 drivers
    mkbox(ax, 72, 28, 14, 23.5, 'A4988 - LEFT', 'stepper driver')
    mkbox(ax, 72, 3, 14, 23.5, 'A4988 - RIGHT', 'stepper driver')
    sig = ['STEP', 'DIR', 'EN', 'RESET-SLEEP', 'MS1', 'MS2', 'MS3']
    l_in, r_in = {}, {}
    for i, n in enumerate(sig):
        c = STEP if n == 'STEP' else STAT
        l_in[n] = 46.6 - i * 2.6
        mkpin(ax, 72, l_in[n], n, side='l', color=c)
        r_in[n] = 21.6 - i * 2.6
        mkpin(ax, 72, r_in[n], n, side='l', color=c)
    l_out = [(mkpin(ax, 86, 48.5 - i * 3, n, color=COIL), 48.5 - i * 3)
             for i, n in enumerate(['1A', '1B', '2A', '2B'])]
    r_out = [(mkpin(ax, 86, 23.5 - i * 3, n, color=COIL), 23.5 - i * 3)
             for i, n in enumerate(['1A', '1B', '2A', '2B'])]

    # Park switches
    mkbox(ax, 44.6, 5.2, 10.0, 4.0, 'SW FORE', tfs=8.5)
    mkbox(ax, 32.5, 5.2, 10.0, 4.0, 'SW AFT', tfs=8.5)
    ax.text(49.6, 6.1, 'lever microswitch, NC', ha='center', fontsize=5.6,
            color='#666666', style='italic')
    ax.text(37.5, 6.1, 'lever microswitch, NC', ha='center', fontsize=5.6,
            color='#666666', style='italic')
    f_p = mkpin(ax, 54.6, 7.2, 'NC', color=SWNET)
    a_p = mkpin(ax, 42.5, 7.2, 'NC', color=SWNET)

    # Motors (chassis)
    mkbox(ax, 92, 37.5, 11, 17, 'NEMA17', dashed=True, tfs=9.5)
    ax.text(97.5, 38.7, 'LEFT wheel (chassis)', ha='center', fontsize=6.5,
            color='#666666', style='italic')
    mkbox(ax, 92, 9.5, 11, 17, 'NEMA17', dashed=True, tfs=9.5)
    ax.text(97.5, 10.7, 'RIGHT wheel (chassis)', ha='center', fontsize=6.5,
            color='#666666', style='italic')
    lm_y, rm_y = [50.5, 47.5, 44.5, 41.5], [22.5, 19.5, 16.5, 13.5]
    for y, c in zip(lm_y, ['coil A', "coil A'", 'coil B', "coil B'"]):
        mkpin(ax, 92, y, c, side='l', color=COIL)
    for y, c in zip(rm_y, ['coil A', "coil A'", 'coil B', "coil B'"]):
        mkpin(ax, 92, y, c, side='l', color=COIL)

    # --- nets ---
    # STEP clocks (top and bottom channels, verticals right of the lanes)
    mknet(ax, [(p12, 39.5), (32.2, 39.5), (32.2, 56.2), (71.3, 56.2),
               (71.3, l_in['STEP']), (70.6, l_in['STEP'])], STEP, 1.6)
    mknet(ax, [(p13, 36.5), (31.6, 36.5), (31.6, 2.6), (71.3, 2.6),
               (71.3, r_in['STEP']), (70.6, r_in['STEP'])], STEP, 1.6)
    ax.text(50, 56.8, 'STEP L - RP1 hardware PWM0 (GPIO12)', fontsize=6.5,
            color=STEP, ha='center')
    ax.text(50, 3.2, 'STEP R - RP1 hardware PWM1 (GPIO13)', fontsize=6.5,
            color=STEP, ha='center')

    # I2C trunk + taps (dots = junctions)
    mknet(ax, [(psda, 31.5), (33.6, 31.5), (33.6, 49.8), (35 - 1.4, 49.8)], I2C)
    mknet(ax, [(pscl, 28.5), (34.4, 28.5), (34.4, 48.0), (35 - 1.4, 48.0)], I2C)
    mknet(ax, [(33.6, 38.2), (37 - 1.4, 38.2)], I2C)
    mknet(ax, [(34.4, 36.4), (37 - 1.4, 36.4)], I2C)
    mknet(ax, [(33.6, 44.0), (46.0, 44.0), (46.0, 50.8), (46.5 - 1.4, 50.8)], I2C)
    mknet(ax, [(34.4, 42.8), (45.4, 42.8), (45.4, 49.0), (46.5 - 1.4, 49.0)], I2C)
    for x, y in [(33.6, 38.2), (34.4, 36.4), (33.6, 44.0), (34.4, 42.8)]:
        ax.plot(x, y, marker='o', ms=3.2, color=I2C)
    ax.text(36.2, 44.7, 'I2C bus (shared with the platform)', fontsize=6,
            color=I2C, ha='left')

    # ADXL axes into the ADC
    for (sx, sy), tx in zip([(a0, 51.0), (a1, 49.2), (a2, 47.4)],
                            [x_x, x_y, x_z]):
        mknet(ax, [(sx, sy), (tx, sy)], ANA)

    # Expander -> driver static lines via vertical lanes
    chan = {'DIR': 62.5, 'EN': 63.05, 'RESET-SLEEP': 63.6,
            'MS1': 64.15, 'MS2': 64.7, 'MS3': 65.25}
    order = ['DIR', 'EN', 'RESET-SLEEP', 'MS1', 'MS2', 'MS3']
    for py, name in zip(gpa_y, order):
        mknet(ax, [(53.4, py), (chan[name], py), (chan[name], l_in[name]),
                   (70.6, l_in[name])], STAT, 0.9)
    for py, name in zip(gpb_y, order):
        mknet(ax, [(53.4, py), (chan[name], py), (chan[name], r_in[name]),
                   (70.6, r_in[name])], STAT, 0.9)

    # Switch nets
    mknet(ax, [(f_p, 7.2), (56.1, 7.2), (56.1, 13.2), (53.4, 13.2)], SWNET)
    mknet(ax, [(a_p, 7.2), (43.9, 4.4), (55.6, 4.4), (55.6, 11.4),
               (53.4, 11.4)], SWNET)

    # Coil nets
    for (ox, oy), my in zip(l_out, lm_y):
        mknet(ax, [(ox, oy), (92 - 1.4, my)], COIL)
    for (ox, oy), my in zip(r_out, rm_y):
        mknet(ax, [(ox, oy), (92 - 1.4, my)], COIL)

    if power:
        draw_power_strip(ax)


def sheet_signals():
    fig, ax = plt.subplots(figsize=(17, 10.5))
    ax.set_xlim(0, 104)
    ax.set_ylim(0, 64)
    ax.axis('off')
    draw_signals(ax, power=False)
    ax.text(52, 62.7, 'Self-balancing robot - board 6 signals',
            fontsize=14, fontweight='bold', ha='center')
    ax.text(52, 60.9,
            'Four signals cross the tether; all driver static lines stay '
            'on-board via the MCP23017 (F5). Power on the power sheet; '
            'connectors on the power sheet only.',
            fontsize=8, ha='center', color='#555555')
    ax.text(2, 1.4,
            'Board 1 is unbuilt - the Pi lands there and its fan-out fixes the '
            'GPIO routing (F5).  No robot device lives on boards 2-5; '
            'cross-board dependencies: shared I2C bus; MPU at 0x69 (0x68 = '
            'board-4 DS3231); ADS1015 at 0x49 (0x48 = board-2 ADS1015, t/360 '
            'gains an address parameter).',
            fontsize=7.5, color='#555555')
    ax.text(2, 0.1,
            'ADXL335 + ADS1015 wire in the B1 redundant tilt cross-check.  '
            'RESET-SLEEP nets carry on-board pull-downs (inert by default).  '
            'Switch commons go to GND; switches are the park / auto-erect '
            'sensors (control-theory.md, section 6).',
            fontsize=7.5, color='#555555')

    plt.savefig(OUT + 'robot-board-schematic.jpg', dpi=200,
                bbox_inches='tight', facecolor='white')
    plt.close(fig)


# =====================================================================
# Sheet 2 - power topology
# =====================================================================
def cap(ax, x, ytop, ybot, label, bulk=False):
    mid = (ytop + ybot) / 2
    hw = 1.1
    ax.plot([x, x], [ytop, mid + 0.45], color=PGND, lw=1.1)
    ax.plot([x - hw, x + hw], [mid + 0.45, mid + 0.45], color=PGND, lw=1.6)
    ax.plot([x - hw, x + hw], [mid - 0.45, mid - 0.45], color=PGND, lw=1.6)
    ax.plot([x, x], [mid - 0.45, ybot], color=PGND, lw=1.1)
    ax.text(x + 1.5, mid, label, fontsize=6 if not bulk else 6.5,
            va='center', color='#444444')


def sheet_power():
    fig, ax = plt.subplots(figsize=(17, 7.2))
    ax.set_xlim(0, 104)
    ax.set_ylim(0, 44)
    ax.axis('off')

    # Board 1
    mkbox(ax, 2, 8, 22, 28, 'BOARD 1', 'power fan-out (planned)', dashed=True)
    ax.text(13, 30.5, '3V3 from the Pi rail', fontsize=7.5, color='#555555',
            ha='center')
    ax.text(13, 10.3, '12 V motor supply in\n(source TBD - out of scope)',
            fontsize=7.5, color='#555555', ha='center')
    v33 = mkpin(ax, 24, 27.5, '3V3', color=P3V3)
    g1 = mkpin(ax, 24, 25.0, 'GND', color=PGND)
    v12 = mkpin(ax, 24, 15.5, '12V', color=P12V)
    g2 = mkpin(ax, 24, 13.0, 'GND', color=PGND)
    # Grounds commoned inside board 1
    mknet(ax, [(22.6, 25.0), (20.5, 25.0), (20.5, 13.0), (22.6, 13.0)], PGND)
    ax.plot(20.5, 19, marker='*', ms=11, color=PGND)
    ax.text(19.4, 19, 'all grounds\ncommoned here', fontsize=6.5,
            ha='right', va='center', color='#444444')

    # Tether
    ax.add_patch(Rectangle((27, 5), 5, 32, fill=True, fc='#efefef', ec='none'))
    ax.text(29.5, 38.5, 'umbilical /\ntether', ha='center', fontsize=8,
            color='#444444', fontweight='bold')
    ax.text(29.5, 6.3, '2 power pairs', ha='center', fontsize=6.5,
            color='#666666', style='italic')

    # Board 6
    mkbox(ax, 34, 2, 68, 40, '', lw=2)
    ax.text(100.5, 40.2, 'ROBOT BOARD (board 6)', ha='right', fontsize=12,
            fontweight='bold', color=BOX)

    # Entry connectors (the only connectors drawn anywhere)
    mkbox(ax, 34.5, 24.5, 5.5, 5.5, 'J1', tfs=8)
    ax.text(37.25, 25.6, 'JST-PH', ha='center', fontsize=6, color='#666666')
    mkbox(ax, 34.5, 11.0, 5.5, 5.5, 'J2', tfs=8)
    ax.text(37.25, 12.1, 'screw\nterm.', ha='center', fontsize=5.6,
            color='#666666')

    # Feed wires across the tether into the connectors
    mknet(ax, [(v33, 27.5), (34.5, 27.5)], P3V3, 1.6)
    mknet(ax, [(g1, 25.0), (34.5, 25.0)], PGND, 1.6)
    mknet(ax, [(v12, 15.5), (34.5, 15.5)], P12V, 1.9)
    mknet(ax, [(g2, 13.0), (34.5, 13.0)], PGND, 1.9)

    # Rails
    mknet(ax, [(40, 27.5), (42.5, 27.5), (42.5, 33), (99, 33)], P3V3, 1.6)
    ax.text(97, 34, '3V3 rail', fontsize=7, color=P3V3, ha='right')
    mknet(ax, [(40, 15.5), (44, 15.5), (44, 9.5), (97.5, 9.5)], P12V, 1.9)
    ax.text(96, 10.5, '12 V rail (VMOT only)', fontsize=7, color=P12V,
            ha='right')
    mknet(ax, [(40, 25.0), (41.5, 25.0), (41.5, 5), (99, 5)], PGND, 1.6)
    mknet(ax, [(40, 13.0), (41.5, 13.0)], PGND, 1.9)
    ax.plot(41.5, 13.0, marker='o', ms=3.5, color=PGND)
    ax.text(97, 3.4, 'GND plane - commoned to board 1 via both pairs; '
                     'park-switch commons land here', fontsize=6.5,
            color='#444444', ha='right')

    # Bulk cap at the 3V3 entry
    cap(ax, 43.6, 33, 5, '10 uF bulk', bulk=True)

    # 3V3 devices
    devs = [('MPU-6050', 47.5), ('MCP23017', 57.0), ('ADS1015', 66.5),
            ('ADXL335', 76.0)]
    for name, x in devs:
        mkbox(ax, x, 18, 8.6, 6.5, name, tfs=7.5)
        ax.text(x + 4.3, 19.2, '+0.1 uF bypass', ha='center', fontsize=5.4,
                color='#666666')
        mknet(ax, [(x + 4.3, 33), (x + 4.3, 24.5)], P3V3, 1.1)
        mknet(ax, [(x + 6.3, 18), (x + 6.3, 5)], PGND, 1.1)

    # A4988 drivers: VDD from 3V3, VMOT from 12 V, 100 uF at each VMOT
    for name, x in [('A4988 - L', 85.5), ('A4988 - R', 93.5)]:
        mkbox(ax, x, 13.5, 7.2, 11, name, tfs=7.5)
        ax.text(x + 3.6, 15.6, 'VDD logic\n+ VMOT', ha='center', fontsize=5.4,
                color='#666666')
        mknet(ax, [(x + 2.4, 33), (x + 2.4, 24.5)], P3V3, 1.1)
        mknet(ax, [(x + 3.6, 13.5), (x + 3.6, 9.5)], P12V, 1.4)
        mknet(ax, [(x + 5.4, 13.5), (x + 5.4, 5)], PGND, 1.1)
    cap(ax, 84.0, 9.5, 5, '100 uF')
    cap(ax, 92.0, 9.5, 5, '100 uF')
    ax.text(82.6, 7.2, 'mandatory - fit\nbefore VMOT', fontsize=5.4,
            color='#8a1d10', ha='right', va='center')

    ax.text(52, 43.2, 'Self-balancing robot - board 6 power topology',
            fontsize=14, fontweight='bold', ha='center')
    ax.text(2, 0.4,
            'Signals on the signals sheet. 0.1 uF bypass values are '
            'datasheet-standard placeholders - confirm each at board-6 '
            'layout; the two 100 uF VMOT electrolytics are required by the '
            'A4988. 12 V touches nothing but the two VMOT pins.',
            fontsize=7.5, color='#555555')

    plt.savefig(OUT + 'robot-board-power.jpg', dpi=200,
                bbox_inches='tight', facecolor='white')
    plt.close(fig)


def draw_power_strip(ax):
    """Full-sheet extras: board-1 power pins, J1/J2, rails, caps, IC flags."""
    # Board-1 power pins + ground commoning star
    v33 = mkpin(ax, 21.5, 21, '3V3', color=P3V3, fs=6.5)
    g1 = mkpin(ax, 21.5, 19, 'GND', color=PGND, fs=6.5)
    v12 = mkpin(ax, 21.5, 17, '12V', color=P12V, fs=6.5)
    g2 = mkpin(ax, 21.5, 15, 'GND', color=PGND, fs=6.5)
    mknet(ax, [(21.5, 19), (20.3, 19), (20.3, 15), (21.5, 15)], PGND, 1.0)
    ax.plot(20.3, 17, marker='*', ms=9, color=PGND)
    ax.text(19.6, 17, 'grounds\ncommoned', fontsize=5.2, ha='right',
            va='center', color='#444444')
    ax.text(11.5, 14.0, '12 V source TBD - out of scope', fontsize=6,
            ha='center', color='#666666', style='italic')

    # Power pairs across the tether into J1 (JST) and J2 (screw terminal)
    mknet(ax, [(v33, 21), (30.2, 21), (30.2, 0.3), (33, 0.3)], P3V3, 1.5)
    mknet(ax, [(g1, 19), (30.8, 19), (30.8, -1.5), (33, -1.5)], PGND, 1.5)
    mknet(ax, [(v12, 17), (29.4, 17), (29.4, -4.2), (33, -4.2)], P12V, 1.8)
    mknet(ax, [(g2, 15), (28.8, 15), (28.8, -6), (33, -6)], PGND, 1.8)
    mkbox(ax, 33, -2.5, 5, 4, 'J1', tfs=7.5)
    ax.text(35.5, -1.9, 'JST-PH', ha='center', fontsize=5.2, color='#666666')
    mkbox(ax, 33, -7.5, 5, 4, 'J2', tfs=7.5)
    ax.text(35.5, -6.9, 'screw term.', ha='center', fontsize=5.2,
            color='#666666')

    # Rails out of the connectors
    mknet(ax, [(38, 0.3), (64.5, 0.3)], P3V3, 1.5)
    ax.text(65.2, 0.3, '3V3 - every IC VDD (0.1 uF bypass each)', fontsize=5.5,
            color=P3V3, va='center')
    mknet(ax, [(38, -4.2), (64.5, -4.2)], P12V, 1.8)
    ax.text(65.2, -4.2, '12 V - VMOT L/R only', fontsize=5.5, color=P12V,
            va='center')
    mknet(ax, [(38, -1.5), (40.4, -1.5), (40.4, -7), (64.5, -7)], PGND, 1.5)
    mknet(ax, [(38, -6), (40.4, -6)], PGND, 1.8)
    ax.plot(40.4, -6, marker='o', ms=3.2, color=PGND)
    ax.text(65.2, -7, 'GND plane - commoned on board 1; switch commons land '
                      'here', fontsize=5.5, color='#444444', va='center')

    # Caps: bulk at the 3V3 entry, 100 uF per VMOT
    cap(ax, 42.6, 0.3, -7, '10 uF bulk')
    cap(ax, 57.5, -4.2, -7, '100 uF')
    cap(ax, 61.5, -4.2, -7, '100 uF')
    ax.text(59.8, -8.1, 'VMOT bulk x2 - mandatory, fit before VMOT',
            fontsize=5, color='#8a1d10', ha='center')

    # Per-IC power flags (net-label style - wires not routed)
    FLAG = '#8a6a15'
    ax.text(40, 45.3, '3V3 - GND - +0.1 uF', fontsize=4.8, color=FLAG,
            ha='center')
    ax.text(51.5, 45.3, '3V3 - GND - +0.1 uF', fontsize=4.8, color=FLAG,
            ha='center')
    ax.text(64.75, 45.3, '3V3 - GND - +0.1 uF', fontsize=4.8, color=FLAG,
            ha='center')
    ax.text(44.5, 10.8, '3V3 - GND - +0.1 uF', fontsize=4.8, color=FLAG,
            ha='center')
    ax.text(79, 28.8, '3V3 (VDD) - 12 V (VMOT) - GND - 100 uF', fontsize=4.6,
            color=FLAG, ha='center')
    ax.text(79, 3.8, '3V3 (VDD) - 12 V (VMOT) - GND - 100 uF', fontsize=4.6,
            color=FLAG, ha='center')


def sheet_full():
    fig, ax = plt.subplots(figsize=(17, 12.2))
    ax.set_xlim(0, 104)
    ax.set_ylim(-10, 64)
    ax.axis('off')
    draw_signals(ax, power=True)
    ax.text(52, 62.7,
            'Self-balancing robot - board 6 full schematic (signals + power)',
            fontsize=14, fontweight='bold', ha='center')
    ax.text(52, 60.9,
            'Four tether signals + two power pairs (3V3 via J1 JST-PH, 12 V '
            'via J2 screw terminal, grounds commoned on board 1). Per-IC '
            'power shown as net flags.',
            fontsize=8, ha='center', color='#555555')
    ax.text(2, -9.6,
            'Board 1 is unbuilt - GPIO routing + power fan-out land at its '
            'design (F5).  Addresses: MPU 0x69, MCP23017 0x23, ADS1015 0x49. '
            'RESET-SLEEP pull-downs keep the chassis inert-by-default.  NC '
            'switch commons go to the GND plane.  0.1 uF values are '
            'placeholders - confirm at board-6 layout.',
            fontsize=6.8, color='#555555')
    plt.savefig(OUT + 'robot-board-full.jpg', dpi=200, bbox_inches='tight',
                facecolor='white')
    plt.close(fig)


if __name__ == '__main__':
    sheet_signals()
    print('wrote robot-board-schematic.jpg')
    sheet_power()
    print('wrote robot-board-power.jpg')
    sheet_full()
    print('wrote robot-board-full.jpg')
