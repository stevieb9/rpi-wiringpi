use strict;
use warnings;

use Data::Dumper;
use RPi::WiringPi;
use Test::More;

my $mod = 'RPi::WiringPi';

if (! $ENV{PI_BOARD}){
    warn "\n*** PI_BOARD is not set! ***\n";
    $ENV{NO_BOARD} = 1;
}

my $pi = $mod->new;

{# pwm

    ok 1, "ok";

    if (! $ENV{NO_BOARD}) {
        my $pin = $pi->pin(1);
        $pin->mode(2);
        is $pin->mode, 2, "pin mode set to PWM ok, and we can read it";

        $pin->pwm(200);
        ok 1, "after mode() set to PWM, pwm() ok";

        $pi->unregister_pin($pin);
    }
}

done_testing();
