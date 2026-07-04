# Plan: Test platform completion + family-wide release readiness (MASTER)

> **NEXT ACTION:** V1 — supersession housekeeping (banner + move the three absorbed plans to plans/done/)
> **LAST SESSION:** 2026-07-03 — plan created from three research passes + 20-dist inventory; then adversarially debated (proposal/test-platform-release-master-plan-review.md, RESOLVED) and the agreed 12-point edit list applied: V6 retired (fixes already shipped 0.02/0.03), V7/V9/V26/V28 rescoped, V33+F11-F13 added, census 16/29/63 and 18-leaf counts corrected, sch-rev stamping added to V4/V8/V10
> **ARCHIVE:** See test-platform-release-master-archive.md for completed V tasks

## Goal

Get the RPi::WiringPi unit-test hardware platform finished (boards 1, 4, 5),
the test suite complete against it, and the entire family — the main dist plus
all 20 sub-module dists — released to CPAN. Every family dist currently sits
on an unreleased `UNREL` Changes section; the release train is the end state
this plan drives toward.

## Supersession

This master plan **supersedes** (absorbs all open work from):

- `test-platform-regen.md` — the model/doc-pipeline design doc. Most of its
  §9 checklist has since been implemented in-tree (render-doc.py,
  check-*.py gates, t/04, kicad/ relocation); V2 reconciles the residue.
- `test-coverage-gaps.md` — 13 open V tasks (V8, V13-V24) absorbed as V12-V24
  here; backlog B1-B18 absorbed below.
- `datasheet-audit-fixes.md` — V-complete; open backlog B1-B6 and the
  ADS1115→ADS1015 naming follow-up absorbed.

Also **carries forward** from `done/wiringpi-conformance-and-review.md` (file
stays in done/): V47 (servo calibration, → V27 here). Its V24 (version bump
3.1801_01→3.1802) is **overtaken by events** — 3.1802 shipped to CPAN
2026-06-12 and lib is now 3.1803 UNREL; V1 annotates it closed.

**NOT superseded:** `wiringpi-version-single-source.md` stays active as the
release-guard workstream; master V25 gates on its completion. Its execution
happens under its own file and rules.

**Findings policy:** the superseded plans' F-ledgers remain the permanent
audit record inside their files (moved to done/, never edited-down). Master
V/B rows cite them (e.g. "TCG F10") instead of re-ledgering. The `## Review
Findings` here contains only NEW findings from this session's research.

## Current known state (research evidence, 2026-07-03)

### Hardware — the five KiCad boards (docs/test-platform/kicad/)

| Board | Hosts | State | Rev | Gerbers | Locked |
|-------|-------|-------|-----|---------|--------|
| 1 | Pi 40-pin host + power/signal fan-out hub + I2C LCD (PCF8574 0x27 behind BOB-12009) + GPIO23/24/25/0/1 test points | **empty dir** (.gitkeep only); design not started; owns all cross-board nets (proposal §251-299) | - | - | - |
| 2 | ADS1115 0x48, MCP3008, MCP4922, MCP42010, 74HC595, servo (GPIO18) | finalized + **ordered** (287 segs, 50 vias) | 4 | yes | yes |
| 3 | MCP23017 ×2 (0x20/0x21), stepper + magnet limits, LEDs, I2C pull-ups | finalized + **ordered** (294 segs, 37 vias); most complete | 2 | yes | yes |
| 4 | DS3231 0x68, AT24C32 0x57, BMP180 0x77, SSD1306 0x3c | **scaffold only**: 9 footprints, 0 tracks, 0 vias, **no Edge.Cuts** | 1 | no | no |
| 5 | HD44780 LCD, Arduino 0x04 + BOB-12009, UART loopback | routed (151 segs, 26 vias) + outline, **no gerbers, not blessed** | 1 | no | **in %FROZEN but NOT in board-locks.json** |

Datasheet-audit verdict (proposal/test-platform-datasheet-validity-audit.md,
2026-06-22): boards 2+3 fab-clean end-to-end; the audit's board-4 driver
defects have since been **paid**: RPi::RTC::DS3231 0.02/0.03 (released
2026-06-22, CPAN at 0.03) fixed setMonth/setHour BCD + getTemp
sign-extension; AT24C32's broken eeprom_write_block was REMOVED in 1.00
UNREL (debate H7/H7b, 2026-07-03). V23 verifies depth; V7 clears the 1.00
residue.

