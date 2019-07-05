use warnings;
use strict;
use feature 'say';

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use Test::More;

if (! $ENV{PI_BOARD}){
    plan skip_all => "Not on a Pi board";
}

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new;

like $pi->file_system, qr|/dev/root|, "method includes root ok";
like $pi->file_system, qr|/var/swap|, "method includes swap ok";

$pi->cleanup;

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();
