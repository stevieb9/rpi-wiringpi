#!/usr/bin/perl
use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);
use Time::HiRes qw(usleep);

# phys 12, wpi 1, gpio 18

if (! @ARGV){
    print "need arg\n";
    exit;
}

my $which = $ARGV[0];

my $mod = 'RPi::WiringPi';

if ($which == 1){ 
    # WPI - setup()
    my $pi = $mod->new;
    my $p = $pi->pin(1);
    
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
