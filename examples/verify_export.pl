#!/usr/bin/perl
use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);

if (! @ARGV){
    print "need arg\n";
    exit;
}

my $which = $ARGV[0];

# connect LED to physical pin 40
# led should blink three times

# phys: 40, wpi: 29, gpio: 21

my $mod = 'RPi::WiringPi';

if ($which == 1){ 
    # WPI - setup()
    my $pi = $mod->new(setup => 'sys');
    my $p = $pi->pin(21);

    $p->mode(OUTPUT);
    print "WPI: HIGH\n";
    $p->write(HIGH);

    opendir my $dh, '/sys/class/gpio';
    my @dirs = readdir $dh;
    print "$_\n" for @dirs;
    my $ok = <STDIN>;
    $p->write(LOW);
    $p->mode(INPUT);
}
__END__
if ($which == 2){
    # GPIO - setup_gpio()
    my $pi = $mod->new(setup => 'gpio');
    my $p = $pi->pin(21);

    $p->mode(OUTPUT);
    print "GPIO: HIGH\n";
    $p->write(HIGH);
    my $ok = <STDIN>;
    $p->write(LOW);
    $p->mode(INPUT);
}

if ($which == 3){ 
    # PHYS - setup_phys()
    my $pi = $mod->new(setup => 'phys');
    my $p = $pi->pin(40);

    $p->mode(OUTPUT);
    print "PHYS: HIGH\n";
    $p->write(HIGH);
    my $ok = <STDIN>;
    $p->write(LOW);
    $p->mode(INPUT);
}
