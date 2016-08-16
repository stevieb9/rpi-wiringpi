use strict;
use warnings;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use RPi::WiringPi::Interrupt;
use Test::More;

my $mod = 'RPi::WiringPi';

if (! $ENV{PI_BOARD}){
    warn "\n*** PI_BOARD is not set! ***\n";
    $ENV{NO_BOARD} = 1;
}

my $pi = $mod->new;

# interrupt module

if (! $ENV{NO_BOARD}){

    my $int = RPi::WiringPi::Interrupt->new;
    $int->set(27, EDGE_RISING, 'handler');

    my $pin = $pi->pin(27);
    $pin->pull(DOWN);

    # trigger the interrupt

    $pin->pull(UP);

    # turn the edge down

    $pin->pull(DOWN);
}

# pin specific interrupts

if (! $ENV{NO_BOARD}){

    my $pin = $pi->pin(27);

    $pin->interrupt_set(EDGE_RISING, 'handler');

    $pin->pull(DOWN);

    # trigger the interrupt

    $pin->pull(UP);

    # turn the edge down

    $pin->pull(DOWN);
}

# interrupt via main module

if (! $ENV{NO_BOARD}){

    my $int = RPi::WiringPi->interrupt(27, EDGE_RISING, 'handler');

    my $pin = $pi->pin(27);
    $pin->pull(DOWN);

    # trigger the interrupt

    $pin->pull(UP);

    # turn the edge down

    $pin->pull(DOWN);
}

sub handler {
    print "in handler\n";
}

done_testing();
