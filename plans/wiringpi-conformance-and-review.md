# Plan: RPi sibling API-conformance to new WiringPi::API + rpi-wiringpi review

> **NEXT ACTION:** V24 — version bump 3.1801_01→3.1802 in 4 modules + reconcile Makefile.PL WiringPi::API prereq (F15); note release-ordering caveat (installed API is trial 3.1802_01).
> **LAST SESSION:** V23 done — all 5 HIGH bugs fixed in Core.pm/WiringPi.pm (F16 SUPER::gpio_layout, F17 pwm_mode getter + in-use mark moved to set path, F18 `||` guard, F19 per-uuid pin cleanup, F42 defined-check on RPI_PIN_MODE). Changes updated (5 entries). Verified: 331 tests pass (t/100/105/106/110/150/153 + more); live root checks of F16/F17/F18/F42 all green. t/109+t/140 still skip on RPI_I2C (F35→V29; ADS1115 dark per V10 note). Uncommitted.
> **ARCHIVE:** See wiringpi-conformance-and-review-archive.md for completed V1-V14, V20-V23, V31

## Context

Two pieces of work, one plan.

**Part A — sibling conformance.** `~/repos/wiringpi-api` (WiringPi::API, now v3.1802) was restructured: exports are grouped into tags `:wiringPi` (camelCase C wrappers), `:perl` (snake_case wrappers), `:constants`, `:all`; **all constants are now single-sourced from `RPi::Const`**; and some old symbols were dropped (`setup_sys`/`setup_phys`, `serial_printf`, `testChar`). The legacy constant module **`RPi::WiringPi::Constant` no longer exists** in rpi-wiringpi's `lib/` (only `Core`/`Util`/`Meta`/`WiringPi` remain). Per the user, "conform" means **only** that each sibling's Perl/XS/C code still *works* against the new WiringPi::API — no tooling/version/POD/style changes. Of the 19 siblings, **8 consume WiringPi::API at the Perl level**, **1 uses RPi::Const only**, **2 link libwiringPi C directly via their own XS**, and the rest are independent (confirm-only).

**Part B — rpi-wiringpi review.** Review all documentation, Perl code, and tests (no XS lives here; C is in WiringPi::API) for bugs, intent mismatches, and improvements. Findings are catalogued as `F#` and promoted to fix `V#` tasks.

Empirical conformance check for Part A = build + run each dependent sibling's test suite on the Pi against the *installed* new WiringPi::API/RPi::Const, plus a static import/call audit. Tests gate on env vars per memory: prefix with `PI_BOARD=1 RPI_OBJECT_COUNT=<n>` (and device-specific `RPI_*`) as needed; reset pins first if "default mode" failures appear.

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of wiringpi-conformance-and-review-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
  3. **Delete the V# row from this file's Validation Table.**
- V task ❌: update Actual with `❌ YYYY-MM-DD attempt N: reason`. Rerun same V# with attempt N+1. Do NOT create a new V#.
- **Sync review findings** — when a V task (or a Fix) resolves a review finding, mark its `F#` entry in `## Review Findings` **in place**: prefix `✅ RESOLVED (V#)` (or `✅ VALIDATED (V#)` if no code change was needed, or `⏸ DEFERRED → B#` if punted to backlog). Findings are a permanent audit ledger — mark in place; never archive, delete, or renumber them.
- Update ARCHIVE pointer to reflect what's archived (e.g., `V1-V2` → `V1-V3`)
- Update NEXT ACTION to next ⏳ row; update LAST SESSION
- Never renumber within a series. New items get next free number.
- **Discovery triage during V# work** — when you find something while working a V task, classify before continuing:
  - Blocks the current V task → add `Fix N: problem discovered during V# — [what + fix]` to `## Discovery Tracking`; resolve as part of this V task's work.
  - Real bug but doesn't block this V task → add a new V# row (next free) to the Validation Table with ⏳; do not detour to fix it now.
  - Non-blocking improvement → add new B# to `## Backlog` (one `B#` per line, each separated by a blank line).
  - Decided not to do → add to `## Explicitly NOT doing` with a one-line justification.
