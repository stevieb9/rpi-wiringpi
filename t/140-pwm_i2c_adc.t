use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

rpi_sudo_check();

my $mod = 'RPi::WiringPi';

if ($> == 0){
    $ENV{RPI_BOARD} = 1;
    $ENV{RPI_ADC} = 1;
    $ENV{RPI_I2C} = 1;
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
    # Re-exec with $^X (the running perl) so sudo doesn't fall back to the
    # system perl, which lacks our perlbrew-installed prerequisites
    system("sudo", $^X, "-I", "blib/lib", $0);
    exit;
}

rpi_i2c_check();

rpi_running_test(__FILE__);

my $pi = $mod->new(label => 't/140-pwm_i2c_adc.t', shm_key => 'rpit');
my $adc = $pi->adc(addr => 0x48);   # ADS1015 #1 (PWM feedback on ch 0)

my $adc_in = 0;

if (! $ENV{NO_BOARD}) {

    # PWM_OUT (2) is the pinMode() setter; the read-back is get_alt(), whose
    # value for GPIO18's hardware PWM is board-specific: ALT5 (2) on the legacy
    # BCM chips, ALT3 (7) on the Pi 5 / RP1
    my $pwm_alt = rpi_board_tag() eq 'pi5' ? ALT3 : ALT5;

    my $pin = $pi->pin(18);
    $pin->mode(PWM_OUT);
    is $pin->mode, $pwm_alt, "pin mode set to PWM ok, and we can read it";

    # Acceptance windows are single-sourced in t/RPiTest.pm
    # (rpi_pwm_adc_window(); shared with t/109-pwm_hw_mods.t) - recalibrate
    # there, not here. The calibration table covers levels up to 1000, but
    # only 100-400 are swept here (the historical sweep range of this test)

    for my $pwm (100, 200, 300, 400){
        $pin->pwm($pwm);
        my $res = $adc->percent($adc_in);
        my ($min, $max) = rpi_pwm_adc_window($pwm, PWM_DEFAULT_RANGE);

        is $res > $min, 1, "$pwm: pwm $res in range of lower end ($min) ok";
        is $max > $res, 1, "$pwm: pwm $res in range of upper end ($max) ok";
    }

    $pi->cleanup;

    select(undef, undef, undef, 0.02);
    rpi_check_pin_status();
#    rpi_metadata_clean();
}

done_testing();
