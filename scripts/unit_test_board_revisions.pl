#!/usr/bin/env perl
#
# unit_test_board_revisions.pl - Report the current revision of each KiCad
# unit test platform board.
#
# The revision lives in the (title_block (rev "N")) section of each board's
# .kicad_pcb file, at docs/test-platform/kicad/<board>/<board>.kicad_pcb.
# Board directories are discovered by name, so a future board-6 shows up
# automatically.
#
# For each board we report the main PCB's rev and title_block date, and flag
# anything suspect in the Notes column:
#
#   - The board directory has no .kicad_pcb file at all
#   - The PCB has no title_block/rev (rev was never set in KiCad)
#   - The sibling schematic's rev differs from the PCB's
#   - A backup copy (_restore_backup_*/ or .history/) carries a HIGHER rev
#     than the main file - the working file may have regressed
#
# With --sync, each schematic's rev is copied into its sibling PCB's
# title block. KiCad never propagates schematic page settings into the
# PCB file, and the front-silkscreen "Revision: ${REVISION}" text renders
# the PCB's OWN title-block rev - so the workflow is: bump the rev in the
# schematic's page settings, run --sync, and the silkscreen follows.
# NOTE: a synced board that is blessed must be re-blessed afterwards
# (check-board-locks.py --bless).
#
# Usage:  perl scripts/unit_test_board_revisions.pl [--sync]

use strict;
use warnings;

use File::Basename;
use File::Spec;
use Getopt::Long;

my $sync = 0;

GetOptions('sync' => \$sync)
    or die "usage: $0 [--sync]\n";

my $repo_root = File::Spec->rel2abs(
    File::Spec->catdir(dirname($0), File::Spec->updir)
);
my $kicad_dir = File::Spec->catdir($repo_root, qw(docs test-platform kicad));

die "kicad directory not found: $kicad_dir\n" if ! -d $kicad_dir;

my @boards = board_dirs($kicad_dir);

die "no board directories found under $kicad_dir\n" if ! @boards;

my @rows;

for my $board (@boards) {
    my $name = basename($board);

    # The shared directory prefix adds no information on screen
    (my $display = $name) =~ s/^rpi-wiringpi-unit-test-platform-//;

    my $pcb = File::Spec->catfile($board, "$name.kicad_pcb");

    if (! -f $pcb) {
        push @rows, [$display, '-', '-', 'no .kicad_pcb file'];
        next;
    }

    my @notes;
    my ($rev, $date) = parse_title_block($pcb);

    # The schematic's page settings are the source of truth for the rev

    my $sch = File::Spec->catfile($board, "$name.kicad_sch");
    my $sch_rev;

    if (-f $sch) {
        ($sch_rev) = parse_title_block($sch);
    }

    if ($sync && defined $sch_rev && (! defined $rev || $sch_rev ne $rev)) {
        sync_rev($pcb, $sch_rev);

        my $old = defined $rev ? $rev : 'not set';
        ($rev, $date) = parse_title_block($pcb);

        push @notes, "SYNCED from schematic ($old -> $sch_rev)";
    }

    if (! defined $rev) {
        push @notes, 'rev not set (PCB has no title_block rev)';
    }

    if (defined $sch_rev && (! defined $rev || $sch_rev ne $rev)) {
        push @notes, "schematic rev is $sch_rev";
    }

    # Flag backup/history copies carrying a higher rev than the main PCB

    for my $copy (pcb_copies($board, $name)) {
        my ($copy_rev) = parse_title_block($copy);

        next if ! defined $copy_rev;

        if (! defined $rev || rev_gt($copy_rev, $rev)) {
            my $rel = File::Spec->abs2rel($copy, $board);
            push @notes, "NEWER rev $copy_rev in $rel";
        }
    }

    push @rows, [
        $display,
        defined $rev  ? $rev  : 'not set',
        defined $date ? $date : '-',
        join('; ', @notes),
    ];
}

# Render an aligned table

my @headers = ('Board', 'PCB rev', 'Date', 'Notes');
my @widths  = map { length } @headers;

for my $row (@rows) {
    for my $i (0 .. $#{ $row }) {
        if (length $row->[$i] > $widths[$i]) {
            $widths[$i] = length $row->[$i];
        }
    }
}

