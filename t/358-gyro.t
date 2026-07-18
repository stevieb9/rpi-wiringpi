# TESTDOC: MPU-6050 IMU (live, over I2C)
use warnings;
use strict;

use lib 't/';

# Convenience: RPI_GYRO=1 flips on the board gate this file needs, so you don't
# export it by hand. Runs in BEGIN so it lands before RPiTest's compile-time
# RPI_BOARD skip_all gate.
BEGIN {
    if ($ENV{RPI_GYRO}){
        $ENV{RPI_BOARD} = 1;
    }
}

use RPiTest;
use RPi::WiringPi;
use Test::More;

# ===========================================================================
# t/358-gyro.t - RPi::Gyro::MPU6050 live integration, reached through
#                $pi->gyro over the I2C bus
# ===========================================================================
#
# WHAT THIS PROVES
#
#   The MPU-6050 driver, built through RPi::WiringPi's gyro() accessor, talks to
#   a REAL sensor over I2C the way its HW-free unit tests (the dist's mocked
#   suite, mirrored by t/357 for the deadband filter) only prove against an
#   in-memory register file. We assert what a motionless sensor makes
#   deterministic: the WHO_AM_I identity register; the power-on register state;
#   an accelerometer vector whose magnitude is ~1 g (gravity, orientation
#   independent); gyro rates near zero once calibrated; a sane die temperature;
#   and that sleep()/wake()/reset() move the power-management register as
#   documented.
#
# WIRING (bench; NOT tied to a test-platform board)
#
#   An MPU-6050 on the I2C bus: VCC (3-5 V), GND, SDA -> GPIO2, SCL -> GPIO3.
#   This platform ties AD0 HIGH, so the gyro answers at 0x69 (the default here),
#   clear of the DS3231 RTC at 0x68; AD0 low would put it back at 0x68. Leave the
#   sensor STILL for the run - the gyro-at-rest and gravity-vector checks assume
#   it isn't being moved.
#
#   Override the address or device via RPI_GYRO_ADDR / RPI_GYRO_DEVICE.
#
# GATE
#
#   RPI_GYRO - the MPU-6050 is wired and powered. Needs a Pi (RPI_BOARD, set for
#   you by RPI_GYRO). Skips cleanly when unset, or when the driver isn't
#   installed.
#
# ===========================================================================

if (! $ENV{RPI_GYRO}){
    plan skip_all => "RPI_GYRO environment variable not set\n";
}

# Loaded at runtime, after the gate: an as-yet-unreleased family leaf, so a
# checkout without it installed still parses and skips rather than dying.
if (! eval { require RPi::Gyro::MPU6050; 1 }){
    plan skip_all => "RPi::Gyro::MPU6050 not installed\n";
}

rpi_running_test(__FILE__);

use constant {
    REG_PWR_MGMT_1  => 0x6B,
    REG_WHO_AM_I    => 0x75,
    WHO_AM_I_ID     => 0x68,
    PM1_SLEEP       => 0x40,
    PM1_CLKSEL_PLL  => 0x01,
    ACCEL_G_TOL     => 0.30,    # |accel| may sit 1 g +/- this at rest
    GYRO_STILL_TOL  => 10,      # deg/s a calibrated, still gyro may still read
};

my $addr   = $ENV{RPI_GYRO_ADDR}   // 0x69;
my $device = $ENV{RPI_GYRO_DEVICE} // '/dev/i2c-1';

my $pi = RPi::WiringPi->new(label => 't/358-gyro.t', shm_key => 'rpit');

my $mpu;
my $cleaned = 0;

my $cleanup = sub {
    return if $cleaned;
    $cleaned = 1;
    # Leave the IMU asleep (~10uA vs ~3.9mA) however this file exits - the
    # body's reset() leaves it awake otherwise
    $mpu->sleep if $mpu;
    $mpu->close if $mpu;
    $pi->cleanup;
};

local $SIG{INT}  = sub { $cleanup->(); exit 1; };
local $SIG{TERM} = sub { $cleanup->(); exit 1; };

