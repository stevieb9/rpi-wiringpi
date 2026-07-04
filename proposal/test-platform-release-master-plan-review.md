# Debate: adversarial review of plans/test-platform-release-master.md

## Objective

Stress-test the master plan (test platform completion + family-wide CPAN release) that supersedes
the test-platform/coverage/datasheet plans: are its findings (F1-F10) factually correct, is its
structure (phases, task ordering, release train) right, and is it COMPLETE — what did it miss?
The debate's outcome is a concrete edit list applied to the plan file afterward.

Hard constraints held fixed: all commits/blesses/fab orders/CPAN uploads are the user's; plan-file
format rules (stable IDs, one-task-per-turn) are fixed; every claim had to be checkable on this
machine (the repo + the 20 family clones in ~/repos, inventoried 2026-07-03).

## Participants & outcome

- **claude** (originator) — declared: Claude (claude-fable-5)
- **challenger** — declared: Claude Fable 5 (claude-fable-5)
- Date: 2026-07-03 · Channel: /tmp/debate-1783080704-17546.md · 5 turns
- **Status: RESOLVED** — genuine convergence on a 12-point edit list; no contested points remain.

## Decision (the agreed 12-point edit list)

1. **V26 → two-directional re-derivation audit** (H1+H7): (a) every PREREQ floor resolvable at its
   release wave; (b) floors RAISED to fix-carrying versions wherever main's suite depends on fixed
   behavior (RPi::Pin→3.1802, RPi::EEPROM::AT24C32→1.00, each V12-V21 fix-carrier; RTC already
   correct at 0.03). V26 re-derives every "known defect" from the current tree (three parties
   propagated one stale fact in this debate). Changes sweep gains: rpi-i2c header, main's stale
   filenames, empty-UNREL cleanup (rpi-rtc-ds3231 0.04). V32 verifies raised floors are indexed
   before upload. Design bullet records the true edge set — const→all (post-V25, via
   CONFIGURE_REQUIRES); pin→main; raised floors→main — and re-labels waves 2/3 as risk convention.
2. **New V33 + F11 — canonical Arduino 0x04 sketch**: docs/sketch/arduino.ino and
   docs/sketch/arduino/arduino.ino ship as byte-identical duplicates (MANIFEST:46-47);
   rpi-i2c/examples/arduino.ino diverges functionally (`eeprom_save_byte(byte*)` vs `(byte)`,
   word endianness) and is NOT in rpi-i2c's MANIFEST beside 8 shipped examples/*.pl. Pick the
   canonical sketch, de-dup, reconcile-or-delete the fork, fix FAQ.pod (~line 1500); V10/V28 gain
   "verify/flash the rig Arduino with the canonical sketch".
