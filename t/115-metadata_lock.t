use strict;
use warnings;
use feature 'say';

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

rpi_running_test(__FILE__);

my $mod = 'RPi::WiringPi';

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

my $pi = $mod->new(label => 't/115-metadata_lock.t');

my $locks = $pi->meta_lock;

is $pi->meta_lock(name => 6626, state => 1), 1, "meta_lock() 6626 is enabled";
is $pi->meta_lock(name => 6626, state => 0), 0, "meta_lock() 6626 is now disabled";
is $pi->meta_lock(name => 6626), 0, "still disabled after a check";

is $pi->meta_lock(name => 6627, state => 1), 1, "meta_lock() 6627 is enabled";

is $pi->meta_lock, $locks+2, "$locks locks exist. Existing plus our 2";

my @locks = $pi->meta_lock;

is grep({$_ == 6626 } @locks), 1, "6626 is a lock";
is grep({$_ == 6627 } @locks), 1, "6627 is a lock";

for (@locks){
    $pi->meta_lock(name => $_, delete => 1);
}

is $pi->meta_lock, $locks, "$locks locks remain. All test locks deleted";

is $pi->meta_lock(name => 'blah'), -1, "if a lock doesn't exist, we return -1";

$pi->cleanup;

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();
