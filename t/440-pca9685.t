# TESTDOC: PCA9685 16-channel PWM (I2C register readback)
use warnings;
use strict;

use lib 't/';

# Board-1 convenience: the PCA9685 will be mounted on board 1 eventually, but
# it isn't wired in yet, so RPI_BOARD_1 deliberately does NOT enable
# RPI_PCA9685 here - only the suite-wide RPI_BOARD gate. Once the chip lands
# on the board, add RPI_PCA9685 to the qw() list below. Runs in BEGIN so it
# lands before RPiTest's compile-time RPI_BOARD skip_all gate.
BEGIN {
    if ($ENV{RPI_BOARD_1}) {
        $ENV{$_} = 1 for qw(RPI_BOARD);
    }
}

use RPiTest;
use RPi::WiringPi;
use Test::More;

# RPi::PWM::PCA9685 tests - every assertion here reads the chip's registers back
# over I2C to confirm what it's set to output, independent of measuring any
# physical pin. This verifies the I2C writes landed correctly, and needs no
# wiring at all beyond the bus.
#
# Datasheet: https://www.nxp.com/docs/en/data-sheet/PCA9685.pdf
#
# Channel plan for the test platform:
#
#   LED0        reserved (purpose TBD)
#   LED1        board 1
#   LED2-LED5   other test boards
#   LED6-LED9   unassigned - used as scratch channels by this file
#   LED10-LED15 to be read by the MCP3008 (analog duty verification, future)

if (! $ENV{RPI_PCA9685}){
    plan skip_all => "RPI_PCA9685 environment variable not set\n";
}

if (! eval { require RPi::PWM::PCA9685; 1 }){
    plan skip_all => "RPi::PWM::PCA9685 is not installed\n";
}

rpi_running_test(__FILE__);

use constant {
    MODE1     => 0x00,
    MODE2     => 0x01,
    SUBADR1   => 0x02,
    PRE_SCALE => 0xFE,
    FULL      => 0x1000, # Bit 12 of an on/off value: the full-on/full-off flag
};

my $pca = RPi::PWM::PCA9685->new;

isa_ok $pca, 'RPi::PWM::PCA9685';

# Safety net: guarantee the chip is parked no matter how this file exits. The
# happy-path teardown below parks it and sets $parked, so this only fires if a
# croak (eg. a failed I2C write) kills the file first, leaving the outputs
# still driven. eval swallows the "device has been closed" croak if we somehow
# reach here after close().
my $parked = 0;
END { eval { $pca->off } if $pca && ! $parked }

{ # new() leaves the chip awake, with register auto-increment enabled

    my $mode1 = $pca->register(MODE1);

    ok $mode1 & 0x20, "MODE1 AI bit is set after new()";
    ok ! ($mode1 & 0x10), "MODE1 SLEEP bit is clear after new()";
}

{ # Read accessors - the configured bus/address, and the live drive type

    is $pca->addr, 0x40, "addr() returns the default I2C address";
    is $pca->device, '/dev/i2c-1', "device() returns the default I2C device";
    is $pca->drive, 'totem', "drive() reads totem-pole from MODE2";
}

{ # freq() - prescaler register readback, datasheet math

    my $freq = $pca->freq(1000);

    is $pca->register(PRE_SCALE), 5, "freq(1000) lands prescale 5 in the register";
    is sprintf('%.2f', $freq), '1017.25', "...and returns the actual quantised freq";

    $freq = $pca->freq(50);

    is $pca->register(PRE_SCALE), 121, "freq(50) lands prescale 121 in the register";
    is sprintf('%.2f', $freq), '50.03', "...and returns the actual quantised freq";
}

{ # pwm()/pwm_read() - raw ON/OFF ticks, including phase offset (scratch LED6)

    $pca->pwm(6, 1024, 3072);

    is_deeply [$pca->pwm_read(6)], [1024, 3072], "pwm() on/off ticks read back";
}

{ # duty()/duty_pct() (scratch LED6/LED7)

    $pca->duty(6, 2048);
    is_deeply [$pca->pwm_read(6)], [0, 2048], "duty(2048) reads back as 50%";

    $pca->duty_pct(7, 25);
    is_deeply [$pca->pwm_read(7)], [0, 1024], "duty_pct(25) reads back as 25%";
}

{ # full_on()/full_off() - the bit 12 flags (scratch LED8)

    $pca->full_on(8);
    is_deeply [$pca->pwm_read(8)], [FULL, 0], "full_on() sets the ON_H full flag";

    $pca->full_off(8);
    is_deeply [$pca->pwm_read(8)], [0, FULL], "full_off() sets the OFF_H full flag";
}

