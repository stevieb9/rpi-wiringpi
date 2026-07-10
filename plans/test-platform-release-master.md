# Plan: Test platform completion + family-wide release readiness (MASTER)

> **NEXT ACTION:** V35 — rpi-eeprom-at24c32 on-silicon verify (USER hardware; **needs board-4 wired**, NOT board-2 which is currently connected): confirm the 1.00 ACK-polling write cycle returns as soon as the AT24C32 (0x57) ACKs + a write→read round-trip is correct. Then V28 (pre-release gate). (V27 ✅ DONE 2026-07-10.)
>
> **ORDERING (revised 2026-07-09):** reordered so everything is settled before the audit/verify/release back-end. Sequence: **V25 (✅ DONE)** → **V26 (✅ DONE 2026-07-09 — audit-only; no floor edit needed, all resolve at wave; F9 filenames fixed, F1/F2 validated as pre-resolved)** → **V27** + **V35** (user-hardware sessions; must precede V28) → **V28** (pre-release verification gate) → **V29-V32** (release waves, in const→api→leaves→main order). This supersedes the earlier "V25 last" (user delegated the call): V25 can't follow the release waves, since V28 disttests all 21 dists and V31 ships the leaves.
> **LAST SESSION:** 2026-07-10 — closed **V27** (USER powered board-2 rig, no servo — ADS1015 reads GPIO18 PWM on A0). Sanity-checked the rig live (0x48 ACKs; GPIO18→A0 drive test high→~2.2V / low→0V / idle→0V, confirming a ~2/3 resistive divider on the board's GPIO18 net + no RC averaging). Replaced t/425's vacuous ±40 bound with a real calibrated gate: single ADS reads are phase-dependent (0..~33 at every position, useless — a severed line reading 0 passes), but the MEAN of 100 reads tracks ideal duty within ~0.3pt (LEFT→3.0/CENTRE→7.5/RIGHT→12.75). Single-sourced `%servo_adc_windows{pi5}` + `rpi_servo_adc_window()`/`rpi_servo_adc_mean()` in RPiTest.pm; t/425 now asserts mean-in-window (LEFT[1.5,5.5]/CENTRE[5.5,10.5]/RIGHT[10.5,15.5]) + sweep gate (read≤36, peak>15). 6/6 + peak GREEN (RIGHT hit 14.27 on final run → validated the 15.5 ceiling). Same session live-proved t/400 + t/405 windows still hold. **Lone failure across t/425/400/405-in-isolation = pre-existing pin-18 mode-31 contamination (got 0/expected 31), PROVEN pre-existing via stash-compare → flagged for V28.** **Uncommitted: t/RPiTest.pm + t/425-servo.t — user commits.** NEXT = V35 (needs board-4 wired).
> **ALSO 2026-07-10 (overnight, user-directed):** NEW family leaf **RPi::StepperMotor::A4988** (0.01 UNREL, pure-Perl A4988 stepper driver, DI GPIO transport). **HARDWARE IS ON HAND — the user PHYSICALLY BOUGHT it:** a *NEMA17 Stepper Motor Kit, 1.0 A/phase, 33 N·cm holding torque* (standard 1.8°/200-step motor + an A4988 Pololu-style driver carrier). So the gated HW test t/353 can be run on real silicon whenever he wires it. Before running under load, set the A4988's VREF current-limit pot to ~1.0 A (I_trip = VREF/(8·Rsense)); the module's DEFAULT steps_per_rev=200 already matches the 1.8° motor. Reviewed = reasonable/datasheet-accurate, no defects (F15); dist suite 74 PASS; installed locally. Authored + verified the requested main-repo tests: **t/354-a4988_unit.t** (non-gated HW-free mirror, 52/52) + **t/353-a4988.t** (full gated HW test, `RPI_A4988`, live GPIO readback 22/22 — confirmed RP1 returns the output-latch on read, so the readbacks are real). Added both to MANIFEST + regenerated the FAQ test-table. New task **V36** tracks the A4988 CPAN release + the main PREREQ_PM edge; it is device-gated (`RPI_A4988`), NOT tied to any board. **Uncommitted: t/353, t/354, MANIFEST, FAQ.pod, plan (+ the separate ~/repos/rpi-steppermotor-a4988 repo) — user commits.** **Rule: present point-form plan before executing any V task.**
> **PRIOR SESSION:** 2026-07-09 — closed V26 (version/floor/Changes audit, audit-only): re-derived all 23 main floors from the current tree — none needs editing (all resolve at their wave; fix-carriers Pin 3.1802 / Serial 3.03 / RTC 0.03 / Const 1.06 already raised; EEPROM checked and left at 0.01 — suite has no 1.00 dependency). F9 fixed: rewrote 9 stale filenames in main's UNREL Changes. F2 validated as already-resolved (user's rpi-i2c rework). F1 validated w/ correction (no longer a blocker; CPAN-index confirm → V32). Audit table recorded under "## V26 audit". Conservative scope: zero edits outside rpi-wiringpi; rpi-pin empty-stub flagged → V31. Also earlier this session: closed V25 (verify-only), F10 confirmed resolved. V14 (RPi::Serial): TCG F14 fixed + surfaced and fixed 3 more real bugs (write() >255 silent-wrap→croak; **tx() was sending 0x00 for the payload**; **rx() returned a defined 0 mid-frame**; **flush() called an undefined tty_flush → added the XSUB**). Dist t/05-unit.t + **live t/10-loopback.t (8/8 PASS on real TX↔RX loopback, /dev/ttyAMA0, gate RPI_SERIAL_LOOPBACK)**; main mirror t/438 = crc vectors only (installed 3.02 predates/breaks the rest). Then (user-directed) rewrote t/610-serial.t into a full live-loopback suite + real-world CRC-framed example, which found + fixed a 6th RPi::Serial bug (tty_open not fully raw — ICRNL mapped 0x0D→0x0A); installed 3.03, bumped main prereq to 3.03. **Rig now has serial loopback wired** (GPIO14↔15) — usable for V28; t/610 26/26 serial tests green (only pre-existing pin-8 contamination fails). **HEADS-UP: sub-dists actively reworked — re-verify each PC row vs the tree first.** **Uncommitted: rpi-wiringpi, rpi-eeprom-at24c32, rpi-i2c, rpi-adc-mcp3008, rpi-spi, rpi-serial — user commits.** F2 looks resolved (rpi-i2c 3.1803 UNREL) → V26. **Rule: present point-form plan before executing any V task**
> **ARCHIVE:** See test-platform-release-master-archive.md for completed V tasks (V1-V5, V7-V10, V12-V27, V33, V34)

