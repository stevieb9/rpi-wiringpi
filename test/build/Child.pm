package Child;

use warnings;
use strict;

use RPi::WiringPi::Constant;
use parent 'RPi::WiringPi::LCD';
use parent 'WiringPi::API';

sub blah {
    print "we're an inherited object!\n";
}

1;