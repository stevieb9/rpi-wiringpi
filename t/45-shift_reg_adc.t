use warnings;
use strict;
use feature 'say';

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Test::More;

my $adc_pin = 26;

my $pi = RPi::WiringPi->new;

my $adc = $pi->adc(
    model => 'MCP3008',
    channel => $adc_pin
);

my $sr = $pi->shift_register(400, 8, 21, 20, 16);

my $sr_pin;

$sr_pin = $pi->pin(400);

$sr_pin->write(LOW);

say $adc->percent(0);
ok $adc->percent(0) < 2, "SR pin 0 low ok";

$sr_pin->write(HIGH);
sleep 1;
print $adc->percent(0) . "\n";

ok $adc->percent(0) > 90, "SR pin 0 HIGH ok";

$sr_pin->write(LOW);


#$sr_pin->write(LOW);

$pi->cleanup;

done_testing();
