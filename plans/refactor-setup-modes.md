# Plan: Remove setup_sys() and setup_phys() initialization support

> **NEXT ACTION:** V7 — final verification sweep across lib/ and the edited test (grep + podchecker)
> **LAST SESSION (2026-06-06):** Ran **V2–V6 — all PASS** (user-authorized batch, single commit). Removed the `RPI_MODE_PHYS` branch from `pin_to_gpio()`/`pin_map()`, deleted `export_pin()`/`unexport_pin()` subs, stripped all SYS/PHYS/export POD from Core.pm + WiringPi.pm, trimmed t/106-pin_map.t to GPIO/WPI assertions, and added the Changes entry (to the live `3.1800 UNREL` section, not the `2.3634 UNREL` the plan named). FAQ.pod checked each task — no references, no edit needed. lib/ grep sweep clean; podchecker "pod syntax OK" on all three modules. V7–V9 still pending.
> **ARCHIVE:** See refactor-setup-modes-archive.md for completed V tasks (V1–V6 archived)

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
| V7 | Final verification sweep across lib/ and the edited test. | `grep -rn "setup_sys\|setup_phys\|RPI_MODE_PHYS\|RPI_MODE_GPIO_SYS\|export_pin\|unexport_pin" lib/ t/106-pin_map.t; podchecker lib/RPi/WiringPi.pm lib/RPi/WiringPi/Core.pm lib/RPi/WiringPi/Util.pm` | grep prints nothing; podchecker reports "pod syntax OK" for all three modules | ⏳ |
| V8 | **Review `RPi::Const` for the removed setup modes (cross-distribution)** — `RPI_MODE_PHYS` (3) and `RPI_MODE_GPIO_SYS` (2) back the deleted `setup_phys()` / `setup_sys()` modes; they live in the separate `RPi::Const` distro and are pulled in here via `use RPi::Const qw(:all)`. With V1–V7 done they are no longer referenced by RPi::WiringPi. Review them upstream: confirm no use remains here, then decide keep / deprecate / document-as-unused — do **not** remove unilaterally, other consumers may import them. Not checked out locally (`~/repos`) or installed on this perl, so treat as a tracking review and log the decision in Discovery Tracking. | here: `grep -rn "RPI_MODE_PHYS\|RPI_MODE_GPIO_SYS" lib/` (expect none); then in an `RPi::Const` checkout: `grep -n "RPI_MODE_PHYS\|RPI_MODE_GPIO_SYS" lib/RPi/Const.pm` | this repo clean; the two constants located in `RPi::Const` and a keep/deprecate/document decision recorded in Discovery Tracking | ⏳ |
| V9 | **Review `RPi::Pin` for the removed setup modes (cross-distribution)** — `RPi::Pin` is the per-pin object (`$pi->pin(...)`, built at `WiringPi.pm:238`). Check it for any dependency on the removed `setup_phys()` / `setup_sys()` modes: references to `RPI_MODE_PHYS` / `RPI_MODE_GPIO_SYS`, PHYS/SYS pin schemes, or sys-mode `export`/`unexport` pin handling. Confirm none remain (or track the cleanup). Like V8 it's the user's own module and is not checked out (`~/repos`) or installed on this perl, so treat as a tracking review and log the decision in Discovery Tracking. See **B2** for the related constant-adoption recommendation. | (in an `RPi::Pin` checkout) `grep -rn "setup_sys\|setup_phys\|RPI_MODE_PHYS\|RPI_MODE_GPIO_SYS\|export\|unexport" lib/` | `RPi::Pin` reviewed; nothing depends on the removed modes (or cleanup tracked); decision recorded in Discovery Tracking | ⏳ |

## Discovery Tracking

_None yet._

## Backlog

B2: `RPi::Pin` modernization — make `RPi::Pin` `use RPi::Const` and switch its pin-mode values (INPUT / OUTPUT / PWM_OUT / GPIO_CLOCK / SOFT_PWM_OUT / ...) and pull values from magic integers to the named constants. `RPi::WiringPi` already passes these constants into `RPi::Pin->mode()` (e.g. `WiringPi.pm:274`, `:439`), so having `RPi::Pin` use them internally keeps the whole stack consistent. Separate from the removed-setup-modes cleanup; surfaced during the `RPi::Pin` review (V9). Both `RPi::Const` and `RPi::Pin` are the user's own modules.

_(B1 retired — promoted to V8.)_

## Explicitly NOT doing

- Removing `phys_to_gpio()` / `phys_to_wpi()` (methods or POD) — they are still used by `pin_map()` (Util.pm lines 39, 42) to build the WPI/GPIO maps from physical-pin iteration. Removing them breaks `pin_map()`.
- Editing historical `Changes` entries that mention `setup_sys()` (older release sections) — they are release history and stay as written.
- Touching `script/` and `build_testing/` — explicitly out of scope per instruction (note: `build_testing/build/defacto_interrupt.pl` uses `setup => 'phys'` / `'sys'` but is intentionally left alone).
- Removing the `setup` / `_setup` constructor machinery or the wpi / gpio / none handling — only the phys branch is removed.
