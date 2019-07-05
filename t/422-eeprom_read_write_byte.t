use strict;
use warnings;

use lib 't/';

use RPiTest;
use Test::More;
use RPi::WiringPi;

BEGIN {
    if (! $ENV{RPI_EEPROM}){
        plan skip_all => "RPI_EEPROM environment variable not set\n";
    }

    if (! $ENV{PI_BOARD}){
        $ENV{NO_BOARD} = 1;
        plan skip_all => "Not on a Pi board\n";
    }
}

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new;
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
rpi_metadata_clean();

done_testing();
