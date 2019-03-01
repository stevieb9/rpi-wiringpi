use warnings;
use strict;

use 5.10.0;

use RPi::WiringPi;
use RPi::Const qw(:all);

use constant {
    DPOT_CS => 23,
    DPOT_CH => 0,
    BMP_BASE => 100,
};

my $pi = RPi::WiringPi->new;

my $adc = $pi->adc;
my $pot = $pi->dpot(DPOT_CS, DPOT_CH);
my $bmp = $pi->bmp(BMP_BASE);

my $pwm_pin = $pi->pin(18);
$pwm_pin->mode(PWM_OUT);

for (0..255){
    $pot->set($_);
    $pwm_pin->pwm($_);

    say "pot set to $_: " . $adc->percent(3);
    say "pwm set to $_: " . $adc->percent(0);
    say "temp C         " . $bmp->temp('c');
    say "bmp            " . $bmp->pressure;
    print "\n";
}
