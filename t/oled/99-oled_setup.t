use strict;
use warnings;

use Test::More;
use RPi::WiringPi;

if (! $ENV{RPI_OLED}){
    plan skip_all => "RPI_OLED environment variable not set\n";
}

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

plan skip_all => "nothing to do here yet";

my $s = RPi::WiringPi->oled('128x64', 0x3C, 0);

done_testing();

