#!/usr/bin/env python3
"""
board-3-model.py - canonical electrical model for unit-test-platform BOARD 3.

Board 3 is a satellite I2C board (no Raspberry Pi on it); the Pi lives on board 1
and reaches board 3 over JST jumpers. It carries the two MCP23017 expanders wired
exactly as the test suite drives them:

  U1  MCP23017 @ 0x20  -- t/330: full 16-pin A<->B loopback, GPA(n)<->GPB(7-n).
  U2  MCP23017 @ 0x21  -- t/450: bank-A pins A0-A3 drive the stepper coils. The
                         motor + its ULN2003 driver are OFF board; the four coil
                         logic lines leave over a 4-pin JST (J5). U2's twelve
                         spare I/O (GPA4-7, GPB0-7) are broken out as three more
                         4-pin JSTs (J6/J7/J8), each a contiguous block.

The stepper's magnetic CW/CCW limit switches (Pi GPIO17/GPIO27, read native in
t/450) are also off board: GPIO17/27 fan out over J4 to the external magnets,
which return +3V3 when aligned (matches the PUD_DOWN reads in t/450). GPIO19 is
the centre LED line (a Pi output in t/450) and stays local to board 3.

Three on-board indicator LEDs, one per GPIO line, each gated by one bank of a
3-position DIP switch so any leg can be cut: GPIO -> DIP bank -> LED -> 330R ->
GND. GPIO17=green (CW switch trip), GPIO27=red (CCW trip), GPIO19=yellow (centre).

The board carries its own 4.7k I2C pull-ups (R4/R5) to +3V3 so the bus is defined
even over a long board-1 cable (the Pi's own 1.8k pull-ups sit in parallel).

This model is hand-curated (board partitioning is a packaging decision, not
test-derivable), and is consumed once by gen-kicad.py to scaffold
docs/test-platform/kicad/rpi-wiringpi-unit-test-platform-board-3/, after which
the board is finalized by hand in KiCad.

Shapes match board-model.py:
  COMPONENTS  ref -> (value, footprint-hint, {pin: name})   pin keys are strings
  NETS        [(name, [(ref, pin), ...]), ...]
  J1FUNC      Pi 40-pin header functions (empty here - no Pi header)
  DRIVER      net -> driving node ('REF' = all pins, 'REF*PIN' = that pin)
  POWER       ref -> [(pin, rail-label), ...]  (drawn as a power flag)
  SHEETS      per-subsystem net groupings
"""

# The full physical MCP23017 DIP-28 pin map, shared by both expanders. Pins 11
# and 14 are NC on the MCP23017 but are real package pins, so they are included
# here to give the footprint all 28 holes.
_MCP = {
 '9':'VDD','10':'VSS','11':'NC','12':'SCL','13':'SDA','14':'NC','18':'RESET',
 '15':'A0','16':'A1','17':'A2','20':'INTA','19':'INTB',
 '21':'GPA0','22':'GPA1','23':'GPA2','24':'GPA3','25':'GPA4','26':'GPA5','27':'GPA6','28':'GPA7',
 '1':'GPB0','2':'GPB1','3':'GPB2','4':'GPB3','5':'GPB4','6':'GPB5','7':'GPB6','8':'GPB7',
}

