use warnings;
use strict;
use feature 'say';

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use Test::More;

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(label => 't/407-sysinfo_pi_details.t');

like $pi->pi_details, qr|Raspberry Pi|, "method includes data ok";
like $pi->pi_details, qr|BCM2835|, "method includes data ok";

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
