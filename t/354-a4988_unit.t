# TESTDOC: RPi::StepperMotor::A4988 unit (HW-free)
use strict;
use warnings;

use Test::More;

# Mirror of RPi::StepperMotor::A4988's HW-free tests (its t/05-params.t +
# t/10-logic.t), run here against the INSTALLED module. The driver takes its
# GPIO transport by injection, so a mock Pi whose pins record every mode()/
# write() call exercises the STEP/DIR/MS logic, the degree-to-microstep math
# and every validation croak with no motor and no Pi attached. t/353-a4988.t
# drives a real A4988 on live GPIO.
#
# Non-gated: this file needs no hardware and runs anywhere. It skips cleanly
# only when the (as-yet-unreleased) family leaf isn't installed.

BEGIN {
    if (! eval { require RPi::StepperMotor::A4988; 1 }){
        plan skip_all => "RPi::StepperMotor::A4988 not installed";
    }
}

my $mod = 'RPi::StepperMotor::A4988';

# --- construction + validation croaks (mirror of dist t/05-params.t) ---

my $pi = MockPi->new;

eval { $mod->new; };
like $@, qr/pi param/, "new() croaks without a pi param";

eval { $mod->new(pi => 'not an object'); };
like $@, qr/pi param/, "new() croaks with an unblessed pi param";

eval { $mod->new(pi => NoPinPi->new); };
like $@, qr/pin\(\) method/, "new() croaks if the pi object can't pin()";

eval { $mod->new(pi => $pi); };
like $@, qr/step param/, "new() requires the step pin";

eval { $mod->new(pi => $pi, step => 23); };
like $@, qr/dir param/, "new() requires the dir pin";

eval { $mod->new(pi => $pi, step => 'abc', dir => 24); };
like $@, qr/step param/, "new() rejects a non-integer step pin";

eval { $mod->new(pi => $pi, step => 23, dir => 24, ms1 => 17); };
like $@, qr/ms1, ms2 and ms3/, "new() rejects a partial MS pin set";

eval { $mod->new(pi => $pi, step => 23, dir => 24, mode => 'bogus'); };
like $@, qr/\$resolution param/, "new() validates the mode param";

eval { $mod->new(pi => $pi, step => 23, dir => 24, steps_per_rev => 0); };
like $@, qr/\$steps param/, "new() validates steps_per_rev";

eval { $mod->new(pi => $pi, step => 23, dir => 24, rpm => 0); };
like $@, qr/\$rpm param/, "new() rejects a zero rpm";

eval { $mod->new(pi => BadPinPi->new, step => 23, dir => 24); };
like $@, qr/mode\(\) and write\(\)/, "new() rejects pins without mode()/write()";

{
    my $m = $mod->new(pi => $pi, step => 23, dir => 24);

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

my $gpio = MockPi->new;

my $m = $mod->new(
    pi     => $gpio,
    step   => 1,
    dir    => 2,
    ms1    => 3,
    ms2    => 4,
    ms3    => 5,
    enable => 6,
    sleep  => 7,
    reset  => 8,
    rpm    => 100_000,
);

my $step   = $gpio->pin(1);
my $dir    = $gpio->pin(2);
my @ms     = map { $gpio->pin($_) } 3, 4, 5;
my $enable = $gpio->pin(6);
my $slp    = $gpio->pin(7);
my $rst    = $gpio->pin(8);

isa_ok $m, $mod;
is $m->pi, $gpio, "pi() exposes the injected GPIO object";
is $step->{mode}, 1, "new() sets the STEP pin to output mode";
is $m->steps_per_rev, 200, "steps_per_rev defaults to 200";
is $m->mode, 'full', "mode defaults to full step";
is state($dir), 1, "DIR comes up high for the default cw direction";
is_deeply [map { state($_) } @ms], [0, 0, 0], "full step drives MS1/MS2/MS3 low";

clear($step);
is $m->cw(360), 200, "cw(360) = 200 microsteps at full step";
is pulses($step), 200, "...and that many STEP pulses went out";
is state($dir), 1, "cw drives DIR high";

clear($step);
is $m->ccw(360), 200, "ccw(360) = 200 microsteps";
is state($dir), 0, "ccw drives DIR low";

clear($step);
is $m->cw(90), 50, "cw(90) is a quarter of a full turn";

is_deeply ms_after($m, \@ms, 'sixteenth'), [1, 1, 1], "sixteenth MS levels";
is_deeply ms_after($m, \@ms, 'half'),      [1, 0, 0], "half MS levels";
is_deeply ms_after($m, \@ms, 'quarter'),   [0, 1, 0], "quarter MS levels";
is_deeply ms_after($m, \@ms, 'eighth'),    [1, 1, 0], "eighth MS levels";

$m->mode('sixteenth');
clear($step);
is $m->cw(18), 160, "cw(18) scales with sixteenth stepping (18/360 of 200 x 16)";

$m->mode('full');

clear($step);
is $m->step(50), 50, "step(50) pulses STEP 50 times";
is pulses($step), 50, "...confirmed in the write log";

clear($step);
is $m->step(0), 0, "step(0) is a no-op";
is pulses($step), 0, "...emitting no pulses";

# Power pins, all active low
is $m->disable, 0, "disable() returns 0";
is state($enable), 1, "disable() drives ENABLE high";
$m->enable;
is state($enable), 0, "enable() drives ENABLE low";
is $m->sleep, 0, "sleep() returns 0";
is state($slp), 0, "sleep() drives SLEEP low";
$m->wake;
is state($slp), 1, "wake() drives SLEEP high";

clear($rst);
is $m->reset, 0, "reset() returns 0";
is_deeply $rst->{writes}, [0, 1], "reset() pulses RESET low then high";

# Geometry feeds the math
$m->rpm(100_000);
is $m->steps_per_rev(400), 400, "steps_per_rev() sets and returns";
clear($step);
is $m->cw(360), 400, "a 400 step/rev motor needs 400 microsteps per turn";

$m->cleanup;
is $step->{mode}, 0, "cleanup() returns the pins to input mode";
is state($step), 0, "...after driving them low";

done_testing();

# Helpers

sub clear {
    my ($pin) = @_;
    @{ $pin->{writes} } = ();
}
sub ms_after {
    my ($motor, $pins, $resolution) = @_;
    $motor->mode($resolution);
    return [map { state($_) } @{ $pins }];
}
sub pulses {
    my ($pin) = @_;
    return scalar grep { $_ == 1 } @{ $pin->{writes} };
}
sub state {
    my ($pin) = @_;
    return @{ $pin->{writes} } ? $pin->{writes}[-1] : undef;
}

# Mock GPIO transport: MockPi hands out (and caches) one MockPin per pin
# number; MockPin records its mode and every write. NoPinPi/BadPinPi are the
# unusable transports new() must reject.

package MockPi;

sub new {
    return bless { pins => {} }, shift;
}
sub pin {
    my ($self, $num) = @_;
    return $self->{pins}{$num} ||= MockPin->new($num);
}

package MockPin;

sub new {
    my ($class, $num) = @_;
    return bless { num => $num, mode => undef, writes => [] }, $class;
}
sub mode {
    my ($self, $mode) = @_;
    $self->{mode} = $mode if defined $mode;
    return $self->{mode};
}
sub write {
    my ($self, $value) = @_;
    push @{ $self->{writes} }, $value;
    return $value;
}

package NoPinPi;

sub new {
    return bless {}, shift;
}

package BadPinPi;

sub new {
    return bless {}, shift;
}
sub pin {
    # An unblessed reference has neither mode() nor write()
    return {};
}
