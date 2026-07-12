# V2 — Master GPIO occupancy table (BCM 0–27)

Built from `pin-inventory.md` (V1). Every role traces to a V1 [T]/[L] fact.
Classification: **FREE** (no assigned role) · **SINGLE** (one fixture) ·
**SHARED-safe** (multiple roles but the tests never run concurrently — serial
suite, each cleans up) · **CONFLICT** (incompatible roles on one physical net).

"Ctx" = where the fixture physically lives: **B1–B5** = fabbed test-platform
boards; **bench** = jumper-wired robot/display devices not on any fabbed board.

| BCM | Phys | Role(s) | Tests | Ctx | Class |
|----:|-----:|---------|-------|-----|-------|
| 0 | 27 | generic test pin (ID_SD; idles high) — reserved I2C0 ID-EEPROM [F] | 108 | — | SINGLE (generic, reserved) |
| 1 | 28 | generic test pin (ID_SC; idles high) — reserved I2C0 ID-EEPROM [F] | 108 | — | SINGLE (generic, reserved) |
| 2 | 3 | **I2C SDA** — every I2C device (0x04/20/21/22/27/3c/40/48/57/68/77) | many | B1–B5+bench | SHARED-safe (bus by design) |
| 3 | 5 | **I2C SCL** — as above | many | B1–B5+bench | SHARED-safe (bus by design) |
| 4 | 7 | LCD D4 | 620 | B5 | SINGLE |
| 5 | 29 | LCD RS | 620 | B5 | SINGLE |
| 6 | 31 | LCD E | 620 | B5 | SINGLE |
| **7** | 26 | **CE1 — unused (SPI-alt default); no fixture** | — | — | **FREE** ← only truly-free header pin |
| **8** | 24 | **TFT ST7735S CS (hardware CE0)** — *doc still says "unused/free"* | 447 | bench | SINGLE (newly claimed) |
| 9 | 21 | **SPI MISO** (MCP3008 read-back) | 410,435 | B2 | SHARED-safe (SPI bus) |
| 10 | 19 | **SPI MOSI** (MCP3008/MCP4922/MCP4XXXX + **TFT**) | 410,435,445,447 | B2+bench | SHARED-safe (SPI bus) |
| 11 | 23 | **SPI SCLK** (same + **TFT**) | 410,435,445,447 | B2+bench | SHARED-safe (SPI bus) |
| 12 | 32 | MCP4922 DAC CS (bit-bang) + generic | 410; 110,112,150 | B2 | SHARED-safe (CS mode-only in harness) |
| 13 | 33 | MCP4XXXX dpot CS (bit-bang) | 445 | B2 | SINGLE |
| 14 | 8 | UART TXD → 15 | 610 | B5 | SINGLE |
| 15 | 10 | UART RXD ← 14 | 610 | B5 | SINGLE |
| 16 | 36 | 74HC595 LATCH + generic | 435; 112 | B2 | SHARED-safe |
| 17 | 11 | LCD D5 **+ stepper CW limit switch** | 620; 350 | B5/B3 | SHARED-safe (never concurrent) |
| 18 | 12 | PWM / servo / interrupt / ADS#1 A0 + generic | 400,405,425,200-213; 105,110,150,multi | B2 | SHARED-safe (**no external load** rule) |
| 19 | 35 | stepper centre LED | 350 | B3 | SINGLE |
| 20 | 38 | 74HC595 CLOCK | 435 | B2 | SINGLE |
| 21 | 40 | 74HC595 DATA + alt-mode round-trip + generic | 435; 107; 112 | B2 | SHARED-safe |
| 22 | 15 | LCD D7 | 620 | B5 | SINGLE |
| **23** | 16 | **TFT BLK (backlight)** — *doc still says "fully spare"* | 447 | bench | SINGLE (newly claimed) |
| **24** | 18 | **TFT RES (reset)** — *doc still says "fully spare"* | 447 | bench | SINGLE (newly claimed) |
| **25** | 22 | **TFT D/C (data-command)** — *doc still says "fully spare"* | 447 | bench | SINGLE (newly claimed) |
| **26** | 37 | MCP3008 ADC CS (bit-bang) + generic **+ radar OUT** | 410,435,110,112,150; **361** | B2 + bench | **CONFLICT** (CS vs radar input on one net) |
| 27 | 13 | LCD D6 **+ stepper CCW limit switch** | 620; 350 | B5/B3 | SHARED-safe (never concurrent) |

## Free-pin count (with evidence)

- **Truly unassigned header GPIO: exactly ONE — GPIO7 (CE1).** No test references
  it; it sits at its SPI-alt default (`RPiTest.pm` pi5 alt=1/state=1 for 7/8). Doc
  §9's claim that 23/24/25 are "fully spare" and CE0/CE1 "stay free" is now false:
  the TFT took CE0(8)+23+24+25 (V1 C1).
- **Caveated generics: GPIO0 / GPIO1.** Used only as generic idle-high pins (t/108);
  hardware convention (reserved HAT ID-EEPROM) says leave unrouted on a real board
  [F]. Usable as scratch GPIO but not recommended for a fixture.
- Everything else carries at least one fixture role. Net: the header is effectively
  **full** — which is the motivation for the V7 relief strategies.

## Notes for V3 (conflicts to reconcile)

- GPIO26 is the only same-net **CONFLICT** (MCP3008 CS ⟷ radar OUT).
- I2C address clashes 0x68 (gyro/RTC) and 0x48 (board-2 ADS ⟷ ADXL335 ADS, incl.
  overlapping channels A0/A1/A2) are **bus/address** contentions, not header-pin
  ones — carried into V3.
