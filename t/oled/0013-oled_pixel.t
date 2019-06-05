use strict;
use warnings;

use Test::More;
use RPi::WiringPi;

my $s = RPi::WiringPi->oled;

for (1..5){
    my $x = int(rand(128));
    my $y = int(rand(64));

    print "$x, $y\n";
    is $s->pixel($x, $y, 1), 1, "pixel() return ok";
    $s->display;
}

for (1..100){
    my $x = int(rand(128));
    my $y = int(rand(64));

    print "$x, $y\n";
    $s->pixel($x, $y, 1);
}

$s->display;

$s->clear;

done_testing();

