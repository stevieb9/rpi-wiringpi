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
    plan skip_all => "not on a pi board\n";
}

my $pi = $mod->new;

# interrupt module

if (! $ENV{NO_BOARD}){

    my $int = RPi::WiringPi::Interrupt->new;
    $int->set(27, EDGE_RISING, 'handler');

    my $pin = $pi->pin(27);
    $pin->pull(PUD_DOWN);

    # trigger the interrupt

    $pin->pull(PUD_UP);

    # turn the edge down

    $pin->pull(PUD_DOWN);
}

# pin specific interrupts

if (! $ENV{NO_BOARD}){

    my $pin = $pi->pin(27);

    $pin->interrupt_set(EDGE_RISING, 'handler');

    $pin->pull(PUD_DOWN);

    # trigger the interrupt

    $pin->pull(PUD_UP);

    # turn the edge down

    $pin->pull(PUD_DOWN);
}

# interrupt via main module

if (! $ENV{NO_BOARD}){

    my $int = RPi::WiringPi->interrupt(27, EDGE_RISING, 'handler');

    my $pin = $pi->pin(27);
    $pin->pull(PUD_DOWN);

    # trigger the interrupt

    $pin->pull(PUD_UP);

    # turn the edge down

    $pin->pull(PUD_DOWN);
}

sub handler {
    print "in handler\n";
}

done_testing();