{ # servo_us() at 50 Hz (scratch LED9)

    $pca->servo_us(9, 1500);
    is_deeply [$pca->pwm_read(9)], [0, 307], "servo_us(1500) centre reads back as 307 ticks";

    $pca->servo_us(9, 2000);
    is_deeply [$pca->pwm_read(9)], [0, 410], "servo_us(2000) reads back as 410 ticks";

    $pca->servo_us(9, 0);
    is_deeply [$pca->pwm_read(9)], [0, FULL], "servo_us(0) releases the servo (full off)";
}

{ # The MCP3008-bound block, LED10-15: distinct duty per channel, read back

    # TODO board 1: once these six channels are wired to the MCP3008, verify
    # each duty below via ADC percent as well as by register readback

    for my $ch (10 .. 15){
        my $duty = ($ch - 9) * 512;

        $pca->duty($ch, $duty);

        is_deeply
            [$pca->pwm_read($ch)],
            [0, $duty],
            "ADC-bound channel $ch duty $duty reads back";
    }
}

{ # all_off() - the ALL_LED write loads every LEDn register (datasheet 7.3.4)

    $pca->all_off;

    for my $ch (6 .. 15){
        is_deeply [$pca->pwm_read($ch)], [0, FULL], "channel $ch is full-off after all_off()";
    }
}

{ # invert() - MODE2 INVRT readback

    $pca->invert;
    my $mode2 = $pca->register(MODE2);
    ok $mode2 & 0x10, "invert() sets MODE2 INVRT";
    is $pca->inverted, 1, "inverted() reads back the INVRT bit";

    $pca->invert(0);
    $mode2 = $pca->register(MODE2);
    ok ! ($mode2 & 0x10), "invert(0) clears MODE2 INVRT";
    is $pca->inverted, 0, "inverted() reflects invert(0)";
}

{ # sleep()/wake() - MODE1 SLEEP readback

    $pca->sleep;
    my $mode1 = $pca->register(MODE1);
    ok $mode1 & 0x10, "sleep() sets MODE1 SLEEP";
    is $pca->sleeping, 1, "sleeping() reads back the SLEEP bit";

    $pca->wake;
    $mode1 = $pca->register(MODE1);
    ok ! ($mode1 & 0x10), "wake() clears MODE1 SLEEP";
    is $pca->sleeping, 0, "sleeping() reflects wake()";
}

{ # status() - a live snapshot hashref, read back over the bus

    my $status = $pca->status;

    is ref $status, 'HASH', "status() returns a hashref";
    is $status->{addr}, 0x40, "status() reports the addr";
    is $status->{device}, '/dev/i2c-1', "status() reports the device";
    is $status->{drive}, 'totem', "status() reports the drive type";
    is $status->{inverted}, 0, "status() reports normal (non-inverted) logic";
    is $status->{sleeping}, 0, "status() reports the chip awake";
    is $status->{ext_clock}, 0, "status() reports the internal clock";
    is $status->{osc_hz}, 25000000, "status() reports the assumed oscillator";
    ok $status->{freq} > 0, "status() reports a positive freq";
}

{ # register() - raw byte write/readback on a harmless register (SUBADR1;
  # SUB1 response is disabled by default, so changing it has no effect)

    my $orig = $pca->register(SUBADR1);

    $pca->register(SUBADR1, 0xA4);
    is $pca->register(SUBADR1), 0xA4, "raw register() write reads back";

    $pca->register(SUBADR1, $orig);
    is $pca->register(SUBADR1), $orig, "...and restores to its original value";
}

{ # reset() - SWRST returns power-on defaults, then the module re-inits

    $pca->reset;

    is $pca->register(PRE_SCALE), 0x1E, "reset() restores the 200 Hz default prescale";

    my $mode1 = $pca->register(MODE1);
    ok $mode1 & 0x20, "...and the chip was re-initialised (AI back on)";
}

# Leave the chip in the board's rest state: 50 Hz, every channel off and the
# oscillator stopped. off() is all_off() plus sleep() - the tidy park-for-exit
# so the chip isn't left driving its outputs after the test process is gone.

$pca->freq(50);
$pca->off;
$parked = 1;

is $pca->register(PRE_SCALE), 121, "chip left at 50 Hz";
is_deeply [$pca->pwm_read(6)], [0, FULL], "off() leaves the channels full-off";
is $pca->sleeping, 1, "off() leaves the chip asleep";

$pca->close;

my $ok = eval { $pca->register(MODE1); 1 };
is $ok, undef, "method calls die after close()";
like $@, qr/device has been closed/, "...with the expected error";

rpi_check_pin_status();

done_testing();
