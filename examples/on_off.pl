use warnings;
use strict;

use RPi::WiringPi;

use constant {
    LOW => 0,
    HIGH => 1,
    IN => 0,
    OUT => 1,	
};

my $pi = RPi::WiringPi->new;

my $pin = $pi->pin(5);

$pin->mode(OUT);
$pin->write(HIGH);

sleep 2;

$pi->unregister_pin($pin);
