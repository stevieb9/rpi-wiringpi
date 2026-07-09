#!/usr/bin/env perl
#
# gen-min-version.pl - Sync the wiringPi minimum-version literal in the prose
# POD to the single source, RPi::Const::WIRINGPI_MIN_VERSION, so the docs can
# never drift from the constant (completes F6 of the wiringpi-version-single-
# source plan beyond V6's one-time manual edit).
#
# The prose carries the version inside a deliberate, machine-updatable marker -
# "WIRINGPI_MIN_VERSION> (currently <ver>)" - in each target POD file. This
# script resolves the canonical version from the constant and rewrites the
# <ver> in that marker (only there, so the unrelated "As of WiringPi::API 3.18
# the callback ..." references - a different 3.18 - are never touched).
#
# The rendered *.md / README.md are produced separately by gen-pod-md.pl, which
# calls this script first so the generated docs inherit the synced value.
# Run order: gen-faq-test-table.pl + gen-min-version.pl (update POD) -> pod2md.
#
# Usage:  perl scripts/gen-min-version.pl

use strict;
use warnings;
use File::Spec;
use File::Basename;

my $script_dir = dirname(File::Spec->rel2abs($0));
my $root       = File::Spec->rel2abs(File::Spec->catdir($script_dir, File::Spec->updir));

# The prose POD files that name the minimum. README.md / FAQ.md are generated
# from these, so syncing the source is enough.
my @targets = (
    File::Spec->catfile($root, 'lib', 'RPi', 'WiringPi.pm'),
    File::Spec->catfile($root, 'lib', 'RPi', 'WiringPi', 'FAQ.pod'),
);

my $version = canonical_version();

# The marker: WIRINGPI_MIN_VERSION>, then "(currently <ver>)" with the version
# optionally wrapped in a C<> POD code span and possibly wrapped onto the next
# line. Match tightly so nothing else in the prose is rewritten.
my $marker = qr{
    (WIRINGPI_MIN_VERSION>\s*\(currently\s+)   # $1 anchor prefix
    (C<)?                                        # $2 optional C<> open
    (\d+\.\d+)                                   # $3 the version literal
    (>)?                                         # $4 optional C<> close
    (\))                                         # $5 closing paren
}x;

my $total = 0;

for my $file (@targets) {
    die "gen-min-version: target not found: " . rel($file) . "\n" if ! -f $file;

    my $src = do { local (@ARGV, $/) = $file; <> };

    my $hits = 0;
    $src =~ s{$marker}{
        $hits++;
        $1 . ($2 // '') . $version . ($4 // '') . $5;
    }gex;

    if (! $hits) {
        die "gen-min-version: no 'WIRINGPI_MIN_VERSION> (currently <ver>)' " .
            "marker found in " . rel($file) . " - the prose structure changed; " .
            "update the marker or this script.\n";
    }

    open my $out, '>', $file or die "$file: $!\n";
    print $out $src;
    close $out;

    printf "gen-min-version: set wiringPi minimum to %s in %s (%d marker%s)\n",
        $version, rel($file), $hits, ($hits == 1 ? '' : 's');
    $total += $hits;
}

printf "gen-min-version: synced %d marker%s across %d file%s\n",
    $total, ($total == 1 ? '' : 's'),
    scalar(@targets), (@targets == 1 ? '' : 's');

# ---------------------------------------------------------------- subroutines

# Resolve RPi::Const::WIRINGPI_MIN_VERSION - the single source. Try the default
# @INC first, then the author's sibling rpi-const checkout (the installed copy
# may predate the constant). Die rather than write a guessed value: a generator
# that cannot be certain of the number must not rewrite the docs.
sub canonical_version {
    my $v = _load_min_version();
    return $v if defined $v;

    my $sibling = File::Spec->catdir($root, File::Spec->updir, 'rpi-const', 'lib');
    if (-d $sibling) {
        $v = _load_min_version($sibling);
        return $v if defined $v;
    }

    die "gen-min-version: could not resolve RPi::Const::WIRINGPI_MIN_VERSION " .
        "(not in \@INC" . (-d $sibling ? " nor the sibling rpi-const checkout" : '') .
        "). Install RPi::Const 1.07+ or run from the family checkout.\n";
}

sub _load_min_version {
    my ($lib) = @_;
    return eval {
        local @INC = (defined $lib ? ($lib, @INC) : @INC);
        local $SIG{__WARN__} = sub {};  # Quiet 'redefined' if reloading from $lib
        delete $INC{'RPi/Const.pm'};    # Force a fresh load from $lib
        require RPi::Const;
        my $v = RPi::Const::WIRINGPI_MIN_VERSION();
        ($v // '') =~ /^\d+\.\d+$/ ? $v : undef;
    };
}

sub rel { File::Spec->abs2rel($_[0], $root) }
