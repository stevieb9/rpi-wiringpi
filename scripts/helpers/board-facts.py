#!/usr/bin/env python3
"""
board-facts.py - curated [F] (gap-filled) facts for the test platform.

These are facts the TEST SUITE cannot establish - so they live here, curated by
hand, rather than being "re-derived". Both the canonical model (board-model.py)
and the independent re-derivation (model-from-tests.py) import them, so a fact
like a device's power rail is stated ONCE, not duplicated and cross-checked.

  POWER  per-device power pins -> supply rail, drawn as a power flag in the
         schematic. Rails are not test-derivable (no test reads a voltage), so
         this whole table is [F]; confirm against your actual parts.

  BENCH_DEVICES  bus devices that are bench-wired (env-gated) rather than on a
         fabbed board, so they are NOT in board-model.py's COMPONENTS/NETS - but
         they DO occupy real I2C addresses, so they belong in the bus map.
         Keyed the same way as board-model.py's BUS_DEVICES. All [T] (the test
         passes/asserts the address), gap-filled only for the human-readable
         name.

  PLANNED_DEVICES / OPTIONAL_DEVICES  same shape as BENCH_DEVICES, for board-1
         (planned) and optional/often-absent parts.

  ELECTRICAL  per-device current draw (active typ/peak + lowest sleep state),
         the source of truth behind the pin doc's current budget and
         facts/electrical.json. Scoped to on-board + planned devices only.
"""

# per-device power: (pin, rail-label) -> drawn as a small flag at the device
POWER = {
 'U1':[('9','+3V3'),('10','GND')], 'U2':[('16','+3V3'),('8','GND')],
 'U3':[('16','+3V3'),('9','GND')], 'U4':[('1','+3V3'),('12','GND')],
 'U5':[('14','+3V3'),('4','GND')], 'M1':[('VDD','+3V3'),('GND','GND')],
 'U6':[('9','+3V3'),('10','GND')], 'M3':[('VCC','+3V3'),('GND','GND')],
 'M4':[('VIN','+3V3'),('GND','GND')], 'M5':[('VCC','+3V3'),('GND','GND')],
 'M6':[('LV','+3V3'),('HV','+5V'),('GND1','GND')], 'M7':[('V+','+5V'),('GND','GND')],
 'M8':[('2','+5V'),('1','GND')],  'A1':[('5V','+5V'),('GND','GND')],
 'SV1':[('V+','+5V'),('GND','GND')], 'RV1':[('1','+5V'),('3','GND')], 'R7':[('1','+5V')],
 'SW1':[('2','+3V3')],'SW2':[('2','+3V3')],'D1':[('K','GND')],
}

# Bench-wired bus devices, not on any fabbed board (so not in the electrical
# model). key -> (ref, bus, value, driver, tests, board); ref is None (no
# schematic component) and board is None (not on a board). Folded into
# facts/bus-map.json tagged context 'bench'. NOTE: this bench ADS1115 (t/360,
# read by the ADXL335) is a DIFFERENT physical chip from the board-2 ADS1015
# (M1, t/405) - both default to I2C 0x48 but are never on the bus together.
BENCH_DEVICES = {
 'MCP23017#3':        (None, 'i2c', 0x22,    'RPi::GPIOExpander::MCP23017', 't/353', None),
 'MPU-6050':          (None, 'i2c', 0x69,    'RPi::Gyro::MPU6050',          't/358', None),
 'ADS1115 (ADXL335)': (None, 'i2c', 0x48,    'RPi::ADC::ADS',               't/360', None),
 'ST7735S TFT':       (None, 'spi', 'GPIO8', 'RPi::TFT::ST7735S',           't/447', None),
 'AT24C256':          (None, 'i2c', 0x50,    'RPi::EEPROM::AT24C256',       't/544', None),
}

# Board 1 is planned/not-yet-built, so its I2C devices are not in the electrical
# model either, but they have passing HW-gated tests and occupy real addresses.
# Same shape as BENCH_DEVICES; folded into the bus map tagged context 'planned'.
PLANNED_DEVICES = {
 'PCF8574 LCD': (None, 'i2c', 0x27, 'RPi::LCD',          't/335', 1),
 'PCA9685':     (None, 'i2c', 0x40, 'RPi::PWM::PCA9685', 't/440', 1),
}

