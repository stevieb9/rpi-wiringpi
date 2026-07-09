# TESTDOC: RPi::SysInfo unit (HW-free)
use strict;
use warnings;

use RPi::SysInfo qw(:all);
use Test::More;

# Mirror of RPi::SysInfo's HW-free tests (its t/50-helpers.t), run here in the
# canonical suite against the INSTALLED module. t/300-308 drive the live system
# queries on this Pi; this covers the parse/decode/format logic with the _run
# (command) and _slurp (file) seams overridden, plus the two TCG defects:
#   F15a - cpuPercent()/memPercent() return -1.0 on failure; _format now
#          surfaces that as '' rather than a nonsensical "-1.00" percentage.
#   F15b - the raspi_config config.txt grep must skip blank lines too; the old
#          '(#|^$)' alternation had an unreachable blank-line branch.

no warnings 'redefine';

my $mod = 'RPi::SysInfo';

# --- _decode_revision(): board revision-code decode, incl. the 16GB Pi 5 ---
{
    my %expect = (
        e04170 => {                                 # Pi 5 16GB (mem field 6)
            name => 'Raspberry Pi 5 Model B', type => '5 Model B',
            soc  => 'BCM2712', mem => '16GB', rp1 => 1, new_style => 1,
        },
        d04171 => {                                 # Pi 5 8GB
            name => 'Raspberry Pi 5 Model B', mem => '8GB', rp1 => 1,
        },
        c03112 => {                                 # Pi 4 4GB
            name => 'Raspberry Pi 4 Model B', soc => 'BCM2711', mem => '4GB',
            rp1  => 0,
        },
        a02082 => {                                 # Pi 3B 1GB
            name => 'Raspberry Pi 3 Model B', soc => 'BCM2837', mem => '1GB',
        },
    );

    for my $rev (sort keys %expect){
        my $got = RPi::SysInfo::_decode_revision($rev);
        for my $k (sort keys %{$expect{$rev}}){
            is $got->{$k}, $expect{$rev}{$k}, "_decode_revision($rev) $k = $expect{$rev}{$k}";
        }
    }

    is_deeply RPi::SysInfo::_decode_revision(undef), {}, "undef revision => {}";
    is_deeply RPi::SysInfo::_decode_revision('xyz'), {}, "non-hex revision => {}";
}

# --- _mem_human(): MB below 1024, GB on 1024-multiples ---
{
    my %m = (256 => '256MB', 512 => '512MB', 1024 => '1GB', 8192 => '8GB', 16384 => '16GB');
    is RPi::SysInfo::_mem_human($_), $m{$_}, "_mem_human($_) = $m{$_}" for sort { $a <=> $b } keys %m;
    is RPi::SysInfo::_mem_human(undef), undef, "_mem_human(undef) = undef";
}

# --- _format(): 2 dp rounding + F15a negative-sentinel handling ---
is RPi::SysInfo::_format(12.345), '12.35',  "_format rounds 12.345 -> 12.35";
is RPi::SysInfo::_format(0),      '0.00',   "_format 0 -> 0.00";
is RPi::SysInfo::_format(-1),     '', "_format returns '' on the -1.0 error sentinel (F15a)";
is RPi::SysInfo::_format(-0.5),   '', "_format treats any negative as an error (F15a)";
eval { RPi::SysInfo::_format(undef) };
like $@, qr/requires a float/, "_format(undef) croaks";

# --- cpu_percent() / mem_percent(): XS formatting + F15a sentinel, both forms ---
{
    local *RPi::SysInfo::cpuPercent = sub { 42.5 };
    local *RPi::SysInfo::memPercent = sub { 73.219 };

    is cpu_percent(), '42.50', "cpu_percent formats the XS sample";
    is mem_percent(), '73.22', "mem_percent formats the XS sample";

    my $sys = $mod->new;
    is $sys->cpu_percent, '42.50', "OO cpu_percent same path";
    is $sys->mem_percent, '73.22', "OO mem_percent same path";
}
{
    local *RPi::SysInfo::cpuPercent = sub { -1.0 };
    local *RPi::SysInfo::memPercent = sub { -1.0 };

    is cpu_percent(), '', "cpu_percent returns '' on the XS -1.0 sentinel (F15a)";
    is mem_percent(), '', "mem_percent returns '' on the XS -1.0 sentinel (F15a)";
}

# --- raspi_config(): F15b - the config.txt filter drops comments AND blanks ---
{
    my @cmds;
    local *RPi::SysInfo::_run         = sub { push @cmds, $_[0]; '' };
    local *RPi::SysInfo::_config_file = sub { '/boot/firmware/config.txt' };

    raspi_config();

    my ($grep) = grep { /grep/ } @cmds;
    like   $grep, qr/\Q(#|$)\E/,  "raspi_config grep skips comments and blanks (F15b)";
    unlike $grep, qr/\Q(#|^$)\E/, "raspi_config grep has no malformed inner '^' (F15b)";
}

done_testing();
