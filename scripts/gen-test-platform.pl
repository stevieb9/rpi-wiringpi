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
#   *.kicad_sch, *.kicad_pro, fp-lib-table -> docs/test-platform/ (open in KiCad)
#   test-platform.pretty/                  -> docs/test-platform/ (footprint lib)
#   test-pinout-doc.pdf                    -> docs/test-platform/ (typeset in place)
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
# The human-readable pinout PDF (test-pinout-doc.pdf) is typeset from the in-repo
# test-pinout-doc.md with `pandoc` + `xelatex` (using the DejaVu fonts). When
# either is absent that step is skipped with a warning; the Markdown is the
# source of record and is never modified.
#
# Usage:
#   perl scripts/gen-test-platform.pl
#
# Environment:
#   SCH_PYTHON   Override the Python interpreter for the schematic pipeline.
#                When unset (the normal case) a persistent venv is built and
#                used automatically - see FRESH-PI SETUP below.
#   NETLISTSVG   Override the netlistsvg executable (default: PATH, then npx).
#
# ---------------------------------------------------------------------------
# FRESH-PI SETUP (building these docs on a new Raspberry Pi or other host)
# ---------------------------------------------------------------------------
# This script is hands-off. On first run it creates a persistent Python venv at
#
#     ${XDG_CACHE_HOME:-$HOME/.cache}/rpi-wiringpi/sch-venv
#
# and pip-installs the schematic dependencies (Pillow -> the PIL module,
# schemdraw, cairosvg, pypdf) into it. Later runs reuse that venv with no
# network access. There is nothing to do by hand AS LONG AS the host already
# has the system prerequisites below. If a run warns that a schematic step was
# skipped, install whatever is missing and re-run:
#
#   1. Python venv + pip support:
#        sudo apt install python3 python3-venv python3-pip
#   2. Native Cairo library (cairosvg loads libcairo at runtime):
#        sudo apt install libcairo2
#   3. netlistsvg, for the wire-routed SVGs + multi-page PDF (needs Node.js):
#        sudo apt install nodejs npm        # or install Node via nvm
#        npm install -g netlistsvg
#
# The venv self-heals: delete it to force a clean reinstall, and the next run
# rebuilds it -
#        rm -rf ${XDG_CACHE_HOME:-$HOME/.cache}/rpi-wiringpi/sch-venv
# To point at a hand-managed interpreter instead, export SCH_PYTHON=/path/python.
# ---------------------------------------------------------------------------

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

# No Python means no schematic/pinout pipeline. Warn and skip cleanly (exit 0)
# rather than dying, so a `make dist` on a host without the toolchain still
# succeeds and simply ships the previously generated artifacts.
if (! $python) {
    warn "WARN: no usable Python for the schematic pipeline; skipping "
       . "test-platform generation.\n"
       . "      See the FRESH-PI SETUP notes at the top of this script.\n";
    exit 0;
}

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

# 4. KiCad project (.kicad_sch + .kicad_pro). Pure-stdlib and independent of the
# schematic/netlistsvg chain - it reuses gen-schematic.py's model directly.
run_in($build, $python, File::Spec->catfile($helpers_dir, 'gen-kicad.py'))
    or warn "WARN: gen-kicad.py failed - KiCad project may be missing\n";

# 5. File every produced artifact into its destination (or discard it).
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

# The footprint library is a directory, so the file loop above skips it; move
# the whole .pretty tree into place, replacing any stale copy from a prior run.
my $pretty_src = File::Spec->catdir($build_t, 'test-platform.pretty');
if (-d $pretty_src) {
    my $pretty_dest = File::Spec->catdir($out_dir, 'test-platform.pretty');
    remove_tree($pretty_dest) if -d $pretty_dest;
    move($pretty_src, $pretty_dest) or die "move test-platform.pretty -> $out_dir: $!\n";
    printf "  %-38s -> %s\n", 'test-platform.pretty/', rel($out_dir);
}

# 6. Validate the filed KiCad project: every symbol must have a resolvable
# footprint whose pads cover its pins - the condition "Update PCB from Schematic"
# enforces. The helper also cross-checks with kicad-cli when that tool exists.
my $kicad_ok = run_in($root, $python,
    File::Spec->catfile($helpers_dir, 'check-kicad.py'), $out_dir);
warn "WARN: KiCad project validation FAILED - see the messages above.\n"
    unless $kicad_ok;

