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
- **Reducible — the pin drives a peripheral that could ride I2C/an expander instead,
  or duplicates coverage.** Displays, indicator LEDs, sensor sensing, and the parallel
  LCD (which duplicates the I2C LCD's driver coverage). This is where the pins are.

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

### R1 — Move the radar OUT off GPIO26  ·  freed: resolves the only conflict (net 0)  ·  risk: ~0
- Now: radar OUT defaults to **GPIO26**, colliding with the MCP3008 bit-banged CS
  [V1 K1; t/361:65]. The driver has **no** built-in default and the pin is env-settable
  (`RPI_RADAR_PIN`) [RCWL0516.pm:27-28], so 26 is purely the test file's choice.
- Do: change the `t/361` default to the one free header pin **GPIO7/CE1** (or any pin
  freed below). One-line test change; no driver change.
- Effect: doesn't increase the free count, but lets radar + MCP3008 co-exist and stops
  a live-header conflict. **The cheapest, safest item — do it regardless.**

### R2 — Convert the board-5 parallel HD44780 to an I2C backpack  ·  freed: 4 (+ de-conflict 2)  ·  risk: LOW*
- Now: the parallel LCD (t/620) burns **6** pins: **4/5/6/22** dedicated + **17/27**
  shared with the stepper limits [V1; tmpl §6]. It's the single largest reducible
  consumer.
- Proven alternative: the **I2C LCD** (t/335, HD44780 behind a **PCF8574 @0x27**) drives
  the *same* `RPi::LCD` module over I2C with **zero** Pi GPIO — and it already passes
  [V1 t/335; tmpl §6 note].
- Do: re-wire board 5's LCD to a PCF8574 backpack (you've OK'd board changes).
- Effect: frees **4/5/6/22** outright; **17/27** become stepper-limit-only (no longer a
  shared net → removes collision K5). **Biggest single win.**
- *Coverage cost (your call, V8):* `RPi::LCD`'s *native-GPIO 4-bit* path is only covered
  by t/620. Options: (a) drop t/620 and accept I2C-only LCD coverage; (b) keep t/620 but
  move its 6 lines onto an MCP23017 (parallel-over-expander) — costs an expander, keeps
  the driver's parallel path exercised, still frees the *header* pins.

### R3 — Move the stepper centre LED (GPIO19) onto an expander  ·  freed: 1  ·  risk: LOW
- Now: **GPIO19** is a plain indicator LED pulsed by a `worker` fork [V1 t/350:143; tmpl §8].
- An LED is the ideal low-frequency expander load (the A4988 precedent proves outputs work).
  Board 3 already has MCP23017s on the bus — add the LED to a spare expander pin.
- Effect: frees **19**. Small driver-side change (drive the LED via the expander object);
  the stepper test already talks to an expander, so the plumbing exists.

### R4 — Move the TFT BLK + RES (GPIO23/24) off the header  ·  freed: up to 2  ·  risk: MEDIUM
- Now: the bench TFT uses **8**(CE0/CS), **25**(D/C), **24**(RES), **23**(BLK) [V1 t/447].
  CS(CE0) and D/C are timing-critical (D/C toggles per command) → keep on the header.
  **BLK (backlight) and RES (reset) are low-frequency** → movable.
- Do, either: (a) drive BLK/RES from an MCP23017 — needs the TFT driver to accept an
  expander/virtual pin for `bl`/`rst` (**code change, unverified — flag**); or (b) tie
  BLK high (always-on backlight) and RES to a shared reset/RC — frees the pins but drops
  the `backlight()`/reset test coverage.
- Effect: frees **23/24**; TFT shrinks to 2 header pins (CS + D/C).

### R5 — Move the stepper CW/CCW limit switches (GPIO17/27) onto an expander  ·  freed: 2 (post-R2)  ·  risk: MED-HIGH
- Now: **17/27** read magnetic limit switches via the Pi's **native `background_interrupt`**
  [V1 t/350:148,152,157,163]. (Pre-R2 they're shared with the LCD; post-R2 they're
  stepper-only.)
- MCP23017 has its own INT output, but moving these loses the *native* Pi-interrupt path
  the test exercises — you'd route the expander INT to one Pi GPIO and rework the test's
  interrupt handling (**test + wiring change**). This partly defeats the purpose (the test
  is partly *about* native background interrupts).
- Effect: frees **17/27** but trades native-interrupt coverage. Lower priority than R1–R4.

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

| # | Strategy | Header pins freed | Risk | Needs |
|---|----------|-------------------|------|-------|
| 1 | **R1** radar off GPIO26 | 0 (resolves conflict) | ~0 | 1-line test default |
| 2 | **R2** parallel LCD → I2C backpack | **4** (+de-conflict 17/27) | LOW* | board-5 re-wire; coverage decision |
| 3 | **R3** centre LED → expander | 1 | LOW | small driver change (expander already present) |
| 4 | **R4** TFT BLK/RES → expander or tie-off | up to 2 | MED | TFT expander-pin support (unverified) or coverage drop |
| 5 | **R5** stepper limits → expander INT | 2 | MED-HIGH | test rework; trades native-interrupt coverage |
| — | R6 74HC595, R7 SPI-CS, R8 GPIO0/1 | — | — | **reject / low value** (coverage-defeating or marginal) |

## Net budget

- **Free header pins today:** 1 (GPIO7/CE1) [V2].
- **Low-risk, minimal-coverage-loss (R1+R2+R3):** ~**+5** header pins (GPIO4/5/6/22 + 19),
  and the header stops being over-subscribed. R2 is ~80% of the win.
- **If you also accept coverage/rework trades (R4+R5):** up to **+4** more (23/24 + 17/27),
  i.e. ~**9–10** pins reclaimable in total.
- **Irreducible floor (never free without dropping a library feature under test):**
  2/3 (I2C), 9/10/11 (SPI), 14/15 (UART), 18 (PWM/servo/native-interrupt), and the
  software-CS / shift-register GPIO the tests exist to prove.

## Open items to verify before implementing (do-not-guess flags)
- **F-a:** Does the ST7735S driver accept an expander/virtual pin for `bl`/`rst`? (R4)
- **F-b:** Does `shift_register()` accept expander pins, and is I2C-bit-banged shifting
  acceptable? (R6 — only matters if pursued)
- **F-c:** MCP23017 INT→Pi-GPIO wiring + `background_interrupt` rework for R5.
- **F-d:** If R2 keeps t/620 via an expander, confirm `RPi::LCD` parallel mode accepts
  virtual pins (the PCF8574 path suggests yes, but the *parallel* constructor path is
  separate — verify).
