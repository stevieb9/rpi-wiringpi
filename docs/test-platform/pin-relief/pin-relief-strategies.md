# V7 — Pin-freeing strategies (evaluated, grounded)

Scope (user 2026-07-12): **board re-wiring/re-spin is acceptable** — boards 2–5 are
NOT treated as frozen for this analysis. Every claim traces to the V1/V2/V3
inventory or a driver source; feasibility that needs an unverified code change is
flagged as such, never asserted. Analysis only — nothing implemented (that's V8→you).

## Framing: what is reducible vs irreducible

The platform spends Pi GPIO for two different reasons, and only one is negotiable:

- **Irreducible — the pin IS the test.** These exercise a *Pi-native* library feature
  that only exists on specific header pins, so freeing the pin means not testing the
  feature on this Pi:
  - I2C bus **2/3** (every I2C device) — [V1 §B]
  - SPI bus **9/10/11** (MISO/MOSI/SCLK) — [V1 §A]
  - UART **14/15** — the primary header UART is fixed to these pins [t/610; RPiTest serial]
  - **18** — hardware PWM + servo + *native* edge-interrupt workhorse; hardware PWM
    lives only on a few pins and the interrupt tests need a real Pi pin [tmpl §7; t/200-213,400,425]
  - the **bit-banged SPI CS 12/13/26** and **74HC595 16/20/21** — testing software-CS
    and `shift_register()` over *real GPIO* is the point of t/410/435/445 [tmpl §5,§8]
  - the **parallel LCD 4/5/6/17/22/27** — exercising wiringPi's *native parallel*
    `lcd_init` path is the deliberate purpose of t/620 (user 2026-07-12); the I2C path is
    covered separately by the PCF8574 LCD (t/335). Moving these to an expander deletes that
    coverage → **irreducible by design** (see R2, rejected).
- **Reducible — the pin drives a peripheral that could ride I2C/an expander instead.**
  After the parallel-LCD decision, this is now just **indicator LEDs** and the **bench**
  devices — a much smaller set than first estimated. This is where the (little) remaining
  relief is.

**The proven lever (already in-tree):** an MCP23017 makes a fixture cost **zero** header
GPIO — the 28BYJ-48 (@0x21) and A4988 (@0x22) drive *all* their control lines, including
the A4988's STEP pulse train, over I2C [V1 t/353; tmpl §4.1]. wiringPi exposes expander
pins as transparent virtual GPIO (the PCF8574 LCD does the same, base 64 [V1 t/335]).
Electrical limit: I2C-expander pin toggles are ~1000× slower than native GPIO, so
**low-frequency** lines (LED, RESET, backlight, ENABLE, DIR, MS, even a slow STEP) move
cleanly; **timing-critical** lines (an SPI CS that frames each byte, a TFT D/C toggled
per command) and **native-edge-interrupt** inputs do NOT move without extra work.

---

## Strategies

### R1 — Move the radar OUT off GPIO26  ·  ✅ IMPLEMENTED 2026-07-12 (interim)  ·  freed: resolves the only conflict (net 0)  ·  risk: ~0
- **Done:** `t/361` now defaults the radar to **GPIO7** (CE1), the only board-free pin,
  and asserts the pin comes up INPUT and that `cleanup()` restores it. Interim — the
  permanent home is an MCP23017 expander input (radar rework, backlog), which frees GPIO7.
- Was (pre-R1): radar OUT defaulted to **GPIO26**, colliding with the MCP3008 bit-banged CS
  [V1 K1; t/361:65]. The driver has **no** built-in default and the pin is env-settable
  (`RPI_RADAR_PIN`) [RCWL0516.pm:27-28], so 26 is purely the test file's choice.
- Do: change the `t/361` default to the one free header pin **GPIO7/CE1** (or any pin
  freed below). One-line test change; no driver change.
- Effect: doesn't increase the free count, but lets radar + MCP3008 co-exist and stops
  a live-header conflict. **The cheapest, safest item — do it regardless.**

### R2 — Convert the board-5 parallel HD44780 to an expander/backpack  ·  ❌ REJECTED (user 2026-07-12)
- **REJECTED — the parallel LCD is irreducible by design.** Its whole purpose is to
  exercise wiringPi's **native parallel `lcd_init` path**; moving its data lines onto any
  expander (PCF8574 backpack *or* the `0x21` MCP23017) deletes exactly that coverage.
  `RPi::LCD` is a thin wrapper over wiringPi's C LCD library (`LCD.pm:8,34` — `use parent
  'WiringPi::API'`, `init`→`lcd_init`→C `lcdInit`), so the HD44780 protocol bit-bangs in C
  and only reaches pins wiringPi knows (native, or `pcf8574Setup`/`sr595Setup` nodes — **no
  `mcp23017Setup` is exposed** in this WiringPi::API build). The user's own
  `RPi::GPIOExpander::MCP23017` can't be injected into that C path without reimplementing
  HD44780 in Perl, and doing so would test a *different* path than the one t/620 exists for.
  The I2C-backpack path gets its own coverage from a separate PCF8574 LCD (`t/335`) sited
  elsewhere.
- **Consequence:** GPIO **4/5/6/17/22/27** are now **irreducible** (moved to the floor
  below). This removes the single largest relief candidate; the reclaimable budget on the
  fabbed boards shrinks to essentially **GPIO19** (R3).
- Footnote for R3: the `0x21` expander's spare Bank-B pins the user has wired ARE a good
  home — but for the **centre LED** (a plain `$exp->write`, works through the user's own
  library), not the LCD.

### R3 — Move the stepper centre LED (GPIO19) onto the 0x21 expander  ·  freed: 1  ·  risk: LOW  ·  **the one clean fabbed-board win**
- Now: **GPIO19** is a plain indicator LED pulsed by a `worker` fork [V1 t/350:143; tmpl §8].
- Unlike the LCD (R2), this works through the user's **own** `RPi::GPIOExpander::MCP23017`
  with **no** wiringPi involvement — an LED is a single digital output, so it's just
  `$exp->write($pin, HIGH/LOW)`, exactly like the stepper already drives its coils. No
  HD44780/`lcd_init` C-path problem applies here.
- Fit: the `0x21` chip (board 3, stepper drive) has 12 free pins (16 − 4 for the 28BYJ-48 on
  Bank A0-3); a Bank-B pin is a perfect home. The stepper test already builds that expander,
  so the plumbing exists.
- Effect: frees **19**. Small test/driver change (drive the LED via the expander object);
  negligible coverage change (the `worker`-fork test still pulses an output). **Primary
  recommendation now that R2 is out.**

### R4 — Move the TFT BLK + RES (GPIO23/24) off the header  ·  freed: up to 2  ·  risk: MEDIUM
- Now: the bench TFT uses **8**(CE0/CS), **25**(D/C), **24**(RES), **23**(BLK) [V1 t/447].
  CS(CE0) and D/C are timing-critical (D/C toggles per command) → keep on the header.
  **BLK (backlight) and RES (reset) are low-frequency** → movable.
- Do, either: (a) drive BLK/RES from an MCP23017 — needs the TFT driver to accept an
  expander/virtual pin for `bl`/`rst` (**code change, unverified — flag**); or (b) tie
  BLK high (always-on backlight) and RES to a shared reset/RC — frees the pins but drops
  the `backlight()`/reset test coverage.
- Effect: frees **23/24**; TFT shrinks to 2 header pins (CS + D/C).

### R5 — Move the stepper CW/CCW limit switches (GPIO17/27) onto an expander  ·  ⊘ MOOT (R2 rejected)
- **Now moot.** 17/27 are **shared** with the parallel LCD (D5/D6), which stays on native
  GPIO (R2 rejected). So the LCD keeps 17/27 regardless — moving the stepper limits off them
  frees **nothing**, and would still lose the native `background_interrupt` coverage
  [V1 t/350:148,152,157,163]. Not worth doing.

### R6 — 74HC595 control lines (GPIO16/20/21)  ·  freed: up to 3  ·  risk: HIGH / low value
- The 595 is bit-banged on **16/20/21** *because t/435 tests `shift_register()` over real
  GPIO* [tmpl §8]. Moving DATA/CLOCK/LATCH to an expander either (a) drops that GPIO
  coverage, or (b) needs `shift_register()` to accept expander pins (**unverified**) and
  bit-bangs a shift register *over I2C* — slow and a different topology than intended.
- Effect: 3 pins on paper, but it guts the test's reason to exist. **Recommend NOT doing**
  unless you're dropping shift-register GPIO coverage deliberately.

### R7 — Consolidate bit-banged SPI CS (12/13/26) onto hardware CE0/CE1  ·  freed: ~0–1  ·  risk: MED / reject
- There are **4** SPI CS consumers (MCP3008=26, DAC=12, dpot=13, TFT=CE0/8) but only **2**
  hardware CE lines, and **CE0 is already the TFT's** [V1 §5]. Plus the **Pi 5 RP1 rejects
  `SPI_NO_CS`** and CE0 strobes even when bit-banging [memory: pi5-spi-nocs-limitation].
  At best you move one device to CE1/GPIO7, freeing one bit-bang pin — marginal, and the
  bit-banged-CS path is itself a test target. **Recommend reject.**

### R8 — GPIO0/1  ·  freed: 0 real  ·  skip
- Used only as generic idle-high pins; reserved I2C0 ID-EEPROM, best left unrouted
  [tmpl §9]. Not carrying a fixture — no relief to gain.

---

## Ranked shortlist (value ÷ risk)

Updated after the R2 rejection (user 2026-07-12): the parallel LCD stays native GPIO.

| # | Strategy | Header pins freed | Risk | Needs |
|---|----------|-------------------|------|-------|
| 1 | **R3** centre LED (GPIO19) → 0x21 expander | **1** | LOW | small test/driver change; uses the user's own MCP23017 lib |
| 2 | **R1** ✅ radar off GPIO26 → 7 | 0 (resolves conflict) | ~0 | done in t/361 (interim; bench) |
| — | **R4** TFT BLK/RES → expander/tie-off | up to 2 (**bench only**) | MED | TFT expander-pin support (F-a) or coverage drop |
| ✗ | **R2** parallel LCD → expander/backpack | — | — | **REJECTED** — LCD tests the native parallel path by design |
| ⊘ | **R5** stepper limits off 17/27 | 0 | — | **MOOT** — LCD keeps 17/27 |
| — | R6 74HC595, R7 SPI-CS, R8 GPIO0/1 | — | — | **reject / low value** |

## Net budget (revised)

- **Free header pins today:** 1 (GPIO7/CE1) [V2].
- **Realistic fabbed-board relief:** ~**+1** (GPIO19 via R3), plus R1 resolves the GPIO26
  conflict (net 0 pins). The earlier ~+5 estimate assumed R2, which the user has ruled out.
- **Bench-only (doesn't help the fabbed-board budget):** R4 can trim the TFT to 2 header
  pins (frees 23/24) if you add expander support or tie BLK/RES off.
- **Irreducible floor (never free without dropping a library feature under test):**
  2/3 (I2C), 9/10/11 (SPI), 14/15 (UART), 18 (PWM/servo/native-interrupt), the software-CS
  12/13/26, the 74HC595 GPIO 16/20/21, **and the parallel LCD 4/5/6/17/22/27** (tests the
  native `lcd_init` path — user decision).
- **Bottom line:** this platform is near-fully-subscribed *on purpose*. The main honest
  relief is R3 (one pin, clean, via your own library) + R1 (hygiene).

## Open items to verify before implementing (do-not-guess flags)
- **F-a:** Does the ST7735S driver accept an expander/virtual pin for `bl`/`rst`? (R4)
- **F-b:** Does `shift_register()` accept expander pins? (R6 — only matters if pursued)
- **F-c:** MCP23017 INT→Pi-GPIO wiring + `background_interrupt` rework (R5 — now moot).
- **F-d:** ✅ RESOLVED — `RPi::LCD` is a thin wrapper over wiringPi's C `lcd_init`
  (`LCD.pm:8,34`); the HD44780 protocol bit-bangs in C and can only reach native pins or
  wiringPi extension nodes. No `mcp23017Setup` is exposed, and the user's own MCP23017 lib
  can't be injected without reimplementing HD44780 in Perl. This (plus the design intent to
  test the native path) is why R2 is rejected.
