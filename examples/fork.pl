use strict;
use warnings;
use 5.010;

use Data::Dumper;
use RPi::WiringPi;

say "Process ID: $$";

my $pid = fork;


if ($pid) {
    my $pi_parent = RPi::WiringPi->new(label => 'PARENT');
    say "in parent $$, child $pid";
    $pi_parent->pin(12);

    say "parent: " . $pi_parent->label . "\n";
    print Dumper $pi_parent->metadata;
    #$pi_parent->clean_shared;
    #$pi_parent->cleanup;
} else {
    my $pi = RPi::WiringPi->new(label => 'CHILD');
    $pi->pin(18);

    say "child:" . $pi->label . "\n";;
    print Dumper $pi->metadata;
#    $pi->cleanup;
}

my $pid_w = wait();

say "$pid_w done";


