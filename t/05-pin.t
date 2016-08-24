use strict;
use warnings;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Test::More;

my $mod = 'RPi::WiringPi';

if (! $ENV{PI_BOARD}){
    warn "\n*** PI_BOARD is not set! ***\n";
    $ENV{NO_BOARD} = 1;
    plan skip_all => "not on a pi board\n";
}

my $pi = $mod->new;

{# pin

    my $pin = $pi->pin(5);
    $pin->mode(1);

    is $pin->read, 0, "pin status is LOW by default";


    if (! $ENV{NO_BOARD}){

        $pin->write(1);
        
        is $pin->read, 1, "pin status HIGH after write(1)";

        $pin->write(0);
        
        is $pin->read, 0, "pin status back to LOW after write(0)";
       
        $pin->mode(0);
    }
}

done_testing();