- Move resolved fixes to archive's "Archived Fixes" section; keep only unresolved in main Discovery Tracking
- To promote a backlog item to an active task: assign it the next free V# and move to the Validation Table. The B# slot is retired and never reused.

## Validation Table

| ID | What | Command | Expected | Actual |
|----|------|---------|----------|--------|
| V24 | **Version bump** — set `$VERSION` `3.1801_01`→`3.1802` in WiringPi.pm/Core.pm/Util.pm/Meta.pm; reconcile `Makefile.PL` `WiringPi::API` prereq (F15). **Caveat:** installed reference is `3.1802_01` (a *trial* with underscore); rpi-wiringpi 3.1802 cannot be released against a dev-only API CPAN can't index — a non-trial WiringPi::API must ship first | `cd ~/repos/rpi-wiringpi && grep -rn "3.1801_01" lib/` | All four modules at 3.1802; prereq reconciled; release-ordering noted | ⏳ |
| V25 | **Constify magic defaults** (F10) — Core.pm `1023`→`PWM_DEFAULT_RANGE` (the `#FIXME: add const` at ~line 115) and `pwm_mode` fallback `1`→`PWM_DEFAULT_MODE` | `cd ~/repos/rpi-wiringpi && PI_BOARD=1 RPI_OBJECT_COUNT=<n> prove -bl t/109*` | No magic numbers; tests pass | ⏳ |
| V26 | **Robustness fixes** in rpi-wiringpi: meta lock not exception-safe → stale lock (F20), `meta_get` conditional-`my` UB (F21), signal handlers never restored / non-CODE dispositions dropped / leak (F22), `_fatal_exit` process-global last-writer-wins (F23), `io_led`/`pwr_led` backtick `sudo` with no error check (F24) | `cd ~/repos/rpi-wiringpi && PI_BOARD=1 RPI_OBJECT_COUNT=<n> prove -bl t/03* t/100* t/150* t/153*` | Lock guaranteed-release; handlers restored; led failures surfaced; tests pass | ⏳ |
| V27 | **README + generated md regen** — regenerate README from current WiringPi.pm POD (fixes stale signal/cleanup/version/`new()` text, F25) and run `perl scripts/gen-pod-md.pl` to refresh stale `docs/pod/WiringPi.md` + `FAQ.md` (F14) | `cd ~/repos/rpi-wiringpi && perl scripts/gen-pod-md.pl && git status` | README matches POD; pod/*.md in sync | ⏳ |
| V28 | **POD source fixes** — broken example-doc paths in INTERRUPTS.pod/FAQ.pod (F26), invalid `RPi::WiringPi;` constructor in Meta.pm/FAQ (F27), `my gps`/`$ruler`/`$sensor` example errors (F28), Meta.pm missing `=head1 AUTHOR` (F29), `oled()` undocumented 3rd param (F30), `pwm_mode` 0/1 mapping vs constants (F31), RPi::Pin 2.3609 `background_interrupt` caveat (F32) | `cd ~/repos/rpi-wiringpi && RPI_RELEASE_TESTING=1 RPI_POD=1 prove -bl t/500* t/505* t/510*` | POD examples valid; links resolve; POD tests pass | ⏳ |
| V29 | **Test correctness fixes** — `RPI_ARUDINO`→`RPI_ARDUINO` skip msg (F11), `920-oled_cleanup.t` `/tmp`→`/dev/shm` vacuous-pass (F33), restore pins 12/26 to reset tables so CS pins are reset-verified (F12) + make `rpi_verify_pin_status` report the offending pin (F34), auto-set `RPI_I2C` (or document) so root runs don't silently skip PWM/servo (F35) | `cd ~/repos/rpi-wiringpi && PI_BOARD=1 RPI_OBJECT_COUNT=<n> prove -bl t/300* t/920* t/01*` | Typo fixed; 920 verifies real path; 12/26 covered; root gating consistent | ⏳ |
| V30 | **Test robustness** — adopt the `t/325` eval+idempotent-cleanup+INT/TERM guard (or `END { $pi->cleanup }`) in device tests that leak on death (F36); document the serial-only `-j1` requirement given shared `shm_key 'rpit'` + fixed pins (F37) | `cd ~/repos/rpi-wiringpi && PI_BOARD=1 RPI_OBJECT_COUNT=<n> prove -bl t/310* t/335* t/345* t/305* t/925*` | Cleanup runs on failure; serial requirement documented; tests pass | ⏳ |
| V32 | **`new()` `setup` param** (F47) — make `:50`/`:54`/`:58` match `^w`/`^g`/`^n`(one) **case-insensitively** and croak on truly-unrecognized values (do NOT blanket-croak — `'none'` is the intended uninit sentinel the suite uses); document `setup` (w/g/none + default) in WiringPi.pm POD | `cd ~/repos/rpi-wiringpi && PI_BOARD=1 RPI_OBJECT_COUNT=<n> prove -bl t/106*` + grep POD for `setup` | Unrecognized croaks; `'none'`/`'GPIO'`/`'Gpio'` all work; documented | ⏳ |
| V33 | **Residual exhaustive pass** (F46) — full per-file line-by-line read of all 69 `t/*.t`, AND an exhaustive re-read of the large modules `WiringPi.pm` (~1290 lines) + `Core.pm` (~649) since the single-pass review proved non-exhaustive (yielded F22/F23/F42/F47) | manual review pass; append any new F# | No further material findings, or new F# logged | ⏳ |

## Discovery Tracking

_None yet._

## Review Findings

Permanent audit ledger. Mark in place as resolved; never renumber.

**Part A — sibling conformance (verified during exploration):**
- ✅ RESOLVED (V2) **F1** (→V2): `rpi-spi/lib/RPi/SPI.pm:6` imports `qw(:wiringPi)` but lines 21–22 call `pin_mode()`/`write_pin()` (snake_case `:perl` tag) — undefined subs whenever a GPIO CS is used (bit-bang mode).
- ✅ RESOLVED (V3) **F2** (→V3): `rpi-adc-mcp3008/lib/RPi/ADC/MCP3008.pm:11` `use RPi::WiringPi::Constant qw(:all)` — legacy module removed from ecosystem (see F5).
- ✅ RESOLVED (V3) **F3** (→V3): `rpi-adc-mcp3008 MCP3008.pm:21` calls `wpi_setup()` — not present in new WiringPi::API (no `:wiringPi`/`:perl` member); use `setup_gpio()`/`wiringPiSetupGpio()`.
- ✅ RESOLVED (V3) **F4** (→V3): `rpi-adc-mcp3008 MCP3008.pm:25` calls `spi_setup()` (`:perl`) under a `:wiringPi`-only import — undefined sub.
- ✅ RESOLVED (V3-V6) **F5** (→V3–V6): `RPi::WiringPi::Constant` no longer ships in rpi-wiringpi `lib/`; siblings still importing it (rpi-adc-mcp3008 confirmed; rpi-bmp180/rpi-dac-mcp4922/rpi-digipot-mcp4xxxx flagged by usage map) must migrate to `RPi::Const`. **NOTE (baseline check):** a stale `RPi::WiringPi::Constant` v1.02 is *still installed* on the Pi even though it's no longer in rpi-wiringpi's source — so these siblings load today and the breakage is currently *masked*. They remain non-conforming and will break the moment that leftover copy is removed. Installed reference set: WiringPi::API 3.1802_01, RPi::Const 1.05. **Verified (debate, executed):** live diff of legacy `RPi::WiringPi::Constant` 1.02 vs `RPi::Const` 1.05 → all 31 legacy names present, **0 value diffs** (ALT*/EDGE_*/PWM_*; `EDGE_FALLING==INT_EDGE_FALLING==1`); rpi-bmp180/rpi-dac-mcp4922/rpi-digipot-mcp4xxxx confirmed line-by-line on the legacy module.
- ✅ RESOLVED (V7) **F6** (→V7): `rpi-pin/lib/RPi/Pin.pm:~128` calls `WiringPi::API::background_interrupt(...)`; interrupt subsystem was reworked (split BackgroundInterrupt classes, new return-handle semantics) — verify call site matches new contract. **Verified-at-source (debate):** `Pin.pm:128,155` `set_interrupt`/`background_interrupt` call sites match the new API (still confirm under build/test in V7).
- ⏸ DEFERRED → B1 **F7** (→V13/backlog): several siblings declare an old `WiringPi::API` minimum (2.36xx) in Makefile.PL; satisfied numerically by 3.1802 but understates the real requirement. Tracked as B1 (out of strict scope).

