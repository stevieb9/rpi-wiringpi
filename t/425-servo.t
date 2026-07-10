# TESTDOC: Servo HW PWM (read via ADC)
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
    $ENV{RPI_BOARD} = 1;
    $ENV{RPI_ADC}   = 1;
    $ENV{RPI_I2C}   = 1;
    $ENV{RPI_SERVO} = 1;
}

if (! $ENV{RPI_SERVO}){
    plan skip_all => "RPI_SERVO environment variable not set\n";
}

if (! $ENV{RPI_ADC}){
    plan skip_all => "RPI_ADC environment variable not set\n";
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
    LEFT           => 60,
    RIGHT          => 255,
    CENTRE         => 150,
    PIN            => 18,
    DIVISOR        => 192,
    RANGE          => 2000,
    DELAY          => 0.01,
    ANALOG         => 0,
    SWEEP_CEIL     => 36,
    SWEEP_MIN_PEAK => 15,
};


if (! $ENV{NO_BOARD}) {
    my $pi = $mod->new(label => 't/425-servo.t', shm_key => 'rpit');

    # Always release pin 18 even if the sweep croaks or we're interrupted
    # mid-run. A leaked registration in the shared meta poisons every later
    # test file that uses pin 18 (t/150, t/200-213, etc.)

    my $cleaned = 0;

    my $cleanup = sub {
        return if $cleaned;
        $cleaned = 1;
        $pi->cleanup;
    };

    local $SIG{INT}  = sub { $cleanup->(); exit 1; };
    local $SIG{TERM} = sub { $cleanup->(); exit 1; };

    my $adc = $pi->adc(addr => 0x48);   # ADS1015 #1 (servo feedback on ch 0)

    my $servo = $pi->servo(18);
    my $o;

    my $ok = eval {
        # Static-position gate: at LEFT / CENTRE / RIGHT the MEAN of N feedback
        # reads must land inside the calibrated window (single-sourced in
        # RPiTest.pm). Averaging cancels the phase noise a single read carries,
        # so a broken GPIO18->A0 path collapses the mean to ~0 and FAILS here.
        for my $pos ([LEFT, 'LEFT'], [CENTRE, 'CENTRE'], [RIGHT, 'RIGHT']){
            my ($val, $name) = @$pos;

            $servo->pwm($val);

            # Settle: poll (bounded ~6s) until two consecutive reads track
            # within half a percent of each other, instead of a fixed sleep.
            my $prev = $adc->percent(ANALOG);

            for (1 .. 60){
                select(undef, undef, undef, 0.1);
                my $cur = $adc->percent(ANALOG);
                last if abs($cur - $prev) < 0.5;
                $prev = $cur;
            }

            my ($min, $max) = rpi_servo_adc_window($val);
            my $mean = rpi_servo_adc_mean($adc, ANALOG);

            cmp_ok $mean, '>=', $min, "$name ($val) feedback mean $mean >= $min";
            cmp_ok $mean, '<=', $max, "$name ($val) feedback mean $mean <= $max";
        }

        # Sweep gate: drive the full range both ways. Every instantaneous read
        # must stay within the gross envelope (catches stuck-high / over-range),
        # and the PEAK read across the whole sweep must clear SWEEP_MIN_PEAK
        # (catches stuck-low / a severed line, which never rises above ~0).
        my $peak = 0;

        for my $val (LEFT .. RIGHT, reverse LEFT .. RIGHT){
            $servo->pwm($val);
            $o = $adc->percent(ANALOG);
            $peak = $o if $o > $peak;

            cmp_ok $o, '>=', 0,          "sweep read $o >= 0 at pwm $val";
            cmp_ok $o, '<=', SWEEP_CEIL, "sweep read $o within ceiling at pwm $val";

            select(undef, undef, undef, DELAY);
        }

        cmp_ok $peak, '>', SWEEP_MIN_PEAK,
            "sweep peak $peak clears min (GPIO18->A0 line is live)";

        1;
    };

    my $err = $@;

    $cleanup->();

    if ($ok) {
        $o = $adc->percent(ANALOG);
        is $o < 1, 1, "PWM pin cleaned up ok";
        $o = $adc->percent(ANALOG);
        is $o < 1, 1, "PWM pin cleaned up ok";
    }
    else {
        fail("servo sweep died before completion: $err");
    }

    rpi_check_pin_status();

}

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
