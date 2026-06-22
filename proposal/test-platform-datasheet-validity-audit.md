# Test-Platform Datasheet Validity Audit — AI Debate Proposal

**Date:** 2026-06-22
**Channel:** `/tmp/debate-1782114748-14102.md` (12 turns, hard cap 30)
**Outcome:** **RESOLVED** (mutual convergence; no material disagreement)
**Method:** turn-based adversarial debate between two AIs communicating only through a shared channel file on host `rpi2`, the challenger reaching it over SSH from `domingo`. Burden-of-proof, tangible-reality, go-after-blood rules; every claim grounded in code line numbers and manufacturer datasheet pages. Per the user, **nothing was fixed — findings are recorded only.**

---

## Objective

**Question (fact-finding for a PCB-fab decision):** Are `rpi-wiringpi`'s tests, POD, and code — and those of every dependency submodule — factually valid against the IC datasheets and the board designs, to the standard required to commit a PCB to fab? Secondary: is the `docs/test-platform/` single-source regeneration + off-limits-board protection complete enough to trust?

**User intent/constraints:** This decides a real PCB build, so every claim must be backed by fact (datasheet pages + exact code lines), never assumption or memory. Validity must hold across `rpi-wiringpi` (lib/, t/, POD) and all ~18–20 PREREQ submodules (`RPi::*` + `WiringPi::API`). Canonical source for any submodule = its **latest GitHub HEAD** at `github.com/stevieb9/<repo>` (installed/local copies are skewed). Off-limits boards (board 3 = done/ordered; board 2 = in progress; boards 1/4/5 stationary) must stay byte-untouched.

---

## Participants & Outcome

| Handle | Self-declared name | Role |
|--------|--------------------|------|
| `claude` | Claude (claude-opus-4-8) | Originator; owns this transcript |
| `challenger` | Claude (claude-opus-4-8) | Adversary; reached the channel over SSH from `domingo` |

**Final status: RESOLVED** — set by the challenger (Turn 12) on the user's approval; originator wrote this transcript.

---

## Decision

For the fab decision: **boards 2 and 3 are clean.**

- **Layer 1 (pins/addresses):** every PCB-critical pinout and I2C/SPI address is datasheet-correct (gated by `check-board-nets.py` / `check-datasheets.py` and independently re-verified). Boards 2 & 3 are clean at the copper level.
- **Layer 3 (driver behaviour as the boards use it):** every board-2 device (MCP3008, MCP4922, MCP42010, ADS1115, 74HC595) and board-3 device (MCP23017 ×2, 28BYJ-48/ULN2003 stepper) is datasheet-correct **for its actual usage**.
- **Every defect that fires in ordinary operation is on board 4, which is not built.**

**Board 3 (already ordered) is clean end-to-end** — pins, MCP23017 registers, and the stepper drive path all verified. Nothing found blocks what is at or near the fab.

---

## Findings ledger (severity-ranked, recorded — NOT fixed)

### HIGH — fires in ordinary use (board 4, UNBUILT)
| Finding | Location | Datasheet | Notes |
|---|---|---|---|
| `setMonth` writes raw binary, not BCD | `DS3231.xs:147` (via `setRegisterBits`, whose comment l.353 says "never call dec2bcd") | Maxim DS3231 | Months 10/11/12 stored `0x0A/0x0B/0x0C` (illegal BCD) → breaks the chip's date/rollover. **Dual-confirmed, both AIs.** |
| `setHour` 12-hour mode writes raw binary, not BCD | `DS3231.xs:90` | Maxim DS3231 | Hours 10/11/12 non-BCD. 24-hour path (`dec2bcd`) is correct. **Dual-confirmed.** |

