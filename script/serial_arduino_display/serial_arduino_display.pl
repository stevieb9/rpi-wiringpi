#!/usr/bin/env perl

use warnings;
use strict;
use feature 'say';

use RPi::WiringPi;

my $pi = RPi::WiringPi->new;

my $dev = '/dev/ttyS0';
my $baud = 9600;

my $s = $pi->serial($dev, $baud);

my $test_num = -1;

while (1){
    my $cpu = int $pi->cpu_percent;
    my $mem = int $pi->mem_percent;
    my $tmp = int $pi->core_temp('f');

    $s->putc($cpu);
    $s->putc($mem);
    $s->putc($tmp);
    $s->putc($test_num);

    sleep 1;
}

sub test_num {
    my $test_num_file = '/tmp/running_test.rpi-wiringpi';

    my $fh_ok = eval {
        open my $fh, '<', $test_num_file or die $!;
        1;
    };

    if ($fh_ok){
        $test_num = <$fh>;
        close $fh;
    }
    else {
        $test_num = -1;
    }

#    print "**********$test_num**************\n";
    return $test_num;
}

$pi->cleanup;
