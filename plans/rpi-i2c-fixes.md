# Plan: rpi-i2c fixes — review findings from the 2026-07-05 audit

> **NEXT ACTION:** V1 — `git -C ~/repos/rpi-i2c pull --ff-only && git -C ~/repos/rpi-i2c log --oneline -1`
> **LAST SESSION:** 2026-07-05 — plan created from the rpi-i2c review (conducted on rpi2 against the 3.1802 UNREL tree); no work started.
> **ARCHIVE:** See rpi-i2c-fixes-archive.md for completed V tasks

Scope: the RPi::I2C distribution (`~/repos/rpi-i2c`, on both the Mac and rpi2).
The review ran on rpi2 (current tree, commit `1d2d63f`, 3.1802 UNREL); the Mac
clone is behind origin (V1 fixes that). Work is edit + test only — the user
does all commits/pushes himself.

**ID cross-reference warning:** the `F7`/`F8`/`B18` mentioned in rpi-i2c's
`t/10-validation.t` comments belong to `plans/test-coverage-gaps.md`, NOT this
file. This plan has its own F-series. The contract bugs are: their F7 = this
plan's F1; their F8 = this plan's F2; their B18 = executed here as V8.

## Decisions needed (user)

- **D1 (blocks V7):** license target. Makefile.PL says `GPL_2`, the POD says
  "same terms as Perl itself" (Artistic|GPL dual). Options: `artistic_2`
  (matches the newer rpi-* dists), `perl_5` (matches the POD as written), or
  keep `GPL_2` and change the POD instead.
