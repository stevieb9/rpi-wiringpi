#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Data::Dumper;
use RPi::WiringPi;

if (! $ARGV[0] || $ARGV[0] !~ /[01]/){
    print "\nUsage: metadata <clean> (clean == 0|1)\n\n";
}

my $pi = RPi::WiringPi->new;

print Dumper $pi->metadata;

$pi->clean_shared if $ARGV[0];
$pi->cleanup;
