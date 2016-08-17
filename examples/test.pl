use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Time::HiRes qw(usleep);

die "pin num~\n" if ! @ARGV;

my $pi = RPi::WiringPi->new(setup => 'gpio');

my $pin = $pi->pin($ARGV[0]);

$pin->mode(OUTPUT);
$pin->write(HIGH);

sleep 1;

$pin->write(LOW);
$pin->mode(INPUT);

#$pi->cleanup;
