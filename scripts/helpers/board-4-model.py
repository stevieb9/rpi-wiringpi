#!/usr/bin/env python3
"""
board-4-model.py - canonical electrical model for unit-test-platform BOARD 4.

Board 4 is a pure-I2C satellite "sensor carrier" (no Raspberry Pi on it); the Pi
lives on board 1 and reaches board 4 over JST jumpers. It carries the four I2C
peripherals the suite reads, each as a pre-made breakout MODULE on a header strip
(not a bare chip) -- so the parts here are honest header stand-ins, exactly the
way they are physically used on jumpers:

  M1  ZS-042 RTC/EEPROM module -- ONE breakout, TWO addresses:
        DS3231 RTC     @ 0x68   t/320
        AT24C32 EEPROM @ 0x57   t/420-422
  M2  GY-68 BMP180 pressure/temp @ 0x77   t/340     (3V3 only, NOT 5V tolerant)
  M3  SSD1306 128x64 OLED        @ 0x3c   t/500-520

Everything is 3V3 and bus-only -- no Pi GPIO reaches this board, unlike board 3.

Connectors (mirror board 3's J1/J2 "power in / signal in" convention):
  J1  power in  <- board 1  (JST-3):  1:+3V3  2:GND  3:+3V3
        Pin 3 is a SECOND +3V3 that loops back to board 1 as a presence /
        voltage-sense return (board 1 sources on pin 1, senses pin 3 to confirm
        board 4 is plugged in AND powered at the far cable end). On THIS board
        both pin 1 and pin 3 simply tie to the local +3V3 net; the "return"
        meaning lives entirely in how board 1 wires it (source vs separate sense
        node) -- captured in docs/test-platform/board-layout-proposal.md.
  J2  I2C in    <- board 1  (JST-2):  1:SDA  2:SCL
        Signal only; the I2C ground reference is the board ground delivered on
        J1 pin 2 (both connectors land on board 1).

No I2C pull-ups on this board: board 3 owns the bus pull-ups (its 4.7k R4/R5) and
the Pi adds ~1.8k, so board 4 adds none -- and the breakout modules' own on-board
pulls should be removed/disabled so they don't parallel the bus down.

[F] The per-module header pin ORDER below is the common vendor silk order, filled
from hardware convention (it is not test-derivable). Verify it against your actual
modules when hand-finalizing in KiCad; the NET each pin lands on is what matters
for correctness and is right regardless of physical pin order.

This model is hand-curated (board partitioning is a packaging decision, not
test-derivable), and is consumed once by gen-kicad.py to scaffold
docs/test-platform/kicad/rpi-wiringpi-unit-test-platform-board-4/, after which
the board is finalized by hand in KiCad.

Shapes match board-model.py:
  COMPONENTS  ref -> (value, footprint-hint, {pin: name})   pin keys are strings
  NETS        [(name, [(ref, pin), ...]), ...]
  J1FUNC      Pi 40-pin header functions (empty here - no Pi header)
  DRIVER      net -> driving node ('REF' = all pins, 'REF*PIN' = that pin)
  POWER       ref -> [(pin, rail-label), ...]  (drawn as a power flag)
  SHEETS      per-subsystem net groupings
"""

# ------------------------------------------------------------------ COMPONENTS
# ref: (value, footprint-hint, {pin: name})   pin keys are strings.
# The 'Module' hint scaffolds a single-row 2.54mm header strip (these breakouts
# really are header strips on jumpers); 'JST-n' likewise. Pin keys are the pad
# identifiers; values are the silk signal names.
COMPONENTS = {
 # --- I2C breakout modules ---
 # TODO [OPEN, raised 2026-06-21 -- verify before finalizing board 4]:
 #   This models a ZS-042 breakout, which carries BOTH the DS3231 RTC (0x68) AND
 #   an on-board AT24C32 EEPROM (0x57) on one 6-pin header. CONFIRM the physical
 #   part you have. If it is a *bare* DS3231 (no on-board EEPROM), then t/420-422
 #   need a SEPARATE AT24C32 chip -- add it here as its own module (VCC/GND/SCL/SDA
 #   on the I2C bus, address 0x57) and re-scaffold. If it is the ZS-042, this is
 #   already correct as-is.
 # ZS-042: standard 6-pin header order. 32K + SQW are unused (left unconnected).
 'M1': ('DS3231_0x68+AT24C32_0x57', 'Module',
        {'1':'32K','2':'SQW','3':'SCL','4':'SDA','5':'VCC','6':'GND'}),   # t/320, t/420-422
 # GY-68 BMP180: 4-pin header. VIN powered from 3V3 (part is not 5V tolerant).
 'M2': ('BMP180_0x77', 'Module',
        {'1':'VIN','2':'GND','3':'SCL','4':'SDA'}),                        # t/340
 # SSD1306 128x64 I2C OLED: 4-pin header.
 'M3': ('SSD1306_0x3c', 'Module',
        {'1':'GND','2':'VCC','3':'SCL','4':'SDA'}),                        # t/500-520
 # --- JST connectors (in <- board 1) ---
 'J1': ('JST_IN_PWR', 'JST-3', {'1':'+3V3','2':'GND','3':'+3V3'}),         # 3 = +3V3 return -> board 1
 'J2': ('JST_IN_I2C', 'JST-2', {'1':'SDA','2':'SCL'}),                     # I2C in
}

# ------------------------------------------------------------------ NETS
# Each net: (name, [(ref, pin), ...]). M1 pins 1 (32K) and 2 (SQW) are NC.
NETS = [
 # power: both J1 +3V3 pins (1 in, 3 return) tie to the local +3V3 net
 ('+3V3', [('J1','1'),('J1','3'),
           ('M1','5'),('M2','1'),('M3','2')]),        # module VCC/VIN pins
 ('GND',  [('J1','2'),
           ('M1','6'),('M2','2'),('M3','1')]),        # module GND pins
 # shared I2C bus (no local pull-ups; board 3 owns them)
 ('I2C_SDA', [('J2','1'),('M1','4'),('M2','4'),('M3','4')]),
 ('I2C_SCL', [('J2','2'),('M1','3'),('M2','3'),('M3','3')]),
]

# No Pi header on this board.
J1FUNC = {}

# which node(s) drive each net (become 'output'); rails + bus enter from board 1.
DRIVER = {
 '+3V3':'J1', 'GND':'J1',
 'I2C_SDA':'J2', 'I2C_SCL':'J2',
}

# per-device power flags (drawn at the device); board 4's rails enter on J1.
POWER = {
 'M1':[('5','+3V3'),('6','GND')],
 'M2':[('1','+3V3'),('2','GND')],
 'M3':[('2','+3V3'),('1','GND')],
}

# per-subsystem sheets (cleaner reads)
SHEETS = {
 'i2c': {'I2C_SDA','I2C_SCL'},
}