### MED — real, but edge-case / off the live path (board 4, UNBUILT)
| Finding | Location | Notes |
|---|---|---|
| Negative temperatures decode as large positives | `DS3231.xs:165-172` | `getRegister` returns the byte as a non-negative `int`; `getTemp`'s `(short)msb` can't sign-extend a 0–255 value → sign bit lost. Positive temps correct. (Challenger's catch; originator had wrongly passed it.) |
| `eeprom_write_block` broken & exported | `AT24C32.xs:124-139` (XS export l.170-174) | Computes `addr_msb` but never sends it; builds `buf[2]={LSB,data}` and passes it to `_writeByte` (`:35`) which reads `buf[2]` out of bounds and uses LSB as the command byte → wrong cell + garbage. **Off the OO path** (`.pm` never calls it; correct-ish unused `_writeBlock` helper exists) → no live caller. (Originator's catch.) |

### Dormant-at-default / board-safe (latent)
| Finding | Location | Notes |
|---|---|---|
| ADS1115 constructor drops `gain` arg | `ADS.pm:172` (`$self->gain($args{mode})` should be `$args{gain}`) | Board-2 tests pass no gain → dormant. **Dual-confirmed.** |
| ADS1115 volts/percent hard-code 4.096 V FSR | `ADS.xs:79,82` | Wrong at any non-default PGA (SBAS444E Table 8-3). Board-2 uses default gain + `percent()` → dormant. **Dual-confirmed.** |
| MCP42010 `shutdown()` omits CS toggle | `MCP4XXXX.pm:56-72` vs `set()` `:34-55` | Shutdown command never latched under manual-GPIO CS (DS11195C Fig 5-1). Board 2 (t/345) uses only the wiper path. (Originator's catch; challenger confirmed.) |

### Documentation / version only
| Finding | Location |
|---|---|
| MCP4922 POD inverts SHDN bit polarity | `MCP4922.pm` "SHUTDOWN BITS" ~l.450 ("1 → shut down" vs DS22250A Reg 5-1 bit12 "1 = Active"); XS code is correct |
| ADS POD typos (diff-MUX comments; gain "±2.024"→±1.024) | `ADS.pm:46-47`, `:807` |
| `bmp()` POD omits its mandatory `$pin_base` param | `lib/RPi/WiringPi.pm:154-157` + `=head2 bmp` |
| `RPi::Const` floor too low (1.04 declared; suite needs 1.06 mcp23017 pin constants) | `Makefile.PL:48`; cf. `RPi::GPIOExpander::MCP23017` requires 1.06. Transitively masked by GPIOExpander's floor on a normal install. |
| Stale `RPi::Pin 2.3609` references (real floor is 3.1801) | `WiringPi.pm:1308`, `t/211:19`, `t/212:14,19,22`, `Changes:90,274`. Runtime-harmless. |
| HCSR04 cm = inch×2.54 ≈ raw/58.27 vs datasheet raw/58 (−0.46%, within spec) | `HCSR04.xs:68` (not board-mounted) |
| SSD1306 VCOMH `0xDB,0x40` valid but not a tabulated level; DS1307 `temp()` returns RAM garbage; BMP180 OSS hard-coded 0 | (cosmetic / scope) |

### Structural note (gaps A and E)
The repository **never checks** `datasheet-pinouts.json` against the actual manufacturer PDF (gap **A**), nor any **driver's command/register behaviour** against the datasheet (gap **E**). The gates prove model↔JSON↔PCB internal consistency only. This audit was that missing external check, performed by hand. The agreed ceiling for gap A is **provenance-hash + dual independent transcription**; pure automation is impossible for diagram-only datasheets.

---

## Major points by side

**Originator (claude):** Opened by arguing the test-platform validation was *not* "as complete as it can be" (five concrete gaps). Conceded its two headline pillars once the challenger proved them gated. Drove the debate onto the real layers (A datasheet-truth, E driver-behaviour), then produced board-2 driver audits (MCP3008 clean; ADS1115 two gain bugs) and Wave-2 audits (stepper clean; DS3231 two BCD bugs; AT24C32 broken `eeprom_write_block`; BMP180/SSD1306 clean). Caught the MCP42010 shutdown-CS and MCP4922 POD-SHDN defects the challenger's first pass missed.

**Challenger:** Demolished the originator's two opening pillars as already-gated (citing `check-board-nets.py` `compare()` stray-pin detection and `check-datasheets.py` `model_files()`/`check_pins`). Identified gap **A** as the load-bearing datasheet hole. Ran a 20-submodule sweep; caught the DS3231 negative-temp bug, HCSR04 −0.46%, and the Layer-4 doc/version issues the originator missed. Correctly **refuted** the originator's AT24C32 "endianness-fragility" over-claim (SMBus words are low-byte-first by spec, host-independent). Closed the 74HC595 behaviour gap (`sr595.c` `myDigitalWrite` MSB-first protocol).

---

## Points of agreement
- Layer-1 pins/addresses: all datasheet-correct → boards 2 & 3 fab-clean.
- Layer-3 driver behaviour clean as-used for all board-2/board-3 devices.
- DS3231 `setMonth` + 12-hour `setHour` raw-not-BCD = real HIGH defects (independently found by both).
- The original "single-source breaks at finalized boards" and "model↔per-board-model ungated" pillars are gated (the originator conceded both).
- Gap A cannot be fully closed by code; ceiling = provenance-hash + dual transcription.
- The dual-independent cross-check materially improved the result — each side caught real defects the other missed, and one over-claim was refuted and withdrawn.

## Failures to agree / open items
- None of substance. The only items left open are *choices for the user*, not disagreements: whether to (a) fix the board-4 DS3231/AT24C32 defects, (b) add gap-A/E gates (PDF provenance hash; a driver-behaviour check), and (c) correct the doc/version items (`RPi::Const` floor → 1.06, strike `RPi::Pin 2.3609`, `bmp()` POD).

---

## Transcript (condensed; code, file:line citations, and datasheet refs preserved verbatim)

**Turn 1 — claude.** Position: "nothing more can be done" is false. Five gaps: (1) single-sourcing breaks at finalized boards — `gen-test-platform.pl` renders from `board-model.py` but as-built KiCad is hand-finalized and `gen-kicad.py:489-493` refuses to overwrite (board 3's J1 was 4-pin in KiCad vs 3-pin model until fixed today); (2) `board-model.py`↔`board-N-model.py` ungated; (3) "off-limits" defined three incompatible ways (`gen-kicad.py` refuse-if-exists / `check-board-locks.py` bless / `t/04` `%FROZEN`); (4) `check-datasheets.py` covers only pin maps + I2C addresses; (5) "single call" runs two scripts and silently skips schematic SVG/PDF when netlistsvg/cairo absent, with no staleness gate. Demanded attack on #1 and #2.

**Turn 2 — challenger.** Conceded the *conclusion* but demolished #1 and #2 as already-gated: `check-board-nets.py` `compare()` (l.182-185) stray-pin detection makes board-3 J1 drift a build failure, wired at `t/04:121-128`; `check-datasheets.py` `model_files()` (45-52) diffs every model against `datasheet-pinouts.json` so two files vs the same third can't silently diverge on a covered pin. Opened the real gaps: **A** — nothing proves `datasheet-pinouts.json` matches the manufacturer PDF (the MCP42010-reversal class); **B** — SPDIP-28 vs DIP-28 footprint hint unverified; **C** — schematic-render staleness; **D** — citation hygiene: `Makefile` is gitignored/generated, source is `Makefile.PL`.

**Turn 3 — claude.** Conceded #1, #2, and #D. Refuted **B** with measured geometry: board-3 `U1.kicad_mod` pad rows at X=0.0 and X=7.62 mm = 0.300″ = SPDIP-28 (matches datasheet); descriptor says "Generic outline, not a true package." Fully conceded **A**. Opened **E**: no static gate checks driver code vs datasheet; board-2 drivers unverified. Assigned the cross-check: challenger to audit MCP4922/MCP42010 from GitHub HEAD, originator to take ADS1115/MCP3008.

**Turn 4 — challenger.** Proposed concrete A-mechanisms (provenance hash; `pdftotext` diff for textual tables; dual transcription) and conceded A cannot be fully automated for diagram-only datasheets. Conceded E for board 2. Ran a 20-submodule sweep: HIGH — `RPi::Const` floor 1.04 < needed 1.06 (`Makefile.PL:48`); HIGH — phantom `RPi::Pin 2.3609`; MED — `bmp()` POD omits its param. Verified the rest clean; warned not to chase UNREL upstream version bumps.

**Turn 5 — claude.** Recorded the originator's audits: **MCP3008** (`rpi-adc-mcp3008` @ `0ca01f3` vs DS20001295E) **correct** — `MCP3008.xs` start byte `0x01`, `inputs[input]<<4`, result `(buf[1]&0x03)<<8|buf[2]`. **ADS1115** (`rpi-adc-ads` @ `f171100` vs SBAS444E) correct at default but two bugs: `ADS.pm:172` drops the `gain` arg; `ADS.xs:79,82` hard-code 4.096 V. Independently verified the challenger's Layer-4 claims: `RPi::Const` floor real but transitively masked; `RPi::Pin 2.3609` is *stale* not phantom (real old 2.36xx-scheme release; runtime-harmless); `bmp()` POD confirmed. Demanded the challenger actually *audit* MCP4922/MCP42010, not just concede.

**Turn 6 — challenger.** Audited MCP4922 (vs DS22250A) and MCP42010 (vs DS11195C) — command words MATCH; rendered the PDFs at 300–600 dpi. **Independently confirmed both ADS1115 bugs** (dual-transcription mechanism working). Recorded the rest of Wave 1 MATCHES (MCP3008, 74HC595, HD44780, MCP23017). Proposed RESOLVED pending the user's widened scope; ran Wave 2.

**Turn 7 — claude.** Verified two divergences from raw GitHub HEAD source: **MCP42010 `shutdown()` omits the CS toggle** (`MCP4XXXX.pm:56-72` vs `set()` `:34-55`); **MCP4922 POD inverts SHDN** (`MCP4922.pm` ~l.450 "1 → shut down" vs DS22250A Reg 5-1 bit12 "1 = Active"). Launched independent Wave-2 audits (stepper + board-4 sensors).

**Turn 8 — challenger.** Confirmed both divergences from source. Wave 2: **DS3231** two HIGH BCD bugs (`DS3231.xs:147,90`) plus negative-temp-on-ARM (MED), DS1307 `temp()` (LOW), t/320 blind (LOW); **MCP23017 registers** (board 3) MATCH; **stepper** MATCH; **AT24C32** "MATCHES" (delay note only); **SSD1306** MATCH; **DHT11** MATCH; **HCSR04** −0.46% (LOW); **BMP180** MATCH. Read fleet as substantively RESOLVED pending DS3231 cross-check.

**Turn 9 — claude.** Converged on the DS3231 BCD HIGHs (verified `DS3231.xs:90,147` use `setRegisterBits`, comment l.353 "never call dec2bcd"). **Conceded** the DS3231 negative-temp bug (verified: `getRegister` returns non-negative `int`; `getTemp` l.169 `(short)` casts don't sign-extend → sub-zero wrong). Raised two AT24C32 findings the challenger's pass missed: portability-fragility (claimed) and `eeprom_write_block` broken+exported (`AT24C32.xs:124-139`, verified). Flagged the lone board-2 gap: 74HC595 shiftOut behaviour. Deferred RESOLVED to the user.

**Turn 10 — challenger.** Confirmed `eeprom_write_block` broken & exported but **off the OO path** (latent). **Refuted** the AT24C32 endianness-fragility claim: `i2c_smbus_write_word_data` (`_writeByte` `:35`) sends the word low-byte-first **by SMBus spec, independent of host endianness** — portable. Closed the 74HC595 gap: board 2 drives the 595 via `sr595.c` `myDigitalWrite` (l.44-77) — latch LOW → per-bit MSB-first DATA then SHCP pulse → latch HIGH = correct 74HC595 protocol. Declared substantive RESOLVED; deferred DONE to the user.

**Turn 11 — claude.** **Conceded and withdrew** the AT24C32 endianness-fragility claim (the agent had conflated host memory layout with the SMBus wire protocol; the write path is portable and correct — only the sub-t_WR default delay caveat stands). Accepted the `eeprom_write_block` off-OO-path framing and the 74HC595 closure (board 2 now fully Layer-3 audited). Declared full convergence; deferred DONE to the user.

**Turn 12 — challenger.** RESOLVED on the user's approval. Restated the final reconciled record (Layer 1 pins clean → boards 2 & 3 fab-clean; Layer 3 clean as-used; ordinary-use defects all on board 4; structural gaps A+E noted; nothing fixed). Set `TURN_OWNER: DONE`, `RESOLUTION: RESOLVED`.

---

*Datasheets consulted (verbatim doc numbers): TI SBAS444E (ADS1115), Microchip DS20001295E (MCP3008), DS22250A (MCP4902/12/22), DS11195C (MCP41/42xxx), DS20001952D (MCP23017), DS20006047A (AT24C32D), Maxim DS3231, Bosch BST-BMP180-DS000-09, Solomon Systech SSD1306 Rev 1.1, TI SCLS041J (74HC595), TI SLRS027 (ULN2003A), Hitachi HD44780U / Vishay LCD-016N002M.*
