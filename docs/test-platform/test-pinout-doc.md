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
- [9. Pins NOT wired to fixtures](#9-pins-not-wired-to-fixtures-free-for-generic-tests-t)
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
   GPIO18 PWM / servo            ─►  ADS1015 #1 (0x48) A0         t/140, t/325
   MCP4XXXX dpot wiper           ─►  ADS1015 #1 (0x48) A1         t/345
   MCP4922 DAC out A (set 0,..)  ─►  MCP3008 (CS=GPIO26) CH1      t/310
   MCP4922 DAC out B (set 1,..)  ─►  MCP3008 (CS=GPIO26) CH3      t/310
   74HC595 first Q (vpin 401)    ─►  MCP3008 (CS=GPIO26) CH2      t/335
   MCP23017 #1 (0x20) GPA4-7   <─► MCP23017 #1 GPB4-7 (loopback) t/330
   MCP23017 #2 (0x21) GPA0-3 ► ULN2003 ► 28BYJ-48 stepper (drive) t/450
   28BYJ-48 sweep ─► CW switch (GPIO17) / CCW switch (GPIO27)     t/450
   UART TXD (GPIO14)             ─►  UART RXD (GPIO15)            t/315
```

Loop-back evidence (representative):
- `t/140:44,57-60` writes PWM on GPIO18, reads `$adc_in=0` on ADS @ `0x48`.
- `t/345:23,54-55` sweeps the dpot, reads channel `1` on ADS @ `0x48`.
- `t/310:24-25,58-61,76-80` writes DAC A/B, reads MCP3008 CH1/CH3.
- `t/335:39,43-64` writes shift-register output (virtual pin `401`), reads MCP3008 CH2.
- `t/330:218-231` drives MCP23017 `GPA(n)` and reads `GPB(n)=GPA(n)+8` for n=4..7.
- `t/450:215-243` steps via expander Bank A (0x21); the CW/CCW magnetic limit switches on GPIO17/27 fire edges captured by `background_interrupt` (`t/450:127,133`). Centre is computed, not sensed.
- `t/315:26-43` writes a byte/string to the serial port and reads the same back.

---

## 2. Master GPIO map (by BCM)

`Phys` = 40-pin header position. `★` = wired to a test fixture (a peripheral is
attached). "generic" = the pin is claimed/toggled as an ordinary GPIO by the
registration test (`t/110`) and/or the multi-process tests (`t/111-114`,
`t/multi/*`) — see §10. Every role here is **[T]** unless marked otherwise.

| BCM | Phys | Wired | Net / role | Proven by |
|----:|-----:|:-----:|------------|-----------|
|  2 |  3 | ★ | **I2C SDA** (shared bus) | t/305,320,330,340,420-422,450,500-520 |
|  3 |  5 | ★ | **I2C SCL** (shared bus) | (as above) |
|  4 |  7 | ★ | LCD D4 (`d0`) | t/525:36-50 |
|  5 | 29 | ★ | LCD RS (`rs`) | t/525:36-50 |
|  6 | 31 | ★ | LCD E (`strb`) | t/525:36-50 |
|  7 | 26 |   | SPI CE1 — **unused** (CS is bit-banged) | default-config alt; §5 |
|  8 | 24 |   | SPI CE0 — **unused** (CS is bit-banged) | default-config alt; §5 |
|  9 | 21 | ★ | **SPI MISO** (shared) — MCP3008 read-back only | t/310,335 [L] pin# |
| 10 | 19 | ★ | **SPI MOSI** (shared) — MCP3008/MCP4922/MCP4XXXX | t/310,335,345 [L] pin# |
| 11 | 23 | ★ | **SPI SCLK** (shared) | t/310,335,345 [L] pin# |
| 12 | 32 | ★ | MCP4922 DAC **CS** (bit-banged) (+ generic) | t/310:22,34-38; t/110, multi |
| 13 | 33 | ★ | MCP4XXXX dpot **CS** (bit-banged) | t/345:36 |
| 14 |  8 | ★ | UART TXD → GPIO15 | t/315 |
| 15 | 10 | ★ | UART RXD ← GPIO14 | t/315 |
| 16 | 36 | ★ | 74HC595 LATCH (ST_CP) (+ generic) | t/335:35; multi |
| 17 | 11 | ★ | LCD D5 (`d1`) + stepper **CW limit switch** | t/525:36-50; t/450:118 |
| 18 | 12 | ★ | **PWM/servo out + interrupt source + ADS#1 A0** (+ generic) | t/105,109,140,200-213,325,110,150,multi |
| 19 | 35 | ★ | stepper **centre LED** (computed centre) | t/450:113-114 |
| 20 | 38 | ★ | 74HC595 CLOCK (SH_CP) | t/335:35 |
| 21 | 40 | ★ | 74HC595 DATA (DS) (+ alt-mode test, generic) | t/335:35; t/107; multi |
| 22 | 15 | ★ | LCD D7 (`d3`) | t/525:36-50 |
| 23 | 16 |   | spare / generic test pin | default-config; state checks |
| 24 | 18 |   | spare / generic test pin | default-config; state checks |
| 25 | 22 |   | spare / generic test pin | default-config; state checks |
| 26 | 37 | ★ | MCP3008 ADC **CS** (bit-banged) (+ generic) | t/310,335; t/110, multi |
| 27 | 13 | ★ | LCD D6 (`d2`) + stepper **CCW limit switch** | t/525:36-50; t/450:122 |
|  0 | 27 |   | ID_SD — generic test pin | default-config (idles high) |
|  1 | 28 |   | ID_SC — generic test pin | default-config (idles high) |

> **[F]** GPIO0/1 are physically the reserved I2C0 ID-EEPROM (HAT board-ID) pins.
> The tests only treat them as generic pins that idle high; the "leave unrouted"
> guidance is hardware convention, not a test fact.

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
(`t/335:35`). Clock/data still ride hardware SPI (GPIO9/10/11) **[L]**.

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
     |         |            +-- GPA0-3 ==> ULN2003 ==> 28BYJ-48 stepper (5V)  t/450
     |         |            +-- RESET (chip pin 18) -> 3V3
     |         |
     |         +-- GPA4-7 <-> GPB4-7    (Port A<->B loopback)  t/330
     |         +-- RESET (chip pin 18) -> 3V3
     |
     +-- A0 <==== GPIO18 (PWM / servo signal, 3V3)
     +-- A1 <==== MCP4XXXX dpot wiper

   Stepper feedback is Pi GPIO, not I2C:  CW limit = GPIO17,  CCW limit = GPIO27
   (magnetic switches);  centre LED = GPIO19  (centre computed, not sensed).  t/450

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
- **`kicad/`** — one self-contained KiCad project per PCB (`legacy/` plus
  `rpi-wiringpi-unit-test-platform-board-1..4/`), each with its own
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
hardware — module-load (`t/00,02,03,05`), identification/config (`t/100,104,106,409`),
in-process metadata (`t/111`), signal/exit (`t/153,154`), sysinfo (`t/400-408`),
the OLED lock-file cleanup (`t/520`), and POD/manifest (`t/899,900,905,910,915`) —
are omitted here.

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
| `109-pwm_hw_mods.t` | ADS1015 #1 | GPIO18 (hardware PWM out) → ADS1015 #1 @0x48 A0; I2C SDA2/SCL3 |
| `110-register.t` | — (generic GPIO) | GPIO12, 18, 26 — registration/counting |
| `112-metadata_multi_pi_multi_script.t` | — (generic GPIO) | GPIO12, 16, 18, 21, 26 (via `multi/full_master.pl` + `full_slave.pl`) |
| `113-metadata_multi_pi_multi_script_die.t` | — (generic GPIO) | GPIO12, 18 (via `multi/die_master.pl` + `die_slave.pl`) |
| `114-metadata_multi_pi_multi_script_sigint.t` | — (generic GPIO) | GPIO12, 18 (via `multi/int_master.pl` + `int_slave.pl`) |
| `140-pwm_spi_adc.t` | ADS1015 #1 | GPIO18 (PWM out) → ADS1015 #1 @0x48 A0; I2C SDA2/SCL3 |
| `150-cleanup.t` | — (generic GPIO) | GPIO12, 18, 26 |
| `200-interrupt_rising_and_pud.t` … `212-pin_background_interrupt.t` (13 interrupt tests, incl. `204-last_interrupt.t`), `213-worker.t` | — (generic GPIO) | GPIO18 — self-triggered via internal pull (PUD_UP→PUD_DOWN); **no external driver/load** (§7) |
| `300-i2c_exceptions.t` | — (I2C error path) | I2C SDA2/SCL3; probes deliberately-absent addr 0x99 — no device responds |
| `305-i2c.t` | Arduino (I2C slave) | I2C SDA2/SCL3 @0x04 |
| `310-dac.t` | MCP4922 DAC, MCP3008 ADC | SPI MOSI10/SCLK11/MISO9; DAC CS=GPIO12 (bit-bang), ADC CS=GPIO26 (bit-bang); DAC out A→MCP3008 CH1, out B→CH3 |
| `315-serial.t` | — (UART loopback) | UART TXD GPIO14 → RXD GPIO15 |
| `320-rtc.t` | DS3231 RTC | I2C SDA2/SCL3 @0x68 |
| `325-servo.t` | Servo, ADS1015 #1 | GPIO18 (servo PWM) → ADS1015 #1 @0x48 A0; I2C SDA2/SCL3 |
| `330-mcp23017.t` | MCP23017 expander | I2C SDA2/SCL3 @0x20; GPA4–7 ↔ GPB4–7 loopback |
| `335-shift_reg_adc.t` | 74HC595, MCP3008 ADC | 74HC595 DATA=GPIO21, CLOCK=GPIO20, LATCH=GPIO16 (bit-bang); SPI MOSI10/SCLK11/MISO9, MCP3008 CS=GPIO26; 595 Q0→MCP3008 CH2 |
| `340-bmp.t` | BMP180 | I2C SDA2/SCL3 @0x77 |
| `345-dpot.t` | MCP4XXXX dpot, ADS1015 #1 | SPI MOSI10/SCLK11; dpot CS=GPIO13 (bit-bang); wiper → ADS1015 #1 @0x48 A1; I2C SDA2/SCL3 |
| `420-eeprom_args.t` | AT24C32 EEPROM | I2C SDA2/SCL3 @0x57 |
| `421-eeprom_read_write_byte_croak.t` | AT24C32 EEPROM | I2C SDA2/SCL3 @0x57 |
| `422-eeprom_read_write_byte.t` | AT24C32 EEPROM | I2C SDA2/SCL3 @0x57 |
| `450-stepper.t` | MCP23017 (0x21), ULN2003, 28BYJ-48 stepper | MCP23017 @0x21 GPA0–3 → ULN2003 IN1–4 → 28BYJ-48 coils; CW switch GPIO17 + CCW switch GPIO27 via `background_interrupt` (forked ISR children); centre LED GPIO19 flashed by a one-shot `worker` (fork); centre computed, not sensed; I2C SDA2/SCL3. **Also exercises the interrupt + worker concurrency machinery.** |
| `500-oled_new.t` … `509-oled_horizontal_line.t` (10 OLED tests) | OLED SSD1306 128×64 | I2C SDA2/SCL3 @0x3c |
| `525-lcd.t` | HD44780 LCD (20×4, 4-bit) | RS=GPIO5, E=GPIO6, D4=GPIO4, D5=GPIO17, D6=GPIO27, D7=GPIO22 |

---

## 4. I2C bus (GPIO2 SDA / GPIO3 SCL)

One shared 2-wire bus; each device by address. Addresses below are **[T]** when
the test passes them explicitly, **[L]** when the test relies on the submodule
default.

| Addr | Device | Tests | Source of address |
|------|--------|-------|-------------------|
| 0x04 | Arduino (I2C slave) | t/305 (‡t/300) | **[T]** `ARDUINO_ADDR` t/305:11,31 |
| 0x20 | MCP23017 #1 GPIO expander | t/330 | **[T]** `expander(0x20)` t/330:32 |
| 0x21 | MCP23017 #2 GPIO expander (stepper drive) | t/450 | **[T]** `expander(0x21)` t/450:108 |
| 0x3c | OLED SSD1306 128×64 | t/500-520 | **[T]** `oled('128x64',0x3C,0)` t/500:22 |
| 0x48 | ADS1015 ADC #1 | t/140,325,345 | **[T]** `adc(addr=>0x48)` t/140:42, t/325:77, t/345:35 |
| 0x57 | AT24C32 EEPROM | t/420-422 | **[T]** asserted default t/420:21-24 |
| 0x68 | DS3231 RTC | t/320 | **[L]** `rtc()` passes no addr; default 0x68 (DS3231.pm:13) |
| 0x77 | BMP180 pressure/temp | t/340 | **[L]** `bmp(100)` arg is a pin-base, not an addr; 0x77 from driver/datasheet |

‡ `t/300` is the I2C *exception* test: it probes a deliberately-absent address
`0x99` (t/300:26,34) to verify error handling — it does not talk to a real device.

> **[F]** Notes the tests do **not** establish:
> - The Arduino's board type. The test only uses I2C address `0x04`; "Metro Mini"
>   vs "Uno" vs a bare ATMega-328P (and an optional second unit at `0x05`) is from
>   `FAQ.pod`/README, not the tests.
> - That the EEPROM (`0x57`) and RTC (`0x68`) sit on the **same** physical
>   DS3231 ZS-042 breakout. The tests see two independent I2C addresses.
> - A **3V3↔5V I2C level-shifter** for any 5V I2C device. The tests run the bus at
>   the Pi's native 3V3 and never reveal a shifter; it's a board-design assumption.

```
            +3V3 ── pull-ups ──┐     ┌──────┬──────┬──────┬──── ... (all I2C devices)
 GPIO2 (SDA) ──────────────────┴─SDA─┤      │      │      │
 GPIO3 (SCL) ───────────────────SCL──┤ 0x20 │ 0x21 │ 0x48 │ 0x68 0x77 0x57 0x3c 0x04
                                    MCP#1   MCP#2  ADS#1  RTC  BMP  EEPROM OLED Ardu
```

**One ADS1015 ADC [T].** `0x48` carries the two analog read-backs the suite needs
— PWM/servo on A0 (`t/140,325`) and the dpot wiper on A1 (`t/345`). The stepper no
longer uses an ADC: its limits are magnetic switches on Pi GPIO17/27 and centre is
computed (§8).

**Two MCP23017 expanders [T].** `0x20` is the loopback chip (`t/330`); `0x21` is a
separate expander that drives the stepper coils (`t/450:108`).

### 4.1 MCP23017 expanders — pin allocation **[T]**

Two **separate** MCP23017s, one per job — `t/330`'s loopback chip at `0x20` and
the stepper's drive chip at `0x21`:

```
  #2 @0x21:  GPA0..GPA3  ─► ULN2003 IN1..IN4 ─► 28BYJ-48 coils   (t/450; drive)
  #1 @0x20:  GPA4..GPA7 <-> GPB4..GPB7                           (t/330 loopback)
```

`t/330` writes `GPA(n)` and reads `GPB(n) = GPA(n)+8` for **n = 4,5,6,7** only,
bidirectionally on the **0x20** chip (`t/330:218-231,254-267`). `t/450` drives
`pins => [A0,A1,A2,A3]` = **GPA0-3** on the **0x21** chip (`t/450:108,215-216`);
the `expander => $exp` path means the StepperMotor driver writes via I2C, not Pi
GPIO — `StepperMotor.pm:159-163`.

> **[F]** The MCP23017 RESET (chip pin 18) tie-high to 3V3 is standard practice;
> the tests don't touch it.

---

## 5. SPI bus (GPIO9 MISO / GPIO10 MOSI / GPIO11 SCLK)

Clock and data ride **hardware SPI0** (GPIO9/10/11) **[L]**. Each device's
**chip-select is a bit-banged GPIO** — decoded from the constructor args via the
submodules **[T]**:

- **MCP3008** `adc(model=>'MCP3008', channel=>26)` — the single arg is the SPI
  *bus channel* only when it is 0/1; when **> 1 it is a GPIO used as CS** by the
  driver (`MCP3008.pm:30-32`). So `26` ⇒ **CS = BCM 26** (`t/310:40-43`,
  `t/335:21,35`). MCP3008 is the only SPI device that uses **MISO**.
- **MCP4922 DAC** `dac(model=>'MCP4922', channel=>0, cs=>12)` — `channel`=SPI bus
  0, **CS = BCM 12** (`MCP4922.pm:36-37`; `t/310:22,34-38`). Write-only (no MISO).
- **MCP4XXXX dpot** `dpot(13, 0)` — arg1 = **CS = BCM 13**, arg2 = SPI bus 0
  (`MCP4XXXX.pm:16,19`; `t/345:36`). Write-only (no MISO).

The hardware CE0/CE1 (GPIO8/7) stay free. All three SPI devices are powered at
3V3 **[F]** (so the DAC/dpot/ADC analog range matches the Pi's 3V3 levels).

| Device | CS (BCM, bit-banged) | MOSI | SCLK | MISO | Tests | Output read back by |
|--------|---------------------:|------|------|------|-------|---------------------|
| MCP3008 ADC | **26** | 10 | 11 | 9 | t/310,335 | (it is the reader) |
| MCP4922 DAC | **12** | 10 | 11 | — | t/310 | out A→MCP3008 CH1, out B→MCP3008 CH3 |
| MCP4XXXX pot| **13** | 10 | 11 | — | t/345 | wiper→ADS1015 #1 A1 |

```
 GPIO10 MOSI ─┬──────────┬───────────┐
 GPIO11 SCLK ─┼────┬─────┼─────┬─────┤
 GPIO9  MISO ─┘    │     │     │     │
   CS GPIO26 ──► MCP3008 │     │
   CS GPIO12 ──────────► MCP4922
   CS GPIO13 ──────────────────────► MCP4XXXX
```

**MCP3008 channel map [T]:** CH1 ← DAC out A (`t/310:24`), CH2 ← 74HC595 first Q
(`t/335`), CH3 ← DAC out B (`t/310:25`).

> The dpot in tests is the **MCP4XXXX** family (`rpi-digipot-mcp4xxxx`); the
> existing schematic models it as the specific part **MCP42010** **[F]**.

---

## 6. LCD — HD44780, 4-bit mode (`t/525`) **[T]**

`lcd(... cols=>20, rows=>4, bits=>4, d4..d7=>0 ...)` (`t/525:36-50`) ⇒ a **20×4**
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
LCD" (`RPiTest.pm:204`) — they are reserved for the display and not asserted as
generic pins.

> **Shared with the stepper:** GPIO17 (D5) and GPIO27 (D6) also serve as the
> stepper's CW/CCW magnetic limit switches in `t/450` (§8). The two tests never run
> at once (serial suite), but it is a shared physical net — see §10.

> **[F]** The logical `d0..d3` → physical DB4..DB7 mapping is the standard HD44780
> 4-bit convention; the test proves logical wiring + 4-bit mode, not silkscreen
> pin numbers. R/W tied to GND (write-only) is also convention.

---

## 7. GPIO18 — the multiplexed workhorse pin (physical pin 12)

One physical net wired to **ADS1015 #1 channel A0**, reused across many tests:

| Mode | Tests | Dir | How |
|------|-------|-----|-----|
| Hardware PWM out | t/109, t/140 | OUT | sweeps duty; ADS #1 A0 reads voltage (`t/140:44,57-60`) |
| Servo PWM out | t/325 | OUT | servo pulse; ADS #1 A0 reads position (`t/325:79,89`) |
| Edge interrupt source | t/200-212 | IN | **self-triggered** by toggling the *internal* pull resistor (`pull(PUD_UP)`→`pull(PUD_DOWN)`) — no external edge driver (`t/200:39-44`) |
| Plain pin / register / worker | t/105,110,150,213,multi | IN/OUT | read/write + metadata registration |

**PCB constraint [T] (load-bearing).** The interrupt tests swing the line using
only the Pi's *internal* ~50 kΩ pull (`pull()` → `pullUpDnControl`, `RPi/Pin.pm:75-85`).
The tests say so directly: "wire nothing to BCM18" (`t/213:120`), "self-triggered
pin" (`t/210:114`). Therefore the GPIO18 net must carry **no external pull
resistor and no low-impedance load** — only the high-Z ADS1015 A0 input may hang
off it (a series resistor to A0 is fine; a pull resistor would break the interrupt
tests). Debounce is 0 throughout (`t/210:37`), so the net must also be kept short
/ low-capacitance to settle inside the ~20 ms edge pacing. The pin's at-rest
default is INPUT (`get_alt(18)==0`, `t/213:151`).

---

## 8. Shift register & stepper (indirect drives)

**74HC595 (`t/335`) — fully bit-banged GPIO [T].** `shift_register(400, 8, 21, 20, 16)`
(`t/335:35`) decodes (via `WiringPi.pm:334`) to base=400, 8 outputs,
**DATA=BCM21, CLOCK=BCM20, LATCH=BCM16**:

| Pi BCM | 74HC595 | Library arg position |
|-------:|---------|----------------------|
| 21 | DS (pin 14)    | data  |
| 20 | SH_CP (pin 11) | clock |
| 16 | ST_CP (pin 12) | latch |

The first Q-output is exposed as virtual pin **401**; writing it HIGH/LOW is read
back on **MCP3008 CH2** (`t/335:39,43-64`). Virtual pins 400-407 are not Pi GPIO.

**Stepper (`t/450`) — coils via I2C expander, limits on Pi GPIO [T].** Coils are
driven through a ULN2003 by **MCP23017 #2 (0x21)** Bank A pins 0-3 (§4.1), so they
use no direct Pi GPIO. Travel is bounded by **two magnetic limit switches** read
directly on the Pi: **CW on GPIO17** (`t/450:118`) and **CCW on GPIO27**
(`t/450:122`), each armed as a rising-edge `background_interrupt` (`t/450:127,133`).
**Centre is computed, not sensed** — symmetric tick counts return the motor to
mid-travel — and shown on a **centre LED on GPIO19** (`t/450:113`), pulsed by a
one-shot fork **`worker`** so the LED hold never stalls the sweep. So beyond the
expander drive, the test concurrently exercises both the `background_interrupt`
(ISR) and `worker` (fork) subsystems. The test
sweeps ccw/cw across several speed/delay configs and asserts each limit edge fires
within its expected time window (`t/450:215-243`).

**Per-config timing map (`t/450`) [T].** Each pass sweeps one `speed/delay` config
and asserts both magnet edges trip within **±5%** of these measured means
(out-sweep start → magnet); `%EXPECT` in the test holds the same numbers:

| Pass | speed / delay | ccw edge | cw edge  |
|-----:|---------------|---------:|---------:|
| 1, 2 | full / 0.00   | 2088 ms  | 2048 ms  |
| 3    | full / 0.01   | 8926 ms  | 8604 ms  |
| 4    | half / 0.01   | 17816 ms | 17176 ms |
| 5    | half / 0.00   | 4170 ms  | 4028 ms  |

---

## 9. Pins NOT wired to fixtures (free for generic tests) **[T]**

Exercised only for default-mode/state, registration counting and alt-mode round
trips — no peripheral attached; candidates for break-out test points:

- **GPIO23, 24, 25** — fully spare (appear only in the default-state table).
  GPIO19 is now the stepper **centre LED** (§8).
- **GPIO7 (CE1), GPIO8 (CE0)** — at SPI-alt default; unused because CS is
  bit-banged on 26/12/13.
- **GPIO21** — also the alt-mode round-trip pin in `t/107` (loops ALT0–ALT7), in
  addition to its 74HC595 DATA duty.
- **GPIO0 / GPIO1** (phys 27/28) — used as generic test pins; idle high. **[F]**
  reserved I2C0 ID-EEPROM pins — best left unrouted on a real board.

---

## 10. Collisions & shared-net warnings

> Software-wise nothing conflicts — tests run **serially** and each cleans up
> (`RPiTest.pm:3-7`). The items below are physical-net decisions for the PCB.

1. **Shared I2C bus (GPIO2/3) [T] — provide no external pull-up pair [F].** Eight
   addresses share the bus. The Pi already provides ~1.8 kΩ pull-ups on SDA/SCL to
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
   the 5V Arduino adds its own ~10 kΩ pulls on the Pi side. Strap the ADS1015
   to 0x48 and the two MCP23017s to 0x20 (t/330) and 0x21 (stepper).
2. **Shared SPI bus (GPIO9/10/11) [T]** — three devices, one active CS at a time
   (26/12/13). Write-only DAC/dpot must not drive MISO.
3. **GPIO18 over-subscribed [T]** — PWM + servo + interrupt + generic + ADS#1 A0
   on one wire. Honour the "no external pull / no load" rule of §7.
4. **Device-control pins doubling as generic GPIO [T]** — `t/110` and the
   multi-process tests register/toggle **GPIO12, 16, 18, 21, 26** as plain pins
   (`t/110:22-24`; `full_slave.pl:13-20`; `full_master.pl:28`). On the board these
   are live control lines (DAC CS, SR LATCH, PWM/ADS, SR DATA, ADC CS); toggling
   them while the device is idle is harmless but real.
5. **CS lines excluded from state checks [T]** — `rpi_default_pin_config` marks
   **GPIO12 and GPIO26** as *mode-only* (state `undef`): "level depends on the
   attached device's pull state" (`RPiTest.pm:338-340`). Don't add pulls that
   fight the idle level.
6. **GPIO13 comment vs asserted state — discrepancy [T].** The harness comments
   GPIO13 as "OUTPUT/HIGH due to the dpot test (t/345)" yet its expected resting
   `state` is **0** in all three board tables. Flagged as an inconsistency in the
   harness, not resolved by the tests.
7. **Serial vs Bluetooth [F/L]** — the UART loopback (GPIO14→15) needs the primary
   header UART. `rpi_serial_device()` returns `/dev/ttyAMA0` on Pi 5 (RP1) and
   `/dev/ttyS0` on Pi 3/4 (`RPiTest.pm:310-318`). On Pi 5 the header UART is its
   own PL011 (no `disable-bt` overlay needed); on Pi 3/4 freeing it from Bluetooth
   is the classic step. With UART enabled, GPIO14/15 report funcsel and idle high.
8. **OLED locks the I2C bus [T]** — if `/dev/shm/oled_in_use` exists (an external
   OLED daemon, started by `t/crontab`), `rpi_check_pin_status` **drops pins 2 and
   3** from the check (`RPiTest.pm:206-210`).
9. **Mixed rails (3V3 / 5V) [F]** — not determinable from the tests. The existing
   design runs all Pi logic + I2C/SPI ICs + 74HC595 at 3V3, and the LCD, stepper
   (via ULN2003), servo and Arduino at 5V, with a level-shifter for the 5V I2C.
   Verify against your actual parts. Full per-rail device lists and the current
   budget are in §11.
10. **GPIO17/27 shared — LCD vs stepper limits [T].** GPIO17 (LCD D5) and GPIO27
   (LCD D6) also read the stepper's CW/CCW magnetic limit switches (`t/450`).
   `t/525` drives them as LCD outputs; `t/450` reads them as switch inputs. The
   serial suite keeps them apart in software, but they are one shared net on the
   board — don't add a pull/load that fights either role. GPIO19 (stepper centre
   LED) is dedicated.

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
| MCP23017 #1 expander  | I2C 0x20     | VDD           | t/330 loopback; RESET tied 3V3     |
| MCP23017 #2 expander  | I2C 0x21     | VDD           | t/450 stepper drive; RESET tied 3V3|
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
| HD44780 LCD             | display (`t/525`) | VDD + backlight | logic inputs (RS/E/D4-7) are 3V3   |
| 28BYJ-48 stepper        | via ULN2003       | motor V+        | coils, `t/450`                     |
| ULN2003 driver          | stepper driver    | COM / VCC       | driven by MCP23017 #2 (0x21) GPA0-3|
| Servo                   | on GPIO18 PWM     | V+              | signal 3V3, power 5V               |
| Arduino                 | I2C 0x04          | VIN / 5V        | joins bus via level-shifter        |
| ATMega-328P (standalone)| I2C 0x05          | VCC             | optional; only in I2C mode         |

Other 5V connections:

- **Level-shifter HV side** — high-voltage reference = 5V.

### 11.3 Current budget (estimate)

> Datasheet-typical figures, **not measured** — confirm against your parts before
> sizing traces/connectors. The suite runs tests **sequentially** (§10), so the
> stepper (`t/450`) and servo (`t/325`) never draw at the same instant; the
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
| HD44780 logic | t/525 | 1.5 | 2 | |
| HD44780 backlight | t/525 | 25 | 120 | depends on series R / jumper |
| 28BYJ-48 stepper (via ULN2003) | t/450 | 160 | 240 | 2-phase → all-coil energized |
| ULN2003 | — | 0.5 | 1 | own draw; motor current counted above |
| Servo SG90 | t/325 | 10 idle / 250 run | 700 | stall is the big spike |
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

`rpi_default_pin_config()` is the at-rest mode/state every checked pin must return
to after a run; `rpi_check_pin_status()` asserts it. `rpi_board_tag()` selects one
of three tables (`RPiTest.pm:293-310`): **pi5** (RP1, via `pi_rp1_model()`),
**pi4** (model 17/19/20), else **pi3**. `alt`/funcsel encodings: on Pi 5/RP1
`31` = null/no-peripheral, `7` = I2C, `4` = SPI, `3` = UART; on Pi 3/4 the legacy
scheme has ALT0 = `4`. `state = undef` ⇒ mode-only check (the CS pins).

**Pins checked** (`@gpio_pins`, `RPiTest.pm:214-223`): `2 3 14 15 18 23 24 10 9 25
11 8 7 0 1 12 13 19 16 20 21 26` (pins 2/3 dropped when the OLED holds the bus).
**Excluded entirely** (LCD): `4 5 6 17 22 27`.

### Pi 5 / RP1 (the active dev board) — `RPiTest.pm:395-429`

| BCM | alt | state | | BCM | alt | state | | BCM | alt | state |
|----:|----:|------:| |----:|----:|------:| |----:|----:|------:|
| 0 | 0 | 1 | | 10 | 4 | 0 | | 20 | 31 | 0 |
| 1 | 0 | 1 | | 11 | 4 | 0 | | 21 | 31 | 0 |
| 2 | 7 | 1 | | 12 | 31 | *undef* | | 22 | 1 | 0 |
| 3 | 7 | 1 | | 13 | 31 | 0 | | 23 | 31 | 0 |
| 4 | 31 | 0 | | 14 | 3 | 1 | | 24 | 31 | 0 |
| 5 | 31 | 0 | | 15 | 3 | 1 | | 25 | 31 | 0 |
| 6 | 31 | 0 | | 16 | 31 | 0 | | 26 | 31 | *undef* |
| 7 | 1 | 1 | | 17 | 1 | 0 | | 27 | 1 | 0 |
| 8 | 1 | 1 | | 18 | 31 | 0 | |   |   |   |
| 9 | 4 | 0 | | 19 | 31 | 0 | |   |   |   |

### Pi 3 / Pi 4 (identical to each other) — `RPiTest.pm:325-392`

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
| `RPI_BOARD` | Run gate; unset ⇒ `skip_all` | RPiTest.pm:40-43 |
| `RPI_OBJECT_COUNT` | Baseline of pre-existing registered objects in shm; **defaults to 0** | RPiTest.pm:56-61 |
| `RPI_PIN_COUNT` | Baseline of pre-existing registered pins; defaults to 0 | RPiTest.pm:62-67 |
| `RPI_SUDO` | Gate for sudo-requiring tests | RPiTest.pm:71-75 |
| `RPI_MULTI` | Gate for the multi-process tests (t/111-114) | RPiTest.pm:76-80 |
| `RPI_I2C` | Gate for I2C/ADS-dependent tests | RPiTest.pm:137-147 |

All objects share `shm_key => 'rpit'` (`t/02`); the suite is serial-only. The
`RPI_OBJECT_COUNT`/`RPI_PIN_COUNT` baselines exist because `t/crontab` boots
long-running consumers (OLED on I2C, serial on GPIO14/15) that pre-register
objects/pins in the same shm segment.

---

## 14. Quick PCB build checklist (test-grounded)

- [ ] 40-pin header pass-through; route the BCM pins in §2.
- [ ] **No** external I2C pull-up pair — the Pi's built-in ~1.8 kΩ on SDA/SCL is
      enough; just check the breakouts' on-board pulls don't parallel too low
      (§10 item 1). Address straps: ADS1015 0x48, MCP23017 0x20 (t/330) & 0x21 (t/450 stepper). **[T]** addresses.
- [ ] SPI fan-out (9/10/11) → MCP3008 + MCP4922 + MCP4XXXX with **bit-banged CS**
      26/12/13; hardware CE0/CE1 left free. **[T]**
- [ ] DAC out A/out B → MCP3008 CH1/CH3; 74HC595 first Q → MCP3008 CH2. **[T]**
- [ ] dpot wiper → ADS#1 A1. **[T]** (dpot end-terminals to 3V3/GND ref — **[F]**.)
- [ ] GPIO18 → ADS#1 A0 only; **no pull, no load** (series R ok). **[T]**
- [ ] MCP23017 #1 (0x20): GPA4-7 ↔ GPB4-7 loopback (t/330). **[T]** (RESET→3V3 — **[F]**.)
- [ ] MCP23017 #2 (0x21): GPA0-3 → ULN2003 → 28BYJ-48 stepper; CW switch → GPIO17,
      CCW switch → GPIO27, centre LED → GPIO19. **[T]** (RESET→3V3 — **[F]**.)
- [ ] LCD (20×4, 4-bit): 4=D4, 5=RS, 6=E, 17=D5, 27=D6, 22=D7. **[T]**
- [ ] UART: GPIO14 → GPIO15 (header UART freed). **[T]**
- [ ] Leave GPIO0/1 unrouted (reserved ID-EEPROM). **[F]**
- [ ] Provide 3V3 + 5V rails + common ground; I2C level-shifter for the 5V
      Arduino. 3V3: all I2C/SPI ICs + 74HC595. 5V: LCD, stepper(+ULN2003), servo,
      Arduino. **[F]** — verify rails/parts against your hardware (§11).
