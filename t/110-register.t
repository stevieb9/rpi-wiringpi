use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use Test::More;

my $mod = 'RPi::WiringPi';

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

rpi_running_test(__FILE__);

my $pi = $mod->new(fatal_exit => 0);

my $pin26 = $pi->pin(26, 'test26');
my $pin12 = $pi->pin(12, 'test12');
my $pin18 = $pi->pin(18, 'test18');

my %pin_map = (
    26 => $pin26,
    12 => $pin12,
    18 => $pin18,
);

my $pins = $pi->registered_pins;

is @$pins, 3, "proper num of pins registered";

for (keys %pin_map){
    is $pin_map{$_}->num, $_, "\$pin$_ has proper num()";
    is $pin_map{$_}->comment, "test$_", "...and has proper comment";
}

$pi->cleanup;

is @{ $pi->registered_pins }, 0, "after cleanup, all pins unregistered";

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();

