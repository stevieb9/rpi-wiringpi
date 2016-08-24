use strict;
use warnings;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Test::More;

if (! $ENV{PI_BOARD}){
    warn "\n*** PI_BOARD is not set! ***\n";
    $ENV{NO_BOARD} = 1;
    plan skip_all => "not on a pi board\n";
}

{
    my $pi = RPi::WiringPi->new;
    is $pi->gpio_scheme, 'BCM', "default setup is setup(), pinmap is BCM";
    my $pin = $pi->pin(6);
    is $pin->num, 6, "pins exported properly";
}

done_testing();
