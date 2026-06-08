use strict;
use warnings;

use lib 't/';

use RPi::WiringPi;
use RPiTest;
use RPi::Const qw(:all);
use Test::More;

rpi_running_test(__FILE__);

my $mod = 'RPi::WiringPi';

my $pi = $mod->new(label => 't/153-sig_handlers.t', shm_key => 'rpit');

my $sh = $pi->signal_handlers;

# We trap INT and TERM only. __DIE__ is intentionally NOT trapped: hardware
# cleanup on a crash or normal exit is handled by END/DESTROY, so a caught
# eval { die } never disturbs the pins.

is keys(%{ $sh }), 2, "there are two sig handlers set (INT, TERM) ok";
ok ! exists $sh->{'__DIE__'}, "__DIE__ is not trapped";

for ('INT', 'TERM'){
    is exists($sh->{$_}), 1, "$_ is a valid handler";
    my $uuid = $pi->uuid;
    is ref $sh->{$_}{$uuid}, 'CODE', "$_ has a handler for UUID $uuid";
    is ref $SIG{$_}, 'CODE', "\$SIG{$_} is installed as a code ref";
}

$pi->cleanup;

$sh = $pi->signal_handlers;

is keys(%{ $sh }), 2, "after proper cleanup, there are two sig handlers set";
ok ! exists $sh->{'__DIE__'}, "__DIE__ is still not trapped after cleanup()";

for ('INT', 'TERM'){
    is exists($sh->{$_}), 1, "$_ is a valid handler after clean cleanup()";
    my $uuid = $pi->uuid;
    is ref $sh->{$_}{$uuid}, 'CODE', "$_ has a handler for UUID $uuid after clean cleanup()";
}

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
