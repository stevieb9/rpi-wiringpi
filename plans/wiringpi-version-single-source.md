# Plan: Single source of truth for the wiringPi version requirement

> **NEXT ACTION:** _All V tasks (V1-V8) AND all backlog (B1-B6) complete._ The wiringPi minimum is now single-sourced in `RPi::Const::WIRINGPI_MIN_VERSION`, enforced everywhere via `RPi::Const::BuildCheck`; no dist restates the literal, the docs can't drift (B2), discovery is compiler-aware (B3), the runtime version is exposed (B1), and new dists are born conformant via `Dist::Mgr` (B4). Remaining is Steve's alone: **release sequencing** — publish rpi-const 1.07 (ships the constant + BuildCheck) to CPAN FIRST, then the converted dists (their `CONFIGURE_REQUIRES` can't resolve otherwise). Optional stragglers only: rpi-serial/rpi-sysinfo were confirmed to need no guard.
> **LAST SESSION:** 2026-07-08 — V1-V8 DONE (see archive). V8: converted the last 6 XS dists (oled/dac/hcsr04/dht11 -> wiringpi shim; adc-ads/rtc-ds3231 -> i2c shim); discovered `rpi-eeprom-at24c32` bundles its own i2c-dev.h so needs NO guard (corrected V2, refined the audit's angle-vs-quote detection + drift labels); emptied the gate %TODO and reframed test 2 to assert full single-sourcing + a canonical-constant cross-check (gate 13 subtests). Final audit: 9 converted, 0 drift, 0 genuine guardless. V7: converted gpioexpander + rpi-i2c; found B6 (stray `<<<<<<< HEAD` in gpioexpander Changes — Steve fixed it). V6: single-sourced the prose. V5: drift gate. V4: wiringpi-api shim. V3: BuildCheck (F2/F3). V2: classified. V1: audit script.
> **ARCHIVE:** See wiringpi-version-single-source-archive.md for completed V tasks (V1-V8)

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

### V2 classification — what each dist needs (2026-07-08, from the V1 audit)

The family is now **23 dists** (the "20 dists" list above predates three
pure-perl additions to this repo's PREREQ_PM: RPi::Accelerometer::ADXL335,
RPi::Gyro::MPU6050, RPi::Radar::RCWL0516). **All 23 are cloned locally now** —
the "only rpi-const / rpi-i2c / rpi-gpioexpander / wiringpi-api are local" note
above is stale; V1 read every Makefile.PL from a local clone with zero fetches.

Classified by what each dist's XS actually links/includes (Makefile.PL LIBS +
`.xs` #includes), not by the guard it happens to carry today:

| Dist | XS | Links / includes | NEEDS | Has now | V7/V8 action |
|------|----|------------------|-------|---------|--------------|
| wiringpi-api | yes | `-lwiringPi(Dev)`, wiringPi.h | wiringpi | wiringpi (canonical) | V4 reference shim |
| rpi-oled-ssd1306 | yes | `-lwiringPi`, wiringPi.h + wiringPiI2C.h | wiringpi | wiringpi (canonical, via const) | convert to shim |
| rpi-dac-mcp4922 | yes | `-lwiringPi`, wiringPi.h + wiringPiSPI.h | wiringpi | **NONE** | add wiringpi shim |
| rpi-hcsr04 | yes | `-lwiringPi -lrt`, wiringPi.h | wiringpi | **NONE** | add wiringpi shim |
| rpi-dht11 | yes | `-lwiringPi -lrt`, wiringPi.h | wiringpi | presence-only | upgrade to version shim |
| rpi-gpioexpander-mcp23017 | yes | linux/i2c-dev.h + linux/i2c.h | i2c | i2c | convert to i2c shim |
| rpi-adc-ads | yes | linux/i2c-dev.h (system) | i2c | **NONE** | add i2c shim |
| rpi-rtc-ds3231 | yes | linux/i2c-dev.h + linux/i2c.h (system) | i2c | **NONE** | add i2c shim |
| rpi-eeprom-at24c32 | yes | bundled i2c-dev.h + linux/fs.h | i2c | **NONE** | add i2c shim |
| rpi-i2c | yes | bundled i2c-dev.h + linux/types.h | i2c | **NONE** | add i2c shim |
| rpi-serial | yes | termios/fcntl/ioctl (POSIX) | none | none | none — standard-C XS, compiles anywhere |
| rpi-sysinfo | yes | sys/sysinfo.h (standard C) | none | none | none — standard-C XS, compiles anywhere |
| adc-mcp3008, accelerometer-adxl335, bmp180, const, digipot-mcp4xxxx, gyro-mpu6050, lcd, pin, radar-rcwl0516, spi, steppermotor (11) | no | pure perl (deps carry any guard) | none | none | none |

**Refinement of V1's flags:** V1 marked 8 dists "GUARDLESS XS", but only **6
actually need a guard** — `rpi-dac-mcp4922` + `rpi-hcsr04` (wiringpi) and
`rpi-adc-ads` + `rpi-rtc-ds3231` + `rpi-eeprom-at24c32` + `rpi-i2c` (i2c).
`rpi-serial` and `rpi-sysinfo` are XS but link nothing Pi-specific (pure POSIX /
standard C), so they compile on any tester — guardless is fine; they need
**none**. No dist needs **both**.

**Conversion worklist (fixes V7/V8):**
- **wiringpi shim:** rpi-dac-mcp4922, rpi-hcsr04 (add); rpi-dht11 (upgrade
  presence -> version); rpi-oled-ssd1306 (already consumes the const — swap to
  the shim); wiringpi-api is the V4 reference conversion.
- **i2c shim:** rpi-adc-ads, rpi-rtc-ds3231, rpi-eeprom-at24c32, rpi-i2c (add);
  rpi-gpioexpander-mcp23017 (convert its inline i2c check to the shim).
- **none (leave as-is):** rpi-serial, rpi-sysinfo + the 11 pure-perl dists.
- Because every family repo is now local, V7's local / V8's remote split
  collapses — V8 no longer needs to clone anything; both just apply the shim
  per this table.

**The 2.36 paste** (F1) came from **rpi-oled-ssd1306**'s Makefile.PL — Fix 1
(2026-07-05) already corrected it to 3.18 via RPi::Const, which is why V1 shows
it canonical.

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
| _(all V tasks complete — see archive)_ | | | | |

## Discovery Tracking

**Fix 1:** User-directed partial delivery ahead of V3/V4 (2026-07-05)
- The user asked for the constant immediately, without waiting for the
  BuildCheck module: `RPi::Const::WIRINGPI_MIN_VERSION` ('3.18') now exists
  (1.07 UNREL) and both versioned guard sites (wiringpi-api, rpi-oled-ssd1306
  — the F1 drift pair) consume it via eval-require with a 3.18 literal
  fallback. `rpi-const/REQ.md` catalogs every consuming/candidate file.
- Still open here: F2 (tuple compare — the guards still use version->parse),
  F3 (silent pass on unparseable gpio -v), V3's BuildCheck consolidation, and
  the V5 audit gate. V3/V4 should absorb the constant rather than a scalar
  (`$MIN_WIRINGPI_VERSION`) when they land.

## Review Findings

Defects found while researching this plan (the "issues like the paste"). Each maps to the V task that addresses it.

- **F1** (→V1, V8): Minimum-version drift across copies — the pasted Makefile.PL requires `2.36`, `wiringpi-api` requires `3.18`; the other ~16 XS dists are unaudited and likely stale.

- **F2** (→V3): ✅ RESOLVED (V3) — Wrong version comparison semantics — `version->parse($version) < $min` treats `3.8` as v3.800.0 > v3.180.0, so a Pi running wiringPi 3.8 **passes** a 3.18 minimum. wiringPi minors are integers (3.8 is ten releases older than 3.18); same false-pass class for `2.5` vs `2.36`. Needs integer (major, minor) tuple compare. [Fixed in `RPi::Const::BuildCheck::version_ge()` — integer (major,minor) tuple compare, test-pinned (3.8/3.17/2.36 fail, 3.18/3.20/4.0 pass). The inline `version->parse` in wiringpi-api/oled is retired as those dists convert to the shim, V4/V7/V8.]

- **F3** (→V3): ✅ RESOLVED (V3) — Silent pass when `gpio -v` output doesn't match `/version:\s+(\d+\.\d+)/` — the inner `if` has no `else`, so an unparseable output skips version validation entirely and the build proceeds against a possibly-too-old library. [Fixed in `RPi::Const::BuildCheck`: an unparseable or absent `gpio -v` now exits NA (not a silent pass), test-pinned. Retired from the inline guards as they convert, V4/V7/V8.]

- **F4** (→V2, V7, V8): ✅ RESOLVED (V7+V8) — Guard coverage is inconsistent — `rpi-i2c` is XS with **no** guard (CPAN testers without headers get FAIL, not NA); `rpi-gpioexpander-mcp23017` checks only i2c.h; no record exists of which dist needs which check. [V2 2026-07-08: the record now exists — the classification table in "Current known state" states each dist's needed check, refined the count of genuinely-guardless dists (rpi-serial/rpi-sysinfo are standard-C XS, not affected). V7 converted rpi-gpioexpander-mcp23017 + rpi-i2c; V8 converted rpi-oled-ssd1306, rpi-dac-mcp4922, rpi-hcsr04, rpi-dht11, rpi-adc-ads, rpi-rtc-ds3231. V8 also corrected the classification: rpi-eeprom-at24c32 bundles its own `i2c-dev.h` and needs NO guard (standard-C XS, like serial/sysinfo). Final audit: 9 converted, 0 drift, 0 genuine guardless-XS. Every XS dist that links wiringPi or includes a system i2c header now exits NA-not-FAIL through the canonical shim.]

- **F5** (→V5): ✅ RESOLVED (V5) — The duplication itself is structural — N hand-edited copies with no markers, no tooling, no drift detection, so divergence will recur without an audit gate. [Fixed: `scripts/audit-family-buildcheck.pl` is the tooling and `xt/author/buildcheck-audit.t` is the drift gate — it fails on any non-canonical minimum (proven by a live injected-2.36 edit to a clone) and keeps an explicit TODO list of unconverted dists that must shrink as V7/V8 land.]

- **F6** (→V6): ✅ RESOLVED (V6) — Prose version references (WiringPi.pm "v3.18", README/docs copies, FAQ's `RPI_DIST_RELEASE` section) are hand-maintained in parallel with the code copies — another drift surface. [Fixed: the prose now points at the single source rather than restating a literal — WiringPi.pm's v3.18 prose and FAQ.pod's `RPI_DIST_RELEASE` section name `RPi::Const/WIRINGPI_MIN_VERSION` + `RPi::Const::BuildCheck`, and a new FAQ entry documents where the version lives. Derived docs regenerated. The deeper fix is now also done (B2 ✅): `scripts/gen-min-version.pl` rewrites the "(currently 3.18)" parenthetical from the constant at regen time, and `xt/author/min-version-doc-sync.t` fails if it drifts — so even that literal can no longer go stale.]

## Backlog

B1: ✅ DONE (2026-07-08) — Expose the installed wiringPi library version at runtime. The primitive already existed (`WiringPi::API::wiringpi_version()`, wrapping the XS `wiringPiVersion(&maj,&min)`); B1 surfaces it. Chose **RPi::SysInfo** (the family's "what am I running" home) over `pidentify` (a LED-blink identify tool, not an info dump — and the value is already reachable on any `RPi::WiringPi` object via the inherited WiringPi::API primitive). Added `RPi::SysInfo::wiringpi_version()` (exported + method): reads the authoritative linked-library value via a **soft-loaded** WiringPi::API (not a hard prereq — SysInfo stays standalone), falling back to a `gpio -v` parse, else `''`. Added a "wiringPi" line to `pi_details()`. Tests: HW-free gpio-fallback + not-found cases in `t/50-helpers.t` (neutralised the library branch via `local $INC{...}`), and a wiringPi-line assertion in `t/40-pi_details.t`; full suite green on the Pi (built the local XS to clear the 1.02-vs-1.03 bootstrap mismatch), author POD tests green. Verified live: `wiringpi_version()` returns 3.18 as both function and method, and the pi_details line shows it.

B2: ✅ DONE (2026-07-08) — Interpolate the canonical minimum version into POD/README at regen time so prose can never drift from `$MIN_WIRINGPI_VERSION` (completes F6 beyond V6's manual fix). Added `scripts/gen-min-version.pl`: it resolves `RPi::Const::WIRINGPI_MIN_VERSION` (default @INC, then the sibling rpi-const checkout; dies rather than guess) and rewrites the `WIRINGPI_MIN_VERSION> (currently <ver>)` marker in `WiringPi.pm` + `FAQ.pod` — only there, so the unrelated callback-API "3.18" refs are untouched. Wired into `gen-pod-md.pl` before the pod2markdown pass so README.md/FAQ.md inherit it. Idempotent at 3.18 (verified: net-zero diff); proven to track drift by bumping the constant to 3.20 -> prose followed -> restored. Added `xt/author/min-version-doc-sync.t` (4 subtests) which fails if the committed prose drifts from the constant. `scripts/` is author-only (MANIFEST.SKIP `^scripts/`), so no MANIFEST change.

B3: ✅ DONE (2026-07-08) — Broaden library discovery beyond `/usr/include` + `/usr/local/include`. Both `wiringpi_build_check()` and `i2c_build_check()` now share a `_header_found()` helper: with no `include_dirs` given, it searches the two default prefixes and, on a miss, the C compiler's own `<...>` search path (parsed from `cc -E -Wp,-v` verbose output via `_compiler_include_dirs()`), so a header in a multiarch dir (e.g. `/usr/include/aarch64-linux-gnu`) or a non-default prefix is still found. Chose the compiler-probe over pkg-config (wiringPi ships no `.pc`) and Devel::CheckLib (would add a configure-time dependency; BuildCheck stays pure-perl). Best-effort — any failure yields an empty list, never a die — and fully injectable via new `cc`/`cc_output` opts; an explicit `include_dirs` still means the exact list with no probe (existing test semantics preserved). Added 6 tests to `t/55-buildcheck.t` (40 total); full rpi-const suite + author POD tests green. Verified the real probe on this Pi returns the multiarch dir the old list missed.

B4: ✅ DONE (2026-07-09) — Have Dist::Mgr template the shim into newly created RPi-family dists so future modules are born conformant. Added an **opt-in** `Dist::Mgr::add_buildcheck($type)` (`'wiringpi'`|`'i2c'`) that splices the family-canonical `RPi::Const::BuildCheck` guard shim into a new dist's `Makefile.PL` ahead of `WriteMakefile()` and adds `RPi::Const` to `CONFIGURE_REQUIRES` — mirroring the existing `add_bugtracker`/`add_repository` inserters. Idempotent (returns -1 if already present); **not** run by `init()`, so it never touches non-RPi dists. New `FileData.pm` templates (`_makefile_section_buildcheck` + `_makefile_section_buildcheck_configure`), private `_makefile_insert_buildcheck[_configure]` (creates a CONFIGURE_REQUIRES block if the skeleton lacks one). Wired into the `distmgr` CLI as `-k|--buildcheck <type>` for the `create`, `dist` and `install` commands (excluded from `--all`). Full docs: `Dist::Mgr.pod` head2, `distmgr.pod` + internal `help()` for all three commands. Tests: `t/16-add_buildcheck.t` (21 subtests — bad params, both variants, shim-before-WriteMakefile, generated file is valid Perl, idempotency), added to MANIFEST; full suite 2138 tests green, author manifest/pod/pod-coverage green. Verified the CLI live (`distmgr install --buildcheck=i2c` → valid guarded Makefile.PL). Repo: ~/repos/dist-mgr (uncommitted).

B5: ✅ DONE (2026-07-08) — rpi-bmp180 and rpi-digipot-mcp4xxxx are pure-perl (no XS) but their Makefile.PL still carried a vestigial `LIBS => ['-lwiringPi']` from a former XS incarnation (inert, but misleading). Dropped the stale LIBS from both (`perl -c` clean; zero XS confirmed). Bonus: fixed a duplicate `LICENSE` key in rpi-digipot's Makefile.PL (`'Perl_5'` then `'perl_5'` — kept the canonical lowercase). Per-dist Changes entries added. Discovered during V5.

B6: ✅ DONE (Steve, 2026-07-08) — `rpi-gpioexpander-mcp23017/Changes` had a stray, committed `<<<<<<< HEAD` git conflict marker at line 7 (dangling — no matching `=======`/`>>>>>>>`, coherent entries on both sides). Discovered during V7; flagged to Steve, who removed the lone marker line.

## Explicitly NOT doing

- **Putting the check in WiringPi::API and making it a `CONFIGURE_REQUIRES` of the other dists** — WiringPi::API is XS and only installs where wiringPi already exists, which turns configure-dep resolution into an install-ordering problem and muddies the NA semantics. The canonical holder must be pure perl.
- **Dropping configure-time checks in favor of a runtime-only check** — the exit-before-WriteMakefile behavior is what makes CPAN testers report NA instead of FAIL (per FAQ.pod); runtime checks can't replace that.
- **A dedicated new CPAN dist (e.g. RPi::BuildCheck) as the canonical home** — works identically, but adds a repo/dist to maintain for one constant and two functions; rpi-const already ships to every family install. Revisit only if Steve prefers strict separation of constants vs build policy.
- **Adding a wiringPi guard to this repo's (rpi-wiringpi) own Makefile.PL** — it is pure perl; its XS prereqs carry the guards, and a missing wiringPi already surfaces as NA through the dependency chain.
- **Committing or releasing anything on Steve's behalf** — per git rules, all commits and CPAN releases are his; V tasks stop at working-tree changes.
