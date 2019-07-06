use strict;
use warnings;

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

my $pi = $mod->new(label => 't/153-sig_handlers.t');

my $sh = $pi->signal_handlers;

is keys(%{ $sh }), 3, "there are three sig handlers set ok";

for ('__DIE__', 'TERM', 'INT'){
    is exists($sh->{$_}), 1, "$_ is a valid handler";
    my $uuid = $pi->uuid;
    is ref $sh->{$_}{$uuid}, 'CODE', "$_ has a handler for UUID $uuid";
}

$pi->cleanup;

$sh = $pi->signal_handlers;

is keys(%{ $sh }), 3, "after proper cleanup, there are three sig handlers set";

for ('__DIE__', 'TERM', 'INT'){
    is exists($sh->{$_}), 1, "$_ is a valid handler after clean cleanup()";
    my $uuid = $pi->uuid;
    is ref $sh->{$_}{$uuid}, 'CODE', "$_ has a handler for UUID $uuid after clean cleanup()";
}

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();
