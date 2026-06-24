use warnings;
use strict;

# Board-4 convenience: set RPI_BOARD_4=1 and every env gate the board-4 suite
# needs is enabled automatically, instead of exporting each one by hand. Runs in
# BEGIN so it lands before RPiTest's compile-time RPI_BOARD skip_all gate.
BEGIN {
    if ($ENV{RPI_BOARD_4}) {
        $ENV{$_} = 1 for qw(RPI_BOARD RPI_RTC RPI_BMP RPI_EEPROM RPI_OLED);
    }
}

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use Test::More;

# RPi::RTC::DS3231 tests

if (! $ENV{RPI_RTC}){
    plan(skip_all => "RPI_RTC environment variable not set");
}

$SIG{__DIE__} = sub {};

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(fatal_exit => 0, label => 't/320-rtc.t', shm_key => 'rpit');
my $rtc = $pi->rtc;

{ # sec()

    for (0..59){
        is $rtc->sec($_), $_, "setting sec to '$_' result is ok";
        is $rtc->sec, $_, "...and reading is also '$_'"
    }

    for (-1, 60){
        is eval {$rtc->sec($_); 1}, undef, "sending '$_' results in failure ok";
        like $@, qr/out of bounds.*0-59/, "...and for '$_', error msg is sane";
    }
}

{ # min()

    is $rtc->sec(0), 0, "set seconds back to 0 ok";

    for (0..59){
        is $rtc->min($_), $_, "setting min to '$_' result is ok";
        is $rtc->min, $_, "...and reading is also '$_'"
    }

    for (-1, 60){
        is eval {$rtc->min($_); 1}, undef, "sending '$_' results in failure ok";
        like $@, qr/out of bounds.*0-59/, "...and for '$_', error msg is sane";
    }
}

{ # 24 hour clock

    $rtc->clock_hours(24);

    for (0..23){
        is $rtc->hour($_), $_, "setting 24-clock hour to '$_' result is ok";
        is $rtc->hour, $_, "...and reading is also '$_'"
    }

    for (-1, 25){
        is eval {$rtc->hour($_); 1}, undef, "sending '$_' results in failure ok";
        like $@, qr/out of bounds.*0-23/, "...and for '$_', error msg is sane";
    }
}

{ # 12 hour clock

    is $rtc->clock_hours(12), 12, "set to 12 hr clock ok";

    for (1..12){
        $rtc->hour($_);
        is $rtc->hour, $_, "setting hour to '$_' result is ok";
        is $rtc->hour, $_, "...and reading is also '$_'"
    }

    for (0, 13){
        is eval {$rtc->hour($_); 1}, undef, "sending '$_' results in failure ok";
        like $@, qr/out of bounds.*1-12/, "...and for '$_', error msg is sane";
    }
}

{ # clock_hours() bounds checking

    is $rtc->clock_hours(12), 12, "set to 12 ok";
    is $rtc->clock_hours(24), 24, "set to 24 ok";

    is eval { $rtc->clock_hours(13); 1 }, undef, "'13' is invalid ok";
    is eval { $rtc->clock_hours('a'); 1 }, undef, "'a' is invalid ok";
}

{ # clock_hours()

    $rtc->min(1);
    $rtc->sec(1);

    is $rtc->clock_hours(24), 24, "setting clock to 24 hr result ok";
    is $rtc->clock_hours, 24, "...and so is the return with no param";

    # 0

    is $rtc->hour(0), 0, "hr 0 in 24-hr mode ok";
    $rtc->clock_hours(12);
    is $rtc->clock_hours, 12, "set clock to 12-hr ok";
    is $rtc->hour, 12, "hr 0 in 12-hr mode ok";

    for (1..12){
        is $rtc->clock_hours(24), 24, "set clock to 24-hr ok";
        is $rtc->hour($_), $_, "hr $_ in 24-hr mode ok";
        is $rtc->clock_hours(12), 12, "set clock to 12-hr ok";
        is $rtc->hour, $_, "hr $_ in 12-hr mode ok";
    }

    for (13..23){
        is $rtc->clock_hours(24), 24, "set clock to 24-hr ok";
        is $rtc->hour($_), $_, "hr $_ in 24-hr mode ok";
        is $rtc->clock_hours(12), 12, "set clock to 12-hr ok";
        my $hr = $_ - 12;
        is $rtc->hour, $hr, "hr $_ == $hr in 12-hr mode ok";
    }
}

