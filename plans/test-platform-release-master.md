# Plan: Test platform completion + family-wide release readiness (MASTER)

> **NEXT ACTION:** V20 — RPi::OLED::SSD1306 HW-free croak/bounds + TCG F16 singleton (in ~/repos/rpi-oled-ssd1306 + mirror) — re-verify vs the current tree first
> **LAST SESSION:** 2026-07-09 — executed …/V13/V14. V14 (RPi::Serial): TCG F14 fixed + surfaced and fixed 3 more real bugs (write() >255 silent-wrap→croak; **tx() was sending 0x00 for the payload**; **rx() returned a defined 0 mid-frame**; **flush() called an undefined tty_flush → added the XSUB**). Dist t/05-unit.t + **live t/10-loopback.t (8/8 PASS on real TX↔RX loopback, /dev/ttyAMA0, gate RPI_SERIAL_LOOPBACK)**; main mirror t/438 = crc vectors only (installed 3.02 predates/breaks the rest). Then (user-directed) rewrote t/610-serial.t into a full live-loopback suite + real-world CRC-framed example, which found + fixed a 6th RPi::Serial bug (tty_open not fully raw — ICRNL mapped 0x0D→0x0A); installed 3.03, bumped main prereq to 3.03. **Rig now has serial loopback wired** (GPIO14↔15) — usable for V28; t/610 26/26 serial tests green (only pre-existing pin-8 contamination fails). **HEADS-UP: sub-dists actively reworked — re-verify each PC row vs the tree first.** **Uncommitted: rpi-wiringpi, rpi-eeprom-at24c32, rpi-i2c, rpi-adc-mcp3008, rpi-spi, rpi-serial — user commits.** F2 looks resolved (rpi-i2c 3.1803 UNREL) → V26. **Rule: present point-form plan before executing any V task**
> **ARCHIVE:** See test-platform-release-master-archive.md for completed V tasks (V1-V5, V7-V10, V12-V19, V33, V34)

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
| V35 | **PH** (USER hardware; board-4 connected — split out of V7 2026-07-09) — rpi-eeprom-at24c32 on-silicon verification: with the AT24C32 (0x57) live on board-4, verify the 1.00 **ACK-polling write cycle** (t_WR, doc0336 p.9) returns as soon as the chip ACKs (not a fixed sleep) and a write→read round-trip is correct. This is the gated hardware half V7 (HW-free) deliberately left. Can run in the same powered session as V23 (board-4 RTC/EEPROM depth) | on-Pi with board-4 wired: the RPI_EEPROM-gated integration path (main repo t/542/543 and/or a gated dist test) | ACK-poll timing + round-trip verified on real silicon | ⏳ |

## Discovery Tracking

_None yet._

## Review Findings

New findings from this session's research only (absorbed plans' ledgers live in their files in done/).

- **F1** (→V26): Release blocker — this repo's Makefile.PL requires `RPi::Pin => 3.1802`, but CPAN has 3.1801 and rpi-pin's module file is still 3.1801 (only its Changes says 3.1802 UNREL). Released today, RPi::WiringPi is uninstallable.

- **F2** (→V26): rpi-i2c's Changes top section reads `2.3609 UNREL` while the module is 3.1801 — stale header from the 3.19→3.1802 rename.

- **F3** (→V9): ✅ RESOLVED (V9, 2026-07-09): board-locks.json is now the single "off-limits" source. Added `check-board-locks.py --names` (machine-readable locked-board list); t/04's `%FROZEN` is DERIVED from it (frozen ⇔ blessed, so a frozen-but-unblessed board is impossible by construction); gen-kicad.py refuses to scaffold any locked board (exit 1). Verified: t/04 6/6, refuse exits non-zero writing nothing, non-locked scaffold still works. Original: Lock divergence — board-5 was in t/04's `%FROZEN` (skipped) but absent from board-locks.json; three uncoordinated "off-limits" definitions existed.

- **F4** ✅ VALIDATED w/ correction (V4, 2026-07-09 read-only verify): the original "not reproducible" claim was too strong. Board-2 **opens/renders/fabs from a fresh clone** — the `.kicad_sch` embeds its `lib_symbols` (symbol defs cached) and the `.kicad_pcb` embeds placed-footprint geometry. The only external reference is the **user's own `RPi:` alias** (`RPi:ADS1115_ADC` symbol + `RPi:ADS1115_Breakout` footprint), which resolves via the user's global KiCad config (no project `sym-lib-table`, no `RPi:` entry in the project `fp-lib-table`) — matters only for re-caching/editing the lib, not for open/render/fab. No `_restore_backup`/`ADS1115.mod`/`kicad/unit_tests/` leftovers remain. **User owns all board-2 symbols/footprints and directed no changes/restores (board2 frozen), so the residual library-cleanliness is intentionally NOT actioned.** Sch-vs-PCB rev lockstep (sch UNSET vs PCB 4) → tracked in B22. Original: Board-2 is not reproducible from the repo — the ADS1115 symbol (ZC261500.kicad_sym) exists only in a gitignored `_restore_backup_*` dir; the PCB references footprint lib alias `RPi:` defined in no repo fp-lib-table; board-2's own .pretty ref/values are stale scaffold.

