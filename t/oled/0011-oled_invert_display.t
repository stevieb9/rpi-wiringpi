use strict;
use warnings;

use Test::More;

use RPi::OLED::SSD1306::128_64;

my $s = RPi::OLED::SSD1306::128_64->new;

$s->text_size(3);
$s->string("hello", 1);

is $s->invert_display(1), 1, "invert_display() return ok";
$s->clear;

$s->string("hello", 1);

$s->invert_display(0);
$s->clear;

done_testing();

