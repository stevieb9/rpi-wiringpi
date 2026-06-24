use strict;
use warnings;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use Test::More;

# Exercises the RPi::ADC::ADS conversion-averaging feature (samples) through the
# RPi::WiringPi integration path ($pi->adc), mirroring the standalone dist's
# t/55-samples.t. These are accessor + validation checks (no ADC read), but the
# object is obtained the way the platform builds it. Requires RPi::ADC::ADS
# 1.03 or newer (the release that added samples()).

if (! $ENV{RPI_ADC}){
    plan skip_all => "RPI_ADC environment variable not set\n";
}

if (! $ENV{RPI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "RPI_BOARD environment variable not set\n";
}

$SIG{__DIE__} = sub {};

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(label => 't/320-adc_samples.t', shm_key => 'rpit');

{ # default
    my $adc = $pi->adc(addr => 0x48);
    is $adc->samples, 1, "samples() default is 1";
}

{ # set via $pi->adc(samples => N)
    my $adc = $pi->adc(addr => 0x48, samples => 25);
    is $adc->samples, 25, "samples set via \$pi->adc(samples => N) ok";
}

{ # accessor set/get
    my $adc = $pi->adc(addr => 0x48);
    is $adc->samples(64), 64, "samples() set returns the new value";
    is $adc->samples, 64, "...and reads back ok";
}

{ # validation: must be a positive integer
    my $adc = $pi->adc(addr => 0x48);

    for my $bad (0, -1, '1.5', 'x', ''){
        my $ok = eval { $adc->samples($bad); 1 };
        is $ok, undef, "samples('$bad') croaks ok";
        like $@, qr/positive integer/, "...and the error is sane";
    }

    is $adc->samples, 1, "samples() left at the default after the failed sets";
}

$pi->cleanup;

rpi_check_pin_status();

done_testing();
