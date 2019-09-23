use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

rpi_running_test(__FILE__);

my $mod = 'RPi::WiringPi';

BEGIN {
    my $c;

    sub handler {
        $c++;
        $ENV{PI_INTERRUPT} = $c;
    }
}

my $pi = $mod->new(
    label => 't/201-interrupt_falling_and_pud.t',
    shared => 0,
    shm_key => 'rpit'
);

# pin specific interrupts

my $pin = $pi->pin(18);

if (! $ENV{NO_BOARD}){

    # EDGE_FALLING

    $pin->set_interrupt(EDGE_FALLING, 'main::handler');

    $pin->pull(PUD_UP);

    # trigger the interrupt

    $pin->pull(PUD_DOWN);
    $pin->pull(PUD_UP);

    is $ENV{PI_INTERRUPT}, 1, "1st interrupt ok";

    # trigger the interrupt

    $pin->pull(PUD_DOWN);
    $pin->pull(PUD_UP);
    
    is $ENV{PI_INTERRUPT}, 2, "2nd interrupt ok";

    # trigger the interrupt

    $pin->pull(PUD_DOWN);
    $pin->pull(PUD_UP);
    
    is $ENV{PI_INTERRUPT}, 3, "3rd interrupt ok";
    
    $pin->pull(PUD_DOWN);
}

$pi->cleanup;

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();
