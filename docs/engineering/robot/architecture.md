# Robot — system architecture

Companion to [robot.md](robot.md). This is the engineering "why". The reference
design is the [smnbajwa self-balancing robot](https://smnbajwa.github.io/selfbalancingrobot/);
this document adapts it to a Raspberry Pi driven entirely by Perl and by the
in-house `RPi::` distributions.

## Reference vs. this build

| Concern | Reference (smnbajwa) | This build |
|---------|----------------------|-----------|
| Brain | Arduino Nano (AVR, bare-metal, Timer2 ISR @ 50 kHz) | Raspberry Pi, **Perl** on Linux |
| IMU | MPU-6050 (I2C) | MPU-6050 via **`RPi::Gyro::MPU6050`** (I2C) |
| Drive | 2 motors + 2× A4988 | 2× **NEMA17** + 2× **A4988** via **`RPi::StepperMotor::A4988`** |
| Angle | complementary filter (`0.9996`/`0.0004`) | complementary filter, ported — see [control-theory.md](control-theory.md) |
| Control | PID P=15 I=1.5 D=30, clamp ±400 | same coefficients as a **starting point**, retuned on this platform |
| Step timing | hardware timer ISR | **RP1 hardware PWM** as the step clock, driven from an XS layer (Pi 5; see the ladder below) |
| Power/compute | onboard, battery | **off-robot & tethered** — Pi + bench supply reach the chassis over an umbilical; no battery (see [robot.md](robot.md)) |

The reference's control *math* is kept (it's platform-independent), as are its
*sensor and driver ICs* (already in inventory). What fundamentally differs is the
execution substrate: a hard-real-time AVR ISR vs. a Perl process on a
time-shared Linux kernel. That difference is the whole risk, and it is confined
to one place: step-pulse generation.

## Block diagram

```
                +---------------- off-robot Raspberry Pi (Perl) --------------+
                |                                                             |
   MPU-6050 --- I2C ---> RPi::Gyro::MPU6050 --> angle estimator (comp. filter)|
   (0x69)       |                                        |                    |
                |                                         v                    |
                |                                  PID controller             |
                |                                  (setpoint = upright)        |
                |                                         |                    |
                |                                         v                    |
                |                              two-wheel drive module         |
                |                              /                    \         |
                |     RPi::StepperMotor::A4988 (L)      RPi::StepperMotor::A4988 (R)
                +----------------|--------------------------------|-----------+
                ================ | ====== umbilical / tether ===== | ==========
                            STEP/DIR/EN/MS                    STEP/DIR/EN/MS
                                 |                                |
                            A4988 (L) --coils--> NEMA17 (L)   A4988 (R) --coils--> NEMA17 (R)
                                 \__________ VMOT (bench supply) ___________/
```

The MPU's I2C, both A4988s' STEP/DIR/EN/MS, and the 3V3 logic + VMOT rails **all
cross the tether** — the entire chassis is passive silicon; the brain and the power
are off-board. Keep the umbilical short (I2C/STEP integrity) and slack (no
disturbance force); see [control-theory.md](control-theory.md) §4 and
[bill-of-materials.md](bill-of-materials.md).

Software layering (each layer only knows the one below it):

```
  bin/balance  (CLI: calibrate | balance | drive | status)
        |
  Balance controller ....... complementary filter + PID  (control-theory.md)
        |
  Two-wheel drive .......... drive(linear, angular) -> per-wheel velocity
        |
  A4988 velocity driver .... non-blocking "set step-rate"  (extends the distro, V3)
        |
  RPi::WiringPi / RPi::Pin / RPi::I2C  ...... GPIO + bus primitives
```

## Real-time reality check (the crux — read before building anything)

A two-wheel inverted pendulum is open-loop unstable: it falls in a few hundred
milliseconds. To hold it up the loop must **sense → decide → actuate** fast and
*regularly*. Two distinct timing demands:

