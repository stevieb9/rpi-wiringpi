use strict;
use warnings;
use 5.010;

use Data::Dumper;
use RPi::WiringPi;

my $f = 'ready.multi';

my $pi = RPi::WiringPi->new;
#$pi->clean_shared;
#exit;
#print Dumper $pi->metadata;
#$pi->cleanup;
#print Dumper $pi->metadata;

$pi->pin(12);

print "*** Single pin: Local ***\n\n";
print Dumper $pi->metadata;

mywait();
unlink $f or die $!;

print "*** External script: First two pins ***\n\n";
print Dumper $pi->metadata;

mywait();
unlink $f or die $!;

print "*** External script: Second two pins ***\n\n";
print Dumper $pi->metadata;

sleep 2;

print "*** External script: Cleaned up ***\n\n";
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
