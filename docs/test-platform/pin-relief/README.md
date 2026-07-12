# GPIO pin audit & relief — analysis

The test-grounded working analysis behind the plan
`plans/gpio-pin-audit-and-relief.md`. Every fact is tagged **[T]** (proven in a
test, `file:line`), **[L]** (submodule/facade default), or **[F]** (non-test /
hardware convention); unknowns are flagged, never guessed. The narrative results
are folded into `../test-pinout-doc.md` and `../test-board-matrix.md` — these files
are the detailed evidence base and the strategy options.

## Read in this order

1. **[pin-inventory.md](pin-inventory.md)** — every hardware-touching test decoded to
   its devices, Pi BCM pins, bus, I2C address and env gate (incl. the newer
   TFT/radar/gyro/ADXL335/A4988/PCA9685/I2C-LCD devices). The raw audit.
2. **[gpio-occupancy.md](gpio-occupancy.md)** — the 28-pin (BCM 0–27) occupancy table
   with FREE / SINGLE / SHARED-safe / CONFLICT classification, plus the
   conflict/shared-net reconciliation (0 defects — the serial, self-cleaning suite
   keeps every shared role apart).
3. **[pin-relief-strategies.md](pin-relief-strategies.md)** — the full evaluation of
   pin-freeing options (R1–R8): pins freed, mechanism, cost, coverage impact,
   feasibility, citations; ranked shortlist. Scope: board re-wiring allowed.
4. **[pin-relief-recommendation.md](pin-relief-recommendation.md)** — the short
   recommendation (R1+R2+R3 ≈ +5 low-risk pins; R4/R5 optional) and the three
   decisions that are the user's to make (A: R2 coverage, B: how far, C: verify-first).

## The options at a glance

| | Strategy | Header pins freed | Risk |
|---|---|---|---|
| **R1** | Radar default off GPIO26 → GPIO7 | 0 (resolves the only conflict) | ~0 |
| **R2** | Board-5 parallel LCD → PCF8574 I2C backpack | **4** (4/5/6/22) + un-share 17/27 | LOW* |
| **R3** | Stepper centre LED (GPIO19) → MCP23017 | 1 | LOW |
| **R4** | TFT BLK/RES (23/24) → expander / tie-off | up to 2 | MED |
| **R5** | Stepper limits (17/27) → expander INT | 2 | MED-HIGH |
| R6/R7/R8 | 74HC595 relocate / hardware-CE consolidate / GPIO0-1 | — | reject / low value |

\* R2's only cost is a coverage decision (keep or drop the native-GPIO 4-bit LCD path,
`t/620`) — see Decision A in the recommendation.

Implementation is a separate, user-gated phase — nothing here is implemented.
