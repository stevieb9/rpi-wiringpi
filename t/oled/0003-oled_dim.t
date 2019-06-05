use strict;
use warnings;

use Test::More;

use RPi::OLED::SSD1306::128_64;

my $s = RPi::OLED::SSD1306::128_64->new;

is $s->rect(0, 0, 128, 64, 1), 1, "rect return ok";
$s->display;

is $s->dim(1), 1, "dim() return ok";

sleep 1;

$s->dim(0);

$s->clear;

done_testing();

