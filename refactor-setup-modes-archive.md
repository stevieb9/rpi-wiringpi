# Archive: Remove setup_sys() and setup_phys() initialization support

Completed tasks split out of refactor-setup-modes.md. See that file for the live
Validation Table, rules and tracking.

## Archived V Tasks

- V1: Remove the `setup_phys()` dispatch branch (`elsif ($self->_setup =~ /^p/) {...}`) from `RPi::WiringPi::new()` — ✅ 2026-06-04 attempt 1: PASS. Done on branch `3.18` as the coordinated downstream edit for WiringPi::API's V34 (which removed `setup_phys()`). Dropped the `/^p/` branch (`SUPER::setup_phys()` + `pin_scheme(RPI_MODE_PHYS)`); wpi / gpio / else→`RPI_MODE_UNINIT` branches intact. Verified: `grep -n "SUPER::setup_phys\|RPI_MODE_PHYS" lib/RPi/WiringPi.pm` → no output. Full suite run deferred — WiringPi::API 3.1801 not yet installed on this perl (UPGRADE-3.18.md V33 gate).

## Archived Fixes