## Goal

Get the RPi::WiringPi unit-test hardware platform finished (boards 1, 4, 5),
the test suite complete against it, and the entire family — the main dist plus
all 21 sub-module dists (the original 20 + RPi::StepperMotor::A4988, added
2026-07-10) — released to CPAN. Every family dist currently sits
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

**Findings policy:** the three absorbed plans and their two archives were
**deleted** (commit `ecd6971` "Plan updates", 2026-07-09; user confirmed
leave-gone — recover from `ecd6971^` only if ever needed). Their TCG/DSA
F-/B-ledgers therefore no longer exist as standalone files; they survive ONLY
as the inline descriptions carried in this master's V/B rows (each row spells
out its own fix, so the *work* is self-contained). Master rows still cite the
original tags (e.g. "TCG F10", "DSA B1") as historical provenance — treat those
citations as pointers into git history, not into live files. The `## Review
Findings` here contains only NEW findings from this session's research.

## Current known state (research evidence, 2026-07-03)

### Hardware — the five KiCad boards (docs/test-platform/kicad/)

| Board | Hosts | State | Rev | Gerbers | Locked |
|-------|-------|-------|-----|---------|--------|
| 1 | Pi 40-pin host + power/signal fan-out hub + I2C LCD (PCF8574 0x27 behind BOB-12009) + GPIO23/24/25/0/1 test points | **empty dir** (.gitkeep only); design not started; owns all cross-board nets (proposal §251-299) | - | - | - |
| 2 | ADS1115 0x48, MCP3008, MCP4922, MCP42010, 74HC595, servo (GPIO18) | finalized + **ordered** (287 segs, 50 vias) | 4 | yes | yes |
| 3 | MCP23017 ×2 (0x20/0x21), stepper + magnet limits, LEDs, I2C pull-ups | finalized + **ordered** (294 segs, 37 vias); most complete | 3 | yes | yes |
| 4 | DS3231 0x68, AT24C32 0x57, BMP180 0x77, SSD1306 0x3c | finalized + **ordered**; Edge.Cuts + routed + DRC-clean; blessed (re-blessed V34; commit pending) | 2 | yes | yes |
| 5 | HD44780 LCD, Arduino 0x04 + BOB-12009, UART loopback | finalized + **ordered**; routed + outline + gerbers; blessed (re-blessed V34; commit pending; sch title-block rev still UNSET vs PCB 1 — B22, deferred) | 1 | yes | yes |

Datasheet-audit verdict (proposal/test-platform-datasheet-validity-audit.md,
2026-06-22): boards 2+3 fab-clean end-to-end; the audit's board-4 driver
defects have since been **paid**: RPi::RTC::DS3231 0.02/0.03 (released
2026-06-22, CPAN at 0.03) fixed setMonth/setHour BCD + getTemp
sign-extension; AT24C32's broken eeprom_write_block was REMOVED in 1.00
UNREL (debate H7/H7b, 2026-07-03). V23 verifies depth; V7 clears the 1.00
residue.

