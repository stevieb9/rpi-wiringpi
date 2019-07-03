use strict;
use warnings;
use 5.010;

use Data::Dumper;
use RPi::WiringPi;

say "Process ID: $$";

my $n = 1;
my $forks = 0;

for (1 .. $n) {
    my $pid = fork;

    if (not defined $pid) {
        warn 'Could not fork';
        next;
    }
    if ($pid) {
        $forks++;
        say "in parent $$, child $pid";
        my $pi = RPi::WiringPi->new(label => 'parent');
        $pi->pin(12);
        print Dumper $pi->metadata;

        say "Parent obj... label: " . $pi->label . "\n";
    } else {
        my $pi = RPi::WiringPi->new(label => 'child');
        sleep 2;
        say "Child obj... label:" . $pi->label . "\n";;
        exit;
    }
}

for (1 .. $forks) {
    my $pid = wait();
#    say "Parent saw $pid exiting";
}
#say "Parent ($$) ending";
