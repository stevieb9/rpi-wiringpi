#!/usr/bin/env perl
#
# gen-faq-test-table.pl - Regenerate the "Test file reference" table in
# lib/RPi/WiringPi/FAQ.pod from the test suite itself, so the table can never
# drift out of sync with t/ again.
#
# Each test file is the source of truth for its own row:
#
#   - Test file:           the t/*.t basename (the file list is authoritative).
#   - What it tests:       a `# TESTDOC: <description>` marker line in the test
#                          (die if a test has none - that is the drift guard).
#   - Test hardware:       the board the test lives on, read from its
#                          `BEGIN { if ($ENV{RPI_BOARD_N}) {...} }` convenience
#                          block; `-` when the test isn't tied to a board.
#   - Additional env vars: the RPI_* variables that specific test actually reads
#                          or overrides (its skip-gates and any $ENV{} it sets),
#                          minus the universal/infra vars; else `(none)`. The
#                          board's BEGIN convenience block is NOT counted - it
#                          sets vars via $ENV{$_} = 1 for qw(...), which is not a
#                          literal $ENV{RPI_X} reference, so it's skipped here.
#
# The rendered FAQ.md is produced separately by gen-pod-md.pl (which calls this
# script first). Run order: gen-faq-test-table.pl (updates FAQ.pod) -> pod2md.
#
# Usage:  perl scripts/gen-faq-test-table.pl

use strict;
use warnings;
use File::Spec;
use File::Basename;

my $script_dir = dirname(File::Spec->rel2abs($0));
my $root       = File::Spec->rel2abs(File::Spec->catdir($script_dir, File::Spec->updir));
my $tdir       = File::Spec->catdir($root, 't');
my $faq        = File::Spec->catfile($root, 'lib', 'RPi', 'WiringPi', 'FAQ.pod');

die "t/ not found at $tdir\n"   unless -d $tdir;
die "FAQ.pod not found\n"       unless -f $faq;

# Infra env vars that are never shown in the "Additional env vars" column: the
# universal gate, the optional counters, the pin-mode selector, and the
# per-board convenience switches themselves.
my %INFRA = map { $_ => 1 } qw(
    RPI_BOARD RPI_OBJECT_COUNT RPI_PIN_COUNT RPI_PIN_MODE
    RPI_BOARD_1 RPI_BOARD_2 RPI_BOARD_3 RPI_BOARD_4 RPI_BOARD_5
);

my @rows;
my @missing;

for my $path (sort by_test_number glob File::Spec->catfile($tdir, '*.t')) {
    my $file = basename($path);
    my $text = do { local (@ARGV, $/) = $path; <> };

    my ($desc) = $text =~ /^# TESTDOC:[ \t]*(.+?)[ \t]*$/m;
    if (! defined $desc || $desc eq '') {
        push @missing, $file;
        next;
    }

    my $hw  = test_board($text);
    my $env = test_env($text);

    push @rows, [$file, $desc, $hw, $env];
}

if (@missing) {
    die "gen-faq-test-table: these tests have no '# TESTDOC:' marker:\n" .
        join('', map { "  - $_\n" } @missing) .
        "Add one (e.g. `# TESTDOC: what it tests`) and re-run.\n";
}

my $block = render_table(\@rows);

# Splice the new block over the old one. Anchor on the header + dashed-rule
# lines, then consume every following indented (verbatim) row.
my $src = do { local (@ARGV, $/) = $faq; <> };
my $re  = qr/^[ ]{4}Test file\b.*\n[ ]{4}-+[ ].*\n(?:[ ]{4}\S.*\n)+/m;

die "gen-faq-test-table: could not locate the existing table in FAQ.pod\n"
    unless $src =~ $re;

$src =~ s/$re/$block/;

open my $out, '>', $faq or die "$faq: $!";
print $out $src;
close $out;

printf "gen-faq-test-table: wrote %d rows into %s\n",
    scalar(@rows), File::Spec->abs2rel($faq, $root);

# ---------------------------------------------------------------- subroutines

sub by_test_number {
    my ($na) = $a =~ m{/(\d+)-};
    my ($nb) = $b =~ m{/(\d+)-};
    ($na // 0) <=> ($nb // 0) or $a cmp $b;
}

sub render_table {
    my ($rows) = @_;

    my @head = ('Test file', 'What it tests', 'Test hardware', 'Additional env vars');
    my @w    = map { length } @head;
    for my $r (@$rows) {
        for my $c (0 .. 3) {
            $w[$c] = length $r->[$c] if length $r->[$c] > $w[$c];
        }
    }

    my $fmt = sub {
        my @c = @_;
        # Left-justify every column to its width; the last needs no padding.
        join ' ',
            (map { sprintf '%-*s', $w[$_], $c[$_] } 0 .. 2),
            $c[3];
    };

    my @lines;
    push @lines, '    ' . $fmt->(@head);
    push @lines, '    ' . join ' ', map { '-' x $w[$_] } 0 .. 3;
    push @lines, '    ' . $fmt->(@$_) for @$rows;

    return join("\n", @lines) . "\n";
}

sub test_board {
    my ($text) = @_;
    return $text =~ /if\s*\(\s*\$ENV\{RPI_BOARD_(\d)\}\s*\)/ ? "RPI_BOARD_$1" : '-';
}

sub test_env {
    my ($text) = @_;

    # Only the env vars this specific test reads or overrides: every literal
    # $ENV{RPI_X} reference (skip-gates, conditionals, and $ENV{} it sets). The
    # board BEGIN block enables vars via $ENV{$_} = 1 for qw(...) - not a
    # literal $ENV{RPI_X} - so it is not counted. RPI_* constants (RPI_MODE_*)
    # are barewords, never $ENV{...}, so they're excluded too.
    my %seen;
    while ($text =~ /\$ENV\{(RPI_[A-Z0-9_]+)\}/g) {
        $seen{$1}++;
    }

    my @vars = grep { ! $INFRA{$_} } sort keys %seen;
    return @vars ? join(', ', @vars) : '(none)';
}
