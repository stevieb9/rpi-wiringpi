# Plan: Convert RPi::WiringPi shared-memory backend from IPC::ShareLite to IPC::Shareable

> **NEXT ACTION:** V1 — swap the dependency in `Makefile.PL`
> **LAST SESSION:** Plan created (Option A confirmed). Analyzed all shm usage; IPC::ShareLite is used in exactly one file (`lib/RPi/WiringPi/Meta.pm`); IPC::Shareable 1.17 is installed, ShareLite is not. Added V10 + a Risks note on the single-segment 64KB cap (a shared bound, not a regression).
> **ARCHIVE:** See SHAREABLE-archive.md for completed V tasks

---

## Recommended approach (read first)

**Keep the `meta_*` method API; swap only the backend inside `Meta.pm`.**

Every consumer (`Core.pm`, `WiringPi.pm`, `t/RPiTest.pm`, the `t/multi/*.pl` scripts, `t/03`, `t/05`, `t/110`, `t/111`, `t/15x`, `script/*.pl`) talks to shared memory **only** through the `meta_*` methods. If those methods keep their current signatures and return shapes, the migration is contained almost entirely to `Meta.pm`. This is **Option A** below and is the recommended path. **Option B** (rip out `meta_fetch`/`meta_store` and have callers use a tied hash directly) is rejected — see *Explicitly NOT doing*.

If you'd prefer Option B (a fuller native-tie rewrite touching every caller), say so and I'll re-plan — but Option A is lower-risk and behavior-neutral.

---

## Background: how the shared memory is used today

`Meta.pm` is mixed into the `RPi::WiringPi` object (internal-only API). It stores **one JSON blob** — a single hashref — in **one** SysV shared-memory segment keyed by a 4-char string (`shm_key`, default `'rpiw'`; tests use `'rpit'`). The blob's top-level keys:

| Key | Owner | Purpose |
|-----|-------|---------|
| `objects` | software | `{ $uuid => { proc, label } }` — every live Pi object, for collision detection + safety shutdown |
| `object_count` | software | count of `objects` |
| `pins` | software | `{ $pin_num => { alt, state, mode, comment, users => { $uuid => n } } }` — pin registration |
| `pwm` | software | `{ in_use => bool, users => { $uuid => 1 } }` |
| `storage` | **user** | `{ $name => \%href }` — user-facing `meta_set`/`meta_get`/`meta_delete` slots |
| `testing` | test suite | `{ test_name, test_num }` set by `t/RPiTest.pm` |

**Access pattern, used everywhere:**
```perl
$self->meta_lock;                 # exclusive advisory lock
my $meta = $self->meta_fetch;     # detached hashref of the WHOLE blob
... mutate $meta ...
$self->meta_store($meta);         # replace the WHOLE blob
$self->meta_unlock;
```
`meta_set/get/delete/erase` are higher-level wrappers that already implement this same lock→fetch→mutate→store→unlock dance internally against the `storage` sub-key.

**Current IPC::ShareLite surface (all inside `Meta.pm`):**
- `IPC::ShareLite->new(-key, -create => 1, -destroy => 0)` (lazy, cached in `$self->{meta_shm}`)
- `$shm->key`, `$shm->lock($flags)`, `$shm->unlock`, `$shm->fetch` (JSON string), `$shm->store($json)`
- `use IPC::ShareLite qw(:flock)` for `LOCK_EX`
- a raw `shmget($key, 65536, 0)` existence probe in `meta_key_check`, with the key derived by `unpack('i', pack('A4', $key))`
- JSON is hand-rolled here via `JSON::XS` (`encode_json`/`decode_json`)

