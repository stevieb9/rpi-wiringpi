use strict;
use warnings;

# Board-4 convenience: set RPI_BOARD_4=1 and every env gate the board-4 suite
# needs is enabled automatically, instead of exporting each one by hand. Runs in
# BEGIN so it lands before RPiTest's compile-time RPI_BOARD skip_all gate.
BEGIN {
    if ($ENV{RPI_BOARD_4}) {
        $ENV{$_} = 1 for qw(RPI_BOARD RPI_RTC RPI_BMP RPI_EEPROM RPI_OLED);
    }
}

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use Test::More;

BEGIN {
    if (! $ENV{RPI_EEPROM}){
        plan skip_all => "RPI_EEPROM environment variable not set\n";
    }

    $SIG{__DIE__} = sub { die shift; }; # bypass RPi::WiringPi's grab on die()
}

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(
    fatal_exit => 0,
    label => 't/421-eeprom_read_write_byte_croak.t',
    shm_key => 'rpit'
);
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

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();

