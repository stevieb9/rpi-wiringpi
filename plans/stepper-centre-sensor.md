# Stepper homing + centre sensor — design decision (2026-06-19)

Picking this up tomorrow (2026-06-20). Context for the `t/450` stepper test rig.

## The core problem
The 28BYJ-48 is **continuous-rotation — there is NO physical limit / endstop**.
Nothing mechanical will ever stop a runaway, so **software must bound every move**
or a failed seek drives the motor forever (coil/driver heat, wear). The bounded
seek is therefore the *entire* safety system, not a nicety.

## Decision: centre detection via laser + photoresistor on a DIGITAL MCP23017 pin
**No ADC.** A laser pointed at an LDR gives near-binary contrast (lit ≈ few kΩ,
dark ≈ tens of kΩ+), so a digital threshold is enough — we only need "at centre /
not", not an analog level.

Circuit (one free pin on the **0x21 stepper expander**, e.g. GPB0):

```
   +3V3 ──[ LDR ]──┬── MCP23017 input pin   (internal pull-up OFF / GPPU=0)
                   │
                  [ R ]        R ≈ sqrt(R_lit * R_dark) ~ 5–10 kΩ; tune on bench
                   │
                  GND
```
Lit → node toward 3V3 → **HIGH = at centre**. Dark → LOW. Pull-up must be off
(it would parallel/skew the divider). Size R so only the laser (not ambient)
pushes it across ~½·VDD.

## Architecture: MIX — keep everything, add the centre sensor
| Piece | Role |
|---|---|
| **Centre LDR + laser** (new, digital MCP23017 pin) | Direct, absolute base position. Replaces "compute centre from span". |
| **`seek_limit` bounded seek** (`t/StepperSeek.pm`) | Runaway safety — load-bearing because the motor has no physical limit. Already built + unit-tested. |
| **Magnetic CW/CCW switches** (GPIO17/27) | The timing-test targets (the passes time travel-to-magnet). Keep. |
| **`home_target` decision** (`t/StepperSeek.pm`) | Out-of-bounds + re-centre decision. Built + unit-tested. |

The laser changes *how we find centre* (sense vs compute), not whether we need
the bound or the magnetic switches.

## TODO (next session)
1. **Harden the failure mode (independent of hardware):** on a homing
   out-of-bounds, `t/450`'s `home()` must **de-energize the coils**
   (`$sm->cleanup` / drive expander pins LOW) **and `BAIL_OUT`** the whole suite
   — "stop dead", not the current soft-skip. (User requirement; NOT yet done.)
2. **When the LDR/laser is wired:** pick the free 0x21 pin, configure it INPUT
   with pull-up off, and retarget `home()`'s seek so `at_limit` reads that
   expander pin: `sub { $exp_stepper->read_pin($centre_pin) }`. Bounded-seek
   safety is unchanged; drop the "compute centre from span" interim.
3. **Docs/schematic:** add the one centre LDR (passive divider + an existing
   expander pin) to `gen-schematic.py` + the test-platform docs. **No ADS1115
   returns** — stays ADC-free.
4. Retire the manual "centre the motor before testing" ritual once homing works.

## Current code state (all uncommitted)
- `t/StepperSeek.pm` — `seek_limit()` (bounded primitive) + `home_target()`
  (decision + re-centre math). Callback-injected so it's hardware-free testable.
- `t/451-stepper-seek.t` — 26 unit tests, all pass: bound hit/no-hit, boundaries,
  out-of-bounds homing, re-centre math, arg validation.
- `t/450-stepper.t` — `home()` currently computes centre from the measured span
  (interim); seeks both magnetic limits. Switches to the LDR centre per TODO #2.
  Failure path still soft-skips — see TODO #1.
