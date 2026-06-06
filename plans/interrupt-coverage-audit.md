# Plan: Audit fixes + comprehensive interrupt test coverage for RPi::WiringPi

> **NEXT ACTION:** 🎉 ALL V TASKS COMPLETE (V1-V16). No further V work. Remaining open items are backlog only (B1-B4) — none required. Suggested wrap-up if desired: `git add` the new `t/203`-`t/212`, `t/RPiTest.pm`, `Makefile.PL`, `MANIFEST`, `Changes`, and the plan/archive, then commit (user commits manually). Note RPi::Pin 2.3609 was installed locally to satisfy the pin-level background_interrupt test.
> **LAST SESSION:** V14-V16 done (batch of 3) — `t/211` validation PASS 59/59 (19 propagated croaks), `t/212` pin-level background_interrupt PASS (real functional, RPi::Pin 2.3609 installed + prereq bumped), V16 MANIFEST + Changes + full range `t/200-t/212` PASS (13 files / 600 tests). F7 resolved. D2 resolved earlier.
> **ARCHIVE:** See interrupt-coverage-audit-archive.md for completed V tasks (V1-V16)

## Context

The `3.18` branch is mid-way through rebuilding the interrupt subsystem around `WiringPi::API` 3.1801 (callbacks no longer auto-fire; dispatch is driven from the `$pi` object). The interrupt dispatch/control methods in `lib/RPi/WiringPi.pm` are brand-new thin proxies, and **only `wait_interrupts` + `$pin->set_interrupt` have any test coverage** — every other interrupt method (`dispatch_interrupts`, `run_interrupt_loop`/`stop_interrupt_loop`, `auto_dispatch_interrupts`, `stop_interrupts`, `last_interrupt`, `interrupt_buffer`, `background_interrupts`) is untested, including all parameter-validation/edge-case paths.

A read-only audit also surfaced confirmed bugs in `RPi::WiringPi::Core::_pin_registration()` and a handful of POD / doc / versioning discrepancies. This machine is a real Raspberry Pi (`rpi-2712` kernel), so hardware tests run for real using the existing GPIO‑18 pull self-trigger technique.

Goals: (1) fix the confirmed bugs and doc discrepancies, (2) bump the distro version to match the 3.18 API upgrade, and (3) bring the interrupt subsystem to as close to 100% test coverage as the hardware and dependencies allow — happy paths plus edge/param-validation cases.

**Decisions (from the user):** fix bugs *and* write tests; keep proxies as pure pass-throughs and test the *propagated* `WiringPi::API` croaks (no redundant validation layer); skip the unreachable pin-level `$pin->background_interrupt` test with a documented dependency gap and add a `$pi->interrupt_dropped` proxy; bump VERSION to a 3.18xx scheme.

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of interrupt-coverage-audit-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
  3. **Delete the V# row from this file's Validation Table.**
- V task ❌: update Actual with `❌ YYYY-MM-DD attempt N: reason`. Rerun same V# with attempt N+1. Do NOT create a new V#.
- **Sync review findings** — when a V task (or a Fix) resolves a review finding, mark its `F#` entry in `## Review Findings` **in place**: prefix `✅ RESOLVED (V#)` (or `✅ VALIDATED (V#)` if no code change was needed, or `⏸ DEFERRED → B#` if punted to backlog). Findings are a permanent audit ledger — mark in place; never archive, delete, or renumber them.
- Update ARCHIVE pointer to reflect what's archived (e.g., `V1-V2` → `V1-V3`)
- Update NEXT ACTION to next ⏳ row; update LAST SESSION
- Never renumber within a series. New items get next free number.
- **Discovery triage during V# work** — when you find something while working a V task, classify before continuing:
  - Blocks the current V task → add `Fix N: problem discovered during V# — [what + fix]` to `## Discovery Tracking`; resolve as part of this V task's work.
  - Real bug but doesn't block this V task → add a new V# row (next free) to the Validation Table with ⏳; do not detour to fix it now.
  - Non-blocking improvement → add new B# to `## Backlog` (one `B#` per line, each separated by a blank line).
  - Decided not to do → add to `## Explicitly NOT doing` with a one-line justification.
- Move resolved fixes to archive's "Archived Fixes" section; keep only unresolved in main Discovery Tracking
- To promote a backlog item to an active task: assign it the next free V# and move to the Validation Table. The B# slot is retired and never reused.

