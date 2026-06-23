# Unit-Test Platform — Board Layout Proposal (WORKING DRAFT)

> **Status:** starting point — expect to edit. This is a planning aid, not a
> finalized spec.
>
> **Wiring source of truth:** [`test-pinout-doc.md`](test-pinout-doc.md). Every
> pin/device fact below is pulled from there (and ultimately from the test suite).
> Section references like "§7" point into that document.
>
> **Board 3 is FINALIZED + ordered — do not change it.** It appears here only as a
> fixed reference so the cross-board nets line up.

---

## Ground rules

- **Board 1 = the Raspberry Pi connection only.** No test devices on it. It is the
  40-pin header + the power/signal fan-out hub to the satellites. **Built last.**
- **Board 3 = DONE** — the two MCP23017 expanders (0x20 loopback, 0x21 stepper
  drive) plus the off-board stepper/ULN2003/magnet modules. Frozen.
- **Three new satellites** use board numbers **2, 4, 5** (3 is taken).
- **"Everything loops back"** (§1): every output the library can drive is wired
  back to an input it can read. Keep each loop-back pair *on the same board*
  wherever possible, so the analog/timing-sensitive return wires don't cross a
  connector.

---

## Board map

| Board | Role | Rail(s) | Devices | Tests |
|-------|------|---------|---------|-------|
| **1** *(last, passive)* | Pi connection + power/signal fan-out | 3V3 + 5V | **none** | (host) |
| **2** | Analog loop-back + servo | 3V3 + 5V | ADS1015, MCP3008, MCP4922 DAC, MCP4XXXX dpot, 74HC595, servo | 109, 140, 310, 325, 335, 345 |
| **3** *(DONE)* | I2C expanders + stepper | 3V3 + 5V | MCP23017 ×2, ULN2003 + 28BYJ-48 + magnets (off-board) | 330, 450 |
| **4** | I2C sensors | 3V3 | DS3231 RTC, AT24C32 EEPROM, BMP180, OLED | 320, 340, 420–422, 500–520 |
| **5** | 5V logic | 5V + 3V3 | HD44780 LCD, Arduino + I2C level-shifter, UART loop-back | 305, 315, 525 |

---

## Board 1 — Pi host (passive; build last)

Just the Pi 40-pin connection, the power rails, and the outgoing connectors to the
satellites. No devices, no I2C pull-ups (see cross-board notes). The spare GPIO
that the suite toggles but wires to nothing live here as **test points** (see
glossary): **GPIO23, 24, 25**, plus **GPIO0/1** brought to a pad but otherwise
unrouted (reserved ID-EEPROM pins, §9).

**Fans out:** +5V, +3V3, GND, and the per-board signal sets listed under each
satellite below.

---

## Board 2 — analog loop-back + servo (the dense one)

Self-contained: 4 of the 5 loop-backs stay on this board; only **GPIO18 enters
from board 1**.

| Device | CS / pins (BCM) | Loop-back |
|--------|-----------------|-----------|
| ADS1015 | I2C 0x48 | A1 ← dpot wiper *(on-board)*; **A0 ← GPIO18** *(from board 1)* |
| MCP3008 ADC | CS=26 (+ MISO9/MOSI10/SCLK11) | CH1←DAC outA, CH3←DAC outB, CH2←595 Q0 *(on-board)* |
| MCP4922 DAC | CS=12 | outA→MCP3008 CH1, outB→MCP3008 CH3 *(on-board)* |
| MCP4XXXX dpot | CS=13 | wiper → ADS A1 *(on-board)* |
| 74HC595 | DATA=21, CLK=20, LATCH=16 | Q0 → MCP3008 CH2 *(on-board)* |
| Servo (SG90) | GPIO18 (5V power, 3V3 signal) | shares GPIO18 with ADS A0 |

**Connectors (final — authoritative net list in `scripts/helpers/board-2-model.py`):**

| Ref | Group | Pins | Pinout |
|-----|-------|-----:|--------|
| **J1** | power in | 3 | `+3V3, GND, +3V3` (pin 3 = +3V3 sense return → board 1) |
| **J2** | servo feed in | 3 | `+5V, GND, PWM` (+5V powers servo; PWM = GPIO18 signal) |
| **J3** | I2C in | 2 | `SDA, SCL` |
| **J4** | SPI bus in | 3 | `MISO, MOSI, SCLK` |
| **J5** | chip selects in | 3 | `CS26, CS12, CS13` |
| **J6** | shift register in | 3 | `DATA21, CLK20, LATCH16` |
| **J7** | servo (plugs in) | 3 | `GND, V+, SIG` (V+ = +5V, SIG = GPIO18) |

