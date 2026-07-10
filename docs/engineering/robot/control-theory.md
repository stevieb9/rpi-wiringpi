# Robot — control theory (complementary filter + PID)

Companion to [robot.md](robot.md). The control math is platform-independent, so
we port it faithfully from the [reference design](https://smnbajwa.github.io/selfbalancingrobot/)
and retune the constants on our hardware. Implemented in Perl in V2 (angle) and
V5 (PID).

## 1. Angle estimation — complementary filter

Neither sensor alone gives a usable angle:

- The **accelerometer** senses gravity, so it gives an *absolute* tilt angle —
  but only while at rest; every bump and every motor jerk shows up as noise.
  `RPi::Gyro::MPU6050->tilt` returns exactly this: `($pitch, $roll)` in degrees
  from the static gravity vector.
- The **gyroscope** gives a clean *angular rate*, immune to linear acceleration —
  but integrating rate to angle **drifts** without bound. `RPi::Gyro::MPU6050->gyro`
  returns the rate in °/s (offset-corrected once `calibrate_gyro` has run).

The **complementary filter** fuses them: trust the gyro for fast motion, lean on
the accelerometer to cancel long-term drift. The reference uses:

```
angle = 0.9996 * (angle + gyro_rate * dt) + 0.0004 * accel_angle
```

i.e. a 99.96 % / 0.04 % blend each tick. In Perl, per control cycle:

```perl
# once, at startup:
$mpu->calibrate_gyro;              # zero the gyro offsets while still

# each control tick (dt = seconds since last tick):
my ($pitch_acc, undef) = $mpu->tilt;      # absolute tilt from gravity (deg)
my $rate  = $mpu->gyro('x');              # deg/s about the balancing axis
$angle = 0.9996 * ($angle + $rate * $dt)  # integrate gyro ...
       + 0.0004 * $pitch_acc;             # ... nudged toward the accel truth
```

Notes:
- Pick the gyro **axis** that matches the pitch/balancing axis — confirm the
  axis *and* sign empirically in V2 and record it in [architecture.md](architecture.md).
- `dt` must be the *measured* elapsed time per loop, not a constant — Perl loop
  timing varies (see the real-time discussion). Feeding a real `dt` keeps the
  integration honest even when the loop rate wobbles.
- The `0.9996/0.0004` split is tuned for the reference's loop rate; if our loop
  runs slower, the effective time constant shifts — treat these two as tunables,
  not sacred constants.

## 2. Balance control — PID

The controller drives the estimated angle to the **upright setpoint** by
commanding wheel velocity. Error is the angle deviation:

```
error = angle - balance_setpoint - drive_setpoint
```

- `balance_setpoint` — the true upright angle (centre-of-mass dependent, *not*
  necessarily 0°); trimmed during tuning. This is the reference's
  `self_balance_pid_setpoint`.
- `drive_setpoint` — a deliberate lean injected to make the robot travel (0 while
  just balancing; non-zero when driving — backlog B2).

Standard PID:

```perl
my $error = $angle - $balance_setpoint - $drive_setpoint;

$integral += $error;
$integral  = clamp($integral, -400, 400);   # anti-windup

my $output = $Kp * $error
           + $Ki * $integral
           + $Kd * ($error - $prev_error);

$output    = clamp($output, -400, 400);      # actuator limit
$prev_error = $error;

# dead-band: don't fight tiny errors (kills buzz/oscillation at balance)
$output = 0 if abs($output) < $deadband;

# $output -> wheel velocity command (sign = lean-into-fall direction)
$drive->balance_command($output);
```

**Starting constants** (reference values — a *starting point*, retune in V8):

| Term | Symbol | Start | Meaning |
|------|--------|-------|---------|
| Proportional | `Kp` | 15 | stiffness — how hard it resists tilt |
| Integral | `Ki` | 1.5 | removes steady-state lean; windup-prone |
| Derivative | `Kd` | 30 | damping — anticipates, kills oscillation |
| Output clamp | | ±400 | matches the reference's motor command range |
| Dead-band | | tune | suppress buzz when essentially balanced |

## 3. From PID output to step rate

The PID output is an abstract command; the wheels need a **step rate**. Higher
`|output|` → faster pulses → more corrective torque; the sign sets DIR. On the Pi 5
that step rate is expected to be a **hardware-PWM frequency** (Architecture B —
[architecture.md](architecture.md)): the controller writes a frequency per wheel
each tick and the RP1 PWM peripheral clocks the pulses out jitter-free, so the
Perl loop never busy-waits on pulses. The mapping from `output` to steps/second
is calibrated on the bench in V3/V4 and is where microstep resolution and the
achievable pulse rate (V1) actually bite — the reference applies a *nonlinear*
compensation here because step torque falls off with speed. Expect to shape this
curve during tuning, not to get it right first try.

## 4. Tuning procedure (V8)

1. All gains 0. Bring up the angle estimate; confirm sign (lean forward → error
   of the expected sign). Fix any inversion in software, not by rewiring.
2. Raise **`Kp`** until the robot reacts to tilt and just begins to oscillate.
3. Add **`Kd`** to damp that oscillation — the robot should settle rather than
   ring.
4. Add a little **`Ki`** to remove residual lean/drift; keep it small and keep
   the integral clamp — this is the windup-prone term.
5. Trim **`balance_setpoint`** so it sits still without creeping either way.
6. Set the **dead-band** just wide enough to stop the at-rest buzz.
7. Iterate tethered (V8) before free-standing (V9). Log angle + P/I/D terms every
   tick and tune from the logs, not by eye alone.
