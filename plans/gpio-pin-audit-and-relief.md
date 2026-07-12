# Plan: Audit every Pi GPIO pin used across the test suite, bring the pin docs up to date, and produce grounded strategies to free up GPIO pins

> **NEXT ACTION:** V1 — build the complete, test-grounded per-test pin/device inventory (all 112 `t/*.t` + `t/multi` + `RPiTest.pm`), covering the devices the current docs omit.
> **LAST SESSION:** 2026-07-12 — plan authored. Read the suite + `docs/test-platform/test-pinout-doc.md` + `test-board-matrix.md`; confirmed the pinout doc is stale (predates the gyro/adxl335/radar/tft/a4988/pca9685/lcd_i2c wave) and its "free pins"/CE0-CE1 claims are now wrong. Seeded known findings below. No code/doc changes made.
> **ARCHIVE:** See gpio-pin-audit-and-relief-archive.md for completed V tasks

## Purpose & governing rule

Two deliverables: (1) an **authoritative, test-grounded assessment** of every Pi GPIO pin used across the whole suite, with the pin docs corrected to match; (2) **evaluated strategies to free up GPIO pins** — pin sharing/multiplexing where the tests allow it, or any other grounded means.

**DO NOT GUESS (user's explicit constraint).** Every pin/bus/address fact MUST be tagged with the existing doc methodology and a `file:line` citation:
- **[T]** proven by a test (cite `file:line`)
- **[L]** inferred from library/submodule source the test relies on (cite source)
- **[F]** gap-filled from non-test docs/hardware knowledge — **flagged as such**, never presented as test-derived.
Unknowns are **flagged as unknown**, never invented. The test suite is the source of truth (this is the method the existing `test-pinout-doc.md` already declares).

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of gpio-pin-audit-and-relief-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
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
| V1 | **Complete per-test pin/device inventory.** Read every `t/*.t` (112 files), `t/multi/*.pl`, `t/RPiTest.pm` (`rpi_default_pin_config`, `rpi_check_pin_status`, `@gpio_pins`), `t/crontab`, and each device submodule under `~/repos` needed to decode constructor args → concrete pins/bus/address. Produce a master **test → {devices, Pi BCM pins, bus, I2C addr, expander pins, env gate}** table, each fact tagged [T]/[L]/[F] with `file:line`. MUST cover the devices the current doc §3 omits: A4988 (`t/353/354`, MCP23017 **@0x22**, expander pins 0–7, **no Pi GPIO** — verify), MPU6050 gyro (`t/357/358`, I2C **0x68**), ADXL335 (`t/359/360`, via an ADC — **verify which model/addr/channels & which board, do not assume**), RCWL-0516 radar (`t/361/362`, default OUT = **GPIO26**), PCA9685 (`t/440`, I2C **0x40**), I2C LCD/PCF8574 (`t/335`, **0x27**), TFT ST7735S (`t/447/448`, hardware **CE0/GPIO8** CS + DC=25 RES=24 BLK=23, HW SPI). Write to `scratchpad/pin-inventory.md`. | manual audit → `scratchpad/pin-inventory.md` | Every hardware-touching test has a decoded, cited pin/bus/addr row; zero "assumed" facts; omissions flagged | ⏳ |
| V2 | **Master GPIO occupancy table (BCM 0–27)** built from V1. For each of the 28 header BCM pins: all roles/nets it carries, which test(s), direction, and a classification — `FREE` / `SINGLE-USE` / `SHARED (serial-safe)` / `CONFLICT (same physical net, incompatible roles)`. Reconcile against `RPiTest.pm` `@gpio_pins` + the Pi5/Pi3-4 default-state tables. | manual synthesis → `scratchpad/gpio-occupancy.md` | 28-row table; every role cited to a V1 fact; free-pin count stated with evidence | ⏳ |
| V3 | **Conflict & shared-net reconciliation.** From V2, list every collision and classify grounded (not guessed): real single-net conflict vs different-board vs serial-suite-safe timeshare. Known seeds: radar GPIO26 vs MCP3008 CS; TFT GPIO23/24/25 + CE0(8) vs doc's "spare/free"; gyro 0x68 vs DS3231 RTC 0x68 (address clash — same/diff board?); LCD 17/27 vs stepper limits; adxl335 ADC channels vs ADS1015 A0/A1 usage. State for each: is it a defect, a doc error, or an accepted timeshare? | manual → append to `scratchpad/gpio-occupancy.md` | Each conflict resolved to defect / doc-error / accepted-timeshare with citation | ⏳ |
| V4 | **Update the pinout doc.** Edit `docs/test-platform/test-pinout-doc.tmpl.md` (the template — the `.md` is generated from it) to fold in all V1 devices/tests and correct the now-wrong claims: §5 "hardware CE0/CE1 stay free" (TFT uses CE0), §9 "GPIO23/24/25 fully spare" (TFT), §3 device table (add a4988/gyro/adxl335/radar/tft/pca9685/lcd_i2c), §4 I2C address table (add 0x22, 0x27, 0x40; note 0x68 gyro/RTC), §7/§10 collisions (radar on GPIO26). Then regenerate `test-pinout-doc.md` via `scripts/gen-test-platform.pl` (or `render-doc.py` if netlistsvg absent — note which). | edit tmpl + `perl scripts/gen-test-platform.pl` | Generated `test-pinout-doc.md` includes every device; no stale "free"/"CE0 free" claim; regen ran clean (or skip-reason noted) | ⏳ |
| V5 | **Update the board matrix.** Edit `docs/test-platform/test-board-matrix.md`: place the new devices/tests on their boards (verify board assignment from KiCad projects / env gates — do not guess), update per-board test counts and the "26 hardware tests" headline. | edit `test-board-matrix.md` | Matrix lists a4988/gyro/adxl335/radar/tft/pca9685/lcd_i2c on cited boards; totals recomputed | ⏳ |
| V6 | **Sync remaining pin-bearing docs** to the corrected pinout: `README.md`, `lib/RPi/WiringPi/FAQ.pod`, and `docs/pod/*.md` (FAQ/INTERRUPTS/WORKERS/WiringPi) — only where they state concrete pins/addresses. Fix any drift found; leave a note if a doc is intentionally high-level. | grep pin/addr refs → edit as needed | No doc contradicts the V1 inventory; changes cited | ⏳ |
| V7 | **Enumerate & evaluate pin-freeing strategies (the core deliverable).** For each candidate, give: pins freed, mechanism, cost/effort, test-code impact, and feasibility — all grounded in what the suite/submodules prove (cite), never guessed. Candidate seeds to evaluate (add/reject with reasons): (a) **MCP23017 I2C-expander offload** — already proven in-tree (28BYJ-48 @0x21, A4988 @0x22 use 0 Pi GPIO); which other fixtures (74HC595 16/20/21, parallel-LCD lines) could move onto an expander for 2-pin I2C cost? (b) **Retire the parallel HD44780 (`t/620`, pins 4/5/6/17/22, +17/27 shared) in favour of the I2C LCD (`t/335`, PCF8574 @0x27)** — frees up to 4 dedicated pins; does coverage overlap? (c) **Move radar off GPIO26** (MCP3008 CS net) to a genuinely-free pin. (d) **Consolidate bit-banged SPI CS (12/13/26) onto hardware CE0/CE1 (8/7)** — weigh against the Pi 5 SPI_NO_CS limitation ([[pi5-spi-nocs-limitation]] in memory: RP1 rejects SPI_NO_CS). (e) **Free GPIO0/1** (already unrouted-recommended). (f) any pin already only used as a generic/loopback that a device could reuse serially. | manual → `scratchpad/pin-relief-strategies.md` | ≥5 strategies each with pins-freed + feasibility + citations; a ranked shortlist | ⏳ |
| V8 | **Final recommendation & user decision points.** Synthesize V7 into a short recommendation (biggest wins, lowest risk) and a list of decisions only the user can make (which fixtures to retire/relocate, board re-layout appetite). Present; do not implement HW/test changes. | write `scratchpad/pin-relief-recommendation.md` + summarize to user | Clear ranked recommendation + explicit user decision list | ⏳ |

## Discovery Tracking

_None yet._

## Known findings seeded at plan authoring (2026-07-12, to verify in V1–V3)

These were observed while authoring; each must be re-verified with citations during the audit, not taken as fact:

- **Pinout doc §3 is stale** — it omits `t/335` (lcd_i2c), `t/353/354` (a4988), `t/358` (gyro), `t/360` (adxl335), `t/361` (radar), `t/440` (pca9685), `t/447` (tft). It predates the robot/display device wave.
- **A4988 (`t/353`)** — `step..reset => 0..7` are **MCP23017 @0x22** expander pins, **not Pi GPIO** (`t/353:89–99,128–138`; comment `t/353:1` "through an MCP23017 expander"). 0x22 is a **third** expander the I2C address table (§4) doesn't list.
- **TFT ST7735S (`t/447`)** — the **only** device using hardware **CE0 (GPIO8)** as CS; also DC=GPIO25, RES=GPIO24, BLK=GPIO23 (`t/447:39–47,69–96`). Directly contradicts §5 ("CE0/CE1 stay free") and §9 ("GPIO23/24/25 fully spare").
- **Radar RCWL-0516 (`t/361`)** — default OUT line = **GPIO26** (`t/361:43,65`), the same BCM as the MCP3008 bit-banged CS (§5). Env-overridable via `RPI_RADAR_PIN`.
- **Gyro MPU6050 (`t/358`)** — I2C **0x68** (`t/358:76`), the same address as the DS3231 RTC (§4). Confirm whether they share/avoid a board.
- **ADXL335 (`t/360`)** — analog, read **through an ADC** (default model ADS1115, channels x=0/y=1/z=2; `t/360:39–44,73–99`). Which ADC instance/address/board and whether it collides with the ADS1015 @0x48 A0/A1 usage is **unverified — resolve in V1, do not assume**.
- **Pin pressure** — after this device wave, effectively all 28 header BCM pins are claimed; the "free for generic tests" list in §9 is no longer accurate. This is the motivation for the relief strategies (V7).
- **Proven relief pattern** — the MCP23017 I2C expander lets a fixture consume 0 Pi GPIO (28BYJ-48 @0x21, A4988 @0x22). This is the strongest evidence-backed lever for V7.

## Review Findings

(None yet — populate if a review pass runs during the doc updates.)

## Backlog

B1: Consider adding a machine-checkable test/assertion that fails when a doc pin table drifts from the suite (guard against the staleness this plan is fixing).

B2: `test-pinout-doc.tmpl.md` §12 default-state table is generated from `RPiTest.pm`; confirm the generator still round-trips after V4 edits (it should only own §12).

## Explicitly NOT doing

- Editing/regenerating the KiCad board projects (boards 2–5 are frozen & hand-managed per [[board2-frozen-no-automation]] / [[board5-frozen-no-automation]]) — this plan touches docs + strategy only, no board automation.
- Implementing any HW re-wiring or test-code pin changes — V7/V8 recommend; the user decides and executes.
</content>
</invoke>
