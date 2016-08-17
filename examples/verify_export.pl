#!/usr/bin/perl
use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);

# connect LED to physical pin 40
# led should blink three times

# GPIO pin in sys mode, 21

my $mod = 'RPi::WiringPi';

{ 
    # WPI - setup()
    my $pi = $mod->new(setup => 'sys');
    my $p = $pi->pin(21);

    $p->mode(OUTPUT);
    print "GPIO_SYS: HIGH\n";
    $p->write(HIGH);

    my $ok = <STDIN>;
    $p->write(LOW);
    print "GPIO_SYS: LOW\n";
    $p->mode(INPUT);
}
