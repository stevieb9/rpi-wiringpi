#!/usr/bin/env python3
"""Assemble the per-subsystem schematic SVGs into multi-page A3 and A4 PDFs
with a title/contents page.  Normally invoked via scripts/gen-test-platform.pl;
to run standalone (in the schematic venv) from the repo root, after
scripts/helpers/gen-schematic.py + netlistsvg have produced the sheet SVGs:
    /tmp/sch-venv/bin/python scripts/helpers/gen-pdf.py
Outputs: t/test-platform-schematic-A3.pdf, -A4.pdf
"""
import cairosvg, io, datetime
from pypdf import PdfWriter, PdfReader, Transformation, PageObject

date = datetime.date.today().isoformat()
SHEETS = [
 ('Whole board — all signals + power', 't/test-pinout-schematic-signals.svg'),
 ('I2C bus',                            't/sheet-i2c.svg'),
 ('SPI bus',                            't/sheet-spi.svg'),
 ('Stepper + ADC position sense',       't/sheet-stepper.svg'),
 ('Display / PWM / UART',               't/sheet-display.svg'),
]
rows = "".join(
 f'<text x="150" y="{360+i*46}" font-size="22">Page {i+2}&#160;&#160;&#183;&#160;&#160;{t}</text>'
 for i,(t,_) in enumerate(SHEETS))
TITLE = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1190.55pt" height="841.89pt"
 viewBox="0 0 1190 842" font-family="DejaVu Sans Mono, monospace" fill="#111">
<rect width="1190" height="842" fill="white"/>
<rect x="40" y="40" width="1110" height="762" fill="none" stroke="#111" stroke-width="2"/>
<text x="595" y="150" font-size="42" font-weight="bold" text-anchor="middle">RPi::WiringPi — Unit-Test Platform</text>
<text x="595" y="200" font-size="24" text-anchor="middle">Full wiring schematic  ·  Raspberry Pi 40-pin (J8) + 23 devices</text>
<line x1="150" y1="240" x2="1040" y2="240" stroke="#111"/>
<text x="150" y="300" font-size="26" font-weight="bold">Contents</text>
{rows}
<text x="150" y="640" font-size="20" font-weight="bold">Power</text>
<path d="M150,690 h26 l-13,18 z M163,708 v14" fill="none" stroke="#111" stroke-width="1.5"/>
<text x="150" y="676" font-size="16">+3V3</text>
<path d="M300,690 h26 l-13,18 z M313,708 v14" fill="none" stroke="#111" stroke-width="1.5"/>
<text x="300" y="676" font-size="16">+5V</text>
<path d="M450,690 v14 M438,704 h24 M442,710 h16 M447,716 h6" fill="none" stroke="#111" stroke-width="1.5"/>
<text x="430" y="676" font-size="16">GND</text>
<text x="150" y="745" font-size="15">3V3 logic throughout.  5V parts: LCD, stepper (ULN2003), servo, Arduino (via BSS138 shifter).</text>
<text x="150" y="772" font-size="13">Pinouts datasheet-verified · single-sourced from facts/test-platform.net · generated {date}</text>
</svg>'''

def page(svg_url=None, svg_str=None):
    b = io.BytesIO()
    if svg_str is not None: cairosvg.svg2pdf(bytestring=svg_str.encode(), write_to=b)
    else: cairosvg.svg2pdf(url=svg_url, write_to=b)
    b.seek(0); return PdfReader(b).pages[0]

def fit(src, PW, PH, M=40):
    sw, sh = float(src.mediabox.width), float(src.mediabox.height)
    s = min((PW-2*M)/sw, (PH-2*M)/sh)
    blank = PageObject.create_blank_page(width=PW, height=PH)
    blank.merge_transformed_page(src, Transformation().scale(s).translate((PW-sw*s)/2, (PH-sh*s)/2))
    return blank

def build(name, W, H):   # W,H = landscape
    w = PdfWriter()
    w.add_page(fit(page(svg_str=TITLE), W, H))
    for _, svg in SHEETS:
        p = page(svg_url=svg); sw, sh = float(p.mediabox.width), float(p.mediabox.height)
        PW, PH = (H, W) if sh/sw > H/W else (W, H)   # portrait if taller than the landscape aspect
        w.add_page(fit(p, PW, PH))
    out = f't/test-platform-schematic-{name}.pdf'
    with open(out, 'wb') as f: w.write(f)
    print('wrote', out, '-', len(w.pages), 'pages')

build('A3', 1190.55, 841.89)
build('A4', 841.89, 595.28)
