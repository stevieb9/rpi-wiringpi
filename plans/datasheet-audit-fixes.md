# Plan: Address datasheet-validity audit findings (rpi-wiringpi + driver dists)

> **NEXT ACTION:** V7 — MCP42010 `shutdown()` omits the CS toggle in `~/repos/rpi-digipot-mcp4xxxx` (`MCP4XXXX.pm:56-72`)
> **LAST SESSION:** 2026-06-22 — V9 done (out of order): cleared the live stale `RPi::Pin 2.3609` refs in rpi-wiringpi, correcting them to the real floor `3.1802` (Makefile.PL had moved 3.1801->3.1802) — `WiringPi.pm` POD dependency note + `t/211` comment — and removed the now-dead `RPi::Pin` version guard in `t/212` (the `< 2.3609` check never fires on a 3.18xx install; the prereq floor already requires a version with pin-level `background_interrupt`). Left the dated `3.1802`-release Changes entries alone (frozen history — RPi::Pin really was 2.3609 at that release). `grep 2.3609 lib/ t/` clean; t/211 (61) + t/212 (48, interrupt HW ran) PASS. Uncommitted.
> **ARCHIVE:** See datasheet-audit-fixes-archive.md for completed V1-V6, V9, V12

<!-- AI-STATE (terse resume state; authoritative over prose above on conflict)
PTR=V7 | Q=V7>V8>V10>V11>V13 | RATE=1/turn (batch only if user auths)
V7 MCP42010 shutdown() no CS toggle @rpi-digipot-mcp4xxxx/MCP4XXXX.pm:56-72
V8 RPi::Const floor 1.04->1.06 @Makefile.PL:48
V10 bmp() POD missing $pin_base @lib/RPi/WiringPi.pm:154
V11 MCP4922 SHDN POD inverted @rpi-dac-mcp4922/MCP4922.pm:~450 (1=Active)
V13 ADS rate() not applied to conversion @rpi-adc-ads (8 SPS still read in ~9ms not ~125ms; data-rate change has no effect) -- DISCOVERED during averaging work; needs root-cause
CLOSE-V: Actual=PASS -> archive bullet -> DEL row -> mark F# RESOLVED -> advance PTR
DONE V9 stale RPi::Pin 2.3609 refs @rpi-wiringpi lib+t (->3.1802; removed dead t/212 version guard; Changes history left intact; t/211+t/212 PASS; uncommitted).
DONE V12 ADS POD/comment typos @rpi-adc-ads/ADS.pm (gain3 1.024V; ch5 mux comment 00010000; doc-only; podchecker clean; uncommitted).
DONE V6 ADS volts/percent scale by PGA FSR @rpi-adc-ads/ADS.xs pga_fsr() (HW falsified gain0==gain1 volts t/142; t/41 PI_TEST; default-gain preserved; installed 1.03; uncommitted).
DONE V5 ADS ctor gain fix @rpi-adc-ads/ADS.pm:172 (HW PGA-actuated t/142; t/02-new_gain falsified; ADS installed 1.03; uncommitted).
DONE V4 rm broken eeprom_write_block+XS export @rpi-eeprom-at24c32/AT24C32.xs (HW PASS delay=>10; uncommitted).
DONE V1-3 DS3231 BCD+sign fix (DS3231.xs uncommitted, user commits). RTC tests rebalanced:
  core->rpi-wiringpi t/321-rtc-bcd(225,ungated,PASS)+t/320 full sweep(gated); simple guards->
  rpi-rtc-ds3231 t/01(9,ungated,PASS),t/40,t/15(gated). Gating verified. HW falsification
  pending chip: stash DS3231.xs -> old=RED, fix=GREEN (see step-2 protocol).
