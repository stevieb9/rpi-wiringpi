use strict;
use warnings;

use Test::More;
use RPi::WiringPi;

my $s = RPi::WiringPi->oled;

for (1..5) {

    $s->clear;
    my $x = $_ * 2;
    my $y = $_ * 2;

    is $s->char($x, $y, 5, $_), 1, "char() return ok";
    $s->display;
}

for (1..10) {

    $s->clear;
    my $x = 50;
    my $y = 15;

    $s->char($x, $y, $_, 4);
    $s->display;
}
#$s->clear;

done_testing();