+5V is servo-only (J2 → J7); every IC is 3V3. GPIO18 fans to ADS A0 + J7 SIG.

Notes: all three SPI chip-selects are **bit-banged** GPIO (26/12/13), not CE0/CE1
(§5). The 74HC595 clock/data are bit-banged on 21/20/16. Keep GPIO18 a short hop
and add **no pull / no low-impedance load** on it (§7 — see cross-board notes).

### Decoupling & bulk capacitors

Board 2 has four bare ICs (U1–U4), so each needs its own decoupling — more than
board 3's two. Add these by hand in KiCad (net-label style: place the symbol, label
each pin, no wires). The ADS1015 (M1) is a module with onboard decoupling — no cap.

**The cap bill:**

| Ref | Symbol | Value | Pin labels | Place near (in PCB) |
|-----|--------|-------|-----------|---------------------|
| C1 | `Device:C` | 100nF | `+3V3` / `GND` | U1 74HC595 |
| C2 | `Device:C` | 100nF | `+3V3` / `GND` | U2 MCP3008 |
| C3 | `Device:C` | 100nF | `+3V3` / `GND` | U3 MCP4922 |
| C4 | `Device:C` | 100nF | `+3V3` / `GND` | U4 MCP42010 |
| C5 | `Device:C` | 100nF | `+3V3` / `GND` | U2 MCP3008 VREF (clean ADC ref) |
| C6 | `Device:C` (ceramic) | 10µF | `+3V3` / `GND` | J1 power entry (bulk) |
| C7 *(opt)* | `Device:CP` | 470µF | `+5V` / `GND` | **J7** servo reservoir (mind polarity) |
| C8/C9 *(opt)* | `Device:C` | 100nF | `+3V3` / `GND` | U3 VREFA / VREFB |

**Why they're all `+3V3/GND`:** every chip VDD/VREF sits on the +3V3 net, so in a
net-label schematic the decoupling caps are identical (`+3V3 → GND`); only C7 is
`+5V → GND`. The per-chip association exists only in *layout* — place each cap next
to its IC's power pin (last column). Use the plain **Label tool (`L`)** with the
exact strings above (case-sensitive) so they join the existing rails.

**C7:** one cap, at **J7** (the load), not J2 — it's a local reservoir for the
servo's current spikes / back-EMF, so it belongs at the servo connector.

**Footprint sizes** (measure your part; only **diameter** + **lead pitch** matter):

| Value | Type | Ø / body | height | lead pitch | KiCad footprint (`Capacitor_THT:`) |
|-------|------|----------|--------|-----------|-------------------------------------|
| 470µF | electrolytic 16V (pop-can) | 8mm | ~12mm | 3.5mm | `CP_Radial_D8.0mm_P3.50mm` |
| 470µF | electrolytic 25V | 10mm | ~12.5mm | 5mm | `CP_Radial_D10.0mm_P5.00mm` |
| 10µF | electrolytic 16–25V (pop-can) | 5mm | ~11mm | 2.0mm | `CP_Radial_D5.0mm_P2.00mm` |
| 10µF | ceramic (non-polar, preferred for C6) | ~5mm | — | 2.5 / 5.08mm | `C_Disc_D5.0mm_W2.5mm_P2.50mm` |
| 100nF | ceramic | ~5mm | — | 2.5 / 5.08mm | `C_Disc_…_P2.50mm` |

Electrolytics are polarized: **stripe / short lead → `GND`**, long lead → positive rail.

**Workflow:** assigning stock `Capacitor_THT` footprints (as on board 3) makes board 2
diverge from the scaffold, so `check-kicad` / `t/04` will flag it — at that point
board 2 is added to `%FROZEN` in `t/04`, exactly like board 3.

---

## Board 3 — I2C expanders + stepper *(DONE — reference only)*

