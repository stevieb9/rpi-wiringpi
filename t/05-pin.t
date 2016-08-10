use strict;
use warnings;

use Data::Dumper;
use RPi::WiringPi;
use Test::More;

my $mod = 'RPi::WiringPi';
my $pi = $mod->new;

{# pin

    my $pin = $pi->pin(5);
    $pin->mode(1);

    is $pin->read, 0, "pin status is LOW by default";

    $pin->write(1);
    
    is $pin->read, 1, "pin status HIGH after write(1)";

    $pin->write(0);
    
    is $pin->read, 0, "pin status back to LOW after write(0)";
   
    $pin->mode(0);
}

done_testing();
