# TESTDOC: _restore_pin_alt() alt-31 recovery
use strict;
use warnings;

# HW-free coverage of Core::_restore_pin_alt - the safety-critical cleanup
# branch that decides HOW a pin is returned to its boot-time function. On the
# Pi 5 / RP1, get_alt() is a mode enum, so INPUT/OUTPUT must go via pinMode and
# "no function" (alt 31) via a `pinctrl` shell-out (pinModeAlt rejects it);
# real alts and all legacy (non-RP1) restores go via pinModeAlt. A regression
# here strands Pi-5 pins at teardown (the alt-31 issue). We mock every
# dispatch target so nothing touches a real GPIO.

my (@pinmode, @pinmodealt, @system_calls);
my $rp1       = 1;   # toggles pi_rp1_model() (RP1/Pi5 vs legacy Pi3/4)
my $system_rv = 0;   # controllable return of the pinctrl shell-out

BEGIN {
    # Intercept the pinctrl shell-out so the alt-31 branch never touches a real
    # GPIO; record its args and return a controllable status.
    *CORE::GLOBAL::system = sub { push @system_calls, [@_]; return $system_rv; };

    delete $ENV{NO_BOARD};
    delete $ENV{RPI_PIN_MODE};
}

use Test::More;
use RPi::WiringPi;

{
    no warnings 'redefine';
    *WiringPi::API::pi_rp1_model = sub { $rp1 };
    *WiringPi::API::pinMode      = sub { push @pinmode,    [@_]; };
    *WiringPi::API::pinModeAlt   = sub { push @pinmodealt, [@_]; };
}

my $pi = RPi::WiringPi->new(
    setup        => 'none',
    rpi_register => 0,
    shm_key      => 'rpi_restore_alt_t',
);
isa_ok $pi, 'RPi::WiringPi', "off-board object built";

sub reset_calls { @pinmode = (); @pinmodealt = (); @system_calls = (); }

# ===== RP1 / Pi 5 =====
$rp1 = 1;

reset_calls();
$pi->_restore_pin_alt(4, 0);
is_deeply \@pinmode,      [[4, 0]], "RP1 + INPUT(0): via pinMode";
is_deeply \@pinmodealt,   [],       "...not pinModeAlt";
is_deeply \@system_calls, [],       "...not pinctrl";

reset_calls();
$pi->_restore_pin_alt(4, 1);
is_deeply \@pinmode, [[4, 1]], "RP1 + OUTPUT(1): via pinMode";

reset_calls();
$system_rv = 0;
$pi->_restore_pin_alt(26, 31);
is_deeply \@system_calls, [['pinctrl', 'set', 26, 'no']], "RP1 + alt-31: via pinctrl";
is_deeply \@pinmode,      [], "...not pinMode";
is_deeply \@pinmodealt,   [], "...not pinModeAlt";

reset_calls();
$system_rv = 256;   # non-zero = pinctrl failed
my @warns;
{
    local $SIG{__WARN__} = sub { push @warns, $_[0] };
    $pi->_restore_pin_alt(26, 31);
}
like $warns[0], qr/Couldn't restore GPIO 26/, "RP1 + alt-31 + pinctrl failure warns";

reset_calls();
$system_rv = 0;
$pi->_restore_pin_alt(7, 4);
is_deeply \@pinmodealt,   [[7, 4]], "RP1 + real alt(4): via pinModeAlt";
is_deeply \@pinmode,      [], "...not pinMode";
is_deeply \@system_calls, [], "...not pinctrl";

# ===== Legacy Pi 3/4 (no RP1): everything routes through pinModeAlt =====
$rp1 = 0;

reset_calls();
$pi->_restore_pin_alt(7, 0);
is_deeply \@pinmodealt, [[7, 0]], "legacy + alt 0: pinModeAlt (NOT pinMode)";
is_deeply \@pinmode,    [], "...not pinMode";

reset_calls();
$pi->_restore_pin_alt(26, 31);
is_deeply \@pinmodealt,   [[26, 31]], "legacy + alt 31: pinModeAlt (NOT pinctrl)";
is_deeply \@system_calls, [], "...not pinctrl";

reset_calls();
$pi->_restore_pin_alt(7, 4);
is_deeply \@pinmodealt, [[7, 4]], "legacy + real alt(4): pinModeAlt";

$pi->cleanup;

done_testing();
