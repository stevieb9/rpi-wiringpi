#!/usr/bin/env python3
"""
board-5-model.py - canonical electrical model for unit-test-platform BOARD 5.

Board 5 is the "5V logic" satellite (no Raspberry Pi on it); the Pi lives on
board 1 and reaches board 5 over JST jumpers. It carries the three things the
suite needs at, or behind, 5V logic:

  LCD1  HD44780 20x4 character LCD, 4-bit bus -- t/525. 5V powered, but driven
        with 3V3 logic straight from the Pi GPIO (HD44780 reads VIH ~= 0.7*VDD,
        and 3V3 clears that at VDD=5V on these panels; no shifter on the LCD bus).
          RS=GPIO5  E=GPIO6  D4=GPIO4  D5=GPIO17  D6=GPIO27  D7=GPIO22
        D0-D3 (pins 7-10) are unused in 4-bit mode; RW (pin 5) is tied low
        (write-only). Contrast (V0) from an on-board trimpot; backlight A via a
        series resistor to +5V, K to GND.
  U1    SparkFun BOB-12009 bi-directional logic level converter -- bridges the
        3V3 Pi I2C up to a 5V Arduino. LV ref = +3V3, HV ref = +5V; SDA on
        channel 1, SCL on channel 2 (channels 3/4 spare). t/305.
  J4    The Arduino I2C slave (0x04, t/305) is OFF board, reached over J4 on the
        5V (HV) side of the shifter -- the suite reads/writes its eeprom there.
  JP1   UART loop-back: the Pi's TXD (GPIO14) and RXD (GPIO15) arrive on J2 and
        are bridged by a 2-pin jumper so t/315 can putc()->getc() back to back.
        (Relocatable to another satellite; it just rides along here.)

Rails: +5V (LCD panel + backlight + Arduino feed + shifter HV ref) and +3V3
(shifter LV ref). Every Pi signal enters from board 1 on a JST.

Connectors (JSTs in <- board 1, mirroring board 3's "power in / signal in"):
  J1  power in   (JST-4): 1:+5V 2:+3V3 3:GND 4:+3V3   (pin 4 = +3V3 sense return
                          to board 1, exactly like board 3/4's J1; on THIS board
                          pins 2 and 4 both tie to the local +3V3 net)
  J2  signal in  (JST-4): 1:SDA 2:SCL 3:TX14 4:RX15   (I2C bus + the UART pair)
  J3  LCD GPIO in(JST-6): 1:RS 2:E 3:D4 4:D5 5:D6 6:D7 (the six Pi GPIO that drive
                          the LCD; silk shows the LCD role, the net is the BCM
                          GPIO it carries -- GPIO17/GPIO27 are SHARED with board 3's
                          stepper limit switches, platform doc section 10-10)
  J4  I2C out    (JST-4): 1:SDA 2:SCL 3:+5V 4:GND     (5V I2C out to the external
                          Arduino; common GND is mandatory for the bus, +5V is an
                          optional convenience feed for the Arduino)

No I2C pull-ups on this board: board 3 owns the bus pull-ups (its 4.7k R4/R5) and
the Pi adds ~1.8k, so board 5 adds none on the 3V3 side. The Arduino board carries
its own 5V-side pull-ups behind the shifter.

[F] The LCD's 16-pin header order is the HD44780 datasheet order (checked by
check-datasheets.py against the Vishay LCD-016N002M / Hitachi HD44780U pinout).
The level shifter (U1) is the SparkFun BOB-12009 -- "two parallel rows of six
headers". Per-row silk order has the reference and GND in the CENTRE, not the ends:
LV1 LV2 LV GND LV3 LV4 across from HV1 HV2 HV GND HV3 HV4, channel pairs (LVn <-> HVn)
column-aligned. Its scaffolded footprint was hand-corrected from the generic
single-row 'Module' strip to that real 2x6 arrangement (.pretty/U1.kicad_mod); pad
names are unchanged so the schematic->PCB transfer stays 0-error. Pinout per the
SparkFun hookup guide:
https://learn.sparkfun.com/tutorials/bi-directional-logic-level-converter-hookup-guide

This model is hand-curated (board partitioning is a packaging decision, not
test-derivable), and is consumed once by gen-kicad.py to scaffold
docs/test-platform/kicad/rpi-wiringpi-unit-test-platform-board-5/, after which
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
COMPONENTS = {
 # --- HD44780 20x4 character LCD (16-pin SIL header the panel plugs onto) ---
 # Value MUST contain 'HD44780' so check-datasheets.py gates all 16 pins against
 # the datasheet pinout (Vishay LCD-016N002M). Pin names are the datasheet names
 # verbatim; D0-D3 (7-10) are NC in 4-bit mode but kept so the footprint gets all
 # 16 holes and the datasheet check sees every pin.
 'LCD1': ('HD44780_20x4', 'Module',
          {'1':'VSS','2':'VDD','3':'V0','4':'RS','5':'RW','6':'E',
           '7':'D0','8':'D1','9':'D2','10':'D3',
           '11':'D4','12':'D5','13':'D6','14':'D7','15':'A','16':'K'}),   # t/525
 # --- 3V3<->5V level shifter (SparkFun BOB-12009; named pins -> datasheet check
 #     skips it). LV side = 3V3 Pi I2C, HV side = 5V Arduino I2C. Pad ids LGND/HGND
 #     are unique; both display silk 'GND'. Channels 3/4 are spare. ---
 'U1': ('LVLSHIFT_BOB12009', 'Module',
        {'LV':'LV','LV1':'LV1','LV2':'LV2','LV3':'LV3','LV4':'LV4','LGND':'GND',
         'HV':'HV','HV1':'HV1','HV2':'HV2','HV3':'HV3','HV4':'HV4','HGND':'GND'}),  # t/305
 # --- LCD contrast trimpot (V0) and backlight series resistor ---
 'RV1': ('10k', 'Pot', {'1':'A','2':'W','3':'B'}),   # A=+5V, W(iper)=V0, B=GND
 'R1':  ('220', 'R',   {'1':'1','2':'2'}),           # backlight: +5V -> A
 # --- JST connectors (in <- board 1; J4 out -> external Arduino) ---
 'J1': ('JST_IN_PWR', 'JST-4', {'1':'+5V','2':'+3V3','3':'GND','4':'+3V3'}),   # 4 = +3V3 return -> board 1
 'J2': ('JST_IN_SIG', 'JST-4', {'1':'SDA','2':'SCL','3':'TX14','4':'RX15'}),   # I2C + UART in
 'J3': ('JST_IN_LCD', 'JST-6', {'1':'RS','2':'E','3':'D4','4':'D5','5':'D6','6':'D7'}),  # LCD GPIO in
 'J4': ('JST_OUT_I2C5V', 'JST-4', {'1':'SDA','2':'SCL','3':'+5V','4':'GND'}),  # 5V I2C out -> Arduino
 # --- UART loop-back jumper (TXD14 <-> RXD15 bridged by the user's shunt) ---
 'JP1': ('UART_LOOP', 'Conn-2', {'1':'TX','2':'RX'}),  # t/315
}

# ------------------------------------------------------------------ NETS
# Each net: (name, [(ref, pin), ...]). LCD D0-D3 (7-10) are NC (4-bit mode).
NETS = [
 # power rails (enter on J1; pins 2 and 4 are both +3V3, pin 4 = sense return)
 ('+5V', [('J1','1'),
          ('LCD1','2'),                 # LCD VDD (panel logic supply)
          ('RV1','1'),                  # contrast pot top
          ('R1','1'),                   # backlight series resistor -> A
          ('U1','HV'),                  # shifter HV reference
          ('J4','3')]),                 # +5V feed out to the Arduino
 ('+3V3',[('J1','2'),('J1','4'),
          ('U1','LV')]),                # shifter LV reference
 ('GND', [('J1','3'),
          ('LCD1','1'),('LCD1','5'),('LCD1','16'),   # VSS + RW (write-only) + backlight K
          ('RV1','3'),                  # contrast pot bottom
          ('U1','LGND'),('U1','HGND'),  # shifter ground, both sides
          ('J4','4')]),                 # common GND out to the Arduino (mandatory)
 # I2C bus in (3V3 side); enters on J2, lands on the shifter LV channels
 ('I2C_SDA',[('J2','1'),('U1','LV1')]),
 ('I2C_SCL',[('J2','2'),('U1','LV2')]),
 # I2C bus out (5V side); shifter HV channels -> J4 -> external Arduino (0x04)
 ('SDA_5V',[('U1','HV1'),('J4','1')]),
 ('SCL_5V',[('U1','HV2'),('J4','2')]),
 # UART loop-back: Pi TXD14 / RXD15 arrive on J2, bridged by the JP1 shunt
 ('UART_TX',[('J2','3'),('JP1','1')]),   # GPIO14 (TXD)
 ('UART_RX',[('J2','4'),('JP1','2')]),   # GPIO15 (RXD)
 # LCD control + 4-bit data (Pi GPIO in on J3). Net = BCM GPIO; GPIO17/GPIO27 are
 # SHARED with board 3's stepper limit switches (platform doc section 10-10).
 ('GPIO5', [('J3','1'),('LCD1','4')]),    # RS
 ('GPIO6', [('J3','2'),('LCD1','6')]),    # E (strobe)
 ('GPIO4', [('J3','3'),('LCD1','11')]),   # D4
 ('GPIO17',[('J3','4'),('LCD1','12')]),   # D5
 ('GPIO27',[('J3','5'),('LCD1','13')]),   # D6
 ('GPIO22',[('J3','6'),('LCD1','14')]),   # D7
 # LCD local analog: contrast wiper -> V0, backlight resistor -> A
 ('LCD_V0',[('RV1','2'),('LCD1','3')]),
 ('LCD_BL_A',[('R1','2'),('LCD1','15')]),
]

# No Pi header on this board.
J1FUNC = {}

# which node(s) drive each net (become 'output'); rails + buses enter from board 1.
DRIVER = {
 '+5V':'J1', '+3V3':'J1', 'GND':'J1',
 'I2C_SDA':'J2', 'I2C_SCL':'J2',
 'SDA_5V':'U1', 'SCL_5V':'U1',          # the shifter drives the 5V side
 'UART_TX':'J2', 'UART_RX':'JP1',       # RX is fed by the loop-back jumper
 'GPIO5':'J3', 'GPIO6':'J3', 'GPIO4':'J3',
 'GPIO17':'J3', 'GPIO27':'J3', 'GPIO22':'J3',
 'LCD_V0':'RV1', 'LCD_BL_A':'R1',
}

# per-device power flags (drawn at the device); board 5's rails enter on J1.
POWER = {
 'LCD1':[('2','+5V'),('1','GND')],
 'U1':[('LV','+3V3'),('HV','+5V'),('LGND','GND')],
}

# per-subsystem sheets (cleaner reads)
SHEETS = {
 'i2c':  {'I2C_SDA','I2C_SCL','SDA_5V','SCL_5V'},
 'lcd':  {'GPIO5','GPIO6','GPIO4','GPIO17','GPIO27','GPIO22','LCD_V0','LCD_BL_A'},
 'uart': {'UART_TX','UART_RX'},
}