{ # am_pm()

    $rtc->clock_hours(12);
    is eval {$rtc->am_pm('X'); 1; }, undef, "am_pm() croaks with invalid param";
    like $@, qr/requires either 'AM' or 'PM'/, "...and error is sane";

    $rtc->clock_hours(24);
    is $rtc->min(13), 13, "set 24-hr clock to 13th min ok";
    is $rtc->sec(13), 13, "set 24-hr clock to 13th sec ok";

    # AM hours

    for (0..12){
        is $rtc->clock_hours(24), 24, "24 hr clock enabled ok";
        is $rtc->hour($_), $_, "set 24-hr clock to hour '$_' ok";
        is $rtc->clock_hours(12), 12, "12 hr clock enabled ok";
        is $rtc->am_pm, 'AM', "hr $_ in 24 clock mode is AM ok";
    }

    # PM hours

    for (13..23){
        is $rtc->clock_hours(24), 24, "24 hr clock enabled ok";
        is $rtc->hour($_), $_, "set 24-hr clock to hour '$_' ok";
        is $rtc->clock_hours(12), 12, "12 hr clock enabled ok";
        is $rtc->am_pm, 'PM', "hr $_ in 24 clock mode is PM ok";
    }

    is $rtc->clock_hours(24), 24, "set back to 24 hr clock ok";
}

{ # wday()

    my %days = (
        1 => "Monday",
        2 => "Tuesday",
        3 => "Wednesday",
        4 => "Thursday",
        5 => "Friday",
        6 => "Saturday",
        7 => "Sunday",
    );

    { # set/get

        for (1..7){
            is $rtc->day($_), $days{$_}, "$_ == $days{$_} ok";
        }
    }

    {   # out of bounds/illegal chars

        for (qw(8 0)){
            is eval { $rtc->day($_); 1; }, undef, "setting dow to '$_' fails ok";
        }
    }
}

{ # day()

    for (1..31){
        is $rtc->mday($_), $_, "setting mday to $_ ok";
    }
}

{  # day() out of bounds

    for (qw(0 32)){
        is eval { $rtc->mday($_); 1; }, undef, "setting dom to '$_' fails ok";
    }
}

{ # month()

    for (1..12){
        is $rtc->month($_), $_, "setting month to $_ ok";
    }
}

{   # month() out of bounds/illegal chars

    for (qw(0 13)){
        is eval { $rtc->month($_); 1; }, undef, "setting month to '$_' fails ok";
    }
}

{ # year()

    for (2000..2099){
        is $rtc->year($_), $_, "setting year to $_ ok";
    }
}

{   # year() out of bounds/illegal chars

    for (qw(1999 2100)){
        is eval { $rtc->year($_); 1; }, undef, "setting year to '$_' fails ok";
    }
}

{ # temp() - celcius, within the DS3231 operating range
  # (the old qr/\d+/ would pass a bogus +231, the sign bug's output for -25C;
  # the negative path itself is logic-verified, not room-temp reachable)

    my $temp = $rtc->temp;
    like $temp, qr/^-?\d+(?:\.\d{2})?$/, "temp() returns a number";
    cmp_ok $temp, '>=', -40, "temp() >= -40C (DS3231 spec)";
    cmp_ok $temp, '<=', 85,  "temp() <= 85C (DS3231 spec)";
}

{ # temp() - farenheit, within the DS3231 operating range

    my $f = $rtc->temp('f');
    like $f, qr/^-?\d+(?:\.\d{2})?$/, "temp('f') returns a number";
    cmp_ok $f, '>=', -40,  "temp('f') >= -40F";
    cmp_ok $f, '<=', 185,  "temp('f') <= 185F";
}

{ # hms()

    $rtc->clock_hours(24);

    $rtc->year(2018);
    $rtc->month(5);
    $rtc->mday(17);
    $rtc->hour(23);
    $rtc->min(55);
    $rtc->sec(01);

    like $rtc->hms, qr/^23:55:\d{2}$/, "hms() in 24-hr mode ok";

    $rtc->clock_hours(12);

    like $rtc->hms, qr/^11:55:\d{2} PM$/, "hms() in 12-hr PM mode ok";

    $rtc->hour(1);
    $rtc->am_pm('AM');

    like $rtc->hms, qr/^01:55:\d{2} AM$/, "hms() in 12-hr AM mode ok";
}

