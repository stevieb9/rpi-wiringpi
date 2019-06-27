#!/usr/bin/env perl

use warnings;
use strict;
use feature 'say';

use RPi::WiringPi;

my $pi = RPi::WiringPi->new;

my $dev = '/dev/ttyS0';
my $baud = 9600;

my $s = $pi->serial($dev, $baud);

while (1){
    my $cpu = int $pi->cpu_percent;
    my $mem = int $pi->mem_percent;
    my $tmp = int $pi->core_temp('f');

    $s->putc($cpu);
    $s->putc($mem);
    $s->putc($tmp);

    sleep 1;
}

$pi->cleanup;