# ------------------------------------------------------------------ COMPONENTS
# ref: (value, footprint-hint, {pin: name})   pin keys are strings.
COMPONENTS = {
 # --- I2C GPIO expanders ---
 'U1': ('MCP23017_0x20', 'DIP-28', dict(_MCP)),   # t/330 loopback
 'U2': ('MCP23017_0x21', 'DIP-28', dict(_MCP)),   # t/450 stepper drive
 # --- JST connectors ---
 'J1': ('JST_IN_PWR',  'JST-4', {'1':'+5V','2':'+3V3','3':'GND','4':'+3V3'}),            # in <- board 1 (pad 4 = 2nd +3V3, as-built)
 'J2': ('JST_IN_SIG',  'JST-5', {'1':'SDA','2':'SCL','3':'GPIO17','4':'GPIO27','5':'GPIO19'}),  # in <- board 1
 'J3': ('JST_OUT_PWR', 'JST-3', {'1':'+5V','2':'+3V3','3':'GND'}),                       # out -> stepper/magnets
 'J4': ('JST_OUT_SW',  'JST-2', {'1':'GPIO17','2':'GPIO27'}),                            # out -> magnet switches
 'J5': ('JST_OUT_COIL','JST-4', {'1':'IN1','2':'IN2','3':'IN3','4':'IN4'}),              # out -> ULN2003 coils
 # --- U2 (0x21) spare-I/O breakouts: three contiguous 4-pin blocks ---
 'J6': ('JST_IO_A4_7','JST-4', {'1':'A4','2':'A5','3':'A6','4':'A7'}),                   # U2 GPA4-7
 'J7': ('JST_IO_B0_3','JST-4', {'1':'B0','2':'B1','3':'B2','4':'B3'}),                   # U2 GPB0-3
 'J8': ('JST_IO_B4_7','JST-4', {'1':'B4','2':'B5','3':'B6','4':'B7'}),                   # U2 GPB4-7
 # --- indicator LEDs ---
 'D1': ('LED_green',  'LED', {'A':'A','K':'K'}),   # GPIO17 (CW switch trip)
 'D2': ('LED_red',    'LED', {'A':'A','K':'K'}),   # GPIO27 (CCW switch trip)
 'D3': ('LED_yellow', 'LED', {'A':'A','K':'K'}),   # GPIO19 (centre)
 # --- passives ---
 'R1': ('330', 'R', {'1':'1','2':'2'}),   # green LED series
 'R2': ('330', 'R', {'1':'1','2':'2'}),   # red LED series
 'R3': ('330', 'R', {'1':'1','2':'2'}),   # yellow LED series
 'R4': ('4k7', 'R', {'1':'1','2':'2'}),   # SDA pull-up -> +3V3
 'R5': ('4k7', 'R', {'1':'1','2':'2'}),   # SCL pull-up -> +3V3
 # --- 3-bank DIP switch (3x SPST, two rows of three): switch n bridges the two
 #     pins directly across the package, i.e. (1,6), (2,5), (3,4) ---
 'SW1': ('DIP_SW_x3', 'DIP-SW-3', {'1':'1','2':'2','3':'3','4':'4','5':'5','6':'6'}),
}

# ------------------------------------------------------------------ NETS
# Each net: (name, [(ref, pin), ...])
NETS = [
 # power rails (enter on J1, pass through to J3 for the external assembly)
 ('+5V', [('J1','1'),('J3','1')]),
 ('+3V3',[('J1','2'),('J1','4'),('J3','2'),
          ('U1','9'),('U1','18'),               # VDD + RESET (active-low, tied high)
          ('U2','9'),('U2','18'),('U2','15'),   # VDD + RESET + A0 strap (-> 0x21)
          ('R4','2'),('R5','2')]),              # I2C pull-ups
 ('GND', [('J1','3'),('J3','3'),
          ('U1','10'),('U1','15'),('U1','16'),('U1','17'),   # VSS + A0/A1/A2 straps (-> 0x20)
          ('U2','10'),('U2','16'),('U2','17'),               # VSS + A1/A2 straps
          ('R1','2'),('R2','2'),('R3','2')]),                # LED-leg returns
 # I2C bus (shared by both expanders, pulled up locally)
 ('I2C_SDA',[('J2','1'),('U1','13'),('U2','13'),('R4','1')]),
 ('I2C_SCL',[('J2','2'),('U1','12'),('U2','12'),('R5','1')]),
 # Pi GPIO control lines in from board 1 (each enters one side of a DIP switch)
 ('GPIO17',[('J2','3'),('SW1','1'),('J4','1')]),   # -> DIP sw1 (pin 1), out to CW magnet switch
 ('GPIO27',[('J2','4'),('SW1','2'),('J4','2')]),   # -> DIP sw2 (pin 2), out to CCW magnet switch
 ('GPIO19',[('J2','5'),('SW1','3')]),              # -> DIP sw3 (pin 3), centre LED, local only
 # LED legs: anode off the DIP switch's far side; cathode -> series R -> GND
 ('LED_G_A',[('SW1','6'),('D1','A')]),   # green anode  (DIP sw1 far side, pin 6)
 ('LED_R_A',[('SW1','5'),('D2','A')]),   # red anode    (DIP sw2 far side, pin 5)
 ('LED_Y_A',[('SW1','4'),('D3','A')]),   # yellow anode (DIP sw3 far side, pin 4)
 ('LED_G_K',[('D1','K'),('R1','1')]),
 ('LED_R_K',[('D2','K'),('R2','1')]),
 ('LED_Y_K',[('D3','K'),('R3','1')]),
 # stepper coil drive: U2 (0x21) bank A A0-A3 -> coil JST -> external ULN2003
 ('COIL_IN1',[('U2','21'),('J5','1')]),  # GPA0
 ('COIL_IN2',[('U2','22'),('J5','2')]),  # GPA1
 ('COIL_IN3',[('U2','23'),('J5','3')]),  # GPA2
 ('COIL_IN4',[('U2','24'),('J5','4')]),  # GPA3
 # U2 (0x21) spare I/O -> three 4-pin breakout JSTs (contiguous blocks)
 ('IO_A4',[('U2','25'),('J6','1')]),  # GPA4
 ('IO_A5',[('U2','26'),('J6','2')]),  # GPA5
 ('IO_A6',[('U2','27'),('J6','3')]),  # GPA6
 ('IO_A7',[('U2','28'),('J6','4')]),  # GPA7
 ('IO_B0',[('U2','1'),('J7','1')]),   # GPB0
 ('IO_B1',[('U2','2'),('J7','2')]),   # GPB1
 ('IO_B2',[('U2','3'),('J7','3')]),   # GPB2
 ('IO_B3',[('U2','4'),('J7','4')]),   # GPB3
 ('IO_B4',[('U2','5'),('J8','1')]),   # GPB4
 ('IO_B5',[('U2','6'),('J8','2')]),   # GPB5
 ('IO_B6',[('U2','7'),('J8','3')]),   # GPB6
 ('IO_B7',[('U2','8'),('J8','4')]),   # GPB7
 # U1 (0x20) full A<->B loopback, GPA(n)<->GPB(7-n), all 16 pins (t/330)
 ('EXP_LB0',[('U1','21'),('U1','8')]),    # GPA0 <-> GPB7
 ('EXP_LB1',[('U1','22'),('U1','7')]),    # GPA1 <-> GPB6
 ('EXP_LB2',[('U1','23'),('U1','6')]),    # GPA2 <-> GPB5
 ('EXP_LB3',[('U1','24'),('U1','5')]),    # GPA3 <-> GPB4
 ('EXP_LB4',[('U1','25'),('U1','4')]),    # GPA4 <-> GPB3
 ('EXP_LB5',[('U1','26'),('U1','3')]),    # GPA5 <-> GPB2
 ('EXP_LB6',[('U1','27'),('U1','2')]),    # GPA6 <-> GPB1
 ('EXP_LB7',[('U1','28'),('U1','1')]),    # GPA7 <-> GPB0
]

