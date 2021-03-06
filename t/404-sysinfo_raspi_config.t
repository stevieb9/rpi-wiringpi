use warnings;
use strict;
use feature 'say';

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use Test::More;

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(label => 't/404-sysinfo_raspi_config.t', shm_key => 'rpit');

like $pi->raspi_config, qr/core_freq/, "method includes data ok";

like
    $pi->raspi_config,
    qr/dtoverlay=pi3-disable-bt-overlay/,
    "...and custom changes are included";

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
