# TESTDOC: MCP4922 DAC (read via MCP3008)
use warnings;
use strict;

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
use WiringPi::API qw(:all);

if (! $ENV{RPI_MCP4922}){
    plan skip_all => "RPI_MCP4922 environment variable not set\n";
}

if (! $ENV{RPI_MCP3008}){
    plan skip_all => "RPI_MCP3008 environment variable not set\n";
}

rpi_running_test(__FILE__);

my ($adc_cs_pin, $dac_cs_pin) = (26, 12);

my $adc_dac0_in = 1;
my $adc_dac1_in = 3;

my $pi = RPi::WiringPi->new(label => 't/410-dac.t', shm_key => 'rpit');
# Belt-and-braces: if an assertion or library call dies mid-run, release the
# pins/registration this object holds (the library END reap is best-effort)

END { $pi->cleanup if $pi && ! $pi->{clean}; }


my $dac = $pi->dac(
    model => 'MCP4922',
    channel => 0,
    cs => $dac_cs_pin
);

my $adc = $pi->adc(
    model => 'MCP3008',
    channel => $adc_cs_pin
);

my @output = (
    [0, 2],
    [22, 27],
    [46, 52],
    [70, 76],
    [95, 100],
    [95, 100],
);

{ # dac0
    my $c = 0;

    for (0..4095){
        $dac->set(0, $_);

        if ($_ % 1000 == 0 || $_ == 4095){
            my $r = $adc->percent($adc_dac0_in);

            is 
                $r >= $output[$c]->[0] && $r <= $output[$c]->[1], 
                1,
                "DAC 0 output at $_ ok";

            $c++;
        }
    }
}

{ # dac1
    my $c = 0;

    for (0..4095){
        $dac->set(1, $_);

        if ($_ % 1000 == 0 || $_ == 4095){
            my $r = $adc->percent($adc_dac1_in);
            is 
                $r >= $output[$c]->[0] && $r <= $output[$c]->[1], 
                1,
                "DAC 1 output at $_ ok";

            $c++;
        }
    }
}

# Tear the MCP3008 down before cleanup. Its DESTROY forces the bit-banged CS
# pin (26) to INPUT; left to run at global destruction it would fire *after*
# the pin-status check below and strand pin 26 at alt 0, failing this and
# every later test that expects the RP1 "no function" default (31). Destroying
# it here lets $pi->cleanup restore pin 26 to alt 31 with the final word.
undef $adc;

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();
