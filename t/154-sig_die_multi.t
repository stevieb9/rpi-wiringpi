use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

rpi_running_test(__FILE__);

my $mod = 'RPi::WiringPi';

if (! $ENV{RPI_MULTI}){
    plan skip_all => "RPI_MULTI environment variable not set\n";
}

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

my $pi_a = $mod->new(fatal_exit => 0, label => 't/154-sig_die_multi.t: pi_A');
my $pi_b = $mod->new(fatal_exit => 0, label => 't/154-sig_die_multi.t: pi_B');

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
is keys(%{ $pi_a->metadata->{pins} }), 0, "...and meta data shows this (pi_a)";
is keys(%{ $pi_b->metadata->{pins} }), 0, "...and meta data shows this (pi_b)";

is keys(%{ $pi_a->metadata->{objects} }), 0, "after die(), no more objects exist (pi_a)";
is keys(%{ $pi_b->metadata->{objects} }), 0, "after die(), no more objects exist (pi_b)";

is exists $pi_a->_signal_handlers->{__DIE__}{$pi_a->uuid}, 1, "pi_a sig handlers still exist if ! fatal_exit";
is exists $pi_b->_signal_handlers->{__DIE__}{$pi_b->uuid}, 1, "pi_b sig handlers still exist if ! fatal_exit";

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();
