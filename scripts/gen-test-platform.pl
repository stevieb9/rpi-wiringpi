#!/usr/bin/env perl
#
# gen-test-platform.pl - Regenerate the docs/test-platform artifacts.
#
# Orchestrates the Python pipeline that builds the unit-test platform's pinout
# images and electrical schematic, then files the outputs into their final
# homes:
#
#   *.svg                                  -> docs/test-platform/svg/
#   *.net                                  -> docs/test-platform/facts/
#   *.jpg, *.pdf                           -> docs/test-platform/
#   *.nlsvg.json                           -> discarded (netlistsvg inputs)
#   anything else unexpected               -> repo root (for the user to triage)
#
# The Python generators hard-code a "t/" output prefix, so they are run inside a
# throwaway scratch directory (.build-test-platform/) whose own "t/" catches
# their output. The repository's real t/ is never written to.
#
# The schematic PDF + the wire-routed SVGs need the external `netlistsvg` tool.
# If it is not installed, those steps are skipped with a warning and the rest
# (pinout JPEGs, net-label schematic SVG, netlist) are still produced.
#
# Usage:
#   perl scripts/gen-test-platform.pl
#
# Environment:
#   SCH_PYTHON   python interpreter to use (default: /tmp/sch-venv/bin/python,
#                falling back to python3 on PATH). Needs PIL, schemdraw,
#                cairosvg and pypdf.

use strict;
use warnings;
use File::Spec;
use File::Basename;
use File::Find;
use File::Path qw(make_path remove_tree);
use File::Copy qw(move);
use Cwd qw(abs_path);

my $script_dir  = dirname(abs_path($0));
my $helpers_dir = File::Spec->catdir($script_dir, 'helpers');
my $root        = abs_path(File::Spec->catdir($script_dir, File::Spec->updir));
my $out_dir    = File::Spec->catdir($root, 'docs', 'test-platform');
my $svg_dir    = File::Spec->catdir($out_dir, 'svg');
my $facts_dir  = File::Spec->catdir($out_dir, 'facts');
my $build      = File::Spec->catdir($root, '.build-test-platform');
my $build_t    = File::Spec->catdir($build, 't');

die "docs/test-platform/ not found at $out_dir\n" unless -d $out_dir;

# netlistsvg JSON -> SVG filename the rest of the pipeline expects.
my @nlsvg_map = (
    ['test-platform.signals.nlsvg.json' => 'test-pinout-schematic-signals.svg'],
    ['test-platform.nlsvg.json'         => 'test-pinout-schematic-wired.svg'],
    ['sheet-i2c.nlsvg.json'             => 'sheet-i2c.svg'],
    ['sheet-spi.nlsvg.json'             => 'sheet-spi.svg'],
    ['sheet-stepper.nlsvg.json'         => 'sheet-stepper.svg'],
    ['sheet-display.nlsvg.json'         => 'sheet-display.svg'],
);

my $python    = find_python();
my @netlistsvg = find_netlistsvg();

print "Python:    $python\n";
print "netlistsvg: ", (@netlistsvg ? "@netlistsvg" : "(not found - schematic PDF/wired SVGs will be skipped)"), "\n\n";

# Fresh scratch tree so stale output from a prior run can't leak through.
remove_tree($build) if -d $build;
make_path($build_t);
make_path($svg_dir);
make_path($facts_dir);

# 1. Pinout JPEGs (independent of the schematic chain).
run_in($build, $python, File::Spec->catfile($helpers_dir, 'gen-pinout-images.py'))
    or warn "WARN: gen-pinout-images.py failed - pinout JPEGs may be missing\n";

# 2. Netlist + net-label SVG + the netlistsvg JSON inputs.
my $schematic_ok =
    run_in($build, $python, File::Spec->catfile($helpers_dir, 'gen-schematic.py'));
warn "WARN: gen-schematic.py failed - schematic outputs may be missing\n"
    unless $schematic_ok;

# 3. Wire-routed SVGs (netlistsvg) + the multi-page PDF, if the tool exists.
if ($schematic_ok && @netlistsvg) {
    for my $pair (@nlsvg_map) {
        my ($json, $svg) = @$pair;
        next unless -f File::Spec->catfile($build_t, $json);
        run_in($build, @netlistsvg,
               File::Spec->catfile('t', $json), '-o', File::Spec->catfile('t', $svg))
            or warn "WARN: netlistsvg failed for $json\n";
    }
    run_in($build, $python, File::Spec->catfile($helpers_dir, 'gen-pdf.py'))
        or warn "WARN: gen-pdf.py failed - schematic PDFs may be missing\n";
}
elsif ($schematic_ok) {
    print "\nSkipping wire-routed SVGs and schematic PDF (netlistsvg unavailable).\n";
    print "Install it (e.g. `npm i -g netlistsvg`) and re-run to produce them.\n\n";
}

