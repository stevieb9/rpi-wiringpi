# V8 — Final recommendation & decisions

Synthesis of V7 (`pin-relief-strategies.md`). Analysis only — nothing implemented;
implementation is a separate, user-gated phase.

> **REVISED 2026-07-12 (user decision):** the board-5 **parallel LCD stays on native
> GPIO** — its purpose is to test wiringPi's native parallel `lcd_init` path, which
> moving it to any expander/backpack would delete. So **R2 is rejected** and its 6 pins
> (4/5/6/17/22/27) are irreducible by design. The I2C-LCD path is covered separately by a
> PCF8574 LCD (t/335) sited elsewhere. This removes ~80% of the previously-estimated
> relief; the sections below are the revised picture.

## The one-paragraph read

This test platform is **near-fully-subscribed on purpose.** Almost every header pin is
spent deliberately testing a Pi-native library feature — the I2C/SPI buses, UART, hardware
PWM + native interrupts, the software SPI chip-selects, the GPIO shift-register, and the
**parallel LCD**. That's the irreducible floor. With the parallel LCD confirmed as
irreducible, the only genuinely reclaimable *fabbed-board* pin is the stepper's indicator
LED (GPIO19); the rest of the movable stuff is on the bench devices.

## Recommended

- **R3 — stepper centre LED (GPIO19) → the 0x21 MCP23017** (board 3, 12 free pins).
  Frees **GPIO19**. Works through your **own** `RPi::GPIOExpander::MCP23017` (a plain
  `$exp->write` — an LED is one digital output, so none of the wiringPi-C-`lcd_init`
  problem that kills the LCD idea applies). The stepper test already builds that expander.
  Negligible coverage change. **The one clean win.**
- **R1 — radar default off GPIO26 → GPIO7** (bench). ✅ **IMPLEMENTED 2026-07-12
  (interim)** in `t/361` (default 26→7, + INPUT-mode and cleanup-restore asserts).
  Resolves the only live pin conflict (radar OUT vs MCP3008 CS). Permanent home =
  MCP23017 expander input (radar rework, backlog), which frees GPIO7.

Net fabbed-board gain: **~+1 pin** (GPIO19), plus the GPIO26 conflict cleared.

## Optional / bench-only
- **R4 — TFT BLK/RES (23/24) off the header** (bench, +2): needs the TFT driver to accept
  expander pins for `bl`/`rst` (verify F-a) or tying BLK/RES off (drops that coverage).
  Doesn't help the fabbed-board budget.

## Rejected / moot / low value
- **R2** parallel LCD relocation — **rejected** (tests the native path by design).
- **R5** stepper limits off 17/27 — **moot** (the LCD keeps 17/27 anyway).
- **R6** 74HC595 (guts the shift-register-over-GPIO test), **R7** hardware-CE consolidation
  (2 CE lines, CE0 is the TFT's, Pi 5 `SPI_NO_CS`), **R8** GPIO0/1 (reserved).

## Decisions only you can make
- **A — R3:** approve moving the centre LED (GPIO19) onto a 0x21 Bank-B pin via your
  MCP23017 library? (Frees the one reclaimable fabbed-board pin.)
- **B — R1:** change the radar's default pin off GPIO26 (to GPIO7) so it and the MCP3008
  can co-exist? Trivial.
- **C — R4 (bench):** worth trimming the TFT's header footprint (23/24) now, or leave it?

## The honest takeaway
The audit's real value turned out to be the **corrected docs + the confirmation that the
platform is intentionally near-full**, more than a big pin-harvest. The parallel-LCD
decision is the crux: keeping the native path (right call for coverage) costs 6 pins that
aren't coming back. R3 + R1 are the sensible, low-risk moves.

## If you green-light implementation
Each accepted item becomes a new V-task (this plan's V1–V8 were audit + docs + strategy
only). Order: **R1** (trivial) → **R3** → optionally **R4** after its F-a verify spike.
