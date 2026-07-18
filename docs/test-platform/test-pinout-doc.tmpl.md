# RPi::WiringPi — Unit-Test Hardware Pinout (re-derived from the test suite)

Baseline wiring reference for the unit-test PCB, **re-derived from scratch** by
reading the test suite as the source of truth.

**Method.** Every wiring fact below was extracted from `t/` — the `t/*.t`
scripts, the `t/multi/*.pl` master/slave scripts, the `t/RPiTest.pm` harness
(`rpi_default_pin_config`, `rpi_check_pin_status`), and `t/crontab/` — and from
the device-driver submodules under `~/repos` (e.g. `rpi-adc-ads`,
`rpi-gpioexpander-mcp23017`) used to decode each constructor's arguments into
concrete pins/addresses. Where the tests are silent (passive component values,
supply rails, the I2C level-shifter, physical module identities), the gap is
filled from `README.md` / `lib/RPi/WiringPi/FAQ.pod` / `lib/` and **flagged**.

Each fact is tagged:

- **[T]** = proven by a test (file:line cited).
- **[L]** = inferred from library/submodule source (a default the test relies on
  but does not set explicitly).
- **[F]** = gap-filled from non-test docs/hardware knowledge; **not** determinable
  from the tests alone.

All pin numbers are **BCM GPIO** unless they say "physical pin" (40-pin header
position) or "chip pin" (a peripheral IC's own pin). The suite forces the BCM
numbering scheme (`pin_scheme()` ⇒ GPIO; `t/106`), and `last_interrupt()` reports
`pin_bcm` (`t/204:56`).

**Scope — fabbed boards vs bench devices.** This reference covers two populations
of hardware. (1) The **fabbed test-platform boards 1–5** (the PCB this doc was
built for): boards 2/3/4/5 carry the SPI-analog, expander/stepper, I2C-sensor and
5V-logic fixtures; board 1 (host) additionally carries the I2C LCD (`t/335`) and
the planned PCA9685 (`t/440`). (2) A newer wave of **bench-wired** robot/display
devices that are **not on any fabbed board** — the ST7735S TFT (`t/447`), RCWL-0516
radar (`t/361`), MPU-6050 gyro (`t/358`), ADXL335 accelerometer (`t/360`) and A4988
stepper (`t/353`) — jumper-wired straight to the header and gated by their own env
vars. Where a pin/role is bench-only it is tagged **(bench)**; on the fabbed boards
those pins are still free. See the board matrix (`test-board-matrix.md`) for the
device↔board mapping.

---

## Table of contents

- [1. Design philosophy: everything loops back](#1-design-philosophy-everything-loops-back-t)
- [2. Master GPIO map (by BCM)](#2-master-gpio-map-by-bcm)
  - [2.1 Bare 40-pin header (J8)](#21-bare-40-pin-header-j8--native-functions-orientation-only)
  - [2.2 Every pin mapped to its fixture](#22-every-pin-mapped-to-its-test-platform-fixture)
  - [2.3 Bus topology and loop-backs](#23-bus-topology-and-loop-backs)
  - [2.4 Generated artifacts & regeneration](#24-generated-artifacts--regeneration)
- [3. Devices & pinouts per test file](#3-devices--pinouts-per-test-file-t)
- [4. I2C bus (GPIO2 SDA / GPIO3 SCL)](#4-i2c-bus-gpio2-sda--gpio3-scl)
  - [4.1 MCP23017 expanders — pin allocation](#41-mcp23017-expanders--pin-allocation-t)
- [5. SPI bus (GPIO9 MISO / GPIO10 MOSI / GPIO11 SCLK)](#5-spi-bus-gpio9-miso--gpio10-mosi--gpio11-sclk)
- [6. LCD — HD44780, 4-bit mode](#6-lcd--hd44780-4-bit-mode-t525-t)
- [7. GPIO18 — the multiplexed workhorse pin](#7-gpio18--the-multiplexed-workhorse-pin-physical-pin-12)
- [8. Shift register & stepper](#8-shift-register--stepper-indirect-drives)
- [9. Pins NOT wired to fixtures](#9-pins-not-wired-to-fixtures-t)
- [10. Collisions & shared-net warnings](#10-collisions--shared-net-warnings)
- [11. Power rails — supply connections](#11-power-rails--supply-connections-f)
  - [11.1 +3V3 bus](#111-3v3-bus)
  - [11.2 +5V bus](#112-5v-bus)
  - [11.3 Current budget (estimate)](#113-current-budget-estimate)
- [12. Expected default pin states](#12-expected-default-pin-states-from-trpitestpm-t)
- [13. Environment gating](#13-environment-gating-how-to-actually-run-the-suite-t)
- [14. Quick PCB build checklist](#14-quick-pcb-build-checklist-test-grounded)

---

## 1. Design philosophy: everything loops back **[T]**

The platform is self-verifying: every *output* the library can drive is wired
back into an *input* it can read, so a test asserts that what it drove is what it
measured. This is the load-bearing property of the board — it is visible directly
in the tests, which write a value and then read it back to compare.

```
   Pi / device drives  ───────────────►  read back by            Proven in
   --------------------------------------------------------------------------
   GPIO18 PWM / servo            ─►  ADS1015 #1 (0x48) A0         t/405, t/425
   MCP4XXXX dpot PW0 wiper       ─►  ADS1015 #1 (0x48) A1         t/445
   MCP4XXXX dpot PW1 wiper       ─►  ADS1015 #1 (0x48) A2         t/445
   MCP4922 DAC out A (set 0,..)  ─►  MCP3008 (CS=GPIO26) CH1      t/410
   MCP4922 DAC out B (set 1,..)  ─►  MCP3008 (CS=GPIO26) CH3      t/410
   74HC595 first Q (vpin 401)    ─►  MCP3008 (CS=GPIO26) CH2      t/435
   MCP23017 #1 (0x20) GPA(n)   <─► MCP23017 #1 GPB(7-n) (straight-across loopback) t/355
   MCP23017 #2 (0x21) GPA0-3 ► ULN2003 ► 28BYJ-48 stepper (drive) t/350
   28BYJ-48 sweep ─► CW switch (GPIO17) / CCW switch (GPIO27)     t/350
   UART TXD (GPIO14)             ─►  UART RXD (GPIO15)            t/610
```

Loop-back evidence (representative):
- `t/405:56,57,75-82` writes PWM on GPIO18, reads `$adc_in=0` on ADS @ `0x48`.
- `t/445:38-39,68-69` sweeps **two** dpots, reads PW0 on channel `1` (`ADC_PW0=>1`)
  and PW1 on channel `2` (`ADC_PW1=>2`) of the ADS @ `0x48`.
- `t/410:37-38,69-82,88-100` writes DAC A/B, reads MCP3008 CH1/CH3.
- `t/435:51,53-76` writes shift-register output (virtual pin `401`), reads MCP3008 CH2.
- `t/355:671-674` drives MCP23017 `GPA(n)` and reads `GPB(7-n)` (the IC is wired straight across the DIP) for n=0..7.
- `t/350:362-395` steps via expander Bank A (0x21); the CW/CCW magnetic limit switches on GPIO17/27 fire edges captured by `background_interrupt` (`t/350:156,162`). Centre is computed, not sensed.
- `t/610:36-37,40,52` writes a byte/string to the serial port and reads the same back.

---

## 2. Master GPIO map (by BCM)

`Phys` = 40-pin header position. `★` = wired to a test fixture (a peripheral is
attached). "generic" = the pin is claimed/toggled as an ordinary GPIO by the
registration test (`t/110`) and/or the multi-process tests (`t/111-114`,
`t/multi/*`) — see §10. Every role here is **[T]** unless marked otherwise.

`★` = wired to a fabbed-board fixture · `☖` = **bench**-wired only (not on any
fabbed board — see the Scope note) · blank = free / generic.

| BCM | Phys | Wired | Net / role | Proven by |
|----:|-----:|:-----:|------------|-----------|
|  2 |  3 | ★ | **I2C SDA** (shared bus) | t/605,530,355,531,540-542,350,500-520,335,358,360,440,353 |
|  3 |  5 | ★ | **I2C SCL** (shared bus) | (as above) |
|  4 |  7 | ★ | LCD D4 (`d0`) | t/620:50-59 |
|  5 | 29 | ★ | LCD RS (`rs`) | t/620:50-59 |
|  6 | 31 | ★ | LCD E (`strb`) | t/620:50-59 |
|  7 | 26 | ☖ | **bench radar OUT default** (CE1; free on the fabbed boards, interim) | t/361:75; §9,§10 |
|  8 | 24 | ☖ | **TFT ST7735S CS — hardware CE0** (bench) — *was "unused"* | t/447:46,69 [L] channel 0→CE0 |
|  9 | 21 | ★ | **SPI MISO** (shared) — MCP3008 read-back only | t/410,435 [L] pin# |
| 10 | 19 | ★ | **SPI MOSI** (shared) — MCP3008/MCP4922/MCP4XXXX + TFT (bench) | t/410,435,445,447 [L] pin# |
| 11 | 23 | ★ | **SPI SCLK** (shared) — + TFT (bench) | t/410,435,445,447 [L] pin# |
| 12 | 32 | ★ | MCP4922 DAC **CS** (bit-banged) (+ generic) | t/410:35,59-63; t/110, multi |
| 13 | 33 | ★ | MCP4XXXX dpot **CS** (bit-banged) | t/445:34,52 |
| 14 |  8 | ★ | UART TXD → GPIO15 | t/610 |
| 15 | 10 | ★ | UART RXD ← GPIO14 | t/610 |
| 16 | 36 | ★ | 74HC595 LATCH (ST_CP) (+ generic) | t/435:48; multi |
| 17 | 11 | ★ | LCD D5 (`d1`) + stepper **CW limit switch** | t/620:50-59; t/350:148 |
| 18 | 12 | ★ | **PWM/servo out + interrupt source + ADS#1 A0** (+ generic) | t/105,400,405,200-213,425,110,150,multi |
| 19 | 35 | ★ | stepper **centre LED** (computed centre) | t/350:143 |
| 20 | 38 | ★ | 74HC595 CLOCK (SH_CP) | t/435:48 |
| 21 | 40 | ★ | 74HC595 DATA (DS) (+ alt-mode test, generic) | t/435:48; t/107; multi |
| 22 | 15 | ★ | LCD D7 (`d3`) | t/620:50-59 |
| 23 | 16 | ☖ | **TFT BLK / backlight** (bench) — *was "fully spare"* | t/447:47,72 [T] |
| 24 | 18 | ☖ | **TFT RES / reset** (bench) — *was "fully spare"* | t/447:47,71 [T] |
| 25 | 22 | ☖ | **TFT D/C** (bench) — *was "fully spare"* | t/447:46,70 [T] |
| 26 | 37 | ★ | MCP3008 ADC **CS** (bit-banged) (+ generic) | t/410,435; t/110 |
| 27 | 13 | ★ | LCD D6 (`d2`) + stepper **CCW limit switch** | t/620:50-59; t/350:152 |
|  0 | 27 |   | ID_SD — generic test pin | default-config (idles high) |
|  1 | 28 |   | ID_SC — generic test pin | default-config (idles high) |

> **[F]** GPIO0/1 are physically the reserved I2C0 ID-EEPROM (HAT board-ID) pins.
> The tests only treat them as generic pins that idle high; the "leave unrouted"
> guidance is hardware convention, not a test fact.

> **The fabbed boards have one spare header pin: GPIO7 (CE1).** The pins the older
> doc called "spare" — **GPIO23/24/25** and hardware **CE0/GPIO8** — are now claimed
> by the bench-wired TFT (`t/447`). GPIO7 is the last board-free pin, and it is now
> the **bench radar's default OUT** (`t/361`, interim — see §10 item 11 / pin-relief
> R1; the radar will move to an MCP23017 expander input when permanently placed, at
> which point GPIO7 is free again). These bench claims do **not** consume pins on the
> fabbed boards (TFT/radar are off-PCB), but on a live header carrying the bench
> devices the Pi is effectively out of GPIO — the motivation for the pin-relief work.

### 2.1 Bare 40-pin header (J8) — native functions (orientation only)

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

### 2.2 Every pin mapped to its test-platform fixture

```
       Function / fixture       BCM  phys   phys  BCM  Function / fixture
       ----------------------------------------------------------------------
                          3V3   --  ( 1)   ( 2)  --   5V
       I2C SDA -> all I2C devs   2  ( 3)   ( 4)  --   5V
       I2C SCL -> all I2C devs   3  ( 5)   ( 6)  --   GND
                       LCD D4    4  ( 7)   ( 8)  14   UART TXD --+ loopback
                          GND   --  ( 9)   (10)  15   UART RXD <-+
               LCD D5 / CW sw   17  (11)   (12)  18   PWM/servo/INT -> ADS#1 A0
              LCD D6 / CCW sw   27  (13)   (14)  --   GND
                       LCD D7   22  (15)   (16)  23   (spare)
                          3V3   --  (17)   (18)  24   (spare)
        SPI MOSI -> 3 SPI devs  10  (19)   (20)  --   GND
           SPI MISO <- MCP3008   9  (21)   (22)  25   (spare)
        SPI SCLK -> 3 SPI devs  11  (23)   (24)   8   SPI CE0 (unused)
                          GND   --  (25)   (26)   7   SPI CE1 (unused)
            ID_SD (generic)      0  (27)   (28)   1   ID_SC (generic)
                       LCD RS    5  (29)   (30)  --   GND
                        LCD E    6  (31)   (32)  12   MCP4922 DAC CS (bit-bang)
            MCP4XXXX dpot CS    13  (33)   (34)  --   GND
                   centre LED   19  (35)   (36)  16   74HC595 LATCH
          MCP3008 ADC CS (bb)   26  (37)   (38)  20   74HC595 CLOCK
                          GND   --  (39)   (40)  21   74HC595 DATA
```

**Bit-banged chip-selects [T].** The three SPI chip-selects (GPIO26/12/13) are
ordinary GPIOs toggled in software, **not** the hardware CE0/CE1 (GPIO8/7) — see
§5 for the decoding. The 74HC595 (GPIO21/20/16) is fully bit-banged GPIO
(`t/435:48`). Clock/data still ride hardware SPI (GPIO9/10/11) **[L]**.

**The map above is the fabbed-board (PCB) view** — on the PCB, `7/8/23/24/25` are
spare and CE0/CE1 are unused, as drawn. The bench-wired TFT/radar (§Scope) claim
`8/23/24/25` (TFT) and `7` (radar OUT) only when jumpered to the live header; they
are off-PCB.

### 2.3 Bus topology and loop-backs

Top-down floorplan; devices cluster by bus off the Pi header. Each part is tagged
with its supply rail — **(3V3)** or **(5V)** **[F]** (rails are not test-derivable;
see §10 item 9 and §11). All Pi logic (GPIO, I2C, SPI, PWM) is 3V3; 5V parts take
3V3 control signals but need a 5V supply. Dashed arrows are the analog/digital
**loop-backs** from §1.

```
   Raspberry Pi 40-pin header — 3V3 logic; 3V3 + 5V + GND rails fan out below
   ===========================================================================

   I2C RAIL (SDA2 / SCL3, one 3V3 pull-up pair)
   ==+===========+============+=======+========+========+=======+=========
     |           |            |       |        |        |       |
  [ADS#1] [MCP23017#1] [MCP23017#2] [RTC] [EEPROM] [BMP180] [OLED] [Arduino]
   0x48      0x20         0x21      0x68   0x57     0x77     0x3c    0x04
   (3V3)     (3V3)        (3V3)     (3V3)  (3V3)    (3V3)    (3V3)   (5V *)
     |         |            |
     |         |            +-- GPA0-3 ==> ULN2003 ==> 28BYJ-48 stepper (5V)  t/350
     |         |            +-- RESET (chip pin 18) -> 3V3
     |         |
     |         +-- GPA(n) <-> GPB(7-n)  (straight-across loopback)  t/355
     |         +-- RESET (chip pin 18) -> 3V3
     |
     +-- A0 <==== GPIO18 (PWM / servo signal, 3V3)
     +-- A1 <==== MCP4XXXX dpot wiper

   Stepper feedback is Pi GPIO, not I2C:  CW limit = GPIO17,  CCW limit = GPIO27
   (magnetic switches);  centre LED = GPIO19  (centre computed, not sensed).  t/350

   SPI RAIL (MOSI10 / SCLK11 / MISO9; hardware SPI, CS bit-banged)
   ==+==============+==============+==============
     |              |              |
  CS26[MCP3008]  CS12[MCP4922]  CS13[MCP4XXXX]      (all 3V3)
     ^  ^  ^         |  |            |
 CH1_|  |  |_________|  |(out A)     |(write-only; wiper -> ADS#1 A1)
 CH3____|  |____________|(out B)
 CH2_______|
     ^
     +==== 74HC595 (3V3) Q-outputs   [DATA21 CLK20 LATCH16 from Pi, bit-banged]

   LCD HD44780 (5V; 3V3 logic in), 4-bit:  RS5  E6  D4=4  D5=17  D6=27  D7=22
   Servo:  5V power, 3V3 PWM signal shared on GPIO18
   UART loopback (3V3):  GPIO14 TXD ----> GPIO15 RXD

   * Arduino is a 5V board; it joins the bus through a 3V3<->5V I2C
     level-shifter [F], so SDA/SCL stay at 3V3 on the Pi side.
```

Legend: **(3V3)/(5V)** = component supply rail · `<==`/`==>` analog loop-back ·
`<->` bidirectional loopback wire · `==>`/`-->` drive/signal · `==` bus rail.

### 2.4 Generated artifacts & regeneration

The three views above (bare header, mapped fixtures, bus floorplan) are also
rendered, colour-coded by supply rail, as **`test-pinout-overview.jpg`** (bus/block
view) and **`test-pinout-detail.jpg`** (pin-by-pin). The full electrical schematic
ships as a multi-page vector **PDF**, and the KiCad board projects live under
**`kicad/`**:

- **`test-platform-schematic-A3.pdf`** / **`-A4.pdf`** — the schematic deliverable:
  a multi-page vector PDF (title/contents page + whole board + one page each for
  I2C / SPI / stepper / display), orthogonally wire-routed via netlistsvg/ELK.
  Open and zoom to read; the best single file to read/print.
- **`kicad/`** — one self-contained KiCad project per PCB
  (`rpi-wiringpi-unit-test-platform-board-1..5/`), each with its own
  `.kicad_sch` / `.kicad_pro`, `<board>.pretty/` footprint library and
  `fp-lib-table`. These are **not** part of the every-run regeneration: each
  board is scaffolded once with `gen-kicad.py`, then hand-finalized in KiCad.
- **`facts/test-platform.net`** — KiCad-importable netlist; every connection with
  datasheet-accurate pinouts.

This document is itself rendered from **`test-pinout-doc.tmpl.md`**; its only
generated block is the §12 Pi 5 default-state table (from `t/RPiTest.pm`).

Regenerate the views, netlist, schematic PDFs and this doc with
**`scripts/gen-test-platform.pl`** (needs the schematic venv + `netlistsvg`). It
drives the Python generators (`gen-pinout-images.py`, `gen-schematic.py`,
`gen-pdf.py`, `render-doc.py`), files the outputs here, and never writes to `t/`
or to `kicad/`. The wire-routed SVGs are scratch intermediates that feed the PDF
and are not kept. Without `netlistsvg`, the script produces everything else and
skips the schematic PDF with a warning. The KiCad board projects are scaffolded
separately and once, with `scripts/helpers/gen-kicad.py <kicad/board-dir>`.

---

## 3. Devices & pinouts per test file **[T]**

Every test that touches a pin or a device, decoded from its constructor call to
the concrete devices and pins it needs on the board. Tests that exercise no
hardware — module-load (`t/00,02,03,05`), identification/config (`t/100,104,106,309`),
in-process metadata (`t/111`), signal/exit (`t/153,154`), sysinfo (`t/300-308`),
the OLED lock-file cleanup (`t/520`), the HW-free unit tests
(`t/354,356,357,359,362,448` and the other `*_unit` files, which mock the bus and
touch no pins), and POD/manifest (`t/899,900,905,910,915`) — are omitted here.

Pins are **BCM GPIO**; I2C devices are given by bus address. "generic GPIO" =
the pin is claimed/toggled as an ordinary GPIO with no peripheral attached. SPI
clock/data ride hardware SPI0 (**MOSI=GPIO10, SCLK=GPIO11, MISO=GPIO9** — `[L]`
pin numbers); each SPI device's chip-select is a **bit-banged** GPIO. All I2C
devices share **SDA=GPIO2 / SCL=GPIO3**. See the cited sections for full decoding.

| Test file | Device(s) required | Pinout / connections |
|-----------|--------------------|----------------------|
| `105-pin.t` | — (generic GPIO) | GPIO18 — plain read/write |
| `107-alt_modes.t` | — (generic GPIO) | GPIO21 — ALT0–ALT7 round-trip |
| `108-mode_state_all_pins.t` | — (generic GPIO) | all checked pins: GPIO 0,1,2,3,7,8,9,10,11,12,13,14,15,16,18,19,20,21,23,24,25,26 (default mode/state; 4,5,6,17,22,27 excluded for LCD) |
| `400-pwm_hw_mods.t` | ADS1015 #1 | GPIO18 (hardware PWM out) → ADS1015 #1 @0x48 A0; I2C SDA2/SCL3 |
| `110-register.t` | — (generic GPIO) | GPIO12, 18, 26 — registration/counting |
| `112-metadata_multi_pi_multi_script.t` | — (generic GPIO) | GPIO12, 16, 18, 21, 26 (via `multi/full_master.pl` + `full_slave.pl`) |
| `113-metadata_multi_pi_multi_script_die.t` | — (generic GPIO) | GPIO12, 18 (via `multi/die_master.pl` + `die_slave.pl`) |
| `114-metadata_multi_pi_multi_script_sigint.t` | — (generic GPIO) | GPIO12, 18 (via `multi/int_master.pl` + `int_slave.pl`) |
| `405-pwm_i2c_adc.t` | ADS1015 #1 | GPIO18 (PWM out) → ADS1015 #1 @0x48 A0; I2C SDA2/SCL3 |
| `150-cleanup.t` | — (generic GPIO) | GPIO12, 18, 26 |
| `200-interrupt_rising_and_pud.t` … `212-pin_background_interrupt.t` (13 interrupt tests, incl. `204-last_interrupt.t`), `213-worker.t` | — (generic GPIO) | GPIO18 — self-triggered via internal pull (PUD_UP→PUD_DOWN); **no external driver/load** (§7) |
| `600-i2c_exceptions.t` | — (I2C error path) | I2C SDA2/SCL3; probes deliberately-absent addr 0x99 — no device responds |
| `605-i2c.t` | Arduino (I2C slave) | I2C SDA2/SCL3 @0x04 |
| `410-dac.t` | MCP4922 DAC, MCP3008 ADC | SPI MOSI10/SCLK11/MISO9; DAC CS=GPIO12 (bit-bang), ADC CS=GPIO26 (bit-bang); DAC out A→MCP3008 CH1, out B→CH3 |
| `610-serial.t` | — (UART loopback) | UART TXD GPIO14 → RXD GPIO15 |
| `530-rtc.t` | DS3231 RTC | I2C SDA2/SCL3 @0x68 |
| `425-servo.t` | Servo, ADS1015 #1 | GPIO18 (servo PWM) → ADS1015 #1 @0x48 A0; I2C SDA2/SCL3 |
| `355-mcp23017.t` | MCP23017 expander | I2C SDA2/SCL3 @0x20; GPA(n) ↔ GPB(7-n) straight-across loopback |
| `435-shift_reg_adc.t` | 74HC595, MCP3008 ADC | 74HC595 DATA=GPIO21, CLOCK=GPIO20, LATCH=GPIO16 (bit-bang); SPI MOSI10/SCLK11/MISO9, MCP3008 CS=GPIO26; 595 Q0→MCP3008 CH2 |
| `531-bmp.t` | BMP180 | I2C SDA2/SCL3 @0x77 |
| `445-dpot.t` | MCP4XXXX dpot, ADS1015 #1 | SPI MOSI10/SCLK11; dpot CS=GPIO13 (bit-bang); wiper → ADS1015 #1 @0x48 A1; I2C SDA2/SCL3 |
| `540-eeprom_args.t` | AT24C32 EEPROM | I2C SDA2/SCL3 @0x57 |
| `541-eeprom_read_write_byte_croak.t` | AT24C32 EEPROM | I2C SDA2/SCL3 @0x57 |
| `542-eeprom_read_write_byte.t` | AT24C32 EEPROM | I2C SDA2/SCL3 @0x57 |
| `350-stepper.t` | MCP23017 (0x21), ULN2003, 28BYJ-48 stepper | MCP23017 @0x21 GPA0–3 → ULN2003 IN1–4 → 28BYJ-48 coils; CW switch GPIO17 + CCW switch GPIO27 via `background_interrupt` (forked ISR children); centre LED GPIO19 flashed by a one-shot `worker` (fork); centre computed, not sensed; I2C SDA2/SCL3. **Also exercises the interrupt + worker concurrency machinery.** |
| `500-oled_new.t` … `509-oled_horizontal_line.t` (10 OLED tests) | OLED SSD1306 128×64 | I2C SDA2/SCL3 @0x3c |
| `620-lcd.t` | HD44780 LCD (20×4, 4-bit) | RS=GPIO5, E=GPIO6, D4=GPIO4, D5=GPIO17, D6=GPIO27, D7=GPIO22 |

**Newer devices (added since the original derivation).** These join the suite via
their own env gates; the TFT/radar/gyro/adxl335/a4988 are **bench**-wired (§Scope),
the I2C LCD and PCA9685 belong to board 1.

| Test file | Device(s) required | Pinout / connections |
|-----------|--------------------|----------------------|
| `335-lcd_i2c.t` | HD44780 on PCF8574 backpack | I2C SDA2/SCL3 @**0x27**; RS/E/D4-7 are PCF8574 virtual pins (base 64), **no Pi GPIO** beyond the bus (`t/335:38,62`; `WiringPi.pm:290,300`) — board 1 |
| `353-a4988.t` | A4988 stepper via MCP23017 | I2C SDA2/SCL3 @**0x22**; STEP/DIR/MS1-3/ENABLE/SLEEP/RESET = expander GPA0-7, **no Pi GPIO** (`t/353:88-97,99,135`; facade skips Pi-pin registration when `expander` passed, `WiringPi.pm:472-488`) — bench |
| `358-gyro.t` | MPU-6050 IMU | I2C SDA2/SCL3 @**0x68** (`t/358:76`; WHO_AM_I asserted); shares the RTC address (§4, §10) — bench |
| `360-adxl335.t` | ADXL335 via ADS ADC | I2C SDA2/SCL3; analog X/Y/Z → ADS (model `ADS1115` default) @**0x48** channels **0/1/2** (`t/360:71-76`; `ADS.pm:191`) — no Pi GPIO beyond the bus — bench. Same addr+channels as the board-2 ADS (§10) |
| `361-radar.t` | RCWL-0516 motion | **GPIO7** OUT (input, CE1) — test default (driver has none; `RCWL0516.pm:27-28`), env `RPI_RADAR_PIN`; the only board-free pin, interim until an expander (§10 item 11) — bench |
| `440-pca9685.t` | PCA9685 16-ch PWM | I2C SDA2/SCL3 @**0x40** (`PCA9685.pm:47`); register readback only, 16 PWM outs are the chip's own — board 1 (not wired yet) |
| `447-tft_st7735s.t` | ST7735S 128×128 TFT | **hardware SPI0** MOSI10/SCLK11, **CS = hardware CE0/GPIO8** (channel 0); D/C=**GPIO25**, RES=**GPIO24**, BLK=**GPIO23**; write-only, no MISO (`t/447:46-47,69-72`) — bench |

---

## 4. I2C bus (GPIO2 SDA / GPIO3 SCL)

One shared 2-wire bus; each device by address. **This table is generated** from
the bus map (`facts/bus-map.json`), itself derived from `board-model.py`'s
`BUS_DEVICES` and cross-checked against the netlist on every `make test` — a
declared address that disagrees with the wiring fails the build, so this list
cannot drift. `Ctx` is `onboard` (in the electrical model), `planned` (board 1,
not yet fabbed) or `bench` (bench-wired, env-gated). The `Test` column names a
proving test; full per-device provenance (`[T]` explicit vs `[L]` submodule
default, with file:line) lives in `scripts/helpers/model-from-tests.py`.

{{i2c_table}}

Devices sharing an address (0x48, 0x68) are never co-resident — see the note
below. ‡ `t/600` is the I2C *exception* test: it probes a deliberately-absent address
`0x99` (t/600:36,44) to verify error handling — it does not talk to a real device.

> **Shared addresses [T] (never co-resident).** Two pairs answer at the same
> address but are never on the bus together (different context, separate env gates):
> - **0x68** — DS3231 RTC (board 4) and MPU-6050 gyro (bench, `t/358:76`). If ever
>   co-resident, strap the MPU-6050 AD0 pin high → **0x69** (MPU6050.pm:194-195).
> - **0x48** — the board-2 ADS (PWM/servo=A0, dpot PW0=A1, dpot PW1=A2) and the
>   bench ADS the ADXL335 reads on channels 0/1/2 (`t/360:71-76`). Different physical
>   chips; a second ADS can strap **0x49–0x4B** (ADS.pm:184-186) to coexist.

> **[F]** Notes the tests do **not** establish:
> - The Arduino's board type. The test only uses I2C address `0x04`; "Metro Mini"
>   vs "Uno" vs a bare ATMega-328P (and an optional second unit at `0x05`) is from
>   `FAQ.pod`/README, not the tests.
> - That the EEPROM (`0x57`) and RTC (`0x68`) sit on the **same** physical
>   DS3231 ZS-042 breakout. The tests see two independent I2C addresses.
> - A **3V3↔5V I2C level-shifter** for any 5V I2C device. The tests run the bus at
>   the Pi's native 3V3 and never reveal a shifter; it's a board-design assumption.

```
      +3V3 ─ pull-ups ─┐   ┌────┬────┬────┬────┬── ... (all I2C devices)
 GPIO2 (SDA) ──────────┴SDA┤    │    │    │    │
 GPIO3 (SCL) ──────────SCL─┤0x20 0x21 0x22 0x48 0x68 0x77 0x57 0x3c 0x04 0x27 0x40
                          MCP#1 MCP#2 MCP#3 ADS  RTC  BMP  EEP  OLED Ardu LCD  PCA
                          (t355)(t350)(t353)(t405)(t530)(t531)(t540)(t500)(t605)(t335)(t440)
```
Bench-only extras on the same bus when wired: MPU-6050 @0x68 (`t/358`), an ADS
@0x48 for the ADXL335 (`t/360`).

**One board-2 ADS1015 ADC [T].** `0x48` carries the analog read-backs the suite
needs — PWM/servo on A0 (`t/405,425`) and **both dpot wipers, PW0 on A1 and PW1 on
A2** (`t/445:38-39`). The stepper no longer uses an ADC: its limits are magnetic
switches on Pi GPIO17/27 and centre is computed (§8).

**Three MCP23017 expanders [T].** `0x20` is the loopback chip (`t/355`); `0x21`
drives the 28BYJ-48 stepper coils (`t/350:138`); `0x22` drives the bench A4988
stepper's control lines (`t/353:99`).

### 4.1 MCP23017 expanders — pin allocation **[T]**

**Three separate** MCP23017s, one per job — `t/355`'s loopback chip at `0x20`, the
28BYJ-48 stepper's drive chip at `0x21`, and the bench A4988 stepper's control
chip at `0x22`:

```
  #1 @0x20:  GPA(n)     <-> GPB(7-n)   straight across the DIP   (t/355 loopback)
  #2 @0x21:  GPA0..GPA3  ─► ULN2003 IN1..IN4 ─► 28BYJ-48 coils   (t/350; drive)
  #3 @0x22:  GPA0..GPA7  ─► A4988 STEP/DIR/MS1-3/ENABLE/SLEEP/RESET (t/353; bench)
```

`t/355` writes `GPA(n)` and reads it back on `GPB(7-n)` — the IC is jumpered
**straight across the DIP** (GPA0↔GPB7, GPA1↔GPB6, … GPA7↔GPB0) — for **n = 0..7**,
bidirectionally on the **0x20** chip (`t/355:672-683,698-709`). `t/350` drives
`pins => [A0,A1,A2,A3]` = **GPA0-3** on the **0x21** chip (`t/350:138,272`);
`t/353` drives the A4988's 8 control lines on **GPA0-7** of the **0x22** chip
(`t/353:88-97,99`). In every case the `expander => $exp` path means the driver
writes via I2C, not Pi GPIO — the facade registers **no** Pi pin
(`WiringPi.pm:472-488`), so these steppers cost **zero** header GPIO.

> **[F]** The MCP23017 RESET (chip pin 18) tie-high to 3V3 is standard practice;
> the tests don't touch it.

---

## 5. SPI bus (GPIO9 MISO / GPIO10 MOSI / GPIO11 SCLK)

Clock and data ride **hardware SPI0** (GPIO9/10/11) **[L]**. Each device's
**chip-select is a bit-banged GPIO** — decoded from the constructor args via the
submodules **[T]**:

- **MCP3008** `adc(model=>'MCP3008', channel=>26)` — the single arg is the SPI
  *bus channel* only when it is 0/1; when **> 1 it is a GPIO used as CS** by the
  driver (`MCP3008.pm:30-32`). So `26` ⇒ **CS = BCM 26** (`t/410:35,65-68`,
  `t/435:34,43-46`). MCP3008 is the only SPI device that uses **MISO**.
- **MCP4922 DAC** `dac(model=>'MCP4922', channel=>0, cs=>12)` — `channel`=SPI bus
  0, **CS = BCM 12** (`MCP4922.pm:36-37`; `t/410:35,59-63`). Write-only (no MISO).
- **MCP4XXXX dpot** `dpot(13, 0)` — arg1 = **CS = BCM 13**, arg2 = SPI bus 0
  (`MCP4XXXX.pm:16,19`; `t/445:34,52`). Write-only (no MISO).

The three board-2 SPI devices all bit-bang CS, so the fabbed boards leave the
hardware CE0/CE1 (GPIO8/7) free. **The one exception is the bench-wired TFT**
(`t/447`): the ST7735S is driven on **hardware CE0 (GPIO8, channel 0)** — the only
device in the suite that uses a hardware chip-select — plus its own D/C, RES and
BLK GPIOs (§Scope). It shares MOSI/SCLK with the board-2 SPI bus (one CS active at
a time). All four board-2 SPI devices are powered at 3V3 **[F]**; the TFT at 3V3.

**Chip-selects (generated from the bus map).** Each SPI CS below is derived from
`board-model.py` and cross-checked against its `CS_*` net through `J1FUNC` on
every `make test`, so the CS GPIO cannot drift from the wiring:

{{spi_table}}

The wiring/topology view below adds the shared MOSI/SCLK/MISO and analog readback
paths that the CS map above omits:

| Device | CS | MOSI | SCLK | MISO | Tests | Output read back by |
|--------|---:|------|------|------|-------|---------------------|
| MCP3008 ADC | **26** (bit-bang) | 10 | 11 | 9 | t/410,435 | (it is the reader) |
| MCP4922 DAC | **12** (bit-bang) | 10 | 11 | — | t/410 | out A→MCP3008 CH1, out B→MCP3008 CH3 |
| MCP4XXXX pot| **13** (bit-bang) | 10 | 11 | — | t/445 | PW0→ADS#1 A1, PW1→ADS#1 A2 |
| **ST7735S TFT** (bench) | **CE0/GPIO8** (hardware) | 10 | 11 | — | t/447 | write-only (no readback wire) |

```
 GPIO10 MOSI ─┬──────────┬───────────┬───────────┐
 GPIO11 SCLK ─┼────┬─────┼─────┬─────┼─────┬─────┤
 GPIO9  MISO ─┘    │     │     │     │     │     │
   CS GPIO26 ──► MCP3008 │     │     │     │
   CS GPIO12 ──────────► MCP4922     │     │
   CS GPIO13 ──────────────────────► MCP4XXXX    │
   CE0 GPIO8 ──────────────────────────────────► ST7735S TFT (bench)
```

**MCP3008 channel map [T]:** CH1 ← DAC out A (`t/410:37`), CH2 ← 74HC595 first Q
(`t/435`), CH3 ← DAC out B (`t/410:38`).

> The dpot in tests is the **MCP4XXXX** family (`rpi-digipot-mcp4xxxx`); the
> existing schematic models it as the specific part **MCP42010** **[F]**.

---

## 6. LCD — HD44780, 4-bit mode (`t/620`) **[T]**

`lcd(... cols=>20, rows=>4, bits=>4, d4..d7=>0 ...)` (`t/620:50-59`) ⇒ a **20×4**
character module in **4-bit** mode (lower data lines D0–D3 unused; `RPi::LCD`
requires `d4..d7 = 0` for 4-bit — `LCD.pm:114-120`).

| Pi BCM | LCD pin | Library arg |
|-------:|---------|-------------|
| 5  | RS | `rs`  |
| 6  | E  | `strb`|
| 4  | D4 | `d0`  |
| 17 | D5 | `d1`  |
| 27 | D6 | `d2`  |
| 22 | D7 | `d3`  |

`rpi_check_pin_status()` deliberately **excludes pins 4,5,6,17,22,27** "because of
LCD" (`RPiTest.pm:311`) — they are reserved for the display and not asserted as
generic pins.

> **Shared with the stepper:** GPIO17 (D5) and GPIO27 (D6) also serve as the
> stepper's CW/CCW magnetic limit switches in `t/350` (§8). The two tests never run
> at once (serial suite), but it is a shared physical net — see §10.

> **An I2C variant of this LCD also exists (`t/335`).** The same HD44780 behind a
> **PCF8574 backpack at 0x27** (`lcd(i2c => 0x27, rows => 4, cols => 20)`,
> `t/335:38,62`) drives its RS/E/D4-7 as PCF8574 virtual pins (base 64) over the
> I2C bus — **it uses none of the six Pi GPIOs above**. It's a board-1 device. This
> is the pattern behind one of the pin-relief options: the parallel LCD's 6 pins
> (4/5/6/22 dedicated, 17/27 shared) can be reclaimed by moving to the I2C LCD.

> **[F]** The logical `d0..d3` → physical DB4..DB7 mapping is the standard HD44780
> 4-bit convention; the test proves logical wiring + 4-bit mode, not silkscreen
> pin numbers. R/W tied to GND (write-only) is also convention.

---

## 7. GPIO18 — the multiplexed workhorse pin (physical pin 12)

One physical net wired to **ADS1015 #1 channel A0**, reused across many tests:

| Mode | Tests | Dir | How |
|------|-------|-----|-----|
| Hardware PWM out | t/400, t/405 | OUT | sweeps duty; ADS #1 A0 reads voltage (`t/405:56,57,75-82`) |
| Servo PWM out | t/425 | OUT | servo pulse; ADS #1 A0 reads position (`t/425:92,113-114`) |
| Edge interrupt source | t/200-212 | IN | **self-triggered** by toggling the *internal* pull resistor (`pull(PUD_UP)`→`pull(PUD_DOWN)`) — no external edge driver (`t/200:40-45`) |
| Plain pin / register / worker | t/105,110,150,213,multi | IN/OUT | read/write + metadata registration |

**PCB constraint [T] (load-bearing).** The interrupt tests swing the line using
only the Pi's *internal* ~50 kΩ pull (`pull()` → `pullUpDnControl`, `RPi/Pin.pm:75-85`).
The tests say so directly: "wire nothing to BCM18" (`t/213:121`), "self-triggered
pin" (`t/210:115`). Therefore the GPIO18 net must carry **no external pull
resistor and no low-impedance load** — only the high-Z ADS1015 A0 input may hang
off it (a series resistor to A0 is fine; a pull resistor would break the interrupt
tests). Debounce is 0 throughout (`t/210:37`), so the net must also be kept short
/ low-capacitance to settle inside the ~20 ms edge pacing. The pin's at-rest
default is INPUT (`get_alt(18)==0`, `t/213:152`).

---

## 8. Shift register & stepper (indirect drives)

**74HC595 (`t/435`) — fully bit-banged GPIO [T].** `shift_register(400, 8, 21, 20, 16)`
(`t/435:48`) decodes (via `WiringPi.pm:334`) to base=400, 8 outputs,
**DATA=BCM21, CLOCK=BCM20, LATCH=BCM16**:

| Pi BCM | 74HC595 | Library arg position |
|-------:|---------|----------------------|
| 21 | DS (pin 14)    | data  |
| 20 | SH_CP (pin 11) | clock |
| 16 | ST_CP (pin 12) | latch |

The first Q-output is exposed as virtual pin **401**; writing it HIGH/LOW is read
back on **MCP3008 CH2** (`t/435:52,54-77`). Virtual pins 400-407 are not Pi GPIO.

**Stepper (`t/350`) — coils via I2C expander, limits on Pi GPIO [T].** Coils are
driven through a ULN2003 by **MCP23017 #2 (0x21)** Bank A pins 0-3 (§4.1), so they
use no direct Pi GPIO. Travel is bounded by **two magnetic limit switches** read
directly on the Pi: **CW on GPIO17** (`t/350:148`) and **CCW on GPIO27**
(`t/350:152`), each armed as a rising-edge `background_interrupt` (`t/350:157,163`).
**Centre is computed, not sensed** — symmetric tick counts return the motor to
mid-travel — and shown on a **centre LED on GPIO19** (`t/350:143`), pulsed by a
one-shot fork **`worker`** so the LED hold never stalls the sweep. So beyond the
expander drive, the test concurrently exercises both the `background_interrupt`
(ISR) and `worker` (fork) subsystems. The test
sweeps ccw/cw across several speed/delay configs and asserts each limit edge fires
within its expected time window (`t/350:362-395`).

**Per-config timing map (`t/350`) [T].** Each pass sweeps one `speed/delay` config
and asserts both magnet edges trip within **±5%** of these measured means
(out-sweep start → magnet); `%EXPECT` in the test holds the same numbers:

| Pass | speed / delay | ccw edge | cw edge  |
|-----:|---------------|---------:|---------:|
| 1, 2 | full / 0.00   | 2088 ms  | 2048 ms  |
| 3    | full / 0.01   | 8926 ms  | 8604 ms  |
| 4    | half / 0.01   | 17816 ms | 17176 ms |
| 5    | half / 0.00   | 4170 ms  | 4028 ms  |

---

## 9. Pins NOT wired to fixtures **[T]**

> **Update:** the bench device wave (§Scope) consumed nearly all the headroom the
> original derivation reported. On the **fabbed boards** GPIO7/8/23/24/25 are still
> free; on a **live header** carrying the bench devices, none is guaranteed free —
> GPIO7 (CE1) is now the bench radar's default (interim, §10 item 11).

- **GPIO7 (CE1)** — the last header BCM with no fabbed-board role; now the **bench
  radar's default OUT** (`t/361`, interim — it will move to an MCP23017 expander
  input when the radar is permanently placed, freeing GPIO7 again; see §10 item 11 /
  pin-relief R1).
- **GPIO8 (CE0)** — free on the fabbed boards, but **claimed by the bench TFT** as
  its hardware chip-select (`t/447`, §5).
- **GPIO23, 24, 25** — spare on the fabbed boards, but **claimed by the bench TFT**
  (BLK/RES/DC respectively, `t/447`, §2). No longer "fully spare".
- **GPIO26** — the MCP3008 bit-banged CS (+ generic). (The bench radar used to
  default here; moved to GPIO7 to clear the CS collision — §10 item 11.)
- **GPIO21** — also the alt-mode round-trip pin in `t/107` (loops ALT0–ALT7), on
  top of its 74HC595 DATA duty.
- **GPIO0 / GPIO1** (phys 27/28) — used as generic test pins; idle high. **[F]**
  reserved I2C0 ID-EEPROM pins — best left unrouted on a real board, so they are
  not dependable general-purpose spares.

**Zero-GPIO fixtures worth noting (the relief pattern).** Several fixtures already
cost **no** header GPIO by riding a bus: the 28BYJ-48 and A4988 steppers drive all
their control lines through MCP23017 expanders (0x21 / 0x22, §4.1); the I2C LCD
(`t/335`) drives HD44780 through a PCF8574 (0x27, §6); the OLED, RTC, EEPROM, BMP,
gyro and PCA9685 are pure I2C. This is the lever the pin-relief work builds on.

---

## 10. Collisions & shared-net warnings

> Software-wise nothing conflicts — tests run **serially** and each cleans up
> (`RPiTest.pm:3-7`). The items below are physical-net decisions for the PCB.

1. **Shared I2C bus (GPIO2/3) [T] — provide no external pull-up pair [F].** Up to a
   dozen addresses share the bus (board fixtures + bench devices). The Pi already
   provides ~1.8 kΩ pull-ups on SDA/SCL to
   3V3 (every 40-pin model, Pi 3 through Pi 5/RP1), so **add no external pull-up
   pair**. The Pi's 1.8 kΩ dominates; typical breakout pull-ups (4.7–10 kΩ) only
   nudge the combined value down and on a busy bus help drive the extra
   capacitance — which is why a fully-populated bus generally just works. Watch the
   opposite case: if several breakouts carry *aggressive* low-value pulls (2.2 kΩ)
   the combined resistance can drop too low to pull SDA/SCL cleanly below 0.4 V —
   symptoms are missing/flickering addresses in `i2cdetect`, NAKs, or intermittent
   reads. To verify after assembly: measure SDA→3V3 / SCL→3V3 (≥0.6 kΩ is fine),
   run `i2cdetect -y 1` plus a soak loop, and if flaky drop to 100 kHz
   (`dtparam=i2c_arm_baudrate=100000`) for margin. A BSS138-type level-shifter for
   the 5V Arduino adds its own ~10 kΩ pulls on the Pi side. Strap the ADS to 0x48
   and the three MCP23017s to 0x20 (t/355), 0x21 (28BYJ-48 stepper) and 0x22 (A4988,
   bench); board-1 adds the I2C LCD 0x27 and PCA9685 0x40.
2. **Shared SPI bus (GPIO9/10/11) [T]** — four devices total, one active CS at a
   time: three bit-banged (26/12/13) plus the bench TFT on hardware CE0/GPIO8 (§5).
   Write-only DAC/dpot/TFT must not drive MISO.
3. **GPIO18 over-subscribed [T]** — PWM + servo + interrupt + generic + ADS#1 A0
   on one wire. Honour the "no external pull / no load" rule of §7.
4. **Device-control pins doubling as generic GPIO [T]** — `t/110` and the
   multi-process tests register/toggle **GPIO12, 16, 18, 21, 26** as plain pins
   (`t/110:23-25`; `full_slave.pl:13-20`; `full_master.pl:28`). On the board these
   are live control lines (DAC CS, SR LATCH, PWM/ADS, SR DATA, ADC CS); toggling
   them while the device is idle is harmless but real.
5. **CS lines excluded from state checks [T]** — `rpi_default_pin_config` marks
   **GPIO12 and GPIO26** as *mode-only* (state `undef`): "level depends on the
   attached device's pull state" (`RPiTest.pm:336-337`; the undef states sit in the
   pi5/pi4/pi3 tables at `:523-524/:486-487/:451-452`). Don't add pulls that fight
   the idle level.
6. **GPIO13 comment vs asserted state — discrepancy [T].** The harness comments
   GPIO13 as "OUTPUT/HIGH due to the dpot test (t/445)" yet its expected resting
   `state` is **0** in all three board tables. Flagged as an inconsistency in the
   harness, not resolved by the tests.
7. **Serial vs Bluetooth [F/L]** — the UART loopback (GPIO14→15) needs the primary
   header UART. `rpi_serial_device()` returns `/dev/ttyAMA0` on Pi 5 (RP1) and
   `/dev/ttyS0` on Pi 3/4 (`RPiTest.pm:423-431`). On Pi 5 the header UART is its
   own PL011 (no `disable-bt` overlay needed); on Pi 3/4 freeing it from Bluetooth
   is the classic step. With UART enabled, GPIO14/15 report funcsel and idle high.
8. **OLED locks the I2C bus [T]** — if `/dev/shm/oled_in_use` exists (an external
   OLED daemon, started by `t/crontab`), `rpi_check_pin_status` **drops pins 2 and
   3** from the check (`RPiTest.pm:313`; `@gpio_pins` OLED-branch `:322-324`).
9. **Mixed rails (3V3 / 5V) [F]** — not determinable from the tests. The existing
   design runs all Pi logic + I2C/SPI ICs + 74HC595 at 3V3, and the LCD, stepper
   (via ULN2003), servo and Arduino at 5V, with a level-shifter for the 5V I2C.
   Verify against your actual parts. Full per-rail device lists and the current
   budget are in §11.
10. **GPIO17/27 shared — LCD vs stepper limits [T].** GPIO17 (LCD D5) and GPIO27
   (LCD D6) also read the stepper's CW/CCW magnetic limit switches (`t/350`).
   `t/620` drives them as LCD outputs; `t/350` reads them as switch inputs. The
   serial suite keeps them apart in software, but they are one shared net on the
   board — don't add a pull/load that fights either role. GPIO19 (stepper centre
   LED) is dedicated.
11. **GPIO26 / radar OUT — RESOLVED (pin-relief R1).** The bench radar's OUT default
   used to be GPIO26, the MCP3008 bit-banged CS (board 2). Unlike a passive shared net
   (e.g. the reed switches on 17/27), the radar OUT is an **always-on active driver**, so
   it fights the Pi-driven CS whenever the ADC test runs — and software cleanup can't
   quiet an external sensor. `t/361` now defaults the radar to **GPIO7** (CE1), the only
   board-free pin (`t/361:75`; env `RPI_RADAR_PIN`). **Interim:** when the radar is
   permanently placed it will read through an MCP23017 expander input (zero header pin,
   like the steppers), which frees GPIO7 again.
12. **Shared I2C addresses across contexts [T] (bench).** MPU-6050 gyro and DS3231
   RTC both answer at **0x68**; the ADXL335's ADS and the board-2 ADS both at
   **0x48** on the same channels. Board vs bench, never co-resident; escape hatches
   are MPU-6050 → 0x69 and a second ADS at 0x49–0x4B (§4).

---

## 11. Power rails — supply connections **[F]**

> Supply rails are **not** test-derivable — none of the tests read a voltage rail —
> so this whole section is **[F]**: from standard module voltages and the existing
> schematic. Confirm against your actual parts.
>
> The Pi feeds two rails from the 40-pin header: **+3V3** (header pins 1, 17) and
> **+5V** (header pins 2, 4), with a common **GND** (pins 6, 9, 14, 20, 25, 30,
> 34, 39). All Pi logic is 3V3; the 5V parts accept the Pi's 3V3 control signals
> but need a 5V supply on their power pin. The 5V Arduino/ATMega reach the I2C bus
> through a 3V3↔5V level-shifter so SDA/SCL stay at 3V3 on the Pi side (see §10
> item 9).

### 11.1 +3V3 bus

All I2C and SPI ICs plus the 74HC595 run at 3V3 (so the DAC/dpot/ADC analog range
matches the Pi's 3V3 PWM/GPIO levels):

| Device                | Ref / addr   | Power pin     | Notes                              |
|-----------------------|--------------|---------------|------------------------------------|
| ADS1015 ADC #1        | I2C 0x48     | VDD           | A0=PWM/servo, A1=dpot wiper        |
| MCP23017 #1 expander  | I2C 0x20     | VDD           | t/355 loopback; RESET tied 3V3     |
| MCP23017 #2 expander  | I2C 0x21     | VDD           | t/350 stepper drive; RESET tied 3V3|
| DS3231 RTC            | I2C 0x68     | VCC           | RTC/EEPROM breakout                |
| AT24C32 EEPROM        | I2C 0x57     | VCC           | same breakout board as the RTC     |
| BMP180 pressure/temp  | I2C 0x77     | VIN           | 3V3 only — **not** 5V tolerant     |
| OLED SSD1306 128×64   | I2C 0x3c     | VCC           |                                    |
| MCP3008 ADC           | SPI CS26     | VDD + VREF    | the SPI read-back reader           |
| MCP4922 DAC           | SPI CS12     | VDD + VREFA/B | out A→MCP3008 CH1, out B→CH3        |
| MCP4XXXX digital pot  | SPI CS13     | VDD           | wiper → ADS#1 A1                    |
| 74HC595 shift register| bit-banged   | VCC           | 3V3 logic; Q-outputs → MCP3008 CH2 |

Other 3V3 connections (not a device power pin):

- **I2C pull-ups** — the Pi already supplies ~1.8 kΩ pull-ups on SDA/SCL (GPIO2/3)
  to 3V3 on every 40-pin model (Pi 3 through Pi 5/RP1), so **no external pull-up
  pair is needed**. The risk is the opposite — breakout on-board pull-ups parallel
  against the Pi's 1.8 kΩ; verify the combined value isn't too low and run at
  100 kHz for margin if needed (see §10 item 1).
- **MCP23017 RESET** (chip pin 18) — tie HIGH to 3V3 (active-low reset).
- **MCP4XXXX dpot end-terminal** — high terminal to 3V3, other to GND (reference).
- **Level-shifter LV side** — low-voltage reference = 3V3.

### 11.2 +5V bus

The 5V parts take 3V3 control/logic signals but are powered from 5V:

| Device                  | Ref / role        | Power pin       | Notes                              |
|-------------------------|-------------------|-----------------|------------------------------------|
| HD44780 LCD             | display (`t/620`) | VDD + backlight | logic inputs (RS/E/D4-7) are 3V3   |
| 28BYJ-48 stepper        | via ULN2003       | motor V+        | coils, `t/350`                     |
| ULN2003 driver          | stepper driver    | COM / VCC       | driven by MCP23017 #2 (0x21) GPA0-3|
| Servo                   | on GPIO18 PWM     | V+              | signal 3V3, power 5V               |
| Arduino                 | I2C 0x04          | VIN / 5V        | joins bus via level-shifter        |
| ATMega-328P (standalone)| I2C 0x05          | VCC             | optional; only in I2C mode         |

Other 5V connections:

- **Level-shifter HV side** — high-voltage reference = 5V.

### 11.3 Current budget (estimate)

> Datasheet-typical figures, **not measured** — confirm against your parts before
> sizing traces/connectors. The suite runs tests **sequentially** (§10), so the
> stepper (`t/350`) and servo (`t/425`) never draw at the same instant; the
> "naive all-on" column is therefore conservative and is the number to size a
> supply against, while real per-test peaks are lower. Servo figures are for the
> **Tower Pro SG90** micro servo.

**+3V3 bus** — all I2C/SPI ICs + the 74HC595:

| Device | Ref | Typ (mA) | Peak (mA) | Note |
|--------|-----|---------:|----------:|------|
| ADS1015 #1 | 0x48 | 0.15 | 0.20 | continuous-conversion |
| MCP23017 #1 | 0x20 | 1.0 | 1.0 | logic only; loopback drive is high-Z |
| MCP23017 #2 | 0x21 | 1.0 | 1.0 | stepper drive (ULN2003 inputs, high-Z) |
| DS3231 RTC | 0x68 | 0.2 | 0.2 | **+~3 mA if breakout power-LED fitted** |
| AT24C32 EEPROM | 0x57 | 0.5 | 3.0 | peak during page write |
| BMP180 | 0x77 | 0.01 | 0.65 | µA between samples |
| OLED SSD1306 | 0x3c | 15 | 30 | **dominant 3V3 load**; scales with lit pixels |
| MCP3008 | CS26 | 0.5 | 0.55 | |
| MCP4922 DAC | CS12 | 0.7 | 0.9 | |
| MCP4XXXX dpot | CS13 | 0.5 | 1.0 | +~0.33 mA ladder (10 kΩ, 3V3→GND) |
| 74HC595 | bit-bang | 0.5 | 2.0 | dynamic/switching |
| I2C pull-ups (Pi 1.8 kΩ ×2) | — | ~0 | ~4 | momentary, only while a line is held low |
| dpot ladder | — | ~0.33 | ~0.5 | into ADS#1 A1 (high-Z) |
| **+3V3 subtotal** | | **~20** | **~45** | OLED is ~75%; +~3 mA w/ RTC LED |

**+5V bus** — LCD, stepper, servo, Arduino:

| Device | Ref | Typ (mA) | Peak/stall (mA) | Note |
|--------|-----|---------:|----------------:|------|
| HD44780 logic | t/620 | 1.5 | 2 | |
| HD44780 backlight | t/620 | 25 | 120 | depends on series R / jumper |
| 28BYJ-48 stepper (via ULN2003) | t/350 | 160 | 240 | 2-phase → all-coil energized |
| ULN2003 | — | 0.5 | 1 | own draw; motor current counted above |
| Servo SG90 | t/425 | 10 idle / 250 run | 700 | stall is the big spike |
| Arduino | 0x04 | 25 | 40 | regulator + power LED |
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

## 12. Expected default pin states (from `t/RPiTest.pm`) **[T]**

`rpi_default_pin_config()` (`RPiTest.pm:435-551`) is the at-rest mode/state every
checked pin must return to after a run; `rpi_check_pin_status()` asserts it.
`rpi_board_tag()` (`RPiTest.pm:400-417`) selects one of three tables: **pi5** (RP1,
via `pi_rp1_model()`), **pi4** (model 17/19/20), else **pi3**. `alt`/funcsel
encodings: on Pi 5/RP1 `31` = null/no-peripheral, `7` = I2C, `4` = SPI, `3` = UART;
on Pi 3/4 the legacy scheme has ALT0 = `4`. `state = undef` ⇒ mode-only check (the
CS pins).

**Pins checked** (`@gpio_pins`, `RPiTest.pm:327-329`): `2 3 14 15 18 23 24 10 9 25
11 8 7 0 1 12 13 19 16 20 21 26` (pins 2/3 dropped when the OLED holds the bus —
OLED-branch list `:322-324`). **Excluded entirely** (LCD): `4 5 6 17 22 27`.

### Pi 5 / RP1 (the active dev board) — `RPiTest.pm:508-542`

{{default_states_pi5}}

### Pi 3 / Pi 4 (identical to each other) — `RPiTest.pm:438-470` / `:473-505`

Same pins; legacy encoding. Differences from the Pi 5 table: I2C (2/3) alt `4`;
UART (14/15) alt `4`; and the at-rest **state** for **4,5,6,17,22,27** is `1` and
for **23** is `0`, with all "null" pins reading alt `0` instead of `31`. CS pins
12/26 are mode-only in every table.

> On Pi 5, wiringPi cannot *set* alt 31, so once a sweep touches an alt-31-default
> pin it can't be auto-restored mid-run — reset such pins with `pinctrl` between
> full runs. (See the project test notes.)

---

## 13. Environment gating (how to actually run the suite) **[T]**

From `t/RPiTest.pm` and `t/01`:

| Var | Effect | Cite |
|-----|--------|------|
| `RPI_BOARD` | Run gate; unset (and no `SUDO_USER`) ⇒ `skip_all` | RPiTest.pm:42-45 |
| `RPI_OBJECT_COUNT` | Baseline of pre-existing registered objects in shm; **defaults to 0** | RPiTest.pm:58-63 |
| `RPI_PIN_COUNT` | Baseline of pre-existing registered pins; defaults to 0 | RPiTest.pm:64-69 |
| `RPI_SUDO` | Gate for sudo-requiring tests | RPiTest.pm:73-77 |
| `RPI_MULTI` | Gate for the multi-process tests (t/111-114) | RPiTest.pm:78-82 |
| `RPI_I2C` | Gate for I2C/ADS-dependent tests | RPiTest.pm:244-254 |

The run gate is satisfied by **either** `RPI_BOARD` **or** `SUDO_USER`
(`RPiTest.pm:42`). Beyond these, each device has its own gate — `RPI_ADC`,
`RPI_ARDUINO`, `RPI_BMP`, `RPI_DIGIPOT`, `RPI_EEPROM`, `RPI_LCD`, `RPI_MCP3008`,
`RPI_MCP4922`, `RPI_OLED`, `RPI_RTC`, `RPI_SERIAL`, `RPI_SERVO`, `RPI_SHIFTREG`,
`RPI_STEPPER` — plus the newer devices' gates: **`RPI_A4988`, `RPI_ADXL335`,
`RPI_GYRO`, `RPI_LCD_I2C`, `RPI_MCP23017`, `RPI_PCA9685`, `RPI_RADAR`,
`RPI_ST7735S`** (each with per-device pin/addr overrides, e.g. `RPI_RADAR_PIN`,
`RPI_ST7735S_DC`, `RPI_A4988_STEP`, `RPI_GYRO_ADDR`). The `RPI_BOARD_1..5`
convenience switches set `RPI_BOARD` plus that board's device gates — except
`RPI_BOARD_1`, which deliberately does **not** enable `RPI_PCA9685` (not wired to
board 1 yet, `t/440:7-16`).

All objects share `shm_key => 'rpit'` (`t/02`); the suite is serial-only. The
`RPI_OBJECT_COUNT`/`RPI_PIN_COUNT` baselines exist because `t/crontab` boots
long-running consumers (OLED on I2C, serial on GPIO14/15) that pre-register
objects/pins in the same shm segment.

---

## 14. Quick PCB build checklist (test-grounded)

- [ ] 40-pin header pass-through; route the BCM pins in §2.
- [ ] **No** external I2C pull-up pair — the Pi's built-in ~1.8 kΩ on SDA/SCL is
      enough; just check the breakouts' on-board pulls don't parallel too low
      (§10 item 1). Address straps: ADS 0x48, MCP23017 0x20 (t/355) & 0x21 (t/350
      stepper); board-1 I2C LCD 0x27 (t/335) & PCA9685 0x40 (t/440). **[T]** addresses.
- [ ] SPI fan-out (9/10/11) → MCP3008 + MCP4922 + MCP4XXXX with **bit-banged CS**
      26/12/13; hardware CE0/CE1 left free on the fabbed boards. **[T]**
- [ ] DAC out A/out B → MCP3008 CH1/CH3; 74HC595 first Q → MCP3008 CH2. **[T]**
- [ ] dpot PW0 wiper → ADS#1 A1, PW1 wiper → ADS#1 A2. **[T]** (dpot end-terminals
      to 3V3/GND ref — **[F]**.)
- [ ] GPIO18 → ADS#1 A0 only; **no pull, no load** (series R ok). **[T]**
- [ ] MCP23017 #1 (0x20): GPA(n) ↔ GPB(7-n) straight-across loopback (t/355). **[T]** (RESET→3V3 — **[F]**.)
- [ ] MCP23017 #2 (0x21): GPA0-3 → ULN2003 → 28BYJ-48 stepper; CW switch → GPIO17,
      CCW switch → GPIO27, centre LED → GPIO19. **[T]** (RESET→3V3 — **[F]**.)
- [ ] LCD (20×4, 4-bit): 4=D4, 5=RS, 6=E, 17=D5, 27=D6, 22=D7. **[T]**
- [ ] UART: GPIO14 → GPIO15 (header UART freed). **[T]**
- [ ] Leave GPIO0/1 unrouted (reserved ID-EEPROM). **[F]**
- [ ] Provide 3V3 + 5V rails + common ground; I2C level-shifter for the 5V
      Arduino. 3V3: all I2C/SPI ICs + 74HC595. 5V: LCD, stepper(+ULN2003), servo,
      Arduino. **[F]** — verify rails/parts against your hardware (§11).
- [ ] **Bench devices (not on the fabbed boards, §Scope)** — wire only when needed;
      they claim header pins the boards leave free: TFT ST7735S on CE0/GPIO8 +
      DC25/RES24/BLK23 + MOSI10/SCLK11 (t/447); radar OUT on GPIO7/CE1 (default; interim
      until an expander, `RPI_RADAR_PIN` to move it) (t/361); MPU-6050 @0x68 and ADXL335's ADS @0x48 on I2C (t/358,
      t/360); A4988 via MCP23017 @0x22 (t/353, zero header GPIO). **[T]**