# Optional / alternate-mode devices that no test drives but that do occupy an
# address when present. Same shape; folded in tagged context 'optional', with an
# empty tests field and no board. Kept so the generated docs don't lose them.
OPTIONAL_DEVICES = {
 'ATMega-328P': (None, 'i2c', 0x05, 'standalone ATMega-328P (I2C mode)', '', None),
}

# ------------------------------------------------------------------ ELECTRICAL
# Per-device current draw, the single source of truth behind the pin doc's
# current-budget tables (sec 11.3) and facts/electrical.json. [F] DATASHEET-
# TYPICAL ESTIMATES, NOT MEASURED - confirm against your parts before sizing a
# supply. Active figures are carried over from the curated sec 11.3 table; the
# sleep column is the lowest documented power state (sleep/standby/shutdown),
# sourced from plans/rpi-lowpower-modes.md + the part datasheets.
#
# SCOPE (deliberate): only devices that are on a fabbed board (context
# 'onboard', boards 2-5) or planned for one (context 'planned', board 1).
# Bench-wired parts (MPU-6050, A4988, ST7735S, ADXL335 ADS) and optional/
# often-absent parts (standalone ATMega-328P) are EXCLUDED - they are not part
# of the platform's power budget.
#
# key -> dict:
#   ref        schematic ref, or None for planned/infra items not yet modelled
#   rail       '+3V3' | '+5V'
#   context    'onboard' | 'planned'
#   board      fabbed board number (2-5 onboard, 1 planned), or None if not on a board
#   typ_ma     typical active draw (mA)
#   peak_ma    peak/stall active draw (mA)
#   sleep_ma   lowest documented power state (mA); None if the part has none
#   sleep_note how that state is reached (method / mechanism), or why there is none
#   note       free-form active-draw note
ELECTRICAL = {
 # --- +3V3 rail: I2C / SPI ICs + the 74HC595 -----------------------------------
 'ADS1015 #1':      {'ref':'M1', 'rail':'+3V3', 'context':'onboard', 'board':2,
                     'typ_ma':0.15, 'peak_ma':0.20, 'sleep_ma':0.002,
                     'sleep_note':'single-shot mode powers down between reads (MODE bit)',
                     'note':'continuous-conversion when mode() is held on'},
 'MCP23017 #1':     {'ref':'U1', 'rail':'+3V3', 'context':'onboard', 'board':3,
                     'typ_ma':1.0, 'peak_ma':1.0, 'sleep_ma':0.001,
                     'sleep_note':'no sleep register; ~1 uA passive standby',
                     'note':'logic only; loopback drive is high-Z'},
 'MCP23017 #2':     {'ref':'U6', 'rail':'+3V3', 'context':'onboard', 'board':3,
                     'typ_ma':1.0, 'peak_ma':1.0, 'sleep_ma':0.001,
                     'sleep_note':'no sleep register; ~1 uA passive standby',
                     'note':'stepper drive (ULN2003 inputs, high-Z)'},
 'DS3231 RTC':      {'ref':'M3', 'rail':'+3V3', 'context':'onboard', 'board':4,
                     'typ_ma':0.2, 'peak_ma':0.2, 'sleep_ma':0.11,
                     'sleep_note':'always timekeeping; EOSC/EN32kHz save battery, not Vcc',
                     'note':'+~3 mA if breakout power-LED fitted'},
 'AT24C32 EEPROM':  {'ref':'M3', 'rail':'+3V3', 'context':'onboard', 'board':4,
                     'typ_ma':0.5, 'peak_ma':3.0, 'sleep_ma':0.001,
                     'sleep_note':'auto standby on bus idle (no power-down command)',
                     'note':'peak during page write'},
 'BMP180':          {'ref':'M4', 'rail':'+3V3', 'context':'onboard', 'board':4,
                     'typ_ma':0.01, 'peak_ma':0.65, 'sleep_ma':0.0001,
                     'sleep_note':'on-demand measurement; ~0.1 uA idle',
                     'note':'uA between samples'},
 'OLED SSD1306':    {'ref':'M5', 'rail':'+3V3', 'context':'onboard', 'board':4,
                     'typ_ma':15.0, 'peak_ma':30.0, 'sleep_ma':0.01,
                     'sleep_note':'display-off 0xAE + charge-pump off (~uA; not yet a method)',
                     'note':'dominant 3V3 load; scales with lit pixels'},
 'MCP3008 ADC':     {'ref':'U3', 'rail':'+3V3', 'context':'onboard', 'board':2,
                     'typ_ma':0.5, 'peak_ma':0.55, 'sleep_ma':0.00001,
                     'sleep_note':'auto standby (~5 nA) when CS deasserts after each frame',
                     'note':''},
 'MCP4922 DAC':     {'ref':'U4', 'rail':'+3V3', 'context':'onboard', 'board':2,
                     'typ_ma':0.7, 'peak_ma':0.9, 'sleep_ma':0.005,
                     'sleep_note':'disable_sw() software shutdown (SHDN bit)',
                     'note':''},
 'MCP4XXXX dpot':   {'ref':'U5', 'rail':'+3V3', 'context':'onboard', 'board':2,
                     'typ_ma':0.5, 'peak_ma':1.0, 'sleep_ma':0.001,
                     'sleep_note':'shutdown() disconnects the wiper and ladder',
                     'note':'+~0.33 mA ladder (10 kOhm, 3V3->GND) when active'},
 '74HC595':         {'ref':'U2', 'rail':'+3V3', 'context':'onboard', 'board':2,
                     'typ_ma':0.5, 'peak_ma':2.0, 'sleep_ma':0.001,
                     'sleep_note':'static CMOS quiescent when not clocked',
                     'note':'dynamic/switching'},
 'PCA9685':         {'ref':None, 'rail':'+3V3', 'context':'planned', 'board':1,
                     'typ_ma':6.0, 'peak_ma':10.0, 'sleep_ma':0.005,
                     'sleep_note':'off() = sleep bit + all-outputs-off',
                     'note':'board 1 (planned); chip only, PWM loads separate'},
 'I2C pull-ups':    {'ref':None, 'rail':'+3V3', 'context':'onboard', 'board':None,
                     'typ_ma':0.0, 'peak_ma':4.0, 'sleep_ma':0.0,
                     'sleep_note':'only sinks while a line is held low',
                     'note':'Pi built-in 1.8 kOhm x2; momentary'},
 # --- +5V rail: LCD, stepper, servo, Arduino -----------------------------------
 'HD44780 logic':   {'ref':'M8', 'rail':'+5V', 'context':'onboard', 'board':5,
                     'typ_ma':1.5, 'peak_ma':2.0, 'sleep_ma':1.0,
                     'sleep_note':'display-off saves little; no true sleep',
                     'note':'board 5, 4-bit parallel'},
 'HD44780 backlight':{'ref':'M8', 'rail':'+5V', 'context':'onboard', 'board':5,
                     'typ_ma':25.0, 'peak_ma':120.0, 'sleep_ma':0.0,
                     'sleep_note':'backlight can be switched off',
                     'note':'depends on series R / jumper'},
 '28BYJ-48 stepper':{'ref':'M7', 'rail':'+5V', 'context':'onboard', 'board':3,
                     'typ_ma':160.0, 'peak_ma':240.0, 'sleep_ma':0.0,
                     'sleep_note':'coils de-energized at idle (ULN2003 inputs low)',
                     'note':'2-phase -> all-coil energized (via ULN2003)'},
 'ULN2003':         {'ref':'M7', 'rail':'+5V', 'context':'onboard', 'board':3,
                     'typ_ma':0.5, 'peak_ma':1.0, 'sleep_ma':0.0005,
                     'sleep_note':'own quiescent when inputs low',
                     'note':'own draw; motor current counted above'},
 'Servo SG90':      {'ref':'SV1', 'rail':'+5V', 'context':'onboard', 'board':2,
                     'typ_ma':10.0, 'peak_ma':700.0, 'sleep_ma':0.0,
                     'sleep_note':'no PWM signal -> ~0 (holds no torque)',
                     'note':'10 idle / 250 run; stall is the 700 mA spike'},
 'Arduino':         {'ref':'A1', 'rail':'+5V', 'context':'onboard', 'board':5,
                     'typ_ma':25.0, 'peak_ma':40.0, 'sleep_ma':25.0,
                     'sleep_note':'no low-power state used in the test flow',
                     'note':'regulator + power LED'},
 'I2C LCD (PCF8574+HD44780)': {'ref':None, 'rail':'+5V', 'context':'planned', 'board':1,
                     'typ_ma':27.0, 'peak_ma':122.0, 'sleep_ma':1.0,
                     'sleep_note':'display + backlight off; PCF8574 ~uA',
                     'note':'board 1 (planned) I2C LCD; logic + backlight + expander'},
}
