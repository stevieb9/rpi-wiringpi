use strict;
use warnings;

use lib 't/';

use IPC::Shareable;
use RPiTest;
use Test::More;

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(label => 't/04-shm_key.t', shm_key => 'rpit');

is $pi->meta_key, 0x74697072, "meta key successfully accepted in object instantiation";

$pi->cleanup;

#rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();

