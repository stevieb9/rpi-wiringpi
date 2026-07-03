# Plan: Single source of truth for the wiringPi version requirement

> **NEXT ACTION:** V1 — write and run `perl scripts/audit-family-buildcheck.pl`
> **LAST SESSION:** 2026-07-03 — plan created; researched local repos, cataloged guard variants and defects (F1-F6)
> **ARCHIVE:** See wiringpi-version-single-source-archive.md for completed V tasks

## Goal

Every XS distribution in the RPi::WiringPi family carries a hand-copied
`Makefile.PL` guard (wiringPi presence + `gpio -v` version parse +
`RPI_DIST_RELEASE` bypass, exiting 0 before `WriteMakefile` so CPAN testers
report NA instead of FAIL). The copies have drifted — the minimum version is
`2.36` in some dists and `3.18` in others — and the guard logic itself has
latent bugs. This plan (1) inventories every copy and its defects, and
(2) replaces them with a single canonical implementation: a pure-perl
`RPi::Const::BuildCheck` module holding `$MIN_WIRINGPI_VERSION`, pulled in at
configure time via `CONFIGURE_REQUIRES`, plus an audit script in this repo
that detects drift forever after.

## Current known state (research evidence, 2026-07-03)

| Where | Guard | Min ver | Notes |
|-------|-------|---------|-------|
| `wiringpi-api/Makefile.PL` | full wiringPi check | **3.18** | The current canonical form |
| User's pasted snippet (repo TBD via V1) | full wiringPi check | **2.36** | Stale, pre-3.x-fork era |
| `rpi-gpioexpander-mcp23017/Makefile.PL` | i2c.h presence only | n/a | Variant class: i2c guard |
| `rpi-i2c/Makefile.PL` | **none** | n/a | XS dist with no guard at all → FAIL not NA on testers |
| `rpi-const/Makefile.PL` | none (correct) | n/a | Pure perl, installs anywhere |
| `rpi-wiringpi/Makefile.PL` (this repo) | none | n/a | Pure perl manager; relies on dep chain — acceptable, document as deliberate |
| `lib/RPi/WiringPi.pm:716-717`, README, docs/pod | prose | v3.18 | Hand-maintained doc references |
| `lib/RPi/WiringPi/FAQ.pod:1789` | prose | n/a | Documents `RPI_DIST_RELEASE` semantics |

Ground truth: the wiringPi C library (upstream `WiringPi/WiringPi`, cloned at
`~/repos/WiringPi`) is at **3.18**; its `gpio -v` prints
`gpio version: %d.%d` (gpio/gpio.c:918), so the existing parse regex
`/version:\s+(\d+\.\d+)/` still matches on 3.x.

The family universe (from this repo's `PREREQ_PM`, RPi-family only — 20
dists): RPi::ADC::ADS, RPi::ADC::MCP3008, RPi::BMP180, RPi::Const,
RPi::DAC::MCP4922, RPi::DigiPot::MCP4XXXX, RPi::DHT11, RPi::EEPROM::AT24C32,
RPi::GPIOExpander::MCP23017, RPi::HCSR04, RPi::I2C, RPi::LCD,
RPi::OLED::SSD1306::128_64, RPi::Pin, RPi::RTC::DS3231, RPi::Serial,
RPi::SPI, RPi::StepperMotor, RPi::SysInfo, WiringPi::API. Only rpi-const,
rpi-i2c, rpi-gpioexpander-mcp23017 and wiringpi-api are cloned locally; the
rest live at `github.com/stevieb9/<slug>` (V1 fetches their Makefile.PLs —
note the `gh` CLI token is currently invalid, so use
`raw.githubusercontent.com` or local clones, not `gh`).

## Design (decisions)

- **Canonical home: `RPi::Const::BuildCheck`**, a new pure-perl module inside
  the existing rpi-const dist. Rationale: RPi::Const is already the family's
  universal pure-perl leaf dependency, installs on any platform (so it is
  safe in `CONFIGURE_REQUIRES` and on non-Pi CPAN testers), and a minimum
  version IS a constant — squarely its charter. No new repo/dist to maintain.
  (Alternative considered: a dedicated new dist — see NOT doing.)
- The module provides `$RPi::Const::BuildCheck::MIN_WIRINGPI_VERSION`
  (currently `3.18` — THE single place to bump), `wiringpi_build_check()` and
  `i2c_build_check()`. Both honor `RPI_DIST_RELEASE` and exit **0** with a
  message before `WriteMakefile` when unsatisfied — preserving the
  NA-not-FAIL CPAN-tester semantics documented in FAQ.pod.
