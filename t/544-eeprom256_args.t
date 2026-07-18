# TESTDOC: EEPROM AT24C256 argument validation
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
use RPi::WiringPi;
use Test::More;

BEGIN {
    if (! $ENV{RPI_EEPROM256}){
        plan skip_all => "RPI_EEPROM256 environment variable not set\n";
    }
}

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(label => 't/544-eeprom256_args.t', shm_key => 'rpit');
my $e = $pi->eeprom(chip => 'AT24C256');

is ref $e, 'RPi::EEPROM::AT24C256', "object is of proper class";
is $e->{address}, 0x50, "default i2c address ok";
is $e->{device}, '/dev/i2c-1', "default i2c device ok";
is $e->{delay}, 1, "default delay ok";
is $e->{fd} > 0, 1, "file descriptor initialised and set ok";

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
