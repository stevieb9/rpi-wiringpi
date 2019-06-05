use strict;
use warnings;

use Test::More;

use RPi::OLED::SSD1306::128_64;

my $s = RPi::OLED::SSD1306::128_64->new;

# full screen

is $s->rect(0, 0, 128, 64, 1), 1, "rect return ok";
$s->display;

# one pixel border

$s->rect(1, 1, 126, 62, 0);
$s->display;

is $s->rect(0, 0, 128, 64, 1), 1, "rect return ok";
$s->display;

$s->rect(20, 10, 88, 44, 0);
$s->display;

$s->clear;

done_testing();