3. **V27 filename fix + renumber sweep in V3 + F12**: V27 said "t/109/t/140" (now t/400/t/405);
   t/543-eeprom_validation.t:10 cites "t/420-422" for what is now t/540-542. V3 gains a mechanical
   old→new renumber-map sweep across t/*.t comments, docs/, POD.
4. **Census corrections** (H4): RPI_BOARD gates are 1/6/2/16/4 = 29 gated, 63 board-independent
   (plan said ×17/62); board-4 "unblocks 16" (not 17).
5. **V30 gains the wiringpi.com sweep + F13**: six dead-site links in wiringpi-api
   (API.pm:1922, 1926, 2516, 2572, 2652, 2825) → github.com/WiringPi/WiringPi + an explicit
   install-≥3.18 pointer (fork's latest tag v3.19).
6. **V9 rescoped to mechanism unification only** (H6): as positioned it reached forward to V10
   ("bless board-5 after V10") — undischargeable under one-task-per-turn. Blesses move to V8/V10.
7. **V6 retired — zombie task** (H7): every fix it planned (DS3231 setMonth/setHour BCD, getTemp
   sign-extension) was released 2026-06-22 as rpi-rtc-ds3231 0.02/0.03 (CPAN at 0.03). Hardware
   table + driver-debt Design bullet corrected; claude's Turn-3 negative-temp extension withdrawn
   (fixed in the same 0.02).
8. **V7 rescoped to 1.00 residue** (H7b): eeprom_write_block was already REMOVED (Changes 1.00
   UNREL; zero grep hits in AT24C32.xs). Remaining: dead static _writeBlock (AT24C32.xs:47),
   orphaned eeprom_read_current_byte/eeprom_close disposition, tests for the 1.00 changes.
9. **V28 split** (H8): 13 of 20 sub-dists are XS (compile against wiringPi.h / linux i2c headers,
   link -lwiringPi/-lrt) and main's t/RPiTest.pm:33-36 hard-uses RPi::WiringPi + WiringPi::API —
   `make disttest` is impossible on mac. Pi leg: disttest all 21. Mac leg:
   `RPI_DIST_RELEASE=1 make dist` + MANIFEST verification (+ optional rpi-const disttest).
10. **18 leaves, not 17** (H9): 20 sub-dists − const (wave 1) − api (wave 2) = 18 in wave 3.
11. **Schematic rev stamping** (H10): live mismatches on LOCKED boards — board-2 sch rev unset vs
    PCB 4; board-5 sch unset vs PCB 1. Stamp in V4 (board-2 reopens there) / V8 / V10; B22 becomes
    the lockstep rule PLUS fixing unit_test_board_revisions.pl's blind spot (it only flags when a
    sch rev EXISTS and differs — set-vs-unset passes silently).
12. **Dents**: V7's original "driver debt" label was half wrong even in June (eeprom_write_block
    was "off the OO path… no live caller" — hygiene, not a bring-up gate); F6's pointer corrects
    to board-layout-proposal.md:217/:239; V24 gains an explicit ship-or-author-only disposition
    for t/scripts/*.sh (zero MANIFEST entries while the shipped FAQ references them).

## Major points

**Challenger's strongest:**
- **H7 (the kill):** the plan's board-4 "driver debt" task was already shipped eleven days before
  the plan was written — and the stale fact propagated through the plan, claude's Turns 1/3, AND
  the challenger's own Turn-2 H1 example. Made structural: V26 is now an audit that re-derives
  every claimed defect from the current tree.
- **H1:** the release train's stated rationale was measurably false — 20 of 21 floors already
  resolve on today's CPAN (sole failing edge: RPi::Pin 3.1802); no leaf floors WiringPi::API above
  the live 3.1803. The REAL constraint is the inverse: main's suite depends on fixed leaf behavior
  its floors don't demand (e.g. Changes calls t/530 "the on-silicon falsification for the DS3231
  BCD fix" — a floors-minimal install must still pass it).
- **H2:** three copies of the Arduino 0x04 firmware, two behaviors, zero plan coverage — the same
  reproducibility logic as the plan's own F4, applied to flashed firmware.
- **H8:** V28's mac disttest command was physically impossible for 13 XS dists + main.

**Claude's strongest:**
- F1 (RPi::Pin floor unsatisfiable), F3 (board-5 frozen-but-unblessed), F4 (board-2 not
  reproducible from the repo: symbol only in a gitignored restore-backup; `RPi:` footprint alias
  in no repo fp-lib-table) — all survived adversarial verification unchanged.
- Board order 4→5→1 survived: the challenger tried hub-first and conceded on the nets doc (I2C
  pull-ups live on built board-3; GPIO18 already jumpers to board-2; the rig works hubless).
- Extensions past the challenger's own evidence: the sixth wiringpi.com link (API.pm:2825) and the
  DS3231 negative-temp bug (later withdrawn when H7 proved it already fixed — the withdrawal
  itself validating the audit-first lesson); the unit_test_board_revisions.pl blind spot.

## Points of agreement

Everything in the Decision list, plus: the plan's spine held (findings F1-F5, F8-F10 substance;
lock unification target; supersession scope including keeping wiringpi-version-single-source.md
separate with V25 gating; carrying only V47 from the done/ conformance plan — its V24 verified
overtaken by the 3.1802 release). Verified-clean hunting grounds: GPSD::Parse 1.03 and
IPC::Shareable 1.17<1.18 floors satisfied (1.19 UNREL non-gating; B21 correctly scoped), crontab
carries no test-file references, MANIFEST.SKIP matches the plan's tarball claims, board-3 revs
clean (sch 2 = PCB 2).

## Failures to agree

None. RESOLVED with no contested residue.

## Transcript (condensed; no arguments, concessions, or decisions dropped)

### Turn 1 — claude
Named itself Claude (claude-fable-5). Position: the plan is evidence-correct; defended F1 (Pin
floor: Makefile.PL:59 vs Pin.pm:11 vs CPAN 3.1801), F4 (ZC261500.kicad_sym only in gitignored
backup; `RPi:` alias unresolvable from repo), F3 (%FROZEN {2,3,5} vs board-locks.json {2,3}),
board order 4→5→1 (16-file unblock — stated then as 17; hub last per proposal), driver-debt-first
(June audit's DS3231/AT24C32 defects), and the serial train (const→api→leaves→main; all 21 dists
UNREL). Demanded attack on: the serial-train floor basis, hub-first board order, supersession
scope, and specific miss candidates (Arduino firmware, WiringPi-fork install story, RPiTest ADC
windows vs ADS1015, t/scripts in MANIFEST, PAUSE permissions).

### Turn 2 — challenger
Named itself Claude Fable 5 (claude-fable-5). Conceded after verification: F1 (and confirmed the
LIVE 3.1802 release was installable — the floor bump came ten days post-release, so F1 is
future-only, as scoped); F2/F3/F4/F5/F8/F10 verified as written; board order 4→5→1 (hub-first dies
on the nets doc: board-3 carries the I2C pull-ups; GPIO18 jumpers hubless today); two invited
misses ruled duds (RPiTest windows are empirical percent windows keyed by board family and already
say ADS1015; PAUSE first-come applies inside the user's indexed dist); supersession scope correct
(conformance plan's other findings all resolved; only V47 carries).
Landed six hits: **H1** floors (20/21 resolve; nothing floors API 3.1804; main's suite requires
fixed leaf behavior floors don't demand — RTC floored 0.03 vs t/530's BCD falsification [example
later corrected by its own H7]; demanded two-directional V26 + true edge set); **H2** Arduino
firmware triplication (MANIFEST:46-47 identical dup + divergent unshipped rpi-i2c fork; demanded
new V row + rig-flash checklist); **H3** stale filenames in the plan itself (V27's t/109/t/140)
and in t/ (t/543:10); **H4** census wrong (×16 not ×17; 29/63 not 30/62); **H5** wiringpi-api POD
points users at defunct wiringpi.com (five sites cited); **H6** V9 undischargeable as positioned
(reaches forward to V10). Dents: V7's bring-up-gate justification half wrong (write_block had no
live caller); F6 pointer off (:217/:239 not :223); t/scripts not in MANIFEST.

### Turn 3 — claude
Verified and conceded H1-H6 with independent measurement; adopted all demanded edits. Extended two:
the SIXTH wiringpi.com link (API.pm:2825) and — from the same audit table as dent (a) — the DS3231
negative-temp sign-extension bug added to V6's scope. Accepted all three dents. Issued convergence
demand: one more sweep or RESOLVED; pointed the challenger at GPSD/IPC::Shareable floors, generated
docs staleness, board-3 rev history, cross-dist unreleased-version references.

### Turn 4 — challenger
The sweep found **H7**: rpi-rtc-ds3231 0.02/0.03 (both 2026-06-22, released; CPAN at 0.03) already
carry every V6 fix — setMonth/setHour BCD, getTemp sign-extension ((int8_t)msb, DS3231.xs:188-190),
setBcdField routing, BCD tests; 0.04 UNREL is empty. Consequences: V6 is a zombie; the plan's
hardware-table line false; claude's Turn-3 extension stale-squared (must withdraw); the
challenger's OWN H1 RTC example dies (0.03 IS the fix carrier) — "Rule 5 cuts every way."
**H7b**: eeprom_write_block already REMOVED (1.00 UNREL; zero grep hits) — V7 half-zombie, rescope
to residue. **H8**: V28's "disttest on mac" impossible — 13 XS dists enumerated; RPiTest.pm:33-36
hard-use; RPI_DIST_RELEASE scoped to make dist by its own comment. **H9**: leaves = 18, not 17.
**H10**: sch-rev mismatches live on locked boards 2 (unset vs 4) and 5 (unset vs 1). Honest
disposition of claude's hunting grounds: all clean; accepted the :2825 extension. Offered
convergence conditional on adoption.

### Turn 5 — claude
Verified all of Turn 4 (including a counter-probe on the XS census — exactly 13, no omission
found). Conceded H7 (V6 retired; hardware table + Design bullet corrected; Turn-3 extension
formally WITHDRAWN; V26 restructured as re-derivation audit; residue: empty 0.04 UNREL section
added to V26's sweep), H7b (V7 rescoped), H8 (V28 Pi/mac split), H9 (18 leaves), H10 (stamping in
V4/V8/V10 + extended: unit_test_board_revisions.pl's set-vs-unset blind spot is WHY the mismatch
went unreported — folded into B22). Declared the consolidated 12-point list, set
RESOLUTION: RESOLVED, TURN_OWNER: DONE.
