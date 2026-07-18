# TESTDOC: EEPROM AT24C256 validation (HW-free)
use strict;
use warnings;

use Test::More;

use RPi::EEPROM::AT24C256;

# HW-free unit coverage of RPi::EEPROM::AT24C256's argument validators, split out
# of the RPI_EEPROM256-gated integration tests (t/544-546). _check_addr/_check_byte
# are plain package subs that croak before any I2C, so they run ungated here -
# no chip, no RPiTest, no shm. Also asserts new() croaks (not blesses a broken
# fd=-1 object) when eeprom_init() fails on a bad device.

my $mod = 'RPi::EEPROM::AT24C256';

# --- _check_addr('caller', $addr): 0..32767 ---

eval { $mod->can('_check_addr')->('read') };
like $@, qr/requires an EEPROM memory address/, "_check_addr: undef addr croaks";

for my $bad (-1, 32768) {
    eval { $mod->can('_check_addr')->('read', $bad) };
    like $@, qr/address parameter out of range/, "_check_addr: addr $bad out of range";
}

for my $ok (0, 32767) {
    is $mod->can('_check_addr')->('read', $ok), 1, "_check_addr: addr $ok accepted";
}

eval { $mod->can('_check_addr')->() };
like $@, qr/_check_addr\(\) requires \$sub/, "_check_addr: missing caller label croaks";

# --- _check_byte('caller', $byte): 0..255 ---

eval { $mod->can('_check_byte')->('write') };
like $@, qr/requires a data byte/, "_check_byte: undef byte croaks";

for my $bad (-1, 256) {
    eval { $mod->can('_check_byte')->('write', $bad) };
    like $@, qr/data byte parameter out of range/, "_check_byte: byte $bad out of range";
}

for my $ok (0, 255) {
    is $mod->can('_check_byte')->('write', $ok), 1, "_check_byte: byte $ok accepted";
}

eval { $mod->can('_check_byte')->() };
like $@, qr/_check_byte\(\) requires \$sub/, "_check_byte: missing caller label croaks";

# --- new() croaks when eeprom_init() fails (bad device -> -1) ---

my $err;
{
    # eeprom_init writes the open error to the C-level stderr (fd 2), so send
    # fd 2 to /dev/null for this call (reopening STDERR reuses fd 2) to keep the
    # expected error out of the test output, then restore it.
    open my $saveerr, '>&', \*STDERR or die "save STDERR: $!";
    open STDERR, '>', '/dev/null'    or die "redirect STDERR: $!";
    eval { $mod->new(device => '/nonexistent-eeprom-device-xyz') };
    $err = $@;
    open STDERR, '>&', $saveerr      or die "restore STDERR: $!";
}
like
    $err,
    qr/failed to initialise the EEPROM/,
    "new() croaks when eeprom_init() fails on a bad device";

done_testing();
