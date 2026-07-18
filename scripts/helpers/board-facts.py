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
 'M9':[('VCC','+3V3'),('GND','GND')],
 'SV1':[('V+','+5V'),('GND','GND')], 'RV1':[('1','+5V'),('3','GND')], 'R7':[('1','+5V')],
 'SW1':[('2','+3V3')],'SW2':[('2','+3V3')],'D1':[('K','GND')],
}

# Bench-wired bus devices, not on any fabbed board (so not in the electrical
# model). key -> (ref, bus, value, driver, tests); ref is None because they have
# no schematic component. Folded into facts/bus-map.json tagged context 'bench'.
BENCH_DEVICES = {
 'MCP23017#3':       (None, 'i2c', 0x22,    'RPi::GPIOExpander::MCP23017', 't/353'),
 'MPU-6050':         (None, 'i2c', 0x68,    'RPi::Gyro::MPU6050',          't/358'),
 'ADS1115(ADXL335)': (None, 'i2c', 0x48,    'RPi::ADC::ADS',               't/360'),
 'ST7735S TFT':      (None, 'spi', 'GPIO8', 'RPi::TFT::ST7735S',           't/447'),
}

# Board 1 is planned/not-yet-built, so its I2C devices are not in the electrical
# model either, but they have passing HW-gated tests and occupy real addresses.
# Same shape as BENCH_DEVICES; folded into the bus map tagged context 'planned'.
PLANNED_DEVICES = {
 'PCF8574 LCD': (None, 'i2c', 0x27, 'RPi::LCD',          't/335'),
 'PCA9685':     (None, 'i2c', 0x40, 'RPi::PWM::PCA9685', 't/440'),
}

# Optional / alternate-mode devices that no test drives but that do occupy an
# address when present. Same shape; folded in tagged context 'optional', with an
# empty tests field. Kept so the generated docs don't lose them.
OPTIONAL_DEVICES = {
 'ATMega-328P': (None, 'i2c', 0x05, 'standalone ATMega-328P (I2C mode)', ''),
}
