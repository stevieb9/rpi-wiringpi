use warnings;
use strict;

use lib 't/';

use RPiTest qw(check_pin_status running_test);
use Test::More;
use WiringPi::API qw(:perl);

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

running_test(__FILE__);

setup_gpio();
check_pin_status();
done_testing();
