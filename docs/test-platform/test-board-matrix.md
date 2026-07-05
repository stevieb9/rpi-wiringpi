# Test ↔ Board Traceability Matrix

Which unit tests need which physical test board. A companion to
[`test-pinout-doc.md`](test-pinout-doc.md) (the device-per-test wiring reference)
and [`board-layout-proposal.md`](board-layout-proposal.md) (the board plan).

**Source of truth:** the test↔device mapping is `test-pinout-doc.md` §3. For the
device↔board mapping, the finalized boards (2, 3, 4, 5) are authoritative as their
own KiCad projects under `docs/test-platform/kicad/` — they are hand-managed and
have no generated model.
Keep this table in sync when tests or device placement change.

> **Every hardware test below also needs board 1 (the Raspberry Pi itself).**
> Board 1 is the host all the satellites hang off; it's noted once here, not on
> every row. Board 1 also carries two test devices of its own - the I2C LCD
> (`t/335-lcd_i2c.t`) and the planned PCA9685 PWM controller
> (`t/440-pca9685.t`).

---

## Board status

| Board | Role | Status | Hardware tests |
|-------|------|--------|---------------:|
| **1** | Pi host + power/signal fan-out + I2C LCD + PCA9685 | not built (planned last) | 2 (host for all) |
| **2** | SPI analog cluster | **finalized & ordered** | 6 |
| **3** | I2C expanders + stepper | **finalized & ordered** | 2 |
| **4** | I2C sensors | **finalized & ordered** | 15 |
| **5** | 5V logic (LCD / Arduino / UART) | **finalized & ordered** | 3 |

**26 hardware tests are covered by the finalized boards (2 + 3 + 4 + 5, all
ordered); 2 remain on board 1 (the I2C LCD + PCA9685, planned last).**

---

## Built so far

### Board 2 — SPI analog cluster *(finalized & ordered)*
Devices: ADS1015 (0x48), MCP3008 ADC, MCP4922 DAC, MCP42010 dpot, 74HC595, servo.

| Test file | Device(s) it drives |
|-----------|---------------------|
| `t/400-pwm_hw_mods.t` | GPIO18 PWM → ADS1015 A0 |
| `t/405-pwm_i2c_adc.t` | GPIO18 PWM → ADS1015 A0 |
| `t/410-dac.t` | MCP4922 DAC → MCP3008 ADC (CH1/CH3) |
| `t/425-servo.t` | servo on GPIO18 + ADS1015 A0 |
| `t/435-shift_reg_adc.t` | 74HC595 → MCP3008 ADC (CH2) |
| `t/445-dpot.t` | MCP42010 dpot wiper → ADS1015 A1 |

### Board 3 — I2C expanders + stepper *(finalized & ordered)*
Devices: MCP23017 ×2 (0x20, 0x21), ULN2003 + 28BYJ-48 stepper, CW/CCW magnet
limit switches, indicator LEDs.

| Test file | Device(s) it drives |
|-----------|---------------------|
| `t/355-mcp23017.t` | MCP23017 @0x20 — Port A↔B loopback |
| `t/350-stepper.t` | MCP23017 @0x21 → ULN2003 → 28BYJ-48 stepper + magnet limit switches (GPIO17/27) |

### Board 4 — I2C sensors *(finalized & ordered)*
Devices: DS3231 RTC, AT24C32 EEPROM, BMP180, SSD1306 OLED.

| Test file | Device |
|-----------|--------|
| `t/530-rtc.t` | DS3231 RTC (0x68) |
| `t/531-bmp.t` | BMP180 (0x77) |
| `t/540-eeprom_args.t` | AT24C32 EEPROM (0x57) |
| `t/541-eeprom_read_write_byte_croak.t` | AT24C32 EEPROM |
| `t/542-eeprom_read_write_byte.t` | AT24C32 EEPROM |
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

### Board 5 — 5V logic *(finalized & ordered)*
Devices: HD44780 LCD, Arduino (I2C slave) + 3V3↔5V level-shifter, UART loopback.

| Test file | Device |
|-----------|--------|
| `t/605-i2c.t` | Arduino I2C slave (0x04) |
| `t/610-serial.t` | UART loopback GPIO14 → GPIO15 (a jumper, not a chip) |
| `t/620-lcd.t` | HD44780 LCD (RS5, E6, D4=4, D5=17, D6=27, D7=22) |

---

## Remaining hardware tests — no board built yet

### Waiting on Board 1 — Pi host + I2C LCD + PCA9685 *(planned last)*
Board 1 is the passive host (power/signal fan-out) for every other board, and
also carries its own test devices: the I2C LCD - an HD44780 on a PCF8574 I2C
backpack (0x27), 5V, behind a 3V3↔5V level-shifter - and the planned PCA9685
16-channel PWM controller (0x40).

Devices: HD44780 LCD on PCF8574 I2C backpack (0x27), PCA9685 (0x40, 16-ch PWM, planned).

| Test file | Device |
|-----------|--------|
| `t/335-lcd_i2c.t` | HD44780 LCD on PCF8574 I2C backpack (0x27) |
| `t/440-pca9685.t` | PCA9685 16-ch PWM (0x40) — register readback; needs only the chip on the bus |

---

## Borderline / not device-driving

These are gated on a device's env var but don't actually exercise the chip, so
they're not counted in the per-board totals above:

| Test file | Note |
|-----------|------|
| `t/600-i2c_exceptions.t` | Gated on the Arduino (board 5) env, but only tests the **absent-device** error path (probes 0x99). No real chip used. |
| `t/520-oled_cleanup.t` | Gated on the OLED (board 4) env, but only tests the **lock-file cleanup**, not the display. |
| `t/351-stepper-seek.t` | **Pure software** unit test of `StepperSeek::seek_limit` (mock callbacks). No hardware / no board. |

---

## Excluded (no external hardware)

For completeness — these `t/*.t` exercise no external device and need no board
beyond the Pi: module-load / config (`00`–`05`, `100`, `104`–`108`, `110`,
`111`–`114`), self-triggered GPIO18 interrupt + worker tests (`200`–`213`),
signal/exit (`150`, `153`, `154`), sysinfo (`300`–`309`), and POD/manifest
(`899`, `900`, `905`, `910`, `915`).
