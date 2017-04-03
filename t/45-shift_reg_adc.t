use warnings;
use strict;

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

$sr_pin = $pi->pin(401);

$sr_pin->write(LOW);
#print $adc->percent(2) . "\n\n";
ok $adc->percent(2) < 2, "SR pin 1 low ok";


$sr_pin->write(HIGH);
#print $adc->percent(2) . "\n\n";
ok $adc->percent(2) > 90, "SR pin 1 HIGH ok";

$sr_pin->write(LOW);
#print $adc->percent(2) . "\n\n";
ok $adc->percent(2) < 2, "SR pin 1 low ok";

$sr_pin->write(LOW);
#print $adc->percent(2) . "\n\n";
ok $adc->percent(2) < 2, "SR pin 1 low ok";


$sr_pin->write(HIGH);
#print $adc->percent(2) . "\n\n";
ok $adc->percent(2) > 90, "SR pin 1 HIGH ok";

$sr_pin->write(LOW);
#print $adc->percent(2) . "\n\n";
ok $adc->percent(2) < 2, "SR pin 1 low ok";

$pi->cleanup;

done_testing();
