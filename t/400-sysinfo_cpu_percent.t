use warnings;
use strict;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use Test::More;

if (! $ENV{PI_BOARD}){
    plan skip_all => "Not on a Pi board";
}

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new;
like $pi->cpu_percent, qr/^\d+\.\d+$/, "cpu_percent() method return ok";

$pi->cleanup;

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();
