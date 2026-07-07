# TESTDOC: RPi::I2C unit (HW-free)
use strict;
use warnings;

use Test::More;
use IO::File;
use RPi::I2C;

# Mirror of RPi::I2C's own t/10-validation.t, run here in the canonical suite
# against the INSTALLED module. t/605-i2c.t drives a real Arduino over the bus;
# this adds HW-free coverage of the addr validation, _set_reg defaulting, and
# the read_bytes/write_word/process contracts - no bus, no device. The
# contracts were fixed to match the POD in RPi::I2C 3.1803 (test-coverage-gaps
# B18, executed as rpi-i2c-fixes V8); these tests assert the FIXED behaviour,
# so they REQUIRE RPi::I2C >= 3.1803 installed.

# --- new(): addr must be an integer (croaks before opening the bus) ---

for my $bad (undef, 'xx', '0x78') {
    my $shown = defined $bad ? "'$bad'" : 'undef';
    eval { RPi::I2C->new($bad) };
    like $@, qr/requires the \$addr param/, "new($shown) croaks before opening the bus";
}

# --- new(): addr must be within the 7-bit I2C range (0x00-0x7F) ---
# (requires RPi::I2C >= 3.1803)

{
    eval { RPi::I2C->new(0x80) };
    like $@, qr/out of range/, "new(0x80) croaks - beyond the 7-bit address range";

    eval { RPi::I2C->new(1024) };
    like $@, qr/out of range/, "new(1024) croaks - way beyond the 7-bit range";

    # Address 0x00 (the I2C general call) MUST remain legal:
    # RPi::PWM::PCA9685->reset() does RPi::I2C->new(0, ...) for SWRST
    local $ENV{I2C_TESTING} = 1;
    my $gc = RPi::I2C->new(0, '/dev/null');
    isa_ok $gc, 'RPi::I2C', 'new(0, /dev/null) under I2C_TESTING (general call)';

    my $top = RPi::I2C->new(0x7F, '/dev/null');
    isa_ok $top, 'RPi::I2C', 'new(0x7F, /dev/null) under I2C_TESTING (top of range)';
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

    # read_bytes() accumulates and returns the documented array of N bytes,
    # ascending from the base register (was: only the base-register byte)
    is_deeply [$obj->read_bytes(4, 0x10)], [0x10, 0x11, 0x12, 0x13],
        "read_bytes(4, 0x10) returns the documented 4-byte array, ascending from the base register";

    # write_word($value, [$reg]) matches write_byte() and its own POD
    # (was: ($reg, $value))
    $obj->write_word(0xABCD, 0x10);
    is_deeply [@write_args[1, 2]], [0x10, 0xABCD],
        "write_word(0xABCD, 0x10) sends (reg=0x10, value=0xABCD) - value first, register second";

    $obj->write_word(0xBEEF);
    is_deeply [@write_args[1, 2]], [0x00, 0xBEEF],
        "write_word(0xBEEF) defaults the register to 0x00 via _set_reg";

    # process($value, [$reg]) matches its POD and gets the _set_reg default
    # (was: ($reg, $value) with no default)
    my @process_args;
    local *RPi::I2C::_processCall = sub { @process_args = @_; return 0xFFFF; };
    $obj->process(0x1234, 0x20);
    is_deeply [@process_args[1, 2]], [0x20, 0x1234],
        "process(0x1234, 0x20) sends (reg=0x20, value=0x1234) - value first, register second";

    $obj->process(0x5678);
    is_deeply [@process_args[1, 2]], [0x00, 0x5678],
        "process(0x5678) defaults the register to 0x00 via _set_reg";

    # write_block() enforces the 32-byte SMBus block cap instead of letting
    # the bundled header silently truncate
    eval { $obj->write_block([ (1) x 33 ]) };
    like $@, qr/maximum of 32 bytes/,
        "write_block() with 33 bytes croaks instead of silently truncating";
}

done_testing();
