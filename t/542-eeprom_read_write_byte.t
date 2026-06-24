# TESTDOC: EEPROM byte read/write
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

BEGIN {
    if (! $ENV{RPI_EEPROM}){
        plan skip_all => "RPI_EEPROM environment variable not set\n";
    }
}

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(
    label => 't/542-eeprom_read_write_byte.t',
    shm_key => 'rpit'
);
my $e = $pi->eeprom(delay => 2);

$e->write(100, 232);
is $e->read(100), 232, "single address write/read ok";

my $val = 100;

for (4080..4095){
    $e->write($_, $val);
    is $e->read($_), $val, "wrote val $val to addr $_ ok";
    $val++;
}

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
