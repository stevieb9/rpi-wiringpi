use warnings;
use strict;

use Data::Dumper;
use WiringPi::API qw(:all);

my %args = (
    cols => 16,
    rows => 2,
    bits => 4,
    rs => 23,
    strb => 16,
    d0 => 5,
    d1 => 6,
    d2 => 13, 
    d3 => 19,
    d4 => 0,
    d5 => 0, 
    d6 => 0, 
    d7 => 0,
);

my $fd = lcd_init(%args);

lcd_position($fd, 0, 0);

my $def = [0x0,0xa,0x15,0x11,0xa,0x4,0x0];

lcd_char_def($fd, 0, $def);
lcd_put_char($fd, 0, 0);

sleep 3;
lcd_clear($fd);
