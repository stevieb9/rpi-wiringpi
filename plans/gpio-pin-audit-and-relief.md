# Plan: Audit every Pi GPIO pin used across the test suite, bring the pin docs up to date, and produce grounded strategies to free up GPIO pins

> **NEXT ACTION:** ⛔ **COMMIT GATE** — Phase 1 (V1–V6) done. Waiting for the USER to review + commit the factual-baseline docs. Do NOT start V7 (strategy) until that baseline is committed. (Proposed commit message is in the plan handoff / this session's final message.)
> **LAST SESSION:** 2026-07-12 — autonomous run (user away, authorized V1–V6 then stop at commit gate). **V1–V6 ✅ — Phase 1 COMPLETE.** All doc-truth work done: pinout doc template rewritten + regenerated, board matrix updated, remaining docs verified consistent (no drift). Stopped at the commit gate as instructed. Baseline doc changes for the user to commit: `docs/test-platform/test-pinout-doc.tmpl.md`, `docs/test-platform/test-pinout-doc.md`, `docs/test-platform/test-board-matrix.md` (the `t/448` XS fix was already committed separately by the user as bd40b8f). Plan files (`plans/gpio-pin-audit-and-relief.md` + `-archive.md`) also changed — commit with the baseline or separately, user's choice. Scratchpad analyses at `/tmp/claude-1000/-home-steve-repos-rpi-wiringpi/8cc6203d-c22a-427c-9a7a-ecbcd3880fab/scratchpad/`.
> **ARCHIVE:** See gpio-pin-audit-and-relief-archive.md for completed V1-V6

## Purpose & governing rule

Two deliverables: (1) an **authoritative, test-grounded assessment** of every Pi GPIO pin used across the whole suite, with the pin docs corrected to match; (2) **evaluated strategies to free up GPIO pins** — pin sharing/multiplexing where the tests allow it, or any other grounded means.

## Phase structure & factual-baseline gate

The plan runs in two phases, in strict order (user preference 2026-07-12):

- **Phase 1 — Make the docs factual (V1–V6).** Purely descriptive: capture what the suite *currently* does and correct the docs to match. V1–V3 gather and reconcile the facts (scratchpad only, no repo edits); V4–V6 write those facts into the tracked docs. Nothing here changes test behaviour or hardware — only documentation catching up to reality.
- **GATE (after V6): commit the factual baseline.** Once V6 is done, the pin docs represent the current layout exactly. **Propose a commit message and let the user review + commit** (per git rules, never commit on their behalf) so there is a saved, committed factual layout before anything else. Do NOT start V7 until the user has that baseline committed.
- **Phase 2 — Strategy (V7–V8).** Only *after* the baseline is committed: evaluate pin-freeing strategies and produce a recommendation (scratchpad + summary). Still no HW/test changes — those remain the user's separate decision after V8.

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
| V7 | **(GATED — do not start until the user has committed the V1–V6 factual baseline.)** **Enumerate & evaluate pin-freeing strategies (the core deliverable).** For each candidate, give: pins freed, mechanism, cost/effort, test-code impact, and feasibility — all grounded in what the suite/submodules prove (cite), never guessed. Candidate seeds to evaluate (add/reject with reasons): (a) **MCP23017 I2C-expander offload** — already proven in-tree (28BYJ-48 @0x21, A4988 @0x22 use 0 Pi GPIO); which other fixtures (74HC595 16/20/21, parallel-LCD lines) could move onto an expander for 2-pin I2C cost? (b) **Retire the parallel HD44780 (`t/620`, pins 4/5/6/17/22, +17/27 shared) in favour of the I2C LCD (`t/335`, PCF8574 @0x27)** — frees up to 4 dedicated pins; does coverage overlap? (c) **Move radar off GPIO26** (MCP3008 CS net) to a genuinely-free pin. (d) **Consolidate bit-banged SPI CS (12/13/26) onto hardware CE0/CE1 (8/7)** — weigh against the Pi 5 SPI_NO_CS limitation ([[pi5-spi-nocs-limitation]] in memory: RP1 rejects SPI_NO_CS). (e) **Free GPIO0/1** (already unrouted-recommended). (f) any pin already only used as a generic/loopback that a device could reuse serially. | manual → `scratchpad/pin-relief-strategies.md` | ≥5 strategies each with pins-freed + feasibility + citations; a ranked shortlist | ⏳ |
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
