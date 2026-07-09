#!/usr/bin/env perl

use warnings;
use strict;
use feature 'say';

# Audit the RPi::WiringPi family's Makefile.PL build guards for drift against
# the canonical wiringPi minimum version. Read-only reporter (V1 of the
# wiringpi-version-single-source plan): it derives the family list from this
# repo's PREREQ_PM (RPi::* + WiringPi::API), locates each dist's Makefile.PL
# (local clone under ~/repos first, else raw.githubusercontent.com), and
# reports the guard class, the wiringPi minimum it enforces, and whether that
# drifts from canonical. Nothing is modified.
#
#   perl scripts/audit-family-buildcheck.pl [--markdown]

use constant CANONICAL => '3.18';

my $repo_root     = "$ENV{HOME}/repos";
my $this_makefile = "$repo_root/rpi-wiringpi/Makefile.PL";

# Module -> repo slug, only where the default rule (lc; :: -> -) is wrong.
my %slug_exception = (
    'RPi::OLED::SSD1306::128_64' => 'rpi-oled-ssd1306',
);

# Run and print when executed as a script; when require'd (by
# xt/author/buildcheck-audit.t) just expose audit_family() and the helpers.
_main() unless caller;

sub _main {
    my $markdown = grep { $_ eq '--markdown' } @ARGV;
    emit_report(audit_family(), $markdown);
}

sub audit_family {
    my @family = family_modules($this_makefile);
    die "Found no RPi::* / WiringPi::API entries in $this_makefile PREREQ_PM\n"
        if ! @family;
    return [ map { audit_dist($_) } @family ];
}

# --- family discovery ------------------------------------------------------