1. **Control-loop rate** — read IMU, run the filter + PID, update motor targets.
   The reference does this at ~250 Hz (4 ms). Realistically the loop needs on the
   order of **100 Hz with bounded jitter**. This part is *plausibly* fine in Perl: an
   I2C burst read of the MPU plus float math is sub-millisecond of real work; the
   question is scheduler jitter, not throughput.

2. **Step-pulse generation** — a stepper turns by receiving discrete STEP pulses;
   wheel *speed* is the pulse *rate*. Balancing continuously varies each wheel's
   speed (including sign) every control tick. So the drive needs a **smooth, high-rate,
   continuously-retargetable pulse train per wheel**. On the AVR this is a timer
   ISR. On the Pi in Perl it is the hard problem, because:
   - the current `RPi::StepperMotor::A4988->step($count)` **blocks** — it busy-loops
     `_pulse` `$count` times, so it cannot run the control loop and drive both
     wheels concurrently at continuously-changing rates;
   - toggling GPIO from a userspace Perl loop is subject to kernel scheduling
     jitter, which shows up as torque noise the controller must fight.

### Two jitter sources — and why "just rewrite it in C" only fixes one

The pulse-train jitter has **two independent causes**, and they do not share a fix:

1. **Interpreter / per-pulse overhead** — Perl op-dispatch, method calls, and the
   GPIO-write path executed on *every* pulse cap the achievable step rate low.
   **C/XS fixes this** — a compiled loop is orders of magnitude faster.
2. **Kernel scheduler preemption** — a stock Linux kernel can take the CPU away
   mid-pulse-train for milliseconds. **C/XS does *not* fix this by itself**:
   compiled userspace code is preempted exactly like interpreted code, so a C
   busy-loop is *faster* but still *glitches* under preemption. A glitch is a
   pause in the pulse train → a velocity dip → torque noise the controller fights.

So the real question isn't "C or Perl" — it's **"where does the pulse *timing*
come from?"** If it comes from a CPU loop (C or Perl), it is preemptible. If it
comes from a hardware timing peripheral, it is not.

### This platform: Raspberry Pi 5 (BCM2712 / RP1) — confirmed capabilities

- **Hardware PWM present:** `pwmchip0`, **4 channels** — enough to clock *both*
  wheel STEP lines with zero CPU involvement. Changing wheel speed = writing a
  frequency register; changing direction = the DIR GPIO. This is the jitter-free
  path for pulse *emission*; its **low-frequency reach and live-retarget
  semantics** are the open questions V1 answers (see the decision rule below).
  (Channel→GPIO mapping needs a `pwm` device-tree overlay; confirm the two
  channels land on pins next to the A4988 STEP inputs — a V1/V7 wiring detail.)
- **GPIO libraries:** `lgpio` + `libgpiod v3` are installed. **`pigpio` is not** —
  and its classic DMA-waveform trick does **not** work on the Pi 5's RP1 anyway,
  so the "pigpio waves" idea from the first draft is **off the table on Pi 5**.
  The RP1 hardware PWM replaces it.

### The stepping-architecture ladder (V1 measures where it lands)

Every rung stays "code in Perl" — the XS/C, where used, only implements the
non-blocking step generator that Perl commands; the PID/filter stay Perl.

