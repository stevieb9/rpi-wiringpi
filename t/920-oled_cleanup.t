use strict;
use warnings;

use lib 't/';

use RPiTest qw(check_pin_status oled_available oled_unavailable);
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

is oled_available(1), 1, "oled still unavailable for use";
is oled_unavailable(), 1, "oled lock removed, it's now available";

done_testing();

