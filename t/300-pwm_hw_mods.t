use strict;
use warnings;

use lib 't/';

# Board-2 convenience: set RPI_BOARD_2=1 and every env gate the board-2 suite
# needs is enabled automatically, instead of exporting each one by hand. Runs in
# BEGIN so it lands before RPiTest's compile-time RPI_BOARD skip_all gate.
BEGIN {
    if ($ENV{RPI_BOARD_2}) {
        $ENV{$_} = 1 for qw(
            RPI_BOARD RPI_SUDO RPI_I2C RPI_ADC RPI_MCP3008
            RPI_MCP4922 RPI_SERVO RPI_SHIFTREG RPI_DIGIPOT
        );
    }
}

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

rpi_sudo_check();

my $mod = 'RPi::WiringPi';

if ($> == 0){
    # The sudo re-exec below scrubs the environment, so (re)assert the gates
    # the root run needs - matching t/305-pwm_i2c_adc.t. Without RPI_I2C here,
    # rpi_i2c_check() below skips the whole file under sudo.
    $ENV{RPI_BOARD} = 1;
    $ENV{RPI_ADC}   = 1;
    $ENV{RPI_I2C}   = 1;
}

if (! $ENV{RPI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "RPI_BOARD environment variable not set\n";
}

if ($> != 0){
    print "enforcing sudo for PWM tests...\n";
    # Re-exec with $^X (the running perl) so sudo doesn't fall back to the
    # system perl, which lacks our perlbrew-installed prerequisites
    system("sudo", $^X, "-I", "blib/lib", $0);
    exit;
}

rpi_i2c_check();

rpi_running_test(__FILE__);

use constant {
    LEFT    => 60,
    RIGHT   => 255,
    CENTRE  => 150,
    PIN     => 18,
    DIVISOR => 192,
    RANGE   => 2000,
    ANALOG  => 0,
    STEP    => 10,
    SAMPLES => 40,
    SETTLE  => 0.05,
};

my $pi = $mod->new(label => 't/300-pwm_hw_mods.t', shm_key => 'rpit');

my $adc = $pi->adc(addr => 0x48);   # ADS1015 #1 (PWM feedback on ch 0)

if (! $ENV{NO_BOARD}) {

    my $pin = $pi->pin(PIN, 't/300-pwm_hw_mods.t');
    $pin->mode(INPUT);
    $pin->pull(PUD_DOWN);

    is $pin->mode, INPUT, "pin in INPUT ok";
    
    my $o; # analog input
   
    $o = $adc->percent(ANALOG);
    
    # double-check; same when we exit

    is $o < 1, 1, "before PWM hackery, output ok";
    #sleep 1;

    $pin->mode(PWM_OUT);

    $pi->pwm_mode(PWM_MODE_MS);
    $pi->pwm_clock(DIVISOR);
    $pi->pwm_range(RANGE);

    $pin->pwm(LEFT);


    #sleep 1;

    # Acceptance windows are single-sourced in t/RPiTest.pm
    # (rpi_pwm_adc_window(); shared with t/305-pwm_i2c_adc.t) - recalibrate
    # there, not here. With this file's custom RANGE the helper returns the
    # duty-cycle model window, giving each cycle a real lower bound (the old
    # `>= -1` was unfailable) and a duty-tracking upper bound (the old flat
    # ceiling was 40).
    #
    # RANGE 2000 at this clock is a ~50Hz (servo-rate) PWM, so the RC-filtered
    # ADC feedback carries heavy ripple: a single percent() read lands anywhere
    # from 0 to 100. We sweep in STEP increments and let percent() average
    # SAMPLES conversions per point (the RPi::ADC::ADS >= 1.03 averaging
    # feature), which recovers the true duty to within ~1 point - comfortably
    # inside the +/- tolerance window. SETTLE lets the RC filter catch up after
    # each step before we sample.

    for (my $duty = LEFT; $duty <= RIGHT; $duty += STEP){
        # sweep left to right
        $pin->pwm($duty);
        select(undef, undef, undef, SETTLE);
        $o = $adc->percent(ANALOG, SAMPLES);
        my ($min, $max) = rpi_pwm_adc_window($duty, RANGE);
        cmp_ok $o, '>=', $min, "output >= $min on cycle $duty going right ok";
        cmp_ok $o, '<=', $max, "output <= $max on cycle $duty going right ok";
    }

    #sleep 1;

    for (my $duty = RIGHT; $duty >= LEFT; $duty -= STEP){
        # sweep right to left
        $pin->pwm($duty);
        select(undef, undef, undef, SETTLE);
        $o = $adc->percent(ANALOG, SAMPLES);
        my ($min, $max) = rpi_pwm_adc_window($duty, RANGE);
        cmp_ok $o, '>=', $min, "output >= $min on cycle $duty going left ok";
        cmp_ok $o, '<=', $max, "output <= $max on cycle $duty going left ok";
    }

    #sleep 1;

    $pi->pwm_mode(PWM_MODE_BAL);
    $pi->pwm_clock(32);
    $pi->pwm_range(1023);
    $pin->pwm(0);
    $pin->mode(INPUT);
    $pin->pull(PUD_DOWN);

    #sleep 1;
    
    # let's double-check

    $o = $adc->percent(ANALOG);
    is $o < 1, 1, "PWM pin cleaned up ok";
    #sleep 1;
    $o = $adc->percent(ANALOG);
    is $o < 1, 1, "PWM pin cleaned up ok";

    is $pin->mode, INPUT, "PWM pin back to INPUT ok";

}

# rpi_check_pin_status();

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
