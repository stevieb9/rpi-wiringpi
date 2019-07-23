use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

my $mod = 'RPi::WiringPi';

if ($> == 0){
    $ENV{PI_BOARD} = 1;
}
if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

if ($> != 0){
    print "enforcing sudo for PWM tests...\n";
    system('sudo', 'perl', $0);
    exit;
}

rpi_running_test(__FILE__);

use constant {
    LEFT    => 60,
    RIGHT   => 255,
    CENTRE  => 150,
    PIN     => 18,
    DIVISOR => 192,
    RANGE   => 2000,
    DELAY   => 0.01,
    ANALOG  => 0,
    MAX_IN  => 40,
};


if (! $ENV{NO_BOARD}) {
    my $pi = $mod->new(label => 't/325-servo.t');

    my $adc = $pi->adc;

    my $servo = $pi->servo(18);
    my $o;

    $servo->pwm(LEFT);

    sleep 5;

    for (LEFT .. RIGHT){
        # sweep all the way left to right
        $servo->pwm($_);
        $o = $adc->percent(ANALOG);
        is $o >= -1, 1, "output ok on cycle $_ on right";
        is $o < MAX_IN, 1, "output ok on cycle $_ on right\n";
        select(undef, undef, undef, DELAY);
    }

    for (reverse LEFT .. RIGHT){
        # sweep all the way right to left
        $servo->pwm($_);
        $o = $adc->percent(ANALOG);
        is $o >= -1, 1, "output ok on cycle $_ on left";
        is $o < MAX_IN, 1, "output ok on cycle $_ on left\n";
        select(undef, undef, undef, DELAY);
    }

    $pi->cleanup;
    
    $o = $adc->percent(ANALOG);
    is $o < 1, 1, "PWM pin cleaned up ok";
    $o = $adc->percent(ANALOG);
    is $o < 1, 1, "PWM pin cleaned up ok";

    rpi_check_pin_status();

}

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
