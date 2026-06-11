use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

rpi_running_test(__FILE__);

my $mod = 'RPi::WiringPi';

# In-process interrupt callback counter (a file lexical, not an env var gate)

my $interrupts = 0;

sub handler {
    $interrupts++;
}

my $pi = $mod->new(
    label => 't/203-dispatch_interrupts.t',
    shm_key => 'rpit',
    shared => 0
);

# pin specific interrupts

my $pin = $pi->pin(18);

if (! $ENV{NO_BOARD}){

    # dispatch_interrupts() is non-blocking: it drains whatever the ISR thread
    # has already queued and fires the callbacks, with no wait_interrupts() in
    # the loop. Pre-fill a known number of rising edges, settle so the ISR
    # thread has written every record, then drain in a single call.

    my $edges = 3;

    $pin->set_interrupt(EDGE_RISING, \&handler);

    $pin->pull(PUD_DOWN);

    # trigger the interrupts (no wait_interrupts between them)

    for (1 .. $edges){
        $pin->pull(PUD_UP);
        select(undef, undef, undef, 0.02);
        $pin->pull(PUD_DOWN);
        select(undef, undef, undef, 0.02);
    }

    # let the ISR thread finish queuing every edge before we drain

    select(undef, undef, undef, 0.1);

    my $dispatched = $pi->dispatch_interrupts();

    is $dispatched, $edges, "dispatch_interrupts() returned $edges dispatched ok";
    is $interrupts, $edges,
        "callback fired $edges times without wait_interrupts ok";

    # nothing left pending - a second drain reports zero

    my $empty = $pi->dispatch_interrupts();

    is $empty, 0, "dispatch_interrupts() returns 0 when nothing pending ok";
    is $interrupts, $edges, "callback not re-fired on empty drain ok";
}

$pi->cleanup;

rpi_check_pin_status();

done_testing();