| Rung | Approach | Jitter | Effort | Verdict |
|------|----------|--------|--------|---------|
| **A** | Pure-Perl blocking `step()` bursts (today) | bad | none | baseline / likely marginal |
| **A′** | **C/XS** bit-bang (compiled pulse loop) | better, not solved | med | raises step rate; still preemptible |
| **A″** | C/XS bit-bang **+ `SCHED_FIFO` on an isolated core** (`isolcpus` + `mlockall`) | good | med | robust; costs 1 of the 4 cores |
| **B** | **C/XS driving the RP1 hardware PWM** as the step clock | **solved** | med-high | the real fix — hardware emits the train, Perl sets the rate |
| C | Offload inner loop to a microcontroller (the reference's Arduino) | solved | high | **out of scope** — violates the Perl-on-Pi mandate; only if A″ *and* B both fail |

**C/XS is the *mechanism*, not a rung of its own:** it's how Perl reaches A′/A″/B.
The family already ships XS (`WiringPi::API` wraps the wiringPi C lib; `RPi::ADC::ADS`
is XS), so this is in-idiom, not a new toolchain.

**Decision rule:** V1 benches A, A′, and B — sustained control-loop rate,
per-iteration jitter (max + p95), and max clean step rate per approach — with the
control loop under `SCHED_FIFO` + CPU affinity in every rung (bench what would
actually run; cheap insurance even for rung B). Prefer the **lowest rung that
clears ~100 Hz control with bounded jitter and enough step rate for the wheel
geometry**. Expectation: **B (hardware PWM)** is the target; A″ is the fallback if
the PWM routing or low-end behavior proves awkward.

**The low end is pass/fail too (F1).** At balance the commanded wheel speed hovers
near zero and crosses through it every few ticks, so for rung B three low-end
behaviors gate alongside raw rate:

1. **Minimum step frequency + resolution near zero** — verify the RP1 PWM's
   range/divider actually reaches arbitrarily low step rates (read the RP1
   datasheet and the `pwm-rp1` driver; do not assume register width).
2. **Glitch-free retargeting on a live channel** — a period write must latch at
   the next period boundary, not via disable/re-enable. A runt STEP pulse shorter
   than the A4988's minimum STEP width (datasheet ~1 µs — re-verify at the bench)
   is a missed step; a spurious edge is a ghost step.
3. **Zero-speed discipline** — stop = **duty 0 % with the channel left enabled**
   (constant-low line, no enable churn); a DIR flip async to the free-running
   clock costs at most one microstep — negligible, but decided here, not
   discovered later.

**Record the actual numbers and the chosen rung back in this table** when V1
completes — left blank until then:

| Metric (from V1) | A (Perl) | A′ (C bit-bang) | B (HW PWM) |
|------------------|----------|-----------------|------------|
| Sustained control-loop rate | _TBD_ | _TBD_ | _TBD_ |
| Loop jitter (max / p95) | _TBD_ | _TBD_ | _TBD_ |
| Max clean step rate | _TBD_ | _TBD_ | _TBD_ |
| Min clean step rate / resolution near 0 | n/a (CPU-timed) | n/a (CPU-timed) | _TBD_ |
| Live retarget (boundary-latch vs runt pulses) | n/a | n/a | _TBD_ |
| Zero-speed (duty-0) + DIR-flip handling | n/a | n/a | _TBD_ |

**Chosen rung:** _TBD (record the winner + reason here when V1 completes)._

## Coordinate & sign conventions

- **Pitch** (fore/aft lean) is the balancing axis. `RPi::Gyro::MPU6050->tilt`
  returns `($pitch, $roll)` in degrees, `0` when the board lies flat
  component-side up; pitch positive when the `+X` end tips up. Mount the MPU so
  its `+X` points forward — pin down the exact axis/sign empirically in V2 and
  record it, because it sets the sign of the whole control law.
- **Setpoint** is the upright pitch angle (the balance point), which is *not*
  necessarily 0° — it depends on the centre of mass and is trimmed during tuning
  (the reference's `self_balance_pid_setpoint`).
- **Drive sign**: a positive PID output leans-into-the-fall, i.e. drives both
  wheels in the direction the top is tipping. Left/right motors mount as mirror
  images, so one wheel's "forward" is the other's reversed DIR — handled once in
  the two-wheel drive module (V4).

## Failure & safety posture

- **Tilt cutoff** (V9): past ±N° from upright the robot cannot recover — disable
  both A4988 `ENABLE` lines immediately rather than let the motors thrash.
- **Tether integrity**: the umbilical must hang slack — a taut or snagged cable
  injects a disturbance force the controller can't distinguish from a real tilt.
  Route it from above with strain relief; a yanked tether should trip the same
  ENABLE-drop kill as a tilt cutoff.
- **Integral windup**: clamp the PID integral and the total output (reference
  clamp ±400) so a stall doesn't accumulate an unrecoverable command.
- **Clean disable on exit**: any controlled shutdown drops `ENABLE` so the robot
  doesn't lurch when the process dies.
