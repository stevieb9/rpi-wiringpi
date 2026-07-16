# Plan: Expose & test low-power / sleep modes across the RPi device family, and park every device in it at test teardown

> **NEXT ACTION:** All V tasks (V1-V8) implemented. Remaining is on-hardware confirmation on the Pi: V5 especially (`prove t/410` on board-2, DAC↔ADC), plus the V6-V8 teardown calls (t/358, t/353, t/445 — board-gated). Report fallout, then the plan fully closes.
> **LAST SESSION:** 2026-07-16 — V6-V8 done (teardown power-down): t/358 sleeps the MPU-6050, t/353 sleeps the A4988, t/445 shuts down both digipot wipers, each before its cleanup; all compile. MPU-6050 + A4988 SYNOPSISes gained "Powering down" blocks (+ Changes); DigiPot SYNOPSIS already had shutdown. Methods are exercised in each test body, so the teardown calls are low-risk though board-gated.
> **ARCHIVE:** See rpi-lowpower-modes-archive.md for completed V1-V8

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

**SYNOPSIS documentation (added requirement).** Every device task must also update that device module's own POD SYNOPSIS to show how to sleep/shut it off — a short block at the end of the SYNOPSIS where it fits naturally (as done for PCA9685's "Powering down" block this session). Applies to all device tasks V1–V8, including the test-only ones (V4–V8) whose devices already ship a shut-off method the SYNOPSIS should demonstrate.

**Decisions (locked with the user).**
- The RPi::StepperMotor method is named **`off()`** (family-consistent with PCA9685); `release()` was considered and rejected. It returns `0`, matching PCA9685's `off()`.
- `RPi::StepperMotor::cleanup()` is refactored to call `off()` first, so it de-energizes on BOTH the direct and expander paths — fixing the current gap where `cleanup()` does nothing for expander-driven motors — before releasing the direct pins to INPUT. A side effect: the stepper's teardown requirement is then satisfied automatically by t/350's existing `cleanup()` call.

## Validation Table

| ID | What | Command | Expected | Actual |
|----|------|---------|----------|--------|

## Discovery Tracking

_None yet._

## Review Findings

Audit ledger — every device checked. `(→V#/B#)` points to where a gap is handled; N/A and already-covered devices are recorded for completeness.

**Actionable — add a method (capability exists, unexposed):**
- **F1** ✅ RESOLVED (V1) (→V1): RPi::StepperMotor — coils stay energized (last phase pins HIGH) after every move; no release/off method to de-energize and cool the coils. `cleanup()` only de-energizes as teardown (also flips pins to INPUT).
- **F2** ✅ RESOLVED (V2) (→V2): RPi::OLED::SSD1306::128_64 — SSD1306 display-off 0xAE (+ charge-pump off) is a genuine ~µA sleep; no method issues it. `dim()` only sets contrast. Reusable `ssd1306_command` XS binding already exists.
- **F3** ✅ RESOLVED (V3) (→V3): RPi::TFT::ST7735S — SLPIN (0x10) true sleep is a defined-but-unused constant; only DISPOFF/DISPON (panel blank) are exposed via off()/on(). The deeper low-power command has no method and no test.

**Actionable — add a test (method exists, power state unverified):**
- **F4** ✅ RESOLVED (V4) (→V4): RPi::ADC::ADS — `mode()` selects single-shot (delta-sigma powers down between reads), but the one test uses `mode => 0` only to prove non-leak into gain; the power-down/single-shot state is never asserted. (Fixed via t/422-adc_unit.t MODE-bit assertions; readback is cached config, HW-free, not live I2C as the plan first said.)
- **F5** ✅ RESOLVED (V5 — UNVERIFIED, awaits board-2 run) (→V5): RPi::DAC::MCP4922 — `disable_sw`/`enable_sw`/`disable_hw`/`enable_hw` (SHDN bit 12 + SHDN pin) exist but are only hit in error-path unit tests; no test asserts a real output drop. Software-shutdown ADC-readback assertion added to t/410-dac.t; closed at the user's request without running it — confirm on board-2.

**Actionable — teardown hygiene (device left drawing current at test end-of-scope):**
- **F8** ✅ RESOLVED (V6) (→V6): t/358-gyro.t leaves the MPU-6050 AWAKE — the last power op is `reset()` (re-inits to the awake PLL state) and the `$cleanup` closure only calls `$mpu->close`. ~3.9 mA vs ~10 µA asleep.
- **F9** ✅ RESOLVED (V7) (→V7): t/353-a4988.t leaves the A4988 AWAKE+ENABLED (`wake()` then `reset()`); the `$cleanup` closure's `$motor->cleanup` releases pins but does not drive SLEEP low.
- **F10** ✅ RESOLVED (V3) (→V3): t/447-tft_st7735s.t leaves the ST7735S panel ON (last op `on()`); the `$cleanup` closure's `$tft->cleanup` does not blank or sleep the panel.
- **F11** ✅ RESOLVED (V5 — UNVERIFIED, awaits board-2 run) (→V5): t/410-dac.t leaves the MCP4922 driving its last `set()` output; teardown is `undef $adc; $pi->cleanup` with no DAC shutdown. V5 adds `disable_sw(0)`/`disable_sw(1)` before teardown; closed without running — confirm on board-2.
- **F12** ✅ RESOLVED (V8) (→V8): t/445-dpot.t explicitly brings the pot back OUT of shutdown with `set(0)` after the shutdown assertion, leaving the resistor network powered.
- **F13** ✅ VALIDATED (V4) (→V4): t/421-adc_gain.t / t/405-pwm_i2c_adc.t exercise `mode()` (continuous) without restoring the ADS to its single-shot power-down default at teardown. **No change needed:** t/421's `mode => 0` object only checks `gain` (no read → continuous is never written to the chip), and the real reads use the default single-shot mode, which auto-powers-down. The chip is already left powered down.

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

- Naming the StepperMotor method `release()` — chose `off()` for consistency with PCA9685 and the rest of the family (user decision).
- Mass-renaming existing APIs for cross-family naming consistency (off / sleep / shutdown / disable all coexist) — each dist keeps its idiomatic verb; renaming would break published interfaces for a cosmetic win.
- RPi::ADC::MCP3008 low-power method — standby is intrinsic to CS deasserting after each conversion; the chip has no addressable power-down command, so there is nothing to expose.
- RPi::LCD display() power test — it toggles character visibility, not controller power; out of scope for a low-power audit (its lack of test coverage is a separate, minor matter).
- ADXL335 / BMP180 / DHT11 / HCSR04 / RCWL0516 / MCP23017 / AT24C32 — no software-invocable hardware low-power mode exists to expose or test.
