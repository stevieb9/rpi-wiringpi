#!/usr/bin/env python3
"""
Electrical model of the RPi::WiringPi unit-test platform, RE-DERIVED FROM THE
TEST SUITE.

Every net here was reconstructed by reading t/*.t, t/multi/*.pl and t/RPiTest.pm,
and by decoding each device constructor's arguments against the driver submodules
under ~/repos. Per-subsystem provenance (the tests that prove each block) is in
the comments below. Facts the tests do NOT establish -- passive values, supply
rails, the I2C level-shifter, exact module identities -- are filled from
README/FAQ and marked "[F] gap-filled".

This module is data-only (same variable names as scripts/helpers/gen-schematic.py:
COMPONENTS, NETS, J1FUNC, DRIVER, POWER, SHEETS) so the existing renderers can be
pointed at it without change. gen-updated-visuals.py injects it and also diffs it
against the in-repo model to prove the re-derivation matches.

Tags in comments: [T]=proven by a test, [L]=submodule default, [F]=gap-filled.
"""

# Curated [F] facts (not test-derivable, e.g. power rails) come from the shared
# board-facts.py, loaded by path (the hyphen blocks a plain import).
import importlib.util as _ilu
import os as _os

def _load_facts():
    p = _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), 'board-facts.py')
    spec = _ilu.spec_from_file_location('board_facts', p)
    m = _ilu.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

_FACTS = _load_facts()

