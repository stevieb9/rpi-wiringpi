# Plan: Remove setup_sys() and setup_phys() initialization support

> **NEXT ACTION:** None — all V tasks (V1–V9) and backlog B2 complete. Two separate commits to make: (1) **rpi-wiringpi** V2–V6 code/POD/test/Changes edits; (2) **rpi-pin** B2 RPi::Const adoption (lib/RPi/Pin.pm, Makefile.PL, Changes).
> **LAST SESSION (2026-06-06):** Implemented **B2** in `~/repos/rpi-pin`: `Pin.pm` now `use RPi::Const qw(:all)`; `mode()`/`pwm()` validate against INPUT/OUTPUT/PWM_OUT/GPIO_CLOCK, `pull()` against PUD_OFF/PUD_DOWN/PUD_UP (also fixed pull()'s backwards inline comment). Added `RPi::Const 1.04` prereq (1.05 is UNREL, so pinned to released 1.04). Behavior-preserving — constants resolve to the same 0/1/2/3 + 0/1/2; `perl -c` OK; affected tests SKIP in this env (need RPI_SUBMODULE_TESTING). B2 retired.
> **ARCHIVE:** See refactor-setup-modes-archive.md for completed V tasks (V1–V9 archived) and B2.

## Goal

Remove everything related to the `setup_sys()` (System GPIO, `RPI_MODE_GPIO_SYS`) and
`setup_phys()` (physical board numbering, `RPI_MODE_PHYS`) initialization schemes. After
this work the module supports only the `wiringPi` (`setup => 'wpi'`), `GPIO`
(`setup => 'gpio'`, the default), and uninitialized (`setup => 'none'`) schemes.

This also removes `export_pin()` / `unexport_pin()`, which exist solely to support the
`setup_sys()` scheme.

## Scope (files touched)

- `lib/RPi/WiringPi.pm` — `new()` dispatch (`/^p/` branch) + POD (`export_pin`, `unexport_pin`)
- `lib/RPi/WiringPi/Core.pm` — `pin_to_gpio()` PHYS branch, `export_pin()`/`unexport_pin()` subs + POD (`pin_scheme`, `pin_to_gpio`, `export_pin`, `unexport_pin`)
- `lib/RPi/WiringPi/Util.pm` — `pin_map()` PHYS branch
- `t/106-pin_map.t` — PHYS/sys `pin_scheme()` assertions
- `Changes` — new entry under the `2.3634 UNREL` section

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of refactor-setup-modes-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
  3. **Delete the V# row from this file's Validation Table.**
- V task ❌: update Actual with `❌ YYYY-MM-DD attempt N: reason`. Rerun same V# with attempt N+1. Do NOT create a new V#.
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

Line numbers below are anchors as of planning time; re-locate by sub/POD name since edits shift later lines.

| ID | What | Command | Expected | Actual |
|----|------|---------|----------|--------|

## Discovery Tracking

- **V8 decision (2026-06-06) — KEEP `RPI_MODE_PHYS` / `RPI_MODE_GPIO_SYS` in `RPi::Const`.** Located in `~/repos/rpi-const`: defined in `lib/RPi/Const.pm:153-154`, exported via the `:mode` tag and `:all`, documented in POD (`:269-270`), and asserted in `t/27-const_mode.t` + `t/30-const_all.t`. This repo (rpi-wiringpi) is clean — no references remain. A `~/repos` sweep found no other local consumer; only `RPi::Const`'s own files match. Decision: do **not** remove or deprecate — they're part of `RPi::Const`'s published public API (separate CPAN distro; external consumers may import them), and the values map to real historical wiringPi scheme numbers (2 = SYS, 3 = PHYS), so they stay meaningful as reference. No edits made to `RPi::Const`.

- **V9 decision (2026-06-06) — `RPi::Pin` has NO dependency on the removed modes; nothing to clean up.** Reviewed `~/repos/rpi-pin/lib/RPi/Pin.pm`. Sweep for `setup_sys`/`setup_phys`/`RPI_MODE_PHYS`/`RPI_MODE_GPIO_SYS`/`export`/`unexport`/`PHYS`/`SYS` over `lib/` → no matches. `Pin.pm` does not `use RPi::Const` in code (only in the POD SYNOPSIS, `:171`); it uses BCM/GPIO numbering only (`:200`). `mode()` (`:40-52`) validates against magic ints `0/1/2/3` = INPUT/OUTPUT/PWM_OUT/GPIO_CLOCK — these are *pin modes*, not the removed *setup schemes*, so they are unaffected. No sys-mode export/unexport handling exists. Decision: no changes needed in `RPi::Pin` for this cleanup. The magic-int → named-constant modernization (`:47` hard-codes `0/1/2/3`) is real but remains backlog item **B2**, out of scope here. No edits made to `RPi::Pin`.

## Backlog

_(B1 retired — promoted to V8.)_

_(B2 retired — implemented 2026-06-06; see archive.)_

## Explicitly NOT doing

- Removing `phys_to_gpio()` / `phys_to_wpi()` (methods or POD) — they are still used by `pin_map()` (Util.pm lines 39, 42) to build the WPI/GPIO maps from physical-pin iteration. Removing them breaks `pin_map()`.
- Editing historical `Changes` entries that mention `setup_sys()` (older release sections) — they are release history and stay as written.
- Touching `script/` and `build_testing/` — explicitly out of scope per instruction (note: `build_testing/build/defacto_interrupt.pl` uses `setup => 'phys'` / `'sys'` but is intentionally left alone).
- Removing the `setup` / `_setup` constructor machinery or the wpi / gpio / none handling — only the phys branch is removed.
