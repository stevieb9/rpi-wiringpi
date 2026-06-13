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

## 1. Design philosophy: everything loops back **[T]**

The platform is self-verifying: every *output* the library can drive is wired
back into an *input* it can read, so a test asserts that what it drove is what it
measured. This is the load-bearing property of the board — it is visible directly
in the tests, which write a value and then read it back to compare.

```
   Pi / device drives  ───────────────►  read back by            Proven in
   --------------------------------------------------------------------------
   GPIO18 PWM / servo            ─►  ADS1115 #1 (0x48) A0         t/140, t/325
   MCP4XXXX dpot wiper           ─►  ADS1115 #1 (0x48) A1         t/345
   MCP4922 DAC out A (set 0,..)  ─►  MCP3008 (CS=GPIO26) CH1      t/310
   MCP4922 DAC out B (set 1,..)  ─►  MCP3008 (CS=GPIO26) CH3      t/310
   74HC595 first Q (vpin 401)    ─►  MCP3008 (CS=GPIO26) CH2      t/335
   MCP23017 GPA4-7              <─►  MCP23017 GPB4-7  (loopback)  t/330
   MCP23017 GPA0-3 ► ULN2003 ► 28BYJ-48 stepper (drive)          t/450
   stepper position (3 sensors)  ─►  ADS1115 #2 (0x49) A0/A1/A2   t/450
   UART TXD (GPIO14)             ─►  UART RXD (GPIO15)            t/315
```

Loop-back evidence (representative):
- `t/140:44,57-60` writes PWM on GPIO18, reads `$adc_in=0` on ADS @ `0x48`.
- `t/345:23,54-55` sweeps the dpot, reads channel `1` on ADS @ `0x48`.
- `t/310:24-25,58-61,76-80` writes DAC A/B, reads MCP3008 CH1/CH3.
- `t/335:39,43-64` writes shift-register output (virtual pin `401`), reads MCP3008 CH2.
- `t/330:218-231` drives MCP23017 `GPA(n)` and reads `GPB(n)=GPA(n)+8` for n=4..7.
- `t/450:27-35` steps via expander Bank A and reads three ADS @ `0x49` channels.
- `t/315:26-43` writes a byte/string to the serial port and reads the same back.

---

## 2. Master GPIO map (by BCM)

`Phys` = 40-pin header position. `★` = wired to a test fixture (a peripheral is
attached). "generic" = the pin is claimed/toggled as an ordinary GPIO by the
registration test (`t/110`) and/or the multi-process tests (`t/111-114`,
`t/multi/*`) — see §9. Every role here is **[T]** unless marked otherwise.

| BCM | Phys | Wired | Net / role | Proven by |
|----:|-----:|:-----:|------------|-----------|
|  2 |  3 | ★ | **I2C SDA** (shared bus) | t/305,320,330,340,420-422,450,500-520 |
|  3 |  5 | ★ | **I2C SCL** (shared bus) | (as above) |
|  4 |  7 | ★ | LCD D4 (`d0`) | t/525:36-50 |
|  5 | 29 | ★ | LCD RS (`rs`) | t/525:36-50 |
|  6 | 31 | ★ | LCD E (`strb`) | t/525:36-50 |
|  7 | 26 |   | SPI CE1 — **unused** (CS is bit-banged) | default-config alt; §4 |
|  8 | 24 |   | SPI CE0 — **unused** (CS is bit-banged) | default-config alt; §4 |
|  9 | 21 | ★ | **SPI MISO** (shared) — MCP3008 read-back only | t/310,335 [L] pin# |
| 10 | 19 | ★ | **SPI MOSI** (shared) — MCP3008/MCP4922/MCP4XXXX | t/310,335,345 [L] pin# |
| 11 | 23 | ★ | **SPI SCLK** (shared) | t/310,335,345 [L] pin# |
| 12 | 32 | ★ | MCP4922 DAC **CS** (bit-banged) (+ generic) | t/310:22,34-38; t/110, multi |
| 13 | 33 | ★ | MCP4XXXX dpot **CS** (bit-banged) | t/345:36 |
| 14 |  8 | ★ | UART TXD → GPIO15 | t/315 |
| 15 | 10 | ★ | UART RXD ← GPIO14 | t/315 |
| 16 | 36 | ★ | 74HC595 LATCH (ST_CP) (+ generic) | t/335:35; multi |
| 17 | 11 | ★ | LCD D5 (`d1`) | t/525:36-50 |
| 18 | 12 | ★ | **PWM/servo out + interrupt source + ADS#1 A0** (+ generic) | t/105,109,140,200-213,325,110,150,multi |
| 19 | 35 |   | spare / generic test pin | default-config; state checks |
| 20 | 38 | ★ | 74HC595 CLOCK (SH_CP) | t/335:35 |
| 21 | 40 | ★ | 74HC595 DATA (DS) (+ alt-mode test, generic) | t/335:35; t/107; multi |
| 22 | 15 | ★ | LCD D7 (`d3`) | t/525:36-50 |
| 23 | 16 |   | spare / generic test pin | default-config; state checks |
| 24 | 18 |   | spare / generic test pin | default-config; state checks |
| 25 | 22 |   | spare / generic test pin | default-config; state checks |
| 26 | 37 | ★ | MCP3008 ADC **CS** (bit-banged) (+ generic) | t/310,335; t/110, multi |
| 27 | 13 | ★ | LCD D6 (`d2`) | t/525:36-50 |
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
                       LCD D5   17  (11)   (12)  18   PWM/servo/INT -> ADS#1 A0
                       LCD D6   27  (13)   (14)  --   GND
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
                      (spare)   19  (35)   (36)  16   74HC595 LATCH
          MCP3008 ADC CS (bb)   26  (37)   (38)  20   74HC595 CLOCK
                          GND   --  (39)   (40)  21   74HC595 DATA
