use strict;
use warnings;

use lib 't/';

use RPiTest qw(check_pin_status);
use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Test::More;

my $mod = 'RPi::WiringPi';

if ($> == 0){
    $ENV{PI_BOARD} = 1;
}

if (! $ENV{PI_BOARD}){
    warn "\n*** PI_BOARD is not set! ***\n";
    $ENV{NO_BOARD} = 1;
    plan skip_all => "not on a pi board\n";
    exit;
}

if ($> != 0){
    print "enforcing sudo for PWM tests...\n";
    system('sudo', 'perl', $0);
    exit;
}

use constant {
    LEFT    => 60,
    RIGHT   => 255,
    CENTRE  => 150,
    PIN     => 18,
    DIVISOR => 192,
    RANGE   => 2000,
    DELAY   => 0.01,
    ANALOG  => 3,
    MAX_IN  => 0.32,
};

my $pi = $mod->new;

my $adc_pin = 26;

my $adc = $pi->adc(
    model => 'MCP3008',
    channel => $adc_pin
);

if (! $ENV{NO_BOARD}) {

    my $pin = $pi->pin(PIN);
    my $o; # analog input

    $o = $adc->percent(ANALOG);

    # double-check; same when we exit

    is $o, '0.00', "before PWM hackery, output ok";
    sleep 1;
    is $o, '0.00', "before PWM hackery, output ok";

    $pin->mode(PWM_OUT);

    $pi->pwm_mode(PWM_MODE_MS);
    $pi->pwm_clock(DIVISOR);
    $pi->pwm_range(RANGE);

    $pin->pwm(LEFT);


    sleep 1;

    for (LEFT .. RIGHT){
        # sweep all the way left to right
        $pin->pwm($_);
        $o = $adc->percent(ANALOG);
        print "* $o\n";
        is $o >= 0 && $o < MAX_IN, 1, "output ok on cycle $_\n";
        select(undef, undef, undef, DELAY);
    }

    sleep 1;

    for (reverse LEFT .. RIGHT){
        # sweep all the way right to left
        $pin->pwm($_);
        $o = $adc->percent(ANALOG);
        is $o >= 0 && $o < MAX_IN, 1, "output ok on cycle $_\n";
        select(undef, undef, undef, DELAY);
    }

    sleep 1;

    $pi->pwm_mode(PWM_MODE_BAL);
    $pi->pwm_clock(32);
    $pi->pwm_range(1023);
    $pin->mode(INPUT); 

    sleep 1;

    # let's double-check

    $o = $adc->percent(ANALOG);
    is $o, '0.00', "PWM pin cleaned up ok";
    sleep 1;
    $o = $adc->percent(ANALOG);
    is $o, '0.00', "PWM pin cleaned up ok";
}

check_pin_status();

$pi->cleanup;

done_testing();
