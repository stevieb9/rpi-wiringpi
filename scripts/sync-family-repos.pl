#!/usr/bin/env perl

use warnings;
use strict;
use feature 'say';

# Clone-or-update every stevieb9-authored repo the RPi::WiringPi family
# depends on, in one pass.
#
# The family list is derived from this repo's Makefile.PL PREREQ_PM (the same
# single source of truth the family build-check audit uses), so enrolling a new
# prereq automatically enrols its repo here. Only stevieb9-authored deps are
# included: every RPi::*, WiringPi::API, and the two non-RPi leaf dists
# (GPSD::Parse, IPC::Shareable). Third-party CPAN prereqs (parent, JSON::XS, ...)
# are skipped.
#
# Each module maps to a repo slug (lc, :: -> -, with a small exception table),
# then under the repos root either an existing clone is `git pull --ff-only`ed
# or a fresh one is `git clone`d from git@github.com:stevieb9/<slug>. Failures
# never abort the run: each repo is independent and a per-repo summary prints at
# the end.
#
#   perl scripts/sync-family-repos.pl [--dry-run] [--root DIR]
#
#   --dry-run   Print the git commands that would run, but change nothing.
#   --root DIR  Directory the sibling repos live in (default: the parent of
#               this repo's checkout, i.e. ~/repos in the normal layout).

use FindBin;
use Getopt::Long;

my $repo_dir = "$FindBin::Bin/..";       # .../rpi-wiringpi

my $dry_run = 0;
my $root    = "$repo_dir/..";            # .../repos
GetOptions(
    'dry-run' => \$dry_run,
    'root=s'  => \$root,
) or die "Usage: $0 [--dry-run] [--root DIR]\n";

my $makefile = "$repo_dir/Makefile.PL";
my $github   = 'git@github.com:stevieb9';

# Module -> repo slug, only where the default rule (lc; :: -> -) is wrong.
my %slug_exception = (
    'RPi::OLED::SSD1306::128_64' => 'rpi-oled-ssd1306',
);

my @family = family_modules($makefile);
die "Found no family modules in $makefile PREREQ_PM\n" if !@family;

# Refuse to sync while any family repo has uncommitted changes — pulling into a
# dirty working tree risks conflicts. check-family-repos.pl is the source of
# truth: it exits non-zero and lists the offenders when anything is dirty.
my $checker = "$FindBin::Bin/check-family-repos.pl";
open my $check_fh, '-|', $^X, $checker, '--root', $root
    or die "Could not run $checker: $!\n";
my $dirty = do { local $/; <$check_fh> };
close $check_fh;

if ($?) {
    print "Refusing to sync — commit or stash these first:\n\n";
    print $dirty;
    exit 1;
}

say "DRY RUN — no repos will be modified.\n" if $dry_run;

my (@cloned, @updated, @failed, @skipped);

for my $mod (@family) {
    my $slug = module_to_slug($mod);
    my $dir  = "$root/$slug";

    if (-e $dir && ! -d "$dir/.git") {
        push @skipped, $slug;
        next;
    }

    if (-d "$dir/.git") {
        if (run('git', '-C', $dir, 'pull', '--ff-only', '--quiet')) {
            push @updated, $slug;
        }
        else {
            push @failed, $slug;
        }
    }
    else {
        if (run('git', '-C', $root, 'clone', '--quiet', "$github/$slug", $slug)) {
            push @cloned, $slug;
        }
        else {
            push @failed, $slug;
        }
    }
}

# --- summary ---------------------------------------------------------------

report('Cloned',  @cloned);
report('Updated', @updated);
report('Skipped', @skipped);
report('Failed',  @failed);

exit(@failed ? 1 : 0);

# --- helpers ---------------------------------------------------------------

sub report {
    my ($heading, @slugs) = @_;
    return if !@slugs;
    say "$heading:";
    say "    - $_" for @slugs;
}

sub run {
    my (@cmd) = @_;
    return 1 if $dry_run;
    return system(@cmd) == 0;
}

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

sub module_to_slug {
    my ($mod) = @_;
    return $slug_exception{$mod} if exists $slug_exception{$mod};
    (my $slug = lc $mod) =~ s/::/-/g;
    return $slug;
}
