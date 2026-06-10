# Proposal — Completeness audit of the wiringpi conformance & review plan

## Objective

Decide whether `~/repos/rpi-wiringpi/plans/wiringpi-conformance-and-review.md` (+ archive) is **complete** — does it capture every real issue across (A) making the ~19 `rpi-*` sibling dists work against the restructured `WiringPi::API` 3.1802, and (B) the bug/issue/improvement review of `rpi-wiringpi` (docs, Perl, tests)? The user wanted assurance that nothing material was missing; the challenger's mandate was adversarial completeness — find concrete gaps or prove exhaustiveness.

**Constraints:** "Conform" scoped to **code-compatibility only** for siblings (their Perl/XS/C must *work* against the new API; not tooling/version/POD/style). Part B (rpi-wiringpi) is full-scope. Tangible reality only (file/line/failure-mode). Reference: WiringPi::API 3.1802_01 installed; constants single-sourced from RPi::Const 1.05; stale RPi::WiringPi::Constant 1.02 still installed, masking sibling breakage. Per operator instruction the audit makes **no changes to any device/repo** — all evidence is read-only; the only writeable artifact is the plan.

## Participants & outcome

- **claude** — Claude (claude-opus-4-8), originator.
- **challenger** — Claude Fable 5 (claude-fable-5).
- **Date:** 2026-06-10 — **Status: RESOLVED.**

## Decision

The plan's *contents* survived the audit (all originator findings confirmed real and correctly located), but its **completeness claim was false as written** — the challenger landed five concrete misses, three of them inside files the review had already covered or enumerated. The plan is **complete as a static audit** once it carries the agreed additions below; the empirical gate (sibling + rpi-wiringpi builds/tests, V2–V13/V23–V30) remains scheduled future work and was **not** run (operator instruction).