- The TFT's four claims (8/23/24/25) and radar's (26) are **bench-vs-board**
  header contention: none of these devices sit on a fabbed board, so on the PCBs
  the pins are free; the contention only arises when bench devices and board
  fixtures hang off the same Pi header at once.

---

# V3 — Conflict & shared-net reconciliation

Each clash classified grounded (no guessing): **DEFECT** (a real bug to fix),
**DOC-ERROR** (reality is fine; the docs are stale), or **ACCEPTED-TIMESHARE**
(genuinely shared but the serial, self-cleaning suite never runs the roles at
once). "Never concurrent" rests on `RPiTest.pm:3-7` (serial-only) + per-test
cleanup, and on the per-device env gates.

### K1 — GPIO26: MCP3008 CS ⟷ radar OUT → **DOC-ERROR + relief candidate** (not a defect)
- Evidence: MCP3008 CS=26 [T t/410:35], radar OUT=26 [T t/361:65]. MCP3008 is board 2;
  radar is bench. Gated separately (RPI_I2C-family vs RPI_RADAR); never concurrent.
- The radar driver has **no built-in default pin** — it croaks if none is given
  [T RCWL0516.pm:27-28] — so GPIO26 is purely the *test file's* choice, landing on a
  live bit-banged CS net for no reason.
- Verdict: not a software defect (serial suite). It IS a needless default collision
  and the single cheapest pin-relief move: change the `t/361` default (and
  `RPI_RADAR_PIN` guidance) to a genuinely-free pin — **GPIO7/CE1** is the obvious
  target (V2: the only truly-free header pin). Recorded for V7; do NOT change now
  (Phase-1 is doc-truth only).

### K2 — I2C 0x68: MPU-6050 gyro ⟷ DS3231 RTC → **ACCEPTED-TIMESHARE / DOC note**
- Evidence: gyro 0x68 [T t/358:76], RTC 0x68 [L t/530:31]. Gyro bench, RTC board 4.
  Two devices at one address can't share a live bus segment, but they're never wired
  together (different context, separate gates RPI_GYRO vs RPI_RTC).
- Escape hatch if ever co-resident: MPU-6050 AD0-high → **0x69** [L MPU6050.pm:194-195].
- Verdict: not a defect. Docs should record the shared 0x68 and the 0x69 escape.

### K3 — I2C 0x48 + channels: board-2 ADS ⟷ ADXL335 ADS → **ACCEPTED-TIMESHARE + D1 doc fix**
- Evidence: board-2 ADS1015 @0x48 uses A0 (PWM/servo), A1 (dpot PW0), **A2 (dpot PW1)**
  [T t/445:38-39]. ADXL335 reads an ADS @0x48 on ch **0/1/2** [T t/360:72-76; L ADS.pm:191].
  Same address AND same three channels. ADXL335 is bench (robot family); the board-2
  ADS is a different physical chip. Never co-resident.
- Escape hatch: ADS supports 0x48–0x4B [L ADS.pm:184-186]; a second ADS straps 0x49.
- Verdict: not a defect. But the doc MUST add the A2 (dpot PW1) path — that's **D1**,
  fixed in V4 regardless of this clash.

### K4 — TFT on CE0(8) + 23/24/25 → **DOC-ERROR** (reality is correct)
- Evidence: TFT CS=hardware CE0=GPIO8, DC=25, RES=24, BLK=23 [T t/447:46,70-72].
  Doc §5 says "hardware CE0/CE1 stay free" and §9 says "GPIO23/24/25 fully spare".
- The TFT correctly uses these pins; only the docs are stale. TFT is also the **only**
  hardware-CE0 SPI device (board-2 SPI devices all bit-bang CS) — architecturally
  notable, worth stating. TFT shares MOSI/SCLK (10/11) with the board-2 SPI bus by
  design (one CS active at a time); no conflict with the bit-banged CS lines 26/12/13
  because CE0=8 is a distinct net.
- Verdict: not a defect. Rewrite §5/§9 (and §2 map) in V4.

### K5 — GPIO17/27: LCD D5/D6 ⟷ stepper CW/CCW limits → **ACCEPTED-TIMESHARE** (already documented)
- Evidence: LCD D5=17, D6=27 [T t/620:50-59]; stepper CW=17, CCW=27 [T t/350:148,152].
  Doc §6/§10-item-10 already flag this correctly. Never concurrent (t/620 vs t/350,
  serial). Keep the existing warning; no change needed beyond line-cite refresh.

### K6 — GPIO18 over-subscribed (PWM/servo/interrupt/ADS-A0/generic) → **ACCEPTED-TIMESHARE** (already documented)
- Doc §7/§10-item-3 already capture this with the load-bearing "no external pull /
  no load" rule [T t/213:121,152]. Keep; refresh line cites only.

### K7 — GPIO13 harness comment vs asserted state → **pre-existing inconsistency** (out of pin-relief scope)
- Comment says "OUTPUT/HIGH due to dpot (t/445)" but asserted `state=0` in all three
  RPiTest tables [:454/:489/:526]. Doc §10-item-6 already reports it accurately. Not a
  pin conflict; leave the report in place, refresh cites. (Not something this plan resolves.)

## Reconciliation summary

- **Defects: 0.** Nothing here is a software bug; the serial, gated, self-cleaning
  suite keeps every shared role apart.
- **Doc-errors to fix in V4–V6: K1 (radar/26 note), K3/D1 (dpot A2), K4 (TFT
  8/23/24/25 — the big one), plus K2 (0x68 note) and the D2 line-cite refresh.**
- **Accepted timeshares (keep, refresh cites): K5, K6, K7.**
- **Relief candidate carried to V7: K1** (move radar default off GPIO26 → GPIO7).
