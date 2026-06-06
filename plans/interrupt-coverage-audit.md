# Plan: Audit fixes + comprehensive interrupt test coverage for RPi::WiringPi

> **NEXT ACTION:** Start V3 (add `interrupt_dropped` proxy + POD to WiringPi.pm; update INTERRUPTS.md). NOTE: D1 (rpi_check_pin_status mismatch on Pi 5) needs a user decision before hardware tests V6–V16.
> **LAST SESSION:** V2 done — Core.pm register fixes; register-logic assertions pass (t/110 ok 1-7,48,49,90,91). Discovered D1: rpi_check_pin_status() fails 51 default-mode checks on this Pi 5 board (unrelated to V2).
> **ARCHIVE:** See interrupt-coverage-audit-archive.md for completed V tasks (V1-V2)

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
| V3 | Add `interrupt_dropped` proxy to `WiringPi.pm` (`return WiringPi::API::interrupt_dropped();`) in alpha order; add `=head3 interrupt_dropped` POD; update `INTERRUPTS.md` to reference `$pi->interrupt_dropped`. | `prove -lv t/500-pod_coverage.t` (RPI_RELEASE_TESTING=1) | New method documented; POD coverage passes | ⏳ |
| V4 | POD / clarity fixes in `WiringPi.pm`: document `run_interrupt_loop` default `$timeout_ms` (1000) and `$max` in the params block; document `pin()`'s optional `$comment` arg; add a documented dependency note that pin-level `$pin->background_interrupt` needs a future `RPi::Pin` release. Reconcile `INTERRUPTS.md`/`FAQ.pod` wording with actual behavior. | `prove -lv t/510-pod.t t/505-pod_linkcheck.t` (RPI_RELEASE_TESTING=1) | POD valid + links resolve | ⏳ |
| V5 | Bump `$VERSION` in `lib/RPi/WiringPi.pm` from `2.3634` to a 3.18xx value (e.g. `3.1800` — confirm exact at execution); update the `Changes` top section header to match and add entries (capitalized, appended at bottom of current section) for V1-V4 fixes and the new interrupt tests. | `grep VERSION lib/RPi/WiringPi.pm`; `head Changes` | Version + Changes reflect 3.18xx; entries appended in order | ⏳ |
| V6 | `t/203-dispatch_interrupts.t` — non-blocking `dispatch_interrupts()`: returns dispatched count, fires callback without `wait_interrupts`; returns 0 when nothing pending. | `prove -lv t/203-dispatch_interrupts.t` | PASS; counts match | ⏳ |
| V7 | `t/204-last_interrupt.t` — `last_interrupt()` hashref fields `{pin,pin_bcm,edge,status,ts_us}`; `pin_bcm==18`; `edge` tracks armed type (RISING→FALLING); `ts_us` positive + monotonically increasing. | `prove -lv t/204-last_interrupt.t` | PASS | ⏳ |
| V8 | `t/205-stop_interrupts.t` — after `stop_interrupts` further edges don't dispatch (count frozen, `wait_interrupts` returns 0); re-arming resumes dispatch. | `prove -lv t/205-stop_interrupts.t` | PASS | ⏳ |
| V9 | `t/206-run_interrupt_loop_max.t` — pre-fill N rising edges, `run_interrupt_loop(200,N)` returns N and count==N; `(100,1)` returns 1. `alarm` watchdog guards against hang. | `prove -lv t/206-run_interrupt_loop_max.t` | PASS; terminates via `$max` | ⏳ |
| V10 | `t/207-stop_interrupt_loop.t` — callback calls `stop_interrupt_loop` at threshold; loop (no `$max`) returns with count==threshold not the full burst. `alarm` watchdog. | `prove -lv t/207-stop_interrupt_loop.t` | PASS; terminates via callback | ⏳ |
| V11 | `t/208-auto_dispatch_interrupts.t` — `auto_dispatch_interrupts(1,'IO')`, observe counter advance in a **sleep-only** poll loop (no dispatch call) proving async SIGIO delivery; repeat with `'USR1'`. MUST `auto_dispatch_interrupts(0)` after each block before cleanup. | `prove -lv t/208-auto_dispatch_interrupts.t` | PASS; handlers torn down, `rpi_check_pin_status` clean | ⏳ |
| V12 | `t/209-interrupt_buffer.t` — get baseline; set larger, assert get `>=` requested (kernel page-rounds, no exact-equality assert); functional burst counted without drops; restore baseline at end. | `prove -lv t/209-interrupt_buffer.t` | PASS | ⏳ |
| V13 | `t/210-background_interrupts.t` — `background_interrupts([18,EDGE_RISING,\&cb,0])`: `running` true, `pid` positive; parent drives edges, drain child via `->read`/`->fh`; `disarm(18)`/`arm(18)` stop/resume results; `arm(99)`/`disarm(99)` croak; `stop` reaps (`running` false). | `prove -lv t/210-background_interrupts.t` | PASS; no zombie; pins clean | ⏳ |
| V14 | `t/211-interrupt_validation.t` — propagated-croak coverage via `eval{...}; like $@, qr/.../`. **Confirm each regex against `WiringPi/API.pm` croak strings before finalizing** (designed regexes are provisional). Covers: bad edge/callback/debounce on `$pin->set_interrupt`; `interrupt_buffer(0/-5/'x')`; `run_interrupt_loop` 0/non-numeric timeout & max; `auto_dispatch_interrupts(2/'x'/1,'NOPE')`; `background_interrupts` empty/non-arrayref/bad pin/edge/callback/debounce. | `prove -lv t/211-interrupt_validation.t` | PASS; all croaks asserted | ⏳ |
| V15 | `t/212-pin_background_interrupt.t` — `skip_all` because `RPi::Pin` 2.3608 has no real pin-level `background_interrupt` (`->can` false-positives via `@ISA` to `WiringPi::API`). Include explanatory `note` documenting the dependency gap so it auto-activates when RPi::Pin ships the method. | `prove -lv t/212-pin_background_interrupt.t` | Skips cleanly with documented reason | ⏳ |
| V16 | Add `t/203`–`t/212` to `MANIFEST` (alpha/numeric order); run the whole interrupt range + author tests together to confirm no regressions and pins reset between files. | `prove -l t/203-* t/204-* t/205-* t/206-* t/207-* t/208-* t/209-* t/210-* t/211-* t/212-*`; `RPI_RELEASE_TESTING=1 prove -l t/500-* t/515-*` | All PASS; MANIFEST check passes | ⏳ |

