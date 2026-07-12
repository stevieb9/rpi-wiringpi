# Archive — completed V tasks and resolved fixes

## Archived V Tasks

- V1: Complete per-test pin/device inventory (all hardware tests + new devices a4988/gyro/adxl335/radar/tft/pca9685/lcd_i2c decoded via submodules) — ✅ 2026-07-12 attempt 1: PASS. Output: `scratchpad/pin-inventory.md`. Zero guessed facts; found content drift D1 (t/445 two dpot wipers → ADS A1+A2), stale RPiTest.pm cites (D2), 4 address/pin clashes (0x68 gyro/RTC, 0x48 ADS/ADXL335, GPIO26 MCP3008-CS/radar, TFT on CE0+23/24/25).

- V2: Master GPIO occupancy table (BCM 0–27) with FREE/SINGLE/SHARED-safe/CONFLICT classification — ✅ 2026-07-12 attempt 1: PASS. Output: `scratchpad/gpio-occupancy.md`. Result: exactly ONE truly-free header pin (GPIO7/CE1); GPIO0/1 caveated generics; GPIO26 the only same-net CONFLICT; header effectively full.
- V3: Conflict & shared-net reconciliation — ✅ 2026-07-12 attempt 1: PASS. Appended to `scratchpad/gpio-occupancy.md`. Result: 0 defects; doc-errors K1/K3(D1)/K4/K2 to fix in V4–V6; accepted timeshares K5/K6/K7 keep+refresh; relief candidate K1 (radar off GPIO26) carried to V7.
- V4: Update the pinout doc — ✅ 2026-07-12 attempt 1: PASS. Edited `docs/test-platform/test-pinout-doc.tmpl.md` across §Scope/§1/§2/§3/§4/§5/§6/§7/§8/§9/§10/§12/§13/§14: added all 7 new devices, corrected §5 CE0/CE1 + §9 "spare" claims, added I2C 0x22/0x27/0x40 + shared-addr notes (0x68, 0x48), D1 dpot PW1→A2, and refreshed the stale RPiTest.pm/per-test line cites (D2/D3). Regenerated `test-pinout-doc.md` via `python3 scripts/helpers/render-doc.py`; `--check` passes, no leftover placeholders, TOC anchor for §9 fixed.
- V5: Update the board matrix — ✅ 2026-07-12 attempt 1: PASS. `docs/test-platform/test-board-matrix.md`: added a **bench** row + new "Bench-wired devices" section (447/361/358/360/353), recomputed headline to 33 hardware tests (26 boards 2-5 + 2 board 1 + 5 bench), added the new unit tests to Excluded. Board assignment VERIFIED not guessed: grepped all 5 fabbed-board KiCad projects — none reference the new devices — and confirmed each bench device is gated by its own env var, not RPI_BOARD_N.
- V6: Sync remaining pin-bearing docs — ✅ 2026-07-12 attempt 1: PASS (no-drift outcome). Surveyed `README.md`, `lib/RPi/WiringPi/FAQ.pod`, and the POD sources (`WiringPi.pm`, `INTERRUPTS.pod`, `WORKERS.pod`) for concrete pin/addr claims: all match the V1 inventory (gyro 0x68/0x69, LCD 0x27, RTC 0x68, OLED 0x3c, expander 0x20/0x21, radar GPIO26, stepper 0x21/17/27/19, TFT CE0/CE1). The FAQ "Test file reference" table is auto-generated (`gen-faq-test-table.pl`) and already lists all 7 new tests; regenerating it + `gen-pod-md.pl` produced ZERO diff (already current). No hand-edit needed. Note: `WORKERS.pod` uses pins (23,24,25) in a generic worker EXAMPLE — illustrative API, not a test-platform claim; left as-is.

## Archived Fixes

_None yet._
