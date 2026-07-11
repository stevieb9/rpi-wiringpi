# TESTDOC: RPi::StepperMotor::A4988 unit (HW-free)
use strict;
use warnings;

use Test::More;

# Mirror of RPi::StepperMotor::A4988's HW-free tests (its t/05-params.t +
# t/10-logic.t), run here against the INSTALLED module. The driver drives the
# A4988 through WiringPi::API directly, or through an optional MCP23017
# expander. Handing it a mock expander keyed by pin number captures every
# mode()/write() call AND gates setup_gpio() off, so the STEP/DIR/MS logic, the
# degree-to-microstep math and every validation croak run with no motor, no
# expander and no Pi. t/353-a4988.t drives a real A4988 through a live MCP23017.
#
# Non-gated: needs no hardware and runs anywhere. Skips cleanly only when the
# (as-yet-unreleased) family leaf isn't installed.

BEGIN {
    if (! eval { require RPi::StepperMotor::A4988; 1 }){
        plan skip_all => "RPi::StepperMotor::A4988 not installed";
    }
}

# The redesigned (WiringPi::API + expander) build dropped the pi() accessor its
# earlier injected-transport version carried. Skip cleanly on the older build so
# this file passes until the expander-capable release is installed.
if (RPi::StepperMotor::A4988->can('pi')){
    plan skip_all => "installed RPi::StepperMotor::A4988 predates the expander interface";
}

use RPi::Const qw(:all);

my $mod = 'RPi::StepperMotor::A4988';

# --- construction + validation croaks (mirror of dist t/05-params.t) ---
#
# Passing an expander means new() skips setup_gpio() and every pin op lands on
# the mock, so nothing here touches hardware.

my $exp = MockExpander->new;

eval { $mod->new(expander => $exp); };
like $@, qr/step param/, "new() requires the step pin";

eval { $mod->new(expander => $exp, step => 23); };
like $@, qr/dir param/, "new() requires the dir pin";

eval { $mod->new(expander => $exp, step => 'abc', dir => 24); };
like $@, qr/step param/, "new() rejects a non-integer step pin";

eval { $mod->new(expander => $exp, step => 23, dir => 'abc'); };
like $@, qr/dir param/, "new() rejects a non-integer dir pin";

eval { $mod->new(expander => $exp, step => 23, dir => 24, ms1 => 17); };
like $@, qr/ms1, ms2 and ms3/, "new() rejects a partial MS pin set";

eval { $mod->new(expander => $exp, step => 23, dir => 24, enable => 'abc'); };
like $@, qr/enable param/, "new() validates optional control pins";

eval { $mod->new(expander => $exp, step => 23, dir => 24, mode => 'bogus'); };
like $@, qr/\$resolution param/, "new() validates the mode param";

eval { $mod->new(expander => $exp, step => 23, dir => 24, steps_per_rev => 0); };
like $@, qr/\$steps param/, "new() validates steps_per_rev";

eval { $mod->new(expander => $exp, step => 23, dir => 24, rpm => 0); };
like $@, qr/\$rpm param/, "new() rejects a zero rpm";

{
    my $m = $mod->new(expander => $exp, step => 23, dir => 24);

    eval { $m->cw('abc'); };
    like $@, qr/\$degrees param/, "cw() validates degrees";

    eval { $m->ccw('abc'); };
    like $@, qr/\$degrees param/, "ccw() validates degrees";

    eval { $m->step('abc'); };
    like $@, qr/\$count param/, "step() validates count";

    eval { $m->direction('sideways'); };
    like $@, qr/\$direction param/, "direction() validates its param";

    eval { $m->enable; };
    like $@, qr/enable pin/, "enable() croaks without an enable pin";

    eval { $m->sleep; };
    like $@, qr/sleep pin/, "sleep() croaks without a sleep pin";

    eval { $m->reset; };
    like $@, qr/reset pin/, "reset() croaks without a reset pin";
}

# --- logic + math (mirror of dist t/10-logic.t) ---

my $gpio = MockExpander->new;

my $m = $mod->new(
    expander => $gpio,
    step     => 1,
    dir      => 2,
    ms1      => 3,
    ms2      => 4,
    ms3      => 5,
    enable   => 6,
    sleep    => 7,
    reset    => 8,
    rpm      => 100_000,
);

