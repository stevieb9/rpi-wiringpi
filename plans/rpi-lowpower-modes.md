# Plan: Expose & test low-power / sleep modes across the RPi device family

> **NEXT ACTION:** V1 — add a coil de-energize method to RPi::StepperMotor
> **LAST SESSION:** 2026-07-16 — audited all 19 device dists behind rpi-wiringpi for hardware low-power modes; authored this plan. No implementation started.
> **ARCHIVE:** See rpi-lowpower-modes-archive.md for completed V tasks

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of rpi-lowpower-modes-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
  3. **Delete the V# row from this file's Validation Table.**
- V task ❌: update Actual with `❌ YYYY-MM-DD attempt N: reason`. Rerun same V# with attempt N+1. Do NOT create a new V#.
- **Sync review findings** — when a V task (or a Fix) resolves a review finding, mark its `F#` entry in `## Review Findings` **in place**: prefix `✅ RESOLVED (V#)` (or `✅ VALIDATED (V#)` if no code change was needed, or `⏸ DEFERRED → B#` if punted to backlog). Findings are a permanent audit ledger of what review surfaced and where it was handled — mark in place; never archive, delete, or renumber them.
- Update ARCHIVE pointer to reflect what's archived (e.g., `V1-V2` → `V1-V3`)
- Update NEXT ACTION to next ⏳ row; update LAST SESSION
- Never renumber within a series. New items get next free number.
- **Discovery triage during V# work** — when you find something while working a V task, classify before continuing:
  - Blocks the current V task → add `Fix N: problem discovered during V# — [what + fix]` to `## Discovery Tracking`; resolve as part of this V task's work.
  - Real bug but doesn't block this V task → add a new V# row (next free) to the Validation Table with ⏳; do not detour to fix it now.
  - Non-blocking improvement → add new B# to `## Backlog` (one `B#` per line, each separated by a blank line — never run two entries together, or Markdown collapses them into a single mashed paragraph).
  - Decided not to do → add to `## Explicitly NOT doing` with a one-line justification.
- Move resolved fixes to archive's "Archived Fixes" section; keep only unresolved in main Discovery Tracking
- To promote a backlog item to an active task: assign it the next free V# (e.g., B3 becomes V4) and move to the Validation Table. The B# slot is retired and never reused.

## Context

Prompted by adding `off()` (all_off + sleep) to RPi::PWM::PCA9685 this session. An audit of the whole rpi-wiringpi device family asked, per device: does the hardware have a low-power/sleep/standby/shutdown mode, does the driver expose a method for it, and do the rpi-wiringpi tests exercise it? This plan covers only the **actionable gaps** — capabilities that are real but unexposed (add a method), or exposed but unverified (add a test). Devices already covered, and devices with no actionable hardware mode, are recorded under Review Findings / Explicitly NOT doing so the audit is complete in one place.

Each V task follows the PCA9685 precedent set this session: add the method + its POD + a `Changes` entry in the device's own repo, then add/extend an assertion in the corresponding rpi-wiringpi test. Per-repo git rules apply (never commit; work in place in each repo). Most device hardware tests in rpi-wiringpi are env-gated (`RPI_*`); off-board, verification is compile + POD-coverage + the dist's own unit tests + the unit portion of the rpi-wiringpi test.

## Validation Table

| ID | What | Command | Expected | Actual |
|----|------|---------|----------|--------|
| V1 | RPi::StepperMotor (repo rpi-steppermotor): add a coil de-energize method (e.g. `off()`/`release()`) that drives all IN pins LOW via the existing expander-or-direct path in `_engage_motor`, WITHOUT flipping them to INPUT (so the motor stays usable, unlike `cleanup()`). POD + Changes. Assert in rpi-wiringpi t/352-steppermotor_unit.t that all four coil pins read LOW after the call and remain OUTPUT. | `perl -c ~/repos/rpi-steppermotor/lib/RPi/StepperMotor.pm && prove -l ~/repos/rpi-wiringpi/t/352-steppermotor_unit.t` | Module compiles; unit test asserts all four coil pins driven LOW after the call and still in OUTPUT mode | ⏳ |
| V2 | RPi::OLED::SSD1306::128_64 (repo rpi-oled-ssd1306): add display sleep/wake (e.g. `sleep()`/`wake()` or `display_off()`/`display_on()`) issuing 0xAE / 0xAF plus charge-pump 0x8D via the **already-exposed** `ssd1306_command` XS binding (128_64.xs:35) — no XS recompile needed. POD + Changes. Assert in t/510-oled_unit.t (method presence + return). | `cd ~/repos/rpi-oled-ssd1306 && perl Makefile.PL >/dev/null && make >/dev/null 2>&1 && prove -lb t/510-oled_unit.t` | New sleep/wake methods issue the 0xAE/0xAF (+ charge-pump) commands; unit test passes | ⏳ |
| V3 | RPi::TFT::ST7735S (repo rpi-tft-st7735s): add `sleep()`/`wake()` via `_command(SLPIN 0x10)` / `_command(SLPOUT 0x11)` with the datasheet ~120 ms settle delays — the deeper power-down distinct from the existing panel-blank `off()`/`on()` (DISPOFF/DISPON). POD + Changes. Assert in t/447-tft_st7735s.t (return values). | `perl -c ~/repos/rpi-tft-st7735s/lib/RPi/TFT/ST7735S.pm && prove -l ~/repos/rpi-wiringpi/t/447-tft_st7735s.t` (hw-gated) | sleep() sends SLPIN, wake() sends SLPOUT with settle delay; test asserts both return true | ⏳ |
| V4 | RPi::ADC::ADS: test-only gap. Add an assertion in rpi-wiringpi t/421-adc_gain.t (or a new t/) that the default single-shot mode is the power-down state and that `mode()` toggles the config-register MODE bit (0x100), read back over I2C. No driver change expected. | `prove -l ~/repos/rpi-wiringpi/t/421-adc_gain.t` (under RPI_ADS / hw) | Test asserts MODE bit = single-shot (power-down) by default and continuous when `mode(0)` set, via config readback | ⏳ |
| V5 | RPi::DAC::MCP4922: test-only gap. Add a rpi-wiringpi hardware test (extend t/410-dac.t) asserting `disable_sw()` and `disable_hw()` collapse Vout toward 0 and `enable_*()` restores it, measured via an ADC readback (mirroring the digipot shutdown test t/445-dpot.t). No driver change expected. | `prove -l ~/repos/rpi-wiringpi/t/410-dac.t` (under RPI_MCP4922 / hw with ADC wiring) | Measured output near 0 after shutdown, restored after enable | ⏳ |

