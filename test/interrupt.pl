#!/usr/bin/perl
use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Time::HiRes qw(usleep);

die "this test needs validation on wiring setup!\n";

# phys 40, wpi 29, gpio 21

if (! @ARGV){
    print "need arg\n";
    exit;
}

my $which = $ARGV[0];

my $mod = 'RPi::WiringPi';

if ($which == 1){ 
    # WPI - setup()
    my $pi = $mod->new;
    my $p = $pi->pin(29);
    
    $p->mode(INPUT);
    $p->pull(HIGH);

    <STDIN>;

    $p->pwm(0);
    $p->mode(INPUT);
    $p->write(LOW);
}

# gpio

if ($which == 2){ 
    # WPI - setup()
    my $pi = $mod->new(setup => 'gpio');
    my $p = $pi->pin(18);
    
    $p->mode(PWM_OUT);

    for (0..100){
        $p->pwm($_);
        usleep 5000;
    }
    print "done\n";
    <STDIN>;

    $p->pwm(0);
    $p->mode(INPUT);
    $p->write(LOW);
}

# phys

if ($which == 3){ 
    # WPI - setup()
    my $pi = $mod->new(setup => 'phys');
    my $p = $pi->pin(12);
    
    $p->mode(PWM_OUT);

    for (0..100){
        $p->pwm($_);
        usleep 5000;
    }
    print "done\n";
    <STDIN>;

    $p->pwm(0);
    $p->mode(INPUT);
    $p->write(LOW);
}

sub handler {
    print "in handler\n";
}