### Test suite (this repo)

92 t/*.t, all with `# TESTDOC:` markers (generator-enforced). Board-gated:
RPI_BOARD_1 ×1 (t/335), _2 ×6, _3 ×2, _4 ×16, _5 ×4 — 29 files; 63 board-independent
(census re-measured in the 2026-07-03 debate, H4).
Rig runners `t/scripts/test_board_{2,3,4,5}.sh` — **no test_board_1.sh**.
Author tests t/900-915 gate on `RPI_RELEASE_TESTING`. Shared harness
t/RPiTest.pm (board-aware PWM→ADC windows). CI = Test::BrewBuild + perlbrew
on-Pi via t/crontab/crontab.txt; no cloud CI. MANIFEST clean (172/172 exist).
`make dist` → `regen_docs` → gen-pod-md.pl (→ gen-faq-test-table.pl) +
gen-test-platform.pl. scripts/, plans/, proposal/, docs/pod/,
docs/test-platform/ excluded from tarball; build_testing/ ships.

### Family release inventory (all 20 repos now in ~/repos; CPAN vs local)

**Every family dist has an UNREL Changes section.** Local module versions
ahead of CPAN everywhere except rpi-const/rpi-i2c/rpi-pin (version not yet
bumped). Highlights:

| Dist | CPAN | local | Notes |
|------|------|-------|-------|
| RPi::WiringPi (main) | 3.1802 | 3.1803 UNREL | early UNREL entries cite pre-renumber filenames |
| WiringPi::API | 3.1803 | 3.1804 UNREL | guard min 3.18 (canonical); stray untracked PDF in worktree |
| RPi::Pin | 3.1801 | **3.1801** (Changes 3.1802 UNREL) | **main requires 3.1802 — exists nowhere** |
| RPi::Const | 1.06 | 1.06 UNREL | BuildCheck home (other plan) |
| RPi::I2C | 3.1801 | 3.1801 | **Changes top says "2.3609 UNREL"** |
| RPi::EEPROM::AT24C32 | 0.01 | 1.00 UNREL | biggest version jump |
| others (ADC::ADS 1.04, MCP3008/BMP180/DAC/DigiPot/HCSR04/LCD/OLED/SPI/StepperMotor 3.1802, DHT11 1.06, GPIOExpander 1.04, RTC 0.04, Serial 3.03, SysInfo 1.03) | one behind | UNREL | all need releases |

Guards: 16 dists have NO Makefile.PL guard; dht11 + oled presence-only;
gpioexpander i2c-only; wiringpi-api full (3.18). Full detail in
`wiringpi-version-single-source.md`. Raw inventory TSV preserved in this
session's scratchpad; regenerate anytime via the V25 audit script.

## Design (decisions)

- **Board completion order: 4 → 5 → 1.** Board 4 unblocks 16 gated tests +
  coverage V23's HW half; board 1 is the hub and is "built last" per the
  proposal (it owns the cross-board nets, so its design freezes after 4/5).
  Debate-tested: hub-first died on the nets doc (I2C pull-ups live on built
  board-3; GPIO18 already jumpers to board-2 — the rig works hubless).
- **Board-4 driver debt is already paid** — RPi::RTC::DS3231 0.02/0.03
  (2026-06-22, on CPAN) fixed the BCD writes and temp sign-extension;
  AT24C32's broken eeprom_write_block was removed in 1.00 UNREL. V23
  verifies depth on silicon; V7 clears the 1.00 residue. (Debate H7 retired
  the original "fix before bring-up" task V6 — already shipped.)
- **One lock source of truth** (V9): `board-locks.json` becomes canonical;
  t/04's `%FROZEN` and gen-kicad.py's refuse-if-exists derive from it
  (datasheet-audit B5, its F17).
- **Release train order:** rpi-const (with BuildCheck) → wiringpi-api →
  the 18 leaf dists → rpi-wiringpi main last. The FLOOR-required edges
  (debate H1) are only: const→everything (post-V25, via CONFIGURE_REQUIRES);
  pin→main; every floor V26 raises→main. Waves 2-before-3 and 3-before-4
  beyond those edges are risk convention (XS core first, main last), not
  floor requirements — 20 of 21 of today's floors already resolve on live
  CPAN. Nothing ships until: guard shim in place (V25), the V26 audit
  passes, and V28's split verification is green (Pi: full suites + disttest;
  mac: dist + MANIFEST only — 13 XS dists cannot build there).
- **User-only actions:** all git commits, `--bless` sign-offs on locked
  boards, fab orders, CPAN uploads, and powered-rig sessions. V tasks stop at
  working-tree changes + verification.
- Evidence throughout is dated 2026-07-03; agents' full reports live in this
  session; re-verify file-level claims before acting on stale ones.

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of test-platform-release-master-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
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

Phases: P0 housekeeping · PH hardware · PC coverage (absorbed from test-coverage-gaps, "TCG") · PR release.

| ID | What | Command | Expected | Actual |
|----|------|---------|----------|--------|
| V1 | **P0** — Supersession housekeeping: add a `> **SUPERSEDED:** by test-platform-release-master.md (YYYY-MM-DD)` banner atop test-platform-regen.md, test-coverage-gaps.md (+archive), datasheet-audit-fixes.md (+archive); move all five files to plans/done/; annotate done/wiringpi-conformance-and-review.md: V24 closed-overtaken (3.1802 shipped 2026-06-12), V47 carried → master V27 | `ls plans/ plans/done/` | plans/ holds only this master (+future archive) and wiringpi-version-single-source.md; banners in place | ⏳ |
| V2 | **P0** — Reconcile the absorbed test-platform-regen §9 checklist against the tree: verify each of its 10 items as done/partial/open (render-doc.py, facts/ flow, model drift items, kicad relocation, regen orchestration, drift gate all appear implemented); record the verdict table in this plan; file any residue as new V/B rows | inspect scripts/helpers/*, docs/test-platform/, t/04 | Every checklist item dispositioned with file evidence; residues captured (kicad/legacy refs already → V3) | ⏳ |
| V3 | **P0** — Fix stale references: t/04-test-platform-model.t:45 and docs/test-platform/README:60,71 cite nonexistent `kicad/legacy/`; normalize the three conflicting board-5 status wordings (README "hand-finalized" / matrix "being finalized" / t/04 "in progress") to in-progress; build the old→new renumber map and mechanically sweep t/*.t comments, docs/, and POD for stale pre-renumber test filenames (F12; proven instance: t/543-eeprom_validation.t:10 cites "t/420-422" for what is now t/540-542) | `RPI_BOARD=1 prove -l t/04-test-platform-model.t` (on Pi) or perl -c + grep locally | No dangling legacy/ references; consistent board-5 status; zero stale pre-renumber filenames repo-wide; t/04 still passes | ⏳ |
| V4 | **PH** — Board-2 provenance repair (F4): restore ZC261500.kicad_sym (ADS1115 breakout) from the restore-backup into the live board-2 project + a project sym-lib-table; define the `RPi` footprint lib in board-2's fp-lib-table (or migrate the ADS1115_Breakout footprint into the project .pretty); refresh the stale .pretty ref/value assignments; stamp the schematic title_block rev to match the PCB (sch currently UNSET vs PCB rev 4 — debate H10); user re-blesses (`check-board-locks.py --bless board-2`) | `python3 scripts/helpers/check-board-locks.py` + `perl scripts/unit_test_board_revisions.pl` | Board-2 opens/renders from a fresh clone with no global-lib dependence; sch/PCB revs in lockstep; locks green after bless | ⏳ |
| V5 | **PH** — ADS1115 vs ADS1015 reconciliation (F7; user-authorized 2026-06-23): with the user physically confirming the 0x48 part on the built board-2 (chip marking / 12-vs-16-bit read), align proposal/matrix/added-hardware/FAQ/model/RPiTest naming to the as-built truth | grep -rn 'ADS10\|ADS11' docs/ t/ lib/ scripts/helpers/ | One name everywhere, matching the physical part; datasheet-audit follow-up closed | ⏳ |
| V7 | **PH** — rpi-eeprom-at24c32 1.00 residue (debate H7b: the broken eeprom_write_block export was already REMOVED — Changes 1.00 UNREL, zero grep hits in AT24C32.xs): delete the dead static `_writeBlock` (AT24C32.xs:47), disposition the orphaned eeprom_read_current_byte/eeprom_close, add tests covering the 1.00 changes (TCG B5) | `cd ~/repos/rpi-eeprom-at24c32 && perl Makefile.PL && make test` | Residue cleared; 1.00 changes test-covered (HW-free harness or gated) | ⏳ |
| V8 | **PH** — Board-4 PCB completion: sync board-4-model.py ↔ layout, finalize placement, draw Edge.Cuts, route, pour zones, DRC clean, add RPI_BOARD_4 silk label + title_block title and rev (PCB AND schematic, in lockstep — debate H10), plot gerbers + gerber.zip. User blesses (`check-board-locks.py --bless board-4`) and orders fab | kicad-cli DRC + `perl scripts/unit_test_board_revisions.pl` | DRC 0 errors; gerbers produced; revs stamped both files; silk labeled; blessed | ⏳ |
| V9 | **PH** — Lock unification (F3; DSA B5/F17), mechanism ONLY (debate H6 — blessing itself happens in V8/V10 where those boards close): board-locks.json becomes the single "off-limits" source — t/04 `%FROZEN` derives from it, gen-kicad.py refuses per it | `RPI_BOARD=1 prove -l t/04-test-platform-model.t` + `python3 scripts/helpers/check-board-locks.py` | One definition; a frozen-but-unblessed state is impossible by construction | ⏳ |
| V33 | **PH** — Canonical Arduino 0x04 sketch (F11; row sits before V10 per the debate's "before V10 closes" — IDs stable, order meaningful): docs/sketch/arduino.ino and docs/sketch/arduino/arduino.ino ship as byte-identical duplicates (MANIFEST:46-47); ~/repos/rpi-i2c/examples/arduino.ino diverges functionally (`eeprom_save_byte(byte*)` vs `(byte)`, word endianness) and is NOT in rpi-i2c's MANIFEST beside 8 shipped examples/*.pl. Pick the canonical sketch, de-dup docs/sketch to one path (MANIFEST + FAQ.pod ~1500), reconcile or delete the rpi-i2c fork | diff the three copies; grep MANIFEST + FAQ.pod refs | One canonical sketch at one shipped path; rpi-i2c examples and t/605 presuppose the same wire behavior; rig-flash verification handled in V10/V28 | ⏳ |
| V10 | **PH** — Board-5 finish: annotate the 4 `REF**` mounting holes, resolve HD44780_20x2-vs-20×4 spec mismatch (F6; user decides per physical panel), stamp the schematic title_block rev to match the PCB (sch currently UNSET vs PCB rev 1 — debate H10), verify/flash the rig Arduino with the V33 canonical sketch, DRC, plot gerbers, user blesses | kicad-cli DRC + `python3 scripts/helpers/check-board-locks.py` | DRC clean; gerbers exist; revs in lockstep; rig Arduino runs the canonical sketch; blessed; value matches the real panel | ⏳ |
| V11 | **PH** — Board-1 design (the hub, last): schematic + PCB per proposal — Pi 40-pin header, power/signal fan-out to satellites (+5V/+3V3/GND rails ~1.1A peak, per-board +3V3 sense returns), I2C LCD (PCF8574 0x27 + BOB-12009), GPIO18 workhorse net kept high-impedance, GPIO17/27 fan to boards 3+5, GPIO23/24/25/0/1 test points; gerbers; add t/scripts/test_board_1.sh (F8); user blesses + orders | kicad-cli DRC + `bash t/scripts/test_board_1.sh` (on Pi) | Board-1 project complete + locked; runner exists; t/335 runs under it | ⏳ |
| V12 | **PC** (was TCG V13) — RPi::ADC::MCP3008 HW-free: fetch input-range croak (0-15), percent math (÷1023, stubbed fetch), _channel undef die (wiringPi stub/load-guard — no env gate today); fix TCG F9 (spi_setup/wpi_setup exit(errno)→croak); note fetch GPIO-CS FIXME; decode → B-item | `cd ~/repos/rpi-adc-mcp3008 && make test` + mirror in t/ here | Validation covered HW-free; F9 fixed | ⏳ |
| V13 | **PC** (was TCG V14) — RPi::SPI HW-free: _channel GPIO routing, _speed default + TCG F13 (explicit 0 → silently 1MHz), _cs round-trip, new/rw arg validation; stubbed spiDataRW for rw framing | `cd ~/repos/rpi-spi && make test` + mirror | Routing + validation covered; F13 fixed | ⏳ |
| V14 | **PC** (was TCG V15) — RPi::Serial HW-free: crc/crc16 vectors, tx frame+CRC order, rx reassembly + CRC-mismatch warn + pre-start discard, write undef croak + >255 wrap; TCG F14 (new() fd=-1 no croak; baud unvalidated) | `cd ~/repos/rpi-serial && make test` + mirror | Framing stack + validation covered; F14 fixed | ⏳ |
| V15 | **PC** (was TCG V16) — RPi::StepperMotor HW-free via injected mock expander: cw/ccw patterns + wraps, _turns rounding, _pins/new croaks; fix TCG F10 (speed() inverted dead validation) | `cd ~/repos/rpi-steppermotor && make test` + mirror | Step logic covered; F10 fixed | ⏳ |
| V16 | **PC** (was TCG V17) — RPi::HCSR04: fix TCG F11 (new() never blesses) + F12 (pin guard `&&`→`||` dead range check) with tests; un-gate 05-new.t validation; cm/inch math extraction → B-item | `cd ~/repos/rpi-hcsr04 && make test` | Real blessed object; live pin validation; tests off-board | ⏳ |
| V17 | **PC** (was TCG V18) — RPi::DHT11 noboard-mode wins (RDE_NOBOARD_TEST=1): temp('f') conversion, humidity sanity, c_debug; reconcile TCG F17 (RPI_BOARD vs RPI_DHT11 vs unused RDE_HAS_BOARD) | `cd ~/repos/rpi-dht11 && make test` + mirror | HW-free paths covered; one coherent gate story | ⏳ |
| V18 | **PC** (was TCG V19) — RPi::BMP180: _pin_base validation (non-int/unset die) + mirror; compensation/OSS math gap stays logged (TCG B10) | `cd ~/repos/rpi-bmp180 && make test` + mirror | Validation HW-free; upstream math gap logged | ⏳ |
| V19 | **PC** (was TCG V20) — RPi::LCD HW-free: init(%params) 14 required-key death tests (lcd_init mocked), _fd(-1) confess + round-trip, print/puts + print_char/put_char alias identity | `cd ~/repos/rpi-lcd && make test` + mirror | init/_fd/aliases covered HW-free | ⏳ |
| V20 | **PC** (was TCG V21) — RPi::OLED::SSD1306 HW-free croak/bounds: rect/pixel bounds, dim/invert 0/1, text_size ^\d+$; TCG F16 (silent singleton ignores new addr/splash) | `cd ~/repos/rpi-oled-ssd1306 && make test` + ungated mirror | 6 validating methods + singleton behavior covered | ⏳ |
| V21 | **PC** (was TCG V22) — RPi::SysInfo: ungate cpu_percent/mem_percent (XS runs on any Linux), OO-form replay through the seam, 16GB revision decode, TCG F15 (_format -1.0 sentinel; malformed raspi_config regex) | `cd ~/repos/rpi-sysinfo && make test` + mirror | Wrappers + OO + defects covered HW-free | ⏳ |
| V22 | **PC** (was TCG V23) — WiringPi::API interrupt machinery HW-free: auto_dispatch_interrupts (enable/disable, unknown-signal croak, handler save/restore) + singular background_interrupt + results channel, via faked self-pipe + stubbed _arm_interrupt (t/75 pattern) | `cd ~/repos/wiringpi-api && make test` | Dispatch wiring + framed results + teardown covered | ⏳ |
| V23 | **PC** (was TCG V8) — RPi::RTC::DS3231 depth: full 0-99 BCD round-trip + field maxes in t/532, temp decode incl. negative path, HW-free setter validation croaks (mock-fd; TCG B3). HW half runs once board-4 is live (V8) | `prove -l t/532-rtc-bcd.t` + dist tests | BCD/temp/validation HW-free green; HW portion queued on board-4 | ⏳ |
| V24 | **PC** (was TCG V24) — FAQ "RUNNING TESTS" prose audit: fix the Setup intro's pin-doc pointer (README carries no pins; test-pinout-doc.md does) + legacy breadboard-diagram link; reconcile t/420/421 board-2 gating (add RPI_BOARD_2 block or confirm board-independent); sweep env-var prose, rig-runner refs, t/scripts links vs reality — t/scripts/*.sh are NOT in MANIFEST while the shipped FAQ references them: record an explicit ship-or-author-only disposition; regen docs | `perl scripts/gen-pod-md.pl && git diff --stat` | FAQ section accurate; 420/421 dispositioned; t/scripts disposition recorded; no stale prose | ⏳ |
| V25 | **PR** — Complete the wiringpi-version-single-source plan (V1-V8 there, under its own file/rules; user may authorize batching there): BuildCheck in rpi-const, shim in all 20 dists, xt drift gate, docs | `perl scripts/audit-family-buildcheck.pl --markdown` | Zero drift rows; that plan's table empty | ⏳ |
| V26 | **PR** — Version/floor/Changes AUDIT (F1, F2, F9; debate H1+H7): re-derive every claimed defect and floor from the CURRENT tree — assume staleness (three parties propagated one dead fact in the 2026-07-03 debate). Two-directional floors: (a) every PREREQ floor resolvable at its release wave; (b) floors RAISED to the fix-carrying version wherever main's suite depends on fixed behavior (RPi::Pin→3.1802, RPi::EEPROM::AT24C32→1.00, each V12-V21 fix-carrier; RTC already correct at 0.03). Bump RPi::Pin module to 3.1802; fix rpi-i2c Changes header (2.3609→current); rewrite main's stale UNREL filenames; drop-or-fill empty UNREL sections (rpi-rtc-ds3231 0.04) | rerun family inventory; `perl -c` each touched file | Floors resolvable at wave AND raised where the suite depends on them; Changes files coherent; audit table recorded in this plan | ⏳ |
| V27 | **PR** (was conformance V47; USER rig) — t/325 servo calibration windows: replace vacuous bounds with calibrated LEFT(60)/CENTRE(150)/RIGHT(255) + sweep windows in RPiTest.pm (phase-dependent ADS integration noted); same powered session live-proves the t/400-pwm_hw_mods.t / t/405-pwm_i2c_adc.t model windows (post-renumber names — F12) + poll conversions; physical checklist in the conformance plan | on-Pi: `RPI_BOARD_2=1 prove -lv t/425-servo.t` (renumbered 325→425) | Sweep green with real windows; calibration recorded in RPiTest.pm | ⏳ |
| V28 | **PR** — Pre-release verification, SPLIT legs (debate H8: 13 XS dists + main cannot configure/build on mac — wiringPi.h, linux/i2c-dev.h, -lrt; RPiTest.pm:33-36 hard-uses the stack). ON PI: per-board suites `t/scripts/test_board_{1..5}.sh` green; full 92-file suite green; `RPI_RELEASE_TESTING=1` author tests (900-915) green; `make disttest` for all 21 dists. ON MAC: `RPI_DIST_RELEASE=1 make dist` + MANIFEST verification per dist (+ optional rpi-const disttest). BOTH: clean worktrees (incl. wiringpi-api's stray PDF — F10); rig Arduino verified on the V33 canonical sketch | Pi + mac runs + `git status` sweep across ~/repos | All green, all clean on the leg that can run it; train may start | ⏳ |
| V29 | **PR** — Release wave 1: rpi-const (BuildCheck inside). Prepare final Changes/version/README; user uploads; verify CPAN indexes + testers start PASS/NA (never FAIL) | metacpan check post-upload | RPi::Const live; CONFIGURE_REQUIRES resolvable for the family | ⏳ |
| V30 | **PR** — Release wave 2: WiringPi::API 3.1804. Prep gains the six-site wiringpi.com → github.com/WiringPi/WiringPi sweep + an explicit install-≥3.18 pointer (API.pm:1922, 1926, 2516, 2572, 2652, 2825 — F13); user uploads; verify | metacpan + testers | Live + green; no defunct-domain links shipped | ⏳ |
| V31 | **PR** — Release wave 3: the 18 leaf dists (debate H9: 20 sub-dists − const − api; rpi-i2c IS in the train — only its breaking changes defer to B15). Batch prep, one commit set per repo; user uploads in any order after waves 1-2 | family inventory rerun: CPAN == local everywhere | All 18 leaves live; zero UNREL sections left in leaves | ⏳ |
| V32 | **PR** — Release wave 4: RPi::WiringPi 3.1803 (main, last): final regen_docs, MANIFEST check, verify every V26-raised floor is indexed on CPAN before upload, disttest on the Pi, user uploads; then watch CPAN testers across the family for a week; file any FAILs as new V rows | metacpan + testers matrix | Raised floors indexed; main live; family-wide testers PASS/NA only | ⏳ |

## Discovery Tracking

_None yet._

## Review Findings

New findings from this session's research only (absorbed plans' ledgers live in their files in done/).

- **F1** (→V26): Release blocker — this repo's Makefile.PL requires `RPi::Pin => 3.1802`, but CPAN has 3.1801 and rpi-pin's module file is still 3.1801 (only its Changes says 3.1802 UNREL). Released today, RPi::WiringPi is uninstallable.

- **F2** (→V26): rpi-i2c's Changes top section reads `2.3609 UNREL` while the module is 3.1801 — stale header from the 3.19→3.1802 rename.

- **F3** (→V9): Lock divergence — board-5 is in t/04's `%FROZEN` (skipped from validation) but absent from board-locks.json (not byte-frozen): currently ungated entirely. Three uncoordinated "off-limits" definitions exist.

- **F4** (→V4): Board-2 is not reproducible from the repo — the ADS1115 symbol (ZC261500.kicad_sym) exists only in a gitignored `_restore_backup_*` dir; the PCB references footprint lib alias `RPi:` defined in no repo fp-lib-table (resolves only via the user's global KiCad config); the untracked ADS1115.mod and `kicad/unit_tests/` seen in the session-start git status no longer exist on disk (KiCad restore side-effect); board-2's own .pretty ref/values are stale scaffold.

- **F5** (→V3): t/04-test-platform-model.t and docs/test-platform/README reference `kicad/legacy/`, which does not exist.

- **F6** (→V10): Board-5's LCD1 value is `HD44780_20x2` but board-layout-proposal.md:217/:239 specify a 20×4 panel (pointer corrected per debate).

- **F7** (→V5): ADS1115-vs-ADS1015 naming conflict — proposal/matrix/added-hardware say ADS1015; the built board-2, FAQ address map, and symbol say ADS1115; the datasheet audit concluded the 0x48 part is a 12-bit ADS1015. User authorized the doc fix 2026-06-23; still open. Resolve against the physical chip.

- **F8** (→V11): No t/scripts/test_board_1.sh despite board-1 having a gated test (t/335) and the FAQ referring to per-board runners.

- **F9** (→V26): Main repo's 3.1803 UNREL section's early entries cite pre-renumber test filenames (t/321-rtc-bcd, t/140-pwm_spi_adc, …) that no longer exist — confusing for release notes.

- **F10** (→V28): ~/repos/wiringpi-api worktree contains a stray untracked PDF ("Markdown Print | print.markdown.janqi.com.pdf") — hygiene before its release.

- **F11** (→V33): The Arduino 0x04 slave firmware exists in three copies with two behaviors — docs/sketch/arduino.ino + docs/sketch/arduino/arduino.ino ship byte-identical (MANIFEST:46-47) while rpi-i2c/examples/arduino.ino diverges (`eeprom_save_byte(byte*)` vs `(byte)`, word endianness) and is unshipped beside 8 shipped examples/*.pl. One physical Arduino runs ONE firmware; main's t/605 and rpi-i2c's examples cannot both be right against the same rig. (Debate H2.)

- **F12** (→V3, V27): Stale pre-renumber test filenames persist in t/ and in this plan itself — t/543-eeprom_validation.t:10 cites "t/420-422" for what is now t/540-542; V27's carried-forward text said "t/109/t/140" for t/400/t/405. Same disease F9 diagnosed in Changes. (Debate H3.)

- **F13** (→V30): wiringpi-api's POD sends users to the defunct wiringpi.com at six sites (API.pm:1922, 1926, 2516, 2572, 2652, 2825) while main's 3.1803 UNREL already migrated its own links to github.com/WiringPi/WiringPi. (Debate H5.)

## Backlog

Absorbed from test-coverage-gaps (TCG) — dist-refactor enablers:

B1: (TCG B1) rpi-dac-mcp4922 — extract the SPI 16-bit word assembly into a pure builder returning the word, so mask/shift math is unit-testable.

B2: (TCG B2) rpi-adc-ads — expose pga_fsr + 12-vs-16-bit full-scale + VREF/percent scaling for HW-free tests (the rig chip's 12-bit path is production with zero HW-free verification).

B3: (TCG B4/B11) cross-repo — split HW-free validation/math tests out of RPI_*/PI_TEST skip_all gates; add noboard/env gates to dists that have none (mcp3008, spi, bmp180, lcd, oled, hcsr04); reconcile gate-var names.

