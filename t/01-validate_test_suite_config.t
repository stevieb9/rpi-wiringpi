# Checks all pins against a pre-defined set of defaults, and 
# resets them if any are out of check

use warnings;
use strict;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use Test::More;
use WiringPi::API;

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(
    label           => 't/01-validate_test_suite_config.t',
    shm_key         => 'rpit',
    rpi_register    => 0,
);

$pi->meta_erase;
my $meta = $pi->meta_fetch;
$pi->cleanup;

is keys %{ $meta }, 0, "meta data store has been reset ok";

my $pin_defaults = rpi_default_pin_config();
my $valid_pin_config = rpi_verify_pin_status();

warn "pin configuration is not valid, resetting..." if ! $valid_pin_config;

if (! $valid_pin_config){
    for my $pin (keys %$pin_defaults) {
        WiringPi::API::pinModeAlt($pin, $pin_defaults->{$pin}{alt});
        WiringPi::API::digitalWrite($pin, $pin_defaults->{$pin}{state});
    }
}

rpi_check_pin_status();

done_testing();
