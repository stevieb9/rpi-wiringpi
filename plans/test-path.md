# Test / validation path — uncommitted 2026-07-07 work

All the work below is **uncommitted** and spans 12 repos. Much of it is XS or
hardware-dependent and was **not** runnable on the Mac — only static checks were
possible there (podchecker, `ExtUtils::Manifest` consistency, a `clang`
syntax-check of the edited XS, and logic simulations). Build and test on the
**Pi**, with the relevant chip attached where noted, before committing. The user
commits — nothing here runs `git commit`.

Cross-references: this-plan tasks live in `i2c-spi-pod-docs.md` (+ its archive);
the B8 work was a separate session (see that plan's B8 entry).

## rpi2 build results (2026-07-07)

Built my Mac working copies in a temp dir on **rpi2** (aarch64, perl 5.40.1).
This did NOT touch rpi2's own `~/repos` (which have diverged for gpioexpander
and adc-ads and carry their own uncommitted work). Confirmed:

- **All four XS dists compile clean** into their `.so`: rpi-dac-mcp4922 (B9),
  rpi-eeprom-at24c32 (B10), rpi-gpioexpander-mcp23017 (B11), rpi-adc-ads (B5).
- **B5 validated end-to-end**: rpi-adc-ads `t/25-model.t` passes all 25 subtests,
  including the new assertions that **ADS1018 and ADS1118 now die**.
- **B11**: the updated `t/05-registers.t` syntax-checks against the built `.so`.

Still NOT validated here (blocked):

- The RPi prereq stack (RPi::Const, WiringPi::API, RPi::SPI) is **not installed**
  on rpi2's perl, so the dac / at24c32 / gpioexpander module-load + unit tests
  can't run without installing it first (adc-ads needs only XSLoader, which is
  why its test ran). RPi::Const source is present (`~/repos/rpi-const`);
  WiringPi::API (XS) would need building/installing.
- **B9 / B10 / B11 runtime behaviour** still needs the real chips (see §4).

## Pi validation results (2026-07-08)

Ran the full HW-free path on the **primary Pi** (aarch64, perl 5.42.0) — note
this host carries the work **already committed** (not uncommitted as on the Mac):
B5's `[345]` regex, B9's 12-bit mask, B10's `i2c_smbus_write_quick` polling, and
B8's `spiNoCS`/`spiBitBang` are all in the committed trees here. Prereqs were
installed except RPi::SPI (was 3.1801) — rebuilt+installed to 3.1802 for mcp3008.

- **RPi::SPI 3.1802** built + `make test` PASS + installed.
- **rpi-adc-mcp3008 (B8)** — `make test` PASS (`t/05-input-validation.t` incl.).
- **wiringpi-api (B8)** — `make test` PASS (already installed at 3.1804).
- **rpi-dac-mcp4922, rpi-eeprom-at24c32, rpi-digipot-mcp4xxxx, rpi-rtc-ds3231,
  rpi-bmp180, rpi-gpioexpander-mcp23017, rpi-oled-ssd1306** — all `make test`
  PASS (chip-gated tests skip via their env guards, as designed).
- **rpi-adc-ads (B5)** — PASS after a fix: `t/30-resolution.t` iterated model
  suffixes `qw(13 14 15 18)`, constructing ADS1018/ADS1118, which B5's tightened
  `model()` now rejects — the suite died mid-run. B5 had updated `t/25-model.t`
  but missed this test. Dropped `18` from both loops; Changes entry added. Now
  `t/25-model.t` + `t/30-resolution.t` + full suite PASS.

Then (2026-07-08) **B10's real-chip bench PASSED** (§4) — the acknowledge-polling
fix is validated on hardware. Still pending (§4): B9 DAC Vout, B8 mcp3008 CE0
scope. `make test` does NOT exercise the B9 XS fix (see §5 / B19).

## 1. Change inventory (what to validate)

| Repo | Task(s) this session | Uncommitted files |
|------|----------------------|-------------------|
| rpi-adc-ads | localization, MANIFEST gap, **B5** (model regex) | Changes, MANIFEST, lib/RPi/ADC/ADS.pm, t/25-model.t, docs/ |
| rpi-dac-mcp4922 | localization, **B17** (drop pdf), MANIFEST gap, **B9** (XS mask, set(), register() POD) | Changes, MANIFEST, MCP4922.xs, lib/…/MCP4922.pm, docs/datasheet/mcp48xx.pdf (deleted) |
| rpi-eeprom-at24c32 | localization, MANIFEST, **B10** (XS acknowledge polling) | AT24C32.xs, Changes, MANIFEST, lib/…/AT24C32.pm, docs/ |
| rpi-digipot-mcp4xxxx | localization, MANIFEST gap | Changes, MANIFEST, lib/…/MCP4XXXX.pm |
| rpi-rtc-ds3231 | localization, MANIFEST fix, **B16** ($celsius rename) | Changes, MANIFEST, lib/…/DS3231.pm, docs/ |
| rpi-bmp180 | localization | Changes, MANIFEST, lib/RPi/BMP180.pm, docs/ |
| rpi-gpioexpander-mcp23017 | localization (+rev C→D, +MANIFEST) | Changes, MANIFEST, lib/…/MCP23017.pm |
| rpi-oled-ssd1306 | localization | Changes, MANIFEST, Makefile.PL, lib/…/128_64.pm, docs/ |
| rpi-adc-mcp3008 | localization; **B8** (pure-Perl on RPi::SPI) | Changes, MANIFEST, MCP3008.xs (deleted), Makefile.PL, README, lib/…/MCP3008.pm, t/pod-coverage.t, t/05-input-validation.t |
| rpi-spi | **B8** (SPI_NO_CS + bit-bang) | Changes, Makefile.PL, lib/RPi/SPI.pm |
| wiringpi-api | **B8** (spiNoCS()/spiBitBang()) | 9 files |
| rpi-pwm-pca9685 | localization (survived the rename) | **already committed** — clean tree, POD-only |