| Device | Addr / pins | Loop-back |
|--------|-------------|-----------|
| MCP23017 #1 | I2C 0x20 | GPA4–7 ↔ GPB4–7 (t/330) |
| MCP23017 #2 | I2C 0x21 | GPA0–3 → ULN2003 → 28BYJ-48 coils (t/450) |
| Stepper limits | (off-board magnets) | CW→GPIO17, CCW→GPIO27 |
| Centre LED | (on board 3) | GPIO19 |

**Existing connectors:** J1 power (+5V/+3V3/GND), J2 signal (SDA, SCL, GPIO17,
GPIO27, GPIO19) from board 1; J3–J8 out to the stepper/magnets/IO breakouts.
Carries its own **4.7k I2C pull-ups** (R4/R5) — see cross-board notes.

---

## Board 4 — I2C sensors (the easy one)

Pure 3V3, bus only, no GPIO. The four sensor breakouts just drop on SDA/SCL.

| Device | Addr | Rail | Test(s) |
|--------|------|------|---------|
| DS3231 RTC | 0x68 | 3V3 | t/320 |
| AT24C32 EEPROM | 0x57 | 3V3 | t/420–422 |
| BMP180 temp/pressure | 0x77 | 3V3 | t/340 |
| OLED SSD1306 128×64 | 0x3c | 3V3 | t/500–520 |

*RTC + EEPROM are typically the same physical ZS-042 breakout (two addresses).*

> **⚠️ OPEN (raised 2026-06-21) — verify before finalizing board 4:** the model
> (`board-4-model.py` M1) assumes a **ZS-042** (DS3231 + on-board AT24C32). Confirm
> the part you actually have. If it's a **bare DS3231** (no EEPROM), `t/420-422`
> need a **separate AT24C32** added to the model (0x57 on the bus) + a re-scaffold.
> Board 4 is scaffold-only with no hand-work yet, so changing it is cheap.

### Connectors (two JSTs, mirroring board 3's J1/J2 convention)

| Ref | Role | Pins | Pinout |
|-----|------|-----:|--------|
| **J1** | power in ← board 1 | **3** | `1:+3V3  2:GND  3:+3V3 (return → board 1)` |
| **J2** | I2C in ← board 1 | **2** | `1:SDA  2:SCL` |

- **No +5V** on board 4 — every device is 3V3 (unlike board 3's J1, which also
  carries +5V for the stepper).
- **I2C ground reference:** J2 carries only SDA/SCL; the bus ground is the board
  ground delivered on **J1 pin 2**. Both connectors land on board 1, so board 4's
  ground plane ties the I2C return back through J1.

### The +3V3 return pin (J1 pin 3)

> My understanding — confirm: pin 3 is a **second +3V3 that loops back to board 1**
> so board 1 can sense that board 4 is present *and* that 3V3 actually reached the
> far end of the cable (a presence / voltage-sense line, in keeping with the
> "everything loops back" philosophy, §1).

Electrically on **board 4**: J1 pin 1 and J1 pin 3 are **both** tied to the board's
local **+3V3** net (along with every device VCC). There is nothing else to it on
this board.

**Board-1 implication (note for later):** for the return to be meaningful, board 1
must source 3V3 on pin 1 and read pin 3 as a **separate sense node** (GPIO / divider
/ LED / test point) — *not* hard-tie pin 1 and pin 3 to the same node, or the return
is just a redundant parallel wire. Captured here so it isn't lost when board 1 is
designed last.

### Pull-ups

Add **no** I2C pull-ups on board 4 — **board 3 owns the bus pull-ups** (its 4.7k
R4/R5) and the Pi adds ~1.8k (cross-board notes). **Remove/disable the on-board
pull-ups** the RTC/EEPROM/BMP/OLED breakouts ship with, so they don't parallel the
bus down.

---

## Board 5 — 5V logic

HD44780 LCD (20×4, 4-bit) + Arduino (I2C 0x04) behind a 3V3↔5V level-shifter.
The UART loop-back (a 2-pin jumper, GPIO14→GPIO15) rides along here — relocatable
to whichever satellite is convenient.

| Device | Pins (BCM) | Note |
|--------|------------|------|
| HD44780 LCD | RS=5, E=6, D4=4, D5=17, D6=27, D7=22 | 5V power, 3V3 logic in |
| Arduino | I2C 0x04 via level-shifter | 5V board; LV ref = 3V3, HV ref = 5V |
| UART loop-back | TXD14 → RXD15 | jumper only |

