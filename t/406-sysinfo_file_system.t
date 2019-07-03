use warnings;
use strict;
use feature 'say';

use lib 't/';

use RPiTest qw(check_pin_status running_test);
use RPi::WiringPi;
use Test::More;

if (! $ENV{PI_BOARD}){
    plan skip_all => "Not on a Pi board";
}

running_test(__FILE__);

my $pi = RPi::WiringPi->new;

like $pi->file_system, qr|/dev/root|, "method includes root ok";

like $pi->file_system, qr|/var/swap|, "method includes swap ok";

done_testing();
