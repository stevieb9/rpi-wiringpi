use strict;
use warnings;

use Test::More;
use FindBin;
use File::Spec;

# Author-side doc-sync gate for the wiringpi-version-single-source plan (B2).
# The prose in lib/RPi/WiringPi.pm and lib/RPi/WiringPi/FAQ.pod carries the
# wiringPi minimum inside a "WIRINGPI_MIN_VERSION> (currently <ver>)" marker,
# which scripts/gen-min-version.pl rewrites from the single source
# (RPi::Const::WIRINGPI_MIN_VERSION) at doc-regen time. This test fails if the
# committed docs have drifted from the constant - ie. someone bumped the
# constant but did not re-run the generator.
#
# Needs the canonical constant, reachable from the author's sibling rpi-const
# checkout (the installed copy may predate it); skips cleanly otherwise.

my $root = File::Spec->rel2abs(
    File::Spec->catdir($FindBin::Bin, File::Spec->updir, File::Spec->updir)
);

my $canonical = canonical_version();
plan skip_all => 'RPi::Const::WIRINGPI_MIN_VERSION not reachable'
    if ! defined $canonical;

my @targets = (
    File::Spec->catfile($root, 'lib', 'RPi', 'WiringPi.pm'),
    File::Spec->catfile($root, 'lib', 'RPi', 'WiringPi', 'FAQ.pod'),
);

my $marker = qr{WIRINGPI_MIN_VERSION>\s*\(currently\s+(?:C<)?(\d+\.\d+)>?\)};

for my $file (@targets) {
    my $rel = File::Spec->abs2rel($file, $root);
    my $src = do { local (@ARGV, $/) = $file; <> };

    my @found = $src =~ /$marker/g;
    ok scalar(@found), "$rel: has a WIRINGPI_MIN_VERSION prose marker";
    for my $v (@found) {
        is $v, $canonical,
            "$rel: prose minimum '$v' matches the constant ($canonical) " .
            "- run scripts/gen-pod-md.pl if this fails";
    }
}

done_testing();

sub canonical_version {
    my $v = _load();
    return $v if defined $v;
    my $sibling = File::Spec->catdir($root, File::Spec->updir, 'rpi-const', 'lib');
    return -d $sibling ? _load($sibling) : undef;
}

sub _load {
    my ($lib) = @_;
    return eval {
        local @INC = (defined $lib ? ($lib, @INC) : @INC);
        local $SIG{__WARN__} = sub {};
        delete $INC{'RPi/Const.pm'};
        require RPi::Const;
        my $v = RPi::Const::WIRINGPI_MIN_VERSION();
        ($v // '') =~ /^\d+\.\d+$/ ? $v : undef;
    };
}
