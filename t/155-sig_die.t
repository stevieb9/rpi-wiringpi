use strict;
use warnings;

use lib 't/';

use RPiTest qw(check_pin_status running_test);
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

running_test(__FILE__);

my $mod = 'RPi::WiringPi';

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

my $pi = $mod->new(fatal_exit => 0);
my $pin = $pi->pin(21);

$pin->mode(OUTPUT);

is $pin->mode, OUTPUT, "pin s set to OUTPUT";
is ${ $pi->registered_pins }[0], '21', "pin registered ok";

eval { die "intentional die()"; };

is $pin->mode, INPUT, "pin reset to INPUT after die()";

is @{ $pi->registered_pins }, 0, "all pins unregisterd ok";
is keys(%{ $pi->metadata->{pins} }), 0, "...and meta data shows this";

$pi->cleanup;

is keys(%{ $pi->metadata->{objects} }), 0, "after cleanup(), no more objects exist";

#check_pin_status();

done_testing();
