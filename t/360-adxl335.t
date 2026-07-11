# TESTDOC: ADXL335 accelerometer (live, through an ADC)
use warnings;
use strict;

use lib 't/';

# Convenience: RPI_ADXL335=1 flips on the board gate this file needs, so you
# don't export it by hand. Runs in BEGIN so it lands before RPiTest's
# compile-time RPI_BOARD skip_all gate.
BEGIN {
    if ($ENV{RPI_ADXL335}){
        $ENV{RPI_BOARD} = 1;
    }
}

use RPiTest;
use RPi::WiringPi;
use Test::More;

# ===========================================================================
# t/360-adxl335.t - RPi::Accelerometer::ADXL335 live integration, reached
#                   through $pi->accelerometer over a real ADC
# ===========================================================================
#
# WHAT THIS PROVES
#
#   The ADXL335 driver, built through RPi::WiringPi's accelerometer() accessor
#   and reading a REAL sensor through a REAL ADC, does the analog-to-g scaling
#   the way its HW-free unit test (t/359-adxl335_unit.t) only proves against a
#   mock ADC. The sensor is analog and open-loop, so we assert what a still
#   sensor makes deterministic: each axis reads a voltage inside the supply
#   rail; the acceleration vector's magnitude is ~1 g (gravity, orientation
#   independent); tilt() returns finite angles; and calibrate() yields a sane
#   per-axis zero point.
#
# WIRING (bench; NOT tied to a test-platform board)
#
#   An ADXL335 powered from 3.3 V, its XOUT/YOUT/ZOUT analog outputs wired to
#   three channels of an ADC (an ADS1115 by default). The ADC is built through
#   $pi->adc, so it follows that method's own bus wiring (the ADS1115 is I2C).
#   Leave the sensor STILL for the run - the gravity-magnitude check assumes it
#   isn't being moved.
#
#   Override the ADC model and channels via RPI_ADXL335_ADC / _X / _Y / _Z.
#
# GATE
#
#   RPI_ADXL335 - the ADXL335 + ADC are wired and powered. Needs a Pi
#   (RPI_BOARD, set for you by RPI_ADXL335). Skips cleanly when unset, or when
#   the driver isn't installed.
#
# ===========================================================================

if (! $ENV{RPI_ADXL335}){
    plan skip_all => "RPI_ADXL335 environment variable not set\n";
}

# Loaded at runtime, after the gate: an as-yet-unreleased family leaf, so a
# checkout without it installed still parses and skips rather than dying.
if (! eval { require RPi::Accelerometer::ADXL335; 1 }){
    plan skip_all => "RPi::Accelerometer::ADXL335 not installed\n";
}

rpi_running_test(__FILE__);

use constant {
    VS         => 3.3,      # Sensor supply / ADC reference, the driver default
    G_TOL      => 0.35,     # |accel| may sit 1 g +/- this at rest (part bias)
};

my $model = $ENV{RPI_ADXL335_ADC} // 'ADS1115';
my %chan  = (
    x => $ENV{RPI_ADXL335_X} // 0,
    y => $ENV{RPI_ADXL335_Y} // 1,
    z => $ENV{RPI_ADXL335_Z} // 2,
);

my $pi = RPi::WiringPi->new(label => 't/360-adxl335.t', shm_key => 'rpit');

my $accel;
my $cleaned = 0;

my $cleanup = sub {
    return if $cleaned;
    $cleaned = 1;
    $pi->cleanup;
};

local $SIG{INT}  = sub { $cleanup->(); exit 1; };
local $SIG{TERM} = sub { $cleanup->(); exit 1; };

my $ok = eval {
    my $adc = $pi->adc(model => $model);

    $accel = $pi->accelerometer(
        adc => $adc,
        x   => $chan{x},
        y   => $chan{y},
        z   => $chan{z},
    );

    isa_ok $accel, 'RPi::Accelerometer::ADXL335',
        "accelerometer() returns an ADXL335 driver";
    is $accel->adc, $adc, "the driver reads through the ADC we passed in";

    # Each axis output sits inside the supply rail
    my @v = $accel->volts;
    is scalar(@v), 3, "volts() returns three axes";
    ok !(grep { ! defined $_ || $_ < 0 || $_ > VS + 0.1 } @v),
        sprintf "each axis reads inside the 0-%.1f V rail (%.2f, %.2f, %.2f)", VS, @v;

    # At rest the acceleration vector is gravity: ~1 g, whichever way up the
    # sensor sits (magnitude is orientation independent)
    my @g = $accel->g;
    is scalar(@g), 3, "g() returns three axes";

    my $mag = sqrt($g[0]**2 + $g[1]**2 + $g[2]**2);
    ok abs($mag - 1) <= G_TOL,
        sprintf "acceleration magnitude %.3f g is ~1 g (gravity, +/-%.2f)", $mag, G_TOL;

    ok !(grep { abs($_) > 1 + G_TOL } @g),
        "no single axis exceeds ~1 g at rest";

    # Tilt is derived from that vector: two finite angles in degrees
    my ($pitch, $roll) = $accel->tilt;
    ok abs($pitch) <= 180 && abs($roll) <= 180,
        sprintf "tilt() returns sane pitch/roll (%.1f, %.1f deg)", $pitch, $roll;

    # A single-axis read agrees with the vector read
    is sprintf("%.3f", $accel->g('z')), sprintf("%.3f", $g[2]),
        "g('z') matches the z component of the vector read";

    # calibrate() (sensor level and still) yields a sane per-axis zero point
    my $zero = $accel->calibrate(20);
    is ref($zero), 'HASH', "calibrate() returns a per-axis zero point";
    ok !(grep { ! defined $zero->{$_} || $zero->{$_} < 0 || $zero->{$_} > VS } qw(x y z)),
        "calibrated zero points sit inside the supply rail";

    1;
};

my $err = $@;

$cleanup->();

if (! $ok){
    fail("ADXL335 live test died before completion: $err");
}

done_testing();
