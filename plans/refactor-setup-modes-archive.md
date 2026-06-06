# Archive: Remove setup_sys() and setup_phys() initialization support

Completed tasks split out of refactor-setup-modes.md. See that file for the live
Validation Table, rules and tracking.

## Archived V Tasks

- V1: Remove the `setup_phys()` dispatch branch (`elsif ($self->_setup =~ /^p/) {...}`) from `RPi::WiringPi::new()` — ✅ 2026-06-04 attempt 1: PASS. Done on branch `3.18` as the coordinated downstream edit for WiringPi::API's V34 (which removed `setup_phys()`). Dropped the `/^p/` branch (`SUPER::setup_phys()` + `pin_scheme(RPI_MODE_PHYS)`); wpi / gpio / else→`RPI_MODE_UNINIT` branches intact. Verified: `grep -n "SUPER::setup_phys\|RPI_MODE_PHYS" lib/RPi/WiringPi.pm` → no output. Full suite run deferred — WiringPi::API 3.1801 not yet installed on this perl (UPGRADE-3.18.md V33 gate).
- V2: Remove the `RPI_MODE_PHYS` branch from `pin_to_gpio()` (Core.pm) and `pin_map()` (Util.pm) — ✅ 2026-06-06 attempt 1: PASS. Dropped both executable `RPI_MODE_PHYS` branches; kept `phys_to_gpio`/`phys_to_wpi` inside the WPI/GPIO branches. The Core.pm POD `RPI_MODE_PHYS` line was also removed under V4, so `grep -n "RPI_MODE_PHYS" lib/RPi/WiringPi/Core.pm lib/RPi/WiringPi/Util.pm` now returns nothing (cleaner than the planned "POD line remains").
- V3: Remove the `export_pin()` and `unexport_pin()` subs from Core.pm — ✅ 2026-06-06 attempt 1: PASS. `grep -n "sub export_pin\|sub unexport_pin" lib/RPi/WiringPi/Core.pm` → no output.
- V4: Remove all setup_sys / setup_phys / SYS / PHYS / export_pin / unexport_pin POD from Core.pm (`pin_scheme`, `pin_to_gpio`, `export_pin`+`unexport_pin` sections) and WiringPi.pm (`export_pin`+`unexport_pin` sections) — ✅ 2026-06-06 attempt 1: PASS. `grep -rn` sweep over lib/ returns nothing; FAQ.pod checked and had no references. podchecker reports "pod syntax OK" for all three modules.
- V5: Update t/106-pin_map.t — removed the `pin_scheme('PHYS_GPIO')` and `pin_scheme('BCM')`/sys assertions; kept default-GPIO, `'GPIO'`, `'WPI'` — ✅ 2026-06-06 attempt 1: PASS. `grep -ni "phys\|sys\|bcm" t/106-pin_map.t` → no output.
- V6: Add a Changes entry noting removal of `setup_phys()`/`setup_sys()` init support, the PHYS and SYS pin schemes, and `export_pin()`/`unexport_pin()` — ✅ 2026-06-06 attempt 1: PASS. Added at the bottom of the open `3.1800 UNREL` section (plan said `2.3634 UNREL`, but the live section is `3.1800 UNREL`); historical entries untouched.

## Archived Fixes