## Discovery Tracking

_None yet._

## Review Findings

Audit ledger — every device checked. `(→V#/B#)` points to where a gap is handled; N/A and already-covered devices are recorded for completeness.

**Actionable — add a method (capability exists, unexposed):**
- **F1** (→V1): RPi::StepperMotor — coils stay energized (last phase pins HIGH) after every move; no release/off method to de-energize and cool the coils. `cleanup()` only de-energizes as teardown (also flips pins to INPUT).
- **F2** (→V2): RPi::OLED::SSD1306::128_64 — SSD1306 display-off 0xAE (+ charge-pump off) is a genuine ~µA sleep; no method issues it. `dim()` only sets contrast. Reusable `ssd1306_command` XS binding already exists.
- **F3** (→V3): RPi::TFT::ST7735S — SLPIN (0x10) true sleep is a defined-but-unused constant; only DISPOFF/DISPON (panel blank) are exposed via off()/on(). The deeper low-power command has no method and no test.

**Actionable — add a test (method exists, power state unverified):**
- **F4** (→V4): RPi::ADC::ADS — `mode()` selects single-shot (delta-sigma powers down between reads), but the one test uses `mode => 0` only to prove non-leak into gain; the power-down/single-shot state is never asserted.
- **F5** (→V5): RPi::DAC::MCP4922 — `disable_sw`/`enable_sw`/`disable_hw`/`enable_hw` (SHDN bit 12 + SHDN pin) exist but are only hit in error-path unit tests; no test asserts a real output drop.

**Peripheral — deferred to backlog:**
- **F6** (→B1): RPi::RTC::DS3231 — EOSC (0x0E bit 7, stop oscillator on VBAT) and EN32kHz (0x0F bit 3, disable 32 kHz output) battery-conservation bits are unexposed and untested. Not a device sleep; battery-life nicety.
- **F7** (→B2): RPi::Gyro::MPU6050 — core `sleep()`/`wake()`/`reset()` are done and tested (t/358-gyro.t), but CYCLE low-power mode and PWR_MGMT_2 per-axis standby are reachable only via `register()`.

**Already covered — no action:**
- RPi::PWM::PCA9685 — `off()` (all_off + sleep) added this session, tested in t/440-pca9685.t.
- RPi::Gyro::MPU6050 — `sleep()`/`wake()`/`reset()` tested in t/358-gyro.t.
- RPi::StepperMotor::A4988 — `sleep()`/`wake()` + `enable()`/`disable()` (SLEEP/ENABLE pins) tested in t/353-a4988.t, t/354-a4988_unit.t.
- RPi::DigiPot::MCP4XXXX — `shutdown()` tested in t/445-dpot.t, t/446-dpot_unit.t.
- RPi::TFT::ST7735S — panel-blank `off()`/`on()` tested in t/447-tft_st7735s.t (the SLPIN sleep gap is F3).

**No actionable hardware low-power mode (N/A):**
- RPi::ADC::MCP3008 — standby (~5 nA) is automatic when CS deasserts after each frame; no command to expose.
- RPi::Accelerometer::ADXL335 — analog part, no bus/registers, no sleep state.
- RPi::BMP180 — on-demand measurement; only a soft-reset (0xE0) register, no sleep bit.
- RPi::LCD — HD44780 display on/off is a visibility bit, not low power (backlight is a separate GPIO).
- RPi::GPIOExpander::MCP23017 — ~1 µA standby is a passive spec; no sleep register.
- RPi::EEPROM::AT24C32 — standby is automatic on bus idle; no command.
- RPi::DHT11, RPi::HCSR04, RPi::Radar::RCWL0516 — dumb sensors, no sleep/standby command.

## Backlog

B1: RPi::RTC::DS3231 — expose EOSC (0x0E bit 7) and EN32kHz (0x0F bit 3) battery-conservation bits with reader/writer methods; add coverage.

B2: RPi::Gyro::MPU6050 — wrap CYCLE low-power mode (PWR_MGMT_1 bit 5) and PWR_MGMT_2 per-axis standby, currently reachable only via register().

## Explicitly NOT doing

- Mass-renaming existing APIs for cross-family naming consistency (off / sleep / shutdown / disable / release all coexist) — each dist keeps its idiomatic verb; renaming would break published interfaces for a cosmetic win.
- RPi::ADC::MCP3008 low-power method — standby is intrinsic to CS deasserting after each conversion; the chip has no addressable power-down command, so there is nothing to expose.
- RPi::LCD display() power test — it toggles character visibility, not controller power; out of scope for a low-power audit (its lack of test coverage is a separate, minor matter).
- ADXL335 / BMP180 / DHT11 / HCSR04 / RCWL0516 / MCP23017 / AT24C32 — no software-invocable hardware low-power mode exists to expose or test.
