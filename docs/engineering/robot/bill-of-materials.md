# Robot — bill of materials, inventory mapping & wiring

Companion to [robot.md](robot.md). Maps every part to what is **already in
inventory** (per the naranja `rpi-tracker` + the `RPi::` distributions) and what
still has to be **procured**. Pinout is a starting proposal to finalise at V7.

## Already in inventory (no purchase)

### From the naranja inventory table

| Part | Owned | Spec (as inventoried) | Robot role |
|------|-------|-----------------------|------------|
| NEMA17 Stepper Motor Kit | **6** | 1.0 A/phase, 33 N·cm holding, 1.8°/step (200 steps/rev), bipolar; ~2.8 V rated coil | 2 used — the two wheels |
| A4988 Stepper Driver Carrier | **10** | Allegro A4988, up to ~2 A/coil w/ cooling, MS1–3 microstep select, VREF current limit; 8–35 V VMOT, 3–5.5 V logic | 2 used — one driver per wheel |
| MPU-6050 | (drives `RPi::Gyro::MPU6050`) | 6-axis accel+gyro, I2C 0x68/0x69 | the balance sensor |
| Raspberry Pi | this host family | — | the brain — **off-robot**, drives the chassis over the tether |
| ADXL335 breakout | (drives `RPi::Accelerometer::ADXL335`) | analog 3-axis accel, 3V3; Cx/Cy/Cz filter caps on breakout | board-6 redundant tilt cross-check (B1) |
| ADS1015 breakout | (the bench ADS unit — re-homes to board 6) | 12-bit I2C ADC; **re-strap ADDR→VDD = 0x49** (0x48 = board-2 ADS1015); t/360 gains an address param | reads the ADXL335 X/Y/Z on board 6 |
| 2× lever microswitches | (purchased) | ~38 mm lever; **NC contact** used, common → GND | fore/aft park sensors → MCP23017 GPB6/7 ([control-theory.md](control-theory.md) §6) |

> The inventory lists **6 motors and 10 drivers** — plenty of spares for bench
> work, and headroom to break one without stalling the project.

### From the Perl distributions (the software BOM)

| Distro | Ver | Connected today? | Robot role |
|--------|-----|------------------|------------|
| `RPi::Gyro::MPU6050` | 0.01 | **No** — connect here | tilt + angular rate |
| `RPi::StepperMotor::A4988` | 0.01 | **No** — connect + extend (V3) | wheel drivers |
| `RPi::Accelerometer::ADXL335` | 0.01 | **No** — connect here | redundant tilt cross-check on board 6, read via the ADS1015 @ 0x49 (B1) |
| `RPi::WiringPi` | 3.1803 | yes | board/GPIO umbrella (provides `pin()` for A4988) |
| `RPi::Pin` | 3.1803 | yes | per-pin objects |
| `RPi::I2C` | 3.1803 | yes | I2C bus (MPU) |
| `RPi::Const` | 1.07 | yes | HIGH/LOW/mode constants |
| `RPi::ADC::ADS` | — | yes | the board-6 ADS1015 @ 0x49 (ADXL335 axes); battery-telemetry role stays dropped |

The three "No" rows are the distributions that were built but never connected — the
robot is what connects them. (They're absent from the `rpi-tracker` `dists`
table today; V10 makes them first-class prereqs of the robot app, so they start
showing up.)

## What must be procured (gaps — not in inventory)

