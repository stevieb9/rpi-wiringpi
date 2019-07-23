use warnings;
use strict;

use lib 't/';

use RPiTest;
use Test::More;
use WiringPi::API qw(:perl);

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

rpi_running_test(__FILE__);

setup_gpio();

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