## Discovery Tracking

- **D1** (during V2): `t/RPiTest.pm` `rpi_check_pin_status()` reports 51 failures on this Pi 5 / `rpi-2712` board — its hardcoded `rpi_default_pin_config()` alt-mode table predates the RP1 GPIO peripheral, so `get_alt()` returns values (incl. `31`/`invalid mode 31`) that don't match. The *register* logic (what V2 fixes) passes cleanly; this is a teardown-check mismatch only. **Does not block V2, but will surface in every hardware interrupt test (V6–V16) that ends with `rpi_check_pin_status()`.** Needs a decision: update the config table for Pi 5, or relax/skip the alt-mode checks on this board. Awaiting user direction.

## Review Findings

Audit ledger from the read-only investigation. Mark in place as tasks close.

- **F1** ✅ RESOLVED (V1): `Core.pm:275` — `if (! $meta->{pins}{$pin_num}{users}{$param{requester}} eq $self->uuid)` parses as `(! VALUE) eq $uuid`; Perl warns "Possible precedence problem between ! and string eq". The ownership guard in `unregister` is effectively dead (never returns early), so ownership is not enforced. Intended: `ne $self->uuid`.
- **F2** ✅ RESOLVED (V2): `Core.pm:299` & `:310` — `$self->{meta}{pins}` used where the sub fetched a fresh local `$meta`; everywhere else uses `$meta->{pins}`. The duplicate-pin `exists` check (299) never fires, and the returned registered-pins list (310) is computed from the wrong (effectively empty) structure. Line 307 also lacks a trailing semicolon (cosmetic — block-final, compiles OK; agent's "syntax error" claim was overstated).
- **F3** (→V3): `INTERRUPTS.md` (line 164) tells users to call `WiringPi::API::interrupt_dropped()` directly; there is no `$pi->interrupt_dropped` proxy though every other interrupt control method is wrapped. Inconsistent surface.
- **F4** (→V4): Pin-level `$pin->background_interrupt(...)` is documented at length in `INTERRUPTS.md` and `FAQ.pod`, but `RPi::Pin` 2.3608 implements only `set_interrupt`/`interrupt_set` — the method does not exist (and `->can` false-positives via inheritance to `WiringPi::API`). Docs are ahead of the dependency.
- **F5** (→V4): `run_interrupt_loop` POD mentions the default `$timeout_ms` 1000 only in passing prose, not the params block; `pin()` POD omits its optional `$comment` arg.
- **F6** (→V5): Version `2.3634` (and `Changes` header) predate the 3.18 API upgrade (`WiringPi::API` prereq bumped to 3.1801, branch `3.18`). Version scheme mismatch.
- **F7** (→V6-V16): Interrupt test coverage gap — only `wait_interrupts` + `$pin->set_interrupt` are exercised (t/200-202); all other dispatch/control methods and every param-validation path are untested.

## Backlog

B1: `Util.pm:17` `checksum()` returns `md5_hex(rand())` — weak/low-entropy UUID source (no PID/time/hi-res seed). `new()`'s collision loop masks it, but consider seeding with `Time::HiRes` + `$$` for robustness.

B2: `_pin_registration()` (`Core.pm:253-316`) re-`meta_lock`/`meta_fetch`es within an already-locked critical section; could fetch once at entry. Minor.

B3: `WiringPi.pm:20` `$signal_debug` is hardcoded `0` and never set true — dead toggle; either wire it to an env var or remove.

## Explicitly NOT doing

- Adding an explicit validation layer to the interrupt proxies — user chose to keep them as pure pass-throughs and test the propagated `WiringPi::API` croaks instead.
- Implementing pin-level `$pin->background_interrupt` — it belongs in the external `RPi::Pin` distribution, not here; we skip its test (V15) and flag the dependency.
- Forcing `interrupt_dropped` buffer-overflow drops in a test — timing-dependent and flaky on real hardware; V12 asserts the no-drop happy path only.
- Fixing `RPi::Pin::interrupt_set`'s double-pin bug — that defect lives in the external `RPi::Pin` module, out of this repo's scope.
