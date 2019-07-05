use strict;
use warnings;
use 5.010;

use Data::Dumper;
use RPi::WiringPi;

my $f = 'ready.multi';

my $pi = RPi::WiringPi->new;

$pi->pin(12);

print "*** Single pin: Local & Remote ***\n\n";
print Dumper $pi->metadata;

mywait();
unlink $f or die $!;

sleep 1;

print "*** External script: died() ***\n\n";
print Dumper $pi->metadata;

$pi->cleanup;

print "*** Local: Cleaned up ***\n\n";
print Dumper $pi->metadata;

sub mywait {
    while (1){
        last if -e $f;
        select(undef, undef, undef, 0.2);
    }
}
