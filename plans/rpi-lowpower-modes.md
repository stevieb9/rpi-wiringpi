# Plan: Expose & test low-power / sleep modes across the RPi device family, and park every device in it at test teardown

> **NEXT ACTION:** V1 — add a coil de-energize method to RPi::StepperMotor
> **LAST SESSION:** 2026-07-16 — audited all 19 device dists for low-power modes AND audited t/ teardown hygiene (which state each device is left in at object end-of-scope). Added the teardown requirement to V1–V5 and new tasks V6–V8. No implementation started.
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

**Teardown hygiene (added dimension).** A second audit checked what state each device is left in when its object goes out of scope at the end of its test file — to stop leaving hardware drawing full current on the bench after a run. The finding: only t/440-pca9685.t parks its device (ends in `off()`); the rest leave the device powered even when a working, tested low-power method exists (t/358 ends awake after `reset()`; t/353 ends awake+enabled after `wake()`/`reset()`; t/447 ends with the panel `on()`; t/410 leaves the DAC driving; t/445 brings the pot back out of `shutdown()`). So **every device that has — or will have, after this plan — a low-power method must be left in it just before teardown** (before `close()`/`cleanup()`, and inside the `$cleanup` closure where one exists so a mid-test die still parks it). This requirement is folded into V1–V5 for the devices they touch, and V6–V8 cover devices whose method already ships and only need the teardown call. PCA9685 (t/440) is already compliant and is the reference pattern.

## Validation Table

| ID | What | Command | Expected | Actual |
|----|------|---------|----------|--------|
| V1 | RPi::StepperMotor (repo rpi-steppermotor): add a coil de-energize method (e.g. `off()`/`release()`) that drives all IN pins LOW via the existing expander-or-direct path in `_engage_motor`, WITHOUT flipping them to INPUT (so the motor stays usable, unlike `cleanup()`). POD + Changes. Assert in rpi-wiringpi t/352-steppermotor_unit.t that all four coil pins read LOW after the call and remain OUTPUT. **Teardown:** call the new method in t/350-stepper.t before `cleanup()` so coils are de-energized at exit. | `perl -c ~/repos/rpi-steppermotor/lib/RPi/StepperMotor.pm && prove -l ~/repos/rpi-wiringpi/t/352-steppermotor_unit.t` | Module compiles; unit test asserts all four coil pins driven LOW after the call and still in OUTPUT mode; t/350 parks coils off at teardown | ⏳ |
| V2 | RPi::OLED::SSD1306::128_64 (repo rpi-oled-ssd1306): add display sleep/wake (e.g. `sleep()`/`wake()` or `display_off()`/`display_on()`) issuing 0xAE / 0xAF plus charge-pump 0x8D via the **already-exposed** `ssd1306_command` XS binding (128_64.xs:35) — no XS recompile needed. POD + Changes. Assert in t/510-oled_unit.t (method presence + return). **Teardown:** call the new sleep method at the end of the OLED test file(s) (t/50x) before the object drops, so the panel/charge-pump is off at exit. | `cd ~/repos/rpi-oled-ssd1306 && perl Makefile.PL >/dev/null && make >/dev/null 2>&1 && prove -lb t/510-oled_unit.t` | New sleep/wake methods issue the 0xAE/0xAF (+ charge-pump) commands; unit test passes; OLED test parks the display asleep at teardown | ⏳ |
| V3 | RPi::TFT::ST7735S (repo rpi-tft-st7735s): add `sleep()`/`wake()` via `_command(SLPIN 0x10)` / `_command(SLPOUT 0x11)` with the datasheet ~120 ms settle delays — the deeper power-down distinct from the existing panel-blank `off()`/`on()` (DISPOFF/DISPON). POD + Changes. Assert in t/447-tft_st7735s.t (return values). **Teardown:** t/447 currently ends with the panel `on()`; change its `$cleanup` closure to `off()` then `sleep()` (SLPIN) so the panel is left in true low power at exit. | `perl -c ~/repos/rpi-tft-st7735s/lib/RPi/TFT/ST7735S.pm && prove -l ~/repos/rpi-wiringpi/t/447-tft_st7735s.t` (hw-gated) | sleep() sends SLPIN, wake() sends SLPOUT with settle delay; test asserts both return true; t/447 leaves the panel asleep at teardown | ⏳ |
| V4 | RPi::ADC::ADS: test-only gap. Add an assertion in rpi-wiringpi t/421-adc_gain.t (or a new t/) that the default single-shot mode is the power-down state and that `mode()` toggles the config-register MODE bit (0x100), read back over I2C. No driver change expected. **Teardown:** ensure t/421 (and t/405-pwm_i2c_adc.t) leave the ADS in single-shot (its power-down default), not continuous, before teardown. | `prove -l ~/repos/rpi-wiringpi/t/421-adc_gain.t` (under RPI_ADS / hw) | Test asserts MODE bit = single-shot (power-down) by default and continuous when `mode(0)` set, via config readback; ADS left in single-shot at teardown | ⏳ |
| V5 | RPi::DAC::MCP4922: test-only gap. Add a rpi-wiringpi hardware test (extend t/410-dac.t) asserting `disable_sw()` and `disable_hw()` collapse Vout toward 0 and `enable_*()` restores it, measured via an ADC readback (mirroring the digipot shutdown test t/445-dpot.t). No driver change expected. **Teardown:** t/410 currently leaves the DAC driving its last `set()` value; add `disable_sw()` (or `disable_hw()`) before `$pi->cleanup` so both DACs are shut down at exit. | `prove -l ~/repos/rpi-wiringpi/t/410-dac.t` (under RPI_MCP4922 / hw with ADC wiring) | Measured output near 0 after shutdown, restored after enable; DAC left shut down at teardown | ⏳ |
| V6 | RPi::Gyro::MPU6050 teardown (method already ships + tested): t/358-gyro.t ends AWAKE because the last power op is `reset()` (re-inits to the awake PLL state) and the `$cleanup` closure only does `$mpu->close`. Add `$mpu->sleep` inside the `$cleanup` closure (before `close`), so the IMU is left asleep (~10 µA vs ~3.9 mA) however the file exits. No driver change. | `prove -l ~/repos/rpi-wiringpi/t/358-gyro.t` (under RPI_MPU6050 / hw) | Gyro left with PWR_MGMT_1 SLEEP set at teardown; test still passes | ⏳ |
| V7 | RPi::StepperMotor::A4988 teardown (methods already ship + tested): t/353-a4988.t ends AWAKE+ENABLED after `wake()`/`reset()`; the `$cleanup` closure does `$motor->cleanup` (releases pins, does not guarantee SLEEP low). Add `$motor->sleep` (and/or `$motor->disable`) inside the `$cleanup` closure before `$motor->cleanup`, so the driver is powered down at exit. No driver change. | `prove -l ~/repos/rpi-wiringpi/t/353-a4988.t` (under RPI_A4988 / hw) | A4988 SLEEP pin driven low at teardown; test still passes | ⏳ |
| V8 | RPi::DigiPot::MCP4XXXX teardown (method already ships + tested): t/445-dpot.t brings the pot back out of shutdown with `set(0)` after the shutdown assertion, leaving the resistor network drawing current. Add a final `$pot->shutdown($pot_select)` for each pot just before `$pi->cleanup`, so both pots end in their lowest-power (A-terminal-open) state. No driver change. | `prove -l ~/repos/rpi-wiringpi/t/445-dpot.t` (under RPI_MCP4XXXX / hw) | Both pots left in shutdown at teardown; test still passes | ⏳ |

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

