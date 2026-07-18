# TESTDOC: EEPROM AT24C256 byte read/write
use strict;
use warnings;

# Standalone AT24C256 (bench-wired, not on any board): RPI_EEPROM256=1 arms this
# test and sets RPI_BOARD so it clears RPiTest's compile-time RPI_BOARD skip_all
# gate. Runs in BEGIN so it lands before that gate. It is NOT part of the board-4
# suite - it shares no board with the RTC/BMP/OLED/AT24C32.
BEGIN {
    if ($ENV{RPI_EEPROM256}) {
        $ENV{RPI_BOARD} = 1;
    }
}

use lib 't/';

use RPiTest;
use Test::More;
use RPi::WiringPi;

BEGIN {
    if (! $ENV{RPI_EEPROM256}){
        plan skip_all => "RPI_EEPROM256 environment variable not set\n";
    }
}

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(
    label => 't/546-eeprom256_read_write_byte.t',
    shm_key => 'rpit'
);
my $e = $pi->eeprom(chip => 'AT24C256', delay => 2);

$e->write(100, 232);
is $e->read(100), 232, "single address write/read ok";

my $val = 100;

for (32752..32767){
    $e->write($_, $val);
    is $e->read($_), $val, "wrote val $val to addr $_ ok";
    $val++;
}

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
