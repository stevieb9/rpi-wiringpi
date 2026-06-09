#!/usr/bin/env python3
# Generates two JPEG wiring diagrams for the RPi::WiringPi unit-test platform.
from PIL import Image, ImageDraw, ImageFont

FREG = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
FBLD = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'
def F(sz, bold=False): return ImageFont.truetype(FBLD if bold else FREG, sz)

INK = '#111827'
PI   = ('#dbeafe', '#1d4ed8')   # Pi / GPIO net
V3   = ('#dcfce7', '#15803d')   # 3V3 component
V5   = ('#fee2e2', '#b91c1c')   # 5V component
PASS = ('#f1f5f9', '#64748b')   # passive / mechanical
I2CC = ('#ede9fe', '#7c3aed')   # I2C
SPIC = ('#ccfbf1', '#0d9488')   # SPI
LCDC = ('#ffedd5', '#c2410c')   # LCD (5V)
SHFC = ('#fef9c3', '#a16207')   # shift register
GNDC = ('#e5e7eb', '#374151')   # GND
SPRC = ('#f3f4f6', '#9ca3af')   # spare
BUS  = '#7c3aed'
LOOP = '#d97706'

def text_c(d, cx, y, s, font, fill=INK):
    w = d.textlength(s, font=font); d.text((cx - w/2, y), s, font=font, fill=fill)

def box(d, x, y, w, h, title, sublines, pal, r=12):
    fill, outline = pal
    d.rounded_rectangle([x, y, x+w, y+h], radius=r, fill=fill, outline=outline, width=3)
    text_c(d, x+w/2, y+8, title, F(16, True), outline)
    for i, s in enumerate(sublines):
        text_c(d, x+w/2, y+30+i*16, s, F(12), INK)

def legend(d, x, y, items):
    fx = x
    for label, pal in items:
        fill, outline = pal if isinstance(pal, tuple) else (pal, pal)
        d.rounded_rectangle([fx, y, fx+22, y+22], radius=4, fill=fill, outline=outline, width=2)
        d.text((fx+30, y+3), label, font=F(13), fill=INK)
        fx += 40 + d.textlength(label, font=F(13)) + 24

