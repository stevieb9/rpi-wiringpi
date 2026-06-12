# UNWRAPPED — WiringPi::API functions not used or documented by RPi::WiringPi

An audit of every function exported by **`WiringPi::API`** (`~/repos/wiringpi-api`,
the XS layer) against every reference in the **`RPi::WiringPi`** distribution
(`~/repos/rpi-wiringpi`, the high-level wrapper).

## Method

Each name exported by `WiringPi::API` was whole-word matched across all `.pm`,
`.pl`, `.pod`, `.md`, `.t`, `README`, and `Changes` files in `rpi-wiringpi`.
The match catches every form of use: method calls (`$pi->name`), fully-qualified
calls (`WiringPi::API::name`), imports, and prose mentions in POD/Markdown.

`WiringPi::API` exposes most capabilities under **two names** — a camelCase C
binding (`digitalWrite`) and a snake_case Perl wrapper (`write_pin`). A capability
is treated as **covered** if *either* form is referenced anywhere, so every entry
below is one where **neither** the C binding **nor** the Perl wrapper appears in
`rpi-wiringpi` at all. The `C binding` column lists the camelCase sibling(s) that
were also checked; `(C-only)` marks functions that have no Perl wrapper in
`WiringPi::API`.

## 1. Completely unwrapped — 69 capabilities

Neither the Perl wrapper nor the C binding is called or documented anywhere
in `rpi-wiringpi` (not in shipped code, tests, docs, plans, or the changelog).

| # | WiringPi::API function | C binding |
|---|------------------------|-----------|
| 1 | `ads1115_setup` | `ads1115Setup` |
| 2 | `analog_read` | `analogRead` |
| 3 | `analog_write` | `analogWrite` |
| 4 | `bmp180_pressure` | `bmp180Pressure` |
| 5 | `bmp180_setup` | `bmp180Setup` |
| 6 | `bmp180_temp` | `bmp180Temp` |
| 7 | `delay_microseconds` | `delayMicroseconds` |
| 8 | `digital_read_byte` | — |
| 9 | `digital_read_byte2` | — |
| 10 | `digital_write_byte` | `digitalWriteByte` |
| 11 | `digital_write_byte2` | — |
| 12 | `get_pin_mode_alt` | `getPinModeAlt` |
| 13 | `gpio_clock_set` | `gpioClockSet` |
| 14 | `i2c_interface` | `wiringPiI2CSetupInterface` |
| 15 | `i2c_raw_read` | `wiringPiI2CRawRead` |
| 16 | `i2c_raw_write` | `wiringPiI2CRawWrite` |
| 17 | `i2c_read` | `wiringPiI2CRead` |
| 18 | `i2c_read_block` | `wiringPiI2CReadBlockData` |
| 19 | `i2c_read_byte` | `wiringPiI2CReadReg8` |
| 20 | `i2c_write` | `wiringPiI2CWrite` |
| 21 | `i2c_write_block` | `wiringPiI2CWriteBlockData` |
| 22 | `i2c_write_byte` | `wiringPiI2CWriteReg8` |
| 23 | `i2c_write_word` | `wiringPiI2CWriteReg16` |
| 24 | `interrupt_fd` | — |
| 25 | `lcd_cursor` | `lcdCursor` |
| 26 | `lcd_cursor_blink` | `lcdCursorBlink` |
| 27 | `lcd_display` | `lcdDisplay` |
| 28 | `lcd_home` | `lcdHome` |
| 29 | `lcd_puts` | `lcdPuts` |
| 30 | `lcd_send_cmd` | `lcdSendCommand` |
| 31 | `micros (C-only)` | — |
| 32 | `millis (C-only)` | — |
| 33 | `pi_board40_pin` | `piBoard40Pin` |
| 34 | `pi_hi_pri` | `piHiPri` |
| 35 | `pi_lock` | — |
| 36 | `pi_micros64` | `piMicros64` |
| 37 | `pi_unlock` | — |
| 38 | `pseudoPinsSetup (C-only)` | — |
| 39 | `pull_up_down` | `pullUpDnControl` |
| 40 | `pwm_tone_write` | `pwmToneWrite` |
| 41 | `serial_close` | — |
| 42 | `serial_data_avail` | `serialDataAvail` |
| 43 | `serial_flush` | `serialFlush` |
| 44 | `serial_get_char` | `serialGetchar` |
| 45 | `serial_gets` | — |
| 46 | `serial_open` | `serialOpen` |
| 47 | `serial_put_char` | `serialPutchar` |
| 48 | `serial_puts` | `serialPuts` |
| 49 | `set_pad_drive` | `setPadDrive` |
| 50 | `set_pad_drive_pin` | `setPadDrivePin` |
| 51 | `soft_pwm_create` | — |
| 52 | `soft_pwm_stop` | — |
| 53 | `soft_pwm_write` | — |
| 54 | `soft_tone_create` | `softToneCreate` |
| 55 | `soft_tone_stop` | `softToneStop` |
| 56 | `soft_tone_write` | `softToneWrite` |
| 57 | `spi_close` | `wiringPiSPIClose` |
| 58 | `spi_data` | `spiDataRW` |
| 59 | `spi_get_fd` | `wiringPiSPIGetFd` |
| 60 | `spi_setup` | `wiringPiSPISetup` |
| 61 | `spi_setup_mode` | `wiringPiSPISetupMode` |
| 62 | `stop_interrupt` | `wiringPiISRStop` |
| 63 | `wiringpi_global_memory_access` | `wiringPiGlobalMemoryAccess` |
| 64 | `wiringpi_gpio_device_get_fd` | `wiringPiGpioDeviceGetFd` |
| 65 | `wiringpi_setup_gpio_device` | `wiringPiSetupGpioDevice` |
| 66 | `wiringpi_setup_pin_type` | `wiringPiSetupPinType` |
| 67 | `wiringpi_user_level_access` | `wiringPiUserLevelAccess` |
| 68 | `wiringpi_version` | `wiringPiVersion` |
| 69 | `worker` | — |

## 2. Referenced only in dev artifacts — 9 capabilities

These appear *only* in the changelog (`Changes`), design notes (`plans/`),
or ad-hoc scripts under `build_testing/` — never in the shipped `lib/` code,
test suite (`t/`), or user-facing POD/Markdown docs. Effectively unwrapped
from a published-API standpoint, but listed separately since a reference exists.

| # | WiringPi::API function | C binding |
|---|------------------------|-----------|
| 1 | `i2c_read_word` | `wiringPiI2CReadReg16` |
| 2 | `i2c_setup` | `wiringPiI2CSetup` |
| 3 | `lcd_char_def` | `lcdCharDef` |
| 4 | `lcd_clear` | `lcdClear` |
| 5 | `lcd_init` | `lcdInit` |
| 6 | `lcd_position` | `lcdPosition` |
| 7 | `lcd_put_char` | `lcdPutchar` |
| 8 | `pin_mode` | `pinMode` |
| 9 | `pwm_write` | `pwmWrite` |

## Summary

- Total capabilities exported by `WiringPi::API`: **107**
- Covered by `RPi::WiringPi` (shipped code/tests/docs): **29**
- Completely unwrapped: **69**
- Referenced only in dev artifacts: **9**

Constants (`WPI_PIN_*`, `INT_EDGE_*`) were excluded from this function audit.
