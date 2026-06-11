# Archive — completed V tasks and resolved fixes

## Archived V Tasks

- V20: Review rpi-wiringpi documentation (POD, README, FAQ, docs/pod staleness) — ✅ 2026-06-10 attempt 1: PASS — findings catalogued as F14, F25–F32
- V21: Review rpi-wiringpi Perl code (WiringPi.pm/Core.pm/Util.pm/Meta.pm + bin/) — ✅ 2026-06-10 attempt 1: PASS — findings catalogued as F10, F15, F16–F24
- V22: Review rpi-wiringpi tests (69 t/*.t + RPiTest.pm) — ✅ 2026-06-10 attempt 1: PASS — findings catalogued as F11, F12, F13, F33–F37
- V1: Baseline — confirm installed WiringPi::API/RPi::Const + legacy module — ✅ 2026-06-10 attempt 1: PASS — WiringPi::API 3.1802_01, RPi::Const 1.05, stale RPi::WiringPi::Constant 1.02 still installed (masks sibling breakage); recorded in F5
- V2: rpi-spi — fix `:wiringPi`/`:perl` mismatch (F1) with camelCase `pinMode`/`digitalWrite` (user's choice) — ✅ 2026-06-10 attempt 1: PASS (build + `PI_BOARD=1 RPI_OBJECT_COUNT=0 prove -blv t` clean; all four subs verified resolving in RPi::SPI namespace; includes Fix 2)
- V31: [RELEASE-BLOCKING] MANIFEST drift (F41) — removed 3 phantom entries (`docs/interrupt-examples.md`, `docs/threads-examples.md`, `t/README`), added `docs/examples/*.md` — ✅ 2026-06-10 attempt 1: PASS (manicheck clean; `make distdir` succeeds and ships docs/examples; `PI_BOARD=1 RPI_RELEASE_TESTING=1 prove -bl t/515*` passes)

## Archived Fixes

- Fix 2: problem discovered during V2 — `rpi-spi rw():35,37` bracketed the SPI transfer with `pin_mode($cs, 0/1)` (flips pin INPUT/OUTPUT → CS floats mid-transfer) where the intent — per `new()` establishing OUTPUT + idle-HIGH and the 0/1 args — was level writes. Translated to `digitalWrite($cs, 0/1)` rather than mechanical `pinMode`, fixing the latent bug in the previously-dead bit-bang path. Resolved 2026-06-10 as part of V2.
- Fix 1: problem discovered during V31 — t/515 (`Test::CheckManifest::ok_manifest`) also checks disk→MANIFEST, so untracked dev artifacts failed it. Added never-shipped dev/generated paths to MANIFEST.SKIP (`.claude/`, `UNWRAPPED.md`, `docs/pod/`, `docs/test-platform/`, `plans/`, `proposal/`, `scripts/`) and added the one missing file in an already-shipped dir (`build_testing/meta_shareable_check.pl`) to MANIFEST. Resolved 2026-06-10 as part of V31.
