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

like $pi->core_temp, qr/^\d+\.\d+$/, "core_temp() method return ok";

my $tC = $pi->core_temp();
my $tF = $pi->core_temp('f');

is $tF > $tC, 1, "f and c temps ok";

done_testing();