sub family_modules {
    my ($makefile) = @_;

    open my $fh, '<', $makefile or die "Could not open $makefile: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;

    my ($block) = $content =~ /PREREQ_PM\s*=>\s*\{(.*?)\}/s;
    $block //= $content;

    my @mods;
    while ($block =~ /(['"])(RPi::[^'"]+|WiringPi::API)\1\s*=>/g) {
        push @mods, $2;
    }

    # Stable, human-friendly order: WiringPi::API last, RPi::* sorted.
    my @rpi = sort grep { $_ ne 'WiringPi::API' } @mods;
    my @api = grep { $_ eq 'WiringPi::API' } @mods;

    return (@rpi, @api);
}

sub module_to_slug {
    my ($mod) = @_;
    return $slug_exception{$mod} if exists $slug_exception{$mod};
    (my $slug = lc $mod) =~ s/::/-/g;
    return $slug;
}

# --- locate + audit one dist -----------------------------------------------

sub audit_dist {
    my ($mod) = @_;

    my $slug = module_to_slug($mod);
    my ($content, $source, $dir) = locate_makefile($slug);

    my %r = (module => $mod, slug => $slug, source => $source);

    if (! defined $content) {
        @r{qw(xs class needs shim min drift)} =
            ('?', '?', '?', '?', '?', 'NOT FOUND (no clone, fetch failed)');
        return \%r;
    }

    $r{xs}    = defined $dir ? (dir_has_xs($dir) ? 'yes' : 'no') : '?';
    $r{class} = guard_class($content);
    $r{needs} = detect_needs($dir, $content);
    $r{shim}  = $content =~ /RPi::Const::BuildCheck/ ? 'yes' : 'no';
    $r{min}   = wiringpi_min($content, $r{class});
    $r{drift} = drift_status(\%r);

    return \%r;
}

sub locate_makefile {
    my ($slug) = @_;

    my $local = "$repo_root/$slug/Makefile.PL";
    if (-f $local) {
        open my $fh, '<', $local or die "Could not read $local: $!\n";
        my $content = do { local $/; <$fh> };
        close $fh;
        return ($content, 'local', "$repo_root/$slug");
    }

    # Fall back to GitHub raw (try the default branches). Best-effort only.
    require HTTP::Tiny;
    my $http = HTTP::Tiny->new(timeout => 20);
    for my $branch (qw(master main)) {
        my $url = "https://raw.githubusercontent.com/stevieb9/$slug/$branch/Makefile.PL";
        my $res = $http->get($url);
        return ($res->{content}, "github:$branch", undef) if $res->{success};
    }

    return (undef, 'unavailable', undef);
}

sub dir_has_xs {
    my ($dir) = @_;
    my @xs = glob "$dir/*.xs";   # list context: fresh, not the scalar iterator
    return scalar @xs;
}

sub detect_needs {
    # What build check a dist ACTUALLY needs, from what it links/includes -
    # independent of the guard it currently carries. A dist linking wiringPi
    # needs the wiringpi check; one using the raw Linux I2C headers needs the
    # i2c check; a standard-C XS (or pure-perl) dist needs neither.
    my ($dir, $makefile_content) = @_;

    # A dist with no XS compiles nothing, so it needs no build guard whatever
    # its (sometimes vestigial) Makefile.PL LIBS claim.
    return 'none' if defined $dir && ! dir_has_xs($dir);

    my $wpi = $makefile_content =~ /-lwiringPi/;
    my $i2c = 0;

    if (defined $dir) {
        for my $file (glob("$dir/*.xs"), glob("$dir/*.c"), glob("$dir/*.h")) {
            open my $fh, '<', $file or next;
            my $src = do { local $/; <$fh> };
            close $fh;
            $wpi ||= $src =~ /#\s*include\s*<wiringPi\.h>/;
            # Only an ANGLE-bracket <linux/i2c*.h> means a real libi2c-dev
            # dependency; a quoted "i2c-dev.h" is a header the dist BUNDLES
            # (eg. rpi-eeprom-at24c32), so it compiles without the system
            # package and needs no i2c guard.
            $i2c ||= $src =~ m{#\s*include\s*<(?:linux/)?i2c(?:-dev)?\.h>};
        }
    }

    return 'wiringpi' if $wpi;
    return 'i2c'      if $i2c;
    return 'none';
}

# --- guard classification --------------------------------------------------

sub guard_class {
    my ($c) = @_;

    my $wp  = $c =~ m{wiringPi\.h} || has_version_check($c);
    my $i2c = $c =~ m{\bi2c(?:-dev)?\.h\b};

    return 'both'     if $wp && $i2c;
    return 'wiringpi' if $wp;
    return 'i2c'      if $i2c;
    return 'none';
}

sub has_version_check {
    my ($c) = @_;
    return $c =~ /WIRINGPI_MIN_VERSION|version->parse|gpio\s*-v/;
}

sub wiringpi_min {
    my ($c, $class) = @_;

    return '-' unless $class eq 'wiringpi' || $class eq 'both';

    return CANONICAL . ' (via RPi::Const)' if $c =~ /WIRINGPI_MIN_VERSION/;

    if (has_version_check($c)) {
        # A wiringPi minimum is a 1-2 digit minor (2.36, 3.18) - NOT a dist
        # version like 3.1801, and never the perl/EUMM 5.x/6.x numbers.
        if (my ($v) = $c =~ /\b([23]\.\d{1,2})\b/) {
            return $v;
        }
        return 'version check (literal unclear)';
    }

    return 'presence only (no version check)';
}

sub drift_status {
    my ($r) = @_;
    my $class = $r->{class};

    # A dist converted to the RPi::Const::BuildCheck shim gets its minimum from
    # the family constant, so it can't drift.
    return 'converted (BuildCheck shim)' if ($r->{shim} // '') eq 'yes';

    if ($class eq 'wiringpi' || $class eq 'both') {
        return 'canonical'            if index($r->{min}, CANONICAL) == 0;
        return 'PRESENCE-ONLY (no min)' if $r->{min} =~ /presence only/;
        return "DRIFT ($r->{min})";
    }
    return 'i2c-only (no wiringPi guard)' if $class eq 'i2c';

    # class 'none': an XS dist is only a real gap if it actually links wiringPi
    # or includes a SYSTEM i2c header (needs ne 'none'). A standard-C XS - or
    # one that bundles its own i2c header (rpi-eeprom-at24c32) - compiles
    # anywhere and needs no guard, so it is not a FAIL-not-NA risk.
    if ($r->{xs} eq 'yes') {
        return 'GUARDLESS XS (FAIL not NA on testers)' if $r->{needs} ne 'none';
        return 'standard-C XS (no guard needed)';
    }
    return 'n/a (pure perl)';
}

# --- reporting -------------------------------------------------------------

sub emit_report {
    my ($rows, $markdown) = @_;

    my @cols = (
        [ module => 'Module' ],
        [ slug   => 'Repo' ],
        [ source => 'Source' ],
        [ xs     => 'XS' ],
        [ class  => 'Guard' ],
        [ min    => 'wiringPi min' ],
        [ drift  => 'Status vs ' . CANONICAL ],
    );

    if ($markdown) {
        say '| ' . join(' | ', map { $_->[1] } @cols) . ' |';
        say '|' . join('|', map { '---' } @cols) . '|';
        for my $r (@$rows) {
            say '| ' . join(' | ', map { $r->{$_->[0]} } @cols) . ' |';
        }
    }
    else {
        my %w;
        for my $col (@cols) {
            my $key = $col->[0];
            $w{$key} = length $col->[1];
            for my $r (@$rows) {
                my $len = length $r->{$key};
                $w{$key} = $len if $len > $w{$key};
            }
        }
        my $fmt = join('  ', map { "%-$w{$_->[0]}s" } @cols) . "\n";
        printf $fmt, map { $_->[1] } @cols;
        printf $fmt, map { '-' x $w{$_->[0]} } @cols;
        for my $r (@$rows) {
            printf $fmt, map { $r->{$_->[0]} } @cols;
        }
    }

    # Summary counts for the audit gate.
    my %count;
    $count{$_->{drift}}++ for @$rows;
    say '' unless $markdown;
    say $markdown ? '' : 'Summary:';
    for my $status (sort keys %count) {
        say $markdown ? "- **$count{$status}** $status" : "  $count{$status}  $status";
    }
}

sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
