# TESTDOC: RPi::Gyro::MPU6050::Deadband (HW-free)
use strict;
use warnings;

use Test::More;

# Functional coverage of RPi::Gyro::MPU6050::Deadband against the INSTALLED
# module: the windowed-smoothing + threshold-hysteresis behaviour that lets a
# consumer skip work while a noisy sensor is essentially still, plus the
# deadband() convenience factory on RPi::Gyro::MPU6050. All hardware-free - the
# filter reads no device, and the factory just constructs one. The gyro dist's
# t/15-deadband.t is the exhaustive mirror.
#
# Non-gated: needs no hardware; skips only when the (as-yet-unreleased) family
# leaf isn't installed.

BEGIN {
    if (! eval { require RPi::Gyro::MPU6050::Deadband; 1 }){
        plan skip_all => "RPi::Gyro::MPU6050::Deadband not installed";
    }
}

my $class = 'RPi::Gyro::MPU6050::Deadband';

# --- jitter within the band never reports a change; a real move does ---

my $f = $class->new(threshold => 1.0, window => 1);

$f->update(10);                 # the first update always establishes a baseline
ok $f->changed, "the first update establishes a baseline (reports changed)";

my $spurious = grep { $f->update($_); $f->changed } (10.3, 9.8, 10.4, 9.7, 10.2);
is $spurious, 0, "jitter within +/- threshold triggers no changes";
is $f->value, 10, "value() holds at the baseline through the jitter";

$f->update(12);                 # |12 - 10| = 2 > 1
ok $f->changed, "a genuine move past the band reports a change";
is $f->value, 12, "value() advances to the moved reading";

# --- the window smooths a lone spike, but not a sustained shift ---

my $w = $class->new(threshold => 1.0, window => 4);
$w->update(0) for 1 .. 4;       # settle the window at 0
ok ! $w->changed, "a settled stream reports no change";

$w->update(3);                  # window [0,0,0,3] -> mean 0.75 < 1
ok ! $w->changed, "a lone spike is smoothed below the threshold";

$w->update(3) while ! $w->changed;   # keep feeding 3s until the mean crosses
ok $w->changed, "a sustained shift eventually crosses the band";
cmp_ok $w->value, '>', 0, "the reported value moved toward the sustained level";

# --- the deadband() factory on the sensor class returns a filter ---

SKIP: {
    skip "RPi::Gyro::MPU6050 not loadable (needs RPi::I2C)", 4
        if ! eval { require RPi::Gyro::MPU6050; 1 };

    ok(
        RPi::Gyro::MPU6050->can('deadband'),
        "RPi::Gyro::MPU6050 exposes the deadband() factory",
    );

    my $made = RPi::Gyro::MPU6050->deadband(threshold => 0.5, window => 3);
    isa_ok $made, $class;
    is $made->threshold, 0.5, "factory passes the threshold through";
    is $made->window, 3, "factory passes the window through";
}

done_testing;
