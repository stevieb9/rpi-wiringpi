# Plan: Bring lib/ and t/ Perl into line with the personal Perl style rules

> **NEXT ACTION:** V1 — fix lib/RPi/WiringPi.pm (negation line 79 + alphabetize private subs)
> **LAST SESSION:** Scanned all lib/ + t/ Perl per the perl.md rules; built this plan. No edits made yet.
> **ARCHIVE:** See style-archive.md for completed V tasks

## Scope & method

- **In scope:** `lib/**/*.{pm,pod}`, `t/**/*.t`, `t/**/*.pl`, `t/RPiTest.pm`, `Makefile.PL` — i.e. everything matched by the rules' own path globs.
- **Out of scope (per request):** `build_testing/`, `script/`, `docs/`.
- **Verification reality:** this host is not a Pi — `WiringPi::API` / `RPi::Const` are absent, so `perl -c` cannot load these files, and `perlcritic`/`perltidy` are not installed. Every check below is therefore a `grep`/`awk` pattern check that runs locally. Edits must be made by hand and eyeballed; do NOT rely on a compile step.
- **Rules checked:** (1) space after negation, (2) spaces around binary operators, (3) brace placement, (4) Changes-file ordering, (5) no space before `(` in calls, (6) comma spacing, (7) subs after executable code in scripts, (8) subs alphabetical (public then private), (9) positional params validated in receipt order.

### What is already compliant (no task)
- **Rule 3 (braces):** no Allman/cuddled-`else` found. The standalone `{` lines in `t/110-register.t` and `t/330-mcp23017.t` are bare scoping blocks (no keyword to cuddle) — fine.
- **Rule 4 (Changes file):** procedural rule for future edits; no static violation.
- **Rule 6 (commas):** no `,X` or ` ,` in code (the hits were inside string literals / pod shell-examples).
- **Rule 2 (arithmetic operators):** none missing spaces. Only assignment `=` has cases (see V9).
- **Rule 9 (param order):** all croak/`die` validation already runs in receipt order.
- **Util.pm:** public subs already alphabetical; nothing to do.
- **`lib/RPi/WiringPi.pm` public subs** (`adc`…`stepper_motor`) already alphabetical (only the private block is out of order).
- **Makefile.PL**, `t/05-checksum_uuid.t`, all 6 `t/multi/*_master.pl` and the slaves' sub placement: compliant.

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of style-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
  3. **Delete the V# row from this file's Validation Table.**
