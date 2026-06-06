# Archive: Audit fixes + comprehensive interrupt test coverage for RPi::WiringPi

> Companion archive for interrupt-coverage-audit.md. Completed V tasks and resolved Fixes land here.

## Archived V Tasks

- V1: Fix `Core.pm:275` precedence bug (`! $h{...} eq $self->uuid` → `ne $self->uuid`) — ✅ 2026-06-05 attempt 1: PASS
- V2: Fix `Core.pm:299`/`:310` `$self->{meta}{pins}` → local `$meta->{pins}` + trailing `;` at :307 — ✅ 2026-06-05 attempt 1: PASS
- V3: Add `interrupt_dropped` proxy + POD to `WiringPi.pm`; reference `$pi->interrupt_dropped` in `INTERRUPTS.md` — ✅ 2026-06-05 attempt 1: PASS
- V4: POD/clarity fixes — `run_interrupt_loop` params block, `pin()` `$comment` arg, `$pin->background_interrupt` dependency note; reconciled `INTERRUPTS.md`/`FAQ.pod` — ✅ 2026-06-05 attempt 1: PASS
- V5: Bumped `$VERSION` 2.3634 → 3.1800; updated `Changes` header + appended V1-V4 entries (test-coverage entry deferred to V16) — ✅ 2026-06-05 attempt 1: PASS
- V6: `t/203-dispatch_interrupts.t` — non-blocking `dispatch_interrupts()` drains 3 pre-filled rising edges, returns count 3 + fires callback without `wait_interrupts`; second drain returns 0 with no re-fire — ✅ 2026-06-05 attempt 1: PASS (44/44)
- V7: `t/204-last_interrupt.t` — `last_interrupt()` hashref exposes {pin,pin_bcm,edge,status,ts_us}; `pin_bcm==18`; `edge` follows armed type (RISING=2→FALLING=1); `ts_us` positive + monotonically increasing across re-arm — ✅ 2026-06-05 attempt 1: PASS (52/52)
- V8: `t/205-stop_interrupts.t` — armed edge dispatches; after `stop_interrupts` the pipe is torn down (`wait_interrupts` returns 0, count frozen); re-arming with `set_interrupt` resumes dispatch — ✅ 2026-06-05 attempt 1: PASS (44/44)
- V9: `t/206-run_interrupt_loop_max.t` — pre-filled burst, `run_interrupt_loop(200,3)` returns 3 + count==3, `(100,1)` returns 1; `alarm 20` watchdog guards the never-reach-max hang — ✅ 2026-06-05 attempt 1: PASS (45/45)
- V10: `t/207-stop_interrupt_loop.t` — forked child paces 6 edges; callback calls `stop_interrupt_loop` at threshold 3; no-`$max` loop returns 3 (not full burst), `alarm 20` watchdog; stable across 5 runs — ✅ 2026-06-05 attempt 1: PASS (42/42)
- V11: `t/208-auto_dispatch_interrupts.t` — `auto_dispatch_interrupts(1,'IO')` then `'USR1'`; counter advances 3 in a sleep-only poll loop (no wait/dispatch call), proving async SIGIO/SIGUSR1 delivery; `auto_dispatch_interrupts(0)` after each block; stable across 3 runs — ✅ 2026-06-05 attempt 1: PASS (42/42)
- V12: `t/209-interrupt_buffer.t` — baseline pipe 262144; grow to 524288 with get `>=` requested (page-rounded); 5-edge burst all dispatched, `interrupt_dropped()==0`; restored to baseline — ✅ 2026-06-05 attempt 1: PASS (47/47)
- V13: `t/210-background_interrupts.t` — plural `background_interrupts([18,RISING,cb,0])`: `running` true / `pid` positive; child reports edges via temp-file IPC (plural handle has no results channel, D2/B4); parent drives 3 edges → tallied; `disarm(18)` freezes tally, `arm(18)` resumes; `arm(99)`/`disarm(99)` croak; `stop` reaps (`running` false, no zombie). Stable across 5 runs — ✅ 2026-06-05 attempt 1: PASS (50/50)
- V14: `t/211-interrupt_validation.t` — 19 propagated-croak assertions (regexes anchored to real RPi::Pin 2.3609 + WiringPi::API strings): bad edge/callback/debounce on `$pin->set_interrupt`; `interrupt_buffer(0/-5/'x')`; `run_interrupt_loop` bad timeout/max; `auto_dispatch_interrupts(2/'x'/1,'NOPE')`; `background_interrupts` empty/non-arrayref/bad pin/edge/callback/debounce — ✅ 2026-06-05 attempt 1: PASS (59/59)
- V15: `t/212-pin_background_interrupt.t` — REAL functional test (installed RPi::Pin 2.3609 + bumped Makefile.PL prereq): `$pin->background_interrupt(RISING,cb,0,{results=>1})` — `running`/`pid`/`->fh` wired; parent drives 3 edges, drains 3 results via `->read` (each == EDGE_RISING); `stop` reaps. Version-guarded `skip_all` on < 2.3609. Stable across 3 runs — ✅ 2026-06-05 attempt 1: PASS (6 functional + pin status)
- V16: MANIFEST += t/203-t/212 (numeric order); deferred `Changes` entry appended (test coverage + per-board config + RPi::Pin prereq bump); full range `t/200-t/212` run together PASS (13 files / 600 tests, pins reset between files); MANIFEST verified (no disk files missing, t/515 skips cleanly — optional Test::CheckManifest absent) — ✅ 2026-06-05 attempt 1: PASS

## Archived Fixes

_None yet._