- **F5** (→V3): t/04-test-platform-model.t and docs/test-platform/README reference `kicad/legacy/`, which does not exist.

- **F6** ✅ RESOLVED (V10, 2026-07-09): board-5's LCD1 footprint value is now `HD44780_20x4`, matching the proposal's 20×4 panel. Board is complete/blessed/ordered; user declared it finished. Original: LCD1 value was `HD44780_20x2` but board-layout-proposal.md:217/:239 specify a 20×4 panel.

- **F7** ✅ RESOLVED (V5, 2026-07-09): the physical 0x48 part is a 12-bit **ADS1015** (HW-confirmed 2026-06-23). Bulk of the docs/code/POD ADS1115→ADS1015 correction shipped that day; V5 cleared the last residual miss — `t/421-adc_gain.t` TESTDOC (renumbered from t/142) + its two generated FAQ table lines (regenerated via gen-pod-md.pl). `t/` and `lib/` are now 100% ADS1015. **Deliberate split preserved (user-directed):** the frozen board-2 KiCad and the board-mirror helpers (board-model.py, model-from-tests.py, datasheet-pinouts.json, gen-pinout-images.py) keep "ADS1115" as the module-as-placed — so the goal is ADS1015 in all true prose, ADS1115 on board-mirror artifacts, NOT one name literally everywhere. Original: naming conflict — proposal/matrix/added-hardware say ADS1015; built board-2/FAQ/symbol said ADS1115; datasheet audit concluded 12-bit ADS1015.

- **F8** ⏸ USER-OWNED (V11 retired 2026-07-09): No t/scripts/test_board_1.sh despite board-1 having a gated test (t/335) and the FAQ referring to per-board runners. Folds into the user's board-1 work (he handles all of board-1). If desired, the runner alone is a non-hardware sliver Claude could author from the test_board_{2..5}.sh pattern — ask.

- **F9** (→V26): Main repo's 3.1803 UNREL section's early entries cite pre-renumber test filenames (t/321-rtc-bcd, t/140-pwm_spi_adc, …) that no longer exist — confusing for release notes.

- **F10** (→V28): ~/repos/wiringpi-api worktree contains a stray untracked PDF ("Markdown Print | print.markdown.janqi.com.pdf") — hygiene before its release.

- **F11** ✅ RESOLVED (V33, 2026-07-09): One canonical firmware established. Correction: the rpi-i2c fork WAS shipped (rpi-i2c/MANIFEST:3), not unshipped as originally stated. Protocol trace proved **docs/sketch/arduino.ino is canonical** — it is the only version consistent with all consumers (t/605 + all 9 rpi-i2c examples: big-endian word reads via `($b[0]<<8)|$b[1]`, correct write round-trips). The rpi-i2c fork was a **broken refactor** (`eeprom_save_byte(byte*)` called with a `byte` → stored a pointer via EEPROM.put; dead `data += buf[i]`) that could not pass the write_block round-trip both t/605 and pi_write_block assert. Actions: de-duped this repo to the single flat path `docs/sketch/arduino.ino` (removed the nested dup + MANIFEST:47); fixed its misleading "little"→"big" endian comments (code was always big-endian) and header path; overwrote rpi-i2c's fork with the canonical body (RPi::I2C header) — bodies now byte-identical. Rig-flash verification remains V10/V28. Original: firmware existed in three copies with two behaviors; t/605 and rpi-i2c examples couldn't both be right. (Debate H2.)

- **F12** (→V3, V27): Stale pre-renumber test filenames persist in t/ and in this plan itself — t/543-eeprom_validation.t:10 cites "t/420-422" for what is now t/540-542; V27's carried-forward text said "t/109/t/140" for t/400/t/405. Same disease F9 diagnosed in Changes. (Debate H3.)

- **F13** (→V30): wiringpi-api's POD sends users to the defunct wiringpi.com at six sites (API.pm:1922, 1926, 2516, 2572, 2652, 2825) while main's 3.1803 UNREL already migrated its own links to github.com/WiringPi/WiringPi. (Debate H5.)

- **F14** ✅ RESOLVED (V34, 2026-07-09 — user-authorized re-bless run in-session; board-locks.json updated in working tree, **commit pending user**): Board-lock drift — on a clean checkout `check-board-locks.py` reported boards 4 AND 5 as "file CHANGED since bless" (board-4 .kicad_pcb/.pro/.sch; board-5 .kicad_pcb/.pro), so **t/04 test 4 FAILS on HEAD**. Cause: the boards were finalized in commit 0011bce (2026-07-07) but board-locks.json was last re-blessed in ab80ad0 (2026-07-05) — the bless lags the finish by two days. Boards 2 and 3 lock clean. Impact: the "blessed" state this session attributed to boards 4/5 (V8 closure, V10, hardware known-state) is a lock *entry* with stale hashes, not a consistent bless. Fix is user-gated (re-bless).

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