## 2. Build order (on the Pi)

Install shared prereqs first (dependents link against them); the B8 chain has a
release order:

    # 1. base C/XS layer (B8: adds spiNoCS()/spiBitBang())
    cd ~/repos/wiringpi-api    && perl Makefile.PL && make && make test && sudo make install
    # 2. prereqs for the I2C dists (no changes this session, just need to be installed)
    cd ~/repos/rpi-const       && perl Makefile.PL && make && sudo make install
    cd ~/repos/rpi-i2c         && perl Makefile.PL && make && sudo make install
    # 3. RPi::SPI (B8) — prereq for mcp3008
    cd ~/repos/rpi-spi         && perl Makefile.PL && make && make test && sudo make install
    # 4. mcp3008 (B8: needs RPi::SPI 3.1802)
    cd ~/repos/rpi-adc-mcp3008 && perl Makefile.PL && make && make test

Then each remaining chip dist independently:

    for d in adc-ads dac-mcp4922 eeprom-at24c32 digipot-mcp4xxxx \
             rtc-ds3231 bmp180 gpioexpander-mcp23017 oled-ssd1306; do
      (cd ~/repos/rpi-$d && perl Makefile.PL && make && make test) || echo "FAIL: rpi-$d"
    done

## 3. What `make test` covers (HW-free — should pass without a chip)

- **rpi-adc-ads (B5)** — `t/25-model.t`: ADS1013/14/15 + ADS1113/14/15 accepted,
  **ADS1018/ADS1118 now die**. Plus `t/manifest.t`.
- **rpi-dac-mcp4922** — `t/register.t` covers the pure word-builders (`_reg_init`,
  `__set_dac`). It does **NOT** cover `_set()`'s mask fix (that path does SPI I/O
  — see B19). `t/manifest.t`.
- **rpi-digipot-mcp4xxxx** — `t/set_shutdown.t` (asserts SPI byte framing via
  Mock::Sub), `t/manifest.t`.
- **rpi-rtc-ds3231** — full `t/` suite; the B16 `$celsius` rename is
  behaviour-neutral. `t/manifest.t`.
- **rpi-adc-mcp3008 (B8)** — `t/05-input-validation.t` + suite; CE0 behaviour is
  HW-only (§4).
- **every touched dist** — `t/manifest.t` passes (MANIFEST↔disk consistency was
  swept clean 2026-07-07) and `podchecker $(find lib -name '*.pm')` is clean
  (already verified on the Mac).

## 4. Hardware / bench checks (NOT covered by `make test`)

- **B10 — rpi-eeprom-at24c32 (real AT24C32): ✅ VALIDATED 2026-07-08** on the
  primary Pi (chip at 0x57 on /dev/i2c-1, ZS-042 combo board; installed the
  1.00 tree over the stale 0.01). Non-destructive bench (page saved + restored):
  1. Tight `write`→`read` loop, 256 cycles over a 32-byte page (8 passes,
     varying patterns) — **0 I/O errors, 0 mismatches** (the old fixed 1ms sleep
     failed exactly here — actual t_WR is ~2ms, so 1ms returned too early).
  2. Write timing over 32 writes — **min 1.94 / avg 1.98 / max 1.99 ms**, far
     under the 15ms floor: the poll loop exits on the chip's ACK (real
     completion), and the adapter honours `i2c_smbus_write_quick` ACK/NACK.
- **B9 — rpi-dac-mcp4922 (an 8- or 10-bit MCP4902/4912):** write a mid-scale
  value and a high-data-bit value; measure that Vout tracks the written value.
  The mask fix only bites when a cached register carried stale data bits, so
  exercise **repeated** `set()` calls on the same DAC. On a 12-bit MCP4922
  (lsb = 0) the mask change is a no-op.
- **B8 — rpi-adc-mcp3008 GPIO-CS:** scope **CE0** during a GPIO-CS transfer — it
  must stay idle (no spurious selects); confirm the new bit-bang mode drives a
  conversion.

## 5. Automated-coverage gaps (backlog)

- **B19** — split `_set()`'s word-building out of its SPI write so the B9 mask is
  HW-free unit-testable.
- Optional — a mocked-`i2c_smbus_write_quick` test asserting `eeprom_write()`
  polls rather than sleeps (B10).
