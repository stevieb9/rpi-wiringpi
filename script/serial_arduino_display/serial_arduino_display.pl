#!/usr/bin/env perl

use warnings;
use strict;
use feature 'say';

use IPC::Shareable;
use RPi::WiringPi;

tie my %shared_pi_info, 'IPC::Shareable', {
    key => 'ripw',
    create => 1,
};

my $pi = RPi::WiringPi->new(label => 'serial_arduino_display');

my $dev = '/dev/ttyS0';
my $baud = 115200;

my $s = $pi->serial($dev, $baud);

while (1){
    my $cpu = int $pi->cpu_percent;
    my $mem = int $pi->mem_percent;
    my $tmp = int $pi->core_temp('f');
    my $test_num = int test_num();

    $s->putc($cpu);
    $s->putc($mem);
    $s->putc($tmp);

    my $msb = $test_num >> 8;
    my $lsb = $test_num & 0xFF;

    $s->putc(int $msb);
    $s->putc(int $lsb);

    sleep 1;
}

sub test_num {
    my $test_num = $shared_pi_info{testing}->{test_num};

    if (defined $test_num && $test_num > 0){
        return $shared_pi_info{testing}->{test_num};
    }
    else {
        return -1;
    }
}

$pi->cleanup;
