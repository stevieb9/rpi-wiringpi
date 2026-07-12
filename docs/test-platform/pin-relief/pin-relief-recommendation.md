# V8 — Final recommendation & decisions

Synthesis of V7 (`pin-relief-strategies.md`). Analysis only — nothing implemented;
implementation is a separate, user-gated phase.

## The one-paragraph read

The header is full because most pins are spent *deliberately* testing Pi-native
features (I2C/SPI buses, UART, hardware PWM + native interrupts, software SPI-CS,
GPIO shift-register). Those are the irreducible floor. Almost all the *reclaimable*
GPIO is in one place: the **board-5 parallel LCD** (6 pins), which duplicates a
`RPi::LCD` transport already covered zero-GPIO by the **I2C LCD** (t/335). Converting
it, moving the stepper's indicator LED to the expander that's already on that board,
and relocating the radar's default off a live CS pin gets you from **1 free pin to
~6** with little or no coverage loss. Pushing further (TFT/limit-switch relocation)
adds ~4 more but trades test coverage or needs driver work.

## Recommended (do these — biggest win, lowest risk)

- **R1 — radar default off GPIO26** → GPIO7. One-line test change; ends the only live
  conflict. Do it regardless.
- **R2 — board-5 LCD parallel → PCF8574 I2C backpack.** Frees GPIO **4/5/6/22** and
  un-shares 17/27. ~80% of the total win. Requires the board re-wire you've approved.
- **R3 — stepper centre LED (GPIO19) → MCP23017** already on board 3. Frees **19**.

Net: **~+5 header pins**, header no longer over-subscribed, no bus/feature coverage lost
(subject to Decision A).

## Optional (more pins, real trade-offs)

- **R4 — TFT BLK/RES (23/24) off the header** (+2): needs TFT-driver expander support
  *or* accepting loss of backlight()/reset coverage.
- **R5 — stepper limits (17/27) → expander INT** (+2): test rework; trades native
  `background_interrupt` coverage.

## Reject / low value
- **R6** 74HC595 relocation (guts the shift-register-over-GPIO test), **R7** hardware-CE
  consolidation (only 2 CE lines, CE0 is the TFT's, Pi 5 `SPI_NO_CS` limitation),
  **R8** GPIO0/1 (reserved, no fixture).

## Decisions only you can make

- **A — R2 coverage:** drop `t/620` and accept **I2C-only** LCD coverage, OR keep `t/620`
  by moving its parallel lines onto an MCP23017 (preserves the native-4-bit path, costs
  one expander, still frees the header pins)?
- **B — how far:** stop at the low-risk set (**R1+R2+R3, ~5 pins**), or also pursue
  **R4/R5** (~9–10 pins total) accepting the coverage/rework trades?
- **C — verify-first:** before committing to R4/R5/(R6), should I resolve the do-not-guess
  flags F-a…F-d (driver expander-pin support, INT rework)? Each is a small spike.

## If you green-light implementation
Each accepted strategy becomes a new V-task (this plan's V1–V8 were audit + docs +
strategy only, per its "Explicitly NOT doing"). Natural order: R1 (trivial) → R3 →
R2 (with Decision A) → any of R4/R5 after their verify spikes.
