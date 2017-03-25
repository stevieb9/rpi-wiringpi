use warnings;
use strict;
use feature 'say';

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use WiringPi::API qw(:all);

my ($dac_cs_pin, $adc_cs_pin) = (12, 26);
my $adc_shiftreg_in = 0;
my $adc_dac_in = 1;

my $pi = RPi::WiringPi->new;

my $dac = $pi->dac(
    model => 'MCP4922',
    channel => 0,
    cs => $dac_cs_pin
);

my $adc = $pi->adc(
    model => 'MCP3008',
    channel => $adc_cs_pin
);

print "DAC...\n\n";

for (0..4095){
    $dac->set(0, $_);
    if ($_ % 1000 == 0 || $_ == 4095){
        say $adc->percent($adc_dac_in);
    }
}

my $sr = $pi->shift_register(100, 8, 21, 20, 16);

print "\nShift Resgister...\n\n";

my $sr_pin = $pi->pin(100);

$sr_pin->write(1);
say $adc->percent($adc_shiftreg_in);

$sr_pin->write(0);
say $adc->percent($adc_shiftreg_in);

$sr_pin->write(1);
say $adc->percent($adc_shiftreg_in);

$sr_pin->write(0);

say $adc->percent($adc_shiftreg_in);

#$pi->cleanup;
