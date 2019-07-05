use strict;
use warnings;

use lib 't/';

use RPiTest qw(check_pin_status running_test);
use RPi::WiringPi;
use Test::More;

BEGIN {
    if (! $ENV{RPI_EEPROM}){
        plan skip_all => "RPI_EEPROM environment variable not set\n";
    }

    if (! $ENV{PI_BOARD}){
        $ENV{NO_BOARD} = 1;
        plan skip_all => "Not on a Pi board\n";
    }

    $SIG{__DIE__} = sub { die shift; }; # bypass RPi::WiringPi's grab on die()
}

running_test(__FILE__);

my $pi = RPi::WiringPi->new(fatal_exit => 0);
my $e = $pi->eeprom;

# read w/o addr

is
    eval { $e->read(); 1 },
    undef,
    "read() without addr param fails";

like $@, qr/requires an EEPROM memory address/, "...and error is sane";

# write w/o addr

is
    eval { $e->write(); 1 },
    undef,
    "write() without addr param fails";

like $@, qr/requires an EEPROM memory address/, "...and error is sane";

# write w/o byte

is
    eval { $e->write(100); 1 },
    undef,
    "write() without byte param fails";

like $@, qr/requires a data byte/, "...and error is sane";

for (-1, 4096){
    is
        eval { $e->read($_); 1 },
        undef,
        "read() with $_ as addr param fails";

    like $@, qr/address parameter out of range/, "...and error is sane";

    is
        eval { $e->write($_, 255); 1 },
        undef,
        "write() with $_ as addr param fails";

    like $@, qr/address parameter out of range/, "...and error is sane";
}

for (-1, 256){
    is
        eval { $e->write(4095, $_); 1 },
        undef,
        "write() with $_ as byte param fails";

    like $@, qr/byte parameter out of range/, "...and error is sane";
}

done_testing();

