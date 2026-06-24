# TESTDOC: OLED cleanup
use strict;
use warnings;

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
use Test::More;
use RPi::Const;
use RPi::WiringPi;

if (! $ENV{RPI_OLED}){
    plan skip_all => "RPI_OLED environment variable not set\n";
}

rpi_running_test(__FILE__);

is rpi_oled_available(), 0, "oled still unavailable for use";
is rpi_oled_available(1), 1, "oled now available";
is -e '/dev/shm/oled_unavailable.rpi-wiringpi', undef, "oled lock file removed ok";

done_testing();

