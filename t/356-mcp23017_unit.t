# TESTDOC: MCP23017 unit (HW-free)
use strict;
use warnings;

use Test::More;

use RPi::GPIOExpander::MCP23017;

# Mirror of RPi::GPIOExpander::MCP23017's HW-free unit tests (its t/02), run
# here in the canonical suite. t/355 (and t/350 via the stepper) drive the
# expander on real hardware; this adds the pure pin-bit map + arg-validators
# against the INSTALLED module, ungated (no RPiTest, no shm, no Pi).
#
# The pinBit out-of-bounds croak is matched version-agnostically (/out of
# bounds/); the dist's t/02 asserts the pin number now appears (F2 fix).

my $mod = 'RPi::GPIOExpander::MCP23017';

# --- _pinBit: pin -> register bit (bank A 0-7; bank B 8-15 wraps to 0-7) ---

is RPi::GPIOExpander::MCP23017::_pinBit(0),  0, "_pinBit(0) = 0";
is RPi::GPIOExpander::MCP23017::_pinBit(7),  7, "_pinBit(7) = 7";
is RPi::GPIOExpander::MCP23017::_pinBit(8),  0, "_pinBit(8) = 0 (bank B wraps)";
is RPi::GPIOExpander::MCP23017::_pinBit(15), 7, "_pinBit(15) = 7";

for my $bad (-1, 16) {
    eval { RPi::GPIOExpander::MCP23017::_pinBit($bad) };
    like $@, qr/out of bounds/, "_pinBit($bad) croaks";
}

# --- _check_bank / _check_mode / _check_pullup: accept 0/1, reject else ---

for my $check (qw(_check_bank _check_mode _check_pullup)) {
    my $fn = $mod->can($check);
    eval { $fn->(0) }; is $@, '', "$check(0) accepted";
    eval { $fn->(1) }; is $@, '', "$check(1) accepted";
    for my $bad (2, -1, 3) {
        eval { $fn->($bad) };
        like $@, qr/must be either 0 or 1/, "$check($bad) croaks";
    }
}

# --- _check_write: requires a defined 0/1 state ---

eval { RPi::GPIOExpander::MCP23017::_check_write(undef) };
like $@, qr/requires the state to be sent in/, "_check_write(undef) croaks";

eval { RPi::GPIOExpander::MCP23017::_check_write(2) };
like $@, qr/must be either 0 or 1/, "_check_write(2) croaks";

for my $ok (0, 1) {
    eval { RPi::GPIOExpander::MCP23017::_check_write($ok) };
    is $@, '', "_check_write($ok) accepted";
}

done_testing();
