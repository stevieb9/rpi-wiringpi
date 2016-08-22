use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
if (! @ARGV){
    print "\nneed test number as arg: 1-WPI, 2-GPIO, 3-PHYS\n";
    print "\nthis test tests registered_pins(). No wiring is required" .
          "Each test will print 'ok'\n";
    exit;
}

my $which = $ARGV[0];

my $mod = 'RPi::WiringPi';

# WPI

if ($which == 1){
    print "WPI scheme test\n";

    die "\ntest 1 requires root\n" if $> != 0;

    my $pi = $mod->new(setup => 'wpi');
    my $p29 = $pi->pin(29);

    my $ok = eval { my $p_bad = $pi->pin(29); 1; };

    if ($ok){
        print "\nok\n";
    }
    else {
        print "failed to prevent registering a duplicate pin!\n";
    }
    $pi->cleanup;
}

# gpio

if ($which == 2){
    print "GPIO scheme test\n";

    die "\ntest 2 requires root\n" if $> != 0;

    my $pi = $mod->new(setup => 'gpio');
    my $p18 = $pi->pin(18);

    my $ok = eval { my $p_bad = $pi->pin(18); 1; };

    if ($ok){
        print "\nok\n";
    }
    else {
        print "failed to prevent registering a duplicate pin!\n";
    }

    $pi->cleanup;
}

# phys

if ($which == 3){
    print "PHYS scheme test\n";

    die "\ntest 3 requires root\n" if $> != 0;

    my $pi = $mod->new(setup => 'phys');
    my $p12 = $pi->pin(12);

    my $ok = eval { my $p_bad = $pi->pin(12); 1; };

    if ($ok){
        print "\nok\n";
    }
    else {
        print "failed to prevent registering a duplicate pin!\n";
    }

    $pi->cleanup;
}

# sys

if ($which == 4){
    print "GPIO_SYS scheme test\n";

    die "\ntest 4 requires non-root user\n" if $> == 0;

    my $pi = $mod->new(setup => 'gpio');
    my $p18 = $pi->pin(18);

    my $ok = eval { my $p_bad = $pi->pin(18); 1; };

    if ($ok){
        print "\nok\n";
    }
    else {
        print "failed to prevent registering a duplicate pin!\n";
    }

    $pi->cleanup;
}
