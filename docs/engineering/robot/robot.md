# Plan: robot — a self-balancing two-wheel robot, in Perl, on the Raspberry Pi

> **NEXT ACTION:** V1 — real-time feasibility spike (bench, no chassis): measure the fastest jitter-bounded control-loop rate achievable in Perl while reading `RPi::Gyro::MPU6050` and pulsing `RPi::StepperMotor::A4988`, then record a go/no-go + the stepping-architecture decision.
> **LAST SESSION:** 2026-07-11 — **architecture pivot: the robot is now permanently tethered.** The Pi lives *off-robot* (control + power over an umbilical), there is **no on-robot battery**, and the rig will eventually become a tenant of the unit-test platform. Consequences worked through and cleaned across all docs: dropped battery telemetry (**V6 retired**) and the on-robot LiPo/buck; reworked power to a bench supply over the tether; reframed V9 from "free-standing" to "balance under a compliant overhead tether"; recorded the CoM-height/ballast design (control-theory.md §4 — `L = H·(127 + W)/(785 + W)`; recommend ~25 cm rod + ~300 g tunable ballast → CoM ≈ 10 cm) for the no-battery mass model; logged **Fix 1** (the V1 `pwm-2chan` overlay *permanently* regresses `t/107`/`t/108` on GPIO12/13 now that the robot co-habits the test-platform Pi). Prior session (2026-07-10): plan created; real-time approach resolved to **Architecture B** (C/XS driving RP1 hardware PWM); solder-once wiring map written. No code yet.
> **ARCHIVE:** See robot-archive.md for completed V tasks

## What we are building

