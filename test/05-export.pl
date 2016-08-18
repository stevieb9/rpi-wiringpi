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

    print "pin not yet exported\n" if ! -X '/sys/class/gpio/gpio21';

    print "pin is exported but shouldn't be!\n" 
      if -X '/sys/class/gpio/gpio21';

    my $pi = $mod->new(setup => 'sys');
    my $p = $pi->pin(21);

    $p->mode(OUTPUT);

    print "pin exported by mode()\n" if -X '/sys/class/gpio/gpio21';

    $p->write(HIGH);

    print "hit ENTER...\n";
    <STDIN>;
    $pi->unexport_pin($p->num);

    print "pin unexported by unexport_pin)\n" if ! -X '/sys/class/gpio/gpio21';
}
