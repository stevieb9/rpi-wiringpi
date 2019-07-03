use warnings;
use strict;

use lib 't/';

use Data::Dumper;
use RPiTest qw(check_pin_status running_test);
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

$SIG{__DIE__} = sub {
    like shift, qr/Maximum number of LCD/, "initializing too many LCDs error ok";
};

if (! $ENV{RPI_LCD}){
    plan skip_all => "RPI_LCD environment variable not set\n";
}

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

running_test(__FILE__);

my $continue = 1;
$SIG{INT} = sub { $continue = 0; };

my $pi = RPi::WiringPi->new;

my %args = (
    cols => 20,
    rows => 4,
    bits => 4,
    rs => 5,
    strb => 6,
    d0 => 4,
    d1 => 17,
    d2 => 27,
    d3 => 22,
    d4 => 0,
    d5 => 0, 
    d6 => 0, 
    d7 => 0,
);

print "BEFORE lcd():\n";
print Dumper $pi->metadata;

my $lcd = $pi->lcd(%args);

print "AFTER lcd():\n";
print Dumper $pi->metadata;

$lcd->position(0, 0);
$lcd->print("hello, world!"); 

$lcd->position(0, 1);
$lcd->print("line two!");

sleep 2;

$lcd->clear;

is 1, 1, "ok";

my $ok = eval {
    while (1){
        $lcd->init(%args);
        $lcd->position(0, 0);
    }
    1;
};
print "AFTER init():\n";
print Dumper $pi->metadata;

is $ok, undef, "initializing too many LCD objects dies ok";

$lcd->position(0, 0);
$lcd->print("Testing in progress");
$pi->cleanup;

check_pin_status();

running_test(-1);

print "AFTER cleanup():\n";
print Dumper $pi->metadata;

done_testing();
