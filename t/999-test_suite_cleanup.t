use warnings;
use strict;

warn "\n\nRunning 999!\n\n";

use lib 't/';

use RPiTest;
use Test::More;

rpi_running_test(__FILE__);

rpi_reset();

rpi_running_test(-1);

done_testing();
