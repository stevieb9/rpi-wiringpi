#!/usr/bin/env perl

use warnings;
use strict;
use feature 'say';

use IPC::Shareable;
use RPi::WiringPi;

tie my %shared_testinfo, 'IPC::Shareable', {
    key => 'test',
    create => 1,
};

my $pi = RPi::WiringPi->new;

my $dev = '/dev/ttyS0';
my $baud = 9600;

my $s = $pi->serial($dev, $baud);

my $test_num = -1;

while (1){
    my $cpu = int $pi->cpu_percent;
    my $mem = int $pi->mem_percent;
    my $tmp = int $pi->core_temp('f');
    my $test_num = int test_num();

    $s->putc($cpu);
    $s->putc($mem);
    $s->putc($tmp);

#    $s->putc($test_num);
# for the above, we're going to have to separate the test number into two bytes
# and then merge them at the arduino end

# will also need to test sending -1 to the arduino

    sleep 1;
}

sub test_num {
    if ($shared_testinfo{test_num} > 0){
        return $shared_testinfo{test_num};
    }
    else {
        return -1;
    }
}

$pi->cleanup;
