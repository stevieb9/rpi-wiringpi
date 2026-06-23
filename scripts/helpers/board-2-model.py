#!/usr/bin/env python3
"""
board-2-model.py - canonical electrical model for unit-test-platform BOARD 2.

Board 2 is the SPI analog-loopback satellite (no Raspberry Pi on it); the Pi
lives on board 1 and reaches board 2 over JST jumpers. It carries the SPI analog
cluster plus the ADS1115, wired exactly as the suite's loopback tests drive them.
FIVE of the six read-backs stay ON this board -- only the GPIO18 signal arrives
from board 1 -- which is why this cluster is one board:

  U1  74HC595 shift register            -- t/335: Q1 -> MCP3008 CH2
  U2  MCP3008 SPI ADC (CS GPIO26)       -- the read-back reader (t/310, t/335)
  U3  MCP4922 dual SPI DAC (CS GPIO12)  -- t/310: VOUTA -> CH1, VOUTB -> CH3
  U4  MCP42010 dual SPI digipot (CS GPIO13) -- t/345: wipers PW0 -> ADS A1,
                                           PW1 -> ADS A2 (both channels active)
  M1  ADS1115 I2C ADC @ 0x48            -- t/140,325,345: A0 <- GPIO18 (PWM/
                                           servo), A1 <- digipot PW0,
                                           A2 <- digipot PW1

On-board analog loop-backs (the "everything loops back" property):
  MCP4922 VOUTA -> MCP3008 CH1     (t/310)
  MCP4922 VOUTB -> MCP3008 CH3     (t/310)
  74HC595 Q1    -> MCP3008 CH2     (t/335)
  digipot PW0   -> ADS1115 A1      (t/345)
  digipot PW1   -> ADS1115 A2      (ch1 wiper)
  GPIO18 PWM    -> ADS1115 A0      (t/140,325; the signal arrives on J2)

SPI clock/data (MISO/MOSI/SCLK) and the three bit-banged chip-selects
(GPIO26/12/13), plus the shift-register lines (GPIO21/20/16), all arrive from
board 1. MISO is driven back toward board 1 by the MCP3008 -- the only SPI device
that returns data; the DAC and digipot are write-only.

Connectors (JSTs in from board 1; J7 is the servo header):
  J1  power in     (JST-3): 1:+3V3   2:GND   3:+3V3   (pin 3 = +3V3 sense return
                            to board 1, same pattern as board 4)
  J2  servo feed   (JST-3): 1:+5V    2:GND   3:PWM    (+5V powers the servo;
                            PWM = GPIO18, a SIGNAL not a supply)
  J3  I2C in       (JST-2): 1:SDA    2:SCL
  J4  SPI bus in   (JST-3): 1:MISO   2:MOSI  3:SCLK
  J5  chip selects (JST-3): 1:CS26   2:CS12  3:CS13   (ADC / DAC / digipot)
  J6  shift reg in (JST-3): 1:DATA21 2:CLK20 3:LATCH16
  J7  servo        (Conn-3): 1:GND   2:V+    3:SIG    (the servo plugs in here;
                            V+ = +5V, SIG = GPIO18)

+5V is used ONLY by the servo: it enters on J2 and leaves on J7. Every IC on the
board is 3V3. GPIO18 carries no external pull/load beyond the high-Z ADS A0 input
(the interrupt tests depend on that -- platform doc section 7).

No I2C pull-ups on this board: board 3 owns the bus pull-ups (its 4.7k) and the
Pi adds ~1.8k, so board 2 adds none.

This model is hand-curated (board partitioning is a packaging decision, not
test-derivable), and is consumed once by gen-kicad.py to scaffold
docs/test-platform/kicad/rpi-wiringpi-unit-test-platform-board-2/, after which
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
# Bare-IC pin maps are copied verbatim from board-model.py (the canonical whole-
# board model) so connectivity stays identical; refs are renumbered sequentially
# for this stand-alone board (the way board-3-model.py does).
COMPONENTS = {
 # --- bare logic ICs ---
 'U1': ('74HC595', 'DIP-16', {   # shift register
   '16':'VCC','8':'GND','14':'DS','11':'SHCP','12':'STCP','13':'OE','10':'MR','9':'Q7S',
   '15':'Q0','1':'Q1','2':'Q2','3':'Q3','4':'Q4','5':'Q5','6':'Q6','7':'Q7'}),
 'U2': ('MCP3008', 'DIP-16', {   # SPI ADC (bit-banged CS = GPIO26); the reader
   '16':'VDD','15':'VREF','14':'AGND','9':'DGND','13':'CLK','12':'DOUT','11':'DIN','10':'CS',
   '1':'CH0','2':'CH1','3':'CH2','4':'CH3','5':'CH4','6':'CH5','7':'CH6','8':'CH7'}),
 'U3': ('MCP4922', 'DIP-14', {   # dual SPI DAC (bit-banged CS = GPIO12)
   '1':'VDD','3':'CS','4':'SCK','5':'SDI','8':'LDAC','9':'SHDN',
   '14':'VOUTA','13':'VREFA','12':'AVSS','11':'VREFB','10':'VOUTB',
   '2':'NC','6':'NC','7':'NC'}),   # NC package pins - included so the DIP-14 footprint gets all 14 holes
 'U4': ('MCP42010', 'DIP-14', {  # dual SPI digital pot (ch0 + ch1 active; CS = GPIO13)
   # Pinout corrected to Microchip DS11195C - the prior right-column (pins 8-14)
   # numbering was reversed, which mis-wired VDD/PB0/PW0/SHDN/SO.
   '1':'CS','2':'SCK','3':'SI','4':'VSS','5':'PB1','6':'PW1','7':'PA1',
   '8':'PA0','9':'PW0','10':'PB0','11':'RS','12':'SHDN','13':'SO','14':'VDD'}),
 # --- ADC breakout module ---
 'M1': ('ADS1115_0x48', 'Module',
        {'VDD':'VDD','GND':'GND','SCL':'SCL','SDA':'SDA','ADDR':'ADDR',
         'A0':'A0','A1':'A1','A2':'A2','A3':'A3'}),   # ADDR->GND = 0x48
 # --- JST connectors (in <- board 1) ---
 'J1': ('JST_IN_PWR',   'JST-3', {'1':'+3V3','2':'GND','3':'+3V3'}),       # 3 = +3V3 return -> board 1
 'J2': ('JST_IN_SERVO', 'JST-3', {'1':'+5V','2':'GND','3':'PWM'}),         # servo power + GPIO18 signal
 'J3': ('JST_IN_I2C',   'JST-2', {'1':'SDA','2':'SCL'}),
 'J4': ('JST_IN_SPI',   'JST-3', {'1':'MISO','2':'MOSI','3':'SCLK'}),
 'J5': ('JST_IN_CS',    'JST-3', {'1':'CS26','2':'CS12','3':'CS13'}),
 'J6': ('JST_IN_SR',    'JST-3', {'1':'DATA21','2':'CLK20','3':'LATCH16'}),
 # --- servo header (the servo plugs in here) ---
 'J7': ('Servo', 'Conn-3', {'1':'GND','2':'V+','3':'SIG'}),
}

# ------------------------------------------------------------------ NETS
# Each net: (name, [(ref, pin), ...]).
NETS = [
 # +5V: servo only -- in on J2, out to the servo header J7
 ('+5V', [('J2','1'),('J7','2')]),
 # +3V3: both J1 +3V3 pins (1 in, 3 return) + every IC supply/reference pin
 ('+3V3',[('J1','1'),('J1','3'),
          ('U1','16'),('U1','10'),                       # 595 VCC + MR (active-low, tied high)
          ('U2','16'),('U2','15'),                       # MCP3008 VDD + VREF
          ('U3','1'),('U3','13'),('U3','11'),('U3','9'), # MCP4922 VDD + VREFA + VREFB + SHDN
          ('U4','14'),('U4','11'),('U4','12'),('U4','8'),('U4','7'),# MCP42010 VDD(14) + RS(11) + SHDN(12) + PA0(8) + PA1(7) (both pot highs)
          ('M1','VDD')]),
 ('GND',[('J1','2'),('J2','2'),('J7','1'),
         ('U1','8'),('U1','13'),                         # 595 GND + OE (output-enable, tied low)
         ('U2','9'),('U2','14'),                         # MCP3008 DGND + AGND
         ('U3','12'),('U3','8'),                         # MCP4922 AVSS + LDAC (tied low)
         ('U4','4'),('U4','10'),('U4','5'),              # MCP42010 VSS(4) + PB0(10) + PB1(5) (both pot lows)
         ('M1','GND'),('M1','ADDR')]),                   # ADS GND + ADDR strap -> 0x48
 # I2C bus (3V3); only the ADS is on it here
 ('I2C_SDA',[('J3','1'),('M1','SDA')]),
 ('I2C_SCL',[('J3','2'),('M1','SCL')]),
 # SPI bus: clock/data shared by all three; MISO only the MCP3008 drives
 ('SPI_MOSI',[('J4','2'),('U2','11'),('U3','5'),('U4','3')]),   # DIN / SDI / SI
 ('SPI_MISO',[('J4','1'),('U2','12')]),                          # MCP3008 DOUT only
 ('SPI_SCLK',[('J4','3'),('U2','13'),('U3','4'),('U4','2')]),   # CLK / SCK / SCK
 # bit-banged chip-selects (one per device)
 ('CS_ADC', [('J5','1'),('U2','10')]),    # GPIO26 -> MCP3008 CS
 ('CS_DAC', [('J5','2'),('U3','3')]),     # GPIO12 -> MCP4922 CS
 ('CS_DPOT',[('J5','3'),('U4','1')]),     # GPIO13 -> MCP42010 CS
 # shift-register control (bit-banged GPIO)
 ('SR_DATA', [('J6','1'),('U1','14')]),   # GPIO21 -> DS
 ('SR_CLK',  [('J6','2'),('U1','11')]),   # GPIO20 -> SHCP
 ('SR_LATCH',[('J6','3'),('U1','12')]),   # GPIO16 -> STCP
 # GPIO18: in on J2, fans to ADS A0 (read-back) and the servo SIG
 ('PWM18',[('J2','3'),('M1','A0'),('J7','3')]),
 # analog loop-backs (all on-board)
 ('DPOT_WIPER',[('U4','9'),('M1','A1')]),    # PW0(9) -> ADS A1   (t/345)
 ('DPOT_WIPER2',[('U4','6'),('M1','A2')]),   # PW1(6) -> ADS A2   (ch1 wiper)
 ('DAC_A_CH1', [('U3','14'),('U2','2')]),    # VOUTA -> CH1     (t/310)
 ('DAC_B_CH3', [('U3','10'),('U2','4')]),    # VOUTB -> CH3     (t/310)
 ('SR_Q_CH2',  [('U1','1'),('U2','3')]),     # 595 Q1 -> CH2    (t/335)
]

# No Pi header on this board.
J1FUNC = {}

# which node(s) drive each net (become 'output'); buses/rails enter from board 1.
DRIVER = {
 '+5V':'J2','+3V3':'J1','GND':'J1',
 'I2C_SDA':'J3','I2C_SCL':'J3',
 'SPI_MOSI':'J4','SPI_SCLK':'J4','SPI_MISO':'U2',
 'CS_ADC':'J5','CS_DAC':'J5','CS_DPOT':'J5',
 'SR_DATA':'J6','SR_CLK':'J6','SR_LATCH':'J6',
 'PWM18':'J2',
 'DPOT_WIPER':'U4','DPOT_WIPER2':'U4','DAC_A_CH1':'U3','DAC_B_CH3':'U3','SR_Q_CH2':'U1',
}

# per-device power flags (drawn at the device); board 2's rails enter on J1/J2.
POWER = {
 'U1':[('16','+3V3'),('8','GND')],
 'U2':[('16','+3V3'),('9','GND')],
 'U3':[('1','+3V3'),('12','GND')],
 'U4':[('14','+3V3'),('4','GND')],
 'M1':[('VDD','+3V3'),('GND','GND')],
}

# per-subsystem sheets (cleaner reads)
SHEETS = {
 'i2c':   {'I2C_SDA','I2C_SCL'},
 'spi':   {'SPI_MOSI','SPI_MISO','SPI_SCLK','CS_ADC','CS_DAC','CS_DPOT',
           'SR_DATA','SR_CLK','SR_LATCH','DAC_A_CH1','DAC_B_CH3','SR_Q_CH2','DPOT_WIPER','DPOT_WIPER2'},
 'servo': {'PWM18'},
}