### Test suite (this repo)

94 t/*.t, all with `# TESTDOC:` markers (generator-enforced). Board-gated:
RPI_BOARD_1 ×1 (t/335), _2 ×6, _3 ×2, _4 ×16, _5 ×4 — 29 files; plus
t/353-a4988.t **device-gated on `RPI_A4988`** (bench A4988, not tied to any
test-platform board — added 2026-07-10); 64 board-independent (incl. the new
non-gated t/354-a4988_unit.t)
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
| RPi::StepperMotor::A4988 | — (new) | 0.01 UNREL | **NEW leaf 2026-07-10** — pure-Perl A4988 driver, DI transport; never on CPAN; installed locally; main mirror tests t/353/t/354 added; release tracked by V36. **HW owned: user bought a NEMA17 kit (1.0 A/phase, 33 N·cm)** |
| others (ADC::ADS 1.04, MCP3008/BMP180/DAC/DigiPot/HCSR04/LCD/OLED/SPI/StepperMotor 3.1802, DHT11 1.06, GPIOExpander 1.04, RTC 0.04, Serial 3.03, SysInfo 1.03) | one behind | UNREL | all need releases |

Guards: 16 dists have NO Makefile.PL guard; dht11 + oled presence-only;
gpioexpander i2c-only; wiringpi-api full (3.18). Full detail in
`wiringpi-version-single-source.md`. Raw inventory TSV preserved in this
session's scratchpad; regenerate anytime via the V25 audit script.

## Design (decisions)

- **Board completion order: 4 → 5 → 1.** **Status (2026-07-09): boards 4 and 5
  are complete, blessed, and ordered — only board 1 (the hub) remains** (V8/V10
  outcomes achieved on disk; see Validation Table for their task-closure state).
  Board 4 unblocked 16 gated tests +
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

## V2 verdict — test-platform-regen §9 checklist reconciliation (2026-07-09)

Source file deleted in V1; §9 read from git `ecd6971^`. All 10 migration-checklist
items are implemented in-tree; residues noted below.

| # | Item | Verdict | Evidence |
|---|------|---------|----------|
| 1 | Canonical board-model.py; drop gen-schematic.py duplicate; repoint imports | ✅ done | board-model.py canonical; gen-kicad.py:58-61 & gen-schematic.py:22-29 load it by path ("single source of truth"); no inline model dict remains (J1FUNC/DRIVER/POWER/SHEETS come from the model) |
| 2 | Extract `[F]` facts to `facts/board-facts.*` | ✅ done (path variant) | facts live in scripts/helpers/board-facts.py (sibling module, not a facts/ dir); board-model.py:30-31 loads it; shared with model-from-tests.py |
| 3 | Correct model drift: 16-pin loop, 0x21 stepper+magnet, drop photo-sensor | ✅ done | board-model.py carries 0x21/stepper/magnet (8 refs), zero photo-sensor remnants tree-wide; the item's "t/330" is a pre-renumber name — the 16-pin MCP23017 test is now t/355/t/356 (stale-name sweep already owned by V3/F12) |
| 4 | render-doc.py + test-pinout-doc.tmpl.md | ✅ done | both present (scripts/helpers/render-doc.py, docs/test-platform/test-pinout-doc.tmpl.md) |
| 5 | Relocate KiCad to docs/test-platform/kicad/ | ✅ done | boards live there; gen-kicad.py takes an output-project-dir + writes a project-local fp-lib-table (`${KIPRJMOD}`); check-kicad.py points there |
| 6 | Trim schematic renderer (drop schemdraw); SVGs→scratch→gen-pdf.py, don't commit; links→PDF | ✅ done (1 deliberate deviation) | schemdraw net-label path removed (gen-schematic.py:118 records it); gen-pdf.py present; doc links point to the A3/A4 PDFs. **Deviation:** the schematic PDFs ARE committed (shipped deliverables, though excluded from the CPAN tarball) — the checklist's "don't commit" was intentionally reversed |
| 7 | Write regen.py folding in the diff gate + check-kicad.py | ✅ done (no standalone regen.py) | orchestration is Makefile.PL `regen_docs` → gen-pod-md.pl + gen-test-platform.pl (drives the Python generators); the drift gate + check-kicad run in the test path (t/04), not inside a regen.py |
| 8 | Generate test-pinout-doc.md; diff vs hand doc; reconcile | ✅ done | generated doc present via tmpl + render-doc.py; the one-time reconciliation is historical |
| 9 | New operational README; delete the old | ✅ done | single docs/test-platform/README ("test platform guide"); no old duplicate |
| 10 | Drift gate in test/CI so stale docs fail | ✅ done | t/04-test-platform-model.t runs check-model-drift.py (fails on drift) + model re-derivation + KiCad validation + board-lock check |

**Residues:** none require a new V/B row. Item 3's stale "t/330" name is already
covered by V3's pre-renumber sweep (F12). Items 2/6/7 are intentional path/
architecture deviations from the design doc (recorded above); no action.

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
| V35 | **PH** (USER hardware; board-4 connected — split out of V7 2026-07-09) — rpi-eeprom-at24c32 on-silicon verification: with the AT24C32 (0x57) live on board-4, verify the 1.00 **ACK-polling write cycle** (t_WR, doc0336 p.9) returns as soon as the chip ACKs (not a fixed sleep) and a write→read round-trip is correct. This is the gated hardware half V7 (HW-free) deliberately left. Can run in the same powered session as V23 (board-4 RTC/EEPROM depth) | on-Pi with board-4 wired: the RPI_EEPROM-gated integration path (main repo t/542/543 and/or a gated dist test) | ACK-poll timing + round-trip verified on real silicon | ⏳ |
| V28 | **PR** — Pre-release verification, SPLIT legs (debate H8: 13 XS dists + main cannot configure/build on mac — wiringPi.h, linux/i2c-dev.h, -lrt; RPiTest.pm:33-36 hard-uses the stack). ON PI: per-board suites `t/scripts/test_board_{1..5}.sh` green; full 94-file suite green (incl. the 2026-07-10 A4988 pair t/353/t/354); `RPI_RELEASE_TESTING=1` author tests (900-915) green; `make disttest` for all 22 dists (21 + the new RPi::StepperMotor::A4988). **NOTE (V27, 2026-07-10):** the PWM files t/425/t/400/t/405 each fail exactly one subtest — `pin 18 set back to default mode (31)` (got 0/input, expected 31/RP1-null) — when run in ISOLATION via single-file `prove`; wiringPi releases a driven PWM pin to input(0), not boot-pristine null(31). Confirm this clears in the ordered full-suite / test_board_2.sh context (shared-meta reset absorbs it); if it does NOT clear in-suite, the pin-18 default expectation in RPiTest.pm needs adjusting for post-PWM pins. ON MAC: `RPI_DIST_RELEASE=1 make dist` + MANIFEST verification per dist (+ optional rpi-const disttest). BOTH: clean worktrees (incl. wiringpi-api's stray PDF — F10); rig Arduino verified on the V33 canonical sketch | Pi + mac runs + `git status` sweep across ~/repos | All green, all clean on the leg that can run it; train may start | ⏳ |
| V29 | **PR** — Release wave 1: rpi-const (BuildCheck inside). Prepare final Changes/version/README; user uploads; verify CPAN indexes + testers start PASS/NA (never FAIL) | metacpan check post-upload | RPi::Const live; CONFIGURE_REQUIRES resolvable for the family | ⏳ |
| V30 | **PR** — Release wave 2: WiringPi::API 3.1804. Prep gains the six-site wiringpi.com → github.com/WiringPi/WiringPi sweep + an explicit install-≥3.18 pointer (API.pm:1922, 1926, 2516, 2572, 2652, 2825 — F13); user uploads; verify | metacpan + testers | Live + green; no defunct-domain links shipped | ⏳ |
| V31 | **PR** — Release wave 3: the leaf dists (debate H9: 20 sub-dists − const − api = 18; **+ the new RPi::StepperMotor::A4988 2026-07-10 → 19 leaves**, see V36). Batch prep, one commit set per repo; user uploads in any order after waves 1-2 | family inventory rerun: CPAN == local everywhere | All 19 leaves live; zero UNREL sections left in leaves | ⏳ |
| V32 | **PR** — Release wave 4: RPi::WiringPi 3.1803 (main, last): final regen_docs (also regenerates the FAQ test-table's POD→md derivatives after the 2026-07-10 A4988 rows), MANIFEST check, verify every V26-raised floor **and the new RPi::StepperMotor::A4988 0.01 floor (V36)** is indexed on CPAN before upload, disttest on the Pi, user uploads; then watch CPAN testers across the family for a week; file any FAILs as new V rows | metacpan + testers matrix | Raised floors indexed; main live; family-wide testers PASS/NA only | ⏳ |
| V36 | **PR** — RPi::StepperMotor::A4988: NEW family leaf (2026-07-10). **HW ON HAND — user PHYSICALLY BOUGHT a NEMA17 Stepper Motor Kit (1.0 A/phase, 33 N·cm, 1.8°/200-step) + A4988 driver carrier**, so t/353 is runnable on real silicon (set VREF ≈1.0 A first). **Review + main tests DONE this session:** code reviewed reasonable/datasheet-accurate/DI-transport/HW-free (F15); dist suite 74 PASS; main mirror tests authored + green — t/354-a4988_unit.t (non-gated HW-free, 52/52) + t/353-a4988.t (gated `RPI_A4988`, live GPIO readback, 22/22, RP1 output-latch confirmed); installed locally; MANIFEST + FAQ table updated. **Release-prep PENDING (rides V31/wave-3):** replace the Dist::Mgr-boilerplate 0.01 Changes with a real entry, disttest, user uploads; then BEFORE main ships (V32) add `RPi::StepperMotor::A4988 => 0.01` to main Makefile.PL PREREQ_PM + confirm CPAN-indexed. Both main tests guard on the module being installed, so main stays green pre-release. | on-Pi `prove -l t/353-a4988.t t/354-a4988_unit.t`; metacpan post-upload | A4988 0.01 live on CPAN; main prereq added + indexed; mirror tests run for installers | ⏳ |

## V26 audit — family versions & floors (re-derived 2026-07-09)

Re-derived from the CURRENT tree (staleness assumed, per the row). Main `Makefile.PL` PREREQ_PM vs each dist's local module version. **Outcome: no floor edit required this pass** — every floor either resolves at its release wave or is already raised to the fix-carrier; the one open candidate (EEPROM) was checked and the suite does not depend on 1.00.

**Fix-carrier / decision floors:**

| Prereq | main floor | local module | Direction-(b): suite depends on fix? | Verdict |
|--------|-----------|--------------|--------------------------------------|---------|
| RPi::Pin | 3.1802 | 3.1803 UNREL | yes — Pi-5 `pwm()` fix (3.1802) drives t/400/t/405 | ✅ already raised; keep 3.1802 (3.1803 adds nothing yet) |
| RPi::Serial | 3.03 | 3.03 UNREL | yes — raw-tty + framing fixes drive t/610 | ✅ already raised (V14) |
| RPi::RTC::DS3231 | 0.03 | 0.04 UNREL | yes — BCD/temp fixes are in 0.03 | ✅ correct at 0.03 (0.04 no new dep) |
| RPi::EEPROM::AT24C32 | 0.01 | 1.00 UNREL | **no** — main t/540-543 only exercise `_check_addr`/`_check_byte` (present in 0.01); no removed-symbol / ACK-poll assertion | ✅ leave at 0.01 (no raise) |
| RPi::Const | 1.06 | 1.07 UNREL | main uses `:mcp23017_pins` (1.06), not BuildCheck (1.07) | ✅ correct at 1.06 |
| WiringPi::API | 3.1803 | 3.1804 UNREL | floor resolvable; 3.1804 no new main dep | ✅ keep 3.1803 |

**Direction-(a) — all 23 prereqs resolvable at their wave:** every remaining floor (ADS 1.03, MCP3008/BMP180/DAC/DigiPot/HCSR04/I2C/LCD/OLED/SPI/Stepper 3.1801, DHT11 1.05, SysInfo 1.02, Accelerometer/Gyro/Radar 0.01) is ≤ its local module version and ships in wave 3 (leaves) before main (wave 4). No prereq floor points above what its dist will publish.

**Changes coherence:** F9 fixed (9 stale filenames in main's UNREL rewritten). F2 already resolved by the user's rpi-i2c rework (header now `3.1803 UNREL`, no `2.3609` residue). rpi-pin carries an empty `3.1803 UNREL` stub → **flagged as a V31 (wave-3) release-prep item**, deliberately NOT edited here (leaf-repo Changes hygiene belongs with its tarball cut, per the conservative scope).

**Residual for V32:** confirm rpi-pin 3.1802 (or 3.1803) and every wave-raised floor is actually indexed on live CPAN before main uploads — the audit read module/Changes state, not metacpan.

## Discovery Tracking

_None yet._

## Review Findings

New findings from this session's research only (absorbed plans' ledgers live in their files in done/).

- **F1** ✅ VALIDATED w/ correction (V26, 2026-07-09): No longer a live blocker — the original sub-item text is stale. rpi-pin's module is now **3.1803 UNREL** and its Changes shows **3.1802 dated 2026-07-05** (the Pi-5 `pwm()`-dies fix that main's t/400/t/405 depend on). Main's floor `RPi::Pin => 3.1802` is therefore *correctly raised* to the fix-carrier (direction-(b) satisfied) and resolves at wave 3 when rpi-pin ships 3.1803 (3.1803 ≥ 3.1802). No floor edit needed; 3.1803 adds nothing functional yet (empty UNREL stub) so the floor stays 3.1802 not 3.1803. **Residual for V32:** confirm 3.1802 is actually indexed on live CPAN before wave 4 (the Changes date implies it shipped, unverified here). Original: requires 3.1802 but CPAN had 3.1801 and the module file was still 3.1801 → uninstallable.

- **F2** ✅ RESOLVED (V26, 2026-07-09 — pre-fixed by user's rpi-i2c rework): rpi-i2c's Changes top now reads `3.1803 UNREL` and the module is 3.1803; **zero** occurrences of `2.3609` anywhere in the repo. Nothing to edit. Original: Changes top read `2.3609 UNREL` while the module was 3.1801 — stale header from the 3.19→3.1802 rename.

- **F3** (→V9): ✅ RESOLVED (V9, 2026-07-09): board-locks.json is now the single "off-limits" source. Added `check-board-locks.py --names` (machine-readable locked-board list); t/04's `%FROZEN` is DERIVED from it (frozen ⇔ blessed, so a frozen-but-unblessed board is impossible by construction); gen-kicad.py refuses to scaffold any locked board (exit 1). Verified: t/04 6/6, refuse exits non-zero writing nothing, non-locked scaffold still works. Original: Lock divergence — board-5 was in t/04's `%FROZEN` (skipped) but absent from board-locks.json; three uncoordinated "off-limits" definitions existed.

- **F4** ✅ VALIDATED w/ correction (V4, 2026-07-09 read-only verify): the original "not reproducible" claim was too strong. Board-2 **opens/renders/fabs from a fresh clone** — the `.kicad_sch` embeds its `lib_symbols` (symbol defs cached) and the `.kicad_pcb` embeds placed-footprint geometry. The only external reference is the **user's own `RPi:` alias** (`RPi:ADS1115_ADC` symbol + `RPi:ADS1115_Breakout` footprint), which resolves via the user's global KiCad config (no project `sym-lib-table`, no `RPi:` entry in the project `fp-lib-table`) — matters only for re-caching/editing the lib, not for open/render/fab. No `_restore_backup`/`ADS1115.mod`/`kicad/unit_tests/` leftovers remain. **User owns all board-2 symbols/footprints and directed no changes/restores (board2 frozen), so the residual library-cleanliness is intentionally NOT actioned.** Sch-vs-PCB rev lockstep (sch UNSET vs PCB 4) → tracked in B22. Original: Board-2 is not reproducible from the repo — the ADS1115 symbol (ZC261500.kicad_sym) exists only in a gitignored `_restore_backup_*` dir; the PCB references footprint lib alias `RPi:` defined in no repo fp-lib-table; board-2's own .pretty ref/values are stale scaffold.

- **F5** (→V3): t/04-test-platform-model.t and docs/test-platform/README reference `kicad/legacy/`, which does not exist.

- **F6** ✅ RESOLVED (V10, 2026-07-09): board-5's LCD1 footprint value is now `HD44780_20x4`, matching the proposal's 20×4 panel. Board is complete/blessed/ordered; user declared it finished. Original: LCD1 value was `HD44780_20x2` but board-layout-proposal.md:217/:239 specify a 20×4 panel.

- **F7** ✅ RESOLVED (V5, 2026-07-09): the physical 0x48 part is a 12-bit **ADS1015** (HW-confirmed 2026-06-23). Bulk of the docs/code/POD ADS1115→ADS1015 correction shipped that day; V5 cleared the last residual miss — `t/421-adc_gain.t` TESTDOC (renumbered from t/142) + its two generated FAQ table lines (regenerated via gen-pod-md.pl). `t/` and `lib/` are now 100% ADS1015. **Deliberate split preserved (user-directed):** the frozen board-2 KiCad and the board-mirror helpers (board-model.py, model-from-tests.py, datasheet-pinouts.json, gen-pinout-images.py) keep "ADS1115" as the module-as-placed — so the goal is ADS1015 in all true prose, ADS1115 on board-mirror artifacts, NOT one name literally everywhere. Original: naming conflict — proposal/matrix/added-hardware say ADS1015; built board-2/FAQ/symbol said ADS1115; datasheet audit concluded 12-bit ADS1015.

- **F8** ⏸ USER-OWNED (V11 retired 2026-07-09): No t/scripts/test_board_1.sh despite board-1 having a gated test (t/335) and the FAQ referring to per-board runners. Folds into the user's board-1 work (he handles all of board-1). If desired, the runner alone is a non-hardware sliver Claude could author from the test_board_{2..5}.sh pattern — ask.

- **F9** ✅ RESOLVED (V26, 2026-07-09): Rewrote the 9 stale subject-of-work filenames in main's `3.1803 UNREL` section to their renumbered names — t/321→t/532-rtc-bcd, t/320→t/530-rtc, t/140-pwm_{spi,i2c}_adc→t/405, t/109→t/400-pwm_hw_mods, t/141→t/420-adc_samples, t/142→t/421-adc_gain, t/340→t/531 (bmp). **Deliberately left (not stale-in-context):** line-79 "fixed the t/330 reference in check-model-drift.py" (t/330 is the *old* ref that entry describes correcting) and "mirrors that dist's t/55-samples.t" (a foreign RPi::ADC::ADS test, not a main-repo file). t/211/t/212 were never stale (bare-number cites to existing files). Original: early UNREL entries cited pre-renumber filenames that no longer exist — confusing for release notes.

- **F10** ✅ RESOLVED (pre-V28, user cleanup — confirmed 2026-07-09): ~/repos/wiringpi-api worktree is now clean (`git status` empty; zero PDFs tree-wide). The stray untracked PDF ("Markdown Print | print.markdown.janqi.com.pdf") has been removed. Original: worktree contained that stray untracked PDF — hygiene before its release. V28's clean-worktree sweep can treat this leg as already satisfied.

- **F11** ✅ RESOLVED (V33, 2026-07-09): One canonical firmware established. Correction: the rpi-i2c fork WAS shipped (rpi-i2c/MANIFEST:3), not unshipped as originally stated. Protocol trace proved **docs/sketch/arduino.ino is canonical** — it is the only version consistent with all consumers (t/605 + all 9 rpi-i2c examples: big-endian word reads via `($b[0]<<8)|$b[1]`, correct write round-trips). The rpi-i2c fork was a **broken refactor** (`eeprom_save_byte(byte*)` called with a `byte` → stored a pointer via EEPROM.put; dead `data += buf[i]`) that could not pass the write_block round-trip both t/605 and pi_write_block assert. Actions: de-duped this repo to the single flat path `docs/sketch/arduino.ino` (removed the nested dup + MANIFEST:47); fixed its misleading "little"→"big" endian comments (code was always big-endian) and header path; overwrote rpi-i2c's fork with the canonical body (RPi::I2C header) — bodies now byte-identical. Rig-flash verification remains V10/V28. Original: firmware existed in three copies with two behaviors; t/605 and rpi-i2c examples couldn't both be right. (Debate H2.)

- **F12** (→V3, V27): ✅ RESOLVED (V27 portion, 2026-07-10): V27's row/text now uses the renumbered names throughout (t/425 servo, t/400/t/405 for the PWM→ADC windows — no t/109/t/140 residue), and the new RPiTest.pm servo calibration + t/425 rewrite reference only current filenames. **V3 portion still open:** t/543-eeprom_validation.t:10 cites "t/420-422" for what is now t/540-542 — stays with V3's pre-renumber sweep. Original: stale pre-renumber test filenames persist in t/ and in this plan itself; same disease F9 diagnosed in Changes. (Debate H3.)

- **F13** (→V30): wiringpi-api's POD sends users to the defunct wiringpi.com at six sites (API.pm:1922, 1926, 2516, 2572, 2652, 2825) while main's 3.1803 UNREL already migrated its own links to github.com/WiringPi/WiringPi. (Debate H5.)

- **F14** ✅ RESOLVED (V34, 2026-07-09 — user-authorized re-bless run in-session; board-locks.json updated in working tree, **commit pending user**): Board-lock drift — on a clean checkout `check-board-locks.py` reported boards 4 AND 5 as "file CHANGED since bless" (board-4 .kicad_pcb/.pro/.sch; board-5 .kicad_pcb/.pro), so **t/04 test 4 FAILS on HEAD**. Cause: the boards were finalized in commit 0011bce (2026-07-07) but board-locks.json was last re-blessed in ab80ad0 (2026-07-05) — the bless lags the finish by two days. Boards 2 and 3 lock clean. Impact: the "blessed" state this session attributed to boards 4/5 (V8 closure, V10, hardware known-state) is a lock *entry* with stale hashes, not a consistent bless. Fix is user-gated (re-bless).

- **F15** ✅ VALIDATED (V36 review, 2026-07-10): RPi::StepperMotor::A4988 0.01 (new leaf) reviewed — code is reasonable and datasheet-accurate: MS1/MS2/MS3 match A4988 Table 1, current limit `I_trip = VREF / (8 × Rsense)`, ENABLE/SLEEP/RESET treated active-low with correct safe-idle levels at new(), per-microstep timing `60 / (rpm × steps_per_rev × microsteps)`. Follows family conventions (dependency-injected GPIO transport, croak-on-bad-param validation, pure-Perl so HW-free testable — RPi::WiringPi only *recommended*). Dist suite 74 PASS; main mirror tests added + green. **No defects found.** Non-blocking cosmetics, neither actioned: (a) the POD ships a GitHub-Actions CI badge though the family CI policy is Test::BrewBuild on the Pi (see "Explicitly NOT doing" → Cloud CI); (b) examples/ are deliberately `MANIFEST.SKIP`'d so they don't ship (same pattern as main excluding scripts/) — not a bug.

## Backlog

Absorbed from test-coverage-gaps (TCG) — dist-refactor enablers:

B1: (TCG B1) rpi-dac-mcp4922 — extract the SPI 16-bit word assembly into a pure builder returning the word, so mask/shift math is unit-testable.

B2: (TCG B2) rpi-adc-ads — expose pga_fsr + 12-vs-16-bit full-scale + VREF/percent scaling for HW-free tests (the rig chip's 12-bit path is production with zero HW-free verification).

B3: (TCG B4/B11) cross-repo — split HW-free validation/math tests out of RPI_*/PI_TEST skip_all gates; add noboard/env gates to dists that have none (mcp3008, spi, bmp180, lcd, oled, hcsr04); reconcile gate-var names.

