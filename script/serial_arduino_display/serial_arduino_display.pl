#!/usr/bin/env perl

use warnings;
use strict;
use feature 'say';

use IPC::Shareable;
use RPi::WiringPi;

tie my %shared_pi_info, 'IPC::Shareable', {
    key => 'rpiw',
    create => 1,
};

my $pi = RPi::WiringPi->new(label => 'serial_arduino_display');

my $dev = '/dev/ttyS0';
my $baud = 9600;

my $s = $pi->serial($dev, $baud);

while (1){
    my $cpu = int $pi->cpu_percent;
    my $mem = int $pi->mem_percent;
    my $tmp = int $pi->core_temp('f');
    my $test_num = int test_num();

    if (! defined $test_num || $test_num == -1){
        $test_num = 0; 
    } 
    
    $s->putc($cpu);
    $s->putc($mem);
    $s->putc($tmp);

    my $msb = int($test_num >> 8);
    my $lsb = int($test_num & 0xFF);

    #my $num = int($msb << 8 ) | int($lsb & 0xff);
    # print "cpu: $cpu, mem: $mem, temp: $tmp, msb: $msb, lsb: $lsb, num: $num test_num: $test_num\n";

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