my $ok = eval {
    $mpu = $pi->gyro(addr => $addr, device => $device);

    isa_ok $mpu, 'RPi::Gyro::MPU6050',
        "gyro() returns an MPU-6050 driver";

    # Identity + power-on state, straight from the chip's registers
    is $mpu->register(REG_WHO_AM_I), WHO_AM_I_ID,
        "WHO_AM_I reports the MPU-6050 identity (0x68)";
    is $mpu->register(REG_PWR_MGMT_1), PM1_CLKSEL_PLL,
        "new() leaves the chip awake on the X gyro PLL clock";

    is $mpu->accel_range, 2,  "accel range is the power-on +/-2 g";
    is $mpu->gyro_range,  250, "gyro range is the power-on +/-250 deg/s";

    # Accelerometer: at rest the vector is gravity, ~1 g, whichever way up the
    # sensor sits. Magnitude is orientation independent, so it needs no fixed
    # mounting to assert.
    my @a = $mpu->accel;
    is scalar(@a), 3, "accel() returns three axes";

    my $mag = sqrt($a[0]**2 + $a[1]**2 + $a[2]**2);
    ok abs($mag - 1) <= ACCEL_G_TOL,
        sprintf "accel magnitude %.3f g is ~1 g (gravity, +/-%.2f)", $mag, ACCEL_G_TOL;

    ok !(grep { abs($_) > 2 + ACCEL_G_TOL } @a),
        "each accel axis is within the +/-2 g full-scale range";

    # Tilt is derived from that vector: two finite angles in degrees
    my ($pitch, $roll) = $mpu->tilt;
    ok abs($pitch) <= 180 && abs($roll) <= 180,
        sprintf "tilt() returns sane pitch/roll (%.1f, %.1f deg)", $pitch, $roll;

    # Die temperature: a sane room-ish reading in celsius
    my $temp = $mpu->temp;
    ok $temp > -10 && $temp < 70,
        sprintf "temp() returns a sane die temperature (%.1f C)", $temp;

    # Gyro: zero the resting bias, then a still sensor reads near zero on every
    # axis (within a generous band - assumes the bench isn't being bumped)
    my $off = $mpu->calibrate_gyro(100);
    is ref($off), 'HASH', "calibrate_gyro() returns per-axis offsets";

    my @g = $mpu->gyro;
    is scalar(@g), 3, "gyro() returns three axes";
    ok !(grep { abs($_) > GYRO_STILL_TOL } @g),
        sprintf "a calibrated, still gyro reads near zero (%.2f, %.2f, %.2f deg/s)", @g;

    # Power management: sleep sets the SLEEP bit, wake clears it
    $mpu->sleep;
    ok $mpu->register(REG_PWR_MGMT_1) & PM1_SLEEP,
        "sleep() sets the PWR_MGMT_1 SLEEP bit";
    $mpu->wake;
    ok !($mpu->register(REG_PWR_MGMT_1) & PM1_SLEEP),
        "wake() clears the PWR_MGMT_1 SLEEP bit";

    # reset() power-cycles the chip and re-initialises it exactly as new() does
    is $mpu->reset, 0, "reset() returns 0";
    is $mpu->register(REG_WHO_AM_I), WHO_AM_I_ID,
        "the chip still identifies after reset()";
    is $mpu->register(REG_PWR_MGMT_1), PM1_CLKSEL_PLL,
        "reset() re-initialises to the awake PLL-clock state";

    # Low-power cycle mode + per-axis standby. Guarded for the install lag:
    # cycle()/accel_standby()/gyro_standby() ship in a newer RPi::Gyro::MPU6050.
    SKIP: {
        skip "installed RPi::Gyro::MPU6050 lacks cycle()/standby()", 5
            unless $mpu->can('cycle') && $mpu->can('gyro_standby');

        is $mpu->cycle(5), 5, "cycle(5) enables low-power cycle mode at 5 Hz";
        ok $mpu->register(REG_PWR_MGMT_1) & 0x20, "...the CYCLE bit is set";
        $mpu->wake;
        is $mpu->cycle, 0, "wake() exits cycle mode";

        is_deeply [$mpu->gyro_standby(['x', 'y', 'z'])], ['x', 'y', 'z'],
            "gyro_standby() puts all three gyro axes in standby";
        $mpu->wake;
        is_deeply [$mpu->gyro_standby], [], "wake() clears the standby bits";
    }

    1;
};

my $err = $@;

$cleanup->();

if (! $ok){
    fail("MPU-6050 live test died before completion: $err");
}

done_testing();
