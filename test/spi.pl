use warnings;
use strict;

use RPi::WiringPi;

my $pi = RPi::WiringPi->new;

my $spi = $pi->spi(0);

my $buf = [0x01, 0x02];
my $len = scalar @$buf;

$spi->rw($buf, $len);
