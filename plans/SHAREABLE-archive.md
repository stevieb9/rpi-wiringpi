# Archive: shareable-refactor

Completed V tasks and resolved fixes for `shareable-refactor.md`.

## Archived V Tasks

- V1: Swap dependency in `Makefile.PL` (`IPC::Shareable` >= 1.17 + `String::CRC32`, keep `JSON::XS`, drop `IPC::ShareLite`) — ✅ 2026-06-06 attempt 1: PASS
- V2: Rewrite `Meta.pm` backend to tie-a-SCALAR (IPC::Shareable + JSON::XS string + String::CRC32 key derivation); `meta`/`meta_key`/`meta_fetch`/`meta_store`/`meta_key_check` reimplemented, `meta_set/get/delete/erase` left intact — ✅ 2026-06-06 attempt 1: PASS
- V3: No-XS functional gate `build_testing/meta_shareable_check.pl` (16 assertions: key/key_check, lock/fetch/store, detachment, set/get/delete, erase 0/1, fork cross-process, single-segment no-fan-out); empirically confirmed scalar=1 segment vs hash=6; persistence across reruns verified via __runs marker — ✅ 2026-06-06 attempt 1: PASS
- V4: Update `t/02-shm_key.t` to expect `meta_key == 1473559184` (crc32 of 'rpit'); key_check rpit=1/blah=0 retained; 3/3 pass on the Pi (env: `PI_BOARD=1 RPI_OBJECT_COUNT=0`) — ✅ 2026-06-06 attempt 1: PASS
- V5: Meta-data tests on hardware (t/03, t/05, t/110 green; t/111 expected-skip without RPI_MULTI). Initial 3 "pin set back to default mode" failures were PRE-EXISTING hardware pin-state artifacts (pins 18/24/25 not at pristine power-on defaults), NOT a migration regression — pin 18's full register→OUTPUT→cleanup-restore round-trip through shm metadata proved the backend works. Cleared by resetting pins to defaults (18→alt0 via `gpio -g mode 18 in`; 24/25→alt31 via `pinctrl set N no`) — ✅ 2026-06-06 attempt 1: PASS
- V6: Object/pin registration + cleanup paths (t/100, t/105, t/106, t/150 all green). t/150 initially died at "pin 18 is already in use" (line 36) — root cause was Fix 1 (the `_pin_registration` unregister ownership guard, a branch-only bug NOT from the IPC::Shareable migration). After Fix 1 + the standard pin-reset precondition, 4/4 pass; V5 tests re-verified unbroken — ✅ 2026-06-06 attempt 1: PASS

## Archived Fixes

- Fix 1 (discovered during V6): `_pin_registration` unregister ownership guard was a no-op. `register_pin` stores `users{$uuid}` as a **count** (`...{$requester}++`), but the unregister guard compared that count against the uuid string: `if ($meta->{pins}{$pin_num}{users}{$param{requester}} ne $self->uuid)` → `1 ne $uuid` always true → returned early, never deleting the pin, so a later `register_pin` croaked "already in use". Introduced by branch commit `61eacd7 "fix logic bug"` (3.18 only, NOT on master, predates the migration commits) which inverted an earlier accidentally-working precedence form `(! $count) eq $uuid` (always false → always fell through). Fixed to an existence/ownership check: `if (! exists $meta->{pins}{$pin_num}{users}{$param{requester}})`. `lib/RPi/WiringPi/Core.pm:272`. Resolved 2026-06-06 as part of V6.