- **D2 (informs V8):** the B18 contract changes are breaking (read_bytes,
  write_word, process). Ship them inside the still-unreleased 3.1802, or bump
  to a new version to mark the API break?

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of rpi-i2c-fixes-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
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
| V1 | Sync the stale Mac clone (still 3.1801, missing t/10-validation.t) | `git -C ~/repos/rpi-i2c pull --ff-only && git -C ~/repos/rpi-i2c log --oneline -1` | Fast-forwards to `1d2d63f` (or newer); status clean | ⏳ |
| V2 | Fix `I2C__readBlockData` XSUB: on `ret == -1` it falls through to `sv_setpvn(output, buf, -1)` — a (STRLEN)-1 over-read/segfault landmine. Croak before `sv_setpvn` (mirror `_readI2CBlockData`'s croak style) | `ssh rpi2 'cd ~/repos/rpi-i2c && make clean >/dev/null 2>&1; perl Makefile.PL >/dev/null && make 2>&1 \| grep -i "warn\|error"; make test'` | Builds warning-free; full suite passes | ⏳ |
| V3 | `new()` error handling: (a) croak "could not open $dev: $!" when `IO::File->new` returns undef (today: "Can't bless non-reference value"); (b) reword the misleading "I2C device at address X not found" ioctl croak — with `I2C_SLAVE_FORCE` the ioctl succeeds on an empty bus, so failure means EBUSY/bad-fd, not absence. Keep the `I2C_TESTING` escape hatch. Add HW-free tests to t/10-validation.t (bad device path) | `ssh rpi2 'cd ~/repos/rpi-i2c && make test'` | New tests pass; suite green. RPi::PCA9685 unaffected (its eval wrap is message-agnostic) | ⏳ |
| V4 | POD fixes: `ram=i2c_arm=on` → `dtparam=i2c_arm=on` (lines ~183-186 — actively misleads config.txt editors); "examples direcory" typo (line ~154); document the 32-byte SMBus block cap on read_block/write_block (bundled header silently clamps) | on Mac (post-V1): `cd ~/repos/rpi-i2c && RELEASE_TESTING=1 prove -l t/pod.t` | pod test passes; corrected directives present | ⏳ |
| V5 | MANIFEST.SKIP: add skips for build-generated files (`^I2C\.c$`, `^I2C\.bs$`, `\.o$`, `\.so$`) so post-build RELEASE_TESTING manifest.t stays green now that I2C.c is out of git | `ssh rpi2 'cd ~/repos/rpi-i2c && perl Makefile.PL >/dev/null && make >/dev/null 2>&1 && RELEASE_TESTING=1 prove -b t/manifest.t'` | manifest.t passes with build artifacts present | ⏳ |
| V6 | Add CI workflow — this is the one rpi-* dist that can genuinely pass hosted CI (kernel i2c headers on ubuntu-latest, no wiringPi; 00-load + 10-validation are HW-free). Model on rpi-pca9685's workflow, ubuntu-only matrix, must `make` before `prove -b` (XS dist) | `ls ~/repos/rpi-i2c/.github/workflows/` | Workflow file present and YAML-valid; goes green on the user's next push | ⏳ |
| V7 | Unify the license metadata per **D1** (Makefile.PL `GPL_2` vs POD "same terms as Perl itself") | `grep -n LICENSE ~/repos/rpi-i2c/Makefile.PL` + POD LICENSE section | Makefile.PL LICENSE and POD agree | ⏳ |
| V8 | Execute test-coverage-gaps **B18** (coordinated contract fix, per **D2**): `read_bytes` accumulates and returns the documented array of N bytes (fixes the `(0 << 8)` overwrite); `write_word` → `($value, [$reg])` matching write_byte + its POD; `process` → `($value, [$reg])` + `_set_reg` default; enforce/document write_block's 32-byte cap. Update POD; flip the pinned assertions in rpi-i2c `t/10-validation.t` AND the mirror `rpi-wiringpi/t/250-i2c_unit.t`; Changes entries at the bottom of the UNREL section. Cross-plan bookkeeping: in test-coverage-gaps.md mark F7/F8 `✅ RESOLVED (rpi-i2c-fixes V8)` in place and retire B18 with a pointer here | `ssh rpi2 'cd ~/repos/rpi-i2c && make test'` (mirror test runs on the rig Pi later — it needs the RPi::WiringPi stack) | rpi-i2c suite green with un-pinned (fixed-contract) assertions; mirror file edited to match | ⏳ |

## Discovery Tracking

_None yet._

## Review Findings

Findings from the 2026-07-05 review on rpi2 (tree `1d2d63f`, 3.1802 UNREL).
Reminder: F7/F8 *in rpi-i2c's test comments* are test-coverage-gaps.md's IDs,
not these.

- **F1** (→V8): `read_bytes()` — `(0 << 8)` should accumulate (`$retval << 8`); as written it returns only the base register's byte, and returns an integer while its POD promises an array. [= test-coverage-gaps F7; direction fixed by its B18: return the array]

- **F2** (→V8): `write_word($reg, $value)` arg order contradicts its own POD (`write_word($data, [$reg])`) and sibling `write_byte($value, $reg)`. [= test-coverage-gaps F8]

- **F3** (→V8): `process($register_address, $value)` — POD says `process($value, [$reg])`; code order disagrees and skips the `_set_reg` default. In B18's scope but never pinned by a test.

- **F4** (→V2): `I2C__readBlockData` XSUB falls through to `sv_setpvn(output, buf, ret)` when `ret == -1` — (STRLEN)-1 over-read; the preceding `if (ret == -1) RETVAL = ret;` doesn't stop execution. Unused by the .pm (read_block uses the I2C-block variant) but publicly callable.

- **F5** (→V3): `new()` with an unopenable device path: `IO::File->new` returns undef, `bless $fh` dies "Can't bless non-reference value" — uninformative.

- **F6** (→V3): `new()`'s "I2C device at address 0x%x not found" croak is wrong in practice — `I2C_SLAVE_FORCE` ioctl succeeds on an empty bus (verified on rpi2); it only fails for EBUSY/EINVAL-class reasons. Absence detection is `check_device()`'s job.

- **F7** (→V4): POD says `ram=i2c_arm=on` for enabling the bus in config.txt; the correct directive is `dtparam=i2c_arm=on` (the Arduino section below it already uses the `dtparam=` form).

- **F8** (→V4): POD typo "examples direcory".

- **F9** (→V4 docs, →V8 enforcement): read_block/write_block silently clamp to the 32-byte SMBus block max (bundled i2c-dev.h) — undocumented silent truncation.

- **F10** (→V7): license mismatch — Makefile.PL `GPL_2`, POD "same terms as Perl itself".

- **F11** (→V6): no CI workflow, despite being the most CI-able dist in the rpi-* stable.

- **F12** (→V5): MANIFEST.SKIP has no entries for build-generated `I2C.c`/`I2C.bs`/objects — post-build RELEASE_TESTING manifest.t flags the regenerated I2C.c as "extra".

- **F13** (→V1): the Mac clone of rpi-i2c is behind origin (3.1801, no t/10-validation.t, stale Changes).

## Backlog

B1: Regenerate the bundled ppport.h with a current Devel::PPPort.

B2: Consider address-range validation in `new()` (0x00-0x7F) — MUST keep addr 0 legal: RPi::PCA9685's `reset()` depends on `RPi::I2C->new(0, ...)` for the I2C general-call SWRST.

B3: After the B18 contract changes ship, confirm RPi::PCA9685 compatibility and bump its PREREQ_PM floor if needed. (Expected no-op: it uses only read_byte/write_byte/read_block/write_block/write — none of the changed methods.)

## Explicitly NOT doing

- Probing for device presence inside `new()` — would break general-call address 0 usage (RPi::PCA9685->reset) and misbehave on probe-hostile/write-only devices; `check_device()` exists for this.
- Removing the unused SMBus-variant XSUBs (`_readBlockData`, `_writeBlockData`, `_blockProcessCall`) — they're public XS surface someone may call; V2 only defuses the crash.
- Renaming/reworking the examples/ Arduino scripts — still valid as-is; they ship in the tarball per the current MANIFEST on purpose.
