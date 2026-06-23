use warnings;
use strict;

use lib 't/';

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

if (! $ENV{RPI_DIGIPOT}){
    plan skip_all => "RPI_DIGIPOT environment variable not set\n";
}

if (! $ENV{RPI_ADC}){
    plan skip_all => "RPI_ADC environment variable not set\n";

}

use constant {
    DPOT_CS => 13,   # Bit-banged SPI chip-select (GPIO13)
    SPI_CH  => 0,    # MCP42010 SPI bus channel (CE0)
    POT0    => 1,    # set() pot-select: pot 0 -> PW0 wiper
    POT1    => 2,    # set() pot-select: pot 1 -> PW1 wiper
    ADC_PW0 => 1,    # ADS1015 A1 reads the PW0 wiper
    ADC_PW1 => 2,    # ADS1015 A2 reads the PW1 wiper
};

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(label => 't/345-dpot.t', shm_key => 'rpit');
# Belt-and-braces: if an assertion or library call dies mid-run, release the
# pins/registration this object holds (the library END reap is best-effort)

END { $pi->cleanup if $pi && ! $pi->{clean}; }


my $adc = $pi->adc(addr => 0x48);   # ADS1015 #1
my $pot = $pi->dpot(DPOT_CS, SPI_CH);

# Expected ADC percentage window per tap. Both potentiometers are wired
# identically (PA -> +3V3, PB -> GND, wiper -> ADS), so the same windows apply
# to either wiper.
my @windows = (
    [0, 1],
    [18, 20],
    [38, 40],
    [57, 60],
    [76, 79],
    [96, 98],
    [98, 100],
);

# Pot 0's wiper (PW0) feeds ADS A1; pot 1's wiper (PW1) feeds ADS A2.
sweep_pot(POT0, ADC_PW0, 'PW0');
sweep_pot(POT1, ADC_PW1, 'PW1');

# shutdown() must actually reach the chip. In shutdown the MCP42010 disconnects
# the A terminal and ties the wiper to the B terminal (GND on this board), so a
# wiper parked near +3V3 collapses to ~0%. This only latches if shutdown()
# brackets its SPI write with CS LOW/HIGH (matching set()); without that toggle
# the device never sees the frame and the wiper stays where it was.
for my $wiper ([POT0, ADC_PW0, 'PW0'], [POT1, ADC_PW1, 'PW1']){

    my ($pot_select, $adc_ch, $label) = @$wiper;

    $pot->set(255, $pot_select);
    is $adc->percent($adc_ch) >= 96, 1, "$label: wiper near +3V3 before shutdown ok";

    $pot->shutdown($pot_select);
    is $adc->percent($adc_ch) <= 2, 1, "$label: shutdown() ties wiper to B (GND) ok";

    $pot->set(0, $pot_select);   # Bring the pot back out of shutdown
}

# The shutdown checks above leave both pots parked at tap 0 (the set(0)
# restore), so MOSI is already idling low for the shared pin-status check.

$pi->cleanup;

rpi_check_pin_status();
#rpi_metadata_clean();

done_testing();

# Sweep one potentiometer across its tap range and confirm the wiper voltage,
# read back on the given ADS1015 channel, lands inside the expected window.
sub sweep_pot {
    my ($pot_select, $adc_ch, $label) = @_;

    if (! defined $pot_select) {
        die "sweep_pot() requires the \$pot_select param\n";
    }

    if (! defined $adc_ch) {
        die "sweep_pot() requires the \$adc_ch param\n";
    }

    my $count = 0;

    for (0..255){

        if ($_ % 50 == 0 || $_ == 255){

            $pot->set($_, $pot_select);
            my $val = $adc->percent($adc_ch);

            is
                $val >= $windows[$count]->[0] && $val <= $windows[$count]->[1],
                1,
                "$label: POT output at $_ tap ok";

            $count++;
        }
    }
}
