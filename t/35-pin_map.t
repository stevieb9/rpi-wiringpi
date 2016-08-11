use strict;
use warnings;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Test::More;

my $mod = 'RPi::WiringPi';

if (! $ENV{PI_BOARD}){
    warn "\n*** PI_BOARD is not set! ***\n";
    $ENV{NO_BOARD} = 1;
}

my $pi = $mod->new;

is $pi->pin_map, 'NULL', "pin_map() returns NULL if not set";
is $pi->pin_map('BCM'), 'BCM', "pin_map() returns BCM if setup() is sys";
is $pi->pin_map('GPIO'), 'GPIO', "pin_map() returns GPIO if setup() is gpio";
is $pi->pin_map('PHYS_GPIO'), 'PHYS_GPIO', "pin_map() returns BCM if setup() is phys";
is (
    $pi->pin_map('wiringPi'), 
    'wiringPi', 
    "pin_map() returns 'wiringPi' if setup() is wiringPi"
);

done_testing();