| Part | Why | Notes |
|------|-----|-------|
| **Chassis** — 2× **1/4″** plywood tiers + 4× 3/16″ threaded rod + standoffs/nuts | frame for the inverted pendulum | build to the CoM/ballast spec in [control-theory.md](control-theory.md) §4 (~25 cm rod; rods in a wide rectangle for mast rigidity). 1/4″ ply is **through-bolted only** — no wood screws; fender washers under every rod nut |
| **~380 g ballast** — steel plate or stacked washers/nuts on the rod studs | raise CoM to ≈10 cm — **mandatory** (nothing heavy up top without a battery) | tunable during V8: add/remove washers; leave ~3–4 cm spare stud. (~260 g suffices if the rod goes to 30 cm — [control-theory.md](control-theory.md) §4) |
| **2× wheels + motor hubs** (5 mm bore for NEMA17 shaft) | the actual wheels | rubber-tyred for traction; **pick + record the diameter here before V1** (80–100 mm typical) — it sets the steps/s ↔ m/s mapping V1's step-rate thresholds derive from |
| **L-brackets / NEMA17 mounts (×2)** | fix motors low on the frame | 3D-printed: [3d/bracket.py](3d/bracket.py) → robot-motor-bracket.stl (print 2, same STL both sides; **PETG preferred** — steppers run warm and PLA creeps near 60 °C); shaft center 26.5 mm above deck; M4 base **slots** give ±5 mm fore-aft travel to make the two axles collinear |
| **Front + back extender poles** (~2″ outriggers), mounted **LOW** | self-park + auto-erect: park the robot at a small lean *inside the capture envelope*, and act as bi-directional fall-stops | mount near ground & reach out so the rest lean is ~10° (not ~40° at axle height); see [control-theory.md](control-theory.md) §6; set geometry against the V8-measured envelope |
| **Umbilical/tether cable + strain relief** | carries VMOT + logic 3V3 + I2C + STEP/DIR/EN/MS from the off-robot Pi & bench supply | gauge the motor pair for stepper current; keep it separated from the I2C/STEP lines; keep short (≤ ~50 cm) for signal integrity |
| **Bench DC supply (~12 V)** for VMOT | motor rail over the tether | replaces the on-robot LiPo; regulated + current-limited |
| **Dot/proto PCB + headers** | solder the two A4988s + MPU breakout onto the frame (reference dropped breadboards — vibration) | |
| **MCP23017 I2C expander** (robot's — strap A0/A1 for **0x23**) + 2× RESET-SLEEP pull-down resistors | hosts all 12 static driver lines (DIR/EN/RESET-SLEEP/MS) + the 2 park-switch inputs (GPB6/7) off-header — 14 of 16 pins; pull-downs keep the chassis inert-by-default; optionally also hosts the platform's two displaced CS lines (F5) | **not in inventory** (tracker-verified 2026-07-29); 0x20/21/22/27 taken on the shared bus |
| **J1 JST-PH 2-pos + J2 screw-terminal 2-pos** | board-6 power entry: 3V3 on J1, 12 V on J2 — both fed from board 1, **grounds commoned on board 1** | see [robot-board-power.jpg](robot-board-power.jpg) |
| **Bypass caps: 6× 0.1 µF ceramic + 1× 10 µF bulk** | per-IC bypass (MPU, MCP23017, ADS1015, ADXL335, 2× A4988 VDD) + 3V3-entry bulk | 0.1 µF values are datasheet-standard placeholders — confirm each at board-6 layout; the 2× 100 µF VMOT electrolytics are listed above and are mandatory |
| **2× ~100 µF caps across VMOT** | protect each A4988 from LC voltage spikes | **required by the A4988** — never hot-plug VMOT without it |
| Heatsinks for the A4988s | thermal headroom at balancing currents | |
| **Fasteners — M3** | 4× M3×8 SHCS wheel→hub flange (2 per wheel, opposite pair); 8× M3×8 motor→L-bracket (NEMA17 face pattern); M3 screws + standoffs board 6→deck | the whole build is metric — NEMA17, A4988 carriers, breakouts and the flange couplers are all M3. (#4-40 is 2.85 mm: it starts in an M3 hole and strips it — do not mix) |
| **Fasteners — M4** | 8× M4×20 through-bolts + fender washers (both faces) + nyloc nuts: L-bracket→deck | 1/4″ ply gets through-bolts, never wood screws |
| **Fasteners — misc** | M2.5 or M3 for the two microswitch mounts; nuts + fender washers for the 3/16″ threaded rod (deck clamping + ballast stack) | switch mounts **slotted** so the park angle is tunable ([control-theory.md](control-theory.md) §6); the rod is the one imperial family and is self-contained |
| Jumper wire, zip ties, threadlocker | assembly; threadlocker on the hub set screws | |

## Wiring — exact connections (verified for THIS Pi 5 / RP1)

> ⛔ **MAP SUPERSEDED — robot.md F5 rev 2 (2026-07-29). Do NOT solder yet.**
> The 2026-07-10 check only proved the pins *read* free with `pinctrl` at idle —
> bit-banged CS and LCD nets idle as inputs, so they read `none` while claimed:
> GPIO12/13/26 carry the DAC/dpot/ADC chip-selects (t/410, t/445) and
> GPIO5/6/17/22/27 the board-5 LCD (t/620) — though the routing lives in bench
> jumpers + the unbuilt board 1, never in satellite copper. Per F5 rev 2 the
> **STEP rows below stand** (the robot keeps GPIO12/13; the platform vacates them
> by moving both CS lines to expander-hosted pins), while **every other control
> row is superseded** — DIR/EN/RESET-SLEEP/MS move to the robot's MCP23017 @ I2C
> 0x23. The board-6 successor wiring is now drawn in
> [robot-board-schematic.jpg](robot-board-schematic.jpg) +
> [robot-board-power.jpg](robot-board-power.jpg); redraw these tables from those
> sheets when F5 closes. BCM (GPIO) numbering throughout; physical header pin
> in parens.

### The one rule that must not be broken

The two **STEP** lines carry the hardware-PWM step clock (Architecture B). On the
Pi 5 the RP1 exposes PWM on the 40-pin header at **only**:

- **PWM0 → GPIO12** (phys 32) — `Alt0` / `func=4`
- **PWM1 → GPIO13** (phys 33) — `Alt0` / `func=4`

(GPIO18/19 carry the RP1's other PWM channel pair, but the platform needs them:
18 is the t/400 hardware-PWM sweep → ADS#1 A0 plus the servo pin, and 19 the
stepper rig's centre LED.) **Left STEP → GPIO12, Right STEP → GPIO13 —
reaffirmed by F5 rev 2:** they're the only PWM pair the platform can vacate, and
it vacates them by moving the DAC/dpot CS lines to expander-hosted pins (bench
jumpers + board-1 routing — no fabbed-board changes). Everything else
(DIR/EN/MS/RESET/SLEEP) leaves the header entirely for the robot's MCP23017 @
I2C 0x23; STEP can only live on the header's PWM-capable pins.

### Reserved pins routed around (already claimed on this Pi)

I2C1 `GPIO2/3` · SPI0 `GPIO7–11` · UART0 `GPIO14/15` · 1-Wire `GPIO4` (w1-gpio).
The map below avoids all of them.

### I2C bus — MPU-6050 (bus `/dev/i2c-1`, over the tether)

| Signal | Pi pin (phys) | To |
|--------|---------------|----|
| SDA1 | GPIO2 (phys 3) | MPU-6050 SDA |
| SCL1 | GPIO3 (phys 5) | MPU-6050 SCL |
| 3V3 | phys 1 | MPU Vcc (3.3 V logic) |
| GND | phys 9 | MPU GND |
| MPU `AD0` | → 3V3 | selects address **0x69** — 0x68 is the board-4 DS3231's fixed address, and the platform's MPU already runs at 0x69 (t/358); see F5 |

*(The ADS1015 @ 0x48 is a board-2 device already on this shared bus, not part of the
robot — the robot no longer uses it. See robot.md "Explicitly NOT doing".)*

### A4988 — LEFT wheel

| A4988 pin | Pi pin (phys) | Notes |
|-----------|---------------|-------|
| **STEP** | **GPIO12 (phys 32)** | **PWM0 — do not move** |
| DIR | GPIO5 (phys 29) | direction |
| ENABLE | GPIO6 (phys 31) | active-low; drive LOW = motor on, HIGH = off (safety kill) |
| MS1 | GPIO16 (phys 36) | microstep select |
| MS2 | GPIO20 (phys 38) | " |
| MS3 | GPIO21 (phys 40) | " |
| RESET **tied to** SLEEP | GPIO26 (phys 37) | one wire to both pads; must be HIGH to run |
| VDD | 3V3 (phys 17) | logic supply |
| GND (logic) | GND (phys 34) | |
| VMOT | supply +12 V | **100 µF cap VMOT→GND right here** |
| GND (motor) | supply GND | |
| 1A / 1B | NEMA17-L coil A | one identified coil pair |
| 2A / 2B | NEMA17-L coil B | the other coil pair |

### A4988 — RIGHT wheel

| A4988 pin | Pi pin (phys) | Notes |
|-----------|---------------|-------|
| **STEP** | **GPIO13 (phys 33)** | **PWM1 — do not move** |
| DIR | GPIO23 (phys 16) | |
| ENABLE | GPIO24 (phys 18) | active-low |
| MS1 | GPIO17 (phys 11) | |
| MS2 | GPIO22 (phys 15) | |
| MS3 | GPIO27 (phys 13) | |
| RESET **tied to** SLEEP | GPIO25 (phys 22) | |
| VDD | 3V3 (phys 17) | shares the Pi 3V3 rail with the left driver |
| VMOT / GND | supply +12 V / GND | **its own 100 µF cap** |
| 1A/1B / 2A/2B | NEMA17-R coils | identify pairs (below) |

Spare GPIO left over: GPIO18 (phys 12, only if audio disabled) and GPIO19 (phys 35).

## Config the pins need (apply at V1 — requires a reboot; documented now so it's ready)

Add to `/boot/firmware/config.txt`:

```
# STEP clocks: PWM0 on GPIO12, PWM1 on GPIO13 (Alt0 = func 4)
dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4
# Free both PWM channels from the onboard audio, which otherwise claims them
dtparam=audio=off
```

I2C is already enabled (`dtparam=i2c_arm=on`). After reboot, expect a `pwmchip`
under `/sys/class/pwm/` exporting 2 usable channels — that's what the V3 XS driver
targets. *(This is a config step for V1/V7, not soldering — listed here so the
electrical plan is complete.)*

> ⚠️ **This overlay regresses the shared `rpi-wiringpi` test suite** — see robot.md
> Discovery Tracking **Fix 1**. It re-muxes GPIO12/13 off alt 31, which `t/107` and
> `t/108` assert as the Pi-5 default, so those tests fail on 12/13 until `t/RPiTest.pm`
> is made overlay-aware. Robot and test platform share THIS Pi, so this fires the
> moment of the V1 reboot.
>
> ⛔ **F5: never apply this overlay while the DAC/dpot CS jumpers sit on 12/13.**
> The PWM's duty-0 idle drives both **active-low** CS lines LOW = both chips
> permanently selected, clocking garbage from any unrelated SPI0 traffic. Per F5
> rev 2 the overlay **stays on 12/13** (STEP reaffirmed there); the precondition
> is moving the bench CS jumpers to their expander-hosted homes (or detaching
> board-2's circuits) first.

## Power topology (tethered — no on-robot battery)

> **Board-6 power entry (2026-07-30):** 3V3 arrives on **J1 (JST-PH pair)** and 12 V
> on **J2 (screw-terminal pair)**, both **from board 1**, with **all grounds
> commoned on board 1**. On-board rails, per-IC bypasses, and the two mandatory
> 100 µF VMOT electrolytics are drawn in
> [robot-board-power.jpg](robot-board-power.jpg) and the merged
> [robot-board-full.jpg](robot-board-full.jpg) (generator:
> [schematic.py](schematic.py)). The ASCII below remains the tether-level view;
> the 12 V source upstream of board 1 is out of scope.

```
  Bench DC supply (~12 V) --+--> VMOT, LEFT A4988   (+ its own 100 µF cap)   [over tether]
                            +--> VMOT, RIGHT A4988  (+ its own 100 µF cap)   [over tether]

  Off-robot Pi 3V3 (phys 17) --> A4988 VDD (L + R) + MPU-6050 Vcc            [over tether]
  Off-robot Pi GPIO/I2C ------> STEP/DIR/EN/MS + SDA/SCL                     [over tether]

  ALL grounds common: bench-supply GND == Pi GND == both A4988 GND == MPU GND.
  In the tether, keep the ~12 V motor pair separated from / twisted away from the
  I2C + STEP signal lines so stepper-current spikes don't couple into them.
```

## Solder-once checklist (do these in order)

1. **Identify each NEMA17's coil pairs first.** With the motor unplugged, measure
   resistance across wire pairs: the two wires that read a few ohms to each other
   are one coil → `1A/1B`; the other pair → `2A/2B`. A wrong pairing makes the
   motor buzz/lock instead of turn. (Wrong *direction* later is just a DIR flip in
   software — don't rewire for that.)
2. **Fit the 100 µF cap across each A4988's VMOT→GND before anything else**, right
   at the driver. Observe polarity. Never connect/disconnect a motor with VMOT
   live and no cap — the inductive spike kills A4988s.
3. **Tie RESET to SLEEP** on each driver (a short solder bridge or a wire between
   the two pads), then run one wire from that node to its GPIO. Both are active-low
   and must sit HIGH to operate.
4. Solder the logic lines per the tables (STEP/DIR/EN/MS + RESET-SLEEP), VDD to Pi
   3V3, logic GND to Pi GND.
5. **Set VREF (current limit) with the motors DISCONNECTED and VMOT powered.**
   Target ≤ **1.0 A/phase** (the NEMA17 rating). Limit = `VREF / (8 × Rcs)` →
   `VREF = I × 8 × Rcs`. **Rcs varies wildly between A4988 clones** (0.05 / 0.068 /
   0.1 Ω) — read the actual carrier's sense-resistor value off the board before
   trusting a number. Turn the pot, measure VREF pad to GND, dial it in, *then* power
   off and connect the motors.
6. Only after 1–5: bring up VMOT, confirm the off-robot Pi enumerates the MPU
   (0x69) on `i2cdetect -y 1` over the tether — ready for the V1 bench.

- Keep the ~12 V motor rail and the logic 3V3 physically separate in the tether
  (only grounds common). Stepper-current spikes must not couple into the I2C/STEP
  lines or the shared 3V3.

## Microstepping — MS pins are GPIO-wired on purpose

MS1/2/3 are routed to GPIO (not fixed jumpers) so the microstep mode is
software-selectable during V3/tuning without desoldering — higher microstepping is
smoother but needs a higher step rate (harder on timing), so it should be swept,
not committed now. To save six wires instead, tie each MS triple to fixed levels
per the A4988 truth table and pass the matching `mode` to `RPi::StepperMotor::A4988`
so the degree math stays correct — but then the mode is frozen in copper.
