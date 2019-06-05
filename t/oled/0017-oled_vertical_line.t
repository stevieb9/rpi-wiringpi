use strict;
use warnings;

use Test::More;
use RPi::WiringPi;

my $s = RPi::WiringPi->oled;

is $s->vertical_line(64, 0, 64), 1, "vertical_line() return ok";
$s->display;

$s->clear;

done_testing();

