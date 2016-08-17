#!/usr/bin/perl
use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);

# connect LED to physical pin 40
# led should blink three times

# phys: 40, wpi: 29, gpio: 21

my $mod = 'RPi::WiringPi';

{ # WPI - setup()
    my $pi = $mod->new;
    my $p = $pi->pin(29);

    $p->mode(OUTPUT);
    print "WPI: HIGH\n";
    $p->write(HIGH);
    sleep 1;
    $p->write(LOW);
    $p->mode(INPUT);
}

{ # GPIO - setup_gpio()
    my $pi = $mod->new(setup => 'gpio');
    my $p = $pi->pin(21);

    $p->mode(OUTPUT);
    print "GPIO: HIGH\n";
    $p->write(HIGH);
    sleep 1;
    $p->write(LOW);
    $p->mode(INPUT);
}

{ # PHYS - setup_phys()
    my $pi = $mod->new(setup => 'phys');
    my $p = $pi->pin(40);

    $p->mode(OUTPUT);
    print "SYS: HIGH\n";
    $p->write(HIGH);
    sleep 1;
    $p->write(LOW);
    $p->mode(INPUT);
}
