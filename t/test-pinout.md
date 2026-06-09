# RPi::WiringPi — Unit-Test Hardware Pinout

Baseline wiring reference for designing a unit-test PCB/HAT.

Sources reconciled: `t/README`, every `t/*.t` and `t/multi/*.pl`, `t/RPiTest.pm`
(`rpi_default_pin_config`, `rpi_check_pin_status`), and `lib/RPi/WiringPi.pm` +
`lib/RPi/WiringPi/FAQ.pod`. Where the README was incomplete or ambiguous, the
test code is treated as authoritative.

All pin numbers below are **BCM GPIO** unless they say "physical pin" (40-pin
header position) or "chip pin" (a peripheral IC's own pin).

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
   Stepper coils ─► photoresistors L/C/R ─► ADS1115 #2 (0x49) A2/A1/A0
   MCP23017 Port A (GPA0-7)    ─►  MCP23017 Port B (GPB0-7)   [direct loopback]
   UART TXD (GPIO14)           ─►  UART RXD (GPIO15)          [direct loopback]
```

---

## 2. Master GPIO map (by BCM)

`Phys` = 40-pin header position. `★` = physically wired to a test fixture.
"generic/multi" = the pin is *also* claimed/toggled by the registration test
(`t/110`) and/or the multi-process tests (`t/111-114`, `t/multi/*`) as an
ordinary GPIO — see §7.

| BCM | Phys | Wired | Net / role                         | Device                         | Tests |
|----:|-----:|:-----:|------------------------------------|--------------------------------|-------|
|   2 |  3   | ★ | **I2C SDA** (shared bus)              | all I2C devices                | 305,320,330,340,420-422,900-920,450 |
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
|   0 | 27   |   | ID_SD — generic test pin *(see §8)*   | (HAT ID EEPROM reserved)       | (state checks) |
|   1 | 28   |   | ID_SC — generic test pin *(see §8)*   | (HAT ID EEPROM reserved)       | (state checks) |

---

### 2.1 Board layout sketch

Top-down floorplan. Devices cluster by bus off two rails (I2C and SPI) that
run from the Pi header. Dashed arrows are the analog/digital **loop-backs** from
§1 (drive on one side, measure on the other).

```
            +-----------------------------------------------------------------+
            |  Raspberry Pi 40-pin header                                     |
            |  3V3  GND   SDA2 SCL3   SPI: MOSI10 MISO9 SCLK11                |
            +--+----+------+----+-----------+-----+------+--------------------+
               |    |      |    |           |     |      |
   +-----------+    |   I2C RAIL (SDA/SCL, one pull-up pair)                  |
   | 3V3 / GND |    |  ===+======+======+======+======+======+======+===     |
   | rails to  |    |     |      |      |      |      |      |      |          |
   | all parts |    |   [ADS#1] [ADS#2] [MCP23017#1] [MCP23017#2] [RTC+EEPROM]|
   +-----------+    |    0x48   0x49     0x20         0x21        0x68/0x57   |
                    |     | |    |||                   |             |        |
                    |     | |    |||              [BMP180 0x77]  [OLED 0x3c] [Arduino 0x04]
                    |     | |    |||
                    |     | |    ||+--- A0 <--- photoR (R) -+
                    |     | |    |+---- A1 <--- photoR (C) --+--[stepper rig]
                    |     | |    +----- A2 <--- photoR (L) -+        ^
                    |     | |                                        | coils 0-3
                    |     | +--- A1 <==== MCP4XXXX dpot wiper        | (via ULN2003)
                    |     +----- A0 <==== GPIO18 (PWM/servo) <-------(MCP23017#2 Bank A)
                    |
   SPI RAIL (MOSI10/SCLK11/MISO9) ===+=========+=========+===
                                     |         |         |
                                CS26[MCP3008] CS12[MCP4922] CS13[MCP4XXXX]
                                     ^  ^  ^      | |          |
                                CH1__|  |  |______| |(out0)    |
                                CH3_____|  |________|  (out1)  |(write-only,
                                CH2________|                    | wiper-> ADS#1 A1)
                                   ^
                                   +==== 74HC595 Q-outputs
                                          DATA21  CLK20  LATCH16  (from Pi)

   LCD (HD44780, 4-bit, dedicated pins):  RS5  E6  D4=4  D5=17  D6=27  D7=22
   UART loopback:  GPIO14 (TXD) ------> GPIO15 (RXD)
   MCP23017#1 internal loopback:  GPA0-7 -> GPB0-7 ;  RESET(chip pin18) -> 3V3
```

Legend: `<==`/`==>` analog loop-back, `<--`/`-->` signal/sense wire,
`===` a shared bus rail.

## 3. I2C bus (GPIO2 SDA / GPIO3 SCL)

One shared 2-wire bus; every device distinguished by address. Addresses are the
authoritative list from FAQ.pod "I2C Test Platform Connections":

| Addr | Device                    | Tests        | Notes |
|------|---------------------------|--------------|-------|
| 0x04 | Arduino Metro Mini        | 300, 305     | I2C slave sketch in `docs/sketch` |
| 0x05 | ATMega-328P (standalone)  | —            | only when in I2C mode (optional) |
| 0x20 | MCP23017 GPIO expander #1 | 330          | Port A ↔ Port B loopback |
| 0x21 | MCP23017 GPIO expander #2 | 450          | drives stepper coils (Bank A 0-3) |
| 0x3c | OLED SSD1306 128×64       | 900-920      | on the Pi I2C bus |
| 0x48 | ADS1115 ADC #1            | 109,140,325,345 | A0=PWM/servo, A1=dpot wiper |
| 0x49 | ADS1115 ADC #2            | 450          | A0/A1/A2 = stepper photoresistors R/C/L |
| 0x57 | AT24C32 EEPROM            | 420-422      | same breakout board as the RTC |
| 0x68 | DS3231 RTC                | 320          | |
| 0x77 | BMP180 pressure/temp      | 340          | |

```
            +3V3 ── pull-ups ──┐         ┌──────────┬──────────┬─────── ... (all I2C devices)
 GPIO2 (SDA) ──────────────────┴── SDA ──┤          │          │
 GPIO3 (SCL) ───────────────────── SCL ──┤ 0x20/21  │ 0x48/49  │ 0x68 0x77 0x57 0x3c 0x04
                                          MCP23017   ADS1115     RTC  BMP  EEPROM OLED Arduino
```

Note: two of each ADC and expander type are present (0x48/0x49, 0x20/0x21) — the
PCB needs the address-select straps wired accordingly.

### MCP23017 internal loopback (both units)
`t/330` writes Port A and reads Port B, so on the board:

```
  GPA0..GPA7  ─►  GPB0..GPB7      (eight straight wires, A→B)
  3V3         ─►  chip pin 18 (RESET, active-low: tie HIGH)   ← NOT a Pi GPIO
```

---

## 4. SPI bus (GPIO9 MISO / GPIO10 MOSI / GPIO11 SCLK)

Three devices share MOSI+SCLK; only the MCP3008 uses MISO (the DAC and dpot are
write-only). Each device has its own **GPIO** chip-select — the hardware CE0/CE1
(GPIO8/7) are **not** used.

| Device      | CS (BCM) | MOSI | SCLK | MISO | Tests | Output goes to |
|-------------|---------:|------|------|------|-------|----------------|
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

**74HC595 (`t/335`)** — serial-in/parallel-out, outputs read back via MCP3008:

| Pi BCM | 74HC595 | Library arg (`shift_register(400,8,21,20,16)`) |
|-------:|---------|------------------------------------------------|
| 21     | DS (14)   | data  |
| 20     | SH_CP (11)| clock |
| 16     | ST_CP (12)| latch |

Q-outputs feed MCP3008 (e.g. first output → MCP3008 CH2). Library pin-base
400-407 are *virtual* (not Pi GPIO).

**Stepper (`t/450`)** — uses **no direct Pi GPIO**. Coils are driven by MCP23017
#2 (0x21) Bank A pins 0-3; position is sensed by three photoresistors into
ADS1115 #2 (0x49) channels 0/1/2.

---

## 8. Pins NOT wired to fixtures (free for generic tests)

These are exercised only for default mode/state, registration counting and
interrupt-count baselines — they have no peripheral attached and are candidates
for break-out test points on the PCB:

- **GPIO19, 23, 24, 25** — fully spare.
- **GPIO7 (CE1), GPIO8 (CE0)** — at SPI-alt default; unused because CS is
  bit-banged on 26/12/13. Spare unless you switch to hardware CE.
- **GPIO0 / GPIO1** (physical 27/28, ID_SD/ID_SC) — used as generic test pins,
  **but** these are the HAT ID-EEPROM pins. If this becomes a HAT, leave them
  for the ID EEPROM and don't route test fixtures to them.

---

## 9. Collisions & shared-net warnings

> Software-wise nothing conflicts — tests run sequentially and each cleans up.
> The items below are the **physical-net decisions** the PCB must make.

1. **Shared I2C bus (GPIO2/3)** — 8+ devices, intended. Provide one set of
   bus pull-ups (do **not** stack a pull-up per device). Two ADS1115 (0x48/0x49)
   and two MCP23017 (0x20/0x21): wire their address-select pins for the
   distinct addresses.

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
   UART on the header (`/dev/ttyS0`), i.e. Bluetooth moved off the GPIO UART
   (`dtoverlay=disable-bt` / mini-UART config). Pi-5 specifics differ from the
   FAQ's Pi-3 note — verify on target.

---

## 10. Pi 5 (RP1) expected default pin states

From `rpi_default_pin_config()` — the at-rest mode/state every wired pin must
return to after a test run (used to detect a dirty board). Alt `31` = RP1
"null / no peripheral function"; alt `0` = GPIO input.

| BCM | alt | state | | BCM | alt | state | | BCM | alt | state |
|----:|----:|------:|-|----:|----:|------:|-|----:|----:|------:|
| 0  | 0  | 1 | | 11 | 0  | 0 | | 22 | 1  | 0 |
| 1  | 0  | 1 | | 13 | 31 | 0 | | 23 | 1  | 0 |
| 2  | 0  | 1 | | 14 | 31 | 0 | | 24 | 31 | 0 |
| 3  | 0  | 1 | | 15 | 31 | 0 | | 25 | 31 | 0 |
| 4  | 31 | 0 | | 16 | 31 | 0 | | 27 | 1  | 0 |
| 5  | 31 | 0 | | 17 | 1  | 0 | |    |    |   |
| 6  | 31 | 0 | | 18 | 0  | 0 | | **12** | excluded (CS flip) |
| 7  | 1  | 1 | | 19 | 31 | 0 | | **26** | excluded (CS flip) |
| 8  | 1  | 1 | | 20 | 31 | 0 | |        |    |   |
| 9  | 0  | 0 | | 21 | 31 | 0 | |        |    |   |
| 10 | 0  | 0 | |    |    |   | |        |    |   |

> On Pi 5, wiringPi cannot *set* alt 31, so once a sweep touches an alt-31-default
> pin it can't be auto-restored mid-run — reset such pins with `pinctrl` between
> full runs. (See the project test notes.)

---

## 11. Quick PCB build checklist

- [ ] 40-pin header pass-through; route only the BCM pins in §2.
- [ ] One I2C pull-up pair on SDA/SCL; address straps for 0x20/0x21 and 0x48/0x49.
- [ ] SPI fan-out (9/10/11) to MCP3008 + MCP4922 + MCP4XXXX with CS 26/12/13.
- [ ] DAC out0/out1 → MCP3008 CH1/CH3; 74HC595 Q → MCP3008 CH2.
- [ ] dpot wiper → ADS#1 A1; dpot end-terminals to 3V3 / GND reference.
- [ ] GPIO18 → ADS#1 A0 only (series R ok; **no pull, no load**).
- [ ] MCP23017 #1: GPA0-7 → GPB0-7; RESET (chip pin 18) → 3V3.
- [ ] MCP23017 #2 (0x21): Bank-A 0-3 → ULN2003 → stepper; photoresistors → ADS#2 A0-2.
- [ ] LCD: 4=D4,5=RS,6=E,17=D5,27=D6,22=D7.
- [ ] UART: GPIO14 → GPIO15 (with the primary UART freed from Bluetooth).
- [ ] Leave GPIO0/1 (ID_SD/ID_SC) for HAT ID EEPROM if making a HAT.
- [ ] Common ground; 3V3 logic throughout.
