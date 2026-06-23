# Archive — completed V tasks and resolved fixes

## Archived V Tasks

- V1: DS3231 `setMonth()` raw-binary→BCD (`~/repos/rpi-rtc-ds3231` `DS3231.xs`) — ✅ 2026-06-22 attempt 1: PASS. Fixed via a new datasheet-grounded `setBcdField(fd,reg,value,keep,name)` helper (keep `0x80` = Century); months 10/11/12 now store `0x10/0x11/0x12` not `0x0A/0x0B/0x0C`. Compile-verified (`perl Makefile.PL && make`, no warnings) + standalone logic test (months 1-12 valid BCD, round-trip, century preserved). Hardware round-trip + commit/release pending (rig dark; user commits).
- V2: DS3231 `setHour()` 12-hour raw→BCD (`DS3231.xs`) — ✅ 2026-06-22 attempt 1: PASS. Same `setBcdField` path (keep `0x60` = 12/24 select + AM/PM); 24-h path keep `0x00` (bit6=0). Logic-verified (12-h hours 1-12 round-trip with flags preserved; 24-h 0-23 with bit6=0).
- V3: DS3231 negative-temperature sign (`DS3231.xs` `getTemp`) — ✅ 2026-06-22 attempt 1: PASS. MSB now read as `(int8_t)` and decoded `(int8_t)msb + (lsb>>6)*0.25` per DS3231 Rev 2 temp registers; sub-zero decodes correctly (−24.75 verified) while positive unchanged (25.25).

- V4: AT24C32 `eeprom_write_block` broken & exported (`~/repos/rpi-eeprom-at24c32` `AT24C32.xs`) — ✅ 2026-06-22 attempt 1: PASS. Removed the function and its XS export rather than "fix" it: signature was single-byte `(fd,mem_addr,data)` (a byte-for-byte duplicate of `eeprom_write`, so "block" was a misnomer), it never transmitted `addr_msb`, and it handed a 2-byte `buf` to `_writeByte` which reads `buf[2]` OOB. Off the OO path — the module's `write()` uses `eeprom_write`. Rebuilt clean (no warnings); `->can('eeprom_write_block')` now false. Hardware round-trip on the unchanged `write`/`read` path PASS at `delay => 10` (slots 200-205; `delay => 1` hit a bus-timing `Remote I/O error`, unrelated to the change). Changes 1.00 UNREL noted; uncommitted (user commits/releases).

Note: V1-V3 were done as one unified, datasheet-grounded refactor of `DS3231.xs` — all BCD setters/getters now route through `setBcdField`/`getBcdField` with masks from the Maxim DS3231 Rev 2; 6/05 register map, so the raw-vs-BCD bug class cannot recur. The XS export block was left untouched; the public per-field API is unchanged.

## Archived Fixes

_None yet._