isa_ok $m, $mod;
is $gpio->{mode}{1}, MCP23017_OUTPUT, "new() sets the STEP pin to output mode";
is $m->steps_per_rev, 200, "steps_per_rev defaults to 200";
is $m->mode, 'full', "mode defaults to full step";
is state($gpio, 2), HIGH, "DIR comes up high for the default cw direction";
is_deeply [map { state($gpio, $_) } 3, 4, 5], [LOW, LOW, LOW],
    "full step drives MS1/MS2/MS3 low";

clear($gpio, 1);
is $m->cw(360), 200, "cw(360) = 200 microsteps at full step";
is pulses($gpio, 1), 200, "...and that many STEP pulses went out";
is state($gpio, 2), HIGH, "cw drives DIR high";

clear($gpio, 1);
is $m->ccw(360), 200, "ccw(360) = 200 microsteps";
is state($gpio, 2), LOW, "ccw drives DIR low";

clear($gpio, 1);
is $m->cw(90), 50, "cw(90) is a quarter of a full turn";

is_deeply ms_after($m, $gpio, [3, 4, 5], 'sixteenth'), [HIGH, HIGH, HIGH], "sixteenth MS levels";
is_deeply ms_after($m, $gpio, [3, 4, 5], 'half'),      [HIGH, LOW, LOW],   "half MS levels";
is_deeply ms_after($m, $gpio, [3, 4, 5], 'quarter'),   [LOW, HIGH, LOW],   "quarter MS levels";
is_deeply ms_after($m, $gpio, [3, 4, 5], 'eighth'),    [HIGH, HIGH, LOW],  "eighth MS levels";

$m->mode('sixteenth');
clear($gpio, 1);
is $m->cw(18), 160, "cw(18) scales with sixteenth stepping (18/360 of 200 x 16)";

$m->mode('full');

clear($gpio, 1);
is $m->step(50), 50, "step(50) pulses STEP 50 times";
is pulses($gpio, 1), 50, "...confirmed in the write log";

clear($gpio, 1);
is $m->step(0), 0, "step(0) is a no-op";
is pulses($gpio, 1), 0, "...emitting no pulses";

# Power pins, all active low
is $m->disable, 0, "disable() returns 0";
is state($gpio, 6), HIGH, "disable() drives ENABLE high";
$m->enable;
is state($gpio, 6), LOW, "enable() drives ENABLE low";
is $m->sleep, 0, "sleep() returns 0";
is state($gpio, 7), LOW, "sleep() drives SLEEP low";
$m->wake;
is state($gpio, 7), HIGH, "wake() drives SLEEP high";

clear($gpio, 8);
is $m->reset, 0, "reset() returns 0";
is_deeply $gpio->{writes}{8}, [LOW, HIGH], "reset() pulses RESET low then high";

# Geometry feeds the math
$m->rpm(100_000);
is $m->steps_per_rev(400), 400, "steps_per_rev() sets and returns";
clear($gpio, 1);
is $m->cw(360), 400, "a 400 step/rev motor needs 400 microsteps per turn";

is $m->cleanup, 0, "cleanup() is a no-op with an expander, returns 0";

done_testing();

# Helpers

sub clear {
    my ($exp, $pin) = @_;
    @{ $exp->{writes}{$pin} } = ();
}
sub ms_after {
    my ($motor, $exp, $pins, $resolution) = @_;
    $motor->mode($resolution);
    return [map { state($exp, $_) } @{ $pins }];
}
sub pulses {
    my ($exp, $pin) = @_;
    return scalar grep { $_ == HIGH } @{ $exp->{writes}{$pin} };
}
sub state {
    my ($exp, $pin) = @_;
    my $writes = $exp->{writes}{$pin};
    return $writes && @{ $writes } ? $writes->[-1] : undef;
}

# Mock MCP23017 expander: records the mode set on each pin and every write to
# it, keyed by pin number. cleanup() is a no-op, as the real one's is from the
# driver's point of view.

package MockExpander;

sub new {
    return bless { mode => {}, writes => {} }, shift;
}
sub mode {
    my ($self, $pin, $mode) = @_;
    $self->{mode}{$pin} = $mode if defined $mode;
    return $self->{mode}{$pin};
}
sub write {
    my ($self, $pin, $value) = @_;
    push @{ $self->{writes}{$pin} }, $value;
    return $value;
}
sub cleanup { return 0; }