A **self-balancing, two-wheel inverted-pendulum robot** — the [reference project](https://smnbajwa.github.io/selfbalancingrobot/) rebuilt on **your** infrastructure: a Raspberry Pi, **written entirely in Perl**, driven by **your own `RPi::` distributions**. The reference runs on an Arduino Nano; we run on the Pi. The reference uses DC motors; we use the **NEMA17 steppers + A4988 carriers you already own** (6× and 10× per the naranja inventory) — which is the well-proven *B-robot / JJRobots* stepper-balancer architecture and a better fit than DC for precise, encoder-free velocity control.

**This build is permanently tethered.** The Pi stays *off-robot* and drives the chassis over an umbilical (I2C to the MPU, GPIO/PWM to the A4988s); motor and logic power come over that same cable from a bench supply — there is **no on-robot battery and no on-robot Pi**. Only a light control board (the two A4988s + the MPU-6050) rides the frame. The end goal is for this balancing rig to become a permanent tenant of the **unit-test platform** (its own device-gated tests + board designation, like the other boards), not a portable free-roaming robot. It still actively self-balances — the tether supplies power and compute, never mechanical support. Low front/back **extender poles** let it park at a small lean when powered off and **auto-erect on power-up** (it reads its lean from the accelerometer and stands up off the pole — see [control-theory.md](control-theory.md) §6), so it's a hands-off, power-cycle-safe test-platform tenant rather than something you must hand-stand each time.

This project is also the **integration vehicle** for three distributions we built but never connected to anything:

| Distro | Version | Role in the robot |
|--------|---------|-------------------|
| `RPi::Gyro::MPU6050` | 0.01 | The balance sensor — tilt angle (accel) + angular rate (gyro) |
| `RPi::StepperMotor::A4988` | 0.01 | The two wheel drivers — **extended** here with a non-blocking velocity mode (XS + RP1 hardware PWM, per V1/V3) |
| `RPi::Accelerometer::ADXL335` | 0.01 | Optional redundant tilt cross-check (backlog, not required) |

plus already-connected family members it consumes: `RPi::WiringPi`, `RPi::Pin`, `RPi::I2C`, `RPi::Const`. (An earlier draft also consumed `RPi::ADC::ADS` for battery telemetry — dropped now that the rig has no on-robot battery.)

## The one honest risk, stated up front

A stepper balancer needs a **fast, low-jitter** control loop *and* **continuous, smoothly-updated step-pulse trains** on both wheels. Userspace Perl under Linux is not a hard-real-time environment, and today's `RPi::StepperMotor::A4988->step($count)` is a **blocking, busy-looped** call — the wrong shape for balancing, which needs "set wheel velocity now, keep pulsing in the background, change it next tick." The jitter has two causes: interpreter overhead (a **C/XS** rewrite fixes this) and kernel scheduler preemption (C/XS alone does *not*). The identified fix on this **Pi 5 (RP1)** is to stop timing pulses on the CPU at all: a thin **C/XS layer driving the RP1 hardware PWM** (`pwmchip0`, 4 channels — enough for both wheels) as the step clock, with Perl only setting the rate. The control law (PID + filter) stays Perl. **V1 measures this before a single chassis part is cut** and picks the rung from data — see [architecture.md](architecture.md) §"Real-time reality check". We do not promise a balancing robot until V1 confirms the timing holds.

## Phases

- **P0 Feasibility & sensing** (V1–V2) — measure real-time headroom; get a trustworthy tilt angle. *Gate: build no hardware until V1 passes.*
- **P1 Motor subsystem** (V3–V4) — non-blocking velocity stepping; two-wheel coordination.
- **P2 Control** (V5) — complementary filter + PID controller (software dry-run). *(Battery telemetry dropped — no on-robot battery; former V6 retired.)*
- **P3 Build & balance** (V7–V9) — chassis + tether wiring; bring-up + tuning; balance under a compliant overhead tether.
- **P4 Package** (V10) — ship the robot as a proper Perl app that connects the leaf distros.

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of robot-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
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
| V1 | **P0 — feasibility spike (bench, NO chassis).** Prereq: apply the `pwm-2chan`+`audio=off` config from [bill-of-materials.md](bill-of-materials.md) and reboot (needed to bench rung B). Bench the stepping-architecture ladder ([architecture.md](architecture.md)) on this Pi 5 (RP1): for each of **A** pure-Perl blocking bursts, **A′** C/XS bit-bang, and **B** C/XS driving the RP1 hardware PWM (STEP on GPIO12) as the step clock — measure (a) sustained control-loop rate, (b) per-iteration jitter (max/p95), (c) max clean step rate before pulses smear. Pick the lowest rung clearing ~100 Hz with bounded jitter; expect **B**, fall back to **A″** (C bit-bang + `SCHED_FIFO`/isolated core) if PWM→GPIO routing is awkward. `pigpio` is out on Pi 5. Record numbers + chosen rung in [architecture.md](architecture.md). | bench scripts under `docs/engineering/robot/spikes/`; **V1 bench minimum** = MPU6050 on I2C + **one** A4988 (STEP→GPIO12, DIR/EN/RESET-SLEEP, VMOT+cap, VDD) + one NEMA17 | Numbers captured for A/A′/B; a rung chosen from data that clears ~100 Hz with bounded jitter (or a documented reason none can) | ⏳ |
| V2 | **P0 — trustworthy tilt angle.** On the (off-robot) control Pi: `calibrate_gyro`, confirm `tilt`/`gyro`/`accel` read sanely, then write `angle estimator` (complementary filter fusing accel-derived tilt with integrated gyro rate, per [control-theory.md](control-theory.md)). Validate estimator output against known static angles (flat, ±known tilt on a jig). | `prove -l t/*angle*.t` + a manual tilt-jig check | Estimator tracks true angle within a few degrees, no drift over ~60 s, no lag spikes | ⏳ |
| V3 | **P1 — non-blocking velocity drive.** Extend `RPi::StepperMotor::A4988` with a continuously-updatable **velocity** mode: set target step-rate (incl. sign) that keeps pulsing in the background without blocking the caller. Implement per the V1-chosen rung — expected an **XS layer driving the RP1 hardware PWM** as the step clock (in-idiom: the family already ships XS via `WiringPi::API`/`RPi::ADC::ADS`); DIR stays a GPIO. Preserve the existing blocking `step()` API. Unit tests for the new surface; bench-spin one NEMA17 at commanded, reversible rpm. | `cd ~/repos/rpi-steppermotor-a4988 && prove -l t/` + bench spin | New velocity API green; motor holds commanded speed + reverses while the Perl control loop keeps running (no stall) | ⏳ |
| V4 | **P1 — two-wheel coordination.** A drive module that owns both A4988s (mirror-image mounting handedness handled), exposing `drive(linear, angular)` → per-wheel velocities. Bench both NEMA17s: same-direction (drive), opposite (spin). | `prove -l t/*drive*.t` + bench both motors | Both wheels obey linear+differential commands; handedness correct | ⏳ |
| V5 | **P2 — balance controller (software dry-run, NO motion).** Port the complementary-filter + PID loop (start P=15 I=1.5 D=30, output clamp ±400, dead-band — [control-theory.md](control-theory.md)) into a Perl controller. Run with the robot **held**: log angle, P/I/D terms, and the motor command that *would* be sent; motors disabled. | `perl bin/balance --dry-run` (logs only) | Controller produces sane, sign-correct commands as the robot is hand-tilted; no runaway integral | ⏳ |
| V7 | **P3 — chassis + tether wiring build.** Build the 2-tier frame (3/8″ ply + 3/16″ threaded-rod standoffs) to the CoM/ballast spec in [control-theory.md](control-theory.md) §4 (≈25 cm rod, ~300 g tunable ballast on top → CoM ≈ 10 cm) and wire it per the **verified solder-once map** in [bill-of-materials.md](bill-of-materials.md) (STEP→GPIO12/13, the full pin tables, checklist: coil-pair ID, VMOT caps, RESET-SLEEP tie, VREF limit). NEMA17s low; only the control board (2× A4988 + MPU) on the frame; the off-robot Pi + bench supply reach it over the umbilical (power/signal separated). **Procurement-gated** (chassis/wheels/tether not yet owned — see BOM gaps). | Continuity check against the pin tables + `i2cdetect -y 1` | Every net matches the map; 100 µF caps + VREF set before motors; MPU (0x68) enumerates over the tether; ballast sets CoM ≈ 10 cm | ⏳ |
| V8 | **P3 — tethered balance bring-up + auto-erect.** With the robot tethered/hand-caught, close the loop (V5 controller → V4 drive), enable motors, and tune PID + dead-band (log-driven). **Measure the capture envelope** (max recoverable tilt), then fit the **front/back extender poles** (low + long) so the powered-off rest lean sits inside it, and verify **auto-erect on power-up** (accel-seeded startup + sanity gate — [control-theory.md](control-theory.md) §6). | `bin/balance` tethered | Robot resists tilt and holds upright; capture envelope recorded; from a pole-rest power-up it erects to vertical unaided | ⏳ |
| V9 | **P3 — sustained balance under a slack tether + safety.** Balance with the umbilical hanging slack from above (bearing no load); retune; add a tilt-cutoff kill (disable motors past ±N°) and a clean shutdown. The front/back extender poles are the **physical bi-directional fall-stops** — past the cutoff it leans on a pole (to re-catch on the next power-up), not crashes flat. | `bin/balance` with a compliant overhead tether | Holds upright ≥ 30 s with the tether slack (not supporting it); tips past cutoff → motors cut, leans on a pole, no thrash | ⏳ |
| V10 | **P4 — package it.** Wrap the robot as a proper Perl app (dist `App::RPi::Robot` or agreed name) that formally depends on and **connects** the leaf distros; config file, `robot` CLI (`calibrate`/`balance`/`drive`/`status`), logging. Decide the code home (new repo vs. subdir) — see Open decisions. | `perl Makefile.PL && make && make test` in the robot dist | Buildable dist; CLI runs; leaf distros are now first-class prereqs (visible in rpi-tracker) | ⏳ |

## Discovery Tracking

Fix 1: discovered during V1 prep — **the V1 prereq reboot regresses the shared `rpi-wiringpi` test suite.** The prereq `dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4` re-muxes GPIO12/13 to the RP1 PWM funcsel at boot. The suite hard-codes (in `t/RPiTest.pm` `rpi_default_pin_config()`, pi5 branch) that pins 12/13 idle at **alt 31** ("no function"), and `rpi_check_pin_status()` — run **ungated** by `t/107-alt_modes.t` and `t/108-mode_state_all_pins.t`, plus the cleanup sweeps — asserts `get_alt(12)==31` / `get_alt(13)==31`. After the reboot those return the PWM funcsel, so **107/108 (and possibly 150-cleanup) fail on 12/13**. This bites because the robot and the test platform **share THIS Pi** (`bill-of-materials.md` "verified for THIS Pi 5"). Confirmed clean today: `pinctrl get 12,13,18` shows all three as `none`/31. **Pin 18 is unaffected** (BOM remaps PWM off the overlay's default 18/19; `audio=off` doesn't move 18 on Pi 5). Wiring the hardware alone is benign (A4988 inputs are hi-Z → mode checks unaffected; I2C pull-ups on 2/3 already assumed) — only the overlay breaks tests. **FIX:** make the pi5 branch of `rpi_default_pin_config()` overlay-aware — when `pwm-2chan` is active on 12/13, expect the PWM funcsel instead of 31, gated so non-overlay Pis still expect 31 (same per-board pattern already used for the pin-13 dpot / pin-12/26 CS special-cases). Cross-plan: the fix lives in the **test-platform-release-master** repo (`t/RPiTest.pm`); resolve alongside V1's reboot. **Now permanent (not a workaround):** the robot co-habits the test-platform Pi for good (permanently tethered, destined to become a test-platform board), so the `pwm-2chan` overlay is a *standing* config — the overlay-aware fix is mandatory, and GPIO12/13 join the roster of test-platform-managed pins (alongside the pin-13 dpot / 12-26 CS special-cases).

## Open decisions (resolve as they come up; defaults chosen so work isn't blocked)

- **Stepping architecture (the A→B ladder).** Decided empirically by V1 ([architecture.md](architecture.md)). On this Pi 5 (RP1) the target is **B**: a **C/XS layer driving the RP1 hardware PWM** (`pwmchip0`, 4 ch) as a jitter-free step clock, with Perl setting the rate — C/XS is the *mechanism* that lets Perl reach the hardware, not a rewrite of the control law (PID/filter stay Perl). Fallback **A″**: C/XS bit-bang on a `SCHED_FIFO` isolated core. Plain C/XS bit-bang (**A′**) fixes interpreter overhead but *not* scheduler jitter, so it's a rung, not the destination. `pigpio` DMA waves are **out on Pi 5**. **C** (microcontroller co-processor) stays out unless A″ *and* B both fail — the mandate is "code in Perl".
- **Robot code home.** Default: a **new dedicated distribution** `App::RPi::Robot` in a new `~/repos/app-rpi-robot` repo (keeps the robot app separate from the `App::RPi::Umbrella` monitoring tool and from the core `RPi::WiringPi` dist). These engineering docs stay here under `rpi-wiringpi/docs/engineering/robot/`. Confirm the dist name at V10.
- **Power (tethered — resolved).** No on-robot battery. Motor VMOT (~12 V) comes from a bench DC supply over the umbilical; A4988 logic 3V3 + MPU power + all signals come from the off-robot Pi over the same tether; grounds common. Size the tether's motor conductors for stepper current and keep them separated from the I2C/STEP signal lines. Confirm the supply + cable at V7.

## Backlog

B1: `RPi::Accelerometer::ADXL335` as a redundant/independent tilt cross-check against the MPU6050 (sensor-disagreement safety).

B2: Remote control / steering — feed a `(linear, angular)` setpoint over the network (leverage the family's existing web/IPC patterns) so the balanced robot can be driven.

B3: DRV8825 driver upgrade (finer microstepping, higher current headroom) as a drop-in for the A4988s if torque/heat limits balancing.

B4: Wheel-position/velocity feedback (stepper step-counting as a soft encoder) for position hold + drift correction.

B5: Live telemetry dashboard — stream angle / PID terms to a browser for tuning.

## Explicitly NOT doing

- **DC motors** — the reference uses them, but we own NEMA17 steppers + A4988; steppers are the proven, encoder-free balancer drive. No reason to buy DC motors.
- **A microcontroller co-processor (the reference's Arduino)** — the explicit mandate is Perl on the Pi. Only reconsidered if V1 proves both pure-Perl architectures (A and B) cannot balance.
- **Dist::Zilla / cloud CI for the robot app** — hardware-coupled like the rest of the `RPi::` family; follows family convention (EUMM + Dist::Mgr, on-Pi testing), not the `App::RPi::Umbrella` pure-Perl CI model.
- **Rewriting the leaf distros** — we *connect* and (for A4988) *extend* them; we do not rewrite working code.
- **On-robot battery + battery telemetry (was V6)** — the rig is permanently tethered and runs on a regulated bench supply over the umbilical, so there is no pack to monitor and no discharge risk. `RPi::ADC::ADS` is no longer a robot-consumed distro. V6 is retired and its number will not be reused.
- **Untethered / free-roaming operation** — the Pi and power are permanently off-robot; the umbilical is the design, not a bring-up crutch. "Balancing" is demonstrated under a slack overhead tether (V9), never battery-powered and self-contained.
