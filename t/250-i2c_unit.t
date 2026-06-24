# TESTDOC: RPi::I2C unit (HW-free)
use strict;
use warnings;

use Test::More;
use IO::File;
use RPi::I2C;

# Mirror of RPi::I2C's own t/10-validation.t, run here in the canonical suite
# against the INSTALLED module. t/605-i2c.t drives a real Arduino over the bus;
# this adds HW-free coverage of the addr validation, _set_reg defaulting, and
# the read_bytes/write_word contract bugs (F7/F8) - no bus, no device. F7/F8
# are PINNED (current behaviour); their fixes are deferred to B18.

# --- new(): addr must be an integer (croaks before opening the bus) ---

for my $bad (undef, 'xx', '0x78') {
    my $shown = defined $bad ? "'$bad'" : 'undef';
    eval { RPi::I2C->new($bad) };
    like $@, qr/requires the \$addr param/, "new($shown) croaks before opening the bus";
}

# --- _set_reg(): defaults undef -> DEFAULT_REGISTER (0x00) ---

is RPi::I2C::_set_reg(undef), 0x00, "_set_reg(undef) defaults to 0x00";
is RPi::I2C::_set_reg(0x15),  0x15, "_set_reg(0x15) passes through";

# --- faked object: no bus; XS reads/writes stubbed ---

{
    no warnings 'redefine';
    local *RPi::I2C::_readByteData  = sub { return $_[1]; };
    my @write_args;
    local *RPi::I2C::_writeWordData = sub { @write_args = @_; return 1; };

    my $obj = bless IO::File->new('/dev/null'), 'RPi::I2C';

    # F7 (pinned): read_bytes() overwrites $retval each pass, returning only the
    # base-register byte, not the documented array of N bytes.
    is $obj->read_bytes(4, 0x10), 0x10,
        "read_bytes(4, 0x10) returns only the base-register byte (F7, pinned)";

    # F8 (pinned): write_word($reg, $value) - first arg is the register,
    # inconsistent with write_byte($value, $reg) and the POD.
    $obj->write_word(0x10, 0xABCD);
    is_deeply [@write_args[1, 2]], [0x10, 0xABCD],
        "write_word(0x10, 0xABCD) sends (reg, value) - first arg is the register (F8, pinned)";
}

done_testing();
