# Plan: Address datasheet-validity audit findings (rpi-wiringpi + driver dists)

> **NEXT ACTION:** V1 — DS3231 `setMonth()` BCD fix in `~/repos/rpi-rtc-ds3231`
> **LAST SESSION:** 2026-06-22 — plan created from the AI-debate audit (`proposal/test-platform-datasheet-validity-audit.md`). No code changed yet.
> **ARCHIVE:** See datasheet-audit-fixes-archive.md for completed V tasks

**Scope note — there are NO board/PCB changes.** The audit proved boards 2 & 3 are datasheet-correct at the copper level and in their drivers as-used; **nothing here blocks the fab.** Every task below is a software or documentation defect surfaced by the audit, recorded but deliberately left unfixed. Most live in the *driver distribution* repos (`~/repos/rpi-*`), not in `rpi-wiringpi`; the repo for each task is named in "What". Severity order: HIGH (fires in ordinary use) → MED → board-safe code bugs → doc/version.

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of datasheet-audit-fixes-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
  3. **Delete the V# row from this file's Validation Table.**
- V task ❌: update Actual with `❌ YYYY-MM-DD attempt N: reason`. Rerun same V# with attempt N+1. Do NOT create a new V#.
- **Sync review findings** — when a V task (or a Fix) resolves a review finding, mark its `F#` entry in `## Review Findings` **in place**: prefix `✅ RESOLVED (V#)` (or `✅ VALIDATED (V#)` if no code change was needed, or `⏸ DEFERRED → B#` if punted to backlog). Findings are a permanent audit ledger of what review surfaced and where it was handled — mark in place; never archive, delete, or renumber them.
- Update ARCHIVE pointer to reflect what's archived (e.g., `V1-V2` → `V1-V3`)
- Update NEXT ACTION to next ⏳ row; update LAST SESSION
- Never renumber within a series. New items get next free number.
- **Discovery triage during V# work** — when you find something while working a V task, classify before continuing:
  - Blocks the current V task → add `Fix N: problem discovered during V# — [what + fix]` to `## Discovery Tracking`; resolve as part of this V task's work.
  - Real bug but doesn't block this V task → add a new V# row (next free) to the Validation Table with ⏳; do not detour to fix it now.
  - Non-blocking improvement → add new B# to `## Backlog` (one `B#` per line, each separated by a blank line — never run two entries together, or Markdown collapses them into a single mashed paragraph).
  - Decided not to do → add to `## Explicitly NOT doing` with a one-line justification.
- Move resolved fixes to archive's "Archived Fixes" section; keep only unresolved in main Discovery Tracking
- To promote a backlog item to an active task: assign it the next free V# (e.g., B3 becomes V4) and move to the Validation Table. The B# slot is retired and never reused.

## Validation Table

