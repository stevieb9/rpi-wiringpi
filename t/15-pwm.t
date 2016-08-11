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

    my $pin = $pi->pin(1);
    
    my $ok = eval { $pin->pwm(75); 1; };
    ok ! $ok, "pwm() can't be set if mode() isn't PWM (2)";

    $pin->mode(2);
    is $pin->mode, 2, "pin mode set to PWM ok, and we can read it";

    $ok = eval { $pin->pwm(200); 1; };
    is $ok, 1, "after mode() set to PWM, pwm() ok";

    $pi->unregister_pin($pin);

}

done_testing();
