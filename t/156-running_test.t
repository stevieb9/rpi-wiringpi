use strict;
use warnings;

use lib 't/';

use IPC::Shareable;
use RPiTest;
use Test::More;

rpi_running_test(__FILE__);

tie my %shared_pi_info, 'IPC::Shareable', 'rpiw' or die $!;

is $shared_pi_info{testing}->{test_num}, 156, "running_test() stored the test file number ok";
is $shared_pi_info{testing}->{test_name}, 'running_test', "running_test() stored the test file name ok";

rpi_running_test(-1);

is $shared_pi_info{testing}->{test_num}, -1, "running_test() stored the negative test num ok";
is $shared_pi_info{testing}->{test_name}, '', "running_test() with negative num erases test name";

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();

