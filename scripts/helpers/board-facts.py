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
"""

# per-device power: (pin, rail-label) -> drawn as a small flag at the device
POWER = {
 'U1':[('9','+3V3'),('10','GND')], 'U2':[('16','+3V3'),('8','GND')],
 'U3':[('16','+3V3'),('9','GND')], 'U4':[('1','+3V3'),('12','GND')],
 'U5':[('8','+3V3'),('4','GND')],  'M1':[('VDD','+3V3'),('GND','GND')],
 'U6':[('9','+3V3'),('10','GND')], 'M3':[('VCC','+3V3'),('GND','GND')],
 'M4':[('VIN','+3V3'),('GND','GND')], 'M5':[('VCC','+3V3'),('GND','GND')],
 'M6':[('LV','+3V3'),('HV','+5V'),('GND1','GND')], 'M7':[('V+','+5V'),('GND','GND')],
 'M8':[('2','+5V'),('1','GND')],  'A1':[('5V','+5V'),('GND','GND')],
 'SV1':[('V+','+5V'),('GND','GND')], 'RV1':[('1','+5V'),('3','GND')], 'R7':[('1','+5V')],
 'SW1':[('2','+3V3')],'SW2':[('2','+3V3')],'D1':[('K','GND')],
}