```

**Bit-banged chip-selects [T].** The three SPI chip-selects (GPIO26/12/13) are
ordinary GPIOs toggled in software, **not** the hardware CE0/CE1 (GPIO8/7) — see
§4 for the decoding. The 74HC595 (GPIO21/20/16) is fully bit-banged GPIO
(`t/335:35`). Clock/data still ride hardware SPI (GPIO9/10/11) **[L]**.

---

## 3. I2C bus (GPIO2 SDA / GPIO3 SCL)

One shared 2-wire bus; each device by address. Addresses below are **[T]** when
the test passes them explicitly, **[L]** when the test relies on the submodule
default.

| Addr | Device | Tests | Source of address |
|------|--------|-------|-------------------|
| 0x04 | Arduino (I2C slave) | t/305 (‡t/300) | **[T]** `ARDUINO_ADDR` t/305:11,31 |
| 0x20 | MCP23017 GPIO expander | t/330, t/450 | **[T]** `expander(0x20)` t/330:32, t/450:24 |
| 0x3c | OLED SSD1306 128×64 | t/500-520 | **[T]** `oled('128x64',0x3C,0)` t/500:22 |
| 0x48 | ADS1115 ADC #1 | t/140,325,345 | **[T]** `adc(addr=>0x48)` t/140:42, t/325:77, t/345:35 |
| 0x49 | ADS1115 ADC #2 | t/450 | **[T]** `adc(addr=>0x49)` t/450:25 |
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
 GPIO3 (SCL) ───────────────────SCL──┤ 0x20 │ 0x48 │ 0x49 │ 0x68 0x77 0x57 0x3c 0x04
                                    MCP23017  ADS#1  ADS#2  RTC  BMP  EEPROM OLED Ardu
```

**Two ADS1115 ADCs [T].** `0x48` (PWM/servo + dpot feedback) and `0x49` (stepper
sense) are both addressed explicitly in different tests. Two are required: the
suite reads five analog inputs (PWM/servo, dpot wiper, three stepper sensors) —
more than one 4-channel chip can carry, and the PWM output line can't share an
ADC channel with a sensor.

**One MCP23017 [T]**, strapped to `0x20`; both `t/330` and `t/450` use it there.

### 3.1 MCP23017 — pin allocation (single expander) **[T]**

Bank A is split between two jobs; Bank B mirrors only the loopback half. There is
**no** full Port-A→Port-B loopback — this split *is* the wiring (`t/330` comments
at lines 217,253; `t/450:28`):

```
  GPA0..GPA3  ─► ULN2003 IN1..IN4 ─► 28BYJ-48 stepper coils   (t/450; drive)
  GPA4..GPA7 <-> GPB4..GPB7                                   (t/330 loopback pairs)
  GPB0..GPB3  — unused
```

