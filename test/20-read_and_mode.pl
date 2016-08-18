use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);

if (! @ARGV){
    print "\nneed test number as arg: 1-WPI, 2-GPIO, 3-PHYS, 4-SYS\n";
    print "\nthis test tests read() and reading mode() pin functions. " .
          "Connect pin 40 to 3.3v power through a pull-up 4.7k or10k " .
          "resistor\n" .
          "Each test should print '*scheme* mode: 0, state: 1\n";
    exit;
}

# connect phys pin 40 to 3.3v through a resistor
# should print "'scheme' mode: 0, state: 1" for all tests

# phys: 40, wpi: 29, gpio: 21

my $which = $ARGV[0];

my $mod = 'RPi::WiringPi';

# WPI

if ($which == 1){
    print "WPI scheme test\n";

    die "\ntest 1 requires root\n" if $> != 0;

    my $pi = $mod->new;
    my $p = $pi->pin(29);

    $p->mode(INPUT);
    my $mode = $p->mode;
    my $state = $p->read;
    print "WPI - mode: $mode, state: $state\n";
}

# gpio

if ($which == 2){
    print "GPIO scheme test\n";

    die "\ntest 2 requires root\n" if $> != 0;

    my $pi = $mod->new(setup => 'gpio');
    my $p = $pi->pin(21);

    $p->mode(INPUT);
    my $mode = $p->mode;
    my $state = $p->read;
    print "GPIO - mode: $mode, state: $state\n";
}

# phys

if ($which == 3){
    print "PHYS scheme test\n";

    die "\ntest 3 requires root\n" if $> != 0;

    my $pi = $mod->new(setup => 'phys');
    my $p = $pi->pin(40);

    $p->mode(INPUT);
    my $mode = $p->mode;
    my $state = $p->read;
    print "PHYS - mode: $mode, state: $state\n";
}

# sys

if ($which = 4){
    print "GPIO_SYS scheme test\n";

    die "\ntest 4 requires non-root user\n" if $> == 0;

    my $pi = $mod->new(setup => 'sys');
    my $p = $pi->pin(21);

    $p->mode(INPUT);
    my $mode = $p->mode;
    my $state = $p->read;
    print "GPIO_SYS - mode: $mode, state: $state\n";
}
