use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

## plan skip_all => "fatal_exit = 0 TESTS NEED TO BE FIXED";
#TODO: fatal_exit => 0 doesn't clean up pins

rpi_running_test(__FILE__);

my $mod = 'RPi::WiringPi';

rpi_multi_check();

my $meta;

my $pi_a = $mod->new(fatal_exit => 0, label => 't/154-sig_die_multi.t: pi_A', shm_key => 'rpit');
my $pi_b = $mod->new(fatal_exit => 0, label => 't/154-sig_die_multi.t: pi_B', shm_key => 'rpit');

my $pin_a = $pi_a->pin(21);
my $pin_b = $pi_b->pin(16);

$pin_a->mode(OUTPUT);
$pin_b->mode(OUTPUT);

is $pin_a->mode, OUTPUT, "pin_a set to OUTPUT";
is $pin_b->mode, OUTPUT, "pin_b set to OUTPUT";

is @{ $pi_a->registered_pins }, 2, "all pins registerd ok (pi_a)";
is @{ $pi_b->registered_pins }, 2, "all pins registerd ok (pi_b)";

is grep({$_ == 16} @{ $pi_a->registered_pins }), 1, "pin_a registered ok";
is grep({$_ == 21} @{ $pi_a->registered_pins }), 1, "pin_a registered ok";

eval { die "intentional die()"; };

is $pin_a->mode, INPUT, "pin reset to INPUT after die()";
is $pin_b->mode, INPUT, "pin reset to INPUT after die()";

is @{ $pi_a->registered_pins }, 0, "all pins unregisterd ok (pi_a)";
is @{ $pi_b->registered_pins }, 0, "all pins unregisterd ok (pi_b)";

$pi_a->meta_lock;
$meta = $pi_a->meta_fetch;
$pi_a->meta_unlock;

sleep 1;

is keys(%{ $meta->{pins} }), 0, "...and meta data shows this (pi_a)";
is keys(%{ $meta->{objects} }), rpi_legal_object_count(), "after die(), proper num of objects exist (pi_a)";
is $meta->{object_count}, rpi_legal_object_count(), "after die(), proper object count exist (pi_a)";

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