# 4. File every produced artifact into its destination (or discard it).
my %count = (svg => 0, facts => 0, doc => 0, root => 0, drop => 0);
opendir my $dh, $build_t or die "opendir $build_t: $!\n";
for my $name (sort readdir $dh) {
    my $src = File::Spec->catfile($build_t, $name);
    next unless -f $src;
    my $dest_dir = classify_dest($name);
    if (! defined $dest_dir) {
        $count{drop}++;
        next;
    }
    my $dest = File::Spec->catfile($dest_dir, $name);
    move($src, $dest) or die "move $name -> $dest_dir: $!\n";
    printf "  %-38s -> %s\n", $name, rel($dest_dir);
    my $bucket = $dest_dir eq $svg_dir   ? 'svg'
               : $dest_dir eq $facts_dir ? 'facts'
               : $dest_dir eq $out_dir   ? 'doc'
               :                           'root';
    $count{$bucket}++;
}
closedir $dh;

# Removing the scratch tree also disposes of the discarded intermediates.
remove_tree($build);

# Sweep macOS AppleDouble / .DS_Store cruft a Mac may have left in the tree.
my $cruft = prune_apple_cruft($out_dir);

printf "\nDone: %d SVG -> svg/, %d netlist -> facts/, %d artifacts -> %s, %d extra -> repo root, %d intermediate discarded.\n",
    $count{svg}, $count{facts}, $count{doc}, rel($out_dir), $count{root}, $count{drop};
print "Pruned $cruft macOS cruft file(s) (._* / .DS_Store).\n" if $cruft;

# --- helpers ---------------------------------------------------------------

# Decide which directory a generated file belongs in, or undef to discard it.
sub classify_dest {
    my ($name) = @_;
    # netlistsvg input JSON: a throwaway intermediate, regenerated every run and
    # referenced by nothing shipped. Discard (it dies with the scratch dir).
    return undef    if $name =~ /\.nlsvg\.json$/;
    return $svg_dir  if $name =~ /\.svg$/;
    return $facts_dir if $name =~ /\.net$/;
    return $out_dir  if $name =~ /\.(jpg|pdf)$/;
    # Anything unexpected: leave at the repo root for the user to triage.
    return $root;
}

# Locate netlistsvg: a direct binary first, then `npx netlistsvg`. Returns the
# command as a list, or an empty list if neither is available.
sub find_netlistsvg {
    return ($ENV{NETLISTSVG}) if $ENV{NETLISTSVG} && -x $ENV{NETLISTSVG};
    my $direct = which('netlistsvg');
    return ($direct) if $direct;
    my $npx = which('npx');
    return ($npx, 'netlistsvg') if $npx;
    return ();
}

# Pick the Python interpreter and verify the schematic deps import.
sub find_python {
    my @cands = ($ENV{SCH_PYTHON}, '/tmp/sch-venv/bin/python', which('python3'));
    for my $py (@cands) {
        next unless $py && -x $py;
        my $missing = qx($py -c "import importlib,sys
mods=['PIL','schemdraw','cairosvg','pypdf']
print(','.join(m for m in mods if importlib.util.find_spec(m) is None))" 2>/dev/null);
        chomp $missing;
        warn "WARN: $py is missing Python modules: $missing\n" if $missing;
        return $py;
    }
    die "No usable Python found (set SCH_PYTHON or create /tmp/sch-venv)\n";
}

# Remove macOS AppleDouble / .DS_Store cruft from a directory tree. These are
# created by macOS on non-Mac filesystems and are never part of the output.
sub prune_apple_cruft {
    my ($dir) = @_;
    my $n = 0;
    find(sub {
        return unless -f $_;
        return unless /^\._/ || $_ eq '.DS_Store';
        $n++ if unlink $File::Find::name;
    }, $dir);
    return $n;
}

# Path of a file relative to the repo root, for tidy logging.
sub rel { File::Spec->abs2rel($_[0], $root) }

# Run a command with its working directory set to $dir, without disturbing the
# parent process's cwd. Returns true on a zero exit status.
sub run_in {
    my ($dir, @cmd) = @_;
    my $pid = fork();
    die "fork failed: $!\n" unless defined $pid;
    if (! $pid) {
        chdir $dir or die "chdir $dir: $!\n";
        exec { $cmd[0] } @cmd or die "exec $cmd[0]: $!\n";
    }
    waitpid $pid, 0;
    return $? == 0;
}

# Locate an executable on PATH.
sub which {
    my ($prog) = @_;
    for my $d (split /:/, ($ENV{PATH} // '')) {
        my $p = File::Spec->catfile($d, $prog);
        return $p if -x $p;
    }
    return undef;
}
