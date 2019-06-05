use strict;
use warnings;

use Test::More;

use RPi::WiringPi;

my $s = RPi::WiringPi->oled;

for (1..5) {
    $s->clear;
    my $size_r = $s->text_size($_);
    is $size_r, 1, "return from text_size($_) ok";
    my $string_r = $s->string("hello", 1);
    is $string_r, 1, "return from string() ok";

}
$s->clear;

done_testing();