B4: (TCG B5) rpi-eeprom-at24c32 — remove dead _writeBlock; wire or remove orphaned eeprom_read_current_byte/eeprom_close (partially handled in V7).

B5: (TCG B6) rpi-gpioexpander-mcp23017 — getFd/_establishI2C exit(-1) → croak.

B6: (TCG B7) rpi-adc-mcp3008 — extract fetch's frame-build + 10-bit decode into a pure helper; add env gate.

B7: (TCG B8) rpi-hcsr04 — extract pure raw→cm/inch conversion (divisor 58 vs 58.27, also DSA B3).

B8: (TCG B9) rpi-dht11 — injectable 5-byte frame for read_env so bit-decode + checksum are testable.

B9: (TCG B10) BMP180 compensation/OSS math lives in WiringPi::API XS — add coverage there or a Perl-side injectable refactor.

B10: (TCG B12) systematic mirror sweep — diff each sub-repo t/ against rpi-wiringpi/t/, port non-conflicting tests, prove the superset property.

B11: (TCG B13) rpi-pin — validate mode_alt($alt) input (TCG F18).

B12: (TCG B14) rpi-gpioexpander-mcp23017 — expose bit.c via thin XS for HW-free bit-math tests; check bitCount(0,0) __builtin_clz(0) UB + bitGet precedence.