- **Version comparison is an integer (major, minor) tuple compare**, not
  `version->parse` / decimal compare — wiringPi minors are integers, so
  `3.8 < 3.18`. The current code gets this wrong (F2).
- Each XS dist's Makefile.PL shrinks to a uniform ~6-line shim:
  `eval { require RPi::Const::BuildCheck }` → call the check(s) it needs; if
  the module is absent (bare `perl Makefile.PL` with no CPAN client), print
  "install RPi::Const first" and exit 0 (still NA-safe). Plus
  `CONFIGURE_REQUIRES => { 'RPi::Const' => <new ver> }` so CPAN clients
  install it before configure runs.
- **Bumping the minimum later = one rpi-const release.** Even already-shipped
  tarballs of the other dists pick up the new minimum on fresh installs,
  because the check floats with the installed RPi::Const.
- **Release sequencing:** the new RPi::Const must be on CPAN **before** any
  converted dist is released, or their `CONFIGURE_REQUIRES` cannot resolve.
- Per the user's git rules, no V task commits or releases anything — every
  task stops at working-tree changes; Steve reviews, commits, and releases.

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of wiringpi-version-single-source-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
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
| V1 | Write `scripts/audit-family-buildcheck.pl` — read-only reporter. Derives the family list from this repo's `PREREQ_PM` (RPi::\* + WiringPi::API), locates each dist's Makefile.PL (local clone at `~/repos/<slug>` first, else `raw.githubusercontent.com/stevieb9/<slug>/master/Makefile.PL`; small slug-exceptions hash for non-obvious repo names), and reports per dist: guard class (wiringpi / i2c / both / none), min version found, and drift vs canonical. `--markdown` emits a table | `perl scripts/audit-family-buildcheck.pl --markdown` | One row per family dist, no fetch errors; the 2.36-vs-3.18 drift and the guardless XS dists (e.g. rpi-i2c) are visible in the output | ⏳ |
| V2 | Classify every dist from the V1 report: which check(s) does each need (wiringpi / i2c / both / none, based on what its XS actually links/includes)? Append the classification table + the V1 drift report to this plan under "Current known state", and identify which repo the user's 2.36 paste came from | manual review of V1 output + each dist's `LIBS`/`INC` | Every one of the 20 dists classified with rationale; conversion worklist for V7/V8 is fixed | ⏳ |
| V3 | Implement `RPi::Const::BuildCheck` in `~/repos/rpi-const`: `$MIN_WIRINGPI_VERSION = 3.18`, `wiringpi_build_check()`, `i2c_build_check()`, integer tuple version compare, `RPI_DIST_RELEASE` bypass, exit-0 NA semantics; unit tests covering tuple compare (`3.8` fails a `3.18` minimum; `3.18` passes; `2.36` fails), unparseable `gpio -v` output → hard NA exit (not silent pass), bypass behavior; POD + Changes entry | `cd ~/repos/rpi-const && perl Makefile.PL && make test` | All tests pass on this mac (pure perl, no wiringPi needed — check functions are testable via injected paths/output) | ⏳ |
| V4 | Reference conversion: replace `wiringpi-api/Makefile.PL`'s inline guard with the shim + `CONFIGURE_REQUIRES => { 'RPi::Const' => <new ver> }`; drop `use version;` | `cd ~/repos/wiringpi-api && PERL5LIB=~/repos/rpi-const/lib perl Makefile.PL; echo "exit=$?"` | On this mac (no wiringPi): message + exit 0, no Makefile written. With `RPI_DIST_RELEASE=1`: Makefile written. Final on-Pi pass/fail verification is Steve's, on the test platform | ⏳ |
| V5 | Add author-side drift gate in this repo: `xt/author/buildcheck-audit.t` wraps the V1 script and fails on any dist whose guard drifts from canonical; unconverted dists sit in an explicit TODO list inside the test that shrinks as V7/V8 land | `cd ~/repos/rpi-wiringpi && prove -l xt/author/buildcheck-audit.t` | Passes with current TODO list; a simulated drift (edit a local clone's min ver) makes it fail | ⏳ |
| V6 | Docs: update FAQ.pod's `RPI_DIST_RELEASE` section and WiringPi.pm's v3.18 prose (line ~717) to name `RPi::Const::BuildCheck` as the canonical minimum; add a FAQ entry "where is the required wiringPi version defined?"; regen derived docs | `perl scripts/gen-pod-md.pl && grep -rn 'BuildCheck' docs/pod/FAQ.md README.md` | Prose + generated md reference the single source; no stale standalone version claims left | ⏳ |
| V7 | Convert remaining local clones per V2 classification: `rpi-gpioexpander-mcp23017` (i2c check → shim) and `rpi-i2c` (add missing guard via shim) | `for r in rpi-gpioexpander-mcp23017 rpi-i2c; do (cd ~/repos/$r && PERL5LIB=~/repos/rpi-const/lib perl Makefile.PL); done` | Both behave per their V2 class on this mac: exit-0 NA without headers, Makefile written with `RPI_DIST_RELEASE=1` | ⏳ |
| V8 | Convert the remaining non-local family repos: clone each (worklist from V2) into `~/repos`, apply the shim per classification, rerun the audit | `perl scripts/audit-family-buildcheck.pl --markdown` | Every family dist reports "shim, canonical" — zero drift rows; V5's TODO list is emptied. Steve then releases rpi-const first, then the converted dists | ⏳ |

## Discovery Tracking

_None yet._

## Review Findings

Defects found while researching this plan (the "issues like the paste"). Each maps to the V task that addresses it.

- **F1** (→V1, V8): Minimum-version drift across copies — the pasted Makefile.PL requires `2.36`, `wiringpi-api` requires `3.18`; the other ~16 XS dists are unaudited and likely stale.

- **F2** (→V3): Wrong version comparison semantics — `version->parse($version) < $min` treats `3.8` as v3.800.0 > v3.180.0, so a Pi running wiringPi 3.8 **passes** a 3.18 minimum. wiringPi minors are integers (3.8 is ten releases older than 3.18); same false-pass class for `2.5` vs `2.36`. Needs integer (major, minor) tuple compare.

- **F3** (→V3): Silent pass when `gpio -v` output doesn't match `/version:\s+(\d+\.\d+)/` — the inner `if` has no `else`, so an unparseable output skips version validation entirely and the build proceeds against a possibly-too-old library.

- **F4** (→V2, V7, V8): Guard coverage is inconsistent — `rpi-i2c` is XS with **no** guard (CPAN testers without headers get FAIL, not NA); `rpi-gpioexpander-mcp23017` checks only i2c.h; no record exists of which dist needs which check.

- **F5** (→V5): The duplication itself is structural — N hand-edited copies with no markers, no tooling, no drift detection, so divergence will recur without an audit gate.

- **F6** (→V6): Prose version references (WiringPi.pm "v3.18", README/docs copies, FAQ's `RPI_DIST_RELEASE` section) are hand-maintained in parallel with the code copies — another drift surface.

## Backlog

B1: Expose the installed wiringPi library version at runtime — WiringPi::API already links the lib (3.x provides `wiringPiVersion(&maj, &min)`); surface it through `pidentify` and/or RPi::SysInfo so "what wiringPi am I actually running" has one runtime answer too.

B2: Interpolate the canonical minimum version into POD/README at regen time (extend `scripts/gen-pod-md.pl`) so prose can never drift from `$MIN_WIRINGPI_VERSION` (completes F6 beyond V6's manual fix).

B3: Broaden library discovery in `wiringpi_build_check()` — today only `/usr/include` and `/usr/local/include` are probed; consider `pkg-config`/`ldconfig` or a Devel::CheckLib-style compile-and-link probe.

B4: Have Dist::Mgr template the shim into newly created RPi-family dists so future modules are born conformant.

## Explicitly NOT doing

- **Putting the check in WiringPi::API and making it a `CONFIGURE_REQUIRES` of the other dists** — WiringPi::API is XS and only installs where wiringPi already exists, which turns configure-dep resolution into an install-ordering problem and muddies the NA semantics. The canonical holder must be pure perl.
- **Dropping configure-time checks in favor of a runtime-only check** — the exit-before-WriteMakefile behavior is what makes CPAN testers report NA instead of FAIL (per FAQ.pod); runtime checks can't replace that.
- **A dedicated new CPAN dist (e.g. RPi::BuildCheck) as the canonical home** — works identically, but adds a repo/dist to maintain for one constant and two functions; rpi-const already ships to every family install. Revisit only if Steve prefers strict separation of constants vs build policy.
- **Adding a wiringPi guard to this repo's (rpi-wiringpi) own Makefile.PL** — it is pure perl; its XS prereqs carry the guards, and a missing wiringPi already surfaces as NA through the dependency chain.
- **Committing or releasing anything on Steve's behalf** — per git rules, all commits and CPAN releases are his; V tasks stop at working-tree changes.
