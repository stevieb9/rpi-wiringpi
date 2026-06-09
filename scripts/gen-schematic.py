#!/usr/bin/env python3
"""
Full electrical model of the RPi::WiringPi unit-test platform.
Emits:
  t/test-platform.net          -- KiCad-importable netlist (every connection)
  t/test-pinout-schematic.svg  -- rendered schematic (net-label style)
  t/test-pinout-schematic.jpg
Pinouts are datasheet-verified (see comments).  Run from repo root with the
schematic venv:  /tmp/sch-venv/bin/python scripts/gen-schematic.py
Style: bare ICs for logic (74HC595/MCP3008/MCP4922/MCP42010/MCP23017), module
blocks for sensor breakouts + level-shifter + stepper driver board.
"""

# ------------------------------------------------------------------ COMPONENTS
# ref: (value, footprint-hint, {pin: name})   pin keys are strings.
COMPONENTS = {
 'J1': ('Raspberry_Pi_40pin', 'PinHeader_2x20', {str(i): f'P{i}' for i in range(1,41)}),
 # --- bare logic ICs ---
 'U1': ('MCP23017', 'DIP-28', {  # I2C GPIO expander, 0x20
   '9':'VDD','10':'VSS','12':'SCL','13':'SDA','18':'RESET','15':'A0','16':'A1','17':'A2',
   '20':'INTA','19':'INTB',
   '21':'GPA0','22':'GPA1','23':'GPA2','24':'GPA3','25':'GPA4','26':'GPA5','27':'GPA6','28':'GPA7',
   '1':'GPB0','2':'GPB1','3':'GPB2','4':'GPB3','5':'GPB4','6':'GPB5','7':'GPB6','8':'GPB7'}),
 'U2': ('74HC595', 'DIP-16', {   # shift register
   '16':'VCC','8':'GND','14':'DS','11':'SHCP','12':'STCP','13':'OE','10':'MR','9':'Q7S',
   '15':'Q0','1':'Q1','2':'Q2','3':'Q3','4':'Q4','5':'Q5','6':'Q6','7':'Q7'}),
 'U3': ('MCP3008', 'DIP-16', {   # SPI ADC (bit-banged CS)
   '16':'VDD','15':'VREF','14':'AGND','9':'DGND','13':'CLK','12':'DOUT','11':'DIN','10':'CS',
   '1':'CH0','2':'CH1','3':'CH2','4':'CH3','5':'CH4','6':'CH5','7':'CH6','8':'CH7'}),
 'U4': ('MCP4922', 'DIP-14', {   # dual SPI DAC
   '1':'VDD','3':'CS','4':'SCK','5':'SDI','8':'LDAC','9':'SHDN',
   '14':'VOUTA','13':'VREFA','12':'AVSS','11':'VREFB','10':'VOUTB'}),
 'U5': ('MCP42010', 'DIP-14', {  # dual SPI digital pot (ch0 used)
   '8':'VDD','4':'VSS','1':'CS','2':'SCK','3':'SI','11':'RS','10':'SHDN','9':'SO',
   '14':'PB0','13':'PW0','12':'PA0','5':'PB1','6':'PW1','7':'PA1'}),
 # --- sensor / breakout modules ---
 'M1': ('ADS1115_0x48', 'Module', {'VDD':'VDD','GND':'GND','SCL':'SCL','SDA':'SDA','ADDR':'ADDR','A0':'A0','A1':'A1','A2':'A2','A3':'A3'}),
 'M2': ('ADS1115_0x49', 'Module', {'VDD':'VDD','GND':'GND','SCL':'SCL','SDA':'SDA','ADDR':'ADDR','A0':'A0','A1':'A1','A2':'A2','A3':'A3'}),
 'M3': ('DS3231_ZS042', 'Module', {'VCC':'VCC','GND':'GND','SCL':'SCL','SDA':'SDA','SQW':'SQW','32K':'32K'}),  # +AT24C32 onboard
 'M4': ('BMP180', 'Module', {'VIN':'VIN','GND':'GND','SCL':'SCL','SDA':'SDA'}),
 'M5': ('SSD1306_OLED', 'Module', {'VCC':'VCC','GND':'GND','SCL':'SCL','SDA':'SDA'}),
 'M6': ('BSS138_LLC', 'Module', {'LV':'LV','HV':'HV','GND1':'GND','GND2':'GND','LV1':'LV1','LV2':'LV2','HV1':'HV1','HV2':'HV2'}),
 'M7': ('ULN2003_28BYJ48', 'Module', {'IN1':'IN1','IN2':'IN2','IN3':'IN3','IN4':'IN4','V+':'V+','GND':'GND'}),
 'M8': ('LCD_HD44780', 'Module', {  # 16-pin, 4-bit
   '1':'VSS','2':'VDD','3':'V0','4':'RS','5':'RW','6':'E','11':'D4','12':'D5','13':'D6','14':'D7','15':'A','16':'K'}),
 'A1': ('Arduino_MetroMini', 'Module', {'SDA':'SDA','SCL':'SCL','5V':'5V','GND':'GND'}),
 'SV1': ('Servo', 'Conn-3', {'SIG':'SIG','V+':'V+','GND':'GND'}),
 # --- passives ---
 'RV1': ('10k_pot', 'Pot', {'1':'A','2':'W','3':'B'}),     # LCD contrast
 'R1': ('LDR', 'LDR', {'1':'1','2':'2'}), 'R2': ('LDR','LDR',{'1':'1','2':'2'}), 'R3': ('LDR','LDR',{'1':'1','2':'2'}),
 'R4': ('10k', 'R', {'1':'1','2':'2'}), 'R5': ('10k','R',{'1':'1','2':'2'}), 'R6': ('10k','R',{'1':'1','2':'2'}),
 'R7': ('220', 'R', {'1':'1','2':'2'}),  # LCD backlight series
}