-->

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
| V7 | MCP42010 `shutdown()` omits the CS toggle (`~/repos/rpi-digipot-mcp4xxxx` `MCP4XXXX.pm:56-72`) — unlike `set()` (l.34-55), so the command never latches under manual-GPIO CS. Bracket the `spiDataRW` with `digitalWrite($self->_cs, LOW/HIGH)`. | `cd ~/repos/rpi-digipot-mcp4xxxx && grep -nA16 'sub shutdown' lib/RPi/DigiPot/MCP4XXXX.pm` | `shutdown()` drives CS LOW before / HIGH after `spiDataRW`, matching `set()` | ⏳ |
| V8 | `rpi-wiringpi`: `RPi::Const` prereq floor too low — `Makefile.PL:48` declares `1.04`, but the suite needs the `:mcp23017_pins` constants added in `1.06` (`RPi::GPIOExpander::MCP23017` already requires 1.06). Bump to `1.06`. | `grep -n "RPi::Const" Makefile.PL` | floor is `1.06` | ⏳ |
| V10 | `rpi-wiringpi`: `bmp()` POD omits its mandatory `$pin_base` param (`lib/RPi/WiringPi.pm:154-157`; `=head2 bmp`); `t/340` calls `$pi->bmp(100)`. Document the parameter. | `sed -n '/=head2 bmp/,/=head2 dac/p' lib/RPi/WiringPi.pm` | `bmp()` POD documents the required integer `$pin_base` arg | ⏳ |
| V11 | MCP4922 POD inverts the SHDN bit polarity (`~/repos/rpi-dac-mcp4922` `MCP4922.pm` "SHUTDOWN BITS" ≈ l.450: "1 → shut down" vs DS22250A Reg 5-1 bit12 "1 = Active"). Code is correct; fix the POD. | `cd ~/repos/rpi-dac-mcp4922 && grep -niA6 'SHUTDOWN BITS' lib/RPi/DAC/MCP4922.pm` | POD states 1 = Active / 0 = Shutdown, matching the datasheet + the XS | ⏳ |
| V13 | **[discovered]** ADS1115 `rate()` has no effect on the conversion (`~/repos/rpi-adc-ads`): setting the slowest rate (8 SPS, ~125 ms/conversion) still reads in ~9 ms (the 128 SPS default), so the data-rate config never reaches the chip. Found while characterising the averaging feature. Needs root-cause (config bits / single-shot OS-poll). | `cd ~/repos/rpi-adc-ads && grep -nE 'rate|DR' ADS.xs lib/RPi/ADC/ADS.pm` | a non-default `rate()` measurably changes the per-conversion time | ⏳ |

## Discovery Tracking

_None yet._

## Review Findings

Audit ledger from `proposal/test-platform-datasheet-validity-audit.md` (dual-AI, cross-checked vs manufacturer datasheets). Marked in place as tasks close.

- **F1** ✅ RESOLVED (V1): DS3231 `setMonth` raw-not-BCD [HIGH, dual-confirmed]
- **F2** ✅ RESOLVED (V2): DS3231 `setHour` 12-h raw-not-BCD [HIGH, dual-confirmed]
- **F3** ✅ RESOLVED (V3): DS3231 negative-temp sign lost [MED]
- **F4** ✅ RESOLVED (V4): AT24C32 `eeprom_write_block` broken & exported, off-OO-path [MED]
- **F5** ✅ RESOLVED (V5): ADS1115 constructor ignores `gain` arg [board-safe — board 2 uses default gain]
- **F6** ✅ RESOLVED (V6): ADS1115 fixed 4.096 V scaling vs PGA [board-safe — board 2 reads `percent()` at default]
- **F7** (→V7): MCP42010 `shutdown()` no CS toggle [board-safe — board 2 uses only the wiper]
- **F8** (→V11): MCP4922 POD SHDN polarity inverted [doc-only; code correct]
- **F9** ✅ RESOLVED (V12): ADS1115 POD typos [doc-only]
- **F10** (→V8): `RPi::Const` floor 1.04 < needed 1.06 [transitively masked on normal install]
- **F11** ✅ RESOLVED (V9): stale `RPi::Pin 2.3609` refs [runtime-harmless; misstates floor]
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