## Key references

- `lib/RPi/WiringPi.pm` — interrupt proxies (lines 111-364) + POD (lines 1010-1092)
- `lib/RPi/WiringPi/Core.pm` — `_pin_registration()` (lines 253-316), the bug site
- `lib/INTERRUPTS.md`, `lib/RPi/WiringPi/FAQ.pod` — interrupt docs to reconcile
- `t/RPiTest.pm` — harness: `rpi_running_test`, `rpi_check_pin_status`, `rpi_default_pin_config`
- `t/202-interrupt_both_and_pud.t` — canonical EDGE_BOTH self-trigger + 0.02s settle pattern to copy
- `t/200-`/`t/201-` — RISING / FALLING self-trigger patterns
- `MANIFEST` — every new `t/*.t` must be listed (enforced by `t/515-manifest.t`)
- Authoritative croak strings + background-handle API (`arm`/`disarm`/`read`/`fh`/`stop`/`running`/`pid`): `~/perl5/perlbrew/perls/5.42.0/lib/site_perl/5.42.0/aarch64-linux/WiringPi/API.pm`

**Self-trigger primitive (GPIO 18, no wiring):** arm with `$pin->set_interrupt($edge,\&handler)`, then RISING = `pull(PUD_DOWN); pull(PUD_UP); pull(PUD_DOWN)`; FALLING = inverse; BOTH = same with `select(undef,undef,undef,0.02)` settle between each `pull()` (one up+down = 2 events). Handler bumps a `BEGIN`-scoped `$c` mirrored into `$ENV{PI_INTERRUPT}`. Every file: `use lib 't/'; use RPiTest; rpi_running_test(__FILE__);`, build Pi with `shm_key=>'rpit', shared=>0, label=>'t/2NN-...'`, wrap hardware in `if (! $ENV{NO_BOARD})`, end with `$pi->cleanup; rpi_check_pin_status(); done_testing();`.

## Validation Table

| ID | What | Command | Expected | Actual |
|----|------|---------|----------|--------|
| — | _All V tasks complete (V1-V16). See archive._ | — | — | ✅ |

## Discovery Tracking

- **D2** (during V13) — ✅ RESOLVED 2026-06-05: The plural `background_interrupts()` handle (`WiringPi::API::BackgroundInterrupts`) has **no results channel** — its `_new` calls `SUPER::_new($pid)` without a `results_fh`, so the inherited `->read`/`->fh` always return undef (confirmed by probe). Only the **singular** `background_interrupt(..., {results=>1})` wires a results pipe. **Resolution (user: "do it your way"):** V13 verifies real edge-flow + `arm`/`disarm` gating via **temp-file IPC** (child callback appends a byte per processed edge to `/dev/shm/...`; parent tallies) instead of the nonexistent `->read`/`->fh`. The directly-observable contract (`running`/`pid`/`arm(99)`+`disarm(99)` croak/`stop` reaps) is also asserted. The underlying upstream gap (dead inherited `read`/`fh` on the plural handle) is logged as **B4** for a possible future `WiringPi::API` fix.
- **D1** (during V2) — ✅ RESOLVED 2026-06-05: `t/RPiTest.pm` `rpi_check_pin_status()` reported 51 failures on this Pi 5 / `rpi-2712` board — its single hardcoded `rpi_default_pin_config()` alt-mode table predated the RP1 GPIO peripheral, so `get_alt()` returned values (incl. `31` = RP1 null funcsel) that didn't match. **Fix (no checks relaxed, per user):** split the config into three board-specific tables — `pi3`, `pi4` (both legacy BCM 0-7 alt encoding, identical), and `pi5` (RP1 funcsel, captured live from the board) — selected at runtime by new exported `rpi_board_tag()`: `pi_rp1_model()` truthy → `pi5`; else `pi_board_id()->{model}` ∈ {17,19,20} → `pi4`; else `pi3`. Verified: `t/202` PASS 43/43 incl. all 20 checked pins. V6-V16 teardown checks now valid.

## Review Findings

Audit ledger from the read-only investigation. Mark in place as tasks close.

