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
use RPi::OLED::SSD1306::128_64;

if (! $ENV{RPI_OLED}){
    plan skip_all => "RPI_OLED environment variable not set\n";
}

rpi_running_test(__FILE__);

# Leave the physical panel in its low-power state at the very end of the OLED
# suite, so the board isn't left driving the display. Guarded for the install
# lag: sleep() needs RPi::OLED::SSD1306::128_64 >= 3.1802.
if (RPi::OLED::SSD1306::128_64->can('sleep')){
    is(RPi::OLED::SSD1306::128_64->new->sleep, 1, "panel left asleep (low power)");
}

is rpi_oled_available(), 0, "oled still unavailable for use";
is rpi_oled_available(1), 1, "oled now available";
is -e '/dev/shm/oled_unavailable.rpi-wiringpi', undef, "oled lock file removed ok";

done_testing();