| ID | What | Command | Expected | Actual |
|----|------|---------|----------|--------|
| V1 | **[HIGH]** DS3231 `setMonth()` writes raw binary, not BCD (`~/repos/rpi-rtc-ds3231` `DS3231.xs:147`). Route the month through `dec2bcd` while preserving the century bit (bit7). | `cd ~/repos/rpi-rtc-ds3231 && grep -nA12 'void setMonth' DS3231.xs` | Month value BCD-encoded before the register write; month 12 → `0x12` (not `0x0C`), bit7 preserved | ⏳ |
| V2 | **[HIGH]** DS3231 `setHour()` 12-hour path writes raw binary, not BCD (`DS3231.xs:90`). BCD-encode while preserving the 12/24 + AM/PM bits. | `cd ~/repos/rpi-rtc-ds3231 && grep -nA20 'void setHour' DS3231.xs` | 12-h hour BCD-encoded; hours 10/11/12 → `0x10/0x11/0x12`; 24-h path unchanged | ⏳ |
| V3 | **[MED]** DS3231 negative temperatures decode as large positives (`DS3231.xs:165-172`): `getRegister` returns a non-negative `int`, so `getTemp`'s `(short)msb` never sign-extends. Sign-extend the 8-bit MSB before combining. | `cd ~/repos/rpi-rtc-ds3231 && grep -nA8 'float getTemp' DS3231.xs` | Sub-zero temps decode negative (e.g. MSB `0xE7` → ≈ −25 °C); positive temps unchanged | ⏳ |
| V4 | **[MED]** AT24C32 `eeprom_write_block` broken & exported (`~/repos/rpi-eeprom-at24c32` `AT24C32.xs:124-139`): computes `addr_msb`, never sends it; passes a 2-byte `buf` to `_writeByte` (reads `buf[2]` OOB). Fix to send `[MSB,LSB,data...]` via the correct helper, or remove the export. | `cd ~/repos/rpi-eeprom-at24c32 && grep -nA15 'eeprom_write_block' AT24C32.xs` | `addr_msb` actually transmitted (or function removed from the XS export block); no OOB `buf` read | ⏳ |
| V5 | ADS1115 constructor drops the `gain` arg (`~/repos/rpi-adc-ads` `ADS.pm:172` — `$self->gain($args{mode})` should be `$args{gain}`). | `cd ~/repos/rpi-adc-ads && sed -n '170,174p' lib/RPi/ADC/ADS.pm` | `gain()` fed `$args{gain}`; a non-default `gain =>` in `new()` is applied | ⏳ |
| V6 | ADS1115 `volts`/`percent` hard-code 4.096 V FSR regardless of PGA (`ADS.xs:79,82`); wrong at any non-default gain (SBAS444E Tbl 8-3). Scale by the actually-programmed PGA range. | `cd ~/repos/rpi-adc-ads && grep -nE '4.096' ADS.xs` | Conversion uses the selected PGA's full-scale range, not a constant 4.096 | ⏳ |
| V7 | MCP42010 `shutdown()` omits the CS toggle (`~/repos/rpi-digipot-mcp4xxxx` `MCP4XXXX.pm:56-72`) — unlike `set()` (l.34-55), so the command never latches under manual-GPIO CS. Bracket the `spiDataRW` with `digitalWrite($self->_cs, LOW/HIGH)`. | `cd ~/repos/rpi-digipot-mcp4xxxx && grep -nA16 'sub shutdown' lib/RPi/DigiPot/MCP4XXXX.pm` | `shutdown()` drives CS LOW before / HIGH after `spiDataRW`, matching `set()` | ⏳ |
| V8 | `rpi-wiringpi`: `RPi::Const` prereq floor too low — `Makefile.PL:48` declares `1.04`, but the suite needs the `:mcp23017_pins` constants added in `1.06` (`RPi::GPIOExpander::MCP23017` already requires 1.06). Bump to `1.06`. | `grep -n "RPi::Const" Makefile.PL` | floor is `1.06` | ⏳ |
| V9 | `rpi-wiringpi`: stale `RPi::Pin 2.3609` references (real floor is `3.1801`, `Makefile.PL:59`). Update/remove in `lib/RPi/WiringPi.pm:1308`, `t/211-interrupt_validation.t:19`, `t/212-pin_background_interrupt.t:14,19,22`, `Changes:90,274`. | `grep -rn "2.3609" lib/ t/` | no stale `RPi::Pin 2.3609` floor claims remain (refs corrected to 3.1801 or removed) | ⏳ |
| V10 | `rpi-wiringpi`: `bmp()` POD omits its mandatory `$pin_base` param (`lib/RPi/WiringPi.pm:154-157`; `=head2 bmp`); `t/340` calls `$pi->bmp(100)`. Document the parameter. | `sed -n '/=head2 bmp/,/=head2 dac/p' lib/RPi/WiringPi.pm` | `bmp()` POD documents the required integer `$pin_base` arg | ⏳ |
| V11 | MCP4922 POD inverts the SHDN bit polarity (`~/repos/rpi-dac-mcp4922` `MCP4922.pm` "SHUTDOWN BITS" ≈ l.450: "1 → shut down" vs DS22250A Reg 5-1 bit12 "1 = Active"). Code is correct; fix the POD. | `cd ~/repos/rpi-dac-mcp4922 && grep -niA6 'SHUTDOWN BITS' lib/RPi/DAC/MCP4922.pm` | POD states 1 = Active / 0 = Shutdown, matching the datasheet + the XS | ⏳ |
| V12 | ADS1115 POD typos (`~/repos/rpi-adc-ads` `ADS.pm`): differential-MUX binary comments wrong (≈ l.46-47); gain table "±2.024 V" should be "±1.024 V" (≈ l.807). | `cd ~/repos/rpi-adc-ads && grep -nE '2.024|0b' lib/RPi/ADC/ADS.pm` | diff-MUX comments and the gain table read correctly | ⏳ |

