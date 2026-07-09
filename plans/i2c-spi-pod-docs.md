# Plan: REGISTER MAP / ON THE WIRE / DATASHEET POD sections across the I2C/SPI rpi-* dists

> **NEXT ACTION:** Plan essentially COMPLETE (2026-07-08). All V tasks done (V8 landed; V11 skipped); the Validation Table is empty. 🎉 **PLAN COMPLETE (2026-07-08).** All V tasks done (V8 landed, V11 skipped) and the entire backlog is resolved: B2, B6, B7, B11 (runtime-validated), B12 (implemented + HW-validated), B13, B14, B15, B18, B19, B20, B21, V8 all done; B1 declined. Nothing left to do. Uncommitted tails to commit: rpi-oled-ssd1306 (B12), plus the B18 .gitignore/MANIFEST.SKIP sweep across ~10 dists and this plan file's bookkeeping. Uncommitted this session: `rpi-i2c` (V8), `rpi-wiringpi` (B2 FAQ.pod + plan bookkeeping), and all 14 repos' MANIFEST.SKIP/.gitignore (B18); `rpi-rtc-ds3231` (B14) already committed.
> **LAST SESSION:** 2026-07-08 — hardware-validation + backlog cleanup day on the primary Pi (a Raspberry Pi 5). HW-validated B5/B8/B9/B10 via the board-2 SPI loopback (t/410) and direct probes; discovered + landed the missing B8 consumer in `rpi-spi` (SPI_NO_CS GPIO-CS + bit-bang mode + a Pi-5 fallback, since RP1 rejects SPI_NO_CS — kernel-confirmed). Root-caused the "unstable SPI" saga as WIRING (power, then a miswired DAC CS), not the platform; fixed a t/410 pin-cleanup contamination (reset CS pins at test start). Backlog done + verified: B19 (rpi-dac-mcp4922 pure __build_word helper + HW-free mask tests, negative-control-proven), B13 (rpi-rtc-ds3231 atomic burst read/write, HW-validated on the DS3231), B15 (rpi-adc-ads COMP_MODE/COMP_LAT + applicability, datasheet-verified), B7 (rpi-adc-mcp3008 MCP3002/3004 claim corrected), B14 (rpi-rtc-ds3231 DS1307 claim corrected against the DS1307 datasheet), and V8 (rpi-i2c TECHNICAL INFORMATION: DEVICE SPECIFICS + per-method ON THE WIRE + UM10204 DATASHEET) with a fresh 11-dist sweep all-clean. Prior session 2026-07-07 — V16 (promoted from B3): localized ALL 10 in-scope dists' datasheets — each PDF now bundled under the dist's `docs/` with POD pointing at it via `F<...>`, zero datasheet web-URLs left; all 10 podchecker-clean, PDFs in/added to MANIFEST, Changes entries added (6 fetched + identity-verified, 4 reused already-bundled copies). Discoveries: gpioexpander cited rev C but ships rev D (corrected) + its PDF was missing from MANIFEST (added); model dist renamed rpi-pca9685 → rpi-pwm-pca9685 mid-task (edits survived); logged B17; B4 superseded. Earlier same day: V12 (final cross-repo sweep, 9-dist form) PASS: all 9 in-scope dists report "pod syntax OK" and each has a Changes 'wire' entry; DEVICE SPECIFICS + ON THE WIRE + a register-equivalent present in all 9; `=head2 DATASHEET` in the 6 that needed one, inline datasheet link confirmed in the 3 pre-existing (B3 migration still parked). Plan now complete except the two intentionally-parked tasks (V8 deferred on rpi-i2c-fixes, V11 skipped). Also this session — quick cleanups: B16 done (`$celcius`→`$celsius` in ds3231 temp()); MANIFEST hygiene swept across all 10 dists — gaps closed in adc-ads (t/26-register.t, t/56-samples_validation.t), dac-mcp4922 (t/register.t), digipot (t/set_shutdown.t), and rtc-ds3231 (removed a stale untracked .claude/settings.local.json entry); pwm-pca9685 has an unlisted .claude/settings.local.json (other AI's renamed dist — left for them); rest clean; B17 done (dropped dac's orphaned mcp48xx.pdf + its MANIFEST line). B5 done as V17 (rpi-adc-ads model() now rejects the SPI-only ADS1018/ADS1118; regex + die message + POD valid-values + t/25-model.t updated, regex logic verified 6-accept/9-reject). B9 done as V18 (rpi-dac-mcp4922: fixed _set()'s 12-bit clear-mask, dropped set()'s dead void-capture, reworded register()'s POD; mask fix verified by calc, XS build pending on the Pi; spun off B19). B10 done as V19 (rpi-eeprom-at24c32: eeprom_write() now acknowledge-polls the chip instead of a fixed 1ms sleep, waiting the real t_WR; verified by C-mirror syntax check + poll sim, Pi build pending). Documented a consolidated Pi validation runbook in `plans/test-path.md` covering all ~11 repos of uncommitted work (build order + HW-free `make test` coverage + the B9/B10/B8 hardware/bench checks). B11 done as V20 (rpi-gpioexpander-mcp23017: IOCON unlocked in the XS write-guard except a BANK-bit croak; POD + t/05-registers.t updated; guard truth-table 13/13). rpi2 (aarch64) build check: all 4 session XS dists (B5/B9/B10/B11) compile clean; B5's t/25-model.t passes on hardware (ADS1018/1118 rejected); prereq stack (RPi::Const/WiringPi::API) not installed there, so dac/at24c32/gpioexpander unit tests + all real-chip behaviour remain pending (see test-path.md's rpi2 section). Prior session 2026-07-06: V15/V14/V13/V10 + V1-V7/V9.
> **ARCHIVE:** See i2c-spi-pod-docs-archive.md for completed V tasks (V1-V10, V12-V20) and archived fixes (Fix 1-Fix 3)

Scope: every `~/repos/rpi-*` dist that uses I2C or SPI gets, in its POD:

1. A **DEVICE SPECIFICS** section (chip capability/electrical bullet list +
   wiring-to-Pi notes, per the pca9685 model) — only where nothing similar
   exists yet.
2. A **register section** (`REGISTER MAP` or the chip-appropriate equivalent) —
   only where nothing similar exists yet.
3. An **ON THE WIRE** section (bus-transaction ASCII diagrams) — only where
   nothing similar exists yet.
4. A **datasheet link** — only in dists whose POD has no datasheet link at all
   today. New links go in their own `=head2 DATASHEET` section, NEVER in
   SEE ALSO.

The model for all four is `rpi-pca9685/lib/RPi/PCA9685.pm` (its
`TECHNICAL INFORMATION` head1 contains `DEVICE SPECIFICS`, `REGISTER MAP`
and `ON THE WIRE`; added 2026-07-06). UPDATE 2026-07-07: the model dist was
renamed — it now lives at `rpi-pwm-pca9685/lib/RPi/PWM/PCA9685.pm` (module
RPi::PWM::PCA9685); rpi-pca9685 mentions elsewhere in this plan refer to it. Work is edit-only — the user does all
commits himself.

## Survey (2026-07-06)

| Repo | Chip | Bus | Device-specifics section | Register-ish section | Wire section | Datasheet link | Needs |
|------|------|-----|--------------------------|----------------------|--------------|----------------|-------|
| rpi-adc-ads | ADS1015/1115 | I2C | partial (`PHYSICAL SETUP` = wiring/addressing only) | yes (`REGISTERS`, `CONFIG REGISTER`) | no | yes (inline, `READING DATA`) | wire + specifics |
| rpi-adc-mcp3008 | MCP3008 | SPI | no | yes (`CHANNEL SELECT` bit layout) | no | yes (inline, github.io PDF) | wire + specifics |
| rpi-bmp180 | BMP180 | I2C (indirect) | no | no | no | no | all four |
| rpi-dac-mcp4922 | MCP4902/12/22 | SPI | yes (`DEVICE SPECIFICS`) | yes (`DEVICE REGISTER`, `REGISTER BITS`) | no | no | wire + datasheet |
| rpi-digipot-mcp4xxxx | MCP41xxx/42xxx | SPI | no (`OVERVIEW` is protocol framing, not device facts) | yes (`CONTROL BYTE`, `REGISTER BIT SEQUENCE`) | no | yes (inline, github.io PDF) | wire + specifics |
| rpi-eeprom-at24c32 | AT24C32 | I2C | no | no | no | no | all four (register = `MEMORY MAP`) |
| rpi-gpioexpander-mcp23017 | MCP23017 | I2C | no | no (`REGISTER ACCESS METHODS` is API docs, not a map) | no | no | all four |
| rpi-i2c | (bus transport) | I2C | no (`READ THIS FIRST` is setup/software notes) | n/a — no chip | no | no | wire + datasheet + specifics (bus-level) |
| rpi-oled-ssd1306 | SSD1306 128x64 | I2C | no | no | no | no | all four (register = `COMMAND SET`) |
| rpi-pca9685 | PCA9685 | I2C | yes | yes | yes | yes (SEE ALSO) | nothing — the model |
| rpi-rtc-ds3231 | DS3231 | I2C | no | no | no | no | all four |
| rpi-spi | (bus transport) | SPI | no | n/a — no chip | no | no | wire + datasheet + specifics (bus-level) |

Out of scope (no I2C/SPI): rpi-const, rpi-dht11, rpi-hcsr04, rpi-lcd
(HD44780 driven over GPIO here), rpi-pin, rpi-serial (UART), rpi-steppermotor,
rpi-sysinfo, rpi-x. No Perl lib/POD at all: rpi-i2cv, rpi-tracker.
rpi-wiringpi itself is the board umbrella, not a chip driver — see
"Explicitly NOT doing" and B2.

## Decisions & conventions

- **Source of truth is ALWAYS the datasheet** (user directive 2026-07-06).
  Every hardware fact written into POD — register addresses, bit fields,
  reset/default values, timing, electrical limits, capability numbers — is
  verified against the manufacturer datasheet before it is written. Fetch
  the PDF (candidate URLs below) and, where text extraction is unclear,
  render the relevant pages high-res (`pdftoppm -r 400`) and read them.
  Never assert hardware facts from training memory. The module code shows
  *which* transactions the module performs and with what byte values; the
  datasheet governs what those bytes mean and whether they are correct.
  Any code-vs-datasheet mismatch found → discovery triage (Fix/new V/B) —
  never silently documented as fact.
- **DEVICE SPECIFICS convention** (added 2026-07-06): a short verbatim
  bullet list of chip capabilities and electrical facts (channels,
  resolution, supply range, bus speed/addressing, per-pin limits — whatever
  the datasheet makes load-bearing for the chip), followed by
  wiring-to-the-Pi prose, modeled on rpi-pca9685's. Placement: FIRST
  `=head2` under TECHNICAL INFORMATION, matching the model's order
  (DEVICE SPECIFICS → chip-specific sections → REGISTER MAP → ON THE WIRE
  → DATASHEET). Where a dist has a partial equivalent (rpi-adc-ads
  `PHYSICAL SETUP`), leave that section untouched and don't duplicate it —
  the new DEVICE SPECIFICS carries the capability summary and cross-refs
  it for wiring. Transports (rpi-i2c, rpi-spi) get bus-level specifics
  (Pi bus pins, voltage, speeds, device nodes) rather than chip specifics.
  rpi-dac-mcp4922 is exempt — it already has a DEVICE SPECIFICS section.
- **Point forms begin with a capital letter** (user directive 2026-07-06):
  every bullet, legend description, and caption sentence/phrase in new POD
  starts with a capital where practical — skip case-sensitive first tokens
  (identifiers, pin/register names, hex values, units like 128SPS, code).
  The pca9685 model's own bullets predate this rule and are lowercase; new
  content follows this rule, not the model's casing (B6 tracks restyling
  the model itself).
- **"Already has one" (datasheet)** = any datasheet link anywhere in the
  dist's POD, including SEE ALSO or inline prose. Those dists get no new
  link (consistency migration captured as B3).
- **Placement**: new sections are `=head2`s nested under the dist's existing
  `=head1 TECHNICAL INFORMATION` / `TECHNICAL DATA`; where no such head1
  exists, create `=head1 TECHNICAL INFORMATION` (before SEE ALSO/AUTHOR) to
  host them. Datasheet section is `=head2 DATASHEET` — the user explicitly
  forbade putting new links in SEE ALSO.
- **Register-equivalents**: chips without classic register maps document the
  nearest real thing — AT24C32 gets `MEMORY MAP` (address space, page
  layout), SSD1306 gets `COMMAND SET` (control/data byte framing), transports
  get none.
- **Transports**: rpi-i2c's "datasheet" is the NXP I2C-bus specification
  (UM10204); rpi-spi's is the BCM2835 ARM Peripherals PDF (SPI chapter).
  Their ON THE WIRE sections show generic transactions (per-method for
  RPi::I2C; SCLK/MOSI/MISO/CE timing + modes for RPi::SPI).
- **rpi-bmp180 is in scope** even though the Perl layer only calls
  WiringPi::API's devLib (`bmp180_setup`): the chip is an I2C device and the
  sections document what the C layer does on the bus (calibration EEPROM
  0xAA-0xBF, ctrl_meas 0xF4, out 0xF6+). Strike V3 if this reading of "uses
  I2C" is unwanted.
- **rpi-i2c coordination**: `plans/rpi-i2c-fixes.md` (active) pulls the Mac
  clone current (its V1) and changes method contracts (`read_bytes`,
  `write_word`, `process` — its V8). Before writing wire diagrams for those
  methods, check that plan's state and document the tree as it stands then;
  prefer running this plan's V8 after that plan's V8 lands.
- **Uncommitted work exists** in several of these dists (datasheet-audit
  fixes: MCP4922.pm, MCP4XXXX.pm, ADS.pm/.xs, AT24C32.xs; the DS3231.xs
  entry that used to be listed here was committed before V10 ran). Check
  `git status` before editing; leave unrelated modifications untouched and
  never revert them. UPDATE 2026-07-07: the B8 fix (separate session) added
  substantial uncommitted work across wiringpi-api, rpi-spi, and
  rpi-adc-mcp3008 — in the latter, MCP3008.xs is deleted (the dist is pure
  Perl on RPi::SPI now, with a regenerated README and a new
  t/05-input-validation.t).
- **Diagram hygiene** (from the pca9685 model): pure ASCII, 4-space verbatim
  indent, lines ≤ 79 chars, frame bytes taken from the module's actual code
  paths (real register numbers, real example values) and verified against
  the datasheet (see the source-of-truth bullet).
- **Datasheet URLs must be verified live** (`curl -sIL <url>` → 200,
  content-type PDF) before being written into POD.
- Every touched dist gets a **Changes entry** at the bottom of its current
  section (house style: capitalized, no AI attribution).
- **No git commits** — ever. The user reviews and commits.

### Candidate datasheet URLs (verify before embedding)

- BMP180: `https://cdn-shop.adafruit.com/datasheets/BST-BMP180-DS000-09.pdf`
- MCP4922: `https://ww1.microchip.com/downloads/en/DeviceDoc/22250A.pdf`
- AT24C32: `https://ww1.microchip.com/downloads/en/devicedoc/doc0336.pdf`
- MCP23017: `https://ww1.microchip.com/downloads/en/devicedoc/20001952c.pdf`
- SSD1306: `https://cdn-shop.adafruit.com/datasheets/SSD1306.pdf`
- DS3231: `https://cdn-shop.adafruit.com/product-files/3013/DS3231.pdf` (used in V10; the analog.com canonical URL fails for curl — Akamai kills the transfer after the TLS handshake regardless of user-agent, so it can't be link-verified from here)
- I2C-bus spec (UM10204): `https://www.nxp.com/docs/en/user-guide/UM10204.pdf`
- BCM2835 ARM Peripherals: `https://datasheets.raspberrypi.com/bcm2835/bcm2835-peripherals.pdf`

### Standard checklist (applies to every V1-V11)

1. `git status` — note any pre-existing uncommitted work; don't disturb it.
2. Fetch the chip datasheet (render pages high-res where text extraction is
   unclear) — it is the source of truth for every hardware fact. Read the
   module; every register number, byte value, and transaction shape in the
   new sections comes from the module's code paths and is verified against
   the datasheet. Code-vs-datasheet mismatch → discovery triage, never
   silent documentation.
3. Add only the sections the survey row says are missing, modeled on
   rpi-pca9685's `TECHNICAL INFORMATION`.
4. `=head2 DATASHEET` with a verified URL (where the survey says needed).
5. Changes entry at the bottom of the dist's current section.
6. `podchecker` clean + `pod2text` render eyeballed.
7. No commit.

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of i2c-spi-pod-docs-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
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

| ID | What | Command | Expected | Actual |
|----|------|---------|----------|--------|

_Empty — all V tasks complete. V1-V10 + V12-V20 archived; V8 done 2026-07-08 (see archive); V11 (rpi-spi) intentionally skipped (see "Explicitly NOT doing")._

## Discovery Tracking

_None unresolved (resolved fixes are moved to the archive — see Fix 1 there)._

## Backlog

B1: ❌ NOT DOING (2026-07-08, user decision; see "Explicitly NOT doing"). Original: DATASHEET sections for the non-bus dists (rpi-dht11 DHT11, rpi-hcsr04 HC-SR04, rpi-lcd HD44780, rpi-serial Pi UART docs, rpi-steppermotor 28BYJ-48/ULN2003) — these GPIO/UART/parallel parts are outside the plan's stated I2C/SPI scope.

B2: ✅ DONE 2026-07-08 — added a "Bus datasheet" =head2 to both the I2C BUS and SPI BUS sections of lib/RPi/WiringPi/FAQ.pod, linking the SoC peripherals manuals: BCM2835 (Pi 1/2/3/Zero; I2C = the BSC block), BCM2711 (Pi 4), and RP1 (Pi 5 southbridge). Linked the canonical datasheets.raspberrypi.com URLs — that host SYN-drops sandbox/AWS traffic (000 from here; the RPi docs hub 403s the bot) but all three docs are confirmed to exist (200 application/pdf via the Wayback Machine) and resolve for real users. podchecker clean; Changes added. Uncommitted in rpi-wiringpi (FAQ.pod, Changes).

B3: ✅ DONE 2026-07-07 → promoted to V16 (slot retired; see archive). Original: consistency migration — move the pre-existing datasheet links (rpi-pca9685 SEE ALSO; rpi-adc-ads `READING DATA` inline; rpi-adc-mcp3008 and rpi-digipot-mcp4xxxx inline) into their own `=head2 DATASHEET` sections. Delivered beyond the original scope at the user's direction: ALL 10 in-scope dists' datasheets were bundled locally under `docs/` and POD repointed at them via `F<...>` (no web URLs anywhere in POD).

B4: ✅ SUPERSEDED 2026-07-07 by V16 — rather than github.io hosting, V16 bundled every datasheet PDF inside each dist's own `docs/` and pointed POD at the local file via `F<...>`, which eliminates manufacturer link rot directly and removes the web URLs from POD entirely. Original idea: self-host all datasheet PDFs under `stevieb9.github.io/<repo>/datasheet/` (precedent: rpi-adc-mcp3008, rpi-digipot-mcp4xxxx).

B5: ✅ DONE 2026-07-07 → V17 (slot retired; see archive). Tightened model()'s regex `[3458]`→`[345]` so the SPI-only ADS1018/ADS1118 are rejected (this I2C driver reaches only the six I2C parts ADS1013/14/15 + ADS1113/14/15), fixed the matching die message and the POD valid-values line (now enumerates the six parts), and added ADS1018/ADS1118 to t/25-model.t's faulty set. Re-verified against the bundled SBAS473C; regex logic checked 6-accept/9-reject.

B6: ✅ DONE 2026-07-07 → V21 (slot retired; see archive). Restyled the model dist rpi-pwm-pca9685 (RPi::PWM::PCA9685) point-forms to leading capitals across the convention triad — DEVICE SPECIFICS bullets, REGISTER MAP description column, and ON THE WIRE legend + diagram captions — matching the casing the other dists now follow. Left lowercase per the unanimous sibling convention: the `addr+W`/`addr+R` byte tokens; also skipped identifiers (LED0_ON_L, PRE_SCALE, SWRST, OFF[..]), hex, numbers, and caption continuation lines. Only leading-letter case changed, so all ASCII diagram alignment is preserved. Spun off B20 (the I2C ADDRESSING section's captions are still lowercase — outside the triad B6 was scoped to). UPDATE 2026-07-08: V21's restyle was uncommitted "no commit" work and was NOT present in the `~/repos/rpi-pwm-pca9685` clone (a fresh copy from origin after the rename — DEVICE SPECIFICS/REGISTER MAP/ON THE WIRE were all still lowercase). Re-applied the full triad restyle in that clone, together with B20, this session. podchecker clean, make test PASS. Uncommitted in rpi-pwm-pca9685.

B7: ✅ DONE 2026-07-08 — corrected the DESCRIPTION compatibility claim. Kept the (real) MCP3004 support, grounded in the bundled DS21295: same control-word format, channel-select bit D2 a "don't care" per Table 5-1 (verified in the datasheet), so the 3-byte frame reads CH0-CH3. Dropped the false MCP3002 claim: it's a separate device (DS21294, not bundled) with a different control word, so this module's frame doesn't address it — phrased without asserting unverifiable DS21294 bit details. podchecker clean; Changes added. Uncommitted in rpi-adc-mcp3008.

B8: ✅ RESOLVED externally 2026-07-07 (fixed in a separate session, not as a V task). Original: rpi-adc-mcp3008 GPIO-CS mode drives hardware CE0 alongside the chosen GPIO (XS FIXME: channel dummied to 0), so a device on CE0 gets spurious selects. Resolution — both candidate routes landed, all uncommitted (release order: wiringpi-api → rpi-spi → rpi-adc-mcp3008): wiringpi-api 3.1804 UNREL adds spiNoCS() (kernel SPI_NO_CS via ioctl, set/restored per transaction) and spiBitBang() (full software SPI frame in C); rpi-spi 3.1802 UNREL uses them — GPIO-CS mode no longer strobes CE0, plus a true bit-bang mode via new(hashref); rpi-adc-mcp3008 3.1802 UNREL dropped MCP3008.xs entirely and is pure Perl on RPi::SPI (sole prereq, 3.1802), inheriting both fixes and losing its DESTROY CS-float quirk. Note for V2's author: the ON THE WIRE "don't hang a second device off CE0" hazard paragraph was replaced with the SPI_NO_CS description, and DESCRIPTION/SYNOPSIS/new()/DEVICE SPECIFICS were edited alongside. Still open (tracked outside this plan): Pi build + make test of all three dists, scope CE0 during a GPIO-CS transfer.

B9: ✅ DONE 2026-07-07 → V18 (slot retired; see archive). Fixed all three: _set()'s clear-mask now clears the full 12-bit data field (was `0xFFF >> lsb`, which left stale top-of-field bits on the 8/10-bit parts); dropped set()'s dead `my $buf =` capture of the void _set(); and reworded register()'s POD to say it returns the construction-time BUF/GAIN/SHDN base, not set() writes (chose the POD-reword path over updating the cache, which would need _set to return its word). XS build/test pending on the Pi.

B10: ✅ DONE 2026-07-07 → V19 (slot retired; see archive). eeprom_write() (XS) now acknowledge-polls the chip via i2c_smbus_write_quick until it ACKs (doc0336 p.9) — waiting the real t_WR instead of a fixed 1ms guess — capped by the `delay` param (ms) but floored at 15ms (>t_WR) so it never under-waits or spins forever. `delay` kept for backward compat as a rarely-needed ceiling; POD reworded. Verified by C-mirror syntax check + poll-logic sim + podchecker; XS build + real-chip validation pending on the Pi.

B11: ✅ DONE 2026-07-07 → V20 (slot retired; see archive). Chose "unlock + BANK-bit croak": removed IOCON (0x0A/0x0B) from the XS read-only guard and added _checkIoconBank() in GPIO_setRegister, so register() can now set IOCON's functional bits (MIRROR/SEQOP/DISSLW/HAEN/ODR/INTPOL) but a write setting BANK (bit 7, datasheet-confirmed) croaks — protecting the BANK=0 layout without silent masking. INTF/INTCAP stay read-only. POD note + t/05-registers.t updated. XS compiles clean on rpi2. RUNTIME ✅ VALIDATED 2026-07-08 on the primary Pi with a real MCP23017 @ 0x20: `t/05-registers.t` passes all 3591 subtests (`RPI_MCP23017=1 RPI_SUBMODULE_TESTING=1`) — IOCON functional bits write + read back, a BANK-bit write croaks, INTF/INTCAP stay read-only. (Initial runs died mid-sweep with intermittent I2C "Remote I/O" errors at varying points — 0 subtests failed — traced to marginal wiring, most likely a floating RESET; clean once reseated.)

B12: ✅ DONE 2026-07-08 — optimised ssd1306_display() to stream the whole framebuffer in ONE I2C transaction (single 0x40 control byte, Co=0, then all 1024 data bytes via a raw write() on the wiringPi I2C fd), replacing the ~1024 control+data-per-byte transactions. Added a byte-by-byte fallback if the single transfer is rejected. HW-validated on the connected SSD1306 @ 0x3c with a before/after on the same panel: **~325ms -> ~94ms per refresh at 100kHz (3.4x; now bus-bound, ~92ms is the raw floor for 1025 bytes)**. The 94ms result also confirms the single write() succeeded (a failure would hit the slow fallback). ON THE WIRE POD updated; Changes added; podchecker clean. Uncommitted in rpi-oled-ssd1306 (ssd1306_i2c.c, lib/…/128_64.pm, Changes). Note: user should visually confirm the panel still renders correctly. Original: display() pushed one byte per I2C frame (~0.3s/refresh); the bundled ssd1306_i2c.c even carried a "should be optimized" comment.

B13: ✅ DONE 2026-07-08 — made the composed ops atomic via burst transfers. Added `_read_time_burst`/`_write_time_burst` XS helpers; hms()/date_time()/dt_hash() now take one coherent burst-read of 0x00-0x06 (chip snapshots to secondary buffers on START — datasheet confirmed), and the date_time() setter does a single burst write seconds-first (datasheet confirmed: seconds write resets the countdown chain, remaining regs due within 1s). day-of-week, 12/24 mode and century bits preserved; the chip-mutating clock_hours() read-toggle is gone; ON THE WIRE POD updated. Validated on the connected DS3231 (0x68): 23-assertion round-trip incl. 12h/24h + midnight/noon/23:00 edge cases, plus the dist's own t/55/60/65/70 (21 tests) pass on hardware. Uncommitted in rpi-rtc-ds3231 (DS3231.xs, lib/…/DS3231.pm, Changes). Original: composed gets stitched one-register-per-transaction reads (a tick could tear a boundary read); the setter wrote seconds LAST, resetting the chain after the other registers.

B14: ✅ DONE 2026-07-08 — verified the DS1307 claim against the DS1307 datasheet (fetched + read locally via pdftotext) and corrected the DESCRIPTION. Confirmed: basic timekeeping carries over (same 0x68 addr, 0x00-0x06 BCD register map, hour bit6=12/24 + bit5=AM/PM), so all three flagged concerns resolve as real caveats now documented: (1) temp() invalid — 0x11-0x12 are NV RAM on a DS1307 (RAM 0x08-0x3F; no temp sensor); (2) seconds bit 7 = CH clock-halt — the module masks it on read and clears it on write, so a halted DS1307 clock is hidden and silently restarted (DS3231 has no CH bit); (3) hour/AM-PM layout confirmed identical. Also found a 4th: the B13 burst read isn't snapshot-atomic on a DS1307 (no secondary buffer; datasheet says the pointer just wraps at 3Fh). podchecker clean; Changes added. Cannot exercise on the bench — needs a real DS1307 (the connected chip is a DS3231). Uncommitted in rpi-rtc-ds3231.

B15: ✅ DONE 2026-07-08 — added the two missing CONFIG REGISTER head3s: COMPARATOR MODE (bit 4, traditional vs window) and COMPARATOR LATCH (bit 2), both documented as left at 0, verified against the bundled ADS1015 datasheet (SBAS473). Added per-model applicability notes to INPUT CHANNELS (MUX on the ADS1015/1115 only — datasheet: "The ADS1015 contains an input multiplexer"), GAIN AMPLIFIER (PGA on ADS1014/1015, "INTERNAL PGA (ADS1014 and ADS1015)"; ADS1013/1113 fixed at ±2.048V), and the comparator block (no function on ADS1013/1113). Confirmed the module's default config leaves bits 4 and 2 at 0 (no DEFAULT_ constants for them; config LSB default 0x00). podchecker clean; Changes added. Uncommitted in rpi-adc-ads.

B16: ✅ DONE 2026-07-07 — renamed the `$celcius` local in temp() to `$celsius` (3 occurrences, lines 29-30); Changes entry added; purely cosmetic, no API/behaviour change. Original: rpi-rtc-ds3231 — the local variable `$celcius` in temp() was misspelled; V15 fixed the POD/comment spellings but left this code identifier alone (out of that POD-only task's scope).

B17: ✅ DONE 2026-07-07 — dropped `docs/datasheet/mcp48xx.pdf` (DS22244B, 1.29 MB, MCP48xx internal-Vref family; referenced nowhere but a stale MANIFEST line and a historical Changes note) and removed its MANIFEST entry; Changes entry added. The module drives only MCP4902/4912/4922 (49xx), documented via mcp49xx.pdf. Discovered during V16.

B18: ✅ DONE 2026-07-08 — swept all 14 repos (the 11 in-scope dists + rpi-i2c/wiringpi-api/rpi-wiringpi): added `^\.claude/` to each MANIFEST.SKIP that lacked it (11 added; rpi-i2c/wiringpi-api/rpi-wiringpi already had a form of it) and `.claude/` to every `.gitignore` (all 14 lacked it). Verified functionally: `ExtUtils::Manifest::maniskip()` skips `.claude/settings.local.json` + `.claude/` but not real files, and `t/manifest.t` passes on rpi-rtc-ds3231 (which has a `.claude/` dir on disk). No per-dist Changes entries: this is preventive build-config only (.gitignore isn't shipped; the SKIP pattern just stops `.claude/` being added to a future MANIFEST — current MANIFESTs are already clean), so it changes neither shipped content nor behaviour. Uncommitted across all 14 repos (MANIFEST.SKIP and/or .gitignore).

B19: ✅ DONE 2026-07-08 — split `_set()`'s word-building out of the SPI write into a pure `__build_word(buf, dac, lsb, data)` XS helper (returns the int register word; `_set` now just calls it + `_write_dac`), bound it for testing, and added HW-free `t/register.t` cases across the 8/10/12-bit lsb values including stale-cache scenarios. Negative control confirmed the tests catch the B9 bug: reverting the mask to the old `0xFFF >> lsb` fails the 8- and 10-bit stale-field guards, the fixed mask passes. This validates the B9 clear-mask fix without needing an 8/10-bit MCP4902/4912 part. Uncommitted in rpi-dac-mcp4922 (Changes, MCP4922.xs, t/register.t). Original: _set() (XS) combined word-building with the SPI write, so its register math wasn't HW-free unit-testable — that is why V18's clear-mask bug went uncaught. Discovered during V18.

B20: ✅ DONE 2026-07-08 — restyled the rpi-pwm-pca9685 I2C ADDRESSING captions to leading capitals ("The 7-bit address", "Each pin's weight...", "Fixed - the 0x40...", the "Address" column header, "The default - all pins to GND"), done together with re-applying B6's triad restyle in the same clone (V21's work was missing from it — see B6). Only leading letters changed, alignment preserved; podchecker clean; make test PASS; Changes added. Uncommitted in rpi-pwm-pca9685.

B21: ✅ DONE 2026-07-08 — the user supplied a verified UM10204.pdf (identity-checked via pdftotext: "UM10204, I2C-bus specification and user manual, Rev. 7.0 — 1 October 2021"; pdfinfo confirms 62 pages, 750KB — the `file` tool miscounts it as 3 due to the Apache FOP producer). The canonical NXP URL still 404s from here (re-verified curl → HTTP/2 404; Wayback proxied the same 404). Bundled it as `rpi-i2c/docs/datasheet/UM10204.pdf`, repointed the DATASHEET POD at it via `F<docs/datasheet/UM10204.pdf>` (matching the V16 convention), and added the PDF to MANIFEST. podchecker clean; `t/manifest.t` + full suite PASS under RELEASE_TESTING (MANIFEST↔disk consistent). Removed the redundant handoff copy from the rpi-wiringpi root. Uncommitted in rpi-i2c (docs/datasheet/UM10204.pdf, lib/RPi/I2C.pm, MANIFEST, Changes).

- rpi-spi (was V11) — user directed skip mid-task (2026-07-06); no edits had been made. Reusable intel from the aborted prep, should it ever be revived: rpi-spi's tree was clean; wiringPiSPI.c confirms mode 0/8-bit/full-duplex tx==rx and that the module's GPIO-CS path still runs hardware channel 0 (CE0 hazard, cf. B8); datasheets.raspberrypi.com is TCP-unreachable from the Mac (all four AWS IPs drop SYNs) — the BCM2835 peripherals PDF pulls fine via the Wayback Machine, official pin/driver/speed facts live in raspberrypi/documentation `spi-bus-on-raspberry-pi.adoc` (master branch), and the official docs now link the datasheet at `https://pip.raspberrypi.com/documents/RP-008249-DS` (unverified from here). UPDATE 2026-07-07: the B8 fix (separate session) has since rewritten rpi-spi — uncommitted code + POD changes (SPI_NO_CS around GPIO-CS transactions, a true bit-bang mode, all three modes documented) — so the "tree was clean / no edits" statement above no longer holds, and the CE0 hazard is fixed (see B8).

- rpi-pca9685 — already has DEVICE SPECIFICS, REGISTER MAP, ON THE WIRE, and a datasheet link; it is the model the other dists copy.

- New DEVICE SPECIFICS for rpi-dac-mcp4922 — it already has one (the only non-model dist that does).

- Rewriting rpi-adc-ads `PHYSICAL SETUP` — it stays as-is; V1's DEVICE SPECIFICS adds the capability summary and cross-references it for wiring.
- Non-I2C/SPI dists (rpi-const, rpi-dht11, rpi-hcsr04, rpi-lcd, rpi-pin, rpi-serial, rpi-steppermotor, rpi-sysinfo, rpi-x) — outside the user's stated "uses I2C or SPI" scope. The datasheet-link idea for them was tracked as B1, now also declined by the user (2026-07-08): GPIO/UART/parallel parts, out of scope.
- rpi-i2cv, rpi-tracker — no Perl lib/POD to document.
- rpi-wiringpi umbrella REGISTER/WIRE sections — it's the board umbrella, not a chip driver; chip specifics belong in the driver dists (B2 covers its datasheet links).
- REGISTER MAP for rpi-i2c / rpi-spi — bus transports have no chip registers to map.
- Relocating datasheet links that already exist (SEE ALSO or inline) — user asked to add links only where missing; migration is B3, not this plan.
- git commits — the user reviews and commits all work himself.
