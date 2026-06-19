# Test-platform documentation regeneration — plan (2026-06-19)

## Goal

One **cohesive, repeatable** pipeline for `docs/test-platform/`: a single canonical
**MODEL** of the physical board, validated against the unit-test suite, from which
*every* artifact is rendered — the human pin reference, the schematic, the KiCad
project, the PDFs, the pinout images, the netlist. No more hand-maintained docs
that silently drift from the tests (the stale "A4-7 ↔ B4-7" loopback was exactly
that failure).

---

## 1. What "the MODEL" is (concretely)

The MODEL is **one machine-readable description of the board**: its components, the
nets that wire them together, and a little render metadata. It is the *only* thing
edited (or derived) by hand — everything under `docs/test-platform/` is rendered
*from* it. A given pin number lives in exactly one place.

It already exists today — it's just **duplicated** across `gen-schematic.py` and
`model-from-tests.py` as six Python structures. This is the MODEL:

### `COMPONENTS` — every physical part

```
ref  →  (value/part, footprint, { chip-pin : pin-name })

'U1':  ('MCP23017',        'DIP-28',        {'9':'VDD','12':'SCL','13':'SDA','21':'GPA0', ...}),
'M1':  ('ADS1115_0x48',    'Module',        {'VDD':'VDD','SCL':'SCL','A0':'A0', ...}),
'M7':  ('ULN2003_28BYJ48', 'Module',        {'IN1':'IN1','IN2':'IN2','V+':'V+', ...}),
'J1':  ('Raspberry_Pi_40pin','PinHeader_2x20',{ '1':'P1', ... '40':'P40' }),
```

### `NETS` — every wire, with provenance

```
( net-name, [ (ref, pin), (ref, pin), ... ] )   # tag + proving test

('I2C_SDA', [('J1','3'),('U1','13'),('M1','SDA'),('M3','SDA'), ...]),   # [T] t/305,330,450...
('EXP_IN1', [('U1','21'),('M7','IN1')]),                               # [T] t/450  GPA0 → ULN2003
('+3V3',    [('J1','1'),('U1','9'), ...]),                             # [F] supply rail
```

### Render metadata (derived facts, also in the MODEL)

```
J1FUNC = {1:'3V3', 3:'GPIO2/SDA', 12:'GPIO18', ...}     # Pi 40-pin native functions
DRIVER = {'I2C_SDA':'J1', 'SPI_MISO':'U3', ...}         # which node DRIVES each net (direction)
POWER  = {'U1':[('9','+3V3'),('10','GND')], ...}        # per-device power pins → rail
SHEETS = {'i2c':{...nets...}, 'spi':{...}, 'stepper':{...}, 'display':{...}}  # per-subsystem grouping
```

### The provenance tags travel with every fact

- `[T]` proven by a test (the test is cited)
- `[L]` a submodule default the test relies on but does not set
- `[F]` gap-filled from non-test sources (rails, passive values, exact part IDs)

**That's the whole idea of "MODEL":** components + nets + metadata, each fact tagged
with where its authority comes from. Connectivity is stored once, as data. The
schematic, the KiCad netlist, and the pin tables in the doc are then three *views*
of the same rows — they cannot disagree because they read the same `NETS`.

---

## 2. Source of truth → MODEL

The MODEL has **two** inputs, because the tests alone are not a complete spec:

| Input | Provides | Tag |
|---|---|---|
| **The test suite** (`t/*.t`, `t/multi/*.pl`, `t/RPiTest.pm`, `t/crontab`) | connectivity, I²C addresses, pin modes — decoded from each device constructor's arguments against the driver submodules | `[T]` / `[L]` |
| **A curated facts file** (new: `docs/test-platform/facts/board-facts.*`) | the things no test can prove — supply rails, passive values, the level-shifter, exact module part numbers | `[F]` |

Today the `[F]` facts are scattered inline in the Python. Pulling them into one
curated input file makes the source-of-truth boundary explicit: **tests + facts
file → MODEL → everything**.

---

## 3. Architecture (hub-and-spoke)

