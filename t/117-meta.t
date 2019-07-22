use strict;
use warnings;

use lib 't/';

use Data::Dumper;
use RPiTest;
use RPi::WiringPi;
use Test::More;
use feature 'say';

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

rpi_running_test(__FILE__);

my $mod = 'RPi::WiringPi';

my $pi= $mod->new(label => 't/117-meta.t');

$pi->cleanup;

#rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();