**Confirmed facts driving this plan:**
- `grep` shows IPC::ShareLite appears **only** in `lib/RPi/WiringPi/Meta.pm`. No other module touches SysV directly.
- `IPC::Shareable` **1.17 is installed**; `IPC::ShareLite` is **not** — so `Meta.pm` cannot even load today. Migration is also a build-unblock.
- `pimeta`/`pimetaerase` are referenced only in `lib/RPi/WiringPi/FAQ.pod` (docs), not as real scripts.
- IPC::Shareable's `END`/`_end` block removes a segment **only** when its `destroy` attribute is true (`lib/IPC/Shareable.pm:2190`). There is **no** per-object `DESTROY` remover. So `destroy => 0` preserves the segment exactly like ShareLite's `-destroy => 0`.
- `IPC::Shareable::SharedMem` exposes a public integer-key accessor `->key` (`SharedMem.pm:95`).
- IPC::Shareable's `:flock` exports `LOCK_EX/SH/NB/UN` with the same numeric values as `Fcntl` flock — `meta_lock(LOCK_EX)` maps 1:1.
- IPC::Shareable defaults to the JSON serializer and a 65536-byte segment (`SHM_BUFSIZ`). The current code passes no `-size` to ShareLite, so it uses ShareLite's own default (also ~65536) — default segment sizes line up. Behavior *at* the cap differs, though (see Risks / V10): IPC::Shareable croaks once the JSON exceeds the segment, whereas ShareLite's >64KB behavior is unverified here (not installed). Both are effectively bounded by the segment size for this single-blob design, so it is **not** a regression for the small RPi metadata.

## Method mapping (ShareLite → Shareable), all within `Meta.pm`

| Method | Today (ShareLite) | After (IPC::Shareable) |
|--------|-------------------|------------------------|
| `meta` | `IPC::ShareLite->new(-key,-create,-destroy)` cached in `{meta_shm}` | `tie my %h,'IPC::Shareable',{key=>$shm_key,create=>1,destroy=>0}`; cache tied ref in `{meta_hash}` and knot in `{meta_knot}` |
| `meta_lock($flags)` | `$self->meta->lock($flags//LOCK_EX)` | `$self->{meta_knot}->lock($flags//LOCK_EX)` |
| `meta_unlock` | `$self->meta->unlock` | `$self->{meta_knot}->unlock` |
| `meta_fetch` | `decode_json($shm->fetch \|\| '{}')` | `return { %{ $self->{meta_hash} } }` (detached copy; `{}` when empty) |
| `meta_store($href)` | `$shm->store(encode_json $href)` | `%{ $self->{meta_hash} } = %$href` (whole-blob replace) |
| `meta_key` | `$self->meta->key` → `0x74697072` for `'rpit'` | `$self->{meta_knot}->seg->key` → **1473559184** for `'rpit'` (CRC32-derived) |
| `meta_key_check($key)` | `shmget(unpack('i',pack('A4',$key)),65536,0)` | `shmget(<crc32($key) w/ overflow correction>, 0, 0)` |
| `meta_set/get/delete/erase` | lock→fetch→mutate→store→unlock | **unchanged** — they ride on the four primitives above |

Imports: replace `use IPC::ShareLite qw(:flock)` with `use IPC::Shareable qw(:flock)`; drop the direct `use JSON::XS` (serialization now lives in IPC::Shareable); add `use String::CRC32 qw(crc32)` for `meta_key_check`'s standalone (no-object) key derivation.

New integer keys (for updating `t/02-shm_key.t`): `rpit` → **1473559184** (`0x57d4ba90`), `rpiw` → 1323166506, `blah` → 1311334748 (must still report "doesn't exist").

## Why `meta_fetch` returns a detached copy and neither primitive locks internally