**JST in (~13):** `+5V, +3V3, GND, SDA2, SCL3, RS5, E6, D4(4), D5(17), D6(27),
D7(22), GPIO14, GPIO15`.

⚠️ **GPIO17/27 fan out to *both* board 5 (LCD D5/D6) and board 3 (stepper limit
switches)** — one shared net, two destinations (§10-10).

---

## Cross-board nets (watch these)

### GPIO18 — the workhorse net
PWM + servo + edge-interrupt source + ADS1015 A0, all on one wire, now running
board 1 → board 2 over a jumper. **Fine to do**: the interrupt tests (t/200–213)
swing it with the Pi's ~50 kΩ *internal* pull into a ~20 ms window, so even with
cable capacitance the settle time is microseconds. The hard rules (§7): **no
external pull resistor and no low-impedance load** on the net — the high-Z ADS A0
and the servo signal input both satisfy that. Keep board 2 a short hop; don't add
a pull there.

### GPIO17 / 27 / 19 — shared with board 3
- **GPIO17/27**: LCD D5/D6 on **board 5** *and* the stepper CW/CCW limit switches
  on **board 3**. Fan both from board 1 to both boards; don't add a pull/load that
  fights either role.
- **GPIO19**: stepper centre LED on **board 3** only.

### I2C bus + pull-ups
One shared SDA2/SCL3 bus now multi-drops to boards **2, 3, 4, 5**. Pull-ups
already exist in two places:

- Pi built-in: **~1.8 kΩ** on SDA/SCL (every 40-pin model).
- Board 3: **4.7 kΩ** (R4/R5).

Combined = 1.8k ∥ 4.7k ≈ **1.3 kΩ**, which is in spec (3V3 I2C wants ≳ 1 kΩ). So:

- **Add no more pull-ups** on boards 1/2/4/5.
- **Remove/disable the on-board pull-ups** on the breakouts you mount (RTC, BMP,
  OLED, ADS module, level-shifter) — every extra 4.7k–10k parallels the bus down.
- After assembly, run `i2cdetect -y 1` + a soak loop. If SDA/SCL can't reach
  ≤ 0.4 V or addresses flicker, the combined pull is too low — pull resistors off
  breakouts (board 3's are permanent) or drop to 100 kHz
  (`dtparam=i2c_arm_baudrate=100000`). (§10-1)

### Power rails
Board 1 distributes **+5V, +3V3, GND** to every satellite. 3V3 = all I2C/SPI ICs +
74HC595 + ADS. 5V = LCD, servo, Arduino, stepper(+ULN2003 on board 3). The ~1.1 A
5V peak is dominated by the stepper/servo (§11) — keep big inductive loads off the
Pi's 5V if practical (bulk cap or separate feed).

### SPI bus
Originates at board 1 (GPIO9/10/11 + bit-banged CS 26/12/13) and goes to **board 2
only**. The 74HC595 lines (21/20/16) likewise board 1 → board 2 only.

---

## Open decisions (mark up as you go)

- [ ] **Connector style/size** — board 2 (~15) and board 5 (~13) are fat because
      many distinct GPIO fan out to one satellite. Pick connectors, or rethink the
      split if you'd rather shrink them.
- [ ] **UART loop-back home** — defaulted to board 5; could move to board 4 or be a
      standalone jumper.
- [ ] **Servo on board 2 vs board 5** — kept on board 2 so GPIO18 has a single
      destination. Moving it to board 5 would tap GPIO18 on two boards.
- [ ] **Which breakouts have removable pull-ups** — confirm per part; note any that
      can't be de-populated.
- [ ] **Per-board form factor / mounting / JST keying.**

---

## Glossary

- **Test point** — an exposed pad / pin / header position on a net, there so you
  can touch it with a meter/scope probe or attach a jumper. *Not a device*, draws
  no power. Here it means the spare Pi GPIO (23/24/25, 0/1) that the suite toggles
  or reads (t/107 alt-modes, t/108 default state, t/110 registration) but that have
  no peripheral wired to them — bring them out on board 1's breakout so you can
  probe/verify them.
- **Loop-back** — an output wired back into an input so a test can assert "what I
  drove is what I read" (§1).
- **Bit-banged CS** — a chip-select driven as an ordinary GPIO in software, not the
  hardware SPI CE0/CE1 (§5).
