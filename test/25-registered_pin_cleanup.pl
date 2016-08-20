use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
if (! @ARGV){
    print "\nneed test number as arg: 1-WPI, 2-GPIO, 3-PHYS\n";
    print "\nthis test tests registered_pins(). Connect LEDs to phys pins 12 & 40" .
          "Each test should blink both LEDs, and turn off completely'\n";
    exit;
}

# phys: 40, wpi: 29, gpio: 21
# phys: 12, wpi: 1, gpio: 18

my $which = $ARGV[0];

my $mod = 'RPi::WiringPi';

# WPI

if ($which == 1){
    print "WPI scheme test\n";

    die "\ntest 1 requires root\n" if $> != 0;

    my $pi = $mod->new(setup => 'wpi');
    my $p29 = $pi->pin(29);
    my $p1 = $pi->pin(1);

    $p29->mode(OUTPUT);
    $p1->mode(OUTPUT);
    
    $p29->write(HIGH);
    $p1->write(HIGH);
    sleep 1;

    my $pins = $pi->registered_pins(1);

    $p29->pull(PUD_UP);

    $pi->cleanup;

}

# gpio

if ($which == 2){
    print "GPIO scheme test\n";

    die "\ntest 2 requires root\n" if $> != 0;

    my $pi = $mod->new(setup => 'gpio');
    my $p21 = $pi->pin(21);
    my $p18 = $pi->pin(18);

    $p21->mode(OUTPUT);
    $p18->mode(OUTPUT);
    
    $p21->write(HIGH);
    $p18->write(HIGH);

    sleep 1;

    my $pins = $pi->registered_pins(1);

    $p21->pull(PUD_UP);
    
    $pi->cleanup;

}

# phys

if ($which == 3){
    print "PHYS scheme test\n";

    die "\ntest 3 requires root\n" if $> != 0;

    my $pi = $mod->new(setup => 'phys');
    my $p12 = $pi->pin(12);
    my $p40 = $pi->pin(40);

    $p12->mode(OUTPUT);
    $p40->mode(OUTPUT);
    
    $p12->write(HIGH);
    $p40->write(HIGH);

    sleep 1;

    my $pins = $pi->registered_pins(1);

    $p40->pull(PUD_UP);

    $pi->cleanup;

}

# sys

if ($which == 4){
    print "GPIO_SYS scheme test\n";

    die "\ntest 4 requires non-root user\n" if $> == 0;

    my $pi = $mod->new(setup => 'gpio');
    my $p21 = $pi->pin(29);
    my $p18 = $pi->pin(1);

    $p21->mode(OUTPUT);
    $p18->mode(OUTPUT);
    
    $p21->write(HIGH);
    $p18->write(HIGH);

    sleep 1;

    my $pins = $pi->registered_pins(1);

    $p21->pull(PUD_UP);

    $pi->cleanup;


}
