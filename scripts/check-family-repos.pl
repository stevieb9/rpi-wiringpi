#!/usr/bin/env perl

use warnings;
use strict;
use feature 'say';

# Report which stevieb9-authored RPi::WiringPi family repos have uncommitted
# changes, in one pass.
#
# The family list and repo-slug mapping are derived exactly as in
# sync-family-repos.pl: from this repo's Makefile.PL PREREQ_PM, filtered to
# stevieb9-authored deps (every RPi::*, WiringPi::API, and the two non-RPi leaf
# dists GPSD::Parse and IPC::Shareable). Enrolling a new prereq there
# automatically enrols its repo here too.
#
# For each repo under the repos root, `git status --porcelain` decides the
# verdict: a dirty tree lists its changed files; a clean tree is reported clean.
# Missing clones and non-git directories are noted but never abort the run.
#
#   perl scripts/check-family-repos.pl [--root DIR]
#
#   --root DIR  Directory the sibling repos live in (default: the parent of
#               this repo's checkout, i.e. ~/repos in the normal layout).

use FindBin;
use Getopt::Long;

my $repo_dir = "$FindBin::Bin/..";       # .../rpi-wiringpi

my $root = "$repo_dir/..";               # .../repos
GetOptions(
    'root=s' => \$root,
) or die "Usage: $0 [--root DIR]\n";

my $makefile = "$repo_dir/Makefile.PL";

# Module -> repo slug, only where the default rule (lc; :: -> -) is wrong.
my %slug_exception = (
    'RPi::OLED::SSD1306::128_64' => 'rpi-oled-ssd1306',
);

my @family = family_modules($makefile);
die "Found no family modules in $makefile PREREQ_PM\n" if !@family;

my @repos = family_repos(@family);

my @dirty;

for my $slug (@repos) {
    my $dir = "$root/$slug";

    next if ! -d "$dir/.git";

    my @changes = git_status($dir);
    next if ! @changes;

    say "$slug  (${\ scalar @changes} changed)";
    say "    - $_" for @changes;
    push @dirty, $slug;
}

exit(@dirty ? 1 : 0);

# --- helpers ---------------------------------------------------------------

sub family_modules {
    my ($mf) = @_;

    open my $fh, '<', $mf or die "Could not open $mf: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;

    my ($block) = $content =~ /PREREQ_PM\s*=>\s*\{(.*?)\}/s;
    $block //= $content;

    my @mods;
    while ($block =~ /(['"])([\w:]+)\1\s*=>/g) {
        my $mod = $2;
        push @mods, $mod
            if $mod =~ /^RPi::/
            || $mod eq 'WiringPi::API'
            || $mod eq 'GPSD::Parse'
            || $mod eq 'IPC::Shareable';
    }

    # This repo's own dist heads the family but isn't listed in its own
    # PREREQ_PM — include it so the umbrella is covered too.
    push @mods, 'RPi::WiringPi';

    # Stable, human-friendly order.
    return sort @mods;
}

sub family_repos {
    my (@mods) = @_;

    # Sibling repos that travel with the family but aren't RPi::WiringPi CPAN
    # prereqs, so PREREQ_PM never names them (e.g. the rpi-tracker inventory
    # web app).
    my @extra = ('rpi-tracker');

    # Stable, human-friendly order.
    return sort((map { module_to_slug($_) } @mods), @extra);
}

sub git_status {
    my ($dir) = @_;

    open my $fh, '-|', 'git', '-C', $dir, 'status', '--porcelain'
        or die "Could not run git status in $dir: $!\n";
    my @lines = <$fh>;
    close $fh;

    chomp @lines;
    return @lines;
}

sub module_to_slug {
    my ($mod) = @_;
    return $slug_exception{$mod} if exists $slug_exception{$mod};
    (my $slug = lc $mod) =~ s/::/-/g;
    return $slug;
}
