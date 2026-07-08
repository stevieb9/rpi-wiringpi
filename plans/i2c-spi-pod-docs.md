# Plan: REGISTER MAP / ON THE WIRE / DATASHEET POD sections across the I2C/SPI rpi-* dists

> **NEXT ACTION:** Validate the uncommitted 2026-07-07 work on the Pi before committing — runbook in `plans/test-path.md` (build order, per-dist `make test` expectations, and the hardware/bench checks the XS fixes need: B9 DAC output, B10 at24c32 write timing, B8 CE0 scope). Then, separately: this plan's own V8 stays DEFERRED on `plans/rpi-i2c-fixes.md`'s V8 landing (when it does, run V8 here + a fresh 10-dist sweep). Remaining optional backlog: real bugs B11/B13/B14, plus B1/B2/B6/B7/B12/B15/B18/B19.
> **LAST SESSION:** 2026-07-07 — V16 (promoted from B3): localized ALL 10 in-scope dists' datasheets — each PDF now bundled under the dist's `docs/` with POD pointing at it via `F<...>`, zero datasheet web-URLs left; all 10 podchecker-clean, PDFs in/added to MANIFEST, Changes entries added (6 fetched + identity-verified, 4 reused already-bundled copies). Discoveries: gpioexpander cited rev C but ships rev D (corrected) + its PDF was missing from MANIFEST (added); model dist renamed rpi-pca9685 → rpi-pwm-pca9685 mid-task (edits survived); logged B17; B4 superseded. Earlier same day: V12 (final cross-repo sweep, 9-dist form) PASS: all 9 in-scope dists report "pod syntax OK" and each has a Changes 'wire' entry; DEVICE SPECIFICS + ON THE WIRE + a register-equivalent present in all 9; `=head2 DATASHEET` in the 6 that needed one, inline datasheet link confirmed in the 3 pre-existing (B3 migration still parked). Plan now complete except the two intentionally-parked tasks (V8 deferred on rpi-i2c-fixes, V11 skipped). Also this session — quick cleanups: B16 done (`$celcius`→`$celsius` in ds3231 temp()); MANIFEST hygiene swept across all 10 dists — gaps closed in adc-ads (t/26-register.t, t/56-samples_validation.t), dac-mcp4922 (t/register.t), digipot (t/set_shutdown.t), and rtc-ds3231 (removed a stale untracked .claude/settings.local.json entry); pwm-pca9685 has an unlisted .claude/settings.local.json (other AI's renamed dist — left for them); rest clean; B17 done (dropped dac's orphaned mcp48xx.pdf + its MANIFEST line). B5 done as V17 (rpi-adc-ads model() now rejects the SPI-only ADS1018/ADS1118; regex + die message + POD valid-values + t/25-model.t updated, regex logic verified 6-accept/9-reject). B9 done as V18 (rpi-dac-mcp4922: fixed _set()'s 12-bit clear-mask, dropped set()'s dead void-capture, reworded register()'s POD; mask fix verified by calc, XS build pending on the Pi; spun off B19). B10 done as V19 (rpi-eeprom-at24c32: eeprom_write() now acknowledge-polls the chip instead of a fixed 1ms sleep, waiting the real t_WR; verified by C-mirror syntax check + poll sim, Pi build pending). Documented a consolidated Pi validation runbook in `plans/test-path.md` covering all ~11 repos of uncommitted work (build order + HW-free `make test` coverage + the B9/B10/B8 hardware/bench checks). B11 done as V20 (rpi-gpioexpander-mcp23017: IOCON unlocked in the XS write-guard except a BANK-bit croak; POD + t/05-registers.t updated; guard truth-table 13/13). rpi2 (aarch64) build check: all 4 session XS dists (B5/B9/B10/B11) compile clean; B5's t/25-model.t passes on hardware (ADS1018/1118 rejected); prereq stack (RPi::Const/WiringPi::API) not installed there, so dac/at24c32/gpioexpander unit tests + all real-chip behaviour remain pending (see test-path.md's rpi2 section). Prior session 2026-07-06: V15/V14/V13/V10 + V1-V7/V9.
> **ARCHIVE:** See i2c-spi-pod-docs-archive.md for completed V tasks (V1-V7, V9, V10, V12-V20) and archived fixes (Fix 1-Fix 3)

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
| V8 | **DEFERRED (checked 2026-07-06):** rpi-i2c-fixes.md has no tasks done (Mac clone still stale at 3.1801; its contract-changing V8 waits on decision D2) — run this only after that plan's V8 lands. rpi-i2c: add DEVICE SPECIFICS (bus-level) + ON THE WIRE (generic, per-method) + DATASHEET (UM10204) | `cd ~/repos/rpi-i2c && podchecker lib/RPi/I2C.pm && pod2text lib/RPi/I2C.pm \| grep -cE 'ON THE WIRE\|DATASHEET\|DEVICE SPECIFICS'` | pod OK; count ≥ 3 | ⏳ deferred |

## Discovery Tracking

_None unresolved (resolved fixes are moved to the archive — see Fix 1 there)._

## Backlog

B1: DATASHEET sections for the non-bus dists (rpi-dht11 DHT11, rpi-hcsr04 HC-SR04, rpi-lcd HD44780, rpi-serial Pi UART docs, rpi-steppermotor 28BYJ-48/ULN2003) — user scoped this plan to I2C/SPI dists only.

B2: rpi-wiringpi umbrella — link the SoC peripherals datasheets (BCM2835/BCM2711/RP1) from its `I2C BUS` / `SERIAL PERIPHERAL INTERFACE (SPI) BUS` sections.

B3: ✅ DONE 2026-07-07 → promoted to V16 (slot retired; see archive). Original: consistency migration — move the pre-existing datasheet links (rpi-pca9685 SEE ALSO; rpi-adc-ads `READING DATA` inline; rpi-adc-mcp3008 and rpi-digipot-mcp4xxxx inline) into their own `=head2 DATASHEET` sections. Delivered beyond the original scope at the user's direction: ALL 10 in-scope dists' datasheets were bundled locally under `docs/` and POD repointed at them via `F<...>` (no web URLs anywhere in POD).

B4: ✅ SUPERSEDED 2026-07-07 by V16 — rather than github.io hosting, V16 bundled every datasheet PDF inside each dist's own `docs/` and pointed POD at the local file via `F<...>`, which eliminates manufacturer link rot directly and removes the web URLs from POD entirely. Original idea: self-host all datasheet PDFs under `stevieb9.github.io/<repo>/datasheet/` (precedent: rpi-adc-mcp3008, rpi-digipot-mcp4xxxx).

B5: ✅ DONE 2026-07-07 → V17 (slot retired; see archive). Tightened model()'s regex `[3458]`→`[345]` so the SPI-only ADS1018/ADS1118 are rejected (this I2C driver reaches only the six I2C parts ADS1013/14/15 + ADS1113/14/15), fixed the matching die message and the POD valid-values line (now enumerates the six parts), and added ADS1018/ADS1118 to t/25-model.t's faulty set. Re-verified against the bundled SBAS473C; regex logic checked 6-accept/9-reject.

B6: rpi-pca9685 (the model dist) predates the capitalization directive — its DEVICE SPECIFICS bullets and ON THE WIRE captions start lowercase; restyle to leading capitals where practical so the model matches the convention the other dists now follow. (UPDATE 2026-07-07: dist renamed — now rpi-pwm-pca9685, module RPi::PWM::PCA9685.)

B7: rpi-adc-mcp3008 DESCRIPTION claims MCP3002 compatibility ("should work equally well") — the MCP3002 (DS21294) control word differs from the 3004/3008 (SGL/DIFF + ODD/SIGN + MSBF vs SGL/DIFF + D2 D1 D0), so the module's 3-byte frame likely doesn't align (the frame now lives in pure-Perl _fetch() — the XS was removed by the B8 fix 2026-07-07; the bytes are unchanged, so this item stands). Verify against DS21294 and correct the claim (MCP3004 compatibility is real: DS21295D Table 5-1, D2 = don't care).

B8: ✅ RESOLVED externally 2026-07-07 (fixed in a separate session, not as a V task). Original: rpi-adc-mcp3008 GPIO-CS mode drives hardware CE0 alongside the chosen GPIO (XS FIXME: channel dummied to 0), so a device on CE0 gets spurious selects. Resolution — both candidate routes landed, all uncommitted (release order: wiringpi-api → rpi-spi → rpi-adc-mcp3008): wiringpi-api 3.1804 UNREL adds spiNoCS() (kernel SPI_NO_CS via ioctl, set/restored per transaction) and spiBitBang() (full software SPI frame in C); rpi-spi 3.1802 UNREL uses them — GPIO-CS mode no longer strobes CE0, plus a true bit-bang mode via new(hashref); rpi-adc-mcp3008 3.1802 UNREL dropped MCP3008.xs entirely and is pure Perl on RPi::SPI (sole prereq, 3.1802), inheriting both fixes and losing its DESTROY CS-float quirk. Note for V2's author: the ON THE WIRE "don't hang a second device off CE0" hazard paragraph was replaced with the SPI_NO_CS description, and DESCRIPTION/SYNOPSIS/new()/DEVICE SPECIFICS were edited alongside. Still open (tracked outside this plan): Pi build + make test of all three dists, scope CE0 during a GPIO-CS transfer.

B9: ✅ DONE 2026-07-07 → V18 (slot retired; see archive). Fixed all three: _set()'s clear-mask now clears the full 12-bit data field (was `0xFFF >> lsb`, which left stale top-of-field bits on the 8/10-bit parts); dropped set()'s dead `my $buf =` capture of the void _set(); and reworded register()'s POD to say it returns the construction-time BUF/GAIN/SHDN base, not set() writes (chose the POD-reword path over updating the cache, which would need _set to return its word). XS build/test pending on the Pi.

B10: ✅ DONE 2026-07-07 → V19 (slot retired; see archive). eeprom_write() (XS) now acknowledge-polls the chip via i2c_smbus_write_quick until it ACKs (doc0336 p.9) — waiting the real t_WR instead of a fixed 1ms guess — capped by the `delay` param (ms) but floored at 15ms (>t_WR) so it never under-waits or spins forever. `delay` kept for backward compat as a rarely-needed ceiling; POD reworded. Verified by C-mirror syntax check + poll-logic sim + podchecker; XS build + real-chip validation pending on the Pi.

B11: ✅ DONE 2026-07-07 → V20 (slot retired; see archive). Chose "unlock + BANK-bit croak": removed IOCON (0x0A/0x0B) from the XS read-only guard and added _checkIoconBank() in GPIO_setRegister, so register() can now set IOCON's functional bits (MIRROR/SEQOP/DISSLW/HAEN/ODR/INTPOL) but a write setting BANK (bit 7, datasheet-confirmed) croaks — protecting the BANK=0 layout without silent masking. INTF/INTCAP stay read-only. POD note + t/05-registers.t updated. XS compiles clean on rpi2; runtime IOCON behaviour still needs a chip.

B12: rpi-oled-ssd1306 — display() pushes the framebuffer one byte per I2C frame (1024 frames, ~0.3s per refresh at 100kHz); the bundled ssd1306_i2c.c even carries a "should be optimized" comment. The chip accepts a stream of data bytes after a single 0x40 control byte — batching (or 32-byte kernel block writes) would cut a refresh to a fraction. V9's ON THE WIRE documents the current cost.

B13: rpi-rtc-ds3231 — composed operations aren't atomic on the bus. Gets (hms(), date_time(), dt_hash()) stitch together one-register-per-transaction reads, and the chip re-latches its snapshot buffers on every START (datasheet p.12), so a tick between transactions can tear a boundary read (V10's ON THE WIRE documents this). Worse on the set side: date_time() writes seconds LAST, but the datasheet resets the countdown chain on the seconds write and wants the remaining registers written within 1s — writing them BEFORE the chain reset leaves a mid-set tick able to roll an already-written field. A single burst transfer (pointer 0x00 + 7 bytes in one transaction; seconds first for the set) would make both directions atomic per the datasheet's secondary-buffer design.

B14: rpi-rtc-ds3231 — DESCRIPTION claims DS1307 compatibility ("*should* work"). Verify against the DS1307 datasheet before trusting it; candidate concerns to check: the DS3231 temperature registers (0x11-0x12) don't exist on the DS1307 (temp() would read NVRAM there), the DS1307's seconds register is documented to carry a clock-halt bit in bit 7 (this module's seconds write always clears bit 7, and reads mask it off — potentially hiding a halted clock), and the hour/AM-PM bit layout needs confirming.

B15: rpi-adc-ads — the CONFIG REGISTER POD skips two fields entirely: bit 4 COMP_MODE (traditional vs window comparator) and bit 2 COMP_LAT (latching ALERT/RDY), both verified on SBAS473C p.16/SBAS444B p.19; the module leaves both 0. Same pages also note per-model applicability the POD never mentions (MUX bits function on the x15 parts only; PGA on x14/x15 only; the whole comparator block on x14/x15 only — no function on ADS1013/1113). Add the two head3s and applicability notes.

B16: ✅ DONE 2026-07-07 — renamed the `$celcius` local in temp() to `$celsius` (3 occurrences, lines 29-30); Changes entry added; purely cosmetic, no API/behaviour change. Original: rpi-rtc-ds3231 — the local variable `$celcius` in temp() was misspelled; V15 fixed the POD/comment spellings but left this code identifier alone (out of that POD-only task's scope).

B17: ✅ DONE 2026-07-07 — dropped `docs/datasheet/mcp48xx.pdf` (DS22244B, 1.29 MB, MCP48xx internal-Vref family; referenced nowhere but a stale MANIFEST line and a historical Changes note) and removed its MANIFEST entry; Changes entry added. The module drives only MCP4902/4912/4922 (49xx), documented via mcp49xx.pdf. Discovered during V16.

B18: MANIFEST hygiene — a local `.claude/settings.local.json` was found swept into rpi-rtc-ds3231's MANIFEST (stale/untracked, removed during the quick-cleanups pass 2026-07-07) and sits untracked in rpi-pwm-pca9685. Add `.claude/` (and other local/editor cruft) to each dist's MANIFEST.SKIP so `make manifest` never re-lists it; a shared .gitignore entry too. A 10-dist consistency sweep on 2026-07-07 otherwise found all MANIFEST/disk mismatches resolved. Cross-dist packaging hygiene, non-blocking.

B19: ✅ DONE 2026-07-08 — split `_set()`'s word-building out of the SPI write into a pure `__build_word(buf, dac, lsb, data)` XS helper (returns the int register word; `_set` now just calls it + `_write_dac`), bound it for testing, and added HW-free `t/register.t` cases across the 8/10/12-bit lsb values including stale-cache scenarios. Negative control confirmed the tests catch the B9 bug: reverting the mask to the old `0xFFF >> lsb` fails the 8- and 10-bit stale-field guards, the fixed mask passes. This validates the B9 clear-mask fix without needing an 8/10-bit MCP4902/4912 part. Uncommitted in rpi-dac-mcp4922 (Changes, MCP4922.xs, t/register.t). Original: _set() (XS) combined word-building with the SPI write, so its register math wasn't HW-free unit-testable — that is why V18's clear-mask bug went uncaught. Discovered during V18.

## Explicitly NOT doing

- rpi-spi (was V11) — user directed skip mid-task (2026-07-06); no edits had been made. Reusable intel from the aborted prep, should it ever be revived: rpi-spi's tree was clean; wiringPiSPI.c confirms mode 0/8-bit/full-duplex tx==rx and that the module's GPIO-CS path still runs hardware channel 0 (CE0 hazard, cf. B8); datasheets.raspberrypi.com is TCP-unreachable from the Mac (all four AWS IPs drop SYNs) — the BCM2835 peripherals PDF pulls fine via the Wayback Machine, official pin/driver/speed facts live in raspberrypi/documentation `spi-bus-on-raspberry-pi.adoc` (master branch), and the official docs now link the datasheet at `https://pip.raspberrypi.com/documents/RP-008249-DS` (unverified from here). UPDATE 2026-07-07: the B8 fix (separate session) has since rewritten rpi-spi — uncommitted code + POD changes (SPI_NO_CS around GPIO-CS transactions, a true bit-bang mode, all three modes documented) — so the "tree was clean / no edits" statement above no longer holds, and the CE0 hazard is fixed (see B8).

- rpi-pca9685 — already has DEVICE SPECIFICS, REGISTER MAP, ON THE WIRE, and a datasheet link; it is the model the other dists copy.

- New DEVICE SPECIFICS for rpi-dac-mcp4922 — it already has one (the only non-model dist that does).

- Rewriting rpi-adc-ads `PHYSICAL SETUP` — it stays as-is; V1's DEVICE SPECIFICS adds the capability summary and cross-references it for wiring.
- Non-I2C/SPI dists (rpi-const, rpi-dht11, rpi-hcsr04, rpi-lcd, rpi-pin, rpi-serial, rpi-steppermotor, rpi-sysinfo, rpi-x) — outside the user's stated "uses I2C or SPI" scope (datasheet idea preserved as B1).
- rpi-i2cv, rpi-tracker — no Perl lib/POD to document.
- rpi-wiringpi umbrella REGISTER/WIRE sections — it's the board umbrella, not a chip driver; chip specifics belong in the driver dists (B2 covers its datasheet links).
- REGISTER MAP for rpi-i2c / rpi-spi — bus transports have no chip registers to map.
- Relocating datasheet links that already exist (SEE ALSO or inline) — user asked to add links only where missing; migration is B3, not this plan.
- git commits — the user reviews and commits all work himself.
