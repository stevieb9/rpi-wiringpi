# TESTDOC: Test-platform model validation
use warnings;
use strict;

use Test::More;
use File::Basename;
use File::Spec;

# Structural (non-hardware) gate for the docs/test-platform pipeline.
#
# The board model is hand-curated in scripts/helpers/board-model.py and
# independently re-derived in model-from-tests.py; the schematic, KiCad project
# and pin docs are all rendered from it. This test fails the build if the two
# models drift apart, or if the generated KiCad project no longer validates.
#
# It needs python3 and the dev tooling, so it skips cleanly on a host without
# python or on an installed dist that doesn't ship scripts/helpers/.

my $root    = File::Spec->rel2abs(
    File::Spec->catdir(dirname(__FILE__), File::Spec->updir)
);
my $helpers = File::Spec->catdir($root, 'scripts', 'helpers');
my $drift   = File::Spec->catfile($helpers, 'check-model-drift.py');
my $kicad   = File::Spec->catfile($helpers, 'check-kicad.py');
my $render  = File::Spec->catfile($helpers, 'render-doc.py');
my $locks   = File::Spec->catfile($helpers, 'check-board-locks.py');
my $nets    = File::Spec->catfile($helpers, 'check-board-nets.py');
my $sheets  = File::Spec->catfile($helpers, 'check-datasheets.py');

my $python = which('python3');

plan skip_all => 'python3 not found'
    if ! $python;
plan skip_all => 'test-platform dev tooling not present (installed dist?)'
    if ! -f $drift || ! -f $kicad;

# 1. Drift gate: the independent re-derivation must match the canonical model.
my $drift_out = qx("$python" "$drift" 2>&1);
is $? >> 8, 0, 'test-platform model: re-derivation matches canonical board-model.py'
    or diag $drift_out;

# 2. Each populated KiCad board project under docs/test-platform/kicad/ still
#    validates (every symbol's footprint resolves and covers its pins - the
#    "Update PCB from Schematic" invariant). Each board is its own self-contained
#    project subdirectory (rpi-wiringpi-unit-test-platform-board-N/);
#    those are scaffolded once by gen-kicad.py then hand-managed, so empty
#    placeholders (no .kicad_sch yet) are skipped rather than failed.
# Hand-managed boards are FROZEN: once a board is being hand-finalized in KiCad
# (custom parts and stock footprints that intentionally diverge from the
# generated scaffold) it is deliberately left untouched. Validating such a board
# here would be both wrong and a way for it to break the build, so frozen boards
# are listed here and skipped entirely.
#   board-2: finalized + ordered.
#   board-3: finalized + ordered.
#   board-4: finalized + ordered.
#   board-5: finalized + ordered.
my %FROZEN = (
    'rpi-wiringpi-unit-test-platform-board-2' => 1,
    'rpi-wiringpi-unit-test-platform-board-3' => 1,
    'rpi-wiringpi-unit-test-platform-board-4' => 1,
    'rpi-wiringpi-unit-test-platform-board-5' => 1,
);

my $kroot = File::Spec->catdir($root, 'docs', 'test-platform', 'kicad');
my @projects;

if (opendir my $dh, $kroot) {
    for my $name (sort readdir $dh) {
        next if $name =~ /^\./;

        if ($FROZEN{$name}) {
            note "frozen (hand-managed) board left untouched: $name";
            next;
        }

        my $dir = File::Spec->catdir($kroot, $name);
        next if ! -d $dir;
        my @sch = glob File::Spec->catfile($dir, '*.kicad_sch');
        push @projects, [$name, $dir] if @sch;
    }
    closedir $dh;
}

SKIP: {
    skip 'no populated KiCad board projects under docs/test-platform/kicad', 1
        if ! @projects;

    for my $project (@projects) {
        my ($name, $dir) = @$project;
        my $kicad_out = qx("$python" "$kicad" "$dir" 2>&1);
        is $? >> 8, 0, "test-platform KiCad project validates: $name"
            or diag $kicad_out;
    }
}

# 3. The generated pin doc must be up to date with its template + sources
#    (its only generated block, the Pi5 default-state table, comes from
#    RPiTest.pm). A stale doc fails here.
SKIP: {
    skip 'render-doc.py not present', 1
        if ! -f $render;

    my $render_out = qx("$python" "$render" --check 2>&1);
    is $? >> 8, 0, 'test-platform pin doc is up to date with its template'
        or diag $render_out;
}

# 4. Board lock: every finalized (blessed) board must be byte-for-byte unchanged
#    from its committed snapshot. A blessed board cannot drift without an explicit
#    re-bless (scripts/helpers/check-board-locks.py --bless). This is the positive
#    enforcement behind the %FROZEN skip above - those boards are skipped from KiCad
#    validation precisely because they are hand-finalized, so this freezes them.
SKIP: {
    skip 'check-board-locks.py not present', 1
        if ! -f $locks;

    my $lock_out = qx("$python" "$locks" 2>&1);
    is $? >> 8, 0, 'finalized KiCad boards are unchanged since their bless'
        or diag $lock_out;
}

# 5. Board nets: each board that has both a built PCB and a board-N-model.py must
#    still implement that model pin-for-pin (PCB always; schematic too when
#    kicad-cli is available). Catches a hand-edit that moves a net off the pin the
#    tests expect - the gap neither the drift gate nor KiCad validation covered.
SKIP: {
    skip 'check-board-nets.py not present', 1
        if ! -f $nets;

    my $nets_out = qx("$python" "$nets" 2>&1);
    is $? >> 8, 0, 'finalized KiCad boards still implement their board model'
        or diag $nets_out;
}

# 6. Datasheet consistency (the ALL-STOP rule): every board model's IC pin map
#    must match the manufacturer datasheet, recorded independently in
#    datasheet-pinouts.json. A mismatch means the datasheet contradicts the
#    design - the build stops so a human can resolve it.
SKIP: {
    skip 'check-datasheets.py not present', 1
        if ! -f $sheets;

    my $sheet_out = qx("$python" "$sheets" 2>&1);
    is $? >> 8, 0, 'board models match the IC datasheets (datasheet-pinouts.json)'
        or diag $sheet_out;
}

done_testing();

# Locate an executable on PATH.
sub which {
    my ($prog) = @_;

    for my $dir (split /:/, ($ENV{PATH} // '')) {
        my $path = File::Spec->catfile($dir, $prog);
        return $path if -x $path;
    }

    return undef;
}
