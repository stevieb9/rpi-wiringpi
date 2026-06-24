# Archive — completed V tasks and resolved fixes

## Archived V Tasks

- V1: RPi::Const — self-policing coverage guard for all export tags/constants (closes the untested `:altmode` + `:mcp23017_pins`) — ✅ 2026-06-23 attempt 1: PASS. Added `~/repos/rpi-const/t/50-const_coverage.t`: a `%expected` manifest (12 tags, 80 constants, names+values) checked against the live `%RPi::Const::EXPORT_TAGS`/`@EXPORT_OK` via `is_deeply` — so a new/removed tag (check 1), a new/removed constant in any group (check 2), a wrong value (check 3), or an orphan/dup in `:all` (check 4) all fail; plus the `:edge`≡`:int_edge` invariant (check 5). 178 subtests pass; full dist suite 268 pass. **Falsified**: removing `ALT5` from the manifest (simulating a new untested constant) goes RED on the altmode list check. Also added dedicated per-tag files `t/28-const_altmode.t` and `t/48-const_mcp23017_pins.t` to match the existing per-tag convention (every other tag has its own file). Full dist suite 18 files / 290 tests PASS. Lives in rpi-const only (not mirrored into rpi-wiringpi, per user). Changes 1.07 UNREL noted; uncommitted (user commits).

- V2: RPi::Pin — ungated HW-free validation coverage, mirrored into rpi-wiringpi — ✅ 2026-06-23 attempt 1: PASS. Added `rpi-pin/t/10-validation.t` (23 tests, `NO_BOARD=1` + eval/like, no Test::Fatal prereq): `new` integer-validation dies (undef/'x'/-1/'1.5'/''), valid `new` isa + `num`/`comment` accessors, `mode`/`write`/`pull` bad-arg dies, `pwm` non-root die (SKIP under root), the 3 `set_interrupt` + 3 `background_interrupt` croaks (edge/callback/debounce — validated before any fork), and `interrupt_set` delegation. Mirrored verbatim to `rpi-wiringpi/t/116-pin_validation.t` (uses installed RPi::Pin, no RPiTest, no shm → independent of the serial suite + t/110-114 counts); both pass ungated with no Pi. Surfaced F18 (`mode_alt` has no input validation → B13). rpi-pin Changes 3.1802 UNREL noted; uncommitted (user commits).

## Archived Fixes

_None yet._
