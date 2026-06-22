# Test ↔ Board Traceability Matrix

Which unit tests need which physical test board. A companion to
[`test-pinout-doc.md`](test-pinout-doc.md) (the device-per-test wiring reference)
and [`board-layout-proposal.md`](board-layout-proposal.md) (the board plan).

**Source of truth:** the test↔device mapping is `test-pinout-doc.md` §3; the
device↔board mapping is the per-board models (`scripts/helpers/board-2-model.py`,
`board-3-model.py`, `board-4-model.py`). Keep this table in sync when tests or
device placement change.

> **Every hardware test below also needs board 1 (the Raspberry Pi itself).**
> Board 1 is the host all the satellites hang off; it's noted once here, not on
> every row.

---

## Board status

| Board | Role | Status | Hardware tests |
|-------|------|--------|---------------:|
| **1** | Pi host + power/signal fan-out | not built (planned last) | — (host for all) |
| **2** | SPI analog cluster | **being finalized** | 6 |
| **3** | I2C expanders + stepper | **finalized & ordered** | 2 |
| **4** | I2C sensors | scaffolded only (pending EEPROM check) | 16 |
| **5** | 5V logic (LCD / Arduino / UART) | not started | 3 |

**8 hardware tests are covered by the built boards (2 + 3); ~19 remain on the
unbuilt boards (4 + 5).**

---

## Built so far

### Board 2 — SPI analog cluster *(being finalized)*
Devices: ADS1115 (0x48), MCP3008 ADC, MCP4922 DAC, MCP42010 dpot, 74HC595, servo.

| Test file | Device(s) it drives |
|-----------|---------------------|
| `t/109-pwm_hw_mods.t` | GPIO18 PWM → ADS1115 A0 |
| `t/140-pwm_spi_adc.t` | GPIO18 PWM → ADS1115 A0 |
| `t/310-dac.t` | MCP4922 DAC → MCP3008 ADC (CH1/CH3) |
| `t/325-servo.t` | servo on GPIO18 + ADS1115 A0 |
| `t/335-shift_reg_adc.t` | 74HC595 → MCP3008 ADC (CH2) |
| `t/345-dpot.t` | MCP42010 dpot wiper → ADS1115 A1 |

### Board 3 — I2C expanders + stepper *(finalized & ordered)*
Devices: MCP23017 ×2 (0x20, 0x21), ULN2003 + 28BYJ-48 stepper, CW/CCW magnet
limit switches, indicator LEDs.

| Test file | Device(s) it drives |
|-----------|---------------------|
| `t/330-mcp23017.t` | MCP23017 @0x20 — Port A↔B loopback |
| `t/450-stepper.t` | MCP23017 @0x21 → ULN2003 → 28BYJ-48 stepper + magnet limit switches (GPIO17/27) |

---

## Remaining hardware tests — no board built yet

### Waiting on Board 4 — I2C sensors *(scaffolded only)*
Devices: DS3231 RTC, AT24C32 EEPROM, BMP180, SSD1306 OLED.

| Test file | Device |
|-----------|--------|
| `t/320-rtc.t` | DS3231 RTC (0x68) |
| `t/340-bmp.t` | BMP180 (0x77) |
| `t/420-eeprom_args.t` | AT24C32 EEPROM (0x57) |
| `t/421-eeprom_read_write_byte_croak.t` | AT24C32 EEPROM |
| `t/422-eeprom_read_write_byte.t` | AT24C32 EEPROM |
| `t/500-oled_new.t` | SSD1306 OLED (0x3c) |
| `t/501-oled_string.t` | SSD1306 OLED |
| `t/502-oled_rect.t` | SSD1306 OLED |
| `t/503-oled_dim.t` | SSD1306 OLED |
| `t/504-oled_splash_screen.t` | SSD1306 OLED |
| `t/505-oled_invert_display.t` | SSD1306 OLED |
| `t/506-oled_pixel.t` | SSD1306 OLED |
| `t/507-oled_char.t` | SSD1306 OLED |
| `t/508-oled_vertical_line.t` | SSD1306 OLED |
| `t/509-oled_horizontal_line.t` | SSD1306 OLED |

### Waiting on Board 5 — 5V logic *(not started)*
Devices: HD44780 LCD, Arduino (I2C slave) + 3V3↔5V level-shifter, UART loopback.

| Test file | Device |
|-----------|--------|
| `t/305-i2c.t` | Arduino I2C slave (0x04) |
| `t/315-serial.t` | UART loopback GPIO14 → GPIO15 (a jumper, not a chip) |
| `t/525-lcd.t` | HD44780 LCD (RS5, E6, D4=4, D5=17, D6=27, D7=22) |

---

## Borderline / not device-driving

These are gated on a device's env var but don't actually exercise the chip, so
they're not counted in the per-board totals above:

| Test file | Note |
|-----------|------|
| `t/300-i2c_exceptions.t` | Gated on the Arduino (board 5) env, but only tests the **absent-device** error path (probes 0x99). No real chip used. |
| `t/520-oled_cleanup.t` | Gated on the OLED (board 4) env, but only tests the **lock-file cleanup**, not the display. |
| `t/451-stepper-seek.t` | **Pure software** unit test of `StepperSeek::seek_limit` (mock callbacks). No hardware / no board. |

---

## Excluded (no external hardware)

For completeness — these `t/*.t` exercise no external device and need no board
beyond the Pi: module-load / config (`00`–`05`, `100`, `104`–`108`, `110`,
`111`–`114`), self-triggered GPIO18 interrupt + worker tests (`200`–`213`),
signal/exit (`150`, `153`, `154`), sysinfo (`400`–`409`), and POD/manifest
(`899`, `900`, `905`, `910`, `915`).
