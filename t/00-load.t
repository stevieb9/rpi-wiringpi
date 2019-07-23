use strict;
use warnings;

use Test::More;
BEGIN { use_ok('RPi::WiringPi') };
BEGIN { use_ok('WiringPi::API') };
BEGIN { use_ok('RPi::Const') };

my $pi = RPi::WiringPi->new(label => 't/00-load.t');
$pi->cleanup;

done_testing();
