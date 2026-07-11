# TESTDOC: RPi::Accelerometer::ADXL335 unit (HW-free)
use strict;
use warnings;

use Test::More;

# Mirror of RPi::Accelerometer::ADXL335's HW-free tests (its t/05-params.t +
# t/10-logic.t), run here against the INSTALLED module. The driver takes its
# ADC transport by injection, so mock ADCs whose volts()/percent() we control
# exercise the scaling, calibration and tilt math and every validation croak
# with no sensor and no ADC hardware. t/360-adxl335.t drives a real ADXL335
# through a real ADC.
#
# Non-gated: needs no hardware and runs anywhere. Skips cleanly only when the
# (as-yet-unreleased) family leaf isn't installed.

BEGIN {
    if (! eval { require RPi::Accelerometer::ADXL335; 1 }){
        plan skip_all => "RPi::Accelerometer::ADXL335 not installed";
    }
}

my $mod = 'RPi::Accelerometer::ADXL335';

# --- construction + validation croaks (mirror of dist t/05-params.t) ---

my $adc = MockADC->new;

eval { $mod->new; };
like $@, qr/adc param/, "new() requires the adc param";

eval { $mod->new(adc => 'not an object'); };
like $@, qr/adc param/, "new() rejects an unblessed adc param";

eval { $mod->new(adc => NoReadADC->new, x => 0, y => 1, z => 2); };
like $@, qr/volts\(\) or percent\(\)/, "new() rejects an ADC lacking volts()/percent()";

eval { $mod->new(adc => $adc); };
like $@, qr/x param/, "new() requires the x channel";

eval { $mod->new(adc => $adc, x => 0, z => 2); };
like $@, qr/y param/, "new() requires the y channel";

eval { $mod->new(adc => $adc, x => 0, y => 1); };
like $@, qr/z param/, "new() requires the z channel";

eval { $mod->new(adc => $adc, x => 'abc', y => 1, z => 2); };
like $@, qr/x param/, "new() rejects a non-integer channel";

eval { $mod->new(adc => $adc, x => 0, y => 1, z => 2, vs => 0); };
like $@, qr/vs param/, "new() rejects a zero vs";

eval { $mod->new(adc => $adc, x => 0, y => 1, z => 2, vref => -1); };
like $@, qr/vref param/, "new() rejects a bad vref";

{
    my $a = $mod->new(adc => $adc, x => 0, y => 1, z => 2);

    eval { $a->g('w'); };
    like $@, qr/\$axis param/, "g() validates its axis";

    eval { $a->volts('w'); };
    like $@, qr/\$axis param/, "volts() validates its axis";

    eval { $a->sensitivity(0); };
    like $@, qr/\$v_per_g param/, "sensitivity() validates its param";

    eval { $a->zero_g('nope'); };
    like $@, qr/\$offsets param/, "zero_g() rejects a non-hashref";

    eval { $a->calibrate(0); };
    like $@, qr/\$samples param/, "calibrate() validates its sample count";
}

# --- scaling / calibration / tilt math (mirror of dist t/10-logic.t) ---

my $accel = $mod->new(adc => $adc, x => 0, y => 1, z => 2);

isa_ok $accel, $mod;
is $accel->adc, $adc, "adc() exposes the transport object";

is_deeply $accel->zero_g, { x => 1.65, y => 1.65, z => 1.65 },
    "zero g defaults to vs / 2 on all axes";
is sprintf("%.2f", $accel->sensitivity), '0.33', "sensitivity defaults to 0.1 x vs";

MockADC->set(0, 1.65);
MockADC->set(1, 1.98);
MockADC->set(2, 1.32);

is_deeply [map { sprintf "%.2f", $_ } $accel->volts], ['1.65', '1.98', '1.32'],
    "volts() maps each axis to its ADC channel";
is sprintf("%.2f", $accel->volts('y')), '1.98', "volts() takes a single axis";