`t/330` writes `GPA(n)` and reads `GPB(n) = GPA(n)+8` for **n = 4,5,6,7** only,
bidirectionally (`t/330:218-231,254-267`). `t/450` drives `pins => [0,1,2,3]` =
**GPA0-3** through the expander (the `expander => $expander` path means the
StepperMotor driver writes via I2C, not Pi GPIO — `StepperMotor.pm:159-163`).

> **[F]** The MCP23017 RESET (chip pin 18) tie-high to 3V3 is standard practice;
> the tests don't touch it.

---

## 4. SPI bus (GPIO9 MISO / GPIO10 MOSI / GPIO11 SCLK)

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
| MCP4XXXX pot| **13** | 10 | 11 | — | t/345 | wiper→ADS1115 #1 A1 |

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

## 5. LCD — HD44780, 4-bit mode (`t/525`) **[T]**

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

> **[F]** The logical `d0..d3` → physical DB4..DB7 mapping is the standard HD44780
> 4-bit convention; the test proves logical wiring + 4-bit mode, not silkscreen
> pin numbers. R/W tied to GND (write-only) is also convention.

---

## 6. GPIO18 — the multiplexed workhorse pin (physical pin 12)

One physical net wired to **ADS1115 #1 channel A0**, reused across many tests:

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
resistor and no low-impedance load** — only the high-Z ADS1115 A0 input may hang
off it (a series resistor to A0 is fine; a pull resistor would break the interrupt
tests). Debounce is 0 throughout (`t/210:37`), so the net must also be kept short
/ low-capacitance to settle inside the ~20 ms edge pacing. The pin's at-rest
default is INPUT (`get_alt(18)==0`, `t/213:151`).

---

## 7. Shift register & stepper (indirect drives)

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

**Stepper (`t/450`) — no direct Pi GPIO [T].** Coils are driven through a ULN2003
by the single MCP23017's Bank A pins 0-3 (§3.1). Position is sensed by **three
analog sensors** into **ADS1115 #2 (0x49)**, channels **A0/A1/A2 = Right/Centre/Left**
(`t/450:34`: `my ($l,$c,$r)=(2,1,0)`), read with `raw()` and thresholded
(HIGH > 1850, LOW < 1650; `t/450:35`); the test rotates ±90° and asserts exactly
one sensor reads HIGH per position.

> **[F]** That the three sensors are **photo-resistors in 10 kΩ dividers**, lit by
> a "laser position rig", is design detail from README/the existing schematic —
> the tests only establish three analog channels that go HIGH/LOW with position.

---

## 8. Pins NOT wired to fixtures (free for generic tests) **[T]**

Exercised only for default-mode/state, registration counting and alt-mode round
trips — no peripheral attached; candidates for break-out test points:

- **GPIO19, 23, 24, 25** — fully spare (appear only in the default-state table).
- **GPIO7 (CE1), GPIO8 (CE0)** — at SPI-alt default; unused because CS is
  bit-banged on 26/12/13.
- **GPIO21** — also the alt-mode round-trip pin in `t/107` (loops ALT0–ALT7), in
  addition to its 74HC595 DATA duty.
- **GPIO0 / GPIO1** (phys 27/28) — used as generic test pins; idle high. **[F]**
  reserved I2C0 ID-EEPROM pins — best left unrouted on a real board.

---

## 9. Collisions & shared-net warnings

> Software-wise nothing conflicts — tests run **serially** and each cleans up
> (`RPiTest.pm:3-7`). The items below are physical-net decisions for the PCB.

1. **Shared I2C bus (GPIO2/3) [T]** — 8 addresses. Provide one bus pull-up pair
   (not one per device). Strap the two ADS1115 to 0x48/0x49 and the MCP23017 to
   0x20.
2. **Shared SPI bus (GPIO9/10/11) [T]** — three devices, one active CS at a time
   (26/12/13). Write-only DAC/dpot must not drive MISO.
3. **GPIO18 over-subscribed [T]** — PWM + servo + interrupt + generic + ADS#1 A0
   on one wire. Honour the "no external pull / no load" rule of §6.
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
   Verify against your actual parts.

---

## 10. Expected default pin states (from `t/RPiTest.pm`) **[T]**

