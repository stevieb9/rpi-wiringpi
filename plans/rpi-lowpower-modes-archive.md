# Archive — completed V tasks and resolved fixes

## Archived V Tasks

- V1: RPi::StepperMotor `off()` (de-energize all coil pins LOW, pins stay OUTPUT, returns 0) + `cleanup()` refactored to call `off()` (fixes expander-path de-energize gap); POD `=head2 off`, cleanup POD, end-of-SYNOPSIS "Powering off" block, Changes entry; dist t/05-unit.t off()/cleanup() assertions + guarded t/352 mirror + explicit t/350 teardown park — ✅ 2026-07-16 attempt 1: PASS (dist 20 tests, t/352 17 tests with off block SKIPped pre-install)

## Archived Fixes

- Fix 1 (from V1): the plan assumed t/350-stepper.t de-energized the motor at exit via `cleanup()`, but its `$sm->cleanup` calls live only inside helper subs — the main teardown (207-211) did `$exp->cleanup; $pi->cleanup` and never de-energized `$sm`. Added a guarded `$sm->off if $sm->can('off')` before `$exp->cleanup` so the motor is explicitly parked at exit (the `can` guard covers the pre-3.1802 install lag; `$exp->cleanup` releases the pins on older installs).
