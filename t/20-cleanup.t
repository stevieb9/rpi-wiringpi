use strict;
use warnings;

use Data::Dumper;
use RPi::WiringPi;
use Test::More;

my $mod = 'RPi::WiringPi';

if (! $ENV{PI_BOARD}){
    warn "\n*** PI_BOARD is not set! ***\n";
    $ENV{NO_BOARD} = 1;
    plan skip_all => "not on a pi board\n";
}

my $pi = $mod->new;

{# register, unregister

    my $pin26 = $pi->pin(26);
    my $pin12 = $pi->pin(12);
    my $pin18 = $pi->pin(18);

    my @pins = $pi->registered_pins;

    my @pnums = qw(26 12 18);
    my $c = 0;

    for ($pin26, $pin12, $pin18){
        isa_ok $_, 'RPi::Pin';
        is $_->num, $pnums[$c], "pin $pnums[$c] has correct num";
        $c++;
    }

    $pi->unregister_pin($pin18);
    is $pi->registered_pins, '26,12', "unregistered pin ok";

    $pi->register_pin($pin18);
    is $pi->registered_pins, '26,12,18', "registered pin ok";
 
    $pi->cleanup;

    is $pi->registered_pins, undef, "cleanup() ok";
}

$pi->cleanup;

done_testing();
