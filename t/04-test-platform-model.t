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
#    project subdirectory (legacy/, rpi-wiringpi-unit-test-platform-board-N/);
#    those are scaffolded once by gen-kicad.py then hand-managed, so empty
#    placeholders (no .kicad_sch yet) are skipped rather than failed.
# Hand-managed boards are FROZEN: once a board is being hand-finalized in KiCad
# (custom parts and stock footprints that intentionally diverge from the
# generated scaffold) it is deliberately left untouched. Validating such a board
# here would be both wrong and a way for it to break the build, so frozen boards
# are listed here and skipped entirely.
#   board-3: finalized + ordered.
#   board-2: hand-finalization in progress (decoupling caps + custom parts).
my %FROZEN = (
    'rpi-wiringpi-unit-test-platform-board-2' => 1,
    'rpi-wiringpi-unit-test-platform-board-3' => 1,
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