B13: (TCG B15) rpi-eeprom-at24c32 — new() should croak/warn on eeprom_init -1 instead of fd=-1 object (TCG F6).

B14: (TCG B16/B17) rpi-wiringpi core — pin-collision croak via mocked register_pin, factory smoke tests, meta_remove/unregister shm lifecycle; _class_signal_handler prior-handler chaining + GLOBAL_PHASE DESTRUCT early-return.

B15: (TCG B18) rpi-i2c — coordinated breaking API fixes: read_bytes accumulation (TCG F7), write_word arg order (TCG F8), process() POD/arg order, write_block 32-byte cap. Schedule as its own minor release AFTER the main train.

Absorbed from datasheet-audit-fixes (DSA):

B16: (DSA B1) datasheet PDF provenance — committed sha256 per cited PDF in datasheet-pinouts.json + a re-fetch/verify step.

B17: (DSA B2) explore automatable driver-behaviour-vs-datasheet gates (register-constant tables).

B18: (DSA B4) cosmetic dist cleanups — SSD1306 VCOMH level, DS1307 temp() guard, BMP180 OSS selectable, RPi::BMP180 POD SYNOPSIS ->new.

B19: (DSA B6) board-model.py ↔ board-N-model.py drift check (cheap diff of copied pin maps) — verify against V2's findings; check-model-drift.py may already cover it.

