use warnings;
use strict;

use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);

if (! @ARGV){
    print "\nneed test number as arg: 1-WPI, 2-GPIO, 3-PHYS, 4-SYS\n";
    print "\nthis test tests export(), mode() and write() pin functions. " .
          "Connect an LED to physical pin 40. Each test should blink the LED\n";
    exit;
}

# connect LED to physical pin 40
# led should blink for all tests

# phys: 40, wpi: 29, gpio: 21

my $which = $ARGV[0];

my $mod = 'RPi::WiringPi';

# WPI

if ($which == 1){
    print "WPI scheme test\n";

    die "\ntest 1 requires root\n" if $> != 0;
    
    my $pi = $mod->new(setup => 'wpi');
    my $p = $pi->pin(29);

    $p->mode(OUTPUT);

    print "WPI: HIGH\n";
    $p->write(HIGH);
    sleep 1;
    $p->mode(INPUT);
    $p->write(LOW); 
}

# gpio

if ($which == 2){
    print "GPIO scheme test\n";

    die "\ntest 2 requires root\n" if $> != 0;
    
    my $pi = $mod->new(setup => 'gpio');
    my $p = $pi->pin(21);

    $p->mode(OUTPUT);
    print "GPIO: HIGH\n";
    $p->write(HIGH);
    sleep 1;
    $p->mode(INPUT);
    $p->write(LOW); 

}

# phys

if ($which == 3){
    print "PHYS scheme test\n";

    die "\ntest 3 requires root\n" if $> != 0;

    my $pi = $mod->new(setup => 'phys');
    my $p = $pi->pin(40);

    $p->mode(OUTPUT);

    print "PHYS: HIGH\n";
    $p->write(HIGH);
    sleep 1;
    $p->mode(INPUT);
    $p->write(LOW); 
}

# sys

if ($which == 4){
    print "GPIO_SYS scheme test\n";


    die "\ntest 4 requires non-root user\n" if $> == 0;

    print "pin not yet exported\n" if ! -X '/sys/class/gpio/gpio21';
    
    print "pin is exported but shouldn't be!\n" 
      if -X '/sys/class/gpio/gpio21';
    
    my $pi = $mod->new(setup => 'sys');
    my $p = $pi->pin(21);

    $p->mode(OUTPUT);

    print "pin exported\n" if -X '/sys/class/gpio/gpio21';

    print "SYS: HIGH\n";
    $p->write(HIGH);
    sleep 1;
    $p->write(LOW);
    $p->mode(INPUT);

    $pi->unexport_pin($p->num);

    print "pin unexported\n" if ! -X '/sys/class/gpio/gpio21';
}
