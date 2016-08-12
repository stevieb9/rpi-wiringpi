#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;
use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);

my $pi = RPi::WiringPi->new;
$pi->setup;

my $lcd = $pi->lcd;

my %args = (
    cols => 16,
    rows => 2,
    bits => 4,
    rs => 6,
    strb => 5,
    d0 => 4,
    d1 => 2, 
    d2 => 1, 
    d3 => 3,
    d4 => 0,
    d5 => 0, 
    d6 => 0, 
    d7 => 0,
);

$lcd->init(%args);

#$lcd->cursor(0);
#$lcd->cursor_blink(0);

$lcd->position(0, 0);
$lcd->print("stevieb");

my $continue = 1;
$SIG{INT} = sub { $continue = 0; };

while ($continue){
    $lcd->position(0, 1);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

    if ($min % 2 = 0){
        $lcd->print("  beer time!");
    }
    else {
        $lcd->print("$hour:$min");
    }
    sleep 1;
}
$lcd->clear;
