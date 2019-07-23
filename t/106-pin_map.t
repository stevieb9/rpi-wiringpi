use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

rpi_running_test(__FILE__);

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

my $pi = RPi::WiringPi->new(setup => 'none', label => 't/106-pin_map.t');

is $pi->pin_scheme, -1, "pin_scheme() returns NULL if not set";

is
    $pi->pin_scheme('BCM'),
    'BCM',
    "pin_scheme() returns BCM if setup() is sys";

is
    $pi->pin_scheme('GPIO'),
    'GPIO',
    "pin_scheme() returns GPIO if setup() is gpio";

is
    $pi->pin_scheme('PHYS_GPIO'),
    'PHYS_GPIO',
    "pin_scheme() returns BCM if setup() is phys";

is
    $pi->pin_scheme('WPI'),
    'WPI', 
    "pin_scheme() returns 'wiringPi' if setup() is wiringPi";

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
