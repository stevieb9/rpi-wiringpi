# Plan: Convert RPi::WiringPi shared-memory backend from IPC::ShareLite to IPC::Shareable

> **NEXT ACTION:** V7 — signal-handler + multi-process death/cleanup (`t/153`, `t/154`, `t/155` + `t/multi/*.pl`) with `RPI_MULTI=1` and the Pi env vars.
> **ENV:** Work runs **on the Raspberry Pi itself** (perlbrew 5.42.0), NOT a Mac. `WiringPi::API` (XS) loads here, so the full suite is runnable locally — the plan's old Mac/Pi gating is moot. Pre-migration state on this box: `IPC::ShareLite 0.17` IS installed (so `Meta.pm` loads today — the "build-unblock" was Mac-only); `IPC::Shareable 1.17` + `String::CRC32 2.100` now installed; `JSON::XS 4.04` present.
> **HARDWARE PRECONDITION (applies to V6/V7/V8):** Tests that verify "pins reset to default mode" (`rpi_check_pin_status`, RPiTest.pm:123-156) compare physical GPIO against pristine power-on defaults — they FAIL if pins are left in a non-default mode by a prior aborted/crashed run. This is environmental, NOT a code bug. Before running these tests, reset offending pins: `gpio -g mode <pin> in` for alt-0 defaults, `pinctrl set <pin> no` for alt-31 ("no-function") defaults. On this Pi5: 18→alt0, 24/25→alt31.
> **LAST SESSION:** V6 PASS — t/100, t/105, t/106, t/150 all green. t/150 initially died "pin 18 is already in use"; root cause was **Fix 1** — the `_pin_registration` unregister ownership guard at `Core.pm:272` was a no-op (`users{$uuid}` holds a count, but the guard compared that count `ne $self->uuid`, always true → never deleted the pin). A branch-only bug from commit `61eacd7` (NOT on master, predates the migration), fixed to `! exists ...{users}{$param{requester}}`. **Uncommitted code change: `lib/RPi/WiringPi/Core.pm`.** Earlier: V5 PASS (hardware meta tests; failures were stale pin-state), V4 PASS (t/02 key update), V3 PASS (no-XS gate), V2 PASS (tie-a-scalar rewrite), V1 PASS (Makefile.PL dep swap).
> **ARCHIVE:** See SHAREABLE-archive.md for completed V tasks (V1-V6) and Fix 1

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
- Module availability is **per-machine**. On the **Pi (where we work)**: `IPC::ShareLite 0.17` IS installed (so `Meta.pm` loads today), while `IPC::Shareable` and `String::CRC32` were NOT — installed as a pre-V1 step. (The original plan's "Shareable installed / ShareLite missing / Meta.pm can't load / build-unblock" line described the Mac and does not apply here.)
- `pimeta`/`pimetaerase` are referenced only in `lib/RPi/WiringPi/FAQ.pod` (docs), not as real scripts.
- IPC::Shareable's `END`/`_end` block removes a segment **only** when its `destroy` attribute is true (`lib/IPC/Shareable.pm:2190`). There is **no** per-object `DESTROY` remover. So `destroy => 0` preserves the segment exactly like ShareLite's `-destroy => 0`.
- `IPC::Shareable::SharedMem` exposes a public integer-key accessor `->key` (`SharedMem.pm:95`).
- IPC::Shareable's `:flock` exports `LOCK_EX/SH/NB/UN` with the same numeric values as `Fcntl` flock — `meta_lock(LOCK_EX)` maps 1:1.
- IPC::Shareable defaults to the JSON serializer and a 65536-byte segment (`SHM_BUFSIZ`). The current code passes no `-size` to ShareLite, so it uses ShareLite's own default (also ~65536) — default segment sizes line up. Behavior *at* the cap differs, though (see Risks / V10): IPC::Shareable croaks once the serialized payload exceeds the segment, whereas ShareLite's >64KB behavior is unverified here (not installed). For the **tie-a-scalar** design adopted here, the whole blob lives in one segment exactly like ShareLite, so it is **not** a regression for the small RPi metadata.
- **IPC::Shareable does NOT collapse nested structures into one segment.** Per its docs: *"When using nested data structures, each nested structure utilizes an additional shared memory segment. The entire structure is not squashed into a single segment."* This is why we **tie a SCALAR holding a JSON string** rather than tying a HASH and storing the blob natively — a native HASH tie would fan this nested blob out across many segments (risking the system `SHMMNI` cap) and would hand callers tied nested refs (live shared-memory writes through `$meta->{pins}{...}`).

## Method mapping (ShareLite → Shareable), all within `Meta.pm`

| Method | Today (ShareLite) | After (IPC::Shareable, tie-a-scalar) |
|--------|-------------------|------------------------|
| `meta` | `IPC::ShareLite->new(-key,-create,-destroy)` cached in `{meta_shm}` | `my $knot = tie my $blob,'IPC::Shareable',{key=>$shm_key,create=>1,destroy=>0}`; cache `\$blob` in `{meta_scalar}` and the knot in `{meta_knot}`; return the knot |
| `meta_lock($flags)` | `$self->meta->lock($flags//LOCK_EX)` | `$self->meta->lock($flags//LOCK_EX)` (knot's `lock`) |
| `meta_unlock` | `$self->meta->unlock` | `$self->meta->unlock` (knot's `unlock`) |
| `meta_fetch` | `decode_json($shm->fetch \|\| '{}')` | `my $j = ${ $self->{meta_scalar} }; return (defined $j && length $j) ? decode_json($j) : {}` (always detached — JSON decode yields fresh data) |
| `meta_store($href)` | `$shm->store(encode_json $href)` | `${ $self->{meta_scalar} } = encode_json($href)` (whole-blob replace, single segment) |
| `meta_key` | `$self->meta->key` → `0x74697072` for `'rpit'` | `$self->meta->seg->key` → **1473559184** for `'rpit'` (CRC32-derived) |
| `meta_key_check($key)` | `shmget(unpack('i',pack('A4',$key)),65536,0)` | `shmget(<crc32($key) w/ overflow correction>, 0, 0)` |
| `meta_set/get/delete/erase` | lock→fetch→mutate→store→unlock | **unchanged** — they ride on the four primitives above |

**Why a scalar, not a hash:** storing an explicit `encode_json` **string** in a tied SCALAR keeps the entire blob in ONE segment (mirroring ShareLite) and sidesteps IPC::Shareable's per-nested-ref segment fan-out. It also makes `meta_fetch`'s detached-copy guarantee trivially correct (every `decode_json` returns brand-new, fully-untied data — safe to mutate nested keys before `meta_store`). A native HASH tie would break both properties (see Risks).

Imports: replace `use IPC::ShareLite qw(:flock)` with `use IPC::Shareable qw(:flock)`; **keep `use JSON::XS`** (we still hand-serialize the blob to a string ourselves); add `use String::CRC32 qw(crc32)` for `meta_key_check`'s standalone (no-object) key derivation.

New integer keys (for updating `t/02-shm_key.t`): `rpit` → **1473559184** (`0x57d4ba90`), `rpiw` → 1323166506, `blah` → 1311334748 (must still report "doesn't exist").

## Why `meta_fetch` returns a detached copy and neither primitive locks internally

- Callers mutate **nested** structures (`$meta->{pins}{$n}{...}`, `delete $meta->{objects}{$uuid}`) on the returned ref and only then call `meta_store`. With the **scalar-of-JSON** design, `meta_fetch` runs `decode_json` on the stored string, which returns a brand-new, fully **untied** structure every time — nested mutations are purely local until `meta_store` re-serializes and writes the whole blob back. (This is exactly ShareLite's behavior.) **Note:** had we tied a HASH instead, `FETCH` would return *tied* nested refs and a shallow `{ %{ $tied } }` copy would leak live shared-memory writes — which is the core reason we tie a scalar.
- `meta_fetch`/`meta_store` must **not** take their own lock: callers already wrap them in `meta_lock`/`meta_unlock`. IPC::Shareable's `lock()` *releases* a differing lock before acquiring a new one, so an internal `LOCK_SH` inside `meta_fetch` would break a caller's surrounding `LOCK_EX`. (This matches ShareLite, whose `fetch`/`store` also didn't lock.)
- Under an `LOCK_EX` held by the caller, IPC::Shareable buffers the scalar write and flushes on `unlock` — strictly better than the old per-call store, and transparent to callers.

## Risks / watch-items

- **(Resolved) former `$self->{meta}{pins}` bug** — already fixed in commit `c50f8f8`; `_pin_registration` now uses the local `my $meta = $self->meta_fetch` throughout and there are no `$self->{meta}` slot reads left in `lib/`. Still, do **not** name the new cache slot `$self->{meta}` (keep `{meta_scalar}`/`{meta_knot}`) to avoid reintroducing confusion. B2 retired.
- **Key value changes** (CRC32 vs `pack`): only `t/02-shm_key.t` hard-codes the integer; update it (V4). No external consumer depends on the value.
- **Cross-process sharing** (`t/multi/*.pl`, `t/111`, `t/15x`): must still see each other's writes and clean up on death. Covered by V5/V7.
- **Environment (Pi, not Mac)**: all work runs on the Raspberry Pi where `WiringPi::API` loads, so the **entire suite is runnable locally** — the original Mac/Pi split no longer applies. V2/V3/V10 remain useful as fast **no-XS gates** (they exercise `Meta.pm` without pulling in the hardware modules), but they're a convenience here, not a necessity.
- **Nested-structure segment fan-out** (the reason for tie-a-scalar): IPC::Shareable gives **each nested ref its own segment** when you store native structures. This is NOT a HASH-only behavior — scalar `STORE` does it too: `_magic_tie($knot,$val) if ref($val) && $knot->_need_tie($val)` (`Shareable.pm` STORE), which `tie`s each nested ref into a child segment. So storing a hashref into the tied scalar would *also* fan out (and hand callers tied nested refs). The only way to stay single-segment is to hand IPC::Shareable a **non-ref scalar** — hence our own `encode_json` string is **mandatory**, not just convenient. If anyone later "simplifies" `meta_store`/`meta_fetch` to assign a structure (hash or ref) instead of a string, this regression returns — keep the serialize-to-string boundary.
- **Double serialization is expected and benign** (correctness-wise): a plain string stored in a tied scalar is itself re-serialized by IPC::Shareable (wrapped as `{ '__sv__' => $val }` then JSON-encoded), so our JSON blob is JSON-encoded a second time. It round-trips cleanly. The only practical cost is **size inflation** — the second pass escapes every `"`, so the bytes actually written to the segment run ~20–40% larger than our raw JSON, lowering the *effective* 64KB headroom. Measure the as-stored size, not raw JSON length (see V10).
- **Segment-size cap** (whole blob in one segment): with the scalar-of-JSON design both backends store the entire JSON blob in a single 64KB segment, so neither grows unboundedly — this is **not new** with IPC::Shareable. The only divergence is at the cap: IPC::Shareable *croaks* (`"Length of shared data exceeds shared segment size"`, `Shareable.pm:1277`) once the serialized string exceeds the segment, where ShareLite may behave differently (couldn't verify — not installed). The RPi metadata (pins/objects + small user `storage`) is far under 64KB, but we should prove the headroom and pin down the cap behavior — covered by V10. Mitigation if ever needed: pass a larger `size` to the tie in `meta()`.

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
| V7 | Signal-handler + multi-process death/cleanup (cross-process shm sharing) | (Pi) `PI_BOARD=1 RPI_OBJECT_COUNT=0 RPI_PIN_COUNT=0 RPI_MULTI=1 prove -l t/153-sig_handlers.t t/154-sig_die_multi.t t/155-sig_die.t` (and exercise `t/multi/{die,int,full}_{master,slave}.pl`) | masters see slaves' meta writes; cleanup-on-die removes only the dying object's entries | ⏳ |
| V8 | Full regression sweep on the Pi | (Pi) `PI_BOARD=1 RPI_OBJECT_COUNT=0 RPI_PIN_COUNT=0 RPI_MULTI=1 RPI_POD=1 make test` (add `RPI_SUDO=1`/run under sudo for the GPIO-touching tests) | whole suite green (no new skips/failures vs. pre-migration baseline) | ⏳ |
| V9 | Docs + housekeeping: update `Meta.pm` POD (key is now CRC32-derived; `meta_key_check` note), reconcile FAQ.pod `pimeta` text, update/retire `build_testing` Sharelite scratch files. **Do NOT touch `Changes`** — the user adds a single entry at project completion. | `perl -Ilib -c lib/RPi/WiringPi/Meta.pm; podchecker lib/RPi/WiringPi/Meta.pm` | compiles; POD clean | ⏳ |
| V10 | Segment-size headroom + cap behavior (no-XS gate): extend the V3 harness to (a) store a worst-case-ish blob (~40 objects + 40 pins + a few KB of user `storage`) and confirm it round-trips with large headroom under 64KB **in a single segment**, measuring the **as-stored (double-serialized) byte size** vs. our raw JSON length to quantify the escaping inflation; (b) deliberately overflow the segment and confirm IPC::Shareable croaks cleanly (no silent truncation/corruption); decide whether to bump `size` in `meta()` | `perl -Ilib build_testing/meta_shareable_check.pl --size` | realistic blob fits with wide margin in one segment and round-trips; report shows as-stored bytes (inflated) under cap; oversized store croaks with a clear message, segment left intact | ⏳ |

## Discovery Tracking

_None yet._

## Backlog

B3: Add an explicit admin/removal tool to replace the documented `pimeta`/`pimetaerase`, built on `IPC::Shareable->remove` / `shm_segments` (no real script exists today).

B4: Update or retire the dev-scratch files that reference the old API: `build_testing/benchmark/sharelite_vs_memfile.pl` and `build_testing/shared_data.pl` (the latter calls `meta_fetch()`/`meta_store()` as functions, not methods — already broken).

## Explicitly NOT doing

- **Option B — native-tie rewrite of every caller.** Rejected: replacing `meta_fetch`/`meta_store` with direct tied-hash access would touch `Core.pm`, `WiringPi.pm`, `RPiTest.pm`, every `t/multi/*.pl`, and several `t/*.t`, for no behavioral gain. The `meta_*` shim keeps the blast radius inside `Meta.pm`.
- **B2 (former `$self->{meta}{pins}` bug)** — retired: already fixed independently in commit `c50f8f8`, so there's nothing left for the migration to preserve or repair. The `B2` slot is retired (never reused).
- **Preserving the old integer key `0x74697072`** — IPC::Shareable derives keys via CRC32 by design; the key value changes and that's fine since the segment is internal and discovered by `shm_key` string, not by hard-coded int.
- **Tying a HASH and storing the blob natively (former B1 / original mapping)** — rejected. IPC::Shareable allocates a separate segment per nested ref, so a native HASH tie fans this blob across many segments (SHMMNI risk) and returns tied nested refs to callers (live writes through `$meta->{...}`). The scalar-of-JSON design stores one segment and one decode per fetch, so the old B1 "single segment decode" optimization is moot by construction. The `B1` slot is retired (never reused).

## Decisions

- Tie a **SCALAR** holding an `encode_json` **string** (NOT a HASH) with `key => $self->{shm_key}, create => 1, destroy => 0`. `create=>1` = attach-or-create; `destroy=>0` = never auto-remove (matches ShareLite and the END-block guard at `Shareable.pm:2190`). A scalar-of-string keeps the whole blob in ONE segment and avoids IPC::Shareable's per-nested-ref segment fan-out; a HASH tie was rejected for that reason.
- `meta_fetch` `decode_json`s the scalar to a **fully detached** structure; `meta_store` `encode_json`s a **whole-blob replace** into the scalar; **neither locks internally** (callers own the lock). Rationale documented above.
- `meta_key` reads `$self->meta->seg->key` (public `SharedMem::key` on the knot). `meta_key_check` uses `crc32` + overflow-correction (mirroring `IPC::Shareable::_shm_key`) then `shmget($int, 0, 0)` for a content-independent existence probe.
- Minimum `IPC::Shareable` version: **1.17** (installed; ships JSON-default serializer, `:flock`, `SharedMem::key`, and the destroy-guarded END block this plan relies on).