my $format = join('  ', map { "%-${_}s" } @widths) . "\n";

printf $format, @headers;
printf $format, map { '-' x $_ } @widths;
printf $format, @{ $_ } for @rows;

sub board_dirs {
    my ($dir) = @_;

    if (! defined $dir) {
        die "board_dirs() requires a directory param\n";
    }

    opendir my $dh, $dir or die "can't open $dir: $!\n";

    my @dirs = grep { -d $_ }
        map { File::Spec->catdir($dir, $_) }
        grep { /^rpi-wiringpi-unit-test-platform-board-\d+$/ }
        readdir $dh;

    closedir $dh;

    # Sort by trailing board number
    return sort {
        ($a =~ /(\d+)$/)[0] <=> ($b =~ /(\d+)$/)[0]
    } @dirs;
}

sub parse_title_block {
    my ($file) = @_;

    if (! defined $file) {
        die "parse_title_block() requires a file param\n";
    }

    open my $fh, '<', $file or die "can't open $file: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;

    # Pull out just the title_block section (a top-level child closed at the
    # same indent it opens on) so a (rev ...) elsewhere can't false-match

    my ($block) = $content =~ /^([ \t]*)\(title_block\s*\n(.*?)^\1\)/ms
        ? $2
        : undef;

    return (undef, undef) if ! defined $block;

    my ($rev)  = $block =~ /\(rev\s+"([^"]*)"/;
    my ($date) = $block =~ /\(date\s+"([^"]*)"/;

    # An empty rev string means the rev was never set
    $rev = undef if defined $rev && $rev eq '';

    return ($rev, $date);
}

sub pcb_copies {
    my ($board_dir, $board_name) = @_;

    if (! defined $board_dir) {
        die "pcb_copies() requires the \$board_dir param\n";
    }

    if (! defined $board_name) {
        die "pcb_copies() requires the \$board_name param\n";
    }

    opendir my $dh, $board_dir or die "can't open $board_dir: $!\n";
    my @entries = readdir $dh;
    closedir $dh;

    my @copies;

    for my $entry (@entries) {
        next if $entry !~ /^_restore_backup_/ && $entry ne '.history';

        my $sub = File::Spec->catdir($board_dir, $entry);
        next if ! -d $sub;

        my $copy = File::Spec->catfile($sub, "$board_name.kicad_pcb");
        push @copies, $copy if -f $copy;
    }

    return @copies;
}

sub rev_gt {
    my ($rev_a, $rev_b) = @_;

    if (! defined $rev_a) {
        die "rev_gt() requires the \$rev_a param\n";
    }

    if (! defined $rev_b) {
        die "rev_gt() requires the \$rev_b param\n";
    }

    # Numeric compare when both revs are numeric, string compare otherwise

    if ($rev_a =~ /^\d+(?:\.\d+)?$/ && $rev_b =~ /^\d+(?:\.\d+)?$/) {
        return $rev_a > $rev_b;
    }

    return ($rev_a cmp $rev_b) > 0;
}

sub sync_rev {
    my ($file, $rev) = @_;

    if (! defined $file) {
        die "sync_rev() requires the \$file param\n";
    }

    if (! defined $rev) {
        die "sync_rev() requires the \$rev param\n";
    }

    open my $fh, '<', $file or die "can't open $file: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;

    # Operate only inside the top-level title_block section, replacing an
    # existing (rev "...") or inserting one after the opening line

    my $updated = $content;

    if ($updated =~ /^([ \t]*)\(title_block\s*\n(.*?)(^\1\))/ms) {
        my ($indent, $block, $close) = ($1, $2, $3);
        my $new_block = $block;

        if ($new_block =~ /\(rev\s+"[^"]*"\)/) {
            $new_block =~ s/\(rev\s+"[^"]*"\)/(rev "$rev")/;
        }
        else {
            $new_block .= "$indent\t(rev \"$rev\")\n";
        }

        $updated =~ s/^([ \t]*)\(title_block\s*\n.*?^\1\)/$indent(title_block\n$new_block$close/ms;
    }
    else {
        die "no title_block found in $file - set one in KiCad first\n";
    }

    open my $out, '>', $file or die "can't write $file: $!\n";
    print $out $updated;
    close $out;

    return;
}
