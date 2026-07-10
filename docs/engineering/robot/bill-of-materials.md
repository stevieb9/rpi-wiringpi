# Robot — bill of materials, inventory mapping & wiring

Companion to [robot.md](robot.md). Maps every part to what you **already own**
(per the naranja `rpi-tracker` inventory + the `RPi::` distributions) and what
still has to be **procured**. Pinout is a starting proposal to finalise at V7.

## What you already own (no purchase)

### From the naranja inventory table

| Part | Owned | Spec (as inventoried) | Robot role |
|------|-------|-----------------------|------------|
| NEMA17 Stepper Motor Kit | **6** | 1.0 A/phase, 33 N·cm holding, 1.8°/step (200 steps/rev), bipolar; ~2.8 V rated coil | 2 used — the two wheels |
| A4988 Stepper Driver Carrier | **10** | Allegro A4988, up to ~2 A/coil w/ cooling, MS1–3 microstep select, VREF current limit; 8–35 V VMOT, 3–5.5 V logic | 2 used — one driver per wheel |
| ADS1015 ADC | 1 (board-2 device) | 12-bit I2C ADC @ 0x48 | battery pack voltage sense |
| MPU-6050 | (drives `RPi::Gyro::MPU6050`) | 6-axis accel+gyro, I2C 0x68/0x69 | the balance sensor |
| Raspberry Pi | this host family | — | the brain (runs the Perl) |

> The inventory lists **6 motors and 10 drivers** — plenty of spares for bench
> work, and headroom to break one without stalling the project.

### From the Perl distributions (the software BOM)

| Distro | Ver | Connected today? | Robot role |
|--------|-----|------------------|------------|
| `RPi::Gyro::MPU6050` | 0.01 | **No** — connect here | tilt + angular rate |
| `RPi::StepperMotor::A4988` | 0.01 | **No** — connect + extend (V3) | wheel drivers |
| `RPi::Accelerometer::ADXL335` | 0.01 | **No** | optional redundant tilt (backlog B1) |
| `RPi::ADC::ADS` | 1.04 | yes | battery telemetry |
| `RPi::WiringPi` | 3.1803 | yes | board/GPIO umbrella (provides `pin()` for A4988) |
| `RPi::Pin` | 3.1803 | yes | per-pin objects |
| `RPi::I2C` | 3.1803 | yes | I2C bus (MPU + ADS) |
| `RPi::Const` | 1.07 | yes | HIGH/LOW/mode constants |

The three "No" rows are the distributions we built but never connected — the
robot is what connects them. (They're absent from the `rpi-tracker` `dists`
table today; V10 makes them first-class prereqs of the robot app, so they start
showing up.)

## What must be procured (gaps — not in inventory)

| Part | Why | Notes |
|------|-----|-------|
| **Chassis** — 2 plywood/acrylic tiers + 4× ¼" threaded rod + standoffs | frame for the inverted pendulum | reference used plywood for vibration damping; keep CoM high for a gentler, slower fall |
| **2× wheels + motor hubs** (5 mm bore for NEMA17 shaft) | the actual wheels | rubber-tyred for traction |
| **L-brackets / NEMA17 mounts (×2)** | fix motors low on the frame | |
| **Battery — 3S LiPo (11.1–12.6 V)** + connector/strap | VMOT for the steppers | sized above the ~2.8 V rated coil; A4988 current-limits |
| **5 V buck / BEC** | Pi supply from the pack | Pi needs a clean 5 V, separate from motor rail |
| **2× resistors for a voltage divider** | scale pack V into the ADS1015's input range | pick ratio so full pack < ADS FSR at the chosen gain |
| **Dot/proto PCB + headers** | solder the driver + divider (reference dropped breadboards — vibration) | |
| **2× ~100 µF caps across VMOT** | protect each A4988 from LC voltage spikes | **required by the A4988** — never hot-plug VMOT without it |
| Heatsinks for the A4988s | thermal headroom at balancing currents | |
| Jumper wire, screws (#4-40 per reference), zip ties | assembly | |

## Proposed wiring / pinout (finalise at V7)

BCM numbering. The A4988 driver takes its `pin()` objects from an `RPi::WiringPi`
instance (its `new()` requires a `pi` object exposing `pin($n)`). MPU + ADS share
the I2C bus.

### I2C bus (shared)

| Signal | Pi pin | Device |
|--------|--------|--------|
| SDA | BCM 2 (phys 3) | MPU-6050 (0x68) + ADS1015 (0x48) |
| SCL | BCM 3 (phys 5) | " |
| 3V3 | 3V3 | MPU + ADS Vcc (3.3 V logic) |
| GND | GND | common ground (Pi + drivers + pack must share GND) |

### A4988 — LEFT wheel (proposed GPIO)

| A4988 pin | Pi BCM | Notes |
|-----------|--------|-------|
| STEP | 17 | pulse train (rate = speed) |
| DIR | 27 | direction |
| ENABLE | 22 | active-low; drop to kill motors (safety) |
| MS1 / MS2 / MS3 | 5 / 6 / 13 | microstep select (all-or-none per the distro) |
| RESET ↔ SLEEP | tie together, or to a GPIO | must be high to run |
| VMOT / GND | pack + / GND | **100 µF cap across here** |
| VDD / GND | 3V3 / GND | logic supply |
| 1A/1B/2A/2B | NEMA17 (L) coils | verify coil pairs before power-up |

### A4988 — RIGHT wheel (proposed GPIO)

| A4988 pin | Pi BCM | Notes |
|-----------|--------|-------|
| STEP | 23 | |
| DIR | 24 | |
| ENABLE | 25 | active-low |
| MS1 / MS2 / MS3 | 12 / 16 / 20 | |
| (RESET/SLEEP/VMOT/VDD/coils) | as left | separate 100 µF cap |

> The two MS triples can instead be tied to fixed levels (jumpers) if we don't
> need software microstep changes — then pass the matching `mode` to the distro
> so the step math stays correct. Decide at V3/V7.

### Battery sense (ADS1015)

| Node | Connection |
|------|------------|
| Pack + → Rtop → sense node → Rbot → GND | classic divider |
| sense node | ADS1015 AIN0 |
| divider ratio | chosen so max pack voltage < ADS full-scale at the configured gain |

## Power topology

```
  3S LiPo (11.1–12.6 V) --+--> VMOT (both A4988s, each with 100 µF)
                          |
                          +--> 5 V buck --> Raspberry Pi 5 V
                          |
                          +--> divider --> ADS1015 AIN0 (telemetry)

  All grounds common: pack GND == Pi GND == A4988 GND == ADS GND.
```

- Set each A4988 **VREF current limit** to the NEMA17's 1.0 A/phase (or a touch
  under) *before* the motor ever moves — this is a screwdriver + multimeter step,
  not software.
- Keep the motor rail and the Pi's 5 V physically separate downstream of the
  pack; only grounds are common. Stepper current spikes must not brown out the Pi.