- Callers mutate **nested** structures (`$meta->{pins}{$n}{...}`, `delete $meta->{objects}{$uuid}`) on the returned ref and only then call `meta_store`. A tied hash's `FETCH` returns deserialized nested data, so a top-level `{ %{ $tied } }` copy is safe to mutate; `meta_store` then writes the whole blob back. Returning the *live* tied ref would silently drop nested-only mutations.
- `meta_fetch`/`meta_store` must **not** take their own lock: callers already wrap them in `meta_lock`/`meta_unlock`. IPC::Shareable's `lock()` *releases* a differing lock before acquiring a new one, so an internal `LOCK_SH` inside `meta_fetch` would break a caller's surrounding `LOCK_EX`. (This matches ShareLite, whose `fetch`/`store` also didn't lock.)
- Under an `LOCK_EX` held by the caller, IPC::Shareable buffers writes and flushes on `unlock` — strictly better than the old per-call store, and transparent to callers.

## Risks / watch-items

- **`$self->{meta}{pins}` latent bug** (`Core.pm:289,300`): code reads `$self->{meta}` as if it were the blob, but that slot is never populated (the cache is `{meta_shm}`), so those reads are effectively no-ops today. Do **not** name the new tied ref `$self->{meta}` — that would silently change behavior. Preserve the bug; track the real fix as **B2**.
- **Key value changes** (CRC32 vs `pack`): only `t/02-shm_key.t` hard-codes the integer; update it (V4). No external consumer depends on the value.
- **Cross-process sharing** (`t/multi/*.pl`, `t/111`, `t/15x`): must still see each other's writes and clean up on death. Covered by V5/V7.
- **macOS vs Pi**: the WiringPi XS won't load on the dev Mac, so full `make test` is Pi-only. V2/V3 are Mac-runnable gates that exercise `Meta.pm` without loading the XS; V4–V8 run on the Pi.
- **Segment-size cap** (whole blob in one segment): both backends store the entire JSON blob in a single 64KB segment, so neither grows unboundedly — this is **not new** with IPC::Shareable. The only divergence is at the cap: IPC::Shareable *croaks* (`"Length of shared data exceeds shared segment size"`, `Shareable.pm:1277`) once the JSON exceeds the segment, where ShareLite may behave differently (couldn't verify — not installed). The RPi metadata (pins/objects + small user `storage`) is far under 64KB, but we should prove the headroom and pin down the cap behavior — covered by V10. Mitigation if ever needed: pass a larger `size` to the tie in `meta()`.

## Execution rules

- **One task per turn**: when told to proceed or continue (or "next", "go", etc.), perform only the next ⏳ V task listed, then stop and wait for further instruction. Do NOT batch multiple V tasks per turn unless the user explicitly authorizes a batch (e.g., "do V1-V3", "do all the style fixes").

## Maintenance rules

- V task ✅: do all three:
  1. Set Actual to `✅ YYYY-MM-DD attempt N: PASS`.
  2. Append a new bullet at the bottom of SHAREABLE-archive.md's "Archived V Tasks" section: `- V#: description — ✅ YYYY-MM-DD attempt N: PASS`. One bullet per entry — never run two entries together.
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
| V1 | Swap dependency: `Makefile.PL` requires `IPC::Shareable` (>= 1.17) not `IPC::ShareLite`; reassess `JSON::XS` (now transitive via IPC::Shareable) | `perl Makefile.PL 2>&1 \| tail; grep -E 'IPC::(Shareable\|ShareLite)' Makefile.PL` | `Makefile.PL` lists `IPC::Shareable`, no `IPC::ShareLite`; `perl Makefile.PL` runs without "prerequisite missing" for IPC::Shareable | ⏳ |
| V2 | Rewrite `Meta.pm` backend: `use IPC::Shareable qw(:flock)` + `String::CRC32`; reimplement `meta`, `meta_key`, `meta_lock`, `meta_unlock`, `meta_fetch`, `meta_store`, `meta_key_check` per the mapping table; leave `meta_set/get/delete/erase` logic intact; do NOT use `$self->{meta}` as the tied-ref slot | `perl -Ilib -c lib/RPi/WiringPi/Meta.pm` | `syntax OK` | ⏳ |
| V3 | Mac-runnable functional gate: new `build_testing/meta_shareable_check.pl` blesses a minimal object into `RPi::WiringPi::Meta` (no WiringPi XS) and round-trips lock/fetch/store, set/get/delete, erase(0/1), key, key_check(present/absent), and a fork to prove cross-process visibility | `perl -Ilib build_testing/meta_shareable_check.pl` | All assertions pass on macOS; segment auto-persists (not destroyed) between two runs | ⏳ |
| V4 | Update `t/02-shm_key.t`: expect `meta_key == 1473559184` for `'rpit'`; keep `meta_key_check('rpit')==1` and `('blah')==0` | (Pi) `prove -lv t/02-shm_key.t` | pass | ⏳ |
| V5 | Meta data tests on hardware | (Pi) `prove -l t/03-meta.t t/05-checksum_uuid.t t/110-register.t t/111-metadata_multi_pi_single_script.t` | all pass | ⏳ |
| V6 | Object/pin registration + cleanup paths (Core.pm/WiringPi.pm) | (Pi) `prove -l t/100-identification_and_label.t t/105-pin.t t/106-pin_map.t t/150-cleanup.t` | all pass; no pins left registered after cleanup | ⏳ |
| V7 | Signal-handler + multi-process death/cleanup (cross-process shm sharing) | (Pi) `RPI_MULTI=1 prove -l t/153-sig_handlers.t t/154-sig_die_multi.t t/155-sig_die.t` (and exercise `t/multi/{die,int,full}_{master,slave}.pl`) | masters see slaves' meta writes; cleanup-on-die removes only the dying object's entries | ⏳ |
| V8 | Full regression sweep on the Pi | (Pi) `RPI_<all>=1 make test` | whole suite green (no new skips/failures vs. pre-migration baseline) | ⏳ |
| V9 | Docs + housekeeping: update `Meta.pm` POD (key is now CRC32-derived; `meta_key_check` note), reconcile FAQ.pod `pimeta` text, add `Changes` entry at bottom of current section, update/retire `build_testing` Sharelite scratch files | `perl -Ilib -c lib/RPi/WiringPi/Meta.pm; podchecker lib/RPi/WiringPi/Meta.pm` | compiles; POD clean; `Changes` notes the backend swap | ⏳ |
| V10 | Segment-size headroom + cap behavior (Mac-runnable): extend the V3 harness to (a) store a worst-case-ish blob (~40 objects + 40 pins + a few KB of user `storage`) and confirm it round-trips with large headroom under 64KB; (b) deliberately overflow the segment and confirm IPC::Shareable croaks cleanly (no silent truncation/corruption); decide whether to bump `size` in `meta()` | `perl -Ilib build_testing/meta_shareable_check.pl --size` | realistic blob fits with wide margin and round-trips; oversized store croaks with a clear message, segment left intact | ⏳ |

## Discovery Tracking

_None yet._

## Backlog

B1: Optimize `meta_fetch` to a single segment decode. `{ %{ $tied } }` triggers one `FETCH` (full decode) per top-level key when unlocked (~6×). A one-shot snapshot helper would cut that to one decode.

B2: Fix the pre-existing `$self->{meta}{pins}` latent bug in `Core.pm` `_pin_registration` (lines 289, 300) — that slot is never populated, so the "pin already in use" guard and the returned pin list are dead. Decide whether to back them with `meta_fetch` or the tied hash.

B3: Add an explicit admin/removal tool to replace the documented `pimeta`/`pimetaerase`, built on `IPC::Shareable->remove` / `shm_segments` (no real script exists today).

B4: Update or retire the dev-scratch files that reference the old API: `build_testing/benchmark/sharelite_vs_memfile.pl` and `build_testing/shared_data.pl` (the latter calls `meta_fetch()`/`meta_store()` as functions, not methods — already broken).

## Explicitly NOT doing

- **Option B — native-tie rewrite of every caller.** Rejected: replacing `meta_fetch`/`meta_store` with direct tied-hash access would touch `Core.pm`, `WiringPi.pm`, `RPiTest.pm`, every `t/multi/*.pl`, and several `t/*.t`, for no behavioral gain. The `meta_*` shim keeps the blast radius inside `Meta.pm`.
- **Fixing the `$self->{meta}{pins}` latent bug as part of this migration** — preserve current behavior so the migration stays behavior-neutral; tracked as B2.
- **Preserving the old integer key `0x74697072`** — IPC::Shareable derives keys via CRC32 by design; the key value changes and that's fine since the segment is internal and discovered by `shm_key` string, not by hard-coded int.

## Decisions

- Tie a **HASH** (`var => 'HASH'` is the default) with `key => $self->{shm_key}, create => 1, destroy => 0`. `create=>1` = attach-or-create; `destroy=>0` = never auto-remove (matches ShareLite and the END-block guard at `Shareable.pm:2190`).
- `meta_fetch` returns a **detached** top-level copy; `meta_store` does a **whole-blob replace**; **neither locks internally** (callers own the lock). Rationale documented above.
- `meta_key` reads `->{meta_knot}->seg->key` (public `SharedMem::key`). `meta_key_check` uses `crc32` + overflow-correction (mirroring `IPC::Shareable::_shm_key`) then `shmget($int, 0, 0)` for a content-independent existence probe.
- Minimum `IPC::Shareable` version: **1.17** (installed; ships JSON-default serializer, `:flock`, `SharedMem::key`, and the destroy-guarded END block this plan relies on).
