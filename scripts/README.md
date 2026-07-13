# scripts/

Maintenance and documentation-generation scripts for the RPi::WiringPi family.

| Script | Purpose |
| --- | --- |
| `audit-family-buildcheck.pl` | Audit every family dist's `Makefile.PL` build guard for drift from the canonical wiringPi minimum version (read-only). |
| `check-family-repos.pl` | Report which family repos have uncommitted changes. |
| `sync-family-repos.pl` | Clone-or-update every family repo in one pass (refuses to run if any repo is dirty). |
| `gen-faq-test-table.pl` | Regenerate the "Test file reference" table in `FAQ.pod` from the test suite. |
| `gen-min-version.pl` | Sync the wiringPi minimum-version literal in the prose POD to `RPi::Const::WIRINGPI_MIN_VERSION`. |
| `gen-pod-md.pl` | Regenerate `docs/pod/*.md` markdown replicas from the distribution's POD. |
| `gen-test-platform.pl` | Regenerate the `docs/test-platform` pinout images and schematic artifacts. |
| `unit_test_board_revisions.pl` | Report the current KiCad revision of each unit-test-platform board. |
| `helpers/` | Python helpers backing `gen-test-platform.pl` (KiCad/board rendering, datasheet and board-lock checks). |