# ------------------------------------------------------------------ NETS
# Each net: (name, [(ref, pin), ...])
NETS = [
 ('+5V', [('J1','2'),('J1','4'),('M6','HV'),('A1','5V'),('M7','V+'),('M8','2'),('SV1','V+'),('RV1','1'),('R7','1')]),
 ('+3V3',[('J1','1'),('J1','17'),('U1','9'),('U1','18'),('U2','16'),('U2','10'),
          ('U3','16'),('U3','15'),('U4','1'),('U4','13'),('U4','11'),('U4','9'),
          ('U5','8'),('U5','11'),('U5','10'),('U5','12'),('M1','VDD'),('M2','VDD'),('M2','ADDR'),
          ('M3','VCC'),('M4','VIN'),('M5','VCC'),('M6','LV')]),
 ('GND',[('J1','6'),('J1','9'),('J1','14'),('J1','20'),('J1','25'),('J1','30'),('J1','34'),('J1','39'),
         ('U1','10'),('U1','15'),('U1','16'),('U1','17'),('U2','8'),('U2','13'),
         ('U3','9'),('U3','14'),('U4','12'),('U4','8'),('U5','4'),('U5','14'),
         ('M1','GND'),('M1','ADDR'),('M2','GND'),('M3','GND'),('M4','GND'),('M5','GND'),
         ('M6','GND1'),('M6','GND2'),('M7','GND'),('M8','1'),('M8','5'),('M8','16'),
         ('A1','GND'),('SV1','GND'),('RV1','3'),('R4','2'),('R5','2'),('R6','2')]),
 # I2C bus (3V3 side)
 ('I2C_SDA',[('J1','3'),('U1','13'),('M1','SDA'),('M2','SDA'),('M3','SDA'),('M4','SDA'),('M5','SDA'),('M6','LV1')]),
 ('I2C_SCL',[('J1','5'),('U1','12'),('M1','SCL'),('M2','SCL'),('M3','SCL'),('M4','SCL'),('M5','SCL'),('M6','LV2')]),
 # Arduino I2C (5V side of level-shifter)
 ('ARD_SDA',[('M6','HV1'),('A1','SDA')]),
 ('ARD_SCL',[('M6','HV2'),('A1','SCL')]),
 # SPI bus
 ('SPI_MOSI',[('J1','19'),('U3','11'),('U4','5'),('U5','3')]),
 ('SPI_MISO',[('J1','21'),('U3','12')]),
 ('SPI_SCLK',[('J1','23'),('U3','13'),('U4','4'),('U5','2')]),
 ('CS_ADC', [('J1','37'),('U3','10')]),   # GPIO26
 ('CS_DAC', [('J1','32'),('U4','3')]),    # GPIO12
 ('CS_DPOT',[('J1','33'),('U5','1')]),    # GPIO13
 # shift register
 ('SR_DATA', [('J1','40'),('U2','14')]),  # GPIO21
 ('SR_CLK',  [('J1','38'),('U2','11')]),  # GPIO20
 ('SR_LATCH',[('J1','36'),('U2','12')]),  # GPIO16
 # LCD (HD44780, 4-bit)
 ('LCD_RS',[('J1','29'),('M8','4')]),     # GPIO5
 ('LCD_E', [('J1','31'),('M8','6')]),     # GPIO6
 ('LCD_D4',[('J1','7'), ('M8','11')]),    # GPIO4
 ('LCD_D5',[('J1','11'),('M8','12')]),    # GPIO17
 ('LCD_D6',[('J1','13'),('M8','13')]),    # GPIO27
 ('LCD_D7',[('J1','15'),('M8','14')]),    # GPIO22
 ('LCD_V0',[('M8','3'),('RV1','2')]),     # contrast wiper
 ('LCD_BL',[('M8','15'),('R7','2')]),     # backlight anode via R7
 # PWM18 -> ADS#1 A0 and servo
 ('PWM18',[('J1','12'),('M1','A0'),('SV1','SIG')]),  # GPIO18
 # UART loopback
 ('UART_LOOP',[('J1','8'),('J1','10')]),  # GPIO14 TXD <-> GPIO15 RXD
 # analog loop-backs
 ('DPOT_WIPER',[('U5','13'),('M1','A1')]),       # PW0 -> ADS#1 A1
 ('DPOT_PA0',  [('U5','12')]),                   # (also on +3V3 above) terminal A
 ('DPOT_PB0',  [('U5','14'),('GND' ,'')][:1]),   # placeholder removed below
 ('DAC_A_CH1', [('U4','14'),('U3','2')]),        # VOUTA -> MCP3008 CH1
 ('DAC_B_CH3', [('U4','10'),('U3','4')]),        # VOUTB -> MCP3008 CH3
 ('SR_Q_CH2',  [('U2','1'),('U3','3')]),         # 74HC595 Q1 -> MCP3008 CH2
 # photo-resistor dividers -> ADS#2
 ('PHOTO_R',[('R1','2'),('R4','1'),('M2','A0')]),
 ('PHOTO_C',[('R2','2'),('R5','1'),('M2','A1')]),
 ('PHOTO_L',[('R3','2'),('R6','1'),('M2','A2')]),
 ('PHOTO_TOP',[('R1','1'),('R2','1'),('R3','1')]),   # LDR tops -> +3V3 (joined below)
 # expander -> stepper driver
 ('EXP_IN1',[('U1','21'),('M7','IN1')]),  # GPA0
 ('EXP_IN2',[('U1','22'),('M7','IN2')]),  # GPA1
 ('EXP_IN3',[('U1','23'),('M7','IN3')]),  # GPA2
 ('EXP_IN4',[('U1','24'),('M7','IN4')]),  # GPA3
 # expander internal loopback A4-7 <-> B4-7
 ('EXP_LB4',[('U1','25'),('U1','5')]),
 ('EXP_LB5',[('U1','26'),('U1','6')]),
 ('EXP_LB6',[('U1','27'),('U1','7')]),
 ('EXP_LB7',[('U1','28'),('U1','8')]),
]
# fold PHOTO_TOP into +3V3, and dpot terminal B to GND, clean the placeholder
NETS = [n for n in NETS if n[0] != 'DPOT_PB0']
for nm, nodes in NETS:
    if nm == '+3V3': nodes += [('R1','1'),('R2','1'),('R3','1')]
    if nm == 'GND':  nodes += [('U5','14')]   # PB0 terminal B
