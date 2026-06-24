# TESTDOC: OLED horizontal line
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
use RPi::WiringPi;

if (! $ENV{RPI_OLED}){
    plan skip_all => "RPI_OLED environment variable not set\n";
}

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(label => 't/509-oled_horizontal_line.t', shm_key => 'rpit');
my $s = $pi->oled('128x64', 0x3C, 0);

is $s->horizontal_line(0, 32, 128), 1, "horizontal_line() return ok";
$s->display;

$s->clear;

$pi->cleanup;

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();