# ---------------------------------------------------------------- OVERVIEW ----
def overview():
    W, H = 1780, 1060
    img = Image.new('RGB', (W, H), 'white'); d = ImageDraw.Draw(img)
    text_c(d, W/2, 14, 'RPi::WiringPi unit-test platform — bus / block overview', F(24, True))
    text_c(d, W/2, 44, 'colour = component supply rail   ·   buses shared, devices by address / chip-select', F(14))

    # Pi header
    box(d, 640, 78, 500, 60, 'Raspberry Pi  —  40-pin header (J8)',
        ['3V3 logic   ·   GPIO / I2C / SPI / PWM'], PI)

    # I2C bus
    d.line([40, 226, 1740, 226], fill=BUS, width=6)
    d.line([890, 138, 890, 226], fill=BUS, width=4)
    d.text((46, 200), 'I2C BUS   ·   SDA=GPIO2  SCL=GPIO3   ·   3V3 pull-ups', font=F(14, True), fill=BUS)
    i2c = [('ADS1115 #1', ['0x48', 'PWM/servo+dpot'], V3),
           ('ADS1115 #2', ['0x49', 'stepper sense'], V3),
           ('MCP23017',   ['0x20', 'GPIO expander'], V3),
           ('DS3231 RTC', ['0x68'], V3),
           ('AT24C32',    ['0x57', 'EEPROM'], V3),
           ('BMP180',     ['0x77', '3V3 only'], V3),
           ('OLED',       ['0x3c', 'SSD1306'], V3),
           ('Arduino',    ['0x04', 'via lvl-shift'], V5)]
    bx, bw, gap = 40, 192, 19
    cx_for = {}
    for i, (t, s, pal) in enumerate(i2c):
        x = bx + i*(bw+gap)
        box(d, x, 250, bw, 84, t, s, pal)
        cx_for[t] = x + bw/2
        d.line([x+bw/2, 226, x+bw/2, 250], fill=BUS, width=3)

    # SPI bus
    d.line([40, 430, 720, 430], fill=BUS, width=6)
    d.line([820, 138, 820, 162], fill=BUS, width=4)
    d.line([820, 162, 380, 162], fill=BUS, width=4)
    d.line([380, 162, 380, 430], fill=BUS, width=4)
    d.text((46, 404), 'SPI BUS   ·   MOSI=GPIO10  MISO=GPIO9  SCLK=GPIO11   ·   CS bit-banged', font=F(14, True), fill=BUS)
    spi = [('MCP3008 ADC', ['CS=GPIO26'], SPIC),
           ('MCP4922 DAC', ['CS=GPIO12'], SPIC),
           ('MCP4XXXX pot',['CS=GPIO13'], SPIC)]
    for i, (t, s, pal) in enumerate(spi):
        x = 40 + i*(220+24)
        box(d, x, 454, 220, 70, t, s, pal)
        d.line([x+110, 430, x+110, 454], fill=BUS, width=3)

    # GPIO-direct fixtures
    box(d, 760, 454, 240, 70, 'LCD HD44780', ['5V glass · 3V3 logic', 'RS5 E6 D4=4 D5=17 D6=27 D7=22'], LCDC)
    box(d,1020, 454, 230, 70, '74HC595', ['shift reg · 3V3', 'DATA21 CLK20 LATCH16'], SHFC)
    box(d,1270, 454, 200, 70, 'Servo', ['5V power', 'signal = GPIO18'], V5)
    box(d,1490, 454, 250, 70, 'UART loopback', ['3V3', 'GPIO14 TX -> GPIO15 RX'], V3)

    box(d, 760, 548, 240, 64, 'GPIO18 net', ['PWM / servo / interrupt', 'one wire -> ADS#1 A0'], PI)

    # Stepper subsystem
    box(d, 40, 600, 230, 74, 'ULN2003 driver', ['5V', 'in <- MCP23017 GPA0-3'], V5)
    box(d, 300, 600, 230, 74, '28BYJ-48 stepper', ['5V motor'], V5)
    box(d, 560, 600, 300, 74, '3x photo resistor (R/C/L)', ['laser position rig', '-> ADS#2 0x49 A0/A1/A2'], PASS)
    d.line([270, 637, 300, 637], fill=LOOP, width=4)        # ULN2003 -> stepper
    d.line([cx_for['MCP23017'], 334, cx_for['MCP23017'], 590, 155, 590, 155, 600], fill=LOOP, width=3, joint='curve')

    # Loop-back panel
    px, py, pw, ph = 900, 600, 840, 360
    d.rounded_rectangle([px, py, px+pw, py+ph], radius=12, fill='#fffbeb', outline=LOOP, width=3)
    text_c(d, px+pw/2, py+10, 'Loop-backs  —  every output is read back (drive  ===>  measure)', F(16, True), LOOP)
    lbs = ['GPIO18 PWM / servo            ===>  ADS#1 (0x48) A0',
           'MCP4XXXX dpot wiper           ===>  ADS#1 (0x48) A1',
           'MCP4922 DAC out0 / out1       ===>  MCP3008 CH1 / CH3',
           '74HC595 Q-outputs             ===>  MCP3008 CH2',
           'MCP23017 GPA4-7              <===>  MCP23017 GPB4-7   (loopback pairs)',
           'MCP23017 GPA0-3  -> ULN2003 -> 28BYJ-48 stepper      (drive)',
           '3x photo resistor (R/C/L)     ===>  ADS#2 (0x49) A0/A1/A2',
           'UART GPIO14 TXD               ===>  GPIO15 RXD']
    for i, s in enumerate(lbs):
        d.text((px+24, py+44+i*38), s, font=F(15), fill=INK)

    legend(d, 40, 1000, [('Pi / GPIO net', PI), ('3V3 part', V3), ('5V part', V5),
                         ('passive', PASS), ('I2C dev', I2CC), ('SPI dev', SPIC),
                         ('loop-back', (LOOP, LOOP))])
    img.save('t/test-pinout-overview.jpg', 'JPEG', quality=92)
    print('wrote t/test-pinout-overview.jpg', img.size)