# 7. Typeset the human-readable pinout doc to PDF (pandoc + xelatex). Unlike the
# steps above, this works on the in-repo Markdown in place, not the scratch tree.
# Skipped cleanly when either tool is absent, mirroring the netlistsvg handling.
my $doc_md  = File::Spec->catfile($out_dir, 'test-pinout-doc.md');
my $pandoc  = which('pandoc');
if (-f $doc_md && $pandoc && which('xelatex')) {
    # DejaVu fonts carry the box-drawing, arrows and star glyphs the doc uses
    # (Latin Modern does not); the header maps the one glyph DejaVu Serif lacks
    # (the star marker) to DejaVu Sans.
    my $star_fallback =
          '\usepackage{newunicodechar}'
        . '\newfontfamily\dejavusans{DejaVu Sans}'
        . '\newunicodechar{★}{{\dejavusans ★}}';
    my $doc_ok = run_in($out_dir, $pandoc, 'test-pinout-doc.md',
        '-o', 'test-pinout-doc.pdf',
        '--pdf-engine=xelatex',
        '-V', 'mainfont=DejaVu Serif',
        '-V', 'monofont=DejaVu Sans Mono',
        '-V', 'monofontoptions=Scale=0.85',
        '-V', "header-includes=$star_fallback");
    if ($doc_ok) {
        printf "  %-38s -> %s\n", 'test-pinout-doc.pdf', rel($out_dir);
    }
    else {
        warn "WARN: pandoc failed - test-pinout-doc.pdf may be stale\n";
    }
}
else {
    print "\nSkipping test-pinout-doc.pdf (needs pandoc + xelatex on PATH).\n";
    print "Install them (e.g. `apt install pandoc texlive-xetex fonts-dejavu`) and re-run.\n\n";
}

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
    return $out_dir  if $name =~ /\.(jpg|pdf|kicad_sch|kicad_pro)$/;
    return $out_dir  if $name eq 'fp-lib-table';
    # Anything unexpected: leave at the repo root for the user to triage.
    return $root;
}

# Build the persistent schematic venv and install its Python deps. Idempotent:
# safe to call when the venv exists but is missing packages. Returns the venv
# interpreter path on success, or undef if it could not be built. See the
# FRESH-PI SETUP notes at the top of this script.
sub ensure_sch_venv {
    my $dir = sch_venv_dir();
    my $py  = File::Spec->catfile($dir, 'bin', 'python');

    # Create the venv from a base python3 the first time around.
    if (! -x $py) {
        my $base = which('python3');
        if (! $base) {
            warn "WARN: no python3 on PATH to build the schematic venv.\n"
               . "      See the FRESH-PI SETUP notes at the top of this script.\n";
            return undef;
        }
        make_path($dir);
        print "Creating persistent schematic venv at $dir ...\n";
        if (system($base, '-m', 'venv', $dir) != 0) {
            warn "WARN: 'python3 -m venv' failed (install python3-venv?).\n"
               . "      See the FRESH-PI SETUP notes at the top of this script.\n";
            return undef;
        }
    }

    # Install (or top up) the required packages.
    print "Installing schematic Python deps into the venv ...\n";
    if (system($py, '-m', 'pip', 'install', '--quiet', sch_pip_pkgs()) != 0) {
        warn "WARN: pip install of the schematic deps failed.\n"
           . "      See the FRESH-PI SETUP notes at the top of this script.\n";
        return undef;
    }

    return $py;
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

# Pick the Python interpreter for the schematic pipeline, building the
# persistent venv on first run if needed. Returns an interpreter with all deps
# importable, or undef. See the FRESH-PI SETUP notes at the top of this script.
sub find_python {
    # An explicit SCH_PYTHON override wins when it already has the deps.
    if ($ENV{SCH_PYTHON} && -x $ENV{SCH_PYTHON}) {
        my $missing = missing_modules($ENV{SCH_PYTHON});
        return $ENV{SCH_PYTHON} if ! $missing;
        warn "WARN: \$SCH_PYTHON ($ENV{SCH_PYTHON}) is missing modules: $missing\n"
           . "      See the FRESH-PI SETUP notes at the top of this script.\n";
    }

    # The persistent venv: use it as-is, or build/top it up once.
    my $venv_py = File::Spec->catfile(sch_venv_dir(), 'bin', 'python');
    $venv_py = ensure_sch_venv() if ! -x $venv_py || missing_modules($venv_py);
    return $venv_py if $venv_py && -x $venv_py && ! missing_modules($venv_py);

    # Last resort: a system python3 that already happens to have the deps.
    my $sys = which('python3');
    return $sys if $sys && ! missing_modules($sys);

    return undef;
}

# Return a comma-separated list of the required modules that $py cannot import,
# or the empty string if it has them all (Pillow supplies the PIL module).
sub missing_modules {
    my ($py) = @_;
    return 'python3' if ! ($py && -x $py);
    my $missing = qx($py -c "import importlib.util as u
mods = ['PIL', 'schemdraw', 'cairosvg', 'pypdf']
print(','.join(m for m in mods if u.find_spec(m) is None))" 2>/dev/null);
    chomp $missing;
    return $missing;
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

# pip package names for the schematic pipeline (Pillow provides the PIL module).
sub sch_pip_pkgs {
    return qw(Pillow schemdraw cairosvg pypdf);
}

# Location of the persistent schematic venv: under XDG_CACHE_HOME, else ~/.cache.
sub sch_venv_dir {
    my $cache = $ENV{XDG_CACHE_HOME} || File::Spec->catdir($ENV{HOME}, '.cache');
    return File::Spec->catdir($cache, 'rpi-wiringpi', 'sch-venv');
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
