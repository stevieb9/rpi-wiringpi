use warnings;
use strict;
use feature 'say';

use RPi::WiringPi;

my $pi = RPi::WiringPi->new;

my $pin_base = 300;

my $bmp = $pi->bmp180($pin_base);

say $bmp->temp;
say $bmp->pressure;