# ------------------------------------------------------------------ DETAIL ----
PINS = {
 1:('3V3','pwr3'),2:('5V','pwr5'),
 3:('GPIO2   I2C SDA  -> bus','i2c'),4:('5V','pwr5'),
 5:('GPIO3   I2C SCL  -> bus','i2c'),6:('GND','gnd'),
 7:('GPIO4   -> LCD D4','lcd'),8:('GPIO14  UART TXD -> GPIO15','uart'),
 9:('GND','gnd'),10:('GPIO15  UART RXD <- GPIO14','uart'),
 11:('GPIO17  -> LCD D5','lcd'),12:('GPIO18  PWM/servo/INT -> ADS#1 A0','pwm'),
 13:('GPIO27  -> LCD D6','lcd'),14:('GND','gnd'),
 15:('GPIO22  -> LCD D7','lcd'),16:('GPIO23  (spare)','spare'),
 17:('3V3','pwr3'),18:('GPIO24  (spare)','spare'),
 19:('GPIO10  SPI MOSI -> 3 SPI dev','spi'),20:('GND','gnd'),
 21:('GPIO9   SPI MISO <- MCP3008','spi'),22:('GPIO25  (spare)','spare'),
 23:('GPIO11  SPI SCLK -> 3 SPI dev','spi'),24:('GPIO8   SPI CE0 (unused)','spare'),
 25:('GND','gnd'),26:('GPIO7   SPI CE1 (unused)','spare'),
 27:('GPIO0   ID_SD (reserved EEPROM)','idc'),28:('GPIO1   ID_SC (reserved EEPROM)','idc'),
 29:('GPIO5   -> LCD RS','lcd'),30:('GND','gnd'),
 31:('GPIO6   -> LCD E','lcd'),32:('GPIO12  MCP4922 DAC CS (bit-bang)','spi'),
 33:('GPIO13  MCP4XXXX dpot CS (bit-bang)','spi'),34:('GND','gnd'),
 35:('GPIO19  (spare)','spare'),36:('GPIO16  74HC595 LATCH','shift'),
 37:('GPIO26  MCP3008 CS (bit-bang)','spi'),38:('GPIO20  74HC595 CLOCK','shift'),
 39:('GND','gnd'),40:('GPIO21  74HC595 DATA','shift'),
}
GROUP = {'pwr3':V3,'pwr5':V5,'gnd':GNDC,'i2c':I2CC,'spi':SPIC,'lcd':LCDC,
         'uart':PI,'pwm':PI,'shift':SHFC,'spare':SPRC,'idc':SPRC}

def detail():
    W, H = 1520, 1730
    img = Image.new('RGB', (W, H), 'white'); d = ImageDraw.Draw(img)
    text_c(d, W/2, 14, 'RPi::WiringPi unit-test platform — 40-pin header, pin by pin', F(24, True))
    text_c(d, W/2, 44, 'physical two-column header (pin 1 top-left).  Each pin: BCM + test-platform destination.', F(13))

    rh, top = 60, 96
    lx, rx, cw = 60, 780, 660
    for r in range(20):
        lp, rpn = 2*r+1, 2*r+2
        y = top + r*(rh+6)
        for pn, x in ((lp, lx), (rpn, rx)):
            label, grp = PINS[pn]
            fill, outline = GROUP[grp]
            d.rounded_rectangle([x, y, x+cw, y+rh], radius=8, fill=fill, outline=outline, width=2)
            # phys-pin chip
            d.rounded_rectangle([x+8, y+8, x+54, y+rh-8], radius=6, fill='white', outline=outline, width=2)
            text_c(d, x+31, y+rh/2-9, str(pn), F(18, True), outline)
            d.text((x+68, y+rh/2-10), label, font=F(15), fill=INK)
    # centre gutter marker
    d.line([735, top, 735, top+20*(rh+6)-6], fill='#cbd5e1', width=2)

    # device-to-device loop-backs (not Pi pins)
    py = top + 20*(rh+6) + 16
    d.rounded_rectangle([60, py, 1460, py+220], radius=12, fill='#fffbeb', outline=LOOP, width=3)
    text_c(d, 760, py+10, 'Inter-device loop-backs (no Pi pin) — drive ===> read back', F(17, True), LOOP)
    rows = ['MCP4922 DAC out0 ===> MCP3008 CH1        MCP4922 DAC out1 ===> MCP3008 CH3',
            '74HC595 Q-output ===> MCP3008 CH2        MCP4XXXX dpot wiper ===> ADS#1 (0x48) A1',
            'MCP23017 GPA0-3 -> ULN2003 -> 28BYJ-48 stepper      GPA4-7 <===> GPB4-7 (loopback)',
            '3x photo resistor R/C/L ===> ADS#2 (0x49) A0/A1/A2   (laser position rig)',
            'MCP23017 RESET (chip pin 18) -> 3V3      5V Arduino I2C via 3V3<->5V level-shifter']
    for i, s in enumerate(rows):
        d.text((84, py+44+i*32), s, font=F(14), fill=INK)

    legend(d, 60, py+240, [('3V3', V3), ('5V', V5), ('GND', GNDC), ('I2C', I2CC),
                           ('SPI', SPIC), ('LCD 5V', LCDC), ('shift-reg', SHFC),
                           ('PWM/UART', PI), ('spare', SPRC)])
    img.save('t/test-pinout-detail.jpg', 'JPEG', quality=92)
    print('wrote t/test-pinout-detail.jpg', img.size)

overview(); detail()
