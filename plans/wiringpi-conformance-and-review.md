# Plan: RPi sibling API-conformance to new WiringPi::API + rpi-wiringpi review

> **NEXT ACTION:** 🤚 V24 (USER) is the only open task — all Claude-owned V tasks are complete. Backlog B8, B15-B16 remains (numeric order per user directive 2026-06-11; B8 skipped — deferred to the future major version — so B15 is next, in the rpi-pin sibling).
> **LAST SESSION:** V44 done (B14 promoted; F45 note) — gen-schematic.py's two bare `open(path,'w').write(...)` sites now use `with open(...)` + OSError → clean `sys.exit` message; `import sys` added. Verified: py_compile clean; scratch-dir run wrote all 6 outputs through the new writers; no-t/-dir run exits 1 with the clean message (no traceback). No Changes entry — scripts/ is dev tooling excluded from the dist via MANIFEST.SKIP. Uncommitted.
> **ARCHIVE:** See wiringpi-conformance-and-review-archive.md for completed V1-V14, V20-V23, V25-V44 (less 🤚V24)

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
| V24 | **Version bump** — set `$VERSION` `3.1801_01`→`3.1802` in WiringPi.pm/Core.pm/Util.pm/Meta.pm; reconcile `Makefile.PL` `WiringPi::API` prereq (F15). **Caveat:** installed reference is `3.1802_01` (a *trial* with underscore); rpi-wiringpi 3.1802 cannot be released against a dev-only API CPAN can't index — a non-trial WiringPi::API must ship first | `cd ~/repos/rpi-wiringpi && grep -rn "3.1801_01" lib/` | All four modules at 3.1802; prereq reconciled; release-ordering noted | 🤚 USER — Steve will do this manually once all libraries are up to date. Claude: do NOT execute; skip to next ⏳ |

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
- ✅ RESOLVED (V35) **F7** (→V13/backlog): several siblings declare an old `WiringPi::API` minimum (2.36xx) in Makefile.PL; satisfied numerically by 3.1802 but understates the real requirement. Tracked as B1; promoted to V35 and resolved — all 9 declaring siblings bumped to `WiringPi::API 3.1803` / `RPi::Const 1.05`.

**Part B — rpi-wiringpi review (V20–V22 complete; findings below).** Severity in brackets.

_Seeded findings, confirmed/refined by review:_
- ✅ RESOLVED (V25) **F10** [low] (→V25): `Core.pm:115` `#FIXME: add const` — magic `1023` default should be `PWM_DEFAULT_RANGE` (RPi::Const, == 1023). Same smell at `pwm_mode` fallback `: 1` (→ `PWM_DEFAULT_MODE`). Value is correct; constify for consistency.
- ✅ RESOLVED (V29) **F11** [low] (→V29): `t/300-i2c_exceptions.t:19` skip message says `RPI_ARUDINO` though the gate (line 18) correctly reads `RPI_ARDUINO` — diagnostic tells user to set a nonexistent var.
- ✅ RESOLVED (V29) **F12** [med] (→V29): `t/RPiTest.pm:258,273,291,306,326,341` delete GPIO 12 & 26 from every board's `rpi_default_pin_config` with a bare `#FIXME` — so `rpi_verify_pin_status` never reset-checks them. But 12 = MCP4922 DAC CS and 26 = MCP3008 ADC CS (per `docs/test-platform/test-pinout-doc.md:56,70`), actively driven by t/310/335 — i.e. the two pins most likely left asserted are the two excluded. **Root cause of the "stale hardware state" failures.** Restore real idle values or document + add targeted assertion.
- **F13** [low] (→backlog B8): `PI_BOARD`/`PI_INTERRUPT` use the `PI_` prefix vs the prevailing `RPI_*`. Verified **no dead gate** — purely cosmetic. Normalize only in a future major with back-compat.
- ✅ RESOLVED (V27) **F14** [med] (→V27): `docs/pod/WiringPi.md:342` and `docs/pod/FAQ.md:134` are stale vs source POD (e.g. md still has old serial NOTE; FAQ md keeps a `ram=i2c_arm` typo since fixed to `dtparam=i2c_arm` in source). Core/Util/Meta/INTERRUPTS/WORKERS md are in sync. Run `scripts/gen-pod-md.pl`.
- **F15** [med] (→V24): `$VERSION = '3.1801_01'` in all four lib modules (WiringPi.pm:15, Core.pm:16, Util.pm:15, Meta.pm:11) while `Changes` top is `3.1802 UNREL`. Since `Makefile.PL` uses `VERSION_FROM` the dist would ship as trial 3.1801_01. Also confirm `Makefile.PL:65` `WiringPi::API => 3.1801` prereq is intended.

