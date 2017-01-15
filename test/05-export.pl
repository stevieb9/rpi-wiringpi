use warnings;
use strict;
use feature 'say';

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Test::More;

# GPIO pin in sys mode, 29

my $mod = 'RPi::WiringPi';

die "non-root user required\n" if $> == 0;

is ((-X '/sys/class/gpio/gpio29'), undef, "pin not yet exported");

my $pi = $mod->new(setup => 'sys');
my $p = $pi->pin(29);

say $p->num;
$p->mode(OUTPUT);

is $p->mode, OUTPUT, "pinmode set to output ok";

is ((-X '/sys/class/gpio/gpio29'), 1, "mode() has exported pin ok");

$p->write(HIGH);

is $p->read, 1, "exported pin went HIGH ok";

$pi->unexport_pin($p->num);

is ((-X '/sys/class/gpio/gpio29'), undef, "unexport_pin() ok");

$pi->cleanup;

done_testing();