# ------------------------------------------------------------------ COMPONENTS
# ref: (value, footprint-hint, {pin: name})   pin keys are strings.
#
# Device identities & buses, all [T] unless noted:
#   U1 MCP23017  I2C 0x20      t/355:32  (Bank A<->B loopback)
#   U6 MCP23017  I2C 0x21      t/350:24  (stepper drive via Bank A)
#   U2 74HC595   bit-banged    t/435:35  shift_register(400,8,21,20,16)
#   U3 MCP3008   SPI CS=GPIO26 t/410:40-43, t/435:21,35
#   U4 MCP4922   SPI CS=GPIO12 t/410:34-38
#   U5 MCP4XXXX  SPI CS=GPIO13 t/445:36   (modelled as the MCP42010 part [F])
#   M1 ADS1115   I2C 0x48      t/405:42, t/425:77, t/445:35
#   M3 DS3231    I2C 0x68 [L]  t/530 ; carries AT24C32 EEPROM 0x57 [T] t/540-542 [F same board]
#   M4 BMP180    I2C 0x77 [L]  t/531 (bmp(100) arg is a pin-base, not an address)
#   M5 SSD1306   I2C 0x3c      t/500:22  oled('128x64',0x3C,0)
#   M6 level-shifter           [F] not test-derivable (5V Arduino on a 3V3 bus)
#   M7 ULN2003 + 28BYJ-48      t/350:27-32 (driven via U6 Bank A)
#   M8 HD44780 LCD 20x4 4-bit  t/620:36-50  rs5/E6/D4=4/D5=17/D6=27/D7=22
#   A1 Arduino   I2C 0x04      t/605:11,31 (board type "Metro Mini" is [F])
#   SV1 servo    PWM GPIO18    t/425:79
#   SW1/SW2      stepper mag limits  [T] t/350  GPIO17 / GPIO27
#   D1/R8        stepper centre LED  [T] t/350  GPIO19 via R8
#   RV1/R7       passives      [F] LCD contrast / backlight
COMPONENTS = {
 'J1': ('Raspberry_Pi_40pin', 'PinHeader_2x20', {str(i): f'P{i}' for i in range(1,41)}),
 # --- bare logic ICs ---
 'U1': ('MCP23017', 'DIP-28', {  # I2C GPIO expander #1, 0x20 (t/355 loopback)
   '9':'VDD','10':'VSS','12':'SCL','13':'SDA','18':'RESET','15':'A0','16':'A1','17':'A2',
   '20':'INTA','19':'INTB',
   '21':'GPA0','22':'GPA1','23':'GPA2','24':'GPA3','25':'GPA4','26':'GPA5','27':'GPA6','28':'GPA7',
   '1':'GPB0','2':'GPB1','3':'GPB2','4':'GPB3','5':'GPB4','6':'GPB5','7':'GPB6','8':'GPB7'}),
 'U6': ('MCP23017', 'DIP-28', {  # I2C GPIO expander #2, 0x21 (t/350 stepper drive)
   '9':'VDD','10':'VSS','12':'SCL','13':'SDA','18':'RESET','15':'A0','16':'A1','17':'A2',
   '20':'INTA','19':'INTB',
   '21':'GPA0','22':'GPA1','23':'GPA2','24':'GPA3','25':'GPA4','26':'GPA5','27':'GPA6','28':'GPA7',
   '1':'GPB0','2':'GPB1','3':'GPB2','4':'GPB3','5':'GPB4','6':'GPB5','7':'GPB6','8':'GPB7'}),
 'U2': ('74HC595', 'DIP-16', {   # shift register (data=21 clk=20 latch=16)
   '16':'VCC','8':'GND','14':'DS','11':'SHCP','12':'STCP','13':'OE','10':'MR','9':'Q7S',
   '15':'Q0','1':'Q1','2':'Q2','3':'Q3','4':'Q4','5':'Q5','6':'Q6','7':'Q7'}),
 'U3': ('MCP3008', 'DIP-16', {   # SPI ADC (bit-banged CS=GPIO26)
   '16':'VDD','15':'VREF','14':'AGND','9':'DGND','13':'CLK','12':'DOUT','11':'DIN','10':'CS',
   '1':'CH0','2':'CH1','3':'CH2','4':'CH3','5':'CH4','6':'CH5','7':'CH6','8':'CH7'}),
 'U4': ('MCP4922', 'DIP-14', {   # dual SPI DAC (bit-banged CS=GPIO12)
   '1':'VDD','3':'CS','4':'SCK','5':'SDI','8':'LDAC','9':'SHDN',
   '14':'VOUTA','13':'VREFA','12':'AVSS','11':'VREFB','10':'VOUTB'}),
 'U5': ('MCP42010', 'DIP-14', {  # MCP4XXXX dual SPI digital pot, ch0 used (CS=GPIO13)
   # Pinout per Microchip DS11195C (corrected: pins 8-14 were reverse-numbered).
   '1':'CS','2':'SCK','3':'SI','4':'VSS','5':'PB1','6':'PW1','7':'PA1',
   '8':'PA0','9':'PW0','10':'PB0','11':'RS','12':'SHDN','13':'SO','14':'VDD'}),
 # --- sensor / breakout modules ---
 'M1': ('ADS1115_0x48', 'Module', {'VDD':'VDD','GND':'GND','SCL':'SCL','SDA':'SDA','ADDR':'ADDR','ALRT':'ALRT','A0':'A0','A1':'A1','A2':'A2','A3':'A3'}),  # ALRT = ALERT/RDY (TI SBAS444E pin 2), on the module header between ADDR and A0; unused
 'M3': ('DS3231_ZS042', 'Module', {'VCC':'VCC','GND':'GND','SCL':'SCL','SDA':'SDA','SQW':'SQW','32K':'32K'}),  # +AT24C32 0x57 onboard
 'M4': ('BMP180', 'Module', {'VIN':'VIN','GND':'GND','SCL':'SCL','SDA':'SDA'}),
 'M5': ('SSD1306_OLED', 'Module', {'VCC':'VCC','GND':'GND','SCL':'SCL','SDA':'SDA'}),
 'M6': ('BSS138_LLC', 'Module', {'LV':'LV','HV':'HV','GND1':'GND','GND2':'GND','LV1':'LV1','LV2':'LV2','HV1':'HV1','HV2':'HV2'}),  # [F]
 'M7': ('ULN2003_28BYJ48', 'Module', {'IN1':'IN1','IN2':'IN2','IN3':'IN3','IN4':'IN4','V+':'V+','GND':'GND'}),
 'M8': ('LCD_HD44780', 'Module', {  # 16-pin, 4-bit, 20x4
   '1':'VSS','2':'VDD','3':'V0','4':'RS','5':'RW','6':'E','11':'D4','12':'D5','13':'D6','14':'D7','15':'A','16':'K'}),
 'A1': ('Arduino_MetroMini', 'Module', {'SDA':'SDA','SCL':'SCL','5V':'5V','GND':'GND'}),
 'SV1': ('Servo', 'Conn-3', {'SIG':'SIG','V+':'V+','GND':'GND'}),
 # --- passives ([F] gap-filled; tests prove the analog channels, not the parts) ---
 'RV1': ('10k_pot', 'Pot', {'1':'A','2':'W','3':'B'}),     # LCD contrast
 'SW1': ('CW_limit_switch', 'SW', {'1':'1','2':'2'}),   # magnetic, GPIO17 <-> +3V3  [T] t/350
 'SW2': ('CCW_limit_switch', 'SW', {'1':'1','2':'2'}),  # magnetic, GPIO27 <-> +3V3  [T] t/350
 'D1': ('centre_LED', 'LED', {'A':'A','K':'K'}),        # GPIO19 via R8  [T] t/350
 'R8': ('330', 'R', {'1':'1','2':'2'}),                 # centre-LED series  [F]
 'R7': ('220', 'R', {'1':'1','2':'2'}),  # LCD backlight series
}

