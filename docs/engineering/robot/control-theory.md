# Robot — control theory (complementary filter + PID)

Companion to [robot.md](robot.md). The control math is platform-independent, so
it is ported faithfully from the [reference design](https://smnbajwa.github.io/selfbalancingrobot/)
with the constants retuned on this hardware. Implemented in Perl in V2 (angle) and
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
- The `0.9996/0.0004` split is tuned for the reference's loop rate; if this loop
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

Standard PID, **dt-normalized** — a deliberate departure from the reference (F2,
explained below):

```perl
my $error = $angle - $balance_setpoint - $drive_setpoint;

# integral: accumulate the TERM (gain folded in), normalized by measured dt
$i_term += $Ki * $error * $dt;
$i_term  = clamp($i_term, -400, 400);        # anti-windup — clamp the term itself

# derivative: normalized by dt (low-pass it if noisy; don't shrink Kd instead)
my $d_term = $Kd * ($error - $prev_error) / $dt;

my $output = $Kp * $error + $i_term + $d_term;
$output    = clamp($output, -400, 400);      # actuator limit
$prev_error = $error;

# dead-band: don't fight tiny errors (kills buzz/oscillation at balance)
$output = 0 if abs($output) < $deadband;

# $output -> wheel velocity command (sign = lean-into-fall direction);
# §3's slew clamp then bounds how fast the commanded step rate may change
$drive->balance_command($output);
```

**Why dt-normalized (F2).** The reference runs its PID inside a fixed 4 ms ISR, so
it can fold dt into the gains (`integral += error`, `Kd·(error − prev_error)`). Here
the loop period wobbles (userspace Linux), and `Kd` is the dominant gain — in the
un-normalized form every scheduling wobble directly modulates the D term, and the
I term accumulates per-*iteration* rather than per-*second*. Normalizing by the
measured `$dt` makes the gains time-true at any loop rate. Two fidelity notes: the
reference clamps the accumulated integral **term** (its `pid_i_mem` already
contains the gain), which the code above preserves — clamping a raw Σerror at ±400
instead would let the I contribution reach ±400·Ki; and if the derivative is noisy,
filter it (e.g. a 1-pole low-pass on `$d_term`) rather than shrinking `Kd`.

**Starting constants** (the reference's values **converted to dt-normalized form**
at its 4 ms tick — a *starting point*, retune in V8):

| Term | Symbol | Start | Conversion | Meaning |
|------|--------|-------|------------|---------|
| Proportional | `Kp` | 15 | unchanged | stiffness — how hard it resists tilt |
| Integral | `Ki` | 375 /s | 1.5 ÷ 0.004 s | removes steady-state lean; windup-prone |
| Derivative | `Kd` | 0.12 s | 30 × 0.004 s | damping — anticipates, kills oscillation |
| Output clamp | | ±400 | — | matches the reference's motor command range |
| Dead-band | | tune | — | suppress buzz when essentially balanced |

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

**Acceleration (slew) limiting — mandatory, not a tuning discovery (F3).** A
stepper is synchronous: the commanded rate *is* the rotor speed, and the hardware
PWM will happily jump 200 Hz → 8 kHz in a single register write. Available torque ×
(rotor + wheel) inertia bounds the acceleration the motor can actually track;
command a bigger per-tick jump and it desyncs — torque collapses, the robot falls,
and it presents as inexplicable bad tuning. So the controller clamps the per-tick
change of each wheel's commanded step rate: `|Δf| ≤ f_accel_max · dt`, where
`f_accel_max` (steps/s²) is measured on the bench in V3 (steepest clean spin-up
ramp, wheels fitted if possible since their inertia counts, then take margin). At
100 Hz ticks a controller-side clamp yields 10 ms-granularity ramps — sufficient;
the V3 velocity driver needs no internal ramping.

## 4. Physical design — CoM height sets the difficulty

Balancing difficulty is set by **how high the centre of mass (CoM) sits above the
wheel axle**, because the robot is an inverted pendulum whose fall time-constant is

```
τ ≈ √(L / g)      L = CoM height above the axle
```

Counterintuitively, **taller is easier** (broomstick-on-palm vs. pencil-on-palm): a
higher CoM falls slower, giving the loop more ticks to react — which directly buys
margin against the Perl-loop jitter V1 measures. A low/flat robot falls faster and
demands a faster, lower-jitter loop and quicker motor response.

| CoM (L) | τ | at 100 Hz | verdict |
|---|---|---|---|
| 5 cm | 71 ms | ~7 samples/τ | tight — avoid |
| 8 cm | 90 ms | ~9 samples/τ | snappy but fine |
| **10 cm** | **101 ms** | **~10 samples/τ** | **target** |
| 12 cm | 111 ms | ~11 samples/τ | very forgiving |
| 15 cm+ | 124 ms+ | — | tippy; needs heavy ballast + more motor torque |

**Aim for CoM ≈ 9–11 cm** for first balance; trim toward 8 cm later for a snappier
response.

### Mass model (this build: NO battery, Pi is off-robot)

Only a light control board (A4988s + MPU6050, cabled to the off-robot Pi) rides the
chassis, so the **two NEMA17s (~480 g) at the axle dominate the mass and anchor the
CoM down**. With the battery and Pi gone, there is nothing heavy up top — **the top
shelf exists purely as a ballast platform, and ballast is now mandatory, not
optional.** (No ballast → even a 30 cm mast only reaches ~5 cm CoM.)

Lumping on-robot mass — low (at axle, L≈0): 2× NEMA17 480 g + bottom shelf 57 g +
board 6 ~50 g + wheels & hubs ~90 g ≈ 677 g; rods ~85 g at H/2; top shelf 57 g +
ballast W at height H:

```
L = H · (100 + W) / (819 + W)      H in cm, W = top ballast in grams, L in cm
```

Ballast needed to hit a target CoM (**1/4″ ply shelves**, 3/16″ threaded-rod
standoffs):

| Rod height H (axle→top shelf) | Ballast for CoM 8 cm | for 9 cm | for 10 cm |
|---|---|---|---|
| 20 cm (8″)  | ~380 g | ~490 g | ~620 g |
| **25 cm (10″)** | ~240 g | ~305 g | **~380 g** |
| 30 cm (12″) | ~160 g | ~210 g | ~260 g |

**Recommended: 25 cm rod + ~380 g ballast → CoM ≈ 10 cm, τ ≈ 100 ms**, total robot
~1.2 kg (30 cm rod + ~260 g reaches the same CoM for less ballast). On torque, stay honest (F4): 33 N·cm is *holding* torque — usable torque at
recovery speeds is roughly ⅓–½ of that and falls further with speed at 12 V, so
expect a **modest capture envelope** (measured, not assumed, in V8), plan to derate
the A4988s to ~0.8–0.9 A/phase thermally even with heatsinks, and treat B3 (DRV8825)
as the escape hatch if the envelope proves too tight. A taller mast now costs
nothing (no battery to keep low) and roughly halves the ballast vs. a 20 cm mast.

### Practical build notes

- **Tunable ballast = the CoM tuning knob.** Since the top shelf is held by 3/16″
  threaded rod, stack steel nuts/washers (or a bolt-on plate) on the studs above the
  shelf, and leave ~3–4 cm of extra stud. During V8, washers are added/removed to
  move the CoM empirically — start heavy/high (easy), lighten as confidence grows. No rebuild.
- **Spread the 4 rods in a wide rectangle**, not clustered — a floppy mast adds a
  flexible resonant mode the balancer will fight, and makes the IMU read mast wobble
  instead of true body tilt.
- **Mount the MPU6050 low and rigid** on the bottom shelf near the axle (reads the
  rigid base; less tangential-acceleration artifact during body rotation).
- **Tether discipline (Pi off-robot).** The cable must not inject a disturbance
  force: route it slack from *above* with strain relief so cable tension never pulls
  the chassis. Keep it **short** — I2C (MPU6050) and STEP edges degrade over length;
  ≤ ~50 cm is safe, longer needs an I2C buffer / dropping to 100 kHz. Keep motor-power
  conductors separated from / twisted away from the I2C + STEP signal lines to avoid
  coupling motor-current spikes into them. See [bill-of-materials.md](bill-of-materials.md).
- Mass assumptions (NEMA17 ~240 g ea, 1/4″ ply shelf ~57 g, printed wheel ~24 g +
  hub ~10 g + tread) are estimates — weigh actuals; because ballast is tunable the
  design is robust to these being off.
- **1/4″ ply is through-bolted, never wood-screwed**: M4×20 + fender washers both
  faces + nyloc for the motor brackets, and a fender washer under every rod nut so
  the clamp doesn't crush the thinner ply. Ballast stacks on the rod studs, so its
  load path is the rods — top-deck thickness is structurally near-irrelevant.

## 5. Tuning procedure (V8)

1. All gains 0. Bring up the angle estimate; confirm sign (lean forward → error
   of the expected sign). Fix any inversion in software, not by rewiring.
2. Raise **`Kp`** until the robot reacts to tilt and just begins to oscillate.
3. Add **`Kd`** to damp that oscillation — the robot should settle rather than
   ring.
4. Add a little **`Ki`** to remove residual lean/drift; keep it small and keep
   the integral clamp — this is the windup-prone term.
5. Trim **`balance_setpoint`** so it sits still without creeping either way.
6. Set the **dead-band** just wide enough to stop the at-rest buzz.
7. Iterate hand-caught (V8) before balancing under a slack overhead tether (V9).
   Log angle + P/I/D terms every tick and tune from the logs, not by eye alone.

## 6. Startup, self-park & auto-erect

Powered off, the robot tips until it rests on a **front or back extender pole** —
low, ~2″ outriggers that double as bi-directional bump-stops. Sized so the **rest
lean sits inside the capture envelope** (§4; measured in V8), recovery is *not* a
swing-up — it's ordinary balancing from a known small offset, which the steppers
handle fine. **Keep the rest angle small: mount the poles LOW (near ground) and reach
them out.** Height dominates: a pole at axle height parks it ~40° (outside the
envelope — bad); the *same* pole mounted low parks it ~10° (inside — good).

### Which way is it leaning? — the accelerometer, absolutely

The **gyro gives only rate**, so at power-up it has no orientation reference. The
**accelerometer gives an absolute tilt from the gravity vector**, and resting on a
pole the robot is dead still — the *best-case* condition for the accel (its only
weakness, linear-acceleration/vibration noise, is absent at rest). Startup sequence:

1. `calibrate_gyro` while still on the pole — zeroes the gyro *rate* bias; this is
   orientation-independent, so being tilted doesn't spoil it.
2. Read `$mpu->tilt` → **absolute signed pitch. Sign = which pole** (e.g. +pitch →
   front pole, −pitch → back); magnitude = the lean. (Axis + sign pinned in V2.)
3. **Seed the complementary filter with it:** initialise `$angle = $accel_pitch`,
   *do not* start at 0. Starting at 0 while actually leaning ~10° makes the
   controller act on a wrong angle until the 0.04 % accel term slowly drags the
   estimate to truth — many ticks of bad commands right when it matters most.
4. Enter the PID loop. `error = angle − setpoint` already carries the right sign, so
   the wheels drive *toward* the lean, the body rotates up off the pole, and it
   settles vertical (the pole lifts clear). No discrete "which pole" logic — the
   signed angle is all the controller needs.

### Sanity gate (safety)

Before enabling motors, check the seeded angle is a *sane pole-rest* value: erect
only if `|angle|` is within `[envelope_min … expected_rest + margin]`. If it reads
~0° it's already upright (just balance); if it's too large the pole failed / it fell
flat — **stay disabled and flag it** rather than attempt the impossible from-flat
recovery. This makes power-cycling safe for an unattended test-platform tenant.

### Park switches — electrical confirmation (board 6)

The park stops are instrumented: a **lever microswitch** at each stop (fore/aft),
wired **NC, common → GND**, into the board-6 MCP23017's GPB6/GPB7 with the
internal pull-ups enabled. NC is deliberate — a broken or unplugged switch reads
as a deterministic fault, not a silent "not pressed". **The lever is the sensor
only**: a hard stop (the rest mechanics) carries the park load and impact; the
lever just gets pressed at rest. Slotted switch mounts make the rest angle
tunable against the V8-measured envelope. Polling is per control tick (or every
few) over the I2C already in the loop; debounce = 2–3 agreeing reads.

The startup gate becomes a two-source cross-check:

| Fore | Aft | Accel reads | Action |
|------|-----|-------------|--------|
| pressed | open | ≈ +rest° | Erect off the front stop |
| open | pressed | ≈ −rest° | Erect off the back stop |
| open | open | ≈ 0° | Already upright — balance |
| open | open | large lean | Fell flat / off the bench — stay disabled, flag |
| pressed | pressed | anything | Wiring/mechanical fault — stay disabled |
| any switch/accel disagreement | | | Stay disabled, flag (sensor-disagreement safety, same philosophy as B1) |

Two bonuses: the switch *opening* during erection is a clean lift-off event for
tuning, and after a tilt-cutoff kill the expected sequence is "a switch closes
within ~a second" = parked safe — if neither closes, the robot went somewhere it
shouldn't have.
