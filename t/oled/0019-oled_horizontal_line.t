use strict;
use warnings;

use Test::More;
use RPi::WiringPi;

my $s = RPi::WiringPi->oled;

is $s->horizontal_line(0, 32, 128), 1, "horizontal_line() return ok";
$s->display;

$s->clear;

done_testing();

