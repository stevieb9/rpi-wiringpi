use strict;
use warnings;

use Test::More;

use RPi::OLED::SSD1306::128_64;

my $s = RPi::OLED::SSD1306::128_64->new;

is $s->vertical_line(64, 0, 64), 1, "vertical_line() return ok";
$s->display;

$s->clear;

done_testing();

