#!/usr/bin/env perl
#
# gen-pod-md.pl - Regenerate docs/pod/*.md from the distribution's POD.
#
# Scans lib/ for every module (.pm) and standalone POD doc (.pod), and for
# each file that actually contains POD, writes a markdown replica into
# docs/pod/ named after the file's leaf basename (e.g. Core.pm -> Core.md,
# FAQ.pod -> FAQ.md). Files with no POD are skipped.
#
# Also regenerates README.md at the repo root from the main module's
# (lib/RPi/WiringPi.pm) POD; this replaces the legacy pod2text README.
#
# Conversion is delegated to the `pod2markdown` binary (Pod::Markdown is not
# installed in the perlbrew perl, but the system binary is on PATH). After
# conversion, a GitHub-anchored Table of Contents is injected into each
# generated markdown file (including README.md).
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

# Regenerate the FAQ "Test file reference" table from the test suite first, so
# the POD we render below already carries the current table (it lives in
# FAQ.pod). Keeps the generated docs in lock-step with t/.
{
    my $table_gen = File::Spec->catfile($script_dir, 'gen-faq-test-table.pl');
    system($^X, $table_gen) == 0
        or die "gen-pod-md: $table_gen failed (exit " . ($? >> 8) . ")\n";
}

# Sync the wiringPi minimum-version literal in the prose POD to the single
# source (RPi::Const::WIRINGPI_MIN_VERSION) before rendering, so README.md /
# FAQ.md inherit the current value and can't drift from the constant.
{
    my $ver_gen = File::Spec->catfile($script_dir, 'gen-min-version.pl');
    system($^X, $ver_gen) == 0
        or die "gen-pod-md: $ver_gen failed (exit " . ($? >> 8) . ")\n";
}

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

    add_toc($dest);

    my $lines = count_lines($dest);
    printf "  %-14s <- %s  (%d lines)\n", $md, rel($src), $lines;
    $generated++;
}

# The main module's POD also feeds the distribution README.md at the repo
# root (replaces the legacy pod2text README)

my $readme_src  = File::Spec->catfile($lib_dir, 'RPi', 'WiringPi.pm');
my $readme_dest = File::Spec->catfile($root, 'README.md');

system($pod2md, $readme_src, $readme_dest) == 0
    or die "pod2markdown failed for README.md (status $?)\n";

add_toc($readme_dest);

printf "  %-14s <- %s  (%d lines)\n",
    'README.md', rel($readme_src), count_lines($readme_dest);

printf "\nGenerated %d file%s + README.md, skipped %d, into %s\n",
    $generated, ($generated == 1 ? '' : 's'), $skipped, rel($out_dir);

# --- helpers ---------------------------------------------------------------

# Inject a "Table of Contents" section into a generated markdown file. Headings
# are collected from the converted output, GitHub-style anchors are derived
# (matching GitHub's slug + duplicate-suffix rules), and the TOC is spliced in
# just ahead of the second heading (after the leading NAME/title section). Files
# with fewer than three headings are left untouched.
sub add_toc {
    my ($file) = @_;

    open my $fh, '<', $file or die "open $file: $!\n";
    my @lines = <$fh>;
    close $fh;

    # Collect ATX headings, ignoring anything inside fenced code blocks.
    my $in_fence = 0;
    my @headings;
    for my $i (0 .. $#lines) {
        if ($lines[$i] =~ /^```/) {
            $in_fence = ! $in_fence;
            next;
        }
        next if $in_fence;
        if ($lines[$i] =~ /^(#{1,6})[ \t]+(.+?)[ \t]*$/) {
            push @headings, { level => length($1), text => $2, idx => $i };
        }
    }

    # Not worth a TOC for a stub document.
    return if @headings < 3;

    # Assign anchors across all headings in document order so duplicate-name
    # suffixes (-1, -2, ...) match what GitHub would generate.
    my %seen;
    for my $h (@headings) {
        $h->{anchor} = anchor($h->{text}, \%seen);
    }

    # List everything after the leading title heading.
    my @entries = @headings[1 .. $#headings];
    my $min     = $entries[0]{level};
    for my $e (@entries) {
        $min = $e->{level} if $e->{level} < $min;
    }

    my @toc = ("## Table of Contents\n", "\n");
    for my $e (@entries) {
        my $indent = '  ' x ($e->{level} - $min);
        push @toc, sprintf "%s- [%s](#%s)\n",
            $indent, clean_heading($e->{text}), $e->{anchor};
    }
    push @toc, "\n";

    splice @lines, $entries[0]{idx}, 0, @toc;

    open my $wfh, '>', $file or die "open $file: $!\n";
    print $wfh @lines;
    close $wfh;

    return;
}

# Derive a GitHub-compatible anchor slug from heading text, tracking previously
# seen slugs in the passed hashref to append -1/-2/... on collisions.
sub anchor {
    my ($text, $seen) = @_;

    my $s = lc clean_heading($text);
    $s =~ s/[^\w \-]//g;     # Keep word chars (incl. _), spaces and hyphens
    $s =~ s/ /-/g;

    if (defined $seen->{$s}) {
        my $base = $s;
        $s = $base . '-' . (++$seen->{$base});
    }
    else {
        $seen->{$s} = 0;
    }

    return $s;
}

# Strip inline markdown formatting markers (code spans, bold/italic) so the
# visible heading text remains for both the TOC label and the anchor slug.
sub clean_heading {
    my ($text) = @_;

    $text =~ s/`+//g;
    $text =~ s/\*\*?//g;
    $text =~ s/^\s+|\s+$//g;

    return $text;
}

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
