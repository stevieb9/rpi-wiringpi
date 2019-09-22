use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

rpi_running_test(__FILE__);

my $mod = 'RPi::WiringPi';

my $pi = $mod->new(label => 't/107-alt_modes.t');

{ # alt modes

    my $pin = $pi->pin(21);

    my $default = $pin->mode;

    is $default, INPUT, "default pin mode is INPUT ok";

    for (0..7){
        my $alt = "ALT$_";
        $pin->mode_alt($_);
        is $pin->mode_alt eq $_, 1, "pin in alt mode $alt ok";
        $pin->mode($default);
        is $pin->mode_alt, 0, "pin back to INPUT";
        is $pin->mode, INPUT, "...confirmed";
    }
}

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
