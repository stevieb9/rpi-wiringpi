# V1 — Complete per-test pin/device inventory (test-grounded)

Source of truth = the test suite + driver submodules under `~/repos`. Every fact
tagged **[T]** (proven in a test, cited `file:line`), **[L]** (submodule/facade
default the test relies on), or **[F]** (non-test / hardware convention). Unknowns
are flagged, never invented. Line numbers are CURRENT (re-derived this session).

Legend for "pins": **Pi** = Raspberry Pi BCM GPIO on the 40-pin header;
**exp@0xNN** = pins live on an MCP23017 I2C expander (NOT Pi GPIO);
**pcf@0x27** = PCF8574 virtual pins (NOT Pi GPIO); **ADC ch** = analog channel.

---

## A. Master table — every hardware-touching test

| Test | Device(s) | I2C addr | SPI CS | Pi BCM pins used | Non-Pi pins | Env gate | Cite |
|------|-----------|----------|--------|------------------|-------------|----------|------|
| 105-pin | generic GPIO | — | — | 18 | — | RPI_BOARD | t/105:21 [T] |
| 107-alt_modes | generic GPIO | — | — | 21 (ALT0–7 round-trip) | — | RPI_BOARD | t/107:20,37-44 [T] |
| 108-mode_state_all_pins | generic GPIO | — | — | 0,1,2,3,7,8,9,10,11,12,13,14,15,16,18,19,20,21,23,24,25,26 (4,5,6,17,22,27 excluded=LCD) | — | RPI_BOARD | RPiTest @gpio_pins :327-329 [T] |
| 110-register | generic GPIO | — | — | 12, 18, 26 | — | RPI_BOARD | t/110:23-25 [T] |
| 112 / 113 / 114 metadata | generic GPIO | — | — | 112: 12,16,18,21,26 · 113/114: 12,18 | — | RPI_MULTI | multi/*.pl [T] |
| 150-cleanup | generic GPIO | — | — | 12, 18, 26 | — | RPI_BOARD | doc §3 [T] |
| 200–212 interrupt (13 files), 213-worker | generic GPIO (self-triggered) | — | — | 18 (no external driver/load) | — | RPI_BOARD | t/200:40-45; t/213:121,152 [T] |
| 350-stepper | MCP23017(0x21)+ULN2003+28BYJ-48; limits+LED | 0x21 | — | **17** (CW limit), **27** (CCW limit), **19** (centre LED) | coils exp@0x21 GPA0–3 | RPI_STEPPER(+RPI_MCP23017) | t/350:138,143,148,152,272 [T] |
| 355-mcp23017 | MCP23017 loopback | 0x20 | — | none beyond I2C | GPA(n)↔GPB(7−n) exp@0x20 | RPI_MCP23017 | t/355:45,649-650 [T] |
| 400-pwm_hw_mods | ADS1015 | 0x48 | — | **18** (HW PWM out → ADS A0) | ADC A0 | RPI_I2C | t/400:58,69 [T] |
| 405-pwm_i2c_adc | ADS1015 | 0x48 | — | **18** (PWM → ADS A0) | ADC A0 | RPI_I2C | t/405:56,67-68 [T] |
| 410-dac | MCP4922 DAC, MCP3008 ADC | — | DAC=**12**, ADC=**26** (bit-bang) | 9(MISO),10(MOSI),11(SCLK),12,26 | DAC A→MCP3008 CH1, DAC B→CH3 | RPI_I2C? see note | t/410:35,37-38,59-68 [T] |
| 425-servo | Servo, ADS1015 | 0x48 | — | **18** (servo PWM → ADS A0) | ADC A0 | RPI_SERVO | t/425:92,94 [T] |
| 435-shift_reg_adc | 74HC595, MCP3008 | — | ADC=**26** | 9,10,11, **16**(LATCH),**20**(CLOCK),**21**(DATA),26 | 595 Q0(vpin401)→MCP3008 CH2 | RPI_SHIFTREG | t/435:34,43-48,52 [T] |
| 445-dpot | MCP4XXXX dpot ×? , ADS1015 | 0x48 | dpot=**13** | 9? ,10,11,13 | **PW0→ADS A1 AND PW1→ADS A2** (see D1) | RPI_DIGIPOT | t/445:34-35,38-39,52,68-69 [T] |
| 500–509 OLED (10), 520 cleanup | SSD1306 128×64 | 0x3c | — | none beyond I2C (2,3 dropped when OLED lock held) | — | RPI_OLED | t/500:32 [T]; RPiTest :313 |
| 530-rtc | DS3231 RTC | 0x68 | — | none beyond I2C | — | RPI_RTC | t/530:31 [L] default 0x68 |
| 531-bmp | BMP180 | 0x77 | — | none beyond I2C | — | RPI_BMP | t/531:27,33 [L] |
| 540/541/542 eeprom | AT24C32 EEPROM | 0x57 | — | none beyond I2C | — | RPI_EEPROM | t/540:32 [T] |
| 600-i2c_exceptions | (absent-device path) | 0x99 probe | — | none beyond I2C | — | RPI_ARDUINO gate | t/600:36,44 [T] |
| 605-i2c | Arduino I2C slave | 0x04 | — | none beyond I2C | — | RPI_ARDUINO | t/605:21,41 [T] |
| 610-serial | UART loopback | — | — | **14**(TXD)→**15**(RXD) | — | RPI_SERIAL | t/610:22-23 [T] |
| 620-lcd | HD44780 parallel 4-bit | — | — | RS=**5**,E=**6**,D4=**4**,D5=**17**,D6=**27**,D7=**22** | — | RPI_LCD | t/620:50-59 [T] |

### New devices — MISSING from the current pinout doc §3

| Test | Device(s) | I2C addr | SPI CS | Pi BCM pins used | Non-Pi pins | Env gate | Cite |
|------|-----------|----------|--------|------------------|-------------|----------|------|
| **335-lcd_i2c** | HD44780 on PCF8574 backpack | **0x27** | — | **none beyond I2C** | rs/strb/d0-3 = pcf@0x27 pins (vbase 64) | RPI_LCD_I2C (board 1) | t/335:38,62; WiringPi.pm:290,300 [T/L] |
| **353-a4988** | A4988 stepper via MCP23017 | **0x22** | — | **none** (all lines on expander) | step..reset = exp@0x22 GPA0–7 | RPI_A4988(+RPI_MCP23017) | t/353:88-97,99,102,135; WiringPi.pm:472-488 [T] |
| **358-gyro** | MPU-6050 IMU | **0x68** | — | none beyond I2C | — | RPI_GYRO | t/358:76,101-102 [T]; MPU6050.pm:198 [L] |
| **360-adxl335** | ADXL335 via ADS1115 ADC | **0x48** (ADC) | — | none beyond I2C | ADXL335 X/Y/Z → ADS **ch0/ch1/ch2** | RPI_ADXL335 | t/360:71-76,93-100; WiringPi.pm:153-157; ADS.pm:191 [T/L] |
| **361-radar** | RCWL-0516 motion | — | — | **26** (OUT, input) — test default; driver has NO default | — | RPI_RADAR | t/361:65,43-44; RCWL0516.pm:27-28 [T] |
| **440-pca9685** | PCA9685 16-ch PWM | **0x40** | — | none beyond I2C | 16 PWM outs are the chip's own | RPI_PCA9685 (board 1; NOT auto-enabled) | t/440:55; PCA9685.pm:47 [L] |
| **447-tft_st7735s** | ST7735S 128×128 TFT | — | **CE0 = GPIO8** (channel 0, hardware) | **8**(CE0/CS),**10**(MOSI),**11**(SCLK),**25**(DC),**24**(RES),**23**(BLK) | write-only, no MISO | RPI_ST7735S (bench, no board) | t/447:46-47,69-72; ST7735S.pm:152-156; WiringPi.pm:531-536 [T/L] |

### Unit / HW-free tests (ungated; touch no bus/GPIO/address)

`354-a4988_unit`, `356-mcp23017_unit`, `357-gyro_deadband_unit`, `359-adxl335_unit`,
`362-radar_unit`, `448-tft_st7735s_unit`, plus the pre-existing `351-stepper-seek`,
`352-steppermotor_unit`, `411/422/436/437/438/446/510/521/533/534/543` unit tests
and `250-i2c_unit`, `117-wiringpi_api_unit`. Each skips only when its (unreleased)
leaf module is not installed. No pins. (`t/354:98-109` numbers are mock-expander
indices; `t/362:66` pin 23 is a MockPin; `t/448:310` dc=>25 is a mock hash key.)

**Non-hardware** (module-load/config/sysinfo/pod): 00–05,100,104,106,109,111,
116,118,119,153,154,300–309,899,900,905,910,915 — no pins.

---

## B. I2C address map (all devices, current)

| Addr | Device | Test(s) | Board / context | Source |
|------|--------|---------|-----------------|--------|
| 0x04 | Arduino I2C slave | 605 (‡600 probes 0x99) | board 5 | [T] t/605:21 |
| 0x20 | MCP23017 #1 (loopback) | 355 | board 3 | [T] t/355:45 |
| 0x21 | MCP23017 #2 (28BYJ-48 stepper drive) | 350 | board 3 | [T] t/350:138 |
| **0x22** | **MCP23017 #3 (A4988 drive)** | **353** | **bench (robot family)** | **[T] t/353:99** |
| **0x27** | **PCF8574 → HD44780 (I2C LCD)** | **335** | **board 1** | **[T] t/335:38** |
| 0x3c | SSD1306 OLED | 500–520 | board 4 | [T] t/500:32 |
| **0x40** | **PCA9685 16-ch PWM** | **440** | **board 1 (not wired yet)** | **[L] PCA9685.pm:47** |
| 0x48 | ADS1015 ADC (PWM/servo/dpot readback) | 400,405,425,445 | board 2 | [T] t/405:56 |
| 0x48 | **ADS1115 ADC for ADXL335** (same addr, bench) | **360** | **bench** | **[L] ADS.pm:191** — see C3 |
| 0x57 | AT24C32 EEPROM | 540–542 | board 4 | [T] t/540:32 |
| **0x68** | **MPU-6050 gyro** | **358** | **bench** | **[T] t/358:76** — same addr as RTC, see C2 |
| 0x68 | DS3231 RTC | 530 | board 4 | [L] t/530:31 |
| 0x77 | BMP180 | 531 | board 4 | [L] t/531:27 |

---

## C. Substantive findings (feed V2/V3 + the doc edits)

**C1 — Pin pressure / new claims on previously-"free" pins.** The pinout doc §5/§9
claim GPIO23/24/25 "fully spare" and hardware CE0/CE1 "stay free". The TFT (`t/447`)
now claims **CE0=GPIO8, DC=25, RES=24, BLK=23** [T t/447:46-47,70-72]. The radar
(`t/361`) claims **GPIO26** [T t/361:65]. After this device wave, the only header
BCM with no assigned role is **GPIO7 (CE1)**. Doc §9 is stale and must be rewritten.

**C2 — Address clash 0x68: gyro vs RTC.** Both the MPU-6050 (`t/358`, bench) and the
DS3231 RTC (`t/530`, board 4) answer at **0x68** [T t/358:76 / L t/530:31]. Not a
same-board defect (RTC is board 4, gyro is bench), but they cannot share one bus
segment simultaneously. Classify in V3.

**C3 — Address clash 0x48 + channel clash: board-2 ADS vs ADXL335 ADS.** Board 2's
ADS1015 @0x48 uses A0 (PWM/servo), A1 (dpot PW0), **A2 (dpot PW1 — new, see D1)**.
The ADXL335 (`t/360`, bench) reads an ADS @**0x48** on channels **0,1,2** [T
t/360:72-76]. Same address, same three channels — cannot coexist on one bus. ADXL335
is bench (robot family), so no same-board defect, but it's a real header/bus
contention. Classify in V3. (Also: bench test names model ADS1115 by default;
memory notes the board-2 silicon at 0x48 is actually an ADS1015 — separate issue.)

**C4 — GPIO26 double-booked (real single-net question).** MCP3008 ADC CS = GPIO26
(bit-bang) [T t/410:35] AND radar OUT = GPIO26 [T t/361:65]. MCP3008 is board 2;
radar is bench. On one Pi you cannot have both wired to pin 26 at once. Radar's pin
is env-overridable (`RPI_RADAR_PIN`) and the driver has no built-in default, so
GPIO26 is purely the test-file's choice — the cheapest relief candidate (V7).

---

## D. Drift the doc edits (V4–V6) must fix

**D1 — CONTENT drift (t/445 two dpot wipers).** Current `t/445` sweeps TWO pots:
`ADC_PW0=>1` (ADS **A1**) and `ADC_PW1=>2` (ADS **A2**) [T t/445:38-39,68-69].
The doc shows only a single "wiper → ADS#1 A1" in ~6 places (§1:80, §4:334, §5:410,
§7:214, §11:625, §14:790). Add the PW1→**A2** path everywhere. This means ADS @0x48
uses **A0, A1, A2** (not just A0/A1).

**D2 — Stale `RPiTest.pm` line cites (100–250 lines off).** Harness grew; the pin
*values* in §12 (pi5/pi4/pi3 tables) are all still correct, but every `RPiTest.pm:NN`
cite in §6/§10/§12/§13 is wrong. Current anchors:
- LCD-exclude comment: **:311** (doc says :204)
- `@gpio_pins`: normal **:327-329**, OLED-locked **:322-324** (doc says :214-223)
- Pi5 table **:508-542**; Pi3 **:438-470**; Pi4 **:473-505** (doc says :395-429 / :325-392)
- OLED `/dev/shm/oled_in_use` drop of pins 2/3: **:313** (doc says :206-210)
- CS mode-only undef (12/26): comment **:336-337**; per-table undef :451-452/:486-487/:523-524 (doc says :338-340)
- `rpi_serial_device()` ttyS0/ttyAMA0: **:423-431** (doc says :310-318)
- Gates: RPI_BOARD **:42-45**, OBJECT_COUNT **:58-63**, PIN_COUNT **:64-69**, SUDO **:73-77**, MULTI **:78-82**, I2C **:244-254** (doc §13 all off; I2C badly so)
- `rpi_board_tag()` **:400-417**; `rpi_default_pin_config` **:435-551**

**D3 — Stale per-test line cites (+1/+2).** ~24 per-test cites off by one/two lines
(preambles grew). Fact unchanged in every case. Full list captured; will fix the
ones that appear in the doc when editing.

**D4 — §13 gate description incomplete.** `RPI_BOARD` gate is satisfied by
`RPI_BOARD` **OR** `SUDO_USER` [T RPiTest.pm:42]; doc omits `SUDO_USER`.

**D5 — §12 generation reality.** Only the Pi5 table BODY is generated
(`{{default_states_pi5}}` at tmpl:735). Everything else in §12/§13 — prose, the
Pi3/Pi4 difference text, and all `RPiTest.pm:NN` cites — is STATIC template text and
will NOT self-correct on regen; it must be hand-fixed in `test-pinout-doc.tmpl.md`.

**D6 — GPIO13 harness inconsistency (pre-existing, doc already flags it).** Comment
says "OUTPUT/HIGH due to dpot (t/445)" but asserted `state` is `0` in all three
tables (:454/:489/:526). Doc §10 item 6 already reports this accurately — keep.

---

## E. Env-gate reference (current)

Run gate `RPI_BOARD` (or `SUDO_USER`) [:42-45]. Per-device gates: RPI_I2C [:244-254],
RPI_SUDO [:73-77], RPI_MULTI [:78-82]; baselines RPI_OBJECT_COUNT [:58-63] /
RPI_PIN_COUNT [:64-69]. Device gates seen across `t/`: RPI_ADC, RPI_ARDUINO, RPI_BMP,
RPI_DIGIPOT, RPI_EEPROM, RPI_LCD, RPI_MCP3008, RPI_MCP4922, RPI_OLED, RPI_RTC,
RPI_SERIAL, RPI_SERVO, RPI_SHIFTREG, RPI_STEPPER, and the NEW ones: **RPI_A4988,
RPI_ADXL335, RPI_GYRO, RPI_LCD_I2C, RPI_MCP23017, RPI_PCA9685, RPI_RADAR,
RPI_ST7735S** (+ per-device pin overrides like RPI_A4988_STEP, RPI_ST7735S_DC,
RPI_RADAR_PIN, RPI_ADXL335_X/Y/Z, RPI_GYRO_ADDR). `RPI_BOARD_1` sets RPI_BOARD but
deliberately does NOT enable RPI_PCA9685 (not wired to board 1 yet) [t/440:7-16].