**Part B — rpi-wiringpi review (V20–V22 complete; findings below).** Severity in brackets.

_Seeded findings, confirmed/refined by review:_
- **F10** [low] (→V25): `Core.pm:115` `#FIXME: add const` — magic `1023` default should be `PWM_DEFAULT_RANGE` (RPi::Const, == 1023). Same smell at `pwm_mode` fallback `: 1` (→ `PWM_DEFAULT_MODE`). Value is correct; constify for consistency.
- **F11** [low] (→V29): `t/300-i2c_exceptions.t:19` skip message says `RPI_ARUDINO` though the gate (line 18) correctly reads `RPI_ARDUINO` — diagnostic tells user to set a nonexistent var.
- **F12** [med] (→V29): `t/RPiTest.pm:258,273,291,306,326,341` delete GPIO 12 & 26 from every board's `rpi_default_pin_config` with a bare `#FIXME` — so `rpi_verify_pin_status` never reset-checks them. But 12 = MCP4922 DAC CS and 26 = MCP3008 ADC CS (per `docs/test-platform/test-pinout-doc.md:56,70`), actively driven by t/310/335 — i.e. the two pins most likely left asserted are the two excluded. **Root cause of the "stale hardware state" failures.** Restore real idle values or document + add targeted assertion.
- **F13** [low] (→backlog B8): `PI_BOARD`/`PI_INTERRUPT` use the `PI_` prefix vs the prevailing `RPI_*`. Verified **no dead gate** — purely cosmetic. Normalize only in a future major with back-compat.
- **F14** [med] (→V27): `docs/pod/WiringPi.md:342` and `docs/pod/FAQ.md:134` are stale vs source POD (e.g. md still has old serial NOTE; FAQ md keeps a `ram=i2c_arm` typo since fixed to `dtparam=i2c_arm` in source). Core/Util/Meta/INTERRUPTS/WORKERS md are in sync. Run `scripts/gen-pod-md.pl`.
- **F15** [med] (→V24): `$VERSION = '3.1801_01'` in all four lib modules (WiringPi.pm:15, Core.pm:16, Util.pm:15, Meta.pm:11) while `Changes` top is `3.1802 UNREL`. Since `Makefile.PL` uses `VERSION_FROM` the dist would ship as trial 3.1801_01. Also confirm `Makefile.PL:65` `WiringPi::API => 3.1801` prereq is intended.

