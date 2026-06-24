# TESTDOC: EEPROM validation (HW-free)
use strict;
use warnings;

use Test::More;

use RPi::EEPROM::AT24C32;

# HW-free unit coverage of RPi::EEPROM::AT24C32's argument validators, split out
# of the RPI_EEPROM-gated integration tests (t/420-422). _check_addr/_check_byte
# are plain package subs that croak before any I2C, so they run ungated here -
# no chip, no RPiTest, no shm. Also documents F6 (new() swallows eeprom_init's
# -1 on a bad device instead of croaking).

my $mod = 'RPi::EEPROM::AT24C32';

# --- _check_addr('caller', $addr): 0..4095 ---

eval { $mod->can('_check_addr')->('read') };
like $@, qr/requires an EEPROM memory address/, "_check_addr: undef addr croaks";

for my $bad (-1, 4096) {
    eval { $mod->can('_check_addr')->('read', $bad) };
    like $@, qr/address parameter out of range/, "_check_addr: addr $bad out of range";
}

for my $ok (0, 4095) {
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

# --- F6: new() on a bad device swallows eeprom_init's -1 (returns fd=-1, no croak) ---

my $obj;
{
    # eeprom_init writes the open error to the C-level stderr (fd 2), so send
    # fd 2 to /dev/null for this call (reopening STDERR reuses fd 2) to keep the
    # expected error out of the test output, then restore it.
    open my $saveerr, '>&', \*STDERR or die "save STDERR: $!";
    open STDERR, '>', '/dev/null'    or die "redirect STDERR: $!";
    $obj = eval { $mod->new(device => '/nonexistent-eeprom-device-xyz') };
    open STDERR, '>&', $saveerr      or die "restore STDERR: $!";
}
isa_ok $obj, $mod, "new() with a bad device still returns an object (F6: no croak)";
is $obj->fd, -1, "...with fd == -1 (F6: eeprom_init's failure is swallowed, not raised)";

done_testing();