is_deeply [map { sprintf "%.4f", $_ } $accel->g], ['0.0000', '1.0000', '-1.0000'],
    "g() converts each axis' voltage to g";
is sprintf("%.4f", $accel->g('z')), '-1.0000', "g() takes a single axis";

# Channel mapping is per-axis, not positional
my $mapped = $mod->new(adc => $adc, x => 5, y => 3, z => 7);
MockADC->set(5, 2.0);
MockADC->set(3, 1.0);
MockADC->set(7, 0.5);
is_deeply [map { sprintf "%.2f", $_ } $mapped->volts], ['2.00', '1.00', '0.50'],
    "channel mapping is per-axis, not positional";

# vs scales the zero point and sensitivity
my $vs3 = $mod->new(adc => $adc, x => 0, y => 1, z => 2, vs => 3);
is_deeply $vs3->zero_g, { x => 1.5, y => 1.5, z => 1.5 }, "zero g scales with vs";
is sprintf("%.2f", $vs3->sensitivity), '0.30', "sensitivity scales with vs";

# Percent-only ADCs scale by vref
my $pct = $mod->new(adc => MockPctADC->new, x => 0, y => 1, z => 2);
MockPctADC->set(0, 50);
MockPctADC->set(1, 60);
MockPctADC->set(2, 40);
is_deeply [map { sprintf "%.3f", $_ } $pct->volts], ['1.650', '1.980', '1.320'],
    "percent-only ADCs scale by vref (defaulting to vs)";

# calibrate() sets x/y zero to the mean, z a full g lower
my $cal = $mod->new(adc => $adc, x => 0, y => 1, z => 2);
MockADC->set(0, 1.60);
MockADC->set(1, 1.70);
MockADC->set(2, 1.98);
my $measured = $cal->calibrate(4);
is_deeply [map { sprintf "%.4f", $measured->{$_} } qw(x y z)],
    ['1.6000', '1.7000', '1.6500'],
    "calibrate() sets x/y zero to the mean, z a full g lower";
is sprintf("%.4f", $cal->g('z')), '1.0000', "a calibrated level sensor reads +1 g on z";

# tilt(): level, then +X up, then +Y up
my $t = $mod->new(adc => $adc, x => 0, y => 1, z => 2);
MockADC->set(0, 1.65); MockADC->set(1, 1.65); MockADC->set(2, 1.98);
is_deeply [map { sprintf "%.1f", $_ } $t->tilt], ['0.0', '0.0'],
    "tilt() reads level when flat, top side up";
MockADC->set(0, 1.98); MockADC->set(1, 1.65); MockADC->set(2, 1.65);
is_deeply [map { sprintf "%.1f", $_ } $t->tilt], ['90.0', '0.0'],
    "tilt() pitch reads +90 with the +X end straight up";
MockADC->set(0, 1.65); MockADC->set(1, 1.98); MockADC->set(2, 1.65);
is_deeply [map { sprintf "%.1f", $_ } $t->tilt], ['0.0', '90.0'],
    "tilt() roll reads +90 with the +Y end straight up";

done_testing();

# The stand-in transports: MockADC reports volts per channel, MockPctADC
# reports 0-100 percent, and NoReadADC offers neither (the unusable ADC new()
# must reject).

package MockADC;

my %reads;

sub new {
    return bless {}, shift;
}
sub set {
    my (undef, $channel, @values) = @_;
    $reads{$channel} = [@values];
}
sub volts {
    my (undef, $channel) = @_;
    my $queue = $reads{$channel};
    return @{$queue} > 1 ? shift @{$queue} : $queue->[0];
}

package MockPctADC;

my %pct;

sub new {
    return bless {}, shift;
}
sub set {
    my (undef, $channel, $value) = @_;
    $pct{$channel} = $value;
}
sub percent {
    my (undef, $channel) = @_;
    return $pct{$channel};
}

package NoReadADC;

sub new {
    return bless {}, shift;
}