NETS = [n for n in NETS if n[0] not in ('PHOTO_TOP','DPOT_PA0')]

# ------------------------------------------------------------------ NETLIST
def write_netlist(path='t/test-platform.net'):
    lines = ['(export (version "E")', '  (design (source "gen-schematic.py") (date "") (tool "rpi-wiringpi"))',
             '  (components']
    for ref,(val,fp,pins) in COMPONENTS.items():
        lines.append(f'    (comp (ref "{ref}") (value "{val}") (footprint "{fp}"))')
    lines.append('  )')
    lines.append('  (nets')
    for i,(nm,nodes) in enumerate(NETS, 1):
        lines.append(f'    (net (code "{i}") (name "{nm}")')
        for ref,pin in nodes:
            lines.append(f'      (node (ref "{ref}") (pin "{pin}"))')
        lines.append('    )')
    lines.append('  )')
    lines.append(')')
    open(path,'w').write('\n'.join(lines)+'\n')
    print('wrote', path, '-', len(COMPONENTS), 'components,', len(NETS), 'nets')

write_netlist()

# ------------------------------------------------------------------ netlistsvg JSON (for wire-routed render)
J1FUNC = {1:'3V3',2:'5V',3:'GPIO2/SDA',4:'5V',5:'GPIO3/SCL',6:'GND',7:'GPIO4',8:'GPIO14/TXD',
 9:'GND',10:'GPIO15/RXD',11:'GPIO17',12:'GPIO18',13:'GPIO27',14:'GND',15:'GPIO22',16:'GPIO23',
 17:'3V3',18:'GPIO24',19:'GPIO10/MOSI',20:'GND',21:'GPIO9/MISO',22:'GPIO25',23:'GPIO11/SCLK',
 24:'GPIO8',25:'GND',26:'GPIO7',27:'GPIO0',28:'GPIO1',29:'GPIO5',30:'GND',31:'GPIO6',32:'GPIO12',
 33:'GPIO13',34:'GND',35:'GPIO19',36:'GPIO16',37:'GPIO26',38:'GPIO20',39:'GND',40:'GPIO21'}