## Discovery Tracking

_None yet._

## Review Findings

Audit ledger from `proposal/test-platform-datasheet-validity-audit.md` (dual-AI, cross-checked vs manufacturer datasheets). Marked in place as tasks close.

- **F1** (→V1): DS3231 `setMonth` raw-not-BCD [HIGH, dual-confirmed]
- **F2** (→V2): DS3231 `setHour` 12-h raw-not-BCD [HIGH, dual-confirmed]
- **F3** (→V3): DS3231 negative-temp sign lost [MED]
- **F4** (→V4): AT24C32 `eeprom_write_block` broken & exported, off-OO-path [MED]
- **F5** (→V5): ADS1115 constructor ignores `gain` arg [board-safe — board 2 uses default gain]
- **F6** (→V6): ADS1115 fixed 4.096 V scaling vs PGA [board-safe — board 2 reads `percent()` at default]
- **F7** (→V7): MCP42010 `shutdown()` no CS toggle [board-safe — board 2 uses only the wiper]
- **F8** (→V11): MCP4922 POD SHDN polarity inverted [doc-only; code correct]
- **F9** (→V12): ADS1115 POD typos [doc-only]
- **F10** (→V8): `RPi::Const` floor 1.04 < needed 1.06 [transitively masked on normal install]
- **F11** (→V9): stale `RPi::Pin 2.3609` refs [runtime-harmless; misstates floor]
- **F12** (→V10): `bmp()` POD missing param [doc-only]
- **F13** (→B3): HCSR04 cm divisor −0.46% (raw/58.27 vs raw/58) [within spec; not board-mounted]
- **F14** (→B1): gap A — nothing checks `datasheet-pinouts.json` against the actual PDF
- **F15** (→B2): gap E — no automated driver-behaviour-vs-datasheet gate
- **F16** (→B4): cosmetics — SSD1306 VCOMH non-tabulated level; DS1307 `temp()` returns RAM garbage; BMP180 OSS hard-coded 0 / not selectable
- **F17** (→B5): three uncoordinated definitions of "off-limits" (`gen-kicad.py` refuse-if-exists / `check-board-locks.py` bless / `t/04` `%FROZEN`)
- **F18** (→B6): `board-model.py` ↔ `board-N-model.py` pin maps hand-copied, ungated (narrow window: module pins on an unbuilt board)

## Backlog

B1: gap A — add a PDF-provenance gate: store a committed `sha256` of each cited datasheet PDF in `datasheet-pinouts.json`, plus a CI step that re-fetches and verifies it. Pure automation can't prove transcription correctness for diagram-only datasheets; the agreed ceiling is provenance-hash + a second independent transcription.

B2: gap E — explore an automated driver-behaviour-vs-datasheet check (the debate concluded this is largely manual; capture what *can* be gated, e.g. register-constant tables).

B3: HCSR04 cm conversion divisor (`~/repos/rpi-hcsr04` `HCSR04.xs:68`) — raw/58 vs raw/58.27.

B4: cosmetic dist cleanups — SSD1306 VCOMH level code; DS1307 `temp()` guard; BMP180 OSS selectable; `RPi::BMP180` dep POD SYNOPSIS missing `->new`.

B5: unify "off-limits" onto a single source (the lock manifest) so `gen-kicad.py`, `check-board-locks.py`, and `t/04`'s `%FROZEN` can't disagree.

B6: add a `board-model.py` ↔ `board-N-model.py` drift check (cheap direct diff of the copied pin maps).

## Explicitly NOT doing

- **Touch boards 2 or 3 / change any PCB** — the audit proved them datasheet-clean at the copper level and in their drivers as-used. Nothing to change for the fab.
- **Chase UNREL upstream version bumps** — most dist HEADs are unreleased `UNREL` dev versions; the `Makefile.PL` floors correctly match the latest *released* versions. Pinning to an UNREL would make the dist uninstallable. (Exception: V8's `RPi::Const` 1.06, which IS a released version the suite genuinely needs.)
- **Auto-"fix" `datasheet-pinouts.json` against PDFs** — impossible to fully automate for diagram-only datasheets (see B1).