```
   t/*.t  ─┐                       ┌─→ test-pinout-doc.md   (human reference; templated)
           ├─→  MODEL  ──renderers─┼─→ wire-routed SVG (scratch) → schematic PDF
 facts ────┘   (one file)          ├─→ kicad/  (.kicad_sch / .pretty / fp-lib-table)
                  ▲                 ├─→ test-pinout-*.jpg    (pinout images)
                  │                 └─→ test-platform.net    (netlist)
            validation: re-derive from tests, DIFF against the MODEL → fail on drift
```

The markdown doc is a **spoke**, not the hub. It is rendered from the MODEL exactly
like the schematic is — never parsed back to feed anything.

---

## 4. Target layout

```
scripts/helpers/
  board-model.py          # THE MODEL — single canonical COMPONENTS/NETS/J1FUNC/DRIVER/POWER/SHEETS
  render-doc.py           # NEW: MODEL → test-pinout-doc.md (tables) into a template
  gen-schematic.py        # renderer only (imports board-model.py; its in-repo model is deleted)
  gen-kicad.py            # renderer only (imports board-model.py)
  gen-pdf.py              # svg → pdf  (unchanged)
  gen-pinout-images.py    # MODEL → jpg
  check-kicad.py          # validator (unchanged)
  derive-from-tests.py    # the old model-from-tests.py, repurposed as the VALIDATION re-derivation
  regen.py                # NEW: the one orchestrator (replaces gen-updated-visuals.py)

docs/test-platform/
  README                  # NEW operational doc: runbook + directory manifest (NO pin data)
  test-pinout-doc.md      # GENERATED (prose template + injected tables)
  test-pinout-doc.tmpl.md # NEW: the hand-authored prose with {{table placeholders}}
  facts/board-facts.*     # curated [F] inputs
  facts/test-platform.net # generated netlist
  kicad/                  # NEW: ALL KiCad-native docs live here (self-contained project):
                          #   test-platform.kicad_sch, test-platform.kicad_pro,
                          #   test-platform.pretty/ (footprints), fp-lib-table.
                          #   This IS the KiCad "project dir".
  *.pdf                   # schematic deliverable (multi-page A3/A4; the committed schematic)
  *.jpg                   # pinout images (PIL; overview + detail)
  # NO committed svg/ — wire-routed SVGs are scratch intermediates (see below)
```

**Schematic rendering (decided):** keep **only the wire-routed (netlistsvg) sheets**;
drop the schemdraw net-label path entirely — that removes `test-pinout-schematic.svg`
and its `test-pinout-schematic.jpg`, and simplifies `gen-schematic.py`. The wire-routed
sheet SVGs are **build intermediates**: rendered into a scratch dir, consumed by
`gen-pdf.py`, and **not committed**. The committed schematic deliverable is the
multi-page **PDF** (vector, one page per subsystem — equally zoomable); the doc's
schematic links repoint to the PDF. (The `gen-pinout-images.py` JPGs are separate and
stay.)

