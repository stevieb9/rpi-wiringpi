# TESTDOC: RPi::RTC::DS3231 setter validation + temp conversion (HW-free)
use strict;
use warnings;

use RPi::RTC::DS3231;
use Test::More;

# Mirror of RPi::RTC::DS3231's HW-free validation/temp tests (its
# t/75-validation.t), run here in the canonical suite against the INSTALLED
# module. t/530-rtc.t drives the chip on hardware (queued on board-4); t/532
# proves the BCD codec. This covers the Perl-side setter-range croaks and the
# temp() conversion (including the negative path) with no chip:
#   - _write_time() validates each field BEFORE touching the fd, so an
#     out-of-range date_time() croaks on a bare-blessed object.
#   - getTemp() (the XS register/sign decode) is stubbed, so temp()/temp('f')
#     formatting + Fahrenheit conversion run HW-free over known Celsius values.

my $mod = 'RPi::RTC::DS3231';

# --- date_time() -> _write_time() field-range croaks (precede the fd) ---
{
    my $o = bless {}, $mod;

    # The captures are the zero-padded matched strings, interpolated verbatim.
    my %bad = (
        'year below 2000' => ['1999-01-01 00:00:00', qr/Year \(1999\) out of range/],
        'year above 2099' => ['2100-01-01 00:00:00', qr/Year \(2100\) out of range/],
        'month 00'        => ['2025-00-01 00:00:00', qr/Month \(00\) out of range/],
        'month 13'        => ['2025-13-01 00:00:00', qr/Month \(13\) out of range/],
        'mday 00'         => ['2025-01-00 00:00:00', qr/Month day \(00\) out of range/],
        'mday 32'         => ['2025-01-32 00:00:00', qr/Month day \(32\) out of range/],
        'hour 24'         => ['2025-01-01 24:00:00', qr/Hour \(24\) out of range/],
        'min 60'          => ['2025-01-01 00:60:00', qr/Minutes \(60\) out of range/],
        'sec 60'          => ['2025-01-01 00:00:60', qr/Seconds \(60\) out of range/],
    );

    for my $case (sort keys %bad){
        my ($dt, $re) = @{ $bad{$case} };
        eval { $o->date_time($dt) };
        like $@, $re, "date_time($case): croaks before the fd";
    }
}

# --- date_time() format croak + am_pm()/clock_hours() bad-arg croaks ---
{
    my $o = bless {}, $mod;

    eval { $o->date_time('blah') };
    like $@, qr/parameter must be in the format/, "date_time(bad format): croaks";

    eval { $o->am_pm('X') };
    like $@, qr/either 'AM' or 'PM'/, "am_pm(bad meridien): croaks";

    eval { $o->clock_hours(13) };
    like $@, qr/either 12 or 24/, "clock_hours(13): croaks";
}

# --- temp(): sign + 2-decimal format + F-conversion, incl. the negative path ---
{
    no warnings 'redefine';

    my $c;
    local *RPi::RTC::DS3231::getTemp = sub { $c };
    my $o = bless { fd => -1 }, $mod;   # preset fd so _fd() never calls getFh

    my @cases = (
        [ -25,   '-25.00', '-13.00' ],
        [ -40,   '-40.00', '-40.00' ],
        [ 0,     '0.00',   '32.00'  ],
        [ 22.5,  '22.50',  '72.50'  ],
        [ 85,    '85.00',  '185.00' ],
    );

    for my $case (@cases){
        my ($celsius, $c_str, $f_str) = @$case;
        $c = $celsius;
        is $o->temp,      $c_str, "temp() formats ${celsius}C as $c_str";
        is $o->temp('f'), $f_str, "temp('f') converts ${celsius}C to $f_str";
    }
}

done_testing();
