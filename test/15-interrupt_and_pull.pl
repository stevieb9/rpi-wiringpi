#!/usr/bin/perl
use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Time::HiRes qw(usleep);

if (! @ARGV){
    print "\nneed test number as arg: 1-WPI, 2-GPIO, 3-PHYS, 4-SYS\n";
    print "\nthis test tests interrupts. " .
          "Connect an LED to physical pin 40\n";
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

    my $pi = $mod->new;
    my $p = $pi->pin(29);

    $p->interrupt_set(EDGE_RISING, 'handler');

    $p->mode(INPUT);
    $p->pull(HIGH);

    print "hit ENTER...\n";
    <STDIN>;

    $p->write(LOW);
}

# gpio

if ($which == 2){
    print "GPIO interrupt test\n";

    die "test requires root user\n" if $> != 0;

    my $pi = $mod->new;
    my $p = $pi->pin(21);

    $p->interrupt_set(EDGE_RISING, 'handler');

    $p->mode(INPUT);
    $p->pull(HIGH);

    print "hit ENTER...\n";
    <STDIN>;

    $p->write(LOW);
}

# phys

if ($which == 3){
    print "PHYS interrupt test\n";

    die "test requires root user\n" if $> != 0;

    my $pi = $mod->new;
    my $p = $pi->pin(40);

    $p->interrupt_set(EDGE_RISING, 'handler');

    $p->mode(INPUT);
    $p->pull(HIGH);

    print "hit ENTER...\n";
    <STDIN>;

    $p->write(LOW);
}

# sys

if ($which == 4){
    print "GPIO_SYS interrupt test\n";

    die "test requires a non-root user\n" if $> == 0;

    my $pi = $mod->new;
    my $p = $pi->pin(21);

    $p->interrupt_set(EDGE_RISING, 'handler');

    $p->mode(INPUT);
    $p->pull(HIGH);

    print "hit ENTER...\n";
    <STDIN>;

    $p->write(LOW);
}

sub handler {
    print "in handler\n";
}