_New code findings (V21):_
- ✅ RESOLVED (V23) **F16** [HIGH] (→V23): `Core.pm:18-20` `gpio_layout()` calls `$_[0]->gpio_layout` — unbounded self-recursion; never reaches `WiringPi::API`'s impl. Use `SUPER::gpio_layout`/fully-qualified call.
- ✅ RESOLVED (V23) **F17** [HIGH] (→V23): `Core.pm:141-147` `pwm_mode()` getter form croaks — when `$mode` is undef the `else` fires. POD documents it as set/get; only validate when defined.
- ✅ RESOLVED (V23) **F18** [HIGH] (→V23): `Core.pm:379` `_pwm_in_use` early-returns on `! pins && ! register` where every sibling guard uses `|| `. With `rpi_register_pins=>0, rpi_register=>1` it still writes `pwm.users` but `cleanup` (gated on `_rpi_register_pins`) never clears it → stale PWM-in-use leak. Match the `||` form.
- ✅ RESOLVED (V23) **F19** [med→HIGH] (→V23): `Core.pm:223-229` `cleanup` deletes a shared pin from meta for ALL co-owners once the calling object is one user, silently dropping other uuids' registration (the PWM path above does it correctly per-uuid). Delete only `{users}{$self->uuid}`, reset/remove pin only when no users remain.
- ✅ RESOLVED (V26) **F20** [med] (→V26): `Meta.pm:100-136` + callers — `meta_lock` (LOCK_EX) then straight-line fetch/mutate/store; a die between (encode/decode croak, segment-overflow croak, registration croak) skips `meta_unlock`, holding the exclusive lock indefinitely across processes. Wrap critical section so unlock always runs.
- ✅ RESOLVED (V26) **F21** [med] (→V26): `Meta.pm:159` `my $data = {...} if exists ...;` — `my`-with-statement-modifier is Perl UB; value can leak across calls. Split declaration from the conditional assignment.
- ✅ RESOLVED (V26) **F22** [med] (→V26): `WiringPi.pm:464-487,406-439` signal handlers: installed once and **never restored** (not in cleanup/DESTROY/END) so the class handler outlives all objects; only CODE-ref previous handlers are chained (`'IGNORE'`/`'DEFAULT'`/named-sub dispositions silently dropped); `%sig_handlers` closures leak transient objects. Restore `$SIG{$sig}` to prev (incl. non-CODE) when `%sig_handlers{$sig}` empties; delete entries in cleanup.
- ✅ RESOLVED (V26) **F23** [med] (→V26): `WiringPi.pm:454-463` `_fatal_exit` writes the package-global `$fatal_exit`, so `new(fatal_exit=>0)` on a second object flips it for ALL objects (the signal path reads the global, not `$self->{fatal_exit}`). Make per-object or document as process-global.
- ✅ RESOLVED (V26) **F24** [med] (→V26): `Core.pm:42-51,61-66` `io_led`/`pwr_led` use backtick `... | sudo tee ...` with no exit-status check — a failing sudo silently no-ops while `identify()` reports success; STDERR leaks; shell-interpolation-shaped. Mirror the `system(...) != 0` checking already in `_restore_pin_alt:366-369`.
- ✅ RESOLVED (V37) **F38** [low] (→backlog B6): `Util.pm:29` compares scheme with `eq RPI_MODE_UNINIT` while `Core.pm:80-87` uses `==` on the same env-sourced value — inconsistent; pick numeric `==` (enums). Promoted to V37; switched to `==`, confirmed the only `eq` scheme comparison in lib/+bin/.
- ✅ RESOLVED (V36) **F39** [low] (→backlog B5): `bin/pinmap:18-22,28-31` `$wpi == -1` warns when `pin_map` returns undef; guard `next if ! defined $wpi || $wpi == -1`. Also `bin/pimetaerase:21-22` cosmetic `//=`/spacing. Promoted to V36 and fixed exactly as prescribed.
- ✅ RESOLVED (V38) **F40** [info] (→backlog B7): diamond inheritance (Meta reached via Core's branch) works today (DFS dedups, no conflicting overrides) but is latent — document intended MRO or adopt `use mro 'c3'` before adding any cross-branch override. (uuid-collision loop `WiringPi.pm:81-85` reviewed — acceptable, no action.) User chose document (option 1): MRO comments added in WiringPi.pm/Core.pm. V38 audit additions: (a) the hierarchy is C3-*inconsistent* (Util lists Exporter before WiringPi::API which isa Exporter; Core lists WiringPi::API before Util, its subclass) — adopting c3 later requires @ISA reordering in Util/Core/WiringPi first; (b) symbol table audit found one genuine cross-branch method: `new()` in both WiringPi::API and RPi::SysInfo, masked today by RPi::WiringPi's own new() — documented in the comment.

_New documentation findings (V20):_
- ✅ RESOLVED (V27) **F25** [HIGH] (→V27): `README` is a stale `pod2text` of a much older WiringPi.pm (~826 lines behind) — missing INTERRUPT/worker/eeprom/oled/pi_model methods and `shm_key`/`rpi_register*` params; `README:323-326` states the OPPOSITE of current signal behavior (claims it traps `$SIG{__DIE__}`; code explicitly does not); `README:317` says wiringPi 2.36+ (now 3.18). Regenerate from current POD.
- ✅ RESOLVED (V28) **F26** [med] (→V28): `INTERRUPTS.pod:13,17,269` (and FAQ.pod) point to `docs/threads-examples.md`/`docs/interrupt-examples.md` but files live under `docs/examples/`. Broken cross-refs.
- ✅ RESOLVED (V28) **F27** [med] (→V28): `Meta.pm:200` and `FAQ.pod:1200` `my $pi = RPi::WiringPi;` — bareword, not an object; should be `RPi::WiringPi->new`.
- ✅ RESOLVED (V28) **F28** [med/low] (→V28): `FAQ.pod:883` `my gps = $pi->gps;` (missing sigil, won't compile); `FAQ.pod:1021-1025` HCSR04 example assigns `$ruler` but uses `$sensor`.
- ✅ RESOLVED (V28) **F29** [low] (→V28): `Meta.pm:365` AUTHOR line has no preceding `=head1 AUTHOR` (renders as stray paragraph; fails section conventions).
- ✅ RESOLVED (V28) **F30** [low] (→V28): `WiringPi.pm:213-214` `oled($model,$i2c_addr,$display_splash_page)` — 3rd param undocumented in the `=head2 oled` POD (`:763-782`).
- ✅ VALIDATED (V28) **F31** [low] (→V28): `Core.pm:542-558` POD "0=Mark-Space / 1=Balanced" vs code validation using `PWM_DEFAULT_MODE`; verify `PWM_MODE_MS`/`PWM_MODE_BAL`/`PWM_DEFAULT_MODE` numeric values and make POD match.
- ✅ RESOLVED (V28) **F32** [med] (→V28): `INTERRUPTS.pod:112` & `WiringPi.pm:1214` say RPi::Pin "(as of 2.3608)… `background_interrupt` not yet available" but `Makefile.PL:59` now requires RPi::Pin 2.3609 — confirm whether it now ships and update/remove the caveat.

_New test findings (V22):_
- ✅ RESOLVED (V29) **F33** [med] (→V29): `t/920-oled_cleanup.t:19` checks `-e '/tmp/oled_unavailable.rpi-wiringpi'` but the lock is at `/dev/shm/...` (RPiTest.pm:46) — the test passes vacuously, never verifying the lock was removed.
- ✅ RESOLVED (V29) **F34** [med] (→V29): `t/RPiTest.pm:198-203` `rpi_verify_pin_status` returns 0 on first mismatch without saying which pin; combined with F12 it can't see 12/26. Report the offending pin via `note()`.
- ✅ RESOLVED (V29) **F35** [med] (→V29): `t/140-pwm_spi_adc.t`, `t/109-pwm_hw_mods.t`, `t/325-servo.t` set PI_BOARD/RPI_ADC/RPI_SERVO under root but then `rpi_i2c_check()` skips unless `RPI_I2C` (the ADS1115 feedback is I2C) — `RPI_I2C` is not auto-set, so root runs silently skip these. Auto-set or document.
- ✅ RESOLVED (V30) **F36** [med] (→V30): only `t/325-servo.t:66-75` guards cleanup with eval+INT/TERM; other device tests (t/310/335/345/305/925) skip `$pi->cleanup` if an assertion dies mid-loop, leaking pin/CS registration into shared meta. Adopt the guard or `END { $pi->cleanup if $pi }`.
- ✅ RESOLVED (V30) **F37** [med] (→V30): all tests share `shm_key 'rpit'` and many drive the same physical pins (GPIO18 in 12+ tests; 12/26 in several), and t/110-114 assert absolute object/pin counts — the suite is implicitly serial-only; `prove -j` would corrupt counts and fight over pins. Document the `-j1` requirement.
- (low/cosmetic test items folded to backlog: B9 `PI_INTERRUPT` in-process counter naming ✅ RESOLVED (V39), B10 pod tests double-gated on `RPI_RELEASE_TESTING`+`RPI_POD` ✅ RESOLVED (V40), B11 t/109↔t/140 near-duplicate with divergent acceptance bands ✅ RESOLVED (V41), B12 fixed-`sleep` brittleness → poll-until loops ✅ RESOLVED (V42).)

_From the completeness debate (challenger Claude Fable 5, executed checks; see proposal/wiringpi-plan-completeness-audit.md):_
- ✅ RESOLVED (V31) **F41** [RELEASE-BLOCKING] (→V31): `MANIFEST:40,46,151` list `docs/interrupt-examples.md`, `docs/threads-examples.md`, `t/README` — none exist (`ls` fails on all three; the two examples moved to `docs/examples/`, which are NOT in MANIFEST). `make distdir`→`manicopy` croaks → the 3.1802 tarball can't be cut, and post-F26 the POD links point at files the tarball wouldn't ship. Same file-move as F26. Verified by originator.
- ✅ RESOLVED (V23) **F42** [HIGH] (→V23): `WiringPi.pm:38` `if (my $scheme = $ENV{RPI_PIN_MODE})` — `RPI_MODE_WPI == 0` (verified live) is the only falsy scheme, so after a first object's `setup=>'w'` (`:52`/`:65` write `"0"`), a second `new()` reads false, runs `setup_gpio()`, restamps GPIO — every WPI pin silently reinterpreted as BCM. `Core.pm:97-98` uses `defined` correctly. Was missed in a fully-reviewed file. Verified by originator.
- ✅ RESOLVED (V43) **F43** [med→backlog B13] (→B13): `DHT11.xs:187-189` / `HCSR04.xs:23-25` `char modeEnvVar[20]; sprintf(...); putenv(modeEnvVar);` — putenv stores the pointer; the stack buffer dies on return; next `getenv("RPI_PIN_MODE")` reads freed stack. Pre-existing, NOT a 3.18 regression; fires only when `RPI_PIN_MODE` was already set (multi-dist/dual-sensor rig). Fixed in V43 with setenv() in both files; failure mode empirically demonstrated via standalone C before/after.
- ✅ VALIDATED (V14) **F44** [structural] (→V14): `rpi-const`, the 19th sibling and the dependency root the migration single-sources from, had no row. Confirm-only (debate: repo 1.05 == installed 1.05, zero drift).
- **F45** [executed — nothing material] (→done, 2 notes→B14): generator scripts (`gen-test-platform.pl`, `gen-pod-md.pl`, `gen-pdf.py`, `gen-pinout-images.py`) + `build_testing/*` reviewed CLEAN. Notes: `scripts/helpers/gen-schematic.py:145,225` bare `open(path,'w').write(...)` (no context manager / no error handling) [low → B14 ✅ RESOLVED (V44)]; `Changes` 2.3633 chronology oddity (stable stanza dated 2019-09-19 before trials `_02`/`_03`) [info, historical only].
- ✅ RESOLVED (V33) **F46** [open residual] (→V33): the full per-file pass over all 69 `t/*.t` was NOT completed (≈10 more sampled, nothing new), AND the single-pass review of the large modules (`WiringPi.pm`, `Core.pm`) is demonstrably non-exhaustive (it yielded F22/F23/F42/F47). Tracked by V33.
- ✅ RESOLVED (V32) **F47** [med code + med doc] (→V32): `new()` `setup` param — `WiringPi.pm:50 =~ /^w/i` vs `:54 =~ /^g/` (no `/i`) → `'GPIO'`/`'Gpio'` fall through; `:58-60` else stamps `RPI_MODE_UNINIT` with no setup/croak (any typo silently no-ops the board); and `setup` is documented nowhere (0 in WiringPi.pm POD past `__END__:523`, 0 in FAQ.pod) yet public and used by the suite (`t/106-pin_map.t:13`, `setup => 'none'`). Fix must whitelist `w`/`g`/`none` case-insensitively (don't break `'none'`) and document the three forms.

_From the V33 residual exhaustive pass (4 parallel reviewers over all 69 t/*.t + WiringPi.pm/Core.pm/Util.pm/Meta.pm; every candidate finding re-verified at source by the originator; ~10 reviewer claims rejected as false positives):_
- ✅ RESOLVED (V34) **F48** [med] (→V34): `WiringPi.pm sub oled` — `%models` validates `128x32`/`96x16` as legal, but only `128x64` has a construction branch; the other two fall through and return undef silently (caller then crashes on method call). POD says only 128x64 is currently valid. Die for the unsupported models (or drop them from the whitelist).
- ✅ RESOLVED (V34) **F49** [med] (→V34): `WiringPi.pm sub expander` — an unrecognized `$expander` type falls through the single `if` and returns undef silently; POD says MCP23017 is the only option. Croak on unrecognized type.
- ✅ RESOLVED (V34) **F50** [low] (→V34): `Core.pm sub pin_to_gpio` — the `RPI_MODE_UNINIT` check is a bare `if` after the WPI/GPIO returns; any *other* scheme value (e.g. corrupted `RPI_PIN_MODE` env) falls through to implicit undef. Make the croak the catch-all `else`.
- ✅ RESOLVED (V34) **F51** [low] (→V34): test hygiene: `t/150-cleanup.t:34` message says "pin 26" while grepping pin 12 (copy-paste); `t/111:23` leftover debug `print(1 + $obj_count...)` polluting TAP; `t/300:11` duplicate `use lib 't/'`; `t/107:39` asserts the boolean of `mode_alt eq $_` so a failure diagnostic shows ''/1 instead of got/expected alt values.
- ✅ RESOLVED (V41) **F52** [low] (→B11): `t/109:84,95` lower-bound assertions `is $o >= -1, 1` are effectively vacuous (percent can't go below 0); fold into the B11 t/109↔t/140 acceptance-band reconciliation. Fixed in V41: each sweep cycle now asserts the shared duty-tracking window from `rpi_pwm_adc_window()`.

## Backlog

B8: Normalize `PI_BOARD`/`PI_INTERRUPT` → `RPI_*` prefix in a future major version with back-compat (F13).

B15: rpi-pin t/15-pwm.t + t/40-interrupt_and_pud.t re-exec via `system('sudo', 'perl', $0)` when not root — bare `sudo perl` resolves to the system perl (no perlbrew/blib) and dies with "Can't locate RPi/Pin.pm". Use `$^X` and propagate -Iblib paths/env, or document that the suite must run as root (discovered during V7).

B16: t/325-servo.t sweep assertions carry the F52 pattern fixed in t/109 by V41 — vacuous `is $o >= -1, 1` lower bounds and a flat `< MAX_IN` (40) ceiling. Needs servo-feedback calibration windows (the feedback is a servo pot, not PWM duty, so `rpi_pwm_adc_window()` doesn't directly apply); calibrate on a powered rig (discovered during V42).

## Explicitly NOT doing

- Tooling/hygiene conformance (.claude/, .gitignore, CLAUDE.md, CI, and **siblings'** MANIFEST/MANIFEST.SKIP) — user scoped sibling conformance to code-compatibility only. **NOTE:** this exclusion does NOT cover rpi-wiringpi's own `MANIFEST`, which has a release-blocking defect tracked as F41/V31 (in scope).
- Version-scheme renumbering or POD/style normalization of siblings — out of scope per user.
- Touching independent siblings' functionality beyond confirming they don't couple to wiringPi (V13).
