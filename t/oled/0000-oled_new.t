use strict;
use warnings;

use Test::More;

use RPi::Const;
use RPi::WiringPi;

if (! $ENV{RPI_OLED}){
    plan skip_all => "RPI_OLED environment variable not set\n";
}

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

my $s = RPi::WiringPi->oled('128x64', 0x3C);

is ref $s, 'RPi::OLED::SSD1306::128_64', "oled() returns an object of proper class";

done_testing();

