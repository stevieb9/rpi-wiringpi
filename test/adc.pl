use warnings;
use strict;

use constant PWM_MAX => 1023;

use RPi::WiringPi::Constant qw(:all);
use RPi::WiringPi;

my $pi = RPi::WiringPi->new;

my $adc     = $pi->adc;
my $led_pin = $pi->pin(18);

$led_pin->mode(PWM_OUT);

for (0..PWM_MAX){
    next if $_ % 100 != 1;

    $led_pin->pwm($_);
    my $input = $adc->percent(0);
    
    print "pin ". $led_pin->num ." is at $input % output capacity\n";
    
    select(undef, undef, undef, 0.3);
}

$pi->cleanup;