# which node(s) drive each net (become 'output'); 'REF' = all pins of REF, 'REF*PIN' = just that pin
DRIVER = {'+5V':'J1','+3V3':'J1','GND':'J1','I2C_SDA':'J1','I2C_SCL':'J1','ARD_SDA':'M6','ARD_SCL':'M6',
 'SPI_MOSI':'J1','SPI_SCLK':'J1','SPI_MISO':'U3','CS_ADC':'J1','CS_DAC':'J1','CS_DPOT':'J1',
 'SR_DATA':'J1','SR_CLK':'J1','SR_LATCH':'J1','LCD_RS':'J1','LCD_E':'J1','LCD_D4':'J1','LCD_D5':'J1',
 'LCD_D6':'J1','LCD_D7':'J1','LCD_V0':'RV1','LCD_BL':'R7','PWM18':'J1','UART_LOOP':'J1*8',
 'DPOT_WIPER':'U5','DAC_A_CH1':'U4','DAC_B_CH3':'U4','SR_Q_CH2':'U2','PHOTO_R':'R1','PHOTO_C':'R2',
 'PHOTO_L':'R3','EXP_IN1':'U1','EXP_IN2':'U1','EXP_IN3':'U1','EXP_IN4':'U1',
 'EXP_LB4':'U1*25','EXP_LB5':'U1*26','EXP_LB6':'U1*27','EXP_LB7':'U1*28'}

# per-device power: (pin, rail-label) -> drawn as a small flag at the device
POWER = {
 'U1':[('9','+3V3'),('10','GND')], 'U2':[('16','+3V3'),('8','GND')],
 'U3':[('16','+3V3'),('9','GND')], 'U4':[('1','+3V3'),('12','GND')],
 'U5':[('8','+3V3'),('4','GND')],  'M1':[('VDD','+3V3'),('GND','GND')],
 'M2':[('VDD','+3V3'),('GND','GND')], 'M3':[('VCC','+3V3'),('GND','GND')],
 'M4':[('VIN','+3V3'),('GND','GND')], 'M5':[('VCC','+3V3'),('GND','GND')],
 'M6':[('LV','+3V3'),('HV','+5V'),('GND1','GND')], 'M7':[('V+','+5V'),('GND','GND')],
 'M8':[('2','+5V'),('1','GND')],  'A1':[('5V','+5V'),('GND','GND')],
 'SV1':[('V+','+5V'),('GND','GND')], 'RV1':[('1','+5V'),('3','GND')], 'R7':[('1','+5V')],
 'R1':[('1','+3V3')],'R2':[('1','+3V3')],'R3':[('1','+3V3')],
 'R4':[('2','GND')],'R5':[('2','GND')],'R6':[('2','GND')],
}

