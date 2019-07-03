use strict;
use warnings;

use lib 't/';

use RPiTest qw(check_pin_status running_test);
use Test::More;
use RPi::EEPROM::AT24C32;

BEGIN {
    if (! $ENV{RPI_EEPROM}){
        plan skip_all => "RPI_EEPROM environment variable not set\n";
    }

    if (! $ENV{PI_BOARD}){
        $ENV{NO_BOARD} = 1;
        plan skip_all => "Not on a Pi board\n";
    }
}

running_test(__FILE__);

my $e = RPi::EEPROM::AT24C32->new(delay => 2);

$e->write(100, 232);
is $e->read(100), 232, "single address write/read ok";

my $val = 100;

for (4080..4095){
    $e->write($_, $val);
    is $e->read($_), $val, "wrote val $val to addr $_ ok";
    $val++;
}

done_testing();
