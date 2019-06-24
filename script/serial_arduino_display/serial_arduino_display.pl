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
    $s->putc(int $pi->cpu_percent);
    $s->putc(int $pi->mem_percent);
    $s->putc(int $pi->core_temp('f'));

    sleep 1;
}

$pi->cleanup;

