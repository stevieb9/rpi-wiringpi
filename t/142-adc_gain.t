use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

# Verifies the ADS1115 gain handling through the $pi->adc integration path: the
# gain => constructor arg is applied (the V5 fix), and the PGA is actuated on
# real silicon. Requires RPi::ADC::ADS 1.03 (samples()/gain-arg fix).

rpi_sudo_check();

my $mod = 'RPi::WiringPi';

if ($> == 0){
    $ENV{RPI_BOARD} = 1;
    $ENV{RPI_ADC}   = 1;
    $ENV{RPI_I2C}   = 1;
}

if (! $ENV{RPI_ADC}){
    plan skip_all => "RPI_ADC environment variable not set\n";
}

if (! $ENV{RPI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "RPI_BOARD environment variable not set\n";
}

if ($> != 0 && $ENV{RPI_SUDO}){
    print "enforcing sudo for PWM tests...\n";
    system("sudo", $^X, "-I", "blib/lib", $0);
    exit;
}

rpi_i2c_check();

rpi_running_test(__FILE__);

# gain index -> config-register bits (PGA, bits 11-9); index 1 (0x200,
# +/-4.096V) is the default
my %gain = (
    0 => 0x000,
    1 => 0x200,
    2 => 0x400,
    3 => 0x600,
    4 => 0x800,
    5 => 0xA00,
    6 => 0xC00,
    7 => 0xE00,
);

my $pi = $mod->new(label => 't/142-adc_gain.t', shm_key => 'rpit');

{ # the gain => arg reaches the driver through $pi->adc (the V5 fix). FAILS on
  # the old constructor, which passed mode in place of gain.
    for my $g (0, 2, 4, 7){
        my $adc = $pi->adc(addr => 0x48, gain => $g);
        is $adc->gain, $gain{$g}, "\$pi->adc(gain => $g) applies the gain ($gain{$g})";
    }
}

{ # mode must not leak into gain
    my $adc = $pi->adc(addr => 0x48, mode => 0);
    is $adc->gain, $gain{1}, "\$pi->adc(mode => 0) leaves gain at the default";
}

if (! $ENV{NO_BOARD}) {

    # Actuate the PGA on real silicon. A fixed PWM-derived voltage sits on ADC
    # channel 0; reading raw() at increasing gain must give a rising count
    # (smaller FSR -> more counts/volt). We assert DIRECTION, not a precise
    # ratio: the RC-filter source impedance loads the PGA (and percent()/volts()
    # still hard-code 4.096V FSR - a separate bug), so the exact step is
    # rig-dependent (~1.5x here). raw() is used deliberately: it reflects the
    # PGA, whereas percent()/volts() do not (yet).

    my $adc = $pi->adc(addr => 0x48, samples => 60);

    my $pin = $pi->pin(18);
    $pin->mode(PWM_OUT);
    $pin->pwm(300);
    select(undef, undef, undef, 0.3);

    $adc->gain(0);
    my $r0 = $adc->raw(0);
    $adc->gain(1);
    my $r1 = $adc->raw(0);
    $adc->gain(2);
    my $r2 = $adc->raw(0);

    cmp_ok $r0, '>', 0,   "ADC reads the PWM-derived input on channel 0 (raw $r0 > 0)";
    cmp_ok $r1, '>', $r0, "raw rises from gain 0 to gain 1 ($r0 -> $r1): PGA actuated";
    cmp_ok $r2, '>', $r1, "raw rises from gain 1 to gain 2 ($r1 -> $r2): PGA actuated";

    # V6: volts() now scales by the programmed PGA, so the SAME input reads the
    # same voltage regardless of gain (the raw code changes, the scaled voltage
    # does not). Gains 0 and 1 are high-impedance (negligible PGA loading), so
    # they agree closely; before the fix volts() hard-coded 4.096V FSR and the
    # two readings differed by the FSR ratio (~1.5x here).
    $adc->gain(0);
    my $v0 = $adc->volts(0);
    $adc->gain(1);
    my $v1 = $adc->volts(0);

    cmp_ok $v1, '>', 0.1, "volts reads a usable level (gain 1: $v1 V)";

    my $dev = abs($v0 - $v1) / $v1;
    cmp_ok $dev, '<', 0.10, sprintf(
        "volts is gain-consistent: gain0=%.4fV gain1=%.4fV (%.1f%% apart)",
        $v0, $v1, $dev * 100,
    );

    $pin->pwm(0);
    $pin->mode(INPUT);

    $pi->cleanup;

    rpi_check_pin_status();
}

done_testing();