B4: ✅ DONE (V7, 2026-07-09) — (TCG B5) rpi-eeprom-at24c32: dead _writeBlock removed; orphaned eeprom_read_current_byte/eeprom_close removed (user chose "delete both"); HW-free tests added (t/10-api_and_validation.t). Uncommitted in ~/repos/rpi-eeprom-at24c32.

B5: (TCG B6) rpi-gpioexpander-mcp23017 — getFd/_establishI2C exit(-1) → croak.

B6: (TCG B7) rpi-adc-mcp3008 — extract fetch's frame-build + 10-bit decode into a pure helper. NOTE (V12, 2026-07-09): the behavior is now covered HW-free via the _spi seam-stub (t/06 + main t/436), so the "add env gate" half is moot (no gate needed); the pure-helper extraction remains an optional refactor only.

B7: (TCG B8) rpi-hcsr04 — extract pure raw→cm/inch conversion (divisor 58 vs 58.27, also DSA B3).

B8: (TCG B9) rpi-dht11 — injectable 5-byte frame for read_env so bit-decode + checksum are testable.

B9: (TCG B10) BMP180 compensation/OSS math — CORRECTION (V18, 2026-07-09): it does NOT live in WiringPi::API (its bmp180Temp/bmp180Pressure are `return analogRead(pin)` passthroughs); the actual Bosch compensation + hardcoded `#define BMP180_OSS 0` live in EXTERNAL wiringPi's devLib bmp180.c (libwiringPiDev). So there is nothing to fix in our code, and no confirmed defect. The clean enhancement (post-release, NOT train-time surgery on the foundational WiringPi::API/wiringPi) is to reimplement the BMP180 read + compensation in RPi::BMP180 itself via RPi::I2C, making it HW-free testable against datasheet worked-examples and OSS-selectable.

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