`rpi_default_pin_config()` is the at-rest mode/state every checked pin must return
to after a run; `rpi_check_pin_status()` asserts it. `rpi_board_tag()` selects one
of three tables (`RPiTest.pm:293-304`): **pi5** (RP1, via `pi_rp1_model()`),
**pi4** (model 17/19/20), else **pi3**. `alt`/funcsel encodings: on Pi 5/RP1
`31` = null/no-peripheral, `7` = I2C, `4` = SPI, `3` = UART; on Pi 3/4 the legacy
scheme has ALT0 = `4`. `state = undef` ⇒ mode-only check (the CS pins).

**Pins checked** (`@gpio_pins`, `RPiTest.pm:214-223`): `2 3 14 15 18 23 24 10 9 25
11 8 7 0 1 12 13 19 16 20 21 26` (pins 2/3 dropped when the OLED holds the bus).
**Excluded entirely** (LCD): `4 5 6 17 22 27`.

### Pi 5 / RP1 (the active dev board) — `RPiTest.pm:395-429`

| BCM | alt | state | | BCM | alt | state | | BCM | alt | state |
|----:|----:|------:|-|----:|----:|------:|-|----:|----:|------:|
| 0  | 0  | 1 | | 11 | 4  | 0 | | 22 | 1  | 0 |
| 1  | 0  | 1 | | 12 | 31 | *undef* | | 23 | 1  | 0 |
| 2  | 7  | 1 | | 13 | 31 | 0 | | 24 | 31 | 0 |
| 3  | 7  | 1 | | 14 | 3  | 1 | | 25 | 31 | 0 |
| 4  | 31 | 0 | | 15 | 3  | 1 | | 26 | 31 | *undef* |
| 5  | 31 | 0 | | 16 | 31 | 0 | | 27 | 1  | 0 |
| 6  | 31 | 0 | | 17 | 1  | 0 | |    |    |   |
| 7  | 1  | 1 | | 18 | 0  | 0 | |    |    |   |
| 8  | 1  | 1 | | 19 | 31 | 0 | |    |    |   |
| 9  | 4  | 0 | | 20 | 31 | 0 | |    |    |   |
| 10 | 4  | 0 | | 21 | 31 | 0 | |    |    |   |

### Pi 3 / Pi 4 (identical to each other) — `RPiTest.pm:325-392`

Same pins; legacy encoding. Differences from the Pi 5 table: I2C (2/3) alt `4`;
UART (14/15) alt `4`; and the at-rest **state** for **4,5,6,17,22,27** is `1` and
for **23** is `0`, with all "null" pins reading alt `0` instead of `31`. CS pins
12/26 are mode-only in every table.

> On Pi 5, wiringPi cannot *set* alt 31, so once a sweep touches an alt-31-default
> pin it can't be auto-restored mid-run — reset such pins with `pinctrl` between
> full runs. (See the project test notes.)

---

## 11. Environment gating (how to actually run the suite) **[T]**

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

## 12. Quick PCB build checklist (test-grounded)

- [ ] 40-pin header pass-through; route the BCM pins in §2.
- [ ] One I2C pull-up pair on SDA/SCL; address straps: ADS1115 0x48 & 0x49,
      MCP23017 0x20. **[T]** addresses.
- [ ] SPI fan-out (9/10/11) → MCP3008 + MCP4922 + MCP4XXXX with **bit-banged CS**
      26/12/13; hardware CE0/CE1 left free. **[T]**
- [ ] DAC out A/out B → MCP3008 CH1/CH3; 74HC595 first Q → MCP3008 CH2. **[T]**
- [ ] dpot wiper → ADS#1 A1. **[T]** (dpot end-terminals to 3V3/GND ref — **[F]**.)
- [ ] GPIO18 → ADS#1 A0 only; **no pull, no load** (series R ok). **[T]**
- [ ] MCP23017 (0x20): GPA4-7 ↔ GPB4-7 loopback; GPA0-3 → ULN2003 → 28BYJ-48
      stepper; three position sensors → ADS#2 (0x49) A0/A1/A2. **[T]**
      (RESET→3V3 — **[F]**.)
- [ ] LCD (20×4, 4-bit): 4=D4, 5=RS, 6=E, 17=D5, 27=D6, 22=D7. **[T]**
- [ ] UART: GPIO14 → GPIO15 (header UART freed). **[T]**
- [ ] Leave GPIO0/1 unrouted (reserved ID-EEPROM). **[F]**
- [ ] Provide 3V3 + 5V rails + common ground; I2C level-shifter for the 5V
      Arduino. **[F]** — verify rails/parts against your hardware.
