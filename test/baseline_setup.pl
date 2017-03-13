use warnings;
use strict;
use feature 'say';

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);

my ($dac_pin, $adc_pin) = (12, 26);

my $pi = RPi::WiringPi->new;

my $dac = $pi->dac(
    model => 'MCP4922',
    channel => 0,
    cs => 12
);

my $adc = $pi->adc(
    model => 'MCP3008',
    channel => 26
);

for (0..4095){
    $dac->set(0, $_);
    say $adc->raw(1);
}