# No Pi header on this board.
J1FUNC = {}

# which node(s) drive each net (become 'output'); 'REF' = all pins, 'REF*PIN' = just that pin
DRIVER = {
 '+5V':'J1','+3V3':'J1','GND':'J1',
 'I2C_SDA':'J2','I2C_SCL':'J2',
 'GPIO17':'J2','GPIO27':'J2','GPIO19':'J2',
 'LED_G_A':'SW1*2','LED_R_A':'SW1*4','LED_Y_A':'SW1*6',
 'LED_G_K':'D1','LED_R_K':'D2','LED_Y_K':'D3',
 'COIL_IN1':'U2*21','COIL_IN2':'U2*22','COIL_IN3':'U2*23','COIL_IN4':'U2*24',
 'IO_A4':'U2*25','IO_A5':'U2*26','IO_A6':'U2*27','IO_A7':'U2*28',
 'IO_B0':'U2*1','IO_B1':'U2*2','IO_B2':'U2*3','IO_B3':'U2*4',
 'IO_B4':'U2*5','IO_B5':'U2*6','IO_B6':'U2*7','IO_B7':'U2*8',
 'EXP_LB0':'U1*21','EXP_LB1':'U1*22','EXP_LB2':'U1*23','EXP_LB3':'U1*24',
 'EXP_LB4':'U1*25','EXP_LB5':'U1*26','EXP_LB6':'U1*27','EXP_LB7':'U1*28',
}

# per-device power flags (drawn at the device); board 3's rails enter on J1.
POWER = {
 'U1':[('9','+3V3'),('10','GND')],
 'U2':[('9','+3V3'),('10','GND')],
}

# per-subsystem sheets (cleaner reads)
SHEETS = {
 'i2c':     {'I2C_SDA','I2C_SCL'},
 'stepper': {'COIL_IN1','COIL_IN2','COIL_IN3','COIL_IN4'},
 'io':      {'IO_A4','IO_A5','IO_A6','IO_A7','IO_B0','IO_B1','IO_B2','IO_B3',
             'IO_B4','IO_B5','IO_B6','IO_B7'},
 'loopback':{'EXP_LB0','EXP_LB1','EXP_LB2','EXP_LB3','EXP_LB4','EXP_LB5','EXP_LB6','EXP_LB7'},
 'leds':    {'GPIO17','GPIO27','GPIO19',
             'LED_G_A','LED_R_A','LED_Y_A','LED_G_K','LED_R_K','LED_Y_K'},
}
