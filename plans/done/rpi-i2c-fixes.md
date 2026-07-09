# Plan: rpi-i2c fixes — review findings from the 2026-07-05 audit

> **NEXT ACTION:** None — ALL V tasks complete (V1-V15); backlog fully drained (B1-B6 all promoted). For the user: V2-V12 are already committed+pushed as origin/master `01a7f20` (so the V6 CI is already live) — the only thing left to review/commit/push on the Mac is V13 (B4 croak-path test) + V15 (B6 ppport.h removal): `Changes`, `I2C.xs`, `MANIFEST`, deleted `ppport.h`, `t/10-validation.t`. Also: run the updated t/250 mirror on the rig Pi after installing RPi::I2C 3.1803. rpi2 is a content-synced test rig at `1d2d63f` (uncommitted mirror), not a commit location — leave its git state to the user.
> **LAST SESSION:** 2026-07-07 — V15 (was B6): removed ppport.h from the dist. Self-audit re-confirmed "No need to include 'ppport.h'"; dropped the #include from I2C.xs + the MANIFEST line + deleted the file (both trees). rpi2/perlbrew rebuild WITHOUT ppport.h clean (0 warn/error, fresh I2C.c has 0 ppport refs); full RELEASE_TESTING green (5 files, 24 tests). Discovery: Mac HEAD `01a7f20` (the V2-V12 bundle) is already pushed to origin/master — CI already live; only V13+V15 uncommitted on the Mac. Earlier today: V14 (B5 release-host decision) + V13 (B4 croak-path pin) + plan V1-V12 (committed+pushed as 01a7f20; see archive).
> **ARCHIVE:** See rpi-i2c-fixes-archive.md for completed V tasks (V1-V15 — all)

Scope: the RPi::I2C distribution (`~/repos/rpi-i2c`, on both the Mac and rpi2).
The review ran on rpi2 (current tree, commit `1d2d63f`, 3.1802 UNREL); the Mac
clone was behind origin (synced — see archived V1). Work is edit + test only —
the user does all commits/pushes himself.

**Rename note (2026-07-07):** the PCA9685 dist was renamed — repo
`rpi-pca9685` → `rpi-pwm-pca9685`, module `RPi::PCA9685` →
`RPi::PWM::PCA9685`. References below use the new names.

**ID cross-reference warning:** the `F7`/`F8`/`B18` mentioned in rpi-i2c's
`t/10-validation.t` comments belong to `plans/test-coverage-gaps.md`, NOT this
file. This plan has its own F-series. The contract bugs are: their F7 = this
plan's F1; their F8 = this plan's F2; their B18 = executed here as V8.

## Decisions needed (user)

- **D1 (blocks V7):** ✅ DECIDED 2026-07-07: `artistic_2` (was: Makefile.PL
  `GPL_2` vs POD "same terms as Perl itself"). Executed in V7.
- **D2 (informs V8):** ✅ DECIDED 2026-07-07: bump the version to mark the API
  break — incremented by the LAST digit per house convention: 3.1802 → 3.1803.
  (An initial 3.19 edit was corrected by the user: bumps increment the last
  digit, never the integer after the decimal.) Executed in V8.

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
| — | _All V tasks complete (V1-V15) — see rpi-i2c-fixes-archive.md_ | | | |

## Discovery Tracking

_None yet._

## Review Findings

Findings from the 2026-07-05 review on rpi2 (tree `1d2d63f`, 3.1802 UNREL).
Reminder: F7/F8 *in rpi-i2c's test comments* are test-coverage-gaps.md's IDs,
not these.

- **F1** (→V8): ✅ RESOLVED (V8) — `read_bytes()` — `(0 << 8)` should accumulate (`$retval << 8`); as written it returns only the base register's byte, and returns an integer while its POD promises an array. [= test-coverage-gaps F7; direction fixed by its B18: return the array] [fixed 2026-07-07 in 3.1803: returns the documented array ascending from the base register; test-pinned in t/10 + t/250]

- **F2** (→V8): ✅ RESOLVED (V8) — `write_word($reg, $value)` arg order contradicts its own POD (`write_word($data, [$reg])`) and sibling `write_byte($value, $reg)`. [= test-coverage-gaps F8] [fixed 2026-07-07 in 3.1803: ($value, [$reg]) with the _set_reg default; test-pinned in t/10 + t/250]

- **F3** (→V8): ✅ RESOLVED (V8) — `process($register_address, $value)` — POD says `process($value, [$reg])`; code order disagrees and skips the `_set_reg` default. In B18's scope but never pinned by a test. [fixed 2026-07-07 in 3.1803: ($value, [$reg]) + _set_reg default; NOW test-pinned in t/10 + t/250]

- **F4** (→V2): ✅ RESOLVED (V2) — `I2C__readBlockData` XSUB falls through to `sv_setpvn(output, buf, ret)` when `ret == -1` — (STRLEN)-1 over-read; the preceding `if (ret == -1) RETVAL = ret;` doesn't stop execution. Unused by the .pm (read_block uses the I2C-block variant) but publicly callable. [croaks as of 2026-07-07; verified live on rpi2] [test-pinned in t/10 via V13 (was B4), 2026-07-07]

