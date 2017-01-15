use warnings;
use strict;
use feature 'say';

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Test::More;

# GPIO pin in sys mode, 29

my $mod = 'RPi::WiringPi';

die "non-root user required\n" if $> == 0;


my $pi = $mod->new;

is ((-X '/sys/class/gpio/gpio29'), undef, "pin not yet exported");

$pi->export_pin(29);

is ((-X '/sys/class/gpio/gpio29'), 1, "mode() has exported pin ok");

$pi->unexport_pin(29);

is ((-X '/sys/class/gpio/gpio29'), undef, "unexport_pin() ok");

done_testing();
