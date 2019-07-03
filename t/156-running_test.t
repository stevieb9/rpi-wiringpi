use strict;
use warnings;

use lib 't/';

use IPC::Shareable;
use RPiTest qw(running_test);
use Test::More;

running_test(__FILE__);

tie my %shared, 'IPC::Shareable', 'test' or die $!;

is $shared{test_num}, 156, "running_test() stored the test file number ok";
is $shared{test_name}, 'running_test', "running_test() stored the test file name ok";

running_test(-1);

is $shared{test_num}, -1, "running_test() stored the negative test num ok";
is $shared{test_name}, '', "running_test() with negative num erases test name";

done_testing();

