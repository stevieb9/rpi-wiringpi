#!/usr/bin/env perl
#
# gen-pod-md.pl - Regenerate docs/pod/*.md from the distribution's POD.
#
# Scans lib/ for every module (.pm) and standalone POD doc (.pod), and for
# each file that actually contains POD, writes a markdown replica into
# docs/pod/ named after the file's leaf basename (e.g. Core.pm -> Core.md,
# FAQ.pod -> FAQ.md). Files with no POD are skipped.
#
# Conversion is delegated to the `pod2markdown` binary (Pod::Markdown is not
# installed in the perlbrew perl, but the system binary is on PATH).
#
# Usage:  perl scripts/gen-pod-md.pl

use strict;
use warnings;
use File::Find;
use File::Spec;
use File::Basename;

# Resolve project root as the parent of this script's directory, so the
# script works regardless of the current working directory.
my $script_dir = dirname(File::Spec->rel2abs($0));
my $root       = File::Spec->rel2abs(File::Spec->catdir($script_dir, File::Spec->updir));
my $lib_dir    = File::Spec->catdir($root, 'lib');
my $out_dir    = File::Spec->catdir($root, 'docs', 'pod');

die "lib/ not found at $lib_dir\n"        unless -d $lib_dir;
die "docs/pod/ not found at $out_dir\n"   unless -d $out_dir;

my $pod2md = find_pod2markdown();

# Collect candidate POD sources under lib/.
my @sources;
find(
    sub {
        return unless -f $_;
        return unless /\.(pm|pod)$/;
        push @sources, $File::Find::name;
    },
    $lib_dir,
);
@sources = sort @sources;

my %seen;        # leaf basename -> source, to catch name collisions
my $generated = 0;
my $skipped   = 0;

for my $src (@sources) {
    unless (has_pod($src)) {
        printf "  skip (no POD): %s\n", rel($src);
        $skipped++;
        next;
    }

    my $leaf = basename($src);
    $leaf =~ s/\.(pm|pod)$//;
    my $md = "$leaf.md";

    if (my $prev = $seen{$md}) {
        die "name collision: both $prev and " . rel($src) . " map to $md\n";
    }
    $seen{$md} = rel($src);

    my $dest = File::Spec->catfile($out_dir, $md);
    my @cmd  = ($pod2md, $src, $dest);
    system(@cmd) == 0
        or die "pod2markdown failed for " . rel($src) . " (status $?)\n";

    my $lines = count_lines($dest);
    printf "  %-14s <- %s  (%d lines)\n", $md, rel($src), $lines;
    $generated++;
}

printf "\nGenerated %d file%s, skipped %d, into %s\n",
    $generated, ($generated == 1 ? '' : 's'), $skipped, rel($out_dir);

# --- helpers ---------------------------------------------------------------

# Locate the pod2markdown binary: PATH first, then common system location.
sub find_pod2markdown {
    for my $cand ('pod2markdown', '/usr/bin/pod2markdown') {
        my $found = ($cand =~ m{/}) ? (-x $cand ? $cand : undef)
                                    : which($cand);
        return $found if $found;
    }
    die "pod2markdown not found on PATH or at /usr/bin/pod2markdown\n";
}

sub which {
    my ($prog) = @_;
    for my $dir (split /:/, ($ENV{PATH} // '')) {
        my $p = File::Spec->catfile($dir, $prog);
        return $p if -x $p;
    }
    return undef;
}

# True if the file contains at least one POD command paragraph.
sub has_pod {
    my ($file) = @_;
    open my $fh, '<', $file or die "open $file: $!\n";
    while (my $line = <$fh>) {
        return 1 if $line =~ /^=[a-zA-Z]/;
    }
    return 0;
}

sub count_lines {
    my ($file) = @_;
    open my $fh, '<', $file or return 0;
    my $n = 0;
    $n++ while <$fh>;
    return $n;
}

sub rel { File::Spec->abs2rel($_[0], $root) }
