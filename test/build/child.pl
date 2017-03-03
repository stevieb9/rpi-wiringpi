use warnings;
use strict;

use lib '.';
use lib 'test/build';

use Child;

my $continue = 1;
$SIG{INT} = sub { $continue = 0; };

my $lcd = Child->new(setup => 'gpio');

$lcd->setup_gpio;

my %args = (
    cols => 16,
    rows => 2,
    bits => 4,
    rs => 23,
    strb => 16,
    d0 => 5,
    d1 => 6,
    d2 => 13, 
    d3 => 19,
    d4 => 0,
    d5 => 0, 
    d6 => 0, 
    d7 => 0,
);

$lcd->init(%args);

$lcd->position(0, 0);
$lcd->print("stevieb");

$lcd->blah;

while ($continue){
    $lcd->position(0, 1);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    $lcd->print("$hour:$min");
    sleep 1;
}

$lcd->clear;
