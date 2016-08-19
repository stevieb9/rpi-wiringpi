#!/usr/bin/perl
use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Time::HiRes qw(usleep);

if (! @ARGV){
    print "\nneed test number as arg: 1-WPI, 2-GPIO, 3-PHYS, 4-SYS\n";
    print "\nthis test tests interrupts. Wire phys pin 40 to a grounded button, and push the button. Each test " .
          "should output 'in handler!'";
    exit;
}

# phys 40, wpi 29, gpio 21
# "in handler!" should be printed

my $which = $ARGV[0];

my $mod = 'RPi::WiringPi';

# wpi

if ($which == 1){
    print "WPI interrupt test\n";

    die "test requires root user\n" if $> != 0;

    my $pi = $mod->new(setup => 'wpi');
    my $p = $pi->pin(29);

    $p->mode(INPUT);
    $p->pull(PUD_UP);

    $p->interrupt_set(EDGE_FALLING, 'handler');

    for (1..5){
        sleep 1;
    }

    print "hit ENTER...\n";
    <STDIN>;

    $p->pull(PUD_OFF);
}

# gpio

elsif ($which == 2){
    print "GPIO interrupt test\n";

    die "test requires root user\n" if $> != 0;

    my $pi = $mod->new(setup => 'gpio');
    my $p = $pi->pin(21);

    $p->interrupt_set(EDGE_FALLING, 'handler');
    
    $p->mode(INPUT);
    $p->pull(PUD_UP);

    for (1..5){
        sleep 1;
    }

    print "hit ENTER...\n";
    <STDIN>;

    $p->pull(PUD_OFF);
}

# phys

elsif ($which == 3){
    print "PHYS interrupt test\n";

    die "test requires root user\n" if $> != 0;

    my $pi = $mod->new(setup => 'phys');
    my $p = $pi->pin(40);

    $p->interrupt_set(EDGE_FALLING, 'handler');

    $p->mode(INPUT);
    $p->pull(PUD_UP);

    for (1..5){
        sleep 1;
    }

    print "hit ENTER...\n";
    <STDIN>;

    $p->pull(PUD_OFF);
}

# sys

elsif ($which == 4){
    print "GPIO_SYS interrupt test\n";

    die "test requires a non-root user\n" if $> == 0;

    my $pi = $mod->new(setup => 'sys');
    my $p = $pi->pin(21);

    $p->interrupt_set(EDGE_FALLING, 'handler');

    $p->mode(INPUT);
    $p->pull(PUD_UP);

    for (1..5){
        sleep 1;
    }
    print "hit ENTER...\n";
    <STDIN>;

    $p->pull(PUD_OFF);
}

sub handler {
    print "in handler!\n";
}