New:

B20: UNWRAPPED.md roadmap — 69 of 107 WiringPi::API capabilities have no RPi::WiringPi wrapper (i2c_*, serial_*, spi_*, lcd_*, soft_pwm_*, set_pad_drive, …); triage which to wrap/document post-release.

B21: Release-state check for the user's non-family prereqs (GPSD::Parse, IPC::Shareable) — confirm CPAN-current before wave 4.

B22: Keep KiCad schematic title-block revs in lockstep with PCB revs at bless time. Live mismatches exist on LOCKED boards (board-2 sch UNSET vs PCB 4; board-5 sch UNSET vs PCB 1 — stamped in V4/V10; debate H10). Also extend scripts/unit_test_board_revisions.pl to flag a SET PCB rev with an UNSET schematic rev — today it only flags when both exist and differ, which is why these mismatches went unreported.

## Explicitly NOT doing

- **V6 (retired 2026-07-03, slot never reused)** — "rpi-rtc-ds3231 driver debt (BCD writes + temp sign-extension)" was a zombie task: every fix was already released 2026-06-22 as 0.02/0.03 (CPAN at 0.03; DS3231.xs:50 setBcdField, :188-190 `(int8_t)msb`). Killed by debate H7; V23 verifies depth on silicon instead.
- **Re-executing already-implemented test-platform-regen items** — the render/check pipeline exists in-tree; V2 verifies rather than rebuilds.
- **Absorbing wiringpi-version-single-source.md** — it stays the active guard workstream (V25 gates on it); duplicating its 8 tasks here would fork the ledger.
- **Wrapping the 69 unwrapped API capabilities before the release train** — roadmap work (B20), not release-gating.
- **Cloud CI (GitHub Actions)** — the project's CI is Test::BrewBuild on the Pi by design; the drift gates run in `make test`.
- **rpi-i2c breaking API fixes inside the main train** (B15) — coordinated contract changes ship separately so the train stays low-risk.
- **Committing, blessing locked boards, ordering fab, or uploading to CPAN on Steve's behalf** — per git rules and lock workflow, every commit/bless/order/upload is his.
