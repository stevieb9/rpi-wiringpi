#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;
use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);

my $continue = 1;
$SIG{INT} = sub { $continue = 0; };

my $pi = RPi::WiringPi->new(setup => 'gpio');

my $lcd = $pi->lcd;

my %args = (
    cols => 16,
    rows => 2,
    bits => 4,
    rs => 27,
    strb => 26,
    d0 => 11,
    d1 => 12, 
    d2 => 13, 
    d3 => 14,
    d4 => 0,
    d5 => 0, 
    d6 => 0, 
    d7 => 0,
);

$lcd->init(%args);

$lcd->position(0, 0);
$lcd->print("stevieb");

my $pin = $pi->pin(9);

while ($continue){
    $pin->mode(OUTPUT);
    $pin->write(HIGH);
    $lcd->position(0, 1);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

    $lcd->print("$hour:$min");
    sleep 1;
    $pin->write(LOW); 
    sleep 1;
}
$lcd->clear;
