use strict;
use warnings;
use 5.010;

use RPi::WiringPi;

my $pi= RPi::WiringPi->new;

my $p20 = $pi->pin(20, "twenty");

die("croaking intentionally to see if pin 20 is freed");
