use warnings;
use strict;

use Time::HiRes qw(usleep);
use RPi::WiringPi;

my $continue = 1;
$SIG{INT} = sub { $continue = 0; };

use constant {
    LOW => 0,
    HIGH => 1,
    PWM => 2,
    IN => 0,
    OUT => 1,	
};

my $sleep = $ARGV[0] || 5000;

my $pi = RPi::WiringPi->new;

my $pin = $pi->pin(29);

$pin->mode(PWM);

my $count = 0;

while ($continue){
    for (0 .. 400){
        $pin->pwm($_);
        usleep $sleep;
        $count++;
    }    
    while ($count != 0){
        $pin->pwm($count);
        usleep $sleep;
        $count--; 
    }
}
$pi->unregister_pin($pin);
