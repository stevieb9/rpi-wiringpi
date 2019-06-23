#!/usr/bin/env perl

use warnings;
use strict;
use feature 'say';

use RPi::WiringPi;

use constant {
    PROCESS_SYSINFO => 35
};

my $pi = RPi::WiringPi->new;

my $arduino = $pi->i2c(0x05);

while (1){
    my $result = $arduino->write_block(
        [
            int $pi->cpu_percent,
            int $pi->mem_percent,
            int $pi->core_temp('f'),
        ], 
        35
    );

    sleep 1;
}

$pi->cleanup;

