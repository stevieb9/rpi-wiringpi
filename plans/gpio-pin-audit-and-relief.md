# Plan: Audit every Pi GPIO pin used across the test suite, bring the pin docs up to date, and produce grounded strategies to free up GPIO pins

> **NEXT ACTION:** ✅ **All plan tasks (V1–V8) complete.** Awaiting user decisions A/B/C on which relief strategies to implement. Implementation is a NEW user-gated phase — each accepted strategy (R1/R2/R3/…) becomes a new V-task; do not implement until the user picks.
> **LAST SESSION:** 2026-07-12 — full run. **V1–V6 ✅** (audit + docs, baseline committed as 584570c). **V7–V8 ✅** (strategy): scope = board re-wiring allowed. Recommend R1 (radar off GPIO26) + R2 (parallel LCD→I2C, frees 4/5/6/22) + R3 (centre LED→expander) = ~+5 header pins, low risk; R4/R5 optional (~+4 more, coverage trades). **All analysis now lives in the repo at `docs/test-platform/pin-relief/`** (moved out of session scratchpad at user request): `README.md` (index), `pin-inventory.md` (V1), `gpio-occupancy.md` (V2/V3), `pin-relief-strategies.md` (V7), `pin-relief-recommendation.md` (V8, the options + decisions A/B/C).
> **ARCHIVE:** See gpio-pin-audit-and-relief-archive.md for completed V1-V8

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
| V9 | **Implement R1 (interim)** — change `t/361-radar.t` default pin **26 → 7** (CE1), add assertions that `radar()` puts the pin in INPUT mode and that `cleanup()` restores its at-rest alt; sync the docs (pinout doc, board matrix, pin-relief) off GPIO26. | `perl -c t/361-radar.t`; live bench run with radar OUT rewired to GPIO7 | Syntax OK + skip-clean + docs synced (done); live 361 passes incl. the new mode + restore asserts | ⏳ code + docs done 2026-07-12; live bench run pending (rewire radar OUT→GPIO7). Interim — permanent home is B3 (expander). |

Implementation of the accepted relief strategies is a **new, user-gated phase**: on
the user's decisions (A/B/C in `docs/test-platform/pin-relief/pin-relief-recommendation.md`),
promote each accepted strategy (R1/R3/R4/…) to a fresh V-task here. Per "Explicitly NOT
doing", this plan itself does not implement HW/test changes.

## Discovery Tracking

**Post-V8 refinement (2026-07-12, user):** **R2 REJECTED.** The board-5 parallel LCD stays
on native GPIO — its purpose is to test wiringPi's native parallel `lcd_init` path, which
moving it to any expander/backpack would delete. Verified `RPi::LCD` is a thin wrapper over
wiringPi's C `lcd_init` (`LCD.pm:8,34`); its pins bit-bang in C and can't be driven by the
user's own `RPi::GPIOExpander::MCP23017` without reimplementing HD44780 in Perl (and
`WiringPi::API` exposes no `mcp23017Setup`). So GPIO 4/5/6/17/22/27 are irreducible by
design. Revised relief: **R3** (centre LED GPIO19 → 0x21 expander via the user's own lib,
~+1 pin) + **R1** (radar off GPIO26, hygiene); R5 moot. The `pin-relief/` docs are updated;
resolves flag F-d. Net honest gain is ~1 fabbed-board pin — the platform is near-full by
design.

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

B3: **Radar permanent home — read through an MCP23017 expander input (frees GPIO7).** The GPIO7 placement (V9/R1) is interim. When the user permanently attaches the radar, rework `RPi::Radar::RCWL0516` to accept an `expander =>` (like the steppers) and read its OUT via an I2C expander input pin, so the bench radar costs zero header GPIO. User will drive this when they wire it to its permanent spot ("finalize the mess permanently").

## Explicitly NOT doing

- Editing/regenerating the KiCad board projects (boards 2–5 are frozen & hand-managed per [[board2-frozen-no-automation]] / [[board5-frozen-no-automation]]) — this plan touches docs + strategy only, no board automation.
- Implementing any HW re-wiring or test-code pin changes — V7/V8 recommend; the user decides and executes.
</content>
</invoke>