Agreed additions to the plan:
- **F41** [release-blocking] — `MANIFEST` lists `docs/interrupt-examples.md`, `docs/threads-examples.md`, `t/README`, none of which exist; the moved `docs/examples/*.md` are not in MANIFEST. `make distdir` aborts → 3.1802 cannot ship.
- **F42** [HIGH] — `WiringPi.pm:38` `if (my $scheme = $ENV{RPI_PIN_MODE})` with `RPI_MODE_WPI == 0`: WPI scheme is falsy, so a second `new()` silently re-inits to GPIO addressing.
- **F43** [med→backlog] — `DHT11.xs`/`HCSR04.xs` `putenv()` of a stack buffer (dangling `environ`); pre-existing, not a 3.18 regression.
- **F44** [structural] — `rpi-const`, the 19th sibling and the dependency root the migration single-sources from, had no row; add a confirm-only row.
- **F45** [executed — nothing material] — generator scripts + `build_testing/` reviewed clean; two notes: `gen-schematic.py:145,225` bare `open(p,'w').write(...)` [low]; `Changes` 2.3633 chronology oddity [info].
- **F46** [open residual] — full per-file pass over all 69 test files **and** an exhaustive re-read of the large modules (`WiringPi.pm` ~1290 lines, `Core.pm` ~649) — the single-pass agent review is demonstrably non-exhaustive (WiringPi.pm alone yielded F22, F23, F42, F47).
- **F47** [med code + med doc] — `new()` `setup` param: case-asymmetric match + silent swallow + undocumented (see transcript). Fix: whitelist `w`/`g`/`none` case-insensitively and croak on truly-unrecognized; document the three forms.
- Fold Part-1 executed evidence into **F5/F6** (constants 0-diff; six consumers + F6 verified-at-source; dht11/hcsr04 C symbols intact).
- Fix the **V1 / NEXT-ACTION** contradiction (F5 already records the baseline answers); add the **3.1802_01-trial** release caveat to V24 (cannot release against a dev-only API CPAN can't index); rewrite the **`Explicitly NOT doing`** MANIFEST.SKIP wording so it no longer implies MANIFEST is clean.

## Major points

**Challenger (Fable 5):**
- Executed checks on the Pi rather than reasoning statically; closed all three of the originator's self-flagged gaps with data, then produced five misses with file/line/failure-mode.
- Strongest: F41 (release-blocker proven via `ExtUtils::Manifest::manicheck`) and F42 (HIGH bug in a fully-reviewed file). F47 demonstrated WiringPi.pm was "3-for-3" on missed findings across both review passes.
- Refused to declare RESOLVED while introducing an unverified claim (would be fake convergence under Rule 6).

**Originator (claude):**
- Did not concede on assertion — independently re-ran/verified F41, F42, F47 before accepting.
- Sharpened F42 (only WPI=0 is falsy; the truthy branch never re-runs setup) and F47 (`'none'` is the intended uninit sentinel, so the fix must whitelist, not blanket-croak).
- Added an honest residual the challenger had not: widened F46 to include an exhaustive large-module re-read, refusing to overstate completeness.

## Points of agreement

- All originator findings (F1–F40, esp. HIGH F16–F19) are real and correctly located; F19 is a genuine bug (not intended semantics — the per-uuid pattern exists 14 lines above at `Core.pm:211-220`).
- Constant **values** did not change (0 diff legacy 1.02 → RPi::Const 1.05); the six un-read consumers behave as F5/F6 predicted; dht11/hcsr04 C symbols are unchanged in wiringPi 3.18.
- The five misses (F41–F47, minus the executed-clean F45) belong in the plan; with them the plan is complete *as a static audit*.
- The empirical build/test gate is the remaining real work and was correctly deferred (not run).

## Failures to agree

None substantive. The only open item is **F46** (a genuinely-unfinished residual, not a disagreement): the full 69-file test pass and exhaustive large-module re-read remain to be done, and the empirical build/test gate remains to be run.

## Transcript

### Turn 1 — claude (claude-opus-4-8)
Position: the plan is substantially complete on what was examined, but oversells a load-bearing claim — it asserts completeness on the strength of **static reading and grep, with zero builds and zero test runs**. Coverage stated honestly: Part A dependency graph (8 Perl-level WiringPi::API consumers, 1 RPi::Const-only, 2 direct-libwiringPi-XS, rest independent), with two source-verified breakages —
- `rpi-spi/lib/RPi/SPI.pm:6` imports `:wiringPi` but calls `pin_mode()`/`write_pin()` (`:perl`) at 21–22 → undefined subs in bit-bang mode (F1);
- `rpi-adc-mcp3008/lib/RPi/ADC/MCP3008.pm:11` uses removed `RPi::WiringPi::Constant`, `:21` `wpi_setup()` (gone), `:25` `spi_setup()` under `:wiringPi`-only import (F2/F3/F4).

Part B: three full-file review passes → F10–F40, including HIGH bugs F16–F19 and F25 (stale README). Named five self-flagged gap categories the plan structurally cannot have caught (un-read consumers, dht11/hcsr04 C ABI, constant *values*, never-reviewed files like MANIFEST/Makefile.PL/scripts, severity opinions) and demanded the challenger attack both directions: find a missed issue AND disprove a finding.

### Turn 2 — challenger (Claude Fable 5)
Executed before arguing. Closed the originator's self-flagged gaps with data:
- **Constant values:** live diff of installed RPi::WiringPi::Constant 1.02 vs RPi::Const 1.05 → all 31 legacy names present, **0 value diffs** (`EDGE_FALLING == INT_EDGE_FALLING == 1`).
- **Six un-read consumers:** read line-by-line; bmp180/dac/digipot on legacy `RPi::WiringPi::Constant` as F5 predicted; lcd/stepper clean; rpi-pin `set_interrupt`/`background_interrupt` at `Pin.pm:128,155` match the new API → F6 verified-at-source.
- **dht11/hcsr04 C ABI:** all symbols exist with unchanged signatures in wiringPi 3.18; the `wiringPiSetupGpio() == -1` check (`DHT11.xs:192`/`HCSR04.xs:19`) was already dead in 2.x — not a regression.

Four misses:
1. **[RELEASE-BLOCKING] MANIFEST** lists `docs/interrupt-examples.md`, `docs/threads-examples.md`, `t/README` — absent from disk (first two moved to `docs/examples/`); new files not in MANIFEST. `make distdir`/`make dist` aborts.
2. **[HIGH] `WiringPi.pm:38`** — `if (my $scheme = $ENV{RPI_PIN_MODE})`, but `RPI_MODE_WPI == 0`; line 52 sets `RPI_PIN_MODE=0` for `setup=>'w'`, so a second `new()` reads false, runs `setup_gpio()`, stamps GPIO at `:65` — silent address-scheme corruption. `Core.pm:97-98` correctly uses `defined`.
3. **[med] `DHT11.xs:187-189` / `HCSR04.xs:23-25`** — `char modeEnvVar[20]; sprintf(...); putenv(modeEnvVar);` — putenv stores the pointer; buffer dies on return; next `getenv` reads freed stack.
4. **[structural]** V2–V13 enumerate 18 dists; **`rpi-const` (19th, dependency root) has no row** (repo 1.05 == installed 1.05, zero drift — harmless by luck).

Plus minors: NEXT ACTION still queues V1 though F5 records the baseline; "3.1802" vs installed **3.1802_01 trial** (cannot release against a dev-only API CPAN can't index). Tried and failed to break a HIGH: F16 (self-recursion), F17 (getter croak), F18 (`&&` vs `||` at `:159`) all confirmed; F19 is *not* intended semantics (per-uuid pattern at `Core.pm:211-220` proves the author knew better).

### Turn 3 — claude (claude-opus-4-8)
Re-verified the two that matter rather than conceding on say-so. **MANIFEST** confirmed (`MANIFEST:40,46,151`; `ls` fails on all three; `docs/examples/*` not in MANIFEST) — accepted, release-blocking; corrected framing (Turn 1 gap #4 had named MANIFEST as un-reviewed, so the *transcript* didn't claim completeness — but the finding stands). **WiringPi.pm:38** confirmed and sharpened: of GPIO(1)/PHYS(3)/UNINIT(-1)/WPI(0), only WPI is falsy; the truthy branch at `:40` only calls `pin_scheme($scheme)` and never re-runs setup — design intent is "trust the env," defect is WPI can't be trusted to it. Accepted items 3 & 4. Folded Part-1 receipts into F5/F6 (asserted → verified). Refused total victory: `scripts/gen-test-platform.pl` + helpers, `build_testing/`, docs images, full 69-file pass remain untouched, and the empirical gate is unrun. Committed to F41–F46 and the V1/3.1802_01 fixes; invited a fifth miss or a RESOLVED.

### Turn 4 — challenger (Claude Fable 5)
Acknowledged + followed the handshake. Granted the item-2 sharpening and granted item-1 only half: the *plan document* (unlike the transcript) contains no MANIFEST admission and its `## Explicitly NOT doing` waves off MANIFEST.SKIP as out-of-scope tooling while a MANIFEST defect blocks release. Declined RESOLVED (procedural: can't resolve while introducing an unverified claim; substantive: had a fifth).

**Fifth miss — F47: the `new()` `setup` param is broken-by-design and undocumented.**
- `WiringPi.pm:50` `=~ /^w/i` but `:54` `=~ /^g/` (no `/i`) → `setup => 'GPIO'`/`'Gpio'` silently falls through.
- `:58-60` else stamps `RPI_MODE_UNINIT`, **no setup, no croak/warn** — any typo silently no-ops the board.
- Documented nowhere: 0 occurrences of `setup` in WiringPi.pm POD (past `__END__:523`) and 0 in FAQ.pod; yet public and used by the suite (`t/106-pin_map.t:13`, `setup => 'none'`). WiringPi.pm now 3-for-3 on missed findings. Severity [med] code + [med] doc.

Also executed residual hole #1: `gen-test-platform.pl`, `gen-pod-md.pl`, `gen-pdf.py`, `gen-pinout-images.py`, `build_testing/*` — clean; residue = `gen-schematic.py:145,225` bare `open(path,'w').write(...)` [low] and a `Changes` chronology oddity [info]. So F45 = executed/nothing-material. Residual hole #2 (full 69-file pass) only sampled (~10 more, nothing new) — stays open as F46. Stated convergence terms; asked the originator to verify F47 and resolve, or refute.

### Turn 5 — claude (claude-opus-4-8) — RESOLVED
F47 verified: `t/106-pin_map.t:13` uses `new(setup => 'none', ...)`; `grep setup` over WiringPi.pm past `__END__:523` returns nothing; FAQ.pod has 0; code asymmetry + silent else confirmed. Accepted [med]/[med], **sharpened**: `'none'` is the *intended* uninit sentinel the suite relies on, so the fix must match `^w`/`^g`/`^n` case-insensitively and croak only on values matching none of the three (a blanket croak-on-else would break `'none'`); document the three forms + default. Granted the plan-artifact correction (will fix the `Explicitly NOT doing` MANIFEST wording). Accepted F45 (executed, nothing material, two notes) and F46 (open). **Widened F46** to include an exhaustive re-read of WiringPi.pm/Core.pm — the single-pass review is demonstrably non-exhaustive. Declared RESOLVED on the agreed term list (F41–F47 + V1/NEXT-ACTION fix + 3.1802_01 caveat + Explicitly-NOT-doing wording fix + Part-1 evidence into F5/F6), with the empirical build/test gate remaining scheduled and not run.
