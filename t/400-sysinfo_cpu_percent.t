use warnings;
use strict;

use lib 't/';

use RPiTest qw(check_pin_status running_test);
use RPi::WiringPi;
use Test::More;

if (! $ENV{PI_BOARD}){
    plan skip_all => "Not on a Pi board";
}

running_test(__FILE__);

my $pi = RPi::WiringPi->new;

like $pi->cpu_percent, qr/^\d+\.\d+$/, "cpu_percent() method return ok";

done_testing();
