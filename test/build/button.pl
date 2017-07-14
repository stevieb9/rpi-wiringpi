use warnings;
use strict;
use feature 'say';

use RPi::WiringPi;
use RPi::Const qw(:all);

my $c = 1;
$SIG{INT} = sub {$c = 0;};

my $pi = RPi::WiringPi->new;

my $pin = $pi->pin(1);

$pin->mode(INPUT);
$pin->interrupt_set(EDGE_FALLING, 'handler');

$pin->pull(2);

while ($c){
    say $pin->read;
    sleep 1;
}    

sub handler {
    print "button pressed!\n";
}

$pi->cleanup;