{ # date_time()

    $rtc->clock_hours(24);

    $rtc->year(2018);
    $rtc->month(5);
    $rtc->mday(17);
    $rtc->hour(23);
    $rtc->min(55);
    $rtc->sec(01);

    like
        $rtc->date_time,
        qr/^2018-05-17 23:55:\d{2}$/,
        "date_time() in 24-hr mode ok";

    $rtc->clock_hours(12);

    like
        $rtc->date_time,
        qr/^2018-05-17 23:55:\d{2}$/,
        "date_time() in 12-hr PM mode ok";

    $rtc->hour(1);
    $rtc->am_pm('AM');

    like
        $rtc->date_time,
        qr/^2018-05-17 01:55:\d{2}$/,
        "date_time() in 12-hr AM mode ok";

    $rtc->clock_hours(24);
}

{ # dt_hash()

    $rtc->clock_hours(24);

    $rtc->year(2018);
    $rtc->month(5);
    $rtc->mday(17);
    $rtc->hour(23);
    $rtc->min(55);
    $rtc->sec(01);

    my %dt = $rtc->dt_hash;

    my @valid = qw(year month day hour minute second);

    for (keys %dt){
        is exists $dt{$_}, 1, "$_ key exists ok";

        if ($_ eq 'year'){
            is $dt{$_}, 2018, "$_ ok";
            next;
        }

        like $dt{$_}, qr/^\d{2}$/, "$_ contains the proper values ok";
    }

    $rtc->clock_hours(24);
}


{ # date_time() set

    is
        eval { $rtc->date_time($rtc->date_time); 1; },
        1,
        "using properly formatted date ok";

    is
        eval { $rtc->date_time("blah"); 1; },
        undef,
        "croak ok if datetime format invalid";

    like $@, qr/parameter must be in the format/, "...and error is sane";
}

{ # raw-register BCD checks -- comprehensive on-silicon falsification
  #
  # The month()/hour() round-trips above pass even with the raw-vs-BCD bug
  # because getMonth/getHour do bcd2dec(reg) and bcd2dec(0x0C) == 12. Read the
  # actual stored byte and assert valid BCD across the full range. These FAIL
  # on the old raw-binary XS and PASS on the BCD XS, exercised through the
  # RPi::WiringPi -> $pi->rtc integration path (board 4). Reg 0x05 = month bits
  # 0-4 (+ century bit 7); reg 0x02 = hour bits 0-4 (+ AM/PM bit 5, 12/24 bit
  # 6) per the DS3231 datasheet.

    for my $m (1 .. 12) {
        $rtc->month($m);
        is $rtc->_get_register(0x05) & 0x1F, RPi::RTC::DS3231::dec2bcd($m),
            "month $m stored as valid BCD in reg 0x05 (not raw binary)";
    }

    $rtc->clock_hours(12);

    for my $h (1 .. 12) {
        $rtc->hour($h);
        is $rtc->_get_register(0x02) & 0x1F, RPi::RTC::DS3231::dec2bcd($h),
            "12-hour hour $h stored as valid BCD in reg 0x02 (not raw binary)";
    }

    # The 12/24-select (0x40) and AM/PM (0x20) bits must survive an hour() write
    $rtc->clock_hours(12);
    $rtc->am_pm('PM');
    $rtc->hour(11);
    my $hreg = $rtc->_get_register(0x02);
    ok $hreg & 0x40, '12/24-hour select bit preserved across hour() write';
    ok $hreg & 0x20, 'AM/PM bit preserved across hour() write';

    # The Century bit (0x80) must survive a month() write
    RPi::RTC::DS3231::setRegister(
        $rtc->_fd,
        0x05,
        0x80 | RPi::RTC::DS3231::dec2bcd(6),
        'seed century',
    );
    $rtc->month(12);
    ok $rtc->_get_register(0x05) & 0x80,
        'Century bit (0x80) preserved across month() write';

    $rtc->clock_hours(24);
}

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
