use strict;
use warnings;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Test::More;

if (! @ARGV){
    warn "\n*** interactive test need arg ***\n\n";
    exit;
}

my $mod = 'RPi::WiringPi';

if (! $ENV{PI_BOARD}){
    warn "\n*** PI_BOARD is not set! ***\n";
    $ENV{NO_BOARD} = 1;
}

my $pi = $mod->new(fatal_exit => 0);

my $pin = $pi->pin(5);
$pin->mode(OUTPUT);

is $pi->registered_pins, 1, "pin registered ok";

print "\npress CTRL-^C\n\n";
sleep 10;

is $pin->mode, 0, "pin reset to INPUT after die()";

done_testing();
