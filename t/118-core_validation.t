# TESTDOC: Core arg validation (HW-free)
use strict;
use warnings;

BEGIN {
    # Force the HW-free 'none' setup path regardless of ambient env: no NO_BOARD
    # (so new()'s setup branch runs) and no pre-set RPI_PIN_MODE (so it doesn't
    # short-circuit to a real, already-initialised pin scheme).
    delete $ENV{NO_BOARD};
    delete $ENV{RPI_PIN_MODE};
}

use Test::More;
use RPi::WiringPi;
use RPi::Const qw(:all);

# HW-free core validation. setup=>'none' skips the wiringPi C setup (the pin
# scheme stays UNINIT), and a private shm_key + rpi_register=>0 keep us off the
# suite's 'rpit' segment and the t/110-114 counts. Every die/croak below fires
# before any GPIO, so this runs ungated, without a Pi. Does NOT use RPiTest
# (whose load-time RPI_BOARD gate would skip it).

my $pi = RPi::WiringPi->new(
    setup        => 'none',
    rpi_register => 0,
    shm_key      => 'rpi_core_validation_t',
);
isa_ok $pi, 'RPi::WiringPi', "new(setup=>'none') builds off-board";

# --- pin_to_gpio: an uninitialised scheme croaks (never an implicit undef) ---

eval { $pi->pin_to_gpio(18) };
like $@, qr/scheme not initial/, "pin_to_gpio() croaks when the scheme is uninitialised";

# --- device-factory argument validation (dies before any require/hardware) ---

eval { $pi->oled('nope') };
like $@, qr/requires one of the following models/, "oled() rejects an unknown model";

eval { $pi->oled('128x32') };
like $@, qr/not yet implemented/, "oled() rejects a whitelisted-but-unimplemented model";

eval { $pi->lcd() };
like $@, qr/requires pin configuration/, "lcd() rejects a missing pin config";

# rs is validated first, so a non-numeric rs fails before any pin is created.
eval { $pi->lcd(rs => 'x', strb => 2, d0 => 0, d1 => 0, d2 => 0, d3 => 0, d4 => 4, d5 => 5, d6 => 6, d7 => 7) };
like $@, qr/requires pin configuration/, "lcd() rejects a non-numeric pin value";

eval { $pi->expander(0x20, 'BOGUS') };
like $@, qr/unrecognized/, "expander() rejects an unknown type";

eval { $pi->stepper_motor() };
like $@, qr/requires an arrayref of pins/, "stepper_motor() requires pins";

# --- Meta argument croaks (validate before touching shared memory) ---

eval { $pi->meta_store() };
like $@, qr/requires a hash reference/, "meta_store() requires a hashref";

eval { $pi->meta_get() };
like $@, qr/must send in a name/, "meta_get() requires a name";

eval { $pi->meta_set() };
like $@, qr/must send in a name/, "meta_set() requires a name";

eval { $pi->meta_set('slot') };
like $@, qr/must supply a hash reference/, "meta_set() requires a hashref";

eval { $pi->meta_delete() };
like $@, qr/must send in a name/, "meta_delete() requires a name";

eval { $pi->meta_key_check() };
like $@, qr/requires a key/, "meta_key_check() requires a key";

# --- pin_map returns a hashref even with an uninitialised scheme ---

is ref $pi->pin_map, 'HASH', "pin_map() returns a hashref (empty under UNINIT)";

# --- servo()/pwm_*() require root (the guard is HW-free when run as non-root) ---

SKIP: {
    skip "running as root - the non-root PWM/servo guards aren't exercised", 4 if $> == 0;
    eval { $pi->servo(18) };
    like $@, qr/root/, "servo() requires root";
    eval { $pi->pwm_mode(0) };
    like $@, qr/root/, "pwm_mode() requires root";
    eval { $pi->pwm_clock(192) };
    like $@, qr/root/, "pwm_clock() requires root";
    eval { $pi->pwm_range(1023) };
    like $@, qr/root/, "pwm_range() requires root";
}

$pi->cleanup;

done_testing();
