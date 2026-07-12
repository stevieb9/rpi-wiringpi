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

> **Revised 2026-07-12 (user decision):** the parallel LCD stays on native GPIO — it exists
> to test wiringPi's native parallel `lcd_init` path — so **R2 is rejected** and its 6 pins
> (4/5/6/17/22/27) are irreducible by design. That removes ~80% of the earlier estimate.

| | Strategy | Header pins freed | Risk |
|---|---|---|---|
| **R3** | Stepper centre LED (GPIO19) → 0x21 MCP23017 (your own lib) | **1** | LOW — the one clean fabbed-board win |
| **R1** | ✅ **DONE (interim)** — radar default off GPIO26 → GPIO7 (bench), in t/361 | 0 (resolves the only conflict) | ~0 |
| **R4** | TFT BLK/RES (23/24) → expander / tie-off (**bench only**) | up to 2 | MED |
| **R2** | Parallel LCD → expander/backpack | — | ❌ REJECTED (tests the native path) |
| **R5** | Stepper limits (17/27) → expander INT | 0 | ⊘ MOOT (LCD keeps 17/27) |
| R6/R7/R8 | 74HC595 relocate / hardware-CE consolidate / GPIO0-1 | — | reject / low value |

Realistic fabbed-board relief is **~+1 pin (R3)** plus clearing the GPIO26 conflict (R1) —
the platform is near-fully-subscribed on purpose. Implementation is a separate, user-gated
phase — nothing here is implemented.