def write_nlsvg(path='t/test-platform.nlsvg.json', exclude=(), keep=None, power=False):
    import json
    if keep is not None:
        nets = [(nm,nodes) for nm,nodes in NETS if nm in keep]
    else:
        nets = [(nm,nodes) for nm,nodes in NETS if nm not in exclude]
    netbit = {nm:i+2 for i,(nm,_) in enumerate(nets)}
    outs = {}
    for nm,nodes in nets:
        spec = DRIVER.get(nm)
        for ref,pin in nodes:
            o=False
            if spec and '*' in spec: o = (spec==f'{ref}*{pin}')
            elif spec: o = (ref==spec)
            outs[(ref,pin)] = o
    pinnet_local = {}
    for nm,nodes in nets:
        for ref,pin in nodes: pinnet_local[(ref,pin)] = nm
    cells = {}
    for ref,(val,fp,pins) in COMPONENTS.items():
        ports_dir, conns = {}, {}
        for pin in pins:
            if (ref,pin) not in pinnet_local: continue
            base = (f'{pin}:{J1FUNC[int(pin)]}' if ref=='J1' else pins[pin])
            name = base; k=2
            while name in conns: name=f'{base}#{k}'; k+=1
            conns[name] = [netbit[pinnet_local[(ref,pin)]]]
            ports_dir[name] = 'output' if outs[(ref,pin)] else 'input'
        if conns:
            cells[ref] = {'type': f'{ref} {val}', 'port_directions':ports_dir,
                          'connections':conns, 'attributes':{}}
    netnames = {nm:{'bits':[netbit[nm]],'hide_name':0} for nm,_ in nets}
    if power:                       # add a +3V3/+5V/GND flag at each device pin
        nb = max(netbit.values(), default=1) + 1
        for ref in list(cells):
            for pin,rail in POWER.get(ref,[]):
                pname = COMPONENTS[ref][2].get(pin, pin)
                nm2, k = pname, 2
                while nm2 in cells[ref]['connections']: nm2=f'{pname}#{k}'; k+=1
                cells[ref]['connections'][nm2]=[nb]
                cells[ref]['port_directions'][nm2]='input'
                rtype={'+3V3':'PWR_3V3','+5V':'PWR_5V','GND':'PWR_GND'}[rail]
                cells[f'PF_{ref}_{pin}']={'type':rtype,'port_directions':{'P':'output'},
                                          'connections':{'P':[nb]},'attributes':{}}
                nb+=1
    doc = {'modules':{'test_platform':{'ports':{},'cells':cells,'netnames':netnames}}}
    open(path,'w').write(json.dumps(doc,indent=1))
    print('wrote', path, '-', len(cells), 'cells,', len(nets), 'nets')

write_nlsvg()  # full (power routed)
write_nlsvg('t/test-platform.signals.nlsvg.json', exclude={'+5V','+3V3','GND'}, power=True)  # signals + power flags
# per-subsystem sheets (cleaner reads)
SHEETS = {
 'i2c':     {'I2C_SDA','I2C_SCL','ARD_SDA','ARD_SCL'},
 'spi':     {'SPI_MOSI','SPI_MISO','SPI_SCLK','CS_ADC','CS_DAC','CS_DPOT','SR_DATA','SR_CLK',
             'SR_LATCH','DAC_A_CH1','DAC_B_CH3','SR_Q_CH2','DPOT_WIPER'},
 'stepper': {'EXP_IN1','EXP_IN2','EXP_IN3','EXP_IN4','EXP_LB4','EXP_LB5','EXP_LB6','EXP_LB7',
             'PHOTO_R','PHOTO_C','PHOTO_L'},
 'display': {'LCD_RS','LCD_E','LCD_D4','LCD_D5','LCD_D6','LCD_D7','LCD_V0','LCD_BL','PWM18','UART_LOOP'},
}
for snm,keep in SHEETS.items():
    write_nlsvg(f't/sheet-{snm}.nlsvg.json', keep=keep, power=True)

