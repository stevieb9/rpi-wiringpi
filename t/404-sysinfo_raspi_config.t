use warnings;
use strict;
use feature 'say';

use lib 't/';

use RPiTest qw(check_pin_status running_test);
use RPi::WiringPi;
use Test::More;

if (! $ENV{PI_BOARD}){
    plan skip_all => "Not on a Pi board";
}

running_test(__FILE__);

my $pi = RPi::WiringPi->new;

like $pi->raspi_config, qr/core_freq/, "method includes data ok";

like
    $pi->raspi_config,
    qr/dtoverlay=pi3-disable-bt-overlay/,
    "...and custom changes are included";

done_testing();
