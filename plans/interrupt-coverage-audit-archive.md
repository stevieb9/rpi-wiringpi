# Archive: Audit fixes + comprehensive interrupt test coverage for RPi::WiringPi

> Companion archive for interrupt-coverage-audit.md. Completed V tasks and resolved Fixes land here.

## Archived V Tasks

- V1: Fix `Core.pm:275` precedence bug (`! $h{...} eq $self->uuid` → `ne $self->uuid`) — ✅ 2026-06-05 attempt 1: PASS
- V2: Fix `Core.pm:299`/`:310` `$self->{meta}{pins}` → local `$meta->{pins}` + trailing `;` at :307 — ✅ 2026-06-05 attempt 1: PASS
- V3: Add `interrupt_dropped` proxy + POD to `WiringPi.pm`; reference `$pi->interrupt_dropped` in `INTERRUPTS.md` — ✅ 2026-06-05 attempt 1: PASS
- V4: POD/clarity fixes — `run_interrupt_loop` params block, `pin()` `$comment` arg, `$pin->background_interrupt` dependency note; reconciled `INTERRUPTS.md`/`FAQ.pod` — ✅ 2026-06-05 attempt 1: PASS
- V5: Bumped `$VERSION` 2.3634 → 3.1800; updated `Changes` header + appended V1-V4 entries (test-coverage entry deferred to V16) — ✅ 2026-06-05 attempt 1: PASS

## Archived Fixes

_None yet._