# ------------------------------------------------------------------ SCHEMATIC (schemdraw, net-label style)
try:
    import schemdraw, schemdraw.elements as e
    schemdraw.config(fontsize=10)
    # net name per (ref,pin)
    pinnet = {}
    for nm,nodes in NETS:
        for ref,pin in nodes: pinnet[(ref,pin)] = nm

    def ic_pins(ref, layout):
        """layout: {side: [pin,...]} -> list of IcPin with net label as name."""
        out=[]
        for side,pins in layout.items():
            for pin in pins:
                net = pinnet.get((ref,pin),'')
                nm = COMPONENTS[ref][2][pin]
                lbl = f'{nm}' + (f'  [{net}]' if net else '')
                out.append(e.IcPin(name=lbl, pin=pin, side=side))
        return out

    LAYOUT = {
     'U1':{'L':['12','13','18','9','10'],'R':['21','22','23','24','25','26','27','28'],'B':['5','6','7','8'],'T':['15','16','17']},
     'U2':{'L':['14','11','12','13','10','16','8'],'R':['15','1','9']},
     'U3':{'L':['11','12','13','10','16','15','9','14'],'R':['1','2','3','4']},
     'U4':{'L':['3','4','5','1','8','9'],'R':['14','13','10','11','12']},
     'U5':{'L':['1','2','3','8','4','11','10'],'R':['13','12','14']},
    }
    MODL = {
     'M1':{'L':['VDD','GND','SCL','SDA','ADDR'],'R':['A0','A1']},
     'M2':{'L':['VDD','GND','SCL','SDA','ADDR'],'R':['A0','A1','A2']},
     'M3':{'L':['VCC','GND','SCL','SDA']},'M4':{'L':['VIN','GND','SCL','SDA']},
     'M5':{'L':['VCC','GND','SCL','SDA']},
     'M6':{'L':['LV','GND1','LV1','LV2'],'R':['HV','GND2','HV1','HV2']},
     'M7':{'L':['IN1','IN2','IN3','IN4','V+','GND']},
     'M8':{'L':['4','6','11','12','13','14','3','15','2','1','5','16']},
     'A1':{'L':['SDA','SCL','5V','GND']},'SV1':{'L':['SIG','V+','GND']},
    }
    # grid placement
    import math
    with schemdraw.Drawing(file='t/test-pinout-schematic.svg', show=False) as d:
        d.config(fontsize=9)
        d += e.Label().label('RPi::WiringPi unit-test platform — schematic', fontsize=20).at((30, 11))
        d += e.Label().label('net-label style: each pin tagged [NET]; trace connections by net name. Full wire-by-wire list: t/test-platform.net',
                             fontsize=11).at((30, 9))
        # J1 in its own far-left lane, full height
        jpins=[e.IcPin(name=f'{p}:{COMPONENTS["J1"][2][p]}'+(f' [{pinnet[("J1",p)]}]' if (("J1",p) in pinnet) else ' [-]'),
                       pin=p, side=('L' if int(p)%2 else 'R')) for p in (str(i) for i in range(1,41))]
        d += e.Ic(pins=jpins, w=6, h=34, pinspacing=1.6).at((-2, -19)).label('J1  Raspberry Pi 40-pin (J8)', loc='top', fontsize=11)
        # the rest in a 3-column grid to the right of J1
        order = ['U1','U2','U3','U4','U5','M1','M2','M3','M4','M5','M6','M7','M8','A1','SV1']
        cols, x0, dx, dy = 3, 12, 11.0, -12.0
        for idx,ref in enumerate(order):
            r,c = divmod(idx, cols)
            x,y = x0 + c*dx, 0 + r*dy
            lay = LAYOUT.get(ref) or MODL[ref]
            npins = sum(len(v) for v in lay.values())
            h = max(5.5, 0.95*max(len(lay.get('L',[])), len(lay.get('R',[]))))
            d += e.Ic(pins=ic_pins(ref,lay), w=4.2, h=h, pinspacing=1.0).at((x,y)).label(f'{ref}  {COMPONENTS[ref][0]}', loc='top', fontsize=10)
        d.save('t/test-pinout-schematic.svg')
        d.save('t/test-pinout-schematic.jpg', dpi=120)
    print('wrote t/test-pinout-schematic.svg / .jpg')
except Exception as ex:
    import traceback; traceback.print_exc()
    print('schematic render skipped:', ex)
