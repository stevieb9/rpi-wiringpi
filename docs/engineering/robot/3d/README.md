# 3D-printed parts — robot chassis

Each part is a parametric generator (`.py`, the source of truth) plus its
committed STL (a regenerable derivative, kept so the parts are printable
without running anything). Dimensions all in mm.

**Bed adhesion: skirt only — no brim, no raft, no ironing.** Both parts have
large flat first layers that need no help, and the wheel's bottom face is the
flange-seat surface: it must print directly on the glass (a raft ruins the
seat finish and the recess edges). Rafts + ironing also interact badly in
Cura (the raft top gets ironed smooth and the part welds to it — especially
in PETG). Authoritative specs live in
[bill-of-materials.md](../bill-of-materials.md) (fastener schedule, hub
listing), [control-theory.md](../control-theory.md) §4/§6, and
[robot-mechanical.jpg](../robot-mechanical.jpg) (assembly + balloon callouts).

## robot-wheel-90mm.stl (`wheel.py`) — print two

- Envelope Ø89.5 × 14; tread channel root Ø87 × 10 wide between 1.25 mm
  retention lips (top lip 45°-chamfered); effective rolling Ø ≈ 90–91 with
  tread fitted — enter the measured value into the V1 steps/s ↔ m/s math.
- Tread: stretched inner-tube strips, 2–3 layers, **butt-jointed with seams
  staggered**, contact-cemented, ≥2 mm total so rubber stands proud of the
  lips. No overlaps — a lump reads as at-rest hunting during V8 tuning.
- Hub interface: inboard Ø22.6 × 2.8 flange recess (the recess centers the
  wheel); 4× Ø4.0 clearance holes on a Ø16 bolt circle — oversized on purpose
  to absorb bolt-circle tolerance; Ø6.5 counterbores outboard. Populate
  **two opposite M3×8 SHCS**; all four positions are printed so a wobbly seat
  can be pulled flat.
- Center bore is closed by a 0.3 mm sacrificial membrane at the recess
  ceiling (makes the seat bridge fully anchored). Drill it Ø8 only if the
  shaft pokes past the flange at assembly.
- Print: recess face down, 3–4 perimeters, 20–30 % infill, PLA or PETG.
  The STL imports print-ready — do NOT rotate or Lay Flat. Orientation
  check: spoke windows + big pocket against the plate, counterbore rings
  facing up. A slicer showing a TALL support gap under the hub means the
  model is upside-down (the real pocket is a 2.8 mm dish on the glass).
  No supports required by design — the one downward span is the
  fully-anchored Ø22.6 ceiling bridge (max chord 22.6 mm). Enable Bridge
  Settings + bridge fan 100 %; prefer PLA for wheels (bridges better; the
  PETG advice is bracket-specific). The bridge prints at z ≈ 2.8 — watch it
  land in the first ~20 min; mild sag is fine (seat contact is at the outer
  edge). If adding supports anyway, set Support Placement = Touching
  Buildplate so they generate only inside the pocket (scar hides under the
  flange).
- Slicer checks: layer 1 shows the full footprint (rim ring, spokes, boss
  ring) on the plate; the bridge layer at z ≈ 2.8 shows parallel chords
  anchored wall-to-wall; no red on the chamfered top lip.
- Hardware assumptions (verify against the delivered couplers — Amazon
  B0DZXP6XZL): flange Ø22 × 2, barrel Ø10 × 10, bore 5 mm, M3 flange
  threads. Bolt circle Ø16 is a class-standard guess the listing omits — if
  the real pattern differs, seat the flange in the recess and use it as its
  own drill jig (3 mm bit through its holes).
- After printing: FDM holes shrink — run a 3.5 mm bit through the M3
  clearance holes if screws bind.

## robot-motor-bracket.stl (`bracket.py`) — print two (symmetric, same STL both sides)

- Vertical leg 50 × 48 × 4: NEMA17 face pattern — 4× Ø3.4 on the 31.0 mm
  square, Ø23 boss pass-through with a 45° teardrop crown so the horizontal
  bore prints sag-free. Shaft center 26.5 mm above the deck (matches the
  mechanical drawing's stack-up; motor belly clears the base by ~1.3 mm).
- Base 50 × 36 × 4: 4× **M4 slots** (~10 mm fore-aft travel) — the
  adjustment that makes the two motor shafts collinear at assembly; snug the
  M4×20 + fender washers + nyloc stack only after alignment.
- Side gussets (3.5 mm, 45° hypotenuse) sit outboard of the 42.3 mm motor
  width — the motor body never touches them.
- Print: base down, NO supports (teardrop + 45° gussets make that true),
  4–5 perimeters, ~40 % infill. **PETG preferred over PLA** — steppers cruise
  at 50–60 °C, PLA's creep zone.
- Hardware assumption (caliper the actual motors): NEMA17 standard — 42.3
  face, 31.0 mm hole square, M3, Ø22 × 2 pilot boss.

## Regenerating

```sh
python3 -m venv venv && venv/bin/pip install manifold3d numpy
venv/bin/python3 wheel.py      # -> robot-wheel-90mm.stl
venv/bin/python3 bracket.py    # -> robot-motor-bracket.stl  (imports wheel.py helpers)
```

Every dimension is one entry in the script's `P` dict; regenerate and commit
the STL alongside the source. Each script prints triangle count, volume, mass
estimate, and bounding box — a volume that drifts from the hand math is the
first sign a boolean went wrong.
