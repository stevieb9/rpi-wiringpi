# Plan: Make rpi-wiringpi/t/ the canonical test suite for the whole RPi:: stack

> **NEXT ACTION:** V1 — rpi-const: add HW-free value assertions for the two zero-coverage tags `:altmode` and `:mcp23017_pins`, make `:all` exhaustive, add a tag-importability loop.
> **LAST SESSION:** 2026-06-23 — Reframed after user guidance: rpi-wiringpi/t/ is the canonical aggregate suite (it already mirrors eeprom/rtc-bcd/oled/sysinfo and hardware-drives most devices), so the goal is *mirror absent sub-repo tests here + fill HW-free unit gaps + fix surfaced bugs* — NOT re-test what integration already validates. Audited all 20 RPi:: dists (11 newly cloned via `git@github.com:stevieb9/…`) + WiringPi::API → V1–V22, findings F1–F16. Excluded deprecated RPi::WiringPi::Constant.
> **ARCHIVE:** See test-coverage-gaps-archive.md for completed V tasks

## Goal & guiding principles

**rpi-wiringpi/t/ is the canonical home for the stack's tests.** The driver dists ship mostly boilerplate `t/`; the real coverage lives here, where the suite drives the devices on real hardware. Three principles (from the user) govern every V task:

1. **Mirror, don't conflict.** Any test that exists in a sub-repo and isn't already here should be **duplicated into rpi-wiringpi/t/** — *unless* it's already present here or would conflict with this repo's tests (its gating, the shared `rpit` shm segment, the absolute object/pin counts in t/110-114, or naming). Precedent already set: EEPROM (`t/420-422`), RTC-BCD (`t/321`), OLED (`t/500-509`), SysInfo (`t/400-409`) were moved/mirrored here.
2. **Credit integration coverage — don't re-flag it.** The suite already passes real values through most devices on hardware (see the map below), so a device "having no unit test in its own repo" does NOT mean it's untested. The genuine gap is **HW-free unit assertions** (arg-validation/croak paths, pure math, framing logic) and **bug-pinning** that the hardware-gated integration tests don't exercise.
3. **De-gate the HW-free parts.** Most mirrored device tests `skip_all` on a hardware env var (`RPI_OLED`, `RPI_EEPROM`, …) and assert return values, so even mirrored validation doesn't run off-board. HW-free assertions should run **ungated** so they pass in CI / on a dev box.

### Device → existing rpi-wiringpi coverage map

| Distro | Already in rpi-wiringpi/t/ | Own-repo tests | Task |
|---|---|---|---|
| RPi::ADC::ADS | t/109,140,141,142,310,325,335,345 (HW) | 22 (incl. HW-free bit tests) | V5 |
| RPi::ADC::MCP3008 | t/310,335 (HW) | boilerplate only | V13 |
| RPi::DAC::MCP4922 | t/310 (HW) | boilerplate only | V4 |
| RPi::DigiPot::MCP4XXXX | t/345 (HW) | bytes.t, init.t | V3 |
| RPi::GPIOExpander::MCP23017 | t/330,450 (HW) | 17 (HW-gated) | V6 |
| RPi::RTC::DS3231 | t/320,**321-rtc-bcd** (HW+BCD) | 19 | V8 |
| RPi::EEPROM::AT24C32 | **t/420,421,422** (mirrored, RPI_EEPROM-gated) | boilerplate (moved here) | V7 |
| RPi::Pin | t/105-108 + most pin tests (HW) | 7 | V2 |
| RPi::Const | constants used throughout | 15 | V1 |
| RPi::BMP180 | t/340-bmp (HW) | boilerplate | V19 |
| RPi::I2C | t/305-i2c (HW, Arduino) | boilerplate | V12 |
| RPi::LCD | t/525-lcd (HW) | boilerplate | V20 |
| RPi::OLED::SSD1306 | **t/500-509,520** (mirrored, RPI_OLED-gated, return-value asserts) | boilerplate | V21 |
| RPi::Serial | t/315-serial (HW) | boilerplate | V15 |
| RPi::StepperMotor | **t/450** (HW: real motor — engine physically validated), t/451 (StepperSeek unit) | boilerplate | V16 |
| RPi::SysInfo | **t/400-409** (mirrored, RPI_BOARD-gated) | 14 (t/50,55 ungated seam) | V22 |
| RPi::SPI | indirect via SPI devices | boilerplate | V14 |
| RPi::DHT11 | none (hygrometer not on a board) | 2 functional | V18 |
| RPi::HCSR04 | none (not on a board) | 4 functional (gated) | V17 |
| WiringPi::API | (separate dist) | 24 | V9 |

So every V task below means: **port the sub-repo's missing tests here (non-conflicting) + add the HW-free unit assertions the gated integration tests skip + fix the bug** — crediting the integration coverage named above.

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of test-coverage-gaps-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
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

## Validation Table

Every row: mirror absent sub-repo tests into rpi-wiringpi/t/ (non-conflicting) + add the HW-free unit assertions the gated integration tests skip + fix the cited bug. "Already covered" names the integration tests NOT to duplicate.

| ID | What | Command | Expected | Actual |
|----|------|---------|----------|--------|
| V1 | **RPi::Const** — two export tags have ZERO assertions anywhere: `:altmode` (scrambled: ALT0=4, ALT4=3, ALT5=2) and `:mcp23017_pins` (A0-7=0-7, B0-15=8-23). Add HW-free value assertions for both; make `:all` exhaustive; loop `%EXPORT_TAGS` asserting each imports non-empty; cross-assert `:edge` ≡ `:int_edge`. Port from rpi-const where useful. | `cd ~/repos/rpi-const && prove -Ilib t/` | Every constant value + every tag asserted; pass with no hardware. | ⏳ |
| V2 | **RPi::Pin** — ~13 HW-free validation croaks untested (fire before any hardware call). Add an un-gated file (`NO_BOARD=1` + Test::Fatal): `new`/`write`/`mode`/`pull` bad-arg dies, `set_interrupt`/`background_interrupt` croaks, exercise deprecated `interrupt_set`. Flag `mode_alt` (zero coverage + no input validation). Mirror into rpi-wiringpi if not conflicting with t/105-108. | `cd ~/repos/rpi-pin && NO_BOARD=1 prove -Ilib t/10-validation.t` | ~13 croaks asserted off-board. | ⏳ |
| V3 | **RPi::DigiPot::MCP4XXXX** — integration-covered by t/345 (HW). Gap: `set()`/`shutdown()` have no direct unit test though `init.t` has a Mock::Sub harness. Add data(0-255)/pot(1-3) croaks + control-byte framing (set=0x01, shutdown=0x02, chan=3) + CS ordering; mirror `bytes.t`/`init.t` here. F4. | `cd ~/repos/rpi-digipot-mcp4xxxx && prove -Ilib t/` | set/shutdown validation + framing asserted HW-free via mocks. | ⏳ |
| V4 | **RPi::DAC::MCP4922** — integration-covered by t/310 (HW); own repo has ZERO functional tests. Add HW-free assertions for the pure word-builders `_reg_init`/`__set_dac` (exact register words), the model→bits→lsb chain, constructor arg-validation croaks (mock WiringPi). Core `_set` math blocked on B1. | `cd ~/repos/rpi-dac-mcp4922 && prove -Ilib t/` | Word-builder + model/lsb + validation pass HW-free. | ⏳ |
| V5 | **RPi::ADC::ADS** — heavily integration-covered (t/140-142 etc.). Gap: F1 (stray `exit;` dead-codes the gain croak in `t/925`); `register()` set-path + croaks (missing lsb, 0-255, set→`bits` round-trip); `_samples()` validation; `bits`/`_bit_set` isolation. All HW-free. | `cd ~/repos/rpi-adc-ads && prove -Ilib t/` | Gain croak runs; register/_samples/bit-merge covered HW-free. | ⏳ |
| V6 | **RPi::GPIOExpander::MCP23017** — integration-covered by t/330,450 (HW). Gap: F3 (`t/35-pullup.t`+`t/40-pullup_bank.t` test `mode_bank` not pullup); HW-free validation (pin/bank/register/bit bounds; `register($data>255)` truncation); `getRegisterBits` + all of `bit.c` (`bitSet/Tog/Count/Mask`) untested; F2 (`GPIO__pinBit` `%d`-no-arg croak). Mirror the corrected unit tests here. | `cd ~/repos/rpi-gpioexpander-mcp23017 && prove -Ilib t/` | Mis-targeted tests fixed; bit math + validation + pinBit bounds covered. | ⏳ |
| V7 | **RPi::EEPROM::AT24C32** — the validator croak tests are ALREADY mirrored here (`t/420-422`) but **RPI_EEPROM-gated**, so the HW-free `_check_addr`/`_check_byte` croaks don't run off-board. Un-gate the pure-Perl croak assertions (split from the I/O round-trip); surface F6 (eeprom_init -1 swallowed by new). Own repo is boilerplate — nothing new to mirror. | `cd ~/repos/rpi-wiringpi && prove -Iblib/lib -Ilib t/420-eeprom_args.t t/421-eeprom_read_write_byte_croak.t` | Validator croaks run ungated (HW-free); round-trip stays gated. | ⏳ |
| V8 | **RPi::RTC::DS3231** — integration-covered by t/320, and BCD is mirrored in `t/321-rtc-bcd` (HW-free). Gap: extend `321` to full 0-99 `dec2bcd`/`bcd2dec` round-trip + field maxes; extract & unit-test the temp decode incl. the negative-temp sign path (never executed); add HW-free range-validation croaks for every setter (mock-fd, B3). | `cd ~/repos/rpi-wiringpi && prove -Iblib/lib -Ilib t/321-rtc-bcd.t` | Full BCD range + negative temp + setter validation pass HW-free. | ⏳ |
| V9 | **WiringPi::API** — own repo has 24 tests. Gap: `spi_data`/`spiDataRW` croak tests (channel/arrayref/len/byte-range); F5 (`phys_to_gpio`/`wpi_to_gpio`/`pin_to_gpio` lack the bounds guard `phys_to_wpi` has — add C guard + bounds tests); `shift_reg_setup`/`serial_gets`/`lcd_init` croaks; `bmp180_temp/pressure` conversion math (stub XS); `auto_dispatch` + singular `background_interrupt` runtime via faked self-pipe. | `cd ~/repos/wiringpi-api && prove -Ilib t/` | spi_data + pin-map bounds + setup/serial/lcd croaks + bmp180 math + dispatch covered; OOB guard added. | ⏳ |
| V10 | **rpi-wiringpi (core)** — validation paths untested. Add (ideally un-gated): device-factory dies (`oled`/`lcd`/`expander`/`stepper_motor` bad-arg; `servo`/pwm_* non-root); `Meta` arg croaks; `pin()`+`_pin_registration` collision croak (110 tests only the happy path); `pin_to_gpio` uninit croak. Smoke/isa for untested factories (`gps`/`hcsr04`/`hygrometer`/`spi`/`pin_map`); cover `meta_remove`/`unregister_object`. | `cd ~/repos/rpi-wiringpi && prove -Iblib/lib -Ilib t/` | Factory/Meta/registration validation + smoke tests covered. | ⏳ |
| V11 | **rpi-wiringpi (Pi-5/RP1 safety branch)** — `Core::_restore_pin_alt` (pi3/4 vs pi5/RP1 cleanup divergence: INPUT/OUTPUT via `pinMode`, alt-31 via `pinctrl`, real alts via `pinModeAlt`) has ZERO coverage; a break strands Pi-5 pins at teardown. Mock `pi_rp1_model`/`pinMode`/`system`, assert the call per alt value. Also `_class_signal_handler` prior-handler chaining + `${^GLOBAL_PHASE} eq 'DESTRUCT'` early-return. | `cd ~/repos/rpi-wiringpi && prove -Iblib/lib -Ilib t/` | RP1 restore branches + signal-chain asserted via mocks. | ⏳ |
| V12 | **RPi::I2C** — integration-covered by t/305 (HW, Arduino). Own repo boilerplate. Add HW-free: `new()` addr validation (undef/non-int croak; document `"0x78"` string-hex rejection), `_set_reg` defaulting. Characterize-then-pin F7 (`read_bytes` returns only the last byte) and F8 (`write_word` reg/value swapped) with stubbed XS; flag `process()` POD/code arg-order + unenforced 32-byte `write_block` cap. Gate I/O on `I2C_TESTING`. | `cd ~/repos/rpi-i2c && prove -Ilib t/` | new/_set_reg validation HW-free; read_bytes/write_word bugs pinned. | ⏳ |
| V13 | **RPi::ADC::MCP3008** — integration-covered by t/310,335 (HW). Own repo boilerplate; no env gate (new() can't run off-Pi). Add HW-free: `fetch` input-range croak (0-15), `percent` math (÷1023 via stubbed fetch), `_channel` undef die (needs a wiringPi stub / load-guard). F9 (`spi_setup`/`wpi_setup` `exit(errno)`); note `fetch` GPIO-CS→channel=0 FIXME. Core 10-bit decode → B7. | `cd ~/repos/rpi-adc-mcp3008 && prove -Ilib t/` | input-range + percent + channel validation covered HW-free. | ⏳ |
| V14 | **RPi::SPI** — own repo boilerplate, no env gate. Add HW-free: `_channel` GPIO routing (chan>1 → cs set, channel→0), `_speed` default + F13 (explicit `0` → 1 MHz), `_cs` round-trip; `new`/`rw` arg validation (undef channel, non-arrayref buf, len≠@buf). `rw` framing needs a stubbed `spiDataRW`. | `cd ~/repos/rpi-spi && prove -Ilib t/` | channel/speed routing + validation covered HW-free. | ⏳ |
| V15 | **RPi::Serial** — integration-covered by t/315 (HW). Own repo boilerplate. The pure-Perl framing stack is fully HW-free: `crc`/`crc16` known vectors (incl. empty), `tx` frame+CRC-split order, `rx` stateful reassembly + CRC-mismatch warn + pre-start discard (override getc/avail), `write` undef croak + >255 wrap. F14 (`new()` no croak on failed open → fd=-1; baud unvalidated). Mirror here. | `cd ~/repos/rpi-serial && prove -Ilib t/` | crc/tx/rx framing + write validation covered HW-free. | ⏳ |
| V16 | **RPi::StepperMotor** — the step **engine is already physically validated by t/450** (real motor + magnet timing); t/451 unit-tests the StepperSeek helper. Own repo boilerplate. Gap = StepperMotor's OWN unit logic, HW-free via an injected mock `expander` recording (pin,HIGH/LOW): cw pattern + wrap, ccw reversal + reverse-wrap, `_turns` rounding (incl. `cw(1)`→0), `_pins` 4-elem + `new` missing-`pins` croaks. F10 (`speed()` validation inverted dead code — invalid silently accepted). Mirror here. | `cd ~/repos/rpi-steppermotor && prove -Ilib t/` | step-sequence + _turns + validation covered HW-free; speed() bug fixed. | ⏳ |
| V17 | **RPi::HCSR04** — NOT on any board (no rpi-wiringpi integration). F11 (`new()` never `bless`es — class string used as `$self`; assert `ref eq 'RPi::HCSR04'` + fix). F12 (`_trig`/`_echo` guard `$p<0 && $p>40` can never fire — should be `||`; fix + test). Un-gate the existing `05-new.t` arg validation. cm/inch value math (÷58 vs ÷58.27) welded to `_fetch` → B8. Mirror the corrected unit tests here (gate any HW path). | `cd ~/repos/rpi-hcsr04 && prove -Ilib t/` | bless + pin-range bugs fixed & tested; validation runs off-board. | ⏳ |
| V18 | **RPi::DHT11** — NOT on any board. Has 2 functional tests. Add HW-free wins reachable in noboard mode (`RDE_NOBOARD_TEST=1`): `temp('f')` F-conversion + rounding (returns 32 — untested), `humidity` sanity-loop, `c_debug`. F17 (three inconsistent board-detection signals: `RPI_BOARD` vs `RPI_DHT11` vs documented-unused `RDE_HAS_BOARD`). `read_env` decode welded to timing → B9. Mirror non-conflicting tests here. | `cd ~/repos/rpi-dht11 && RDE_NOBOARD_TEST=1 prove -Ilib t/` | temp('f')/humidity/c_debug HW-free; env signals reconciled. | ⏳ |
| V19 | **RPi::BMP180** — integration-covered by t/340 (HW). Own repo boilerplate, no env gate. Only in-repo HW-free win: `_pin_base` validation (non-int die, unset die) — add + mirror. The compensation/OSS math lives in WiringPi::API XS, not here → B10. | `cd ~/repos/rpi-bmp180 && prove -Ilib t/` | _pin_base validation HW-free; upstream math gap logged. | ⏳ |
| V20 | **RPi::LCD** — integration-covered by t/525 (HW). Own repo boilerplate. HW-free: `init(%params)` per-required-key death tests (14 keys; positive case allows `0` for d4-d7, `lcd_init` mocked), `_fd(-1)` confess + round-trip, `print`/`puts` & `print_char`/`put_char` alias identity. (Value bounds for rows/cols/bits don't exist — net-new, optional.) | `cd ~/repos/rpi-lcd && prove -Ilib t/` | init validation + _fd + alias identity covered HW-free. | ⏳ |
| V21 | **RPi::OLED::SSD1306** — extensively mirrored here (`t/500-509`, RPI_OLED-gated, return-value asserts only). Gap = the HW-free **croak/bounds** paths those skip: `rect`/`pixel` bounds, `dim`/`invert_display` 0/1, `text_size` `^\d+$`; F16 (`new()` singleton silently ignores a different addr/splash). Add ungated. Note `rect` Perl/C off-by-one + `char`/`h_line`/`v_line` have no Perl bounds. (No I2C lock-file/DESTROY exists in this dist.) | `cd ~/repos/rpi-wiringpi && prove -Iblib/lib -Ilib t/502-oled_rect.t t/506-oled_pixel.t` | the 6 validating methods' croaks + singleton behavior covered HW-free. | ⏳ |
| V22 | **RPi::SysInfo** — well covered: t/400-409 here (RPI_BOARD-gated) + own t/50,55 (ungated seam). Gap: `cpu_percent`/`mem_percent` wrappers have ZERO ungated coverage though the XS runs on any Linux; replay the OO `$sys->method` form (core_temp/gpio_info/pi_model/pi_details) through the seam (HW-only today); 16GB revision decode; F15 (`_format` doesn't clamp the XS `-1.0` sentinel → "-1.00"); fix the malformed `raspi_config` blank-line regex. Mirror the ungated seam tests here. | `cd ~/repos/rpi-sysinfo && prove -Ilib t/` | cpu/mem wrappers + OO path + sentinel/regex defects covered HW-free. | ⏳ |

## Discovery Tracking

_None yet._

## Review Findings

Code defects surfaced by the coverage audit (separate from the test gaps). Each points to the V task whose test exposes/fixes it; mark in place as that task closes.

- **F1** (→V5): rpi-adc-ads `t/925-bitwise_gain.t` has a stray `exit;` that dead-codes the gain bad-param block — `gain()`'s croak never runs.
- **F2** (→V6): rpi-gpioexpander-mcp23017 `GPIO__pinBit` OOB croak format string uses `%d` with no argument (`MCP23017.xs:134`).
- **F3** (→V6): rpi-gpioexpander-mcp23017 `t/35-pullup.t` and `t/40-pullup_bank.t` test `mode_bank` (copy-paste), leaving `pullup`/`pullup_bank` validation untested.
- **F4** (→V3): rpi-digipot-mcp4xxxx `shutdown()` croak message reads `"set() $pot param…"` (copy-paste from `set()`).
- **F5** (→V9): WiringPi::API `phys_to_gpio`/`wpi_to_gpio`/`pin_to_gpio` pass the index through with NO bounds guard — asymmetric with `phys_to_wpi`; likely OOB read.
- **F6** (→V7): rpi-eeprom-at24c32 `eeprom_init` returns -1 on open failure but `new()` swallows it (no croak/warn) — a bad device path builds a broken object.
- **F7** (→V12): rpi-i2c `read_bytes` returns only the LAST byte (`$retval = (0<<8) | …` overwrite), not the documented array.
- **F8** (→V12): rpi-i2c `write_word($self,$reg,$value)` argument order is inverted vs `write_byte` and its own POD.
- **F9** (→V13): rpi-adc-mcp3008 `spi_setup`/`wpi_setup` use `exit(errno)` (kills the interpreter) instead of `croak`.
- **F10** (→V16): rpi-steppermotor `speed()` validation is inverted dead code (`! grep {$speed ne $_} qw(full half)` is always false) — invalid speeds are silently accepted and treated as half-step.
- **F11** (→V17): rpi-hcsr04 `new()` never `bless`es — it uses the class string as `$self`; the returned object isn't a real instance.
- **F12** (→V17): rpi-hcsr04 `_trig`/`_echo` range guard `$p < 0 && $p > 40` can never be true (should be `||`) — pin-range validation is dead.
- **F13** (→V14): rpi-spi `_speed` uses `|| 1_000_000`, so an explicit `0` speed silently becomes 1 MHz.
- **F14** (→V15): rpi-serial `new()` doesn't croak on a failed open — it builds an object with `fd = -1`; `baud` is unvalidated (silent `switch` fallthrough).
- **F15** (→V22): rpi-sysinfo `_format` doesn't clamp the XS `-1.0` error sentinel, so `cpu_percent` can return `"-1.00"` as if valid; the `raspi_config` blank-line regex `^\s*(#|^$)` is malformed.
- **F16** (→V21): rpi-oled-ssd1306 `new()` is a silent singleton — a second call with a different I2C address/splash returns the cached object, discarding the new args.

## Backlog

B1: rpi-dac-mcp4922 — refactor the XS so the SPI word assembly is a pure builder that RETURNS the 16-bit word (split build from `_write_dac`'s I/O); prereq for fully unit-testing V4's core mask/shift math.

B2: rpi-adc-ads — expose/extract `pga_fsr` + the 12-vs-16-bit full-scale + VREF/percent scaling for HW-free unit testing (the rig's chip is a 12-bit ADS1015, so the 12-bit scaling path is production with zero HW-free verification).

B3: rpi-rtc-ds3231 — mock-fd (or direct-helper) harness so `setBcdField`/`getBcdField` + every setter's validation run without a live DS3231; prereq for the breadth of V8.

B4: cross-repo — reduce over-gating: split HW-free validation/math tests out of the `RPI_*`/`PI_TEST` `skip_all` so they run in CI; reconcile inconsistent gate-var names across dists.

B5: rpi-eeprom-at24c32 — remove the dead unexported `static _writeBlock()`; wire or remove orphaned `eeprom_read_current_byte`/`eeprom_close`.

B6: rpi-gpioexpander-mcp23017 — `getFd`/`_establishI2C` use `exit(-1)` on a missing device instead of `croak` (unmockable, kills the caller).

B7: rpi-adc-mcp3008 — extract `fetch`'s 3-byte frame-build + 10-bit result-decode into a pure helper (I/O currently inlined) so the conversion math is HW-free table-testable; add an env gate / noboard mode (new() can't run off-Pi today).

B8: rpi-hcsr04 — extract a pure raw-travel-time → cm/inch conversion (welded to `_fetch`) so the values and the divisor precision (÷58 vs ÷58.27 — also datasheet-audit B3) become HW-free table-testable.

B9: rpi-dht11 — refactor `read_env` to accept an injectable 5-byte frame so the bit-decode + checksum become HW-free testable (the math is currently welded to live `digitalRead` timing).

B10: rpi-bmp180 — the temp/pressure compensation + hard-coded OSS math lives in WiringPi::API XS, not this dist; add coverage there (or a Perl-side refactor that injects raw ADC + calibration coefficients) so it's testable at all.

B11: add a noboard/env-gate to dists that have none (mcp3008, spi, bmp180, lcd, oled, hcsr04) so their constructors + validation can run off-board (extends B4).

B12: systematic mirror sweep — after the per-distro tasks, diff each sub-repo's `t/` against rpi-wiringpi/t/ and port any non-conflicting functional test still absent here, so rpi-wiringpi is provably the superset (the duplication policy as a final pass).

## Explicitly NOT doing

- **Implement any tests in this turn** — this is a plan; V tasks run one-per-turn on later "proceed".
- **Re-test what hardware-integration already validates** — credit the t/ map above; the gap is HW-free unit asserts + bug-pinning, not re-driving devices.
- **Duplicate a sub-repo test that already exists here or would conflict** with this repo's gating / shared `rpit` shm / t/110-114 absolute counts / naming (per the mirror principle).
- **Re-litigate the ADS1015-vs-ADS1115 data-rate question** — already resolved; the rig chip is a 12-bit ADS1015.
- **Touch frozen/blessed KiCad or board files** — out of scope, off-limits; this plan is test-code only.
- **Rewrite the upstream wiringPi C library** (`~/repos/WiringPi`) — vendored C lib, not a Perl dist under test.
- **Mirror/clone the deprecated RPi::WiringPi::Constant** — superseded by RPi::Const; excluded per the user.
