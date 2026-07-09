use strict;
use warnings;

use Test::More;
use FindBin;

# Author-side drift gate for the wiringpi-version-single-source plan. Wraps
# scripts/audit-family-buildcheck.pl (via require -> audit_family()) and fails
# when:
#   - any dist that STILL carries an inline wiringPi minimum reports a
#     NON-canonical one (a hand-edit or a stale copy reintroducing drift), or
#   - the migration regresses: a dist that needs a guard is no longer
#     shim-converted (the %TODO of unconverted dists is now empty), or
#   - the audit's canonical constant drifts from the single source
#     (RPi::Const::WIRINGPI_MIN_VERSION), when that source is reachable.
#
# Dists that need no guard at all (pure perl, or standard-C XS like rpi-serial /
# rpi-sysinfo / rpi-eeprom-at24c32 which bundles its own i2c-dev.h) are ignored
# - they can't drift.

require "$FindBin::Bin/../../scripts/audit-family-buildcheck.pl";

my $CANONICAL = '3.18';

# Dists that NEED a wiringPi/i2c guard but haven't been converted to the shim
# yet. Now EMPTY: V7/V8 converted every dist that genuinely needs a guard, so
# any dist reporting needs != 'none' must already be shim-converted (test 2
# and test 3 below enforce this). rpi-eeprom-at24c32 is deliberately absent -
# it bundles its own i2c-dev.h and needs no guard (needs == 'none').
my %TODO;

my $rows = audit_family();
cmp_ok scalar(@$rows), '>=', 20, 'audit returned the whole family';

# 1. No version drift: any dist that STILL carries an inline wiringPi minimum
#    must report the canonical one. Post-V8 every guard is the shim, so this
#    normally iterates nothing - it is a regression guard against a hand-edit
#    that reintroduces an inline min (test 4 proves the detector still bites).
my $inline_mins = 0;
for my $r (@$rows) {
    my $min = defined $r->{min} ? $r->{min} : '';
    next if $min !~ /^\d/;
    $inline_mins++;
    ok index($min, $CANONICAL) == 0,
        "$r->{slug}: inline wiringPi minimum '$min' is canonical ($CANONICAL)";
}

# 2. The minimum is fully single-sourced: after V8 no dist restates it inline -
#    every dist gets it from RPi::Const::BuildCheck. A reintroduced inline min
#    (even a canonical one) is a regression away from the single source.
is $inline_mins, 0,
    'wiringPi minimum is fully single-sourced - no dist carries an inline min';

# The audit hard-codes CANONICAL; make sure it still matches the actual single
# source (RPi::Const::WIRINGPI_MIN_VERSION) so the audit itself can't silently
# drift. Reachable only from the author's sibling rpi-const checkout; skip
# cleanly otherwise (eg. CPAN smoke of just this dist).
SKIP: {
    my $const_lib = "$FindBin::Bin/../../../rpi-const/lib";
    skip 'sibling rpi-const checkout not found', 1 if ! -d $const_lib;
    my $source = eval {
        local @INC = ($const_lib, @INC);
        require RPi::Const;
        RPi::Const::WIRINGPI_MIN_VERSION();
    };
    skip 'RPi::Const::WIRINGPI_MIN_VERSION not available', 1 if ! defined $source;
    is $source, $CANONICAL,
        "audit CANONICAL ($CANONICAL) matches RPi::Const::WIRINGPI_MIN_VERSION ($source)";
}

# 2. Coverage: the dists that need a guard and are NOT yet shim-converted are
#    exactly the TODO list.
my %pending = map { $_->{slug} => 1 }
    grep { $_->{needs} ne 'none' && ($_->{shim} // 'no') ne 'yes' } @$rows;

is_deeply [sort keys %pending], [sort keys %TODO],
    'not-yet-converted, needs-a-guard dists match the TODO list';

# 3. Every needs-a-guard dist NOT in the TODO must be converted to the shim.
for my $r (@$rows) {
    next if $r->{needs} eq 'none';
    next if $TODO{$r->{slug}};
    is $r->{shim}, 'yes',
        "$r->{slug} (needs $r->{needs}, not TODO) is converted to the shim";
}

# 4. Simulated drift is caught: run a stale inline guard (min 2.36) through the
#    audit's OWN detection and confirm it is flagged non-canonical - i.e. an
#    edit to a local clone's minimum would fail test 1.
{
    my $stale = <<'SRC';
use version;
if (! -f '/usr/include/wiringPi.h'){ exit }
my $out = `gpio -v`;
if (my ($ver) = $out =~ /version:\s+(\d+\.\d+)/){
    if (version->parse($ver) < 2.36){ exit }
}
SRC
    my $min = wiringpi_min($stale, guard_class($stale));
    isnt index($min, $CANONICAL), 0,
        "simulated drift: a stale inline guard is detected as '$min' (would fail test 1)";
}

done_testing();
