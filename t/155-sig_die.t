use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

plan skip_all => "fatal_exit = 0 TESTS NEED TO BE FIXED";
#TODO: fatal_exit => 0 doesn't clean up pins

rpi_running_test(__FILE__);

my $mod = 'RPi::WiringPi';

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

my $pi = $mod->new(fatal_exit => 0, label => 't/155-sig_die.t');
my $pin = $pi->pin(21);
my $meta;

$pin->mode(OUTPUT);

is $pin->mode, OUTPUT, "pin s set to OUTPUT";
is ${ $pi->registered_pins }[0], '21', "pin registered ok";

eval { die "intentional die()"; };

is $pin->mode, INPUT, "pin reset to INPUT after die()";

is @{ $pi->registered_pins }, 0, "all pins unregisterd ok";

$pi->meta_lock;
$meta = $pi->meta_fetch;
$pi->meta_unlock;

is keys(%{ $meta->{pins} }), 0, "...and meta data shows this";

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