**Actionable — teardown hygiene (device left drawing current at test end-of-scope):**
- **F8** (→V6): t/358-gyro.t leaves the MPU-6050 AWAKE — the last power op is `reset()` (re-inits to the awake PLL state) and the `$cleanup` closure only calls `$mpu->close`. ~3.9 mA vs ~10 µA asleep.
- **F9** (→V7): t/353-a4988.t leaves the A4988 AWAKE+ENABLED (`wake()` then `reset()`); the `$cleanup` closure's `$motor->cleanup` releases pins but does not drive SLEEP low.
- **F10** (→V3): t/447-tft_st7735s.t leaves the ST7735S panel ON (last op `on()`); the `$cleanup` closure's `$tft->cleanup` does not blank or sleep the panel.
- **F11** (→V5): t/410-dac.t leaves the MCP4922 driving its last `set()` output; teardown is `undef $adc; $pi->cleanup` with no DAC shutdown.
- **F12** (→V8): t/445-dpot.t explicitly brings the pot back OUT of shutdown with `set(0)` after the shutdown assertion, leaving the resistor network powered.
- **F13** (→V4): t/421-adc_gain.t / t/405-pwm_i2c_adc.t exercise `mode()` (continuous) without restoring the ADS to its single-shot power-down default at teardown.

**Peripheral — deferred to backlog:**
- **F6** (→B1): RPi::RTC::DS3231 — EOSC (0x0E bit 7, stop oscillator on VBAT) and EN32kHz (0x0F bit 3, disable 32 kHz output) battery-conservation bits are unexposed and untested. Not a device sleep; battery-life nicety.
- **F7** (→B2): RPi::Gyro::MPU6050 — core `sleep()`/`wake()`/`reset()` are done and tested (t/358-gyro.t), but CYCLE low-power mode and PWR_MGMT_2 per-axis standby are reachable only via `register()`.

**Method + test already covered (but see teardown findings above):**
- RPi::PWM::PCA9685 — `off()` (all_off + sleep) added this session, tested in t/440-pca9685.t; **teardown already compliant** (t/440 ends in `off()`) — the reference pattern.
- RPi::Gyro::MPU6050 — `sleep()`/`wake()`/`reset()` tested in t/358-gyro.t; teardown gap F8 → V6.
- RPi::StepperMotor::A4988 — `sleep()`/`wake()` + `enable()`/`disable()` (SLEEP/ENABLE pins) tested in t/353-a4988.t, t/354-a4988_unit.t; teardown gap F9 → V7.
- RPi::DigiPot::MCP4XXXX — `shutdown()` tested in t/445-dpot.t, t/446-dpot_unit.t; teardown gap F12 → V8.
- RPi::TFT::ST7735S — panel-blank `off()`/`on()` tested in t/447-tft_st7735s.t (the SLPIN sleep gap is F3; teardown gap F10 → V3).

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