- **F5** (→V3): ✅ RESOLVED (V3) — `new()` with an unopenable device path: `IO::File->new` returns undef, `bless $fh` dies "Can't bless non-reference value" — uninformative. [croaks "could not open $dev: $!" as of 2026-07-07; test-pinned]

- **F6** (→V3): ✅ RESOLVED (V3) — `new()`'s "I2C device at address 0x%x not found" croak is wrong in practice — `I2C_SLAVE_FORCE` ioctl succeeds on an empty bus (verified on rpi2); it only fails for EBUSY/EINVAL-class reasons. Absence detection is `check_device()`'s job. [now "ioctl(I2C_SLAVE_FORCE) failed for address 0x%x on $dev: $!"; test-pinned via /dev/null ENOTTY]

- **F7** (→V4): ✅ RESOLVED (V4) — POD says `ram=i2c_arm=on` for enabling the bus in config.txt; the correct directive is `dtparam=i2c_arm=on` (the Arduino section below it already uses the `dtparam=` form). [fixed 2026-07-07; pod.t green]

- **F8** (→V4): ✅ RESOLVED (V4) — POD typo "examples direcory". [fixed 2026-07-07]

- **F9** (→V4 docs, →V8 enforcement): read_block/write_block silently clamp to the 32-byte SMBus block max (bundled i2c-dev.h) — undocumented silent truncation. [docs half ✅ done in V4 (2026-07-07): both PODs now document the 32-byte cap, verified against i2c-dev.h l.284-285/303-304. Enforcement half ✅ done in V8: write_block() croaks on >32 bytes (test-pinned); read_block keeps the documented clamp. FULLY RESOLVED]

- **F10** (→V7): ✅ RESOLVED (V7) — license mismatch — Makefile.PL `GPL_2`, POD "same terms as Perl itself". [unified to artistic_2 per D1, 2026-07-07; Makefile.PL + POD agree; pod.t green]

- **F11** (→V6): ✅ RESOLVED (V6) — no CI workflow, despite being the most CI-able dist in the rpi-* stable. [github_ci_default.yml added 2026-07-07; YAML-validated; green-on-push confirmable after the user's next push]

- **F12** (→V5): ✅ RESOLVED (V5) — MANIFEST.SKIP has no entries for build-generated `I2C.c`/`I2C.bs`/objects — post-build RELEASE_TESTING manifest.t flags the regenerated I2C.c as "extra". [premise corrected 2026-07-07: the loose `.c$`/`.bs$`/`.o$` entries were already present and live — Test::CheckManifest 1.43 chomps MANIFEST.SKIP lines and matches them against dist-relative paths (verified in source and by a live post-build run; no artifact was flagged). The actual failure was t/10-validation.t missing from MANIFEST — fixed (Fix 3), manifest.t green post-build. Side discovery → V9]

- **F13** (→V1): ✅ VALIDATED (V1) — the Mac clone of rpi-i2c is behind origin (3.1801, no t/10-validation.t, stale Changes). [already synced to `1d2d63f` by the time V1 ran on 2026-07-07; no pull needed]

## Backlog

B1 — ⬆ PROMOTED → V10 (2026-07-07); slot retired: Regenerate the bundled ppport.h with a current Devel::PPPort.

B2 — ⬆ PROMOTED → V11 (2026-07-07); slot retired: Consider address-range validation in `new()` (0x00-0x7F) — MUST keep addr 0 legal: RPi::PWM::PCA9685's `reset()` depends on `RPi::I2C->new(0, ...)` for the I2C general-call SWRST.

B3 — ⬆ PROMOTED → V12 (2026-07-07); slot retired: After the B18 contract changes ship, confirm RPi::PWM::PCA9685 compatibility and bump its PREREQ_PM floor if needed. (Expected no-op: it uses only read_byte/write_byte/read_block/write_block/write — none of the changed methods.)

B4 — ⬆ PROMOTED → V13 (2026-07-07); slot retired: Pin the V2 croak path in t/10-validation.t — `RPi::I2C::_readBlockData(-1, 0, $buf)` must die with "invalid return" (pre-V2 this exact call was the segfault landmine).

B5 — ⬆ PROMOTED → V14 (2026-07-07); slot retired: Decide where release-time RELEASE_TESTING should run and durably install Test::CheckManifest there.

B6 — ⬆ PROMOTED → V15 (2026-07-07); slot retired: Per the ppport.h 3.68 self-audit ("No need to include 'ppport.h'"), I2C.xs uses no API requiring compat shims — remove the `#include "ppport.h"` from I2C.xs and drop ppport.h from the dist (MANIFEST + git).

## Explicitly NOT doing

- Probing for device presence inside `new()` — would break general-call address 0 usage (RPi::PWM::PCA9685->reset) and misbehave on probe-hostile/write-only devices; `check_device()` exists for this.
- Removing the unused SMBus-variant XSUBs (`_readBlockData`, `_writeBlockData`, `_blockProcessCall`) — they're public XS surface someone may call; V2 only defuses the crash.
- Renaming/reworking the examples/ Arduino scripts — still valid as-is; they ship in the tarball per the current MANIFEST on purpose.
