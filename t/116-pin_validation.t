use strict;
use warnings;

use Test::More;

# Mirror of RPi::Pin's own t/10-validation.t, run here in the canonical suite.
# RPi::Pin's arg-validation is HW-free - every die/croak fires before any
# wiringPi call, and new() skips setup_gpio under NO_BOARD - so this runs
# ungated, without a Pi. It deliberately does NOT use RPiTest (whose load-time
# RPI_BOARD gate would skip it) and never registers in the shared 'rpit'
# segment, so it stays independent of the serial suite and the t/110-114 counts.

BEGIN { $ENV{NO_BOARD} = 1; }

use RPi::Pin;

# --- new(): pin must be a non-negative integer ---

for my $bad (undef, 'x', -1, '1.5', '') {
    my $shown = defined $bad ? "'$bad'" : 'undef';
    eval { RPi::Pin->new($bad) };
    like $@, qr/pin must be an integer/, "new($shown) dies";
}

my $pin = RPi::Pin->new(18, 'validation');
isa_ok $pin, 'RPi::Pin', 'new() with a valid pin (NO_BOARD) returns an object';

# --- HW-free accessors ---

is $pin->num, 18, 'num() returns the pin number';
is $pin->comment, 'validation', 'comment() returns the value set in new()';
is $pin->comment('relabelled'), 'relabelled', 'comment() sets and gets';

# --- mode(): invalid mode dies (valid modes hit hardware, not tested here) ---

for my $bad (99, 5) {
    eval { $pin->mode($bad) };
    like $@, qr/mode param must be either 0/, "mode($bad) dies";
}

# --- write(): value must be 0 or 1 ---

for my $bad (2, -1) {
    eval { $pin->write($bad) };
    like $@, qr/value must be 0 or 1/, "write($bad) dies";
}

# --- pull(): direction must be 0, 1 or 2 ---

for my $bad (5, 3) {
    eval { $pin->pull($bad) };
    like $@, qr/requires either 0, 1 or 2/, "pull($bad) dies";
}

# --- pwm(): requires root (the only HW-free pwm path) ---

SKIP: {
    skip "running as root - pwm() root-guard not exercised", 1 if $> == 0;
    eval { $pin->pwm(100) };
    like $@, qr/root/, 'pwm() dies when not run as root';
}

# --- set_interrupt(): edge / callback / debounce validation ---

eval { $pin->set_interrupt(9, sub {}) };
like $@, qr/edge must be EDGE_FALLING/, 'set_interrupt() bad edge croaks';

eval { $pin->set_interrupt(1, 'not_a_coderef') };
like $@, qr/callback to be a CODE reference/, 'set_interrupt() non-CODE callback croaks';

eval { $pin->set_interrupt(1, sub {}, 'x') };
like $@, qr/debounce_us must be a non-negative integer/, 'set_interrupt() bad debounce croaks';

# --- background_interrupt(): same validation, fires before any fork ---

eval { $pin->background_interrupt(9, sub {}) };
like $@, qr/edge must be EDGE_FALLING/, 'background_interrupt() bad edge croaks';

eval { $pin->background_interrupt(1, 'not_a_coderef') };
like $@, qr/callback to be a CODE reference/, 'background_interrupt() non-CODE callback croaks';

eval { $pin->background_interrupt(1, sub {}, 'x') };
like $@, qr/debounce_us must be a non-negative integer/, 'background_interrupt() bad debounce croaks';

# --- interrupt_set(): deprecated wrapper delegates to set_interrupt() ---

eval { $pin->interrupt_set(9, sub {}) };
like $@, qr/edge must be EDGE_FALLING/, 'interrupt_set() delegates validation to set_interrupt()';

done_testing();
