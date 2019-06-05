use strict;
use warnings;

use Test::More;
use RPi::WiringPi;

my $s = RPi::WiringPi->oled;

is $s->rect(0, 0, 128, 64, 1), 1, "rect return ok";
$s->display;

is $s->dim(1), 1, "dim() return ok";

sleep 1;

$s->dim(0);

$s->clear;

done_testing();