- **F1** ✅ RESOLVED (V1): `Core.pm:275` — `if (! $meta->{pins}{$pin_num}{users}{$param{requester}} eq $self->uuid)` parses as `(! VALUE) eq $uuid`; Perl warns "Possible precedence problem between ! and string eq". The ownership guard in `unregister` is effectively dead (never returns early), so ownership is not enforced. Intended: `ne $self->uuid`.
- **F2** ✅ RESOLVED (V2): `Core.pm:299` & `:310` — `$self->{meta}{pins}` used where the sub fetched a fresh local `$meta`; everywhere else uses `$meta->{pins}`. The duplicate-pin `exists` check (299) never fires, and the returned registered-pins list (310) is computed from the wrong (effectively empty) structure. Line 307 also lacks a trailing semicolon (cosmetic — block-final, compiles OK; agent's "syntax error" claim was overstated).
- **F3** ✅ RESOLVED (V3): `INTERRUPTS.md` (line 164) tells users to call `WiringPi::API::interrupt_dropped()` directly; there is no `$pi->interrupt_dropped` proxy though every other interrupt control method is wrapped. Inconsistent surface.
- **F4** ✅ RESOLVED (V4): Pin-level `$pin->background_interrupt(...)` is documented at length in `INTERRUPTS.md` and `FAQ.pod`, but `RPi::Pin` 2.3608 implements only `set_interrupt`/`interrupt_set` — the method does not exist (and `->can` false-positives via inheritance to `WiringPi::API`). Docs are ahead of the dependency.
- **F5** ✅ RESOLVED (V4): `run_interrupt_loop` POD mentions the default `$timeout_ms` 1000 only in passing prose, not the params block; `pin()` POD omits its optional `$comment` arg.
- **F6** ✅ RESOLVED (V5): Version `2.3634` (and `Changes` header) predate the 3.18 API upgrade (`WiringPi::API` prereq bumped to 3.1801, branch `3.18`). Version scheme mismatch.
- **F7** ✅ RESOLVED (V6-V16): Interrupt test coverage gap — only `wait_interrupts` + `$pin->set_interrupt` were exercised (t/200-202); all other dispatch/control methods and every param-validation path were untested. Now covered by t/203-t/212 (dispatch/last/stop/loop/auto-dispatch/buffer/background/validation/pin-level background) — full range PASS, 600 tests.

## Backlog

B1: `Util.pm:17` `checksum()` returns `md5_hex(rand())` — weak/low-entropy UUID source (no PID/time/hi-res seed). `new()`'s collision loop masks it, but consider seeding with `Time::HiRes` + `$$` for robustness.

B2: `_pin_registration()` (`Core.pm:253-316`) re-`meta_lock`/`meta_fetch`es within an already-locked critical section; could fetch once at entry. Minor.

B3: `WiringPi.pm:20` `$signal_debug` is hardcoded `0` and never set true — dead toggle; either wire it to an env var or remove.

B4: `WiringPi::API::BackgroundInterrupts` (plural `background_interrupts` handle) inherits `read`/`fh` from the base `BackgroundInterrupt` class, but its `_new` calls `SUPER::_new($pid)` without a `results_fh`, so both methods are permanently `undef` — the API advertises a results channel the plural handle can never deliver. Only the singular `background_interrupt(..., {results=>1})` wires one. Consider either wiring a real per-spec results channel into the plural child (`_bg_shared_loop`) or overriding/removing the dead `read`/`fh` on the plural class so the surface doesn't lie. (Surfaced as D2 during V13; V13 verifies edge-flow + arm/disarm gating via temp-file IPC instead. Upstream change lives in the installed `WiringPi::API`, out of this repo.)

## Explicitly NOT doing

- Adding an explicit validation layer to the interrupt proxies — user chose to keep them as pure pass-throughs and test the propagated `WiringPi::API` croaks instead.
- Implementing pin-level `$pin->background_interrupt` — it belongs in the external `RPi::Pin` distribution, not here. (Update 2026-06-05: `RPi::Pin` 2.3609 now implements it; per user decision V15 becomes a real functional test against that version rather than a skip. We still don't implement the method in this distro.)
- Forcing `interrupt_dropped` buffer-overflow drops in a test — timing-dependent and flaky on real hardware; V12 asserts the no-drop happy path only.
- Fixing `RPi::Pin::interrupt_set`'s double-pin bug — that defect lives in the external `RPi::Pin` module, out of this repo's scope.