- V task ❌: update Actual with `❌ YYYY-MM-DD attempt N: reason`. Rerun same V# with attempt N+1. Do NOT create a new V#.
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
| V1 | **lib/RPi/WiringPi.pm**: (a) line 79 `while (!defined` → `while (! defined`; (b) alphabetize the private subs (keep `new`/public block + `DESTROY` as-is). Target private order: `_class_signal_handler, _cleanup_handler, _fatal_exit, _generate_signal_handlers, _setup, _signal_handlers, _vim`. Preserve the `END {}` block and trailing `_vim`/`1;`. | `grep -nE '\(! ?defined' lib/RPi/WiringPi.pm; grep -nE '^sub ' lib/RPi/WiringPi.pm` | line 79 prints `! defined` (with space); private subs (those after `# private`) appear in the target order; total `^sub ` count still **28** (21 public + 7 private) | ⏳ |
| V2 | **lib/RPi/WiringPi/Core.pm**: alphabetize public subs, then private subs. Target public: `cleanup, export_pin, gpio_layout, identify, io_led, label, pin_scheme, pin_to_gpio, pwm_clock, pwm_mode, pwm_range, pwr_led, register_pin, registered_pins, unexport_pin, unregister_object, unregister_pin`. Target private: `_pin_registration, _pwm_in_use, _rpi_register, _rpi_register_pins, _vim`. | `grep -nE '^sub ' lib/RPi/WiringPi/Core.pm` | sub names read public-block-alpha then private-block-alpha as listed; total `^sub ` count still **22** (17 + 5) | ⏳ |
| V3 | **lib/RPi/WiringPi/Meta.pm**: alphabetize public subs. Target: `meta, meta_delete, meta_erase, meta_fetch, meta_get, meta_key, meta_key_check, meta_lock, meta_set, meta_store, meta_unlock` then `_vim`. | `grep -nE '^sub ' lib/RPi/WiringPi/Meta.pm` | sub names in the target order; total `^sub ` count still **12** (11 + 1) | ⏳ |
| V4 | **t/RPiTest.pm**: (a) line 60 `if (!$ENV{RPI_MULTI})` and line 65 `if (!$ENV{RPI_POD})` → `! $ENV{...}`; (b) alphabetize the helper subs. Target: `rpi_check_pin_status, rpi_default_pin_config, rpi_legal_object_count, rpi_legal_pin_count, rpi_multi_check, rpi_oled_available, rpi_oled_unavailable, rpi_pod_check, rpi_reset, rpi_running_test, rpi_sudo_check, rpi_verify_pin_status`. | `grep -nE '\(! ?\$ENV' t/RPiTest.pm; grep -nE '^sub ' t/RPiTest.pm` | lines 60 & 65 print `! $ENV`; subs in target order; total `^sub ` count still **12** | ⏳ |
| V5 | **t/02-shm_key.t**: lines 14 & 15 `is (RPi::WiringPi->...` → `is(RPi::WiringPi->...` (drop space before `(`). | `grep -n 'is (' t/02-shm_key.t` | no matches | ⏳ |
| V6 | **t/150-cleanup.t**: lines 33 & 34 `is ((grep ...` → `is((grep ...` (drop space before `(`). | `grep -n 'is (' t/150-cleanup.t` | no matches | ⏳ |
| V7 | **t/305-i2c.t**: move `sub _eeprom { ... }` (currently lines 78-81) to the bottom, below `done_testing()`, so no executable code follows the sub (rule 7). | `awk '/^sub _eeprom/{s=NR} /done_testing/{d=NR} END{print "sub@"s" done_testing@"d}' t/305-i2c.t` | `sub@` line number is **greater than** `done_testing@` line number | ⏳ |
| V8 | **t/450-stepper.t**: move `sub display { ... }` (currently lines 82-90) to the bottom, below `done_testing()` (rule 7). | `awk '/^sub display/{s=NR} /done_testing/{d=NR} END{print "sub@"s" done_testing@"d}' t/450-stepper.t` | `sub@` line number is **greater than** `done_testing@` line number | ⏳ |
| V9 | **t/multi/{int,full,die}_slave.pl**: `my $pi= RPi::WiringPi->new(...)` → `my $pi = RPi::WiringPi->new(...)` (space before `=`). 3 files. | `grep -rn 'pi= ' t/multi/int_slave.pl t/multi/full_slave.pl t/multi/die_slave.pl` | no matches | ⏳ |

## Discovery Tracking

_None yet._

## Backlog

_None yet._

## Explicitly NOT doing

- **Missing space before `{` (e.g. `if ($x){`, `for (...){`)** — widespread in lib/ and t/, but the rules never state a "space before opening brace" requirement (the brace rule is only about same-line vs next-line, which already passes). Leaving `){` untouched.
- **`t/200/201/202-interrupt_*.t` `sub handler`** — defined inside a compile-time `BEGIN { my $c; sub handler {...} }` block as a closure over a private `$c` counter. This is a deliberate idiom, not loose top-level placement; relocating it serves no rule-7 purpose and muddies the closure. Flagged here for your call rather than changed.
- **`lib/RPi/WiringPi.pm` `new` / `DESTROY` not strictly alphabetized** — kept as conventional lifecycle methods (constructor first, destructor as a special-named method); the rest of the public block is already alphabetical.
- **POD / comment / string "hits"** (`Copyright (C)`, `dtparam=i2c_arm=on`, `2,4,6,8` inside test descriptions, `hello, world!`, regex `!` delimiters, `$!`) — matched the spacing greps but are not code; no change.
- **Trailing whitespace** (e.g. Core.pm:81, a few `.t` lines) — not covered by the rules.
</content>
</invoke>
