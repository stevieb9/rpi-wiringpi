# RPi::WiringPi — Unit-Test Hardware Pinout

Baseline wiring reference for designing a unit-test PCB.

Sources reconciled: this directory's `README`, every `t/*.t` and `t/multi/*.pl`, `t/RPiTest.pm`
(`rpi_default_pin_config`, `rpi_check_pin_status`), and `lib/RPi/WiringPi.pm` +
`lib/RPi/WiringPi/FAQ.pod`. Where the README was incomplete or ambiguous, the
test code is treated as authoritative.

All pin numbers below are **BCM GPIO** unless they say "physical pin" (40-pin
header position) or "chip pin" (a peripheral IC's own pin).

---

## Table of contents

- [1. Design philosophy: everything loops back](#1-design-philosophy-everything-loops-back)
- [2. Master GPIO map (by BCM)](#2-master-gpio-map-by-bcm)
  - [2.1 Board layout sketch](#21-board-layout-sketch)
- [3. I2C bus (GPIO2 SDA / GPIO3 SCL)](#3-i2c-bus-gpio2-sda--gpio3-scl)
  - [3.1 MCP23017 — pin allocation](#31-mcp23017--pin-allocation-single-expander-3v3)
- [4. SPI bus (GPIO9 MISO / GPIO10 MOSI / GPIO11 SCLK)](#4-spi-bus-gpio9-miso--gpio10-mosi--gpio11-sclk)
- [5. LCD — HD44780 in 4-bit mode](#5-lcd--hd44780-in-4-bit-mode-t925)
- [6. GPIO18 — the heavily multiplexed pin](#6-gpio18--the-heavily-multiplexed-pin-physical-pin-12)
- [7. Shift register & stepper](#7-shift-register--stepper-indirect-drives)
- [8. Pins NOT wired to fixtures](#8-pins-not-wired-to-fixtures-free-for-generic-tests)
- [9. Collisions & shared-net warnings](#9-collisions--shared-net-warnings)
- [10. Power rails — supply connections](#10-power-rails--supply-connections)
  - [10.1 +3V3 bus](#101-3v3-bus)
  - [10.2 +5V bus](#102-5v-bus)
  - [10.3 Current budget (estimate)](#103-current-budget-estimate)
- [11. Pi 5 (RP1) expected default pin states](#11-pi-5-rp1-expected-default-pin-states)
- [12. Quick PCB build checklist](#12-quick-pcb-build-checklist)

---

## 1. Design philosophy: everything loops back

The platform is self-verifying. Every *output* the library can drive is wired
back into an *input* the library can read, so a test can assert that what it
drove is what it measured. **This is the single most important thing to preserve
on the PCB.**

```
   Pi drives  ───────────────►  Pi reads back
   ----------------------------------------------------------
   GPIO18 PWM / servo          ─►  ADS1115 #1 (0x48)  A0
   MCP4XXXX dpot wiper         ─►  ADS1115 #1 (0x48)  A1
   MCP4922 DAC  out 0 (A)      ─►  MCP3008 (CS=GPIO26) CH1
   MCP4922 DAC  out 1 (B)      ─►  MCP3008 (CS=GPIO26) CH3
   74HC595 Q-output(s)         ─►  MCP3008 (CS=GPIO26) CH2
   Stepper (via expander)      ─►  ADS1115 #2 (0x49) A0/A1/A2 = R/C/L (photo resistors)
   MCP23017 Port A (GPA4-7)    ─►  MCP23017 Port B (GPB4-7)   [loopback; A0-3 -> stepper]
   UART TXD (GPIO14)           ─►  UART RXD (GPIO15)          [direct loopback]
```

---

## 2. Master GPIO map (by BCM)

`Phys` = 40-pin header position. `★` = physically wired to a test fixture.
"generic/multi" = the pin is *also* claimed/toggled by the registration test
(`t/110`) and/or the multi-process tests (`t/111-114`, `t/multi/*`) as an
ordinary GPIO — see §9.4.

| BCM | Phys | Wired | Net / role                         | Device                         | Tests |
|----:|-----:|:-----:|------------------------------------|--------------------------------|-------|
|   2 |  3   | ★ | **I2C SDA** (shared bus)              | all I2C devices                | 305,320,330,340,420-422,900-909,920,450 |
|   3 |  5   | ★ | **I2C SCL** (shared bus)              | all I2C devices                | (as above) |
|   4 |  7   | ★ | LCD D4                                | HD44780 LCD                    | 925 |
|   5 | 29   | ★ | LCD RS                                | HD44780 LCD                    | 925 |
|   6 | 31   | ★ | LCD E (strobe)                        | HD44780 LCD                    | 925 |
|   7 | 26   |   | SPI CE1 — *unused* (CS is bit-banged) | —                              | — |
|   8 | 24   |   | SPI CE0 — *unused* (CS is bit-banged) | —                              | — |
|   9 | 21   | ★ | **SPI MISO** (shared bus)             | MCP3008 (read-back only)       | 310,335 |
|  10 | 19   | ★ | **SPI MOSI** (shared bus)             | MCP3008, MCP4922, MCP4XXXX     | 310,335,345 |
|  11 | 23   | ★ | **SPI SCLK** (shared bus)             | MCP3008, MCP4922, MCP4XXXX     | 310,335,345 |
|  12 | 32   | ★ | MCP4922 DAC **CS** (+ generic/multi)  | MCP4922 DAC                    | 310, 110, multi |
|  13 | 33   | ★ | MCP4XXXX dpot **CS**                   | MCP4XXXX digital pot           | 345 |
|  14 |  8   | ★ | UART TXD → GPIO15                     | serial loopback                | 315 |
|  15 | 10   | ★ | UART RXD ← GPIO14                     | serial loopback                | 315 |
|  16 | 36   | ★ | 74HC595 LATCH (ST_CP) (+ multi)       | 74HC595 shift register         | 335, multi |
|  17 | 11   | ★ | LCD D5                                | HD44780 LCD                    | 925 |
|  18 | 12   | ★ | **PWM/servo out + interrupt in + ADS#1 A0** (+ generic/multi) | (see §6) | 105,109,140,200-212,325,110,multi |
|  19 | 35   |   | spare / generic test pin              | —                              | (state checks) |
|  20 | 38   | ★ | 74HC595 CLOCK (SH_CP)                  | 74HC595 shift register         | 335 |
|  21 | 40   | ★ | 74HC595 DATA (DS) (+ multi)           | 74HC595 shift register         | 335, multi |
|  22 | 15   | ★ | LCD D7                                | HD44780 LCD                    | 925 |
|  23 | 16   |   | spare / generic test pin              | —                              | (state checks) |
|  24 | 18   |   | spare / generic test pin              | —                              | (state checks) |
|  25 | 22   |   | spare / generic test pin              | —                              | (state checks) |
|  26 | 37   | ★ | MCP3008 ADC **CS** (+ generic/multi)  | MCP3008 ADC                    | 310,335, 110, multi |
|  27 | 13   | ★ | LCD D6                                | HD44780 LCD                    | 925 |
|   0 | 27   |   | ID_SD — generic test pin *(see §8)*   | (reserved I2C0 ID-EEPROM pin)  | (state checks) |
|   1 | 28   |   | ID_SC — generic test pin *(see §8)*   | (reserved I2C0 ID-EEPROM pin)  | (state checks) |

---

### 2.1 Board layout sketch

Three views: the bare 40-pin header (native Pi functions), then the same header
with each pin's test-platform fixture, then a bus-topology floorplan. Rendered
(colour-coded by supply rail) as **`test-pinout-overview.jpg`** (bus/block view)
and **`test-pinout-detail.jpg`** (pin-by-pin).

For the full electrical schematic — the JPEG/PDF outputs live in this directory,
and every vector **SVG** lives in the **`svg/`** sub-directory:

- **`test-platform-schematic-A3.pdf`** / **`-A4.pdf`** — multi-page vector PDF
  (title/contents page + whole board + one page each for I2C / SPI / stepper /
  display). Best single file to read/print.
- **`svg/sheet-i2c.svg`**, **`svg/sheet-spi.svg`**, **`svg/sheet-stepper.svg`**,
  **`svg/sheet-display.svg`** — per-subsystem sheets (clearest — start here).
  Wire-routed, with each device's supply drawn as proper schematic power symbols
  (**▽ +3V3 / +5V** rail symbols and standard **ground** glyphs).
- **`svg/test-pinout-schematic-signals.svg`** — the whole board on one
  wire-routed sheet (signals + per-device power flags).
- **`svg/test-pinout-schematic-wired.svg`** — fully **wire-routed**, including
  the +3V3/+5V/GND nets (busier/taller). The wire-routed sheets are orthogonally
  routed via netlistsvg/ELK; the SVGs are vector — open and zoom to read.
- **`svg/test-pinout-schematic.svg`** (and the raster **`test-pinout-schematic.jpg`**)
  — the same design in net-label style.
- **`facts/test-platform.net`** — KiCad-importable netlist (24 components, 41
  nets); every connection, datasheet-accurate pinouts.

Regenerate everything above with **`scripts/gen-test-platform.pl`**: it drives
the Python generators (`gen-pinout-images.py`, `gen-schematic.py`, `gen-pdf.py`)
and `netlistsvg`, then files the outputs into this directory and `svg/` — it
never writes to `t/`. The schematic PDFs and the wire-routed SVGs require
`netlistsvg` on `PATH`; without it the script still produces the pinout JPEGs,
the net-label schematic and the netlist, and skips the rest with a warning.

**The bare 40-pin header (J8) — native functions.** Standard Raspberry Pi pinout,
for orientation only (no test wiring). Pin 1 is the square pad; odd pins are the
left column, even pins the right. `(n)` = physical pin number.

```
                   3V3 ( 1) | ( 2) 5V
             GPIO2 SDA ( 3) | ( 4) 5V
             GPIO3 SCL ( 5) | ( 6) GND
                 GPIO4 ( 7) | ( 8) GPIO14 TXD
                   GND ( 9) | (10) GPIO15 RXD
                GPIO17 (11) | (12) GPIO18
                GPIO27 (13) | (14) GND
                GPIO22 (15) | (16) GPIO23
                   3V3 (17) | (18) GPIO24
           GPIO10 MOSI (19) | (20) GND
            GPIO9 MISO (21) | (22) GPIO25
           GPIO11 SCLK (23) | (24) GPIO8 CE0
                   GND (25) | (26) GPIO7 CE1
           GPIO0 ID_SD (27) | (28) GPIO1 ID_SC
                 GPIO5 (29) | (30) GND
                 GPIO6 (31) | (32) GPIO12
                GPIO13 (33) | (34) GND
                GPIO19 (35) | (36) GPIO16
                GPIO26 (37) | (38) GPIO20
                   GND (39) | (40) GPIO21
```

**Every pin mapped — 40-pin header (J8).** Same physical layout, but each pin is
labelled with the **test-platform fixture** it carries. `(n)` = physical pin
number, the number beside it = BCM GPIO (`--` = power/ground).

```
       Function / fixture       BCM  phys   phys  BCM  Function / fixture
       ----------------------------------------------------------------------
                          3V3   --  ( 1)   ( 2)  --   5V
       I2C SDA -> all I2C devs   2  ( 3)   ( 4)  --   5V
       I2C SCL -> all I2C devs   3  ( 5)   ( 6)  --   GND
                       LCD D4    4  ( 7)   ( 8)  14   UART TXD --+ loopback
                          GND   --  ( 9)   (10)  15   UART RXD <-+
                       LCD D5   17  (11)   (12)  18   PWM/servo/INT -> ADS#1 A0
                       LCD D6   27  (13)   (14)  --   GND
                       LCD D7   22  (15)   (16)  23   (spare)
                          3V3   --  (17)   (18)  24   (spare)
        SPI MOSI -> 3 SPI devs  10  (19)   (20)  --   GND
           SPI MISO <- MCP3008   9  (21)   (22)  25   (spare)
        SPI SCLK -> 3 SPI devs  11  (23)   (24)   8   SPI CE0 (unused)
                          GND   --  (25)   (26)   7   SPI CE1 (unused)
            ID_SD (ID EEPROM)    0  (27)   (28)   1   ID_SC (ID EEPROM)
                       LCD RS    5  (29)   (30)  --   GND
                        LCD E    6  (31)   (32)  12   MCP4922 DAC CS
             MCP4XXXX dpot CS   13  (33)   (34)  --   GND
                      (spare)   19  (35)   (36)  16   74HC595 LATCH
               MCP3008 ADC CS   26  (37)   (38)  20   74HC595 CLOCK
                          GND   --  (39)   (40)  21   74HC595 DATA
```

Bit-banged signals: the three SPI **chip-selects (GPIO26/12/13)** are toggled in
software, *not* the hardware CE0/CE1 (GPIO8/7) — those are left free. The
**74HC595** (GPIO21/20/16) is fully bit-banged GPIO. SPI clock/data still ride
the hardware SPI pins (GPIO9/10/11). See §4 and §7.

**Bus topology and loop-backs.** Top-down floorplan; devices cluster by bus off
the Pi header. Each part is tagged with its supply rail — **(3V3)** or **(5V)**.
All Pi logic (GPIO, I2C, SPI, PWM) is 3V3; 5V parts take 3V3 control signals but
need a 5V supply. Dashed arrows are the analog/digital **loop-backs** from §1.

```
   Raspberry Pi 40-pin header — 3V3 logic; 3V3 + 5V + GND rails fan out below
   ===========================================================================

   I2C RAIL (SDA2 / SCL3, one 3V3 pull-up pair)
   ==+========+==========+======+========+========+=======+=========
     |        |          |      |        |        |       |
  [ADS#1]  [ADS#2]  [MCP23017] [RTC]  [EEPROM] [BMP180] [OLED]  [Arduino]
   0x48     0x49     0x20      0x68   0x57     0x77     0x3c     0x04
   (3V3)    (3V3)    (3V3)     (3V3)  (3V3)    (3V3)    (3V3)    (5V *)
     |        |        |
     |        |        +-- GPA0-3 ==> ULN2003 ==> 28BYJ-48 stepper coils  (5V)
     |        |        +-- GPA4-7 <-> GPB4-7        (Port A<->B loopback, t/330)
     |        |        +-- RESET (chip pin 18) -> 3V3
     |        |
     |        +-- A0/A1/A2 <-- 3x photo resistor (R/C/L, stepper position; laser rig)
     |
     +-- A0 <==== GPIO18 (PWM / servo signal, 3V3)
     +-- A1 <==== MCP4XXXX dpot wiper

   SPI RAIL (MOSI10 / SCLK11 / MISO9; hardware SPI, CS bit-banged)
   ==+==============+==============+==============
     |              |              |
  CS26[MCP3008]  CS12[MCP4922]  CS13[MCP4XXXX]      (all 3V3)
     ^  ^  ^         |  |            |
 CH1_|  |  |_________|  |(out0)      |(write-only; wiper -> ADS#1 A1)
 CH3____|  |____________|(out1)
 CH2_______|
     ^
     +==== 74HC595 (3V3) Q-outputs   [DATA21 CLK20 LATCH16 from Pi, bit-banged]

   LCD HD44780 (5V; 3V3 logic in), 4-bit:  RS5  E6  D4=4  D5=17  D6=27  D7=22
   Servo:  5V power, 3V3 PWM signal shared on GPIO18
   UART loopback (3V3):  GPIO14 TXD ----> GPIO15 RXD

   * Arduino Metro Mini is a 5V board; it joins the bus through a 3V3<->5V I2C
     level-shifter (assumed present), so SDA/SCL stay at 3V3 on the Pi side.
```

Legend: **(3V3)/(5V)** = component supply rail · `<==`/`==>` analog loop-back ·
`<->` bidirectional loopback wire · `==>`/`-->` drive/signal · `==` bus rail.

## 3. I2C bus (GPIO2 SDA / GPIO3 SCL)

One shared 2-wire bus; every device distinguished by address. Addresses are the
authoritative list from FAQ.pod "I2C Test Platform Connections":

| Addr | Device                    | Pwr  | Tests        | Notes |
|------|---------------------------|------|--------------|-------|
| 0x04 | Arduino Metro Mini        | 5V † | 300‡, 305    | I2C slave sketch in `docs/sketch` |
| 0x05 | ATMega-328P (standalone)  | 5V † | —            | only when in I2C mode (optional) |
| 0x20 | MCP23017 GPIO expander    | 3V3  | 330, 450     | one chip: GPA4-7↔GPB4-7 loopback; GPA0-3 → stepper |
| 0x3c | OLED SSD1306 128×64       | 3V3  | 900-909, 920 | on the Pi I2C bus |
| 0x48 | ADS1115 ADC #1            | 3V3  | 109,140,325,345 | A0=PWM/servo, A1=dpot wiper |
| 0x49 | ADS1115 ADC #2            | 3V3  | 450          | A0/A1/A2 = stepper photo resistors R/C/L |
| 0x57 | AT24C32 EEPROM            | 3V3  | 420-422      | same breakout board as the RTC |
| 0x68 | DS3231 RTC                | 3V3  | 320          | |
| 0x77 | BMP180 pressure/temp      | 3V3  | 340          | 3V3 only — not 5V tolerant |

† The 5V Arduino/ATMega join the bus through a 3V3↔5V I2C level-shifter (assumed
present in this design), keeping the Pi's SDA/SCL at 3V3.

‡ `t/300` is the I2C *exception* test — it probes a deliberately-absent address
(0x99) to verify error handling, so it does not actually communicate with the
Arduino at 0x04. Listed here only because it lives in the I2C test group.

```
            +3V3 ── pull-ups ──┐         ┌──────────┬──────────┬─────── ... (all I2C devices)
 GPIO2 (SDA) ──────────────────┴── SDA ──┤          │          │
 GPIO3 (SCL) ───────────────────── SCL ──┤  0x20    │ 0x48/49  │ 0x68 0x77 0x57 0x3c 0x04
                                          MCP23017   ADS1115     RTC  BMP  EEPROM OLED Arduino
```

**Two** ADS1115 ADCs are present — 0x48 (PWM/servo + dpot feedback) and 0x49
(stepper sense, on the 2nd-case stepper rig). Two are required: the suite drives
five analog inputs (PWM/servo, dpot wiper, three stepper sensors), more than one
4-channel chip can carry, and a PWM-output line can't share an ADC pin with a
sensor.

There is only one MCP23017, strapped to **0x20**. Both `t/330` (expander GPIO
test) and `t/450` (stepper) address it there.

### 3.1 MCP23017 — pin allocation (single expander, 3V3)

Bank A is split between two jobs by design; Bank B mirrors only the loopback
half. There is no full Port-A→Port-B loopback — this split *is* the wiring:

```
  GPA0..GPA3  ─► ULN2003 IN1..IN4 ─► 28BYJ-48 stepper coils   (t/450; 5V motor)
  GPA4..GPA7 <-> GPB4..GPB7                                   (t/330 loopback pairs)
  GPB0..GPB3  — unused
  3V3         ─► chip pin 18 (RESET, active-low: tie HIGH)    ← NOT a Pi GPIO
```

GPA0-3 drive the stepper; GPA4-7 ↔ GPB4-7 are the four loopback pairs the
expander GPIO test exercises (`t/330` writes A4-7, reads them back on B4-7 — the
test was scoped to these non-stepper pins).

---

## 4. SPI bus (GPIO9 MISO / GPIO10 MOSI / GPIO11 SCLK)

Clock and data ride the **hardware SPI** pins (GPIO9/10/11; needs
`dtparam=spi=on`). Each device's **chip-select is bit-banged** on an ordinary
GPIO (26/12/13) — the modules toggle it in software (`digitalWrite`) so the
hardware CE0/CE1 (GPIO8/7) stay free and unused. MCP3008 with a CS pin > 1 runs
in its "bit-bang CS" mode; the DAC/dpot software-toggle their CS around each
hardware transfer. Three devices share MOSI+SCLK; only the MCP3008 uses MISO
(the DAC and dpot are write-only). All three SPI devices are **3V3**-powered (so
the DAC/dpot/ADC analog range matches the Pi's 3V3 PWM/GPIO levels).

| Device      | CS (BCM, bit-banged) | MOSI | SCLK | MISO | Tests | Output goes to |
|-------------|---------------------:|------|------|------|-------|----------------|
| MCP3008 ADC | **26**   | 10   | 11   | 9    | 310,335 | (it's the reader) |
| MCP4922 DAC | **12**   | 10   | 11   | —    | 310     | out0→MCP3008 CH1, out1→MCP3008 CH3 |
| MCP4XXXX pot| **13**   | 10   | 11   | —    | 345     | wiper→ADS1115#1 A1 |

```
 GPIO10 MOSI ─┬──────────┬───────────┐
 GPIO11 SCLK ─┼────┬─────┼─────┬─────┤
 GPIO9  MISO ─┘    │     │     │     │
                   │     │     │     │
   CS GPIO26 ──► MCP3008 │     │   (DIN/CLK)
   CS GPIO12 ──────────► MCP4922      │
   CS GPIO13 ──────────────────────► MCP4XXXX
```

---

## 5. LCD — HD44780 in 4-bit mode (`t/925`)

Six dedicated GPIOs. `rpi_check_pin_status()` deliberately **skips pins
4,5,6,17,22,27** "because of LCD", so these are reserved for the display and
not exercised as generic pins.

| Pi BCM | LCD pin | Library arg |
|-------:|---------|-------------|
| 5      | RS      | `rs`  |
| 6      | E       | `strb`|
| 4      | D4      | `d0`  |
| 17     | D5      | `d1`  |
| 27     | D6      | `d2`  |
| 22     | D7      | `d3`  |

(4-bit mode: LCD D0–D3 unused; library `d4..d7` set to 0.)

---

## 6. GPIO18 — the heavily multiplexed pin (physical pin 12)

GPIO18 is one physical net wired to **ADS1115 #1 channel A0**, and is reused by
many tests in different modes:

| Mode                  | Tests        | Direction | How |
|-----------------------|--------------|-----------|-----|
| Hardware PWM out      | 109, 140     | OUT       | sweeps duty; ADS A0 reads voltage |
| Servo PWM out         | 325          | OUT       | servo pulse; ADS A0 reads position |
| Edge interrupt source | 200-212      | IN        | **self-triggered** by toggling the *internal* pull resistor (`pull(PUD_UP)`→`pull(PUD_DOWN)`) — no external edge driver |
| Plain pin / register  | 105, 110, multi | IN/OUT | read/write + metadata registration |

**PCB constraint:** because the interrupt tests rely on the Pi's *internal*
pull-up/down to swing the pin, the GPIO18 net must carry **no external pull
resistor and no low-impedance load** — only the ADS1115 A0 input (high-Z) may
hang off it. A series resistor to A0 is fine; a pull resistor would break the
interrupt tests.

---

## 7. Shift register & stepper (indirect drives)

**74HC595 (`t/335`)** — serial-in/parallel-out, **fully bit-banged GPIO** (the
library toggles DATA/CLOCK/LATCH directly); outputs read back via MCP3008:

| Pi BCM | 74HC595 | Library arg (`shift_register(400,8,21,20,16)`) |
|-------:|---------|------------------------------------------------|
| 21     | DS (14)   | data  |
| 20     | SH_CP (11)| clock |
| 16     | ST_CP (12)| latch |

Q-outputs feed MCP3008 (e.g. first output → MCP3008 CH2). Library pin-base
400-407 are *virtual* (not Pi GPIO).

**Stepper (`t/450`)** — uses **no direct Pi GPIO**. Coils are driven through a
ULN2003 by the (single) MCP23017's Bank A pins 0-3 (see §3 — GPA0-3 are the
stepper drive; GPA4-7 ↔ GPB4-7 are the expander loopback pairs). Position is
sensed by three photo resistors into ADS1115 #2 (0x49) — R/C/L = channels 0/1/2.

---

## 8. Pins NOT wired to fixtures (free for generic tests)

These are exercised only for default mode/state, registration counting and
interrupt-count baselines — they have no peripheral attached and are candidates
for break-out test points on the PCB:

- **GPIO19, 23, 24, 25** — fully spare.
- **GPIO7 (CE1), GPIO8 (CE0)** — at SPI-alt default; unused because CS is
  bit-banged on 26/12/13. Spare unless you switch to hardware CE.
- **GPIO0 / GPIO1** (physical 27/28, ID_SD/ID_SC) — used as generic test pins,
  **but** these are the reserved I2C0 ID-EEPROM pins (board-identification
  EEPROM on add-on boards). Best left unrouted to test fixtures.

---

## 9. Collisions & shared-net warnings

> Software-wise nothing conflicts — tests run sequentially and each cleans up.
> The items below are the **physical-net decisions** the PCB must make.

1. **Shared I2C bus (GPIO2/3)** — 8+ devices, intended. The Pi already provides
   ~1.8 kΩ pull-ups on SDA/SCL to 3V3 (every 40-pin model, Pi 3 through Pi 5/RP1),
   so **add no external pull-up pair**. The Pi's 1.8 kΩ dominates; typical breakout
   pull-ups (4.7–10 kΩ) only nudge the combined value down and on a busy bus help
   drive the extra capacitance — which is why a fully-populated bus generally just
   works. Watch the opposite case: if several breakouts carry *aggressive* low-value
   pulls (2.2 kΩ) the combined resistance can drop too low to pull SDA/SCL cleanly
   below 0.4 V — symptoms are missing/flickering addresses in `i2cdetect`, NAKs, or
   intermittent reads. To verify after assembly: measure SDA→3V3 / SCL→3V3 (≥0.6 kΩ
   is fine), run `i2cdetect -y 1` plus a soak loop, and if flaky drop to 100 kHz
   (`dtparam=i2c_arm_baudrate=100000`) for margin. Note a BSS138-type level-shifter
   for the 5V Arduino adds its own ~10 kΩ pulls on the Pi side. Two ADS1115
   (0x48/0x49) need their address-select pins strapped to the distinct addresses.
   There is only **one** MCP23017, strapped to **0x20** (both `t/330` and `t/450`
   use it there).

2. **Shared SPI bus (GPIO9/10/11)** — three devices, intended. Only one CS
   (26/12/13) may be active at a time; the library guarantees this, but ensure
   clean CS routing and that the write-only DAC/dpot don't drive MISO.

3. **GPIO18 over-subscribed** (PWM + servo + interrupt + generic + ADS A0 net).
   One wire, many roles. Honour the "no external pull / no load" constraint in
   §6.

4. **Device-control pins doubling as generic GPIO pins:** `t/110` and the
   multi-process tests register and toggle **GPIO12, 16, 18, 21, 26** as plain
   pins. On the board these are live device lines (DAC CS, SR LATCH, PWM/ADS,
   SR DATA, MCP3008 CS). Toggling them while that device is idle is harmless,
   but be aware the "generic pin" tests are physically wiggling real control
   lines. If you ever add bus buffers/latches, keep these directly Pi-driven.

5. **CS lines excluded from state checks:** `rpi_default_pin_config` marks
   **GPIO12 and GPIO26** as removed "due to inherent flipping" — they idle/toggle
   as chip-selects and can't be verified at a fixed default. Expected; no action
   needed, just don't add pull resistors that would fight the idle level.

6. **Serial vs Bluetooth:** the UART loopback (GPIO14→15) needs the primary
   UART on the header. On the **Pi 5 (RP1)** the header UART is `/dev/ttyAMA0`
   and is enabled with `enable_uart=1` alone — Bluetooth has its own dedicated
   UART, so no `disable-bt` overlay is required (that overlay is a Pi 3/4 step,
   where the header would otherwise sit on the mini-UART `/dev/ttyS0`). With the
   UART enabled, GPIO14/15 report funcsel `3` and idle high.

7. **Mixed power rails (3V3 / 5V):** all Pi logic and every I2C/SPI sensor IC
   plus the 74HC595 run at **3V3**. The **5V** parts are the HD44780 LCD, the
   28BYJ-48 stepper (via ULN2003), the servo, and the Arduino/ATMega. 5V parts
   accept the Pi's 3V3 control signals; the 5V Arduino's I2C reaches the bus
   through a **3V3↔5V level-shifter** (assumed present), so the Pi-side SDA/SCL
   stay at 3V3. Provide both a 3V3 and a 5V rail. *(Rail assignments are
   best-effort from standard module voltages — confirm against your actual parts.)*
   Full per-rail device lists are in §10.

---

## 10. Power rails — supply connections

> The Pi feeds two rails from the 40-pin header: **+3V3** (header pins 1, 17) and
> **+5V** (header pins 2, 4), with a common **GND** (pins 6, 9, 14, 20, 25, 30,
> 34, 39). All Pi logic is 3V3; the 5V parts accept the Pi's 3V3 control signals
> but need a 5V supply on their power pin. The 5V Arduino/ATMega reach the I2C bus
> through a 3V3↔5V level-shifter so SDA/SCL stay at 3V3 on the Pi side (see §9.7).
> Rail assignments follow standard module voltages — confirm against your parts.

### 10.1 +3V3 bus

All I2C and SPI ICs plus the 74HC595 run at 3V3 (so the DAC/dpot/ADC analog range
matches the Pi's 3V3 PWM/GPIO levels):

| Device                | Ref / addr   | Power pin     | Notes                              |
|-----------------------|--------------|---------------|------------------------------------|
| ADS1115 ADC #1        | I2C 0x48     | VDD           | A0=PWM/servo, A1=dpot wiper        |
| ADS1115 ADC #2        | I2C 0x49     | VDD           | A0/A1/A2 = stepper photo resistors |
| MCP23017 GPIO expander| I2C 0x20     | VDD           | RESET (chip pin 18) also tied 3V3  |
| DS3231 RTC            | I2C 0x68     | VCC           | RTC/EEPROM breakout                |
| AT24C32 EEPROM        | I2C 0x57     | VCC           | same breakout board as the RTC     |
| BMP180 pressure/temp  | I2C 0x77     | VIN           | 3V3 only — **not** 5V tolerant     |
| OLED SSD1306 128×64   | I2C 0x3c     | VCC           |                                    |
| MCP3008 ADC           | SPI CS26     | VDD + VREF    | the SPI read-back reader           |
| MCP4922 DAC           | SPI CS12     | VDD + VREFA/B | out0→MCP3008 CH1, out1→CH3         |
| MCP4XXXX digital pot  | SPI CS13     | VDD           | wiper → ADS#1 A1                    |
| 74HC595 shift register| bit-banged   | VCC           | 3V3 logic; Q-outputs → MCP3008 CH2 |

Other 3V3 connections (not a device power pin):

- **I2C pull-ups** — the Pi already supplies ~1.8 kΩ pull-ups on SDA/SCL (GPIO2/3)
  to 3V3 on every 40-pin model (Pi 3 through Pi 5/RP1), so **no external pull-up
  pair is needed**. The risk is the opposite — breakout on-board pull-ups parallel
  against the Pi's 1.8 kΩ; verify the combined value isn't too low and run at
  100 kHz for margin if needed (see §9.1).
- **MCP23017 RESET** (chip pin 18) — tie HIGH to 3V3 (active-low reset).
- **MCP4XXXX dpot end-terminal** — high terminal to 3V3, other to GND (reference).
- **Level-shifter LV side** — low-voltage reference = 3V3.

### 10.2 +5V bus

The 5V parts take 3V3 control/logic signals but are powered from 5V:

| Device                  | Ref / role        | Power pin       | Notes                              |
|-------------------------|-------------------|-----------------|------------------------------------|
| HD44780 LCD             | display (`t/925`) | VDD + backlight | logic inputs (RS/E/D4-7) are 3V3   |
| 28BYJ-48 stepper        | via ULN2003       | motor V+        | coils, `t/450`                     |
| ULN2003 driver          | stepper driver    | COM / VCC       | driven by MCP23017 GPA0-3          |
| Servo                   | on GPIO18 PWM     | V+              | signal 3V3, power 5V               |
| Arduino Metro Mini      | I2C 0x04          | VIN / 5V        | joins bus via level-shifter        |
| ATMega-328P (standalone)| I2C 0x05          | VCC             | optional; only in I2C mode         |

Other 5V connections:

- **Level-shifter HV side** — high-voltage reference = 5V.

### 10.3 Current budget (estimate)

> Datasheet-typical figures, **not measured** — confirm against your parts before
> sizing traces/connectors. The suite runs tests **sequentially** (§9), so the
> stepper (`t/450`) and servo (`t/325`) never draw at the same instant; the
> "naive all-on" column is therefore conservative and is the number to size a
> supply against, while real per-test peaks are lower. Servo figures are for the
> **Tower Pro SG90** micro servo.

**+3V3 bus** — all I2C/SPI ICs + the 74HC595:

| Device | Ref | Typ (mA) | Peak (mA) | Note |
|--------|-----|---------:|----------:|------|
| ADS1115 #1 | 0x48 | 0.15 | 0.20 | continuous-conversion |
| ADS1115 #2 | 0x49 | 0.15 | 0.20 | |
| MCP23017 | 0x20 | 1.0 | 1.0 | logic only; loopback drive is high-Z |
| DS3231 RTC | 0x68 | 0.2 | 0.2 | **+~3 mA if breakout power-LED fitted** |
| AT24C32 EEPROM | 0x57 | 0.5 | 3.0 | peak during page write |
| BMP180 | 0x77 | 0.01 | 0.65 | µA between samples |
| OLED SSD1306 | 0x3c | 15 | 30 | **dominant 3V3 load**; scales with lit pixels |
| MCP3008 | CS26 | 0.5 | 0.55 | |
| MCP4922 DAC | CS12 | 0.7 | 0.9 | |
| MCP4XXXX dpot | CS13 | 0.5 | 1.0 | +~0.33 mA ladder (10 kΩ, 3V3→GND) |
| 74HC595 | bit-bang | 0.5 | 2.0 | dynamic/switching |
| I2C pull-ups (Pi 1.8 kΩ ×2) | — | ~0 | ~4 | momentary, only while a line is held low |
| dpot ladder + 3× photo dividers | — | ~1 | ~1.5 | into ADS high-Z |
| **+3V3 subtotal** | | **~20** | **~45** | OLED is ~75%; +~3 mA w/ RTC LED |

**+5V bus** — LCD, stepper, servo, Arduino:

| Device | Ref | Typ (mA) | Peak/stall (mA) | Note |
|--------|-----|---------:|----------------:|------|
| HD44780 logic | t/925 | 1.5 | 2 | |
| HD44780 backlight | t/925 | 25 | 120 | depends on series R / jumper |
| 28BYJ-48 stepper (via ULN2003) | t/450 | 160 | 240 | 2-phase → all-coil energized |
| ULN2003 | — | 0.5 | 1 | own draw; motor current counted above |
| Servo SG90 | t/325 | 10 idle / 250 run | 700 | stall is the big spike |
| Arduino Metro Mini | 0x04 | 25 | 40 | regulator + power LED |
| ATMega-328P standalone | 0x05 | 12 | 20 | **optional** — often absent |
| **+5V naive all-on** | | | **~1120** | sizing figure (see note) |

Realistic per-test 5V peaks (sequential): **servo test ≈ 770 mA** (SG90 stall +
backlight + Arduino + idle rest), **stepper test ≈ 300 mA**, everything else far
lower.

**Totals (both rails off the Pi header):**

| Rail | Typical (active) | Peak (sizing) |
|------|-----------------:|--------------:|
| +3V3 | ~20 mA | ~45–48 mA |
| +5V | ~0.3–0.8 A | ~1.12 A |
| **Overall** | **~0.35–0.85 A** | **~1.15 A** |

**Supply notes:**

- The Pi's on-board 3V3 regulator covers the ~45 mA on that rail with huge margin.
- The ~1.1 A 5V peak rides the Pi's main input rail (header pins 2/4), *on top of*
  the Pi's own draw. Fine with the official Pi 5 (5 A/27 W) supply, but the
  inductive **stepper + servo spikes should ideally have their own 5V feed** (or at
  minimum a bulk cap, ~470–1000 µF, near the ULN2003 and servo) rather than riding
  the Pi's 5V — and mind header-pin/connector current limits.

---

## 11. Pi 5 (RP1) expected default pin states

From `rpi_default_pin_config()` — the at-rest mode/state every wired pin must
return to after a test run (used to detect a dirty board). Alt `31` = RP1
"null / no peripheral function"; alt `0` = GPIO input. With the SPI, I2C and
UART buses enabled, the dedicated bus pins report their peripheral funcsel
rather than GPIO: **GPIO2/3 (I2C) = `7`**, **GPIO9/10/11 (SPI) = `4`**, and
**GPIO14/15 (UART) = `3`** (UART idles high). GPIO12 and GPIO26 are *excluded*
(shown below): as chip-selects they idle/flip and have no stable default to
check against.

| BCM | alt | state | | BCM | alt | state | | BCM | alt | state |
|----:|----:|------:|-|----:|----:|------:|-|----:|----:|------:|
| 0  | 0  | 1 | | 11 | 4  | 0 | | 22 | 1  | 0 |
| 1  | 0  | 1 | | 13 | 31 | 0 | | 23 | 1  | 0 |
| 2  | 7  | 1 | | 14 | 3  | 1 | | 24 | 31 | 0 |
| 3  | 7  | 1 | | 15 | 3  | 1 | | 25 | 31 | 0 |
| 4  | 31 | 0 | | 16 | 31 | 0 | | 27 | 1  | 0 |
| 5  | 31 | 0 | | 17 | 1  | 0 | |    |    |   |
| 6  | 31 | 0 | | 18 | 0  | 0 | | **12** | excluded (CS flip) |
| 7  | 1  | 1 | | 19 | 31 | 0 | | **26** | excluded (CS flip) |
| 8  | 1  | 1 | | 20 | 31 | 0 | |        |    |   |
| 9  | 4  | 0 | | 21 | 31 | 0 | |        |    |   |
| 10 | 4  | 0 | |    |    |   | |        |    |   |

> On Pi 5, wiringPi cannot *set* alt 31, so once a sweep touches an alt-31-default
> pin it can't be auto-restored mid-run — reset such pins with `pinctrl` between
> full runs. (See the project test notes.)

---

## 12. Quick PCB build checklist

- [ ] 40-pin header pass-through; route only the BCM pins in §2.
- [ ] **No** external I2C pull-up pair — the Pi's built-in ~1.8 kΩ on SDA/SCL is
      enough; just check the breakouts' on-board pulls don't parallel too low (§9.1).
      Address straps for the two ADS1115 (0x48/0x49) and the single MCP23017 (0x20).
- [ ] SPI fan-out (9/10/11) to MCP3008 + MCP4922 + MCP4XXXX with **bit-banged
      CS** 26/12/13 (hardware CE0/CE1 left free).
- [ ] DAC out0/out1 → MCP3008 CH1/CH3; 74HC595 (bit-banged) Q → MCP3008 CH2.
- [ ] dpot wiper → ADS#1 A1; dpot end-terminals to 3V3 / GND reference.
- [ ] GPIO18 → ADS#1 A0 only (series R ok; **no pull, no load**).
- [ ] MCP23017 (one chip, 3V3): GPA4-7 ↔ GPB4-7 loopback; RESET (chip pin 18) → 3V3.
- [ ] MCP23017 GPA0-3 → ULN2003 → 28BYJ-48 stepper (5V); 3 photo resistors
      → ADS#2 A0-2.
- [ ] LCD: 4=D4,5=RS,6=E,17=D5,27=D6,22=D7.
- [ ] UART: GPIO14 → GPIO15 (with the primary UART freed from Bluetooth).
- [ ] Leave GPIO0/1 (ID_SD/ID_SC) unrouted — reserved I2C0 ID-EEPROM pins.
- [ ] Provide **3V3 and 5V** rails + common ground. 3V3: all I2C/SPI ICs +
      74HC595. 5V: LCD, stepper(+ULN2003), servo, Arduino. (Verify rails.)
- [ ] 3V3↔5V I2C level-shifter between the Pi's SDA/SCL and the 5V Arduino/ATMega.
