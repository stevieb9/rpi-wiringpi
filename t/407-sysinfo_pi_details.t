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

like $pi->pi_details, qr|Raspberry Pi|, "method includes data ok";

like $pi->pi_details, qr|BCM2835|, "method includes data ok";

done_testing();