# ------------------------------------------------------------------ NETS
# Each net: (name, [(ref, pin), ...]). Power/ground rails and passive hookups are
# [F] (rails are not test-derivable); signal nets and loop-backs are [T] with the
# proving test noted inline.
NETS = [
 ('+5V', [('J1','2'),('J1','4'),('M6','HV'),('A1','5V'),('M7','V+'),('M8','2'),('SV1','V+'),('RV1','1'),('R7','1')]),  # [F]
 ('+3V3',[('J1','1'),('J1','17'),('U1','9'),('U1','18'),('U2','16'),('U2','10'),
          ('U3','16'),('U3','15'),('U4','1'),('U4','13'),('U4','11'),('U4','9'),
          ('U5','14'),('U5','11'),('U5','12'),('U5','8'),('M1','VDD'),
          ('U6','9'),('U6','18'),('U6','15'),('SW1','2'),('SW2','2'),
          ('M3','VCC'),('M4','VIN'),('M5','VCC'),('M6','LV')]),  # [F]
 ('GND',[('J1','6'),('J1','9'),('J1','14'),('J1','20'),('J1','25'),('J1','30'),('J1','34'),('J1','39'),
         ('U1','10'),('U1','15'),('U1','16'),('U1','17'),('U2','8'),('U2','13'),
         ('U3','9'),('U3','14'),('U4','12'),('U4','8'),('U5','4'),('U5','10'),
         ('M1','GND'),('M1','ADDR'),('M3','GND'),('M4','GND'),('M5','GND'),
         ('M6','GND1'),('M6','GND2'),('M7','GND'),('M8','1'),('M8','5'),('M8','16'),
         ('U6','10'),('U6','16'),('U6','17'),('D1','K'),
         ('A1','GND'),('SV1','GND'),('RV1','3')]),  # [F]
 # I2C bus (3V3 side) -- [T] addresses t/605,530,355,531,540-542,350,500
 ('I2C_SDA',[('J1','3'),('U1','13'),('U6','13'),('M1','SDA'),('M3','SDA'),('M4','SDA'),('M5','SDA'),('M6','LV1')]),
 ('I2C_SCL',[('J1','5'),('U1','12'),('U6','12'),('M1','SCL'),('M3','SCL'),('M4','SCL'),('M5','SCL'),('M6','LV2')]),
 # Arduino I2C (5V side of level-shifter) -- [F] shifter; [T] address 0x04 t/605
 ('ARD_SDA',[('M6','HV1'),('A1','SDA')]),
 ('ARD_SCL',[('M6','HV2'),('A1','SCL')]),
 # SPI bus -- [L] MOSI/MISO/SCLK are hardware SPI0; [T] CS pins
 ('SPI_MOSI',[('J1','19'),('U3','11'),('U4','5'),('U5','3')]),
 ('SPI_MISO',[('J1','21'),('U3','12')]),                       # only MCP3008 reads [T]
 ('SPI_SCLK',[('J1','23'),('U3','13'),('U4','4'),('U5','2')]),
 ('CS_ADC', [('J1','37'),('U3','10')]),   # GPIO26  [T] t/410,335
 ('CS_DAC', [('J1','32'),('U4','3')]),    # GPIO12  [T] t/410
 ('CS_DPOT',[('J1','33'),('U5','1')]),    # GPIO13  [T] t/445
 # shift register -- [T] t/435:35 shift_register(400,8,21,20,16)
 ('SR_DATA', [('J1','40'),('U2','14')]),  # GPIO21
 ('SR_CLK',  [('J1','38'),('U2','11')]),  # GPIO20
 ('SR_LATCH',[('J1','36'),('U2','12')]),  # GPIO16
 # LCD (HD44780, 4-bit, 20x4) -- [T] t/620:36-50; D4-D7 physical pins [F] convention
 ('LCD_RS',[('J1','29'),('M8','4')]),     # GPIO5
 ('LCD_E', [('J1','31'),('M8','6')]),     # GPIO6
 ('LCD_D4',[('J1','7'), ('M8','11')]),    # GPIO4
 ('LCD_D5',[('J1','11'),('M8','12'),('SW1','1')]),    # GPIO17 (+ stepper CW limit switch)
 ('LCD_D6',[('J1','13'),('M8','13'),('SW2','1')]),    # GPIO27 (+ stepper CCW limit switch)
 ('LCD_D7',[('J1','15'),('M8','14')]),    # GPIO22
 ('LCD_V0',[('M8','3'),('RV1','2')]),     # contrast wiper [F]
 ('LCD_BL',[('M8','15'),('R7','2')]),     # backlight anode via R7 [F]
 # PWM18 -> ADS#1 A0 and servo -- [T] t/405:44, t/425:79,89
 ('PWM18',[('J1','12'),('M1','A0'),('SV1','SIG')]),  # GPIO18
 # UART loopback -- [T] t/610
 ('UART_LOOP',[('J1','8'),('J1','10')]),  # GPIO14 TXD <-> GPIO15 RXD
 # analog loop-backs -- [T]
 ('DPOT_WIPER',[('U5','9'),('M1','A1')]),        # PW0(9) -> ADS#1 A1   t/445:23,54
 ('DAC_A_CH1', [('U4','14'),('U3','2')]),        # VOUTA -> MCP3008 CH1  t/410:24,58
 ('DAC_B_CH3', [('U4','10'),('U3','4')]),        # VOUTB -> MCP3008 CH3  t/410:25,76
 ('SR_Q_CH2',  [('U2','1'),('U3','3')]),         # 74HC595 Q1 -> MCP3008 CH2  t/435:39,43
 # stepper centre LED (GPIO19 -> R8 -> LED -> GND) -- [T] t/350
 ('LED_CTRL',[('J1','35'),('R8','1')]),   # GPIO19
 ('LED_ANODE',[('R8','2'),('D1','A')]),
 # expander #2 (0x21) -> stepper driver -- [T] t/350 GPA0-3 -> ULN2003
 ('EXP_IN1',[('U6','21'),('M7','IN1')]),  # #2 GPA0
 ('EXP_IN2',[('U6','22'),('M7','IN2')]),  # #2 GPA1
 ('EXP_IN3',[('U6','23'),('M7','IN3')]),  # #2 GPA2
 ('EXP_IN4',[('U6','24'),('M7','IN4')]),  # #2 GPA3
 # expander #1 (0x20) full A<->B loopback, GPA(n)<->GPB(7-n) -- [T] t/355
 ('EXP_LB0',[('U1','21'),('U1','8')]),    # GPA0 <-> GPB7
 ('EXP_LB1',[('U1','22'),('U1','7')]),    # GPA1 <-> GPB6
 ('EXP_LB2',[('U1','23'),('U1','6')]),    # GPA2 <-> GPB5
 ('EXP_LB3',[('U1','24'),('U1','5')]),    # GPA3 <-> GPB4
 ('EXP_LB4',[('U1','25'),('U1','4')]),    # GPA4 <-> GPB3
 ('EXP_LB5',[('U1','26'),('U1','3')]),    # GPA5 <-> GPB2
 ('EXP_LB6',[('U1','27'),('U1','2')]),    # GPA6 <-> GPB1
 ('EXP_LB7',[('U1','28'),('U1','1')]),    # GPA7 <-> GPB0
]
# fold dpot terminal B (U5 PB0) to GND ([F] passive)
for nm, nodes in NETS:
    if nm == 'GND': nodes += [('U5','10')]