**KiCad directory:** every KiCad document (`.kicad_sch`, `.kicad_pro`, the
`.pretty/` footprint library, `fp-lib-table`) is relocated under
`docs/test-platform/kicad/`. They reference each other relatively
(`fp-lib-table` uses `${KIPRJMOD}`, which resolves to the `.kicad_pro` dir), so
moving them together keeps the project self-consistent; `gen-kicad.py` and
`check-kicad.py` simply target the new `kicad/` dir. The cairosvg-derived
schematic **PDFs** and the **pinout JPGs** are renders, not KiCad files, so they
stay outside `kicad/` (say the word if you'd rather the schematic PDFs sit there too).

---

## 5. The one-command flow

A single `make regen-test-platform` (or `regen.py`) runs the chain deterministically:

1. **Load** `board-model.py` (+ `facts/board-facts.*`).
2. **Validate**: run `derive-from-tests.py`, DIFF its re-derivation against the MODEL;
   abort on any difference (this is the drift gate).
3. **Render** every output from the MODEL: netlist → svg → pdf, kicad, jpg, and
   `test-pinout-doc.md` (template + tables).
4. **Check**: `check-kicad.py` validates the KiCad project.
5. **Report** what changed.

"Repeatable" = same inputs → byte-identical outputs. Watch the timestamp emitters
(PDF/KiCad writers; the netlist already stubs `(date "")`).

---

## 6. `test-pinout-doc.md`: templated, not fully generated

Split the current 45 KB doc by what is mechanically derivable:

| Generate from the MODEL (these drift) | Keep hand-authored (analysis) |
|---|---|
| pin → destination tables | collision analysis |
| I²C address map | GPIO18-multiplexing rationale |
| net / loop-back topology | timing-means narrative |
| default-pin-state tables | design intent / "why" |
| "pins not wired to fixtures" | section ordering / framing |

Implementation: `test-pinout-doc.tmpl.md` holds the prose with placeholders like
`{{i2c_map}}`, `{{loopback_table}}`; `render-doc.py` fills them from the MODEL.
**Do not** try to generate the prose — that would either lose the analysis or push
English into Python.

---

## 7. New `README` (operational)

Replaces the current pin-listing README with two things only:

1. **Runbook** — the venv requirement and the single regenerate command; what each
   step does; how the drift gate fails.
2. **Manifest** — one line per entry in `docs/test-platform/`: what it is and which
   generator produced it (`kicad/` ← gen-kicad, `*.pdf` ← gen-pdf [from scratch
   wire-routed SVGs], `*.jpg` ← gen-pinout-images, `test-pinout-doc.md` ←
   render-doc, etc.). No `svg/` — those are scratch intermediates.

**Hard rule: zero pin data in the README** — point to `test-pinout-doc.md`. The
instant it duplicates a pin table, drift is back. Before deleting the old README,
confirm its unique facts (I²C map, per-subsystem `[T]/[L]/[F]` wiring) are present
in the generated doc.

---

## 8. The one open decision

**How "from the tests" actually works** — this drives how automatable the whole
thing is:

- **(a) Build a real test-parser** — read constructor args out of `t/*.t` and emit
  the `[T]` facts automatically. True end-to-end repeatability, but a big lift, and
  the tests are not a clean declarative spec (you still decode against drivers).
- **(b) Curated MODEL + diff** *(recommended to start)* — the MODEL is hand-curated;
  `derive-from-tests.py` independently re-derives and **diffs** as a regression gate.
  This is essentially today's design, made the official contract. It already catches
  drift (it's what *should* have caught the loopback), and it's cheap.

Recommendation: ship **(b)** now (it makes the current setup cohesive with little
new code), and later add **targeted extractors** for the genuinely declarative facts
(I²C addresses, constructor pin lists) to strengthen the diff toward **(a)**
incrementally.

---

## 9. Migration checklist

1. Promote one model file to canonical `board-model.py`; delete the duplicate in
   `gen-schematic.py`; repoint `gen-schematic.py`/`gen-kicad.py` to import it.
2. Extract inline `[F]` facts into `facts/board-facts.*`.
3. **Correct the known drift in the MODEL** before anything renders: t/330 now loops
   **all 16 pins** (datasheet 1-28…8-21 ⇒ `A(n) ↔ B(7-n)`), and the 0x21 stepper
   expander + magnetic-switch rig must be present; remove the last photo-sensor
   remnants (already done in `model-from-tests.py`).
4. Write `render-doc.py` + `test-pinout-doc.tmpl.md` (port the prose, mark the tables).
5. **Relocate the KiCad project** to `docs/test-platform/kicad/`: point
   `gen-kicad.py`'s output dir and `check-kicad.py`'s project dir there; confirm
   `fp-lib-table` / `${KIPRJMOD}` still resolves and the footprints load.
6. **Trim the schematic renderer**: delete the schemdraw net-label path from
   `gen-schematic.py`; render the wire-routed sheet SVGs into a scratch dir, feed
   `gen-pdf.py`, and don't commit them; repoint the doc's schematic links to the PDF.
7. Write `regen.py`, fold in the diff gate + `check-kicad.py`.
8. Generate `test-pinout-doc.md`; diff against the current hand doc; reconcile until
   only intended changes remain.
9. Write the new operational `README`; delete the old one once its unique facts are
   confirmed in the generated doc.
10. Add the drift gate to the test/CI path so stale docs **fail** instead of rotting.

---

## Non-goals / risks

- **Not** generating prose/analysis — templated only.
- **Not** parsing markdown to render anything — the MODEL is the only machine input.
- Determinism risk: timestamp/UUID emitters in the PDF/KiCad writers — stub or pin them.
- Before deleting the old README, the generated doc must be confirmed to cover its
  unique content, or facts are lost.
