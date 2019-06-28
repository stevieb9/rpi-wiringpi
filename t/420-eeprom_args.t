use strict;
use warnings;

use RPi::EEPROM::AT24C32;
use Test::More;

BEGIN {
    if (! $ENV{RPI_EEPROM}){
        plan skip_all => "RPI_EEPROM environment variable not set\n";
    }

    if (! $ENV{PI_BOARD}){
        $ENV{NO_BOARD} = 1;
        plan skip_all => "Not on a Pi board\n";
    }
}

my $e = RPi::EEPROM::AT24C32->new;

is ref $e, 'RPi::EEPROM::AT24C32', "object is of proper class";
is $e->{address}, 0x57, "default i2c address ok";
is $e->{device}, '/dev/i2c-1', "default i2c device ok";
is $e->{delay}, 1, "default delay ok";
is $e->{fd} > 0, 1, "file descriptor initialised and set ok";

done_testing();

