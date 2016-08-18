#!/usr/bin/perl
use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);

if (! @ARGV){
    print "\nneed test number as arg: 1-SYS\n";
    print "\nthis test tests that a pin is exported in SYS mode. " .
          "Connect an LED to physical pin 40. The LED should blink.\n";
    exit;
}

# connect LED to physical pin 40
# led should blink once

# GPIO pin in sys mode, 21

my $mod = 'RPi::WiringPi';
my $which = $ARGV[0];

if ($which == 1){
    print "SYS export/unexport test\n";

    die "non-root user required\n" if $> == 0;

    my $pi = $mod->new(setup => 'sys');
    my $p = $pi->pin(21);

    $p->mode(OUTPUT);
    $p->write(HIGH);

    print "hit ENTER...\n";
    <STDIN>;
    $p->write(LOW);
    $p->mode(INPUT);
}