_New code findings (V21):_
- ✅ RESOLVED (V23) **F16** [HIGH] (→V23): `Core.pm:18-20` `gpio_layout()` calls `$_[0]->gpio_layout` — unbounded self-recursion; never reaches `WiringPi::API`'s impl. Use `SUPER::gpio_layout`/fully-qualified call.
- ✅ RESOLVED (V23) **F17** [HIGH] (→V23): `Core.pm:141-147` `pwm_mode()` getter form croaks — when `$mode` is undef the `else` fires. POD documents it as set/get; only validate when defined.
- ✅ RESOLVED (V23) **F18** [HIGH] (→V23): `Core.pm:379` `_pwm_in_use` early-returns on `! pins && ! register` where every sibling guard uses `|| `. With `rpi_register_pins=>0, rpi_register=>1` it still writes `pwm.users` but `cleanup` (gated on `_rpi_register_pins`) never clears it → stale PWM-in-use leak. Match the `||` form.
- ✅ RESOLVED (V23) **F19** [med→HIGH] (→V23): `Core.pm:223-229` `cleanup` deletes a shared pin from meta for ALL co-owners once the calling object is one user, silently dropping other uuids' registration (the PWM path above does it correctly per-uuid). Delete only `{users}{$self->uuid}`, reset/remove pin only when no users remain.
- **F20** [med] (→V26): `Meta.pm:100-136` + callers — `meta_lock` (LOCK_EX) then straight-line fetch/mutate/store; a die between (encode/decode croak, segment-overflow croak, registration croak) skips `meta_unlock`, holding the exclusive lock indefinitely across processes. Wrap critical section so unlock always runs.
- **F21** [med] (→V26): `Meta.pm:159` `my $data = {...} if exists ...;` — `my`-with-statement-modifier is Perl UB; value can leak across calls. Split declaration from the conditional assignment.
- **F22** [med] (→V26): `WiringPi.pm:464-487,406-439` signal handlers: installed once and **never restored** (not in cleanup/DESTROY/END) so the class handler outlives all objects; only CODE-ref previous handlers are chained (`'IGNORE'`/`'DEFAULT'`/named-sub dispositions silently dropped); `%sig_handlers` closures leak transient objects. Restore `$SIG{$sig}` to prev (incl. non-CODE) when `%sig_handlers{$sig}` empties; delete entries in cleanup.
- **F23** [med] (→V26): `WiringPi.pm:454-463` `_fatal_exit` writes the package-global `$fatal_exit`, so `new(fatal_exit=>0)` on a second object flips it for ALL objects (the signal path reads the global, not `$self->{fatal_exit}`). Make per-object or document as process-global.
- **F24** [med] (→V26): `Core.pm:42-51,61-66` `io_led`/`pwr_led` use backtick `... | sudo tee ...` with no exit-status check — a failing sudo silently no-ops while `identify()` reports success; STDERR leaks; shell-interpolation-shaped. Mirror the `system(...) != 0` checking already in `_restore_pin_alt:366-369`.
- **F38** [low] (→backlog B6): `Util.pm:29` compares scheme with `eq RPI_MODE_UNINIT` while `Core.pm:80-87` uses `==` on the same env-sourced value — inconsistent; pick numeric `==` (enums).
- **F39** [low] (→backlog B5): `bin/pinmap:18-22,28-31` `$wpi == -1` warns when `pin_map` returns undef; guard `next if ! defined $wpi || $wpi == -1`. Also `bin/pimetaerase:21-22` cosmetic `//=`/spacing.
- **F40** [info] (→backlog B7): diamond inheritance (Meta reached via Core's branch) works today (DFS dedups, no conflicting overrides) but is latent — document intended MRO or adopt `use mro 'c3'` before adding any cross-branch override. (uuid-collision loop `WiringPi.pm:81-85` reviewed — acceptable, no action.)

_New documentation findings (V20):_
- **F25** [HIGH] (→V27): `README` is a stale `pod2text` of a much older WiringPi.pm (~826 lines behind) — missing INTERRUPT/worker/eeprom/oled/pi_model methods and `shm_key`/`rpi_register*` params; `README:323-326` states the OPPOSITE of current signal behavior (claims it traps `$SIG{__DIE__}`; code explicitly does not); `README:317` says wiringPi 2.36+ (now 3.18). Regenerate from current POD.
- **F26** [med] (→V28): `INTERRUPTS.pod:13,17,269` (and FAQ.pod) point to `docs/threads-examples.md`/`docs/interrupt-examples.md` but files live under `docs/examples/`. Broken cross-refs.
- **F27** [med] (→V28): `Meta.pm:200` and `FAQ.pod:1200` `my $pi = RPi::WiringPi;` — bareword, not an object; should be `RPi::WiringPi->new`.
- **F28** [med/low] (→V28): `FAQ.pod:883` `my gps = $pi->gps;` (missing sigil, won't compile); `FAQ.pod:1021-1025` HCSR04 example assigns `$ruler` but uses `$sensor`.
- **F29** [low] (→V28): `Meta.pm:365` AUTHOR line has no preceding `=head1 AUTHOR` (renders as stray paragraph; fails section conventions).
- **F30** [low] (→V28): `WiringPi.pm:213-214` `oled($model,$i2c_addr,$display_splash_page)` — 3rd param undocumented in the `=head2 oled` POD (`:763-782`).
- **F31** [low] (→V28): `Core.pm:542-558` POD "0=Mark-Space / 1=Balanced" vs code validation using `PWM_DEFAULT_MODE`; verify `PWM_MODE_MS`/`PWM_MODE_BAL`/`PWM_DEFAULT_MODE` numeric values and make POD match.
- **F32** [med] (→V28): `INTERRUPTS.pod:112` & `WiringPi.pm:1214` say RPi::Pin "(as of 2.3608)… `background_interrupt` not yet available" but `Makefile.PL:59` now requires RPi::Pin 2.3609 — confirm whether it now ships and update/remove the caveat.

_New test findings (V22):_
- **F33** [med] (→V29): `t/920-oled_cleanup.t:19` checks `-e '/tmp/oled_unavailable.rpi-wiringpi'` but the lock is at `/dev/shm/...` (RPiTest.pm:46) — the test passes vacuously, never verifying the lock was removed.
- **F34** [med] (→V29): `t/RPiTest.pm:198-203` `rpi_verify_pin_status` returns 0 on first mismatch without saying which pin; combined with F12 it can't see 12/26. Report the offending pin via `note()`.
- **F35** [med] (→V29): `t/140-pwm_spi_adc.t`, `t/109-pwm_hw_mods.t`, `t/325-servo.t` set PI_BOARD/RPI_ADC/RPI_SERVO under root but then `rpi_i2c_check()` skips unless `RPI_I2C` (the ADS1115 feedback is I2C) — `RPI_I2C` is not auto-set, so root runs silently skip these. Auto-set or document.
- **F36** [med] (→V30): only `t/325-servo.t:66-75` guards cleanup with eval+INT/TERM; other device tests (t/310/335/345/305/925) skip `$pi->cleanup` if an assertion dies mid-loop, leaking pin/CS registration into shared meta. Adopt the guard or `END { $pi->cleanup if $pi }`.
- **F37** [med] (→V30): all tests share `shm_key 'rpit'` and many drive the same physical pins (GPIO18 in 12+ tests; 12/26 in several), and t/110-114 assert absolute object/pin counts — the suite is implicitly serial-only; `prove -j` would corrupt counts and fight over pins. Document the `-j1` requirement.
- (low/cosmetic test items folded to backlog: B9 `PI_INTERRUPT` in-process counter naming, B10 pod tests double-gated on `RPI_RELEASE_TESTING`+`RPI_POD`, B11 t/109↔t/140 near-duplicate with divergent acceptance bands, B12 fixed-`sleep` brittleness → poll-until loops.)

_From the completeness debate (challenger Claude Fable 5, executed checks; see proposal/wiringpi-plan-completeness-audit.md):_
- ✅ RESOLVED (V31) **F41** [RELEASE-BLOCKING] (→V31): `MANIFEST:40,46,151` list `docs/interrupt-examples.md`, `docs/threads-examples.md`, `t/README` — none exist (`ls` fails on all three; the two examples moved to `docs/examples/`, which are NOT in MANIFEST). `make distdir`→`manicopy` croaks → the 3.1802 tarball can't be cut, and post-F26 the POD links point at files the tarball wouldn't ship. Same file-move as F26. Verified by originator.
- ✅ RESOLVED (V23) **F42** [HIGH] (→V23): `WiringPi.pm:38` `if (my $scheme = $ENV{RPI_PIN_MODE})` — `RPI_MODE_WPI == 0` (verified live) is the only falsy scheme, so after a first object's `setup=>'w'` (`:52`/`:65` write `"0"`), a second `new()` reads false, runs `setup_gpio()`, restamps GPIO — every WPI pin silently reinterpreted as BCM. `Core.pm:97-98` uses `defined` correctly. Was missed in a fully-reviewed file. Verified by originator.
- **F43** [med→backlog B13] (→B13): `DHT11.xs:187-189` / `HCSR04.xs:23-25` `char modeEnvVar[20]; sprintf(...); putenv(modeEnvVar);` — putenv stores the pointer; the stack buffer dies on return; next `getenv("RPI_PIN_MODE")` reads freed stack. Pre-existing, NOT a 3.18 regression; fires only when `RPI_PIN_MODE` was already set (multi-dist/dual-sensor rig).
- ✅ VALIDATED (V14) **F44** [structural] (→V14): `rpi-const`, the 19th sibling and the dependency root the migration single-sources from, had no row. Confirm-only (debate: repo 1.05 == installed 1.05, zero drift).
- **F45** [executed — nothing material] (→done, 2 notes→B14): generator scripts (`gen-test-platform.pl`, `gen-pod-md.pl`, `gen-pdf.py`, `gen-pinout-images.py`) + `build_testing/*` reviewed CLEAN. Notes: `scripts/helpers/gen-schematic.py:145,225` bare `open(path,'w').write(...)` (no context manager / no error handling) [low → B14]; `Changes` 2.3633 chronology oddity (stable stanza dated 2019-09-19 before trials `_02`/`_03`) [info, historical only].
- **F46** [open residual] (→V33): the full per-file pass over all 69 `t/*.t` was NOT completed (≈10 more sampled, nothing new), AND the single-pass review of the large modules (`WiringPi.pm`, `Core.pm`) is demonstrably non-exhaustive (it yielded F22/F23/F42/F47). Tracked by V33.
- **F47** [med code + med doc] (→V32): `new()` `setup` param — `WiringPi.pm:50 =~ /^w/i` vs `:54 =~ /^g/` (no `/i`) → `'GPIO'`/`'Gpio'` fall through; `:58-60` else stamps `RPI_MODE_UNINIT` with no setup/croak (any typo silently no-ops the board); and `setup` is documented nowhere (0 in WiringPi.pm POD past `__END__:523`, 0 in FAQ.pod) yet public and used by the suite (`t/106-pin_map.t:13`, `setup => 'none'`). Fix must whitelist `w`/`g`/`none` case-insensitively (don't break `'none'`) and document the three forms.

## Backlog

B1: Bump siblings' declared `WiringPi::API`/`RPi::Const` minimum versions in Makefile.PL to the real new minimums (out of strict "code must work" scope; correctness/metadata hygiene).

B5: `bin/pinmap` undef-guard before `== -1` and `bin/pimetaerase` cosmetic `//=`/spacing (F39).

B6: Make `pin_scheme` comparisons consistently numeric `==` across Util.pm/Core.pm (F38).

B7: Document the intended MRO of the 4-level diamond inheritance, or adopt `use mro 'c3'` before any cross-branch method override (F40).

B8: Normalize `PI_BOARD`/`PI_INTERRUPT` → `RPI_*` prefix in a future major version with back-compat (F13).

B9: Rename the in-process `$ENV{PI_INTERRUPT}` callback counter (t/200–209) to a lexical to stop implying it's an env gate.

B10: Drop the redundant `rpi_pod_check()`/`RPI_POD` second gate from t/500/505/510 so `RPI_RELEASE_TESTING` alone enables POD checks (or document the dual requirement).

B11: Cross-reference / reconcile the near-duplicate PWM tests t/109 (asserts below MAX_IN) vs t/140 (asserts per-PWM windows) so a recalibration updates both.

B12: Replace fixed `select`/`sleep` settle windows in interrupt/I2C tests (t/203/210/305/330/925/325) with poll-until-condition loops bounded by a timeout (as t/206/208 already do).

B13: Fix the `putenv()` stack-buffer UB in `DHT11.xs`/`HCSR04.xs` (F43) — use a static/heap buffer or `setenv()` so `environ` doesn't dangle. Pre-existing, not a 3.18 regression.

B14: `scripts/helpers/gen-schematic.py:145,225` — wrap output writes in a context manager with error handling instead of bare `open(path,'w').write(...)` (F45 note).

B15: rpi-pin t/15-pwm.t + t/40-interrupt_and_pud.t re-exec via `system('sudo', 'perl', $0)` when not root — bare `sudo perl` resolves to the system perl (no perlbrew/blib) and dies with "Can't locate RPi/Pin.pm". Use `$^X` and propagate -Iblib paths/env, or document that the suite must run as root (discovered during V7).

## Explicitly NOT doing

- Tooling/hygiene conformance (.claude/, .gitignore, CLAUDE.md, CI, and **siblings'** MANIFEST/MANIFEST.SKIP) — user scoped sibling conformance to code-compatibility only. **NOTE:** this exclusion does NOT cover rpi-wiringpi's own `MANIFEST`, which has a release-blocking defect tracked as F41/V31 (in scope).
- Version-scheme renumbering or POD/style normalization of siblings — out of scope per user.
- Touching independent siblings' functionality beyond confirming they don't couple to wiringPi (V13).