# ------------------------------------------------------------------ render metadata
# Bare 40-pin header native functions (orientation only; standard Pi pinout).
J1FUNC = {1:'3V3',2:'5V',3:'GPIO2/SDA',4:'5V',5:'GPIO3/SCL',6:'GND',7:'GPIO4',8:'GPIO14/TXD',
 9:'GND',10:'GPIO15/RXD',11:'GPIO17',12:'GPIO18',13:'GPIO27',14:'GND',15:'GPIO22',16:'GPIO23',
 17:'3V3',18:'GPIO24',19:'GPIO10/MOSI',20:'GND',21:'GPIO9/MISO',22:'GPIO25',23:'GPIO11/SCLK',
 24:'GPIO8',25:'GND',26:'GPIO7',27:'GPIO0',28:'GPIO1',29:'GPIO5',30:'GND',31:'GPIO6',32:'GPIO12',
 33:'GPIO13',34:'GND',35:'GPIO19',36:'GPIO16',37:'GPIO26',38:'GPIO20',39:'GND',40:'GPIO21'}
# which node(s) drive each net (become 'output'); 'REF'=all pins of REF, 'REF*PIN'=just that pin
DRIVER = {'+5V':'J1','+3V3':'J1','GND':'J1','I2C_SDA':'J1','I2C_SCL':'J1','ARD_SDA':'M6','ARD_SCL':'M6',
 'SPI_MOSI':'J1','SPI_SCLK':'J1','SPI_MISO':'U3','CS_ADC':'J1','CS_DAC':'J1','CS_DPOT':'J1',
 'SR_DATA':'J1','SR_CLK':'J1','SR_LATCH':'J1','LCD_RS':'J1','LCD_E':'J1','LCD_D4':'J1','LCD_D5':'J1',
 'LCD_D6':'J1','LCD_D7':'J1','LCD_V0':'RV1','LCD_BL':'R7','PWM18':'J1','UART_LOOP':'J1*8',
 'DPOT_WIPER':'U5','DAC_A_CH1':'U4','DAC_B_CH3':'U4','SR_Q_CH2':'U2',
 'LED_CTRL':'J1','LED_ANODE':'R8','EXP_IN1':'U6','EXP_IN2':'U6','EXP_IN3':'U6','EXP_IN4':'U6',
 'EXP_LB0':'U1*21','EXP_LB1':'U1*22','EXP_LB2':'U1*23','EXP_LB3':'U1*24',
 'EXP_LB4':'U1*25','EXP_LB5':'U1*26','EXP_LB6':'U1*27','EXP_LB7':'U1*28'}
# Per-device power flags are [F] (rails are not test-derivable), so they come
# from the shared curated board-facts.py rather than being re-stated here.
POWER = _FACTS.POWER
# per-subsystem sheets (cleaner reads)
SHEETS = {
 'i2c':     {'I2C_SDA','I2C_SCL','ARD_SDA','ARD_SCL'},
 'spi':     {'SPI_MOSI','SPI_MISO','SPI_SCLK','CS_ADC','CS_DAC','CS_DPOT','SR_DATA','SR_CLK',
             'SR_LATCH','DAC_A_CH1','DAC_B_CH3','SR_Q_CH2','DPOT_WIPER'},
 'stepper': {'EXP_IN1','EXP_IN2','EXP_IN3','EXP_IN4',
             'EXP_LB0','EXP_LB1','EXP_LB2','EXP_LB3','EXP_LB4','EXP_LB5','EXP_LB6','EXP_LB7',
             'LED_CTRL','LED_ANODE','LCD_D5','LCD_D6'},
 'display': {'LCD_RS','LCD_E','LCD_D4','LCD_D5','LCD_D6','LCD_D7','LCD_V0','LCD_BL','PWM18','UART_LOOP'},
}
