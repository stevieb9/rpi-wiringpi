#!/usr/bin/env perl

use warnings;
use strict;
use feature 'say';

# Sync, then build-and-install every stevieb9-authored RPi::WiringPi family
# repo in one pass, reporting ONLY the repos that failed to install.
#
# Step A runs sync-family-repos.pl (which itself refuses to run while any
# family repo is dirty), so every clone is present and fast-forwarded before
# anything is built. If sync reports a problem the install is aborted rather
# than run against stale or missing trees.
#
# Step B then visits each repo under the repos root and runs `perl Makefile.PL`
# followed by `make install`. A repo counts as failed if either step exits
# non-zero; only failures are reported, with the tail of the offending
# command's output so the cause is visible. Repos that install cleanly produce
# no report output — a repo the sync left without a clone is listed separately.
#
# The family list and repo-slug mapping are derived exactly as in
# sync-family-repos.pl and check-family-repos.pl: from this repo's Makefile.PL
# PREREQ_PM, filtered to stevieb9-authored deps. Enrolling a new prereq there
# automatically enrols its repo here too.
#
#   perl scripts/install-family-repos.pl [--dry-run] [--root DIR]
#
#   --dry-run   Run sync in dry-run mode and print the build commands that
#               would run, but build and install nothing.
#   --root DIR  Directory the sibling repos live in (default: the parent of
#               this repo's checkout, i.e. ~/repos in the normal layout).

use Cwd qw(getcwd);
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

# Module -> repo slug, only where the default rule (lc; :: -> -) is wrong.
my %slug_exception = (
    'RPi::OLED::SSD1306::128_64' => 'rpi-oled-ssd1306',
);

my @family = family_modules($makefile);
die "Found no family modules in $makefile PREREQ_PM\n" if ! @family;

my @repos = family_repos(@family);

# --- step A: sync -----------------------------------------------------------

# sync-family-repos.pl clones/updates every repo and refuses (exit non-zero)
# while any family tree is dirty, so a clean sync is the gate for installing.
my $sync = "$FindBin::Bin/sync-family-repos.pl";
my @sync_cmd = ($^X, $sync, '--root', $root);
push @sync_cmd, '--dry-run' if $dry_run;

print STDERR "==> Syncing family repos...\n";
if (system(@sync_cmd) != 0) {
    die "\nSync failed — resolve the problems above before installing.\n";
}

# --- step B: build and install ---------------------------------------------

my @failed;      # [ slug, step-label, command output ]
my @missing;     # slugs the sync left without a clone

for my $slug (@repos) {
    my $dir = "$root/$slug";

    if (! -d "$dir/.git") {
        push @missing, $slug;
        next;
    }

    print STDERR "==> Installing $slug\n";

    my $failure = install_repo($dir);
    push @failed, [$slug, @$failure] if $failure;
}

# --- report (failures only) ------------------------------------------------

if (@missing) {
    say "Not installed (no clone found):";
    say "    - $_" for @missing;
    say '';
}

for my $failure (@failed) {
    my ($slug, $step, $output) = @$failure;

    say "$slug — `$step` failed:";
    say "    $_" for output_tail($output);
    say '';
}

my $problems = @failed + @missing;

print STDERR "All ${\ scalar @repos} family repos installed.\n"
    if ! $problems && ! $dry_run;

exit($problems ? 1 : 0);

# --- helpers ---------------------------------------------------------------

sub install_repo {
    my ($dir) = @_;

    # perl Makefile.PL first, then make install (whose target builds before it
    # installs, so a separate `make` step isn't needed).
    my @steps = (
        ['perl Makefile.PL', [$^X, 'Makefile.PL']],
        ['make install',     ['make', 'install']],
    );

    my $orig = getcwd();
    if (! chdir $dir) {
        return ['chdir', "Could not chdir to $dir: $!"];
    }

    my $failure;

    for my $step (@steps) {
        my ($label, $cmd) = @$step;

        if ($dry_run) {
            say "    would run: $label  (in $dir)";
            next;
        }

        my ($status, $output) = run_step(@$cmd);
        if ($status != 0) {
            $failure = [$label, $output];
            last;
        }
    }

    chdir $orig;
    return $failure;
}

sub run_step {
    my (@cmd) = @_;

    # Fork-open so STDERR can be merged into the captured STDOUT without a
    # shell, keeping the whole command output together for the failure report.
    my $pid = open my $fh, '-|';
    if (! defined $pid) {
        return (1, "Could not fork: $!");
    }

    if ($pid == 0) {
        open STDERR, '>&', \*STDOUT;
        exec @cmd;
        exit 127;      # Only reached if exec failed.
    }

    my $output = do { local $/; <$fh> };
    close $fh;

    return ($?, $output // '');
}

sub output_tail {
    my ($output) = @_;

    my @lines = split /\n/, $output;
    my $max   = 15;

    return @lines > $max ? @lines[-$max .. -1] : @lines;
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

sub family_repos {
    my (@mods) = @_;

    # Sibling repos that travel with the family but aren't RPi::WiringPi CPAN
    # prereqs, so PREREQ_PM never names them (e.g. the rpi-tracker inventory
    # web app).
    my @extra = ('rpi-tracker');

    # Stable, human-friendly order.
    return sort((map { module_to_slug($_) } @mods), @extra);
}

sub module_to_slug {
    my ($mod) = @_;
    return $slug_exception{$mod} if exists $slug_exception{$mod};
    (my $slug = lc $mod) =~ s/::/-/g;
    return $slug;
}
