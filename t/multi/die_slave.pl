use strict;
use warnings;
use 5.010;

use Data::Dumper;
use File::Touch qw(touch);
use RPi::WiringPi;

my $f = 'ready.multi';

my $pi= RPi::WiringPi->new;

my $p18 = $pi->pin(18, "eighteen");

touch $f or die $!;
mywait();

die();

$pi->cleanup;

sub mywait {
    while (1){
        last if ! -e $f;
        select(undef, undef, undef, 0.2);
    }
}