B22: Keep KiCad schematic title-block revs in lockstep with PCB revs at bless time. Boards 2 and 5 ship with an UNSET schematic rev vs SET PCB rev (board-2 PCB 4; board-5 PCB 1) — **accepted as-is**: V4 and V10 both closed by user directive (boards complete + frozen; no edits to their design files), so these are NOT being stamped. The remaining actionable is the tooling fix: extend scripts/unit_test_board_revisions.pl to flag a SET PCB rev with an UNSET schematic rev (today it only flags when both exist and differ, which is why these went unreported) and apply lockstep at bless for any future board (board-1 is now user-owned — V11 retired — so the user applies it there).

## Explicitly NOT doing

- **V6 (retired 2026-07-03, slot never reused)** — "rpi-rtc-ds3231 driver debt (BCD writes + temp sign-extension)" was a zombie task: every fix was already released 2026-06-22 as 0.02/0.03 (CPAN at 0.03; DS3231.xs:50 setBcdField, :188-190 `(int8_t)msb`). Killed by debate H7; V23 verifies depth on silicon instead.
- **Re-executing already-implemented test-platform-regen items** — the render/check pipeline exists in-tree; V2 verifies rather than rebuilds.
- **Absorbing wiringpi-version-single-source.md** — it stays the active guard workstream (V25 gates on it); duplicating its 8 tasks here would fork the ledger.
- **Wrapping the 69 unwrapped API capabilities before the release train** — roadmap work (B20), not release-gating.
- **Cloud CI (GitHub Actions)** — the project's CI is Test::BrewBuild on the Pi by design; the drift gates run in `make test`.
- **rpi-i2c breaking API fixes inside the main train** (B15) — coordinated contract changes ship separately so the train stays low-risk.
- **V11 board-1 design (retired 2026-07-09, slot never reused)** — user handles ALL board-1 (the hub) work himself: schematic, PCB, gerbers, bless, order. Not release-gating (design §: the rig works hubless — I2C pull-ups live on built board-3, GPIO18 already jumpers to board-2). F8's `t/scripts/test_board_1.sh` runner rides along as part of the user's board-1 ownership (see F8).
- **Committing, blessing locked boards, ordering fab, or uploading to CPAN on Steve's behalf** — per git rules and lock workflow, every commit/bless/order/upload is his.
