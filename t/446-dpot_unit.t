# TESTDOC: MCP4XXXX digipot unit (HW-free)
use warnings;
use strict;

use Mock::Sub;
use Test::More;

use RPi::DigiPot::MCP4XXXX;

# Mirror of RPi::DigiPot::MCP4XXXX's own t/set_shutdown.t, run here in the
# canonical suite. t/445-dpot.t drives the dpot on real hardware; this adds
# HW-free verification of the exact SPI control/data bytes and the CS framing
# order, so a framing regression is caught in CI with no Pi. We mock every
# wiringPi call the module imports, so it runs ungated (no RPiTest, no shm).
#
# NOTE: this exercises the INSTALLED RPi::DigiPot::MCP4XXXX, so the bad-pot
# message is matched version-agnostically (the F4 wording fix - "shutdown()"
# vs "set()" - is asserted in the dist's own test, against its source).

my $mod = 'RPi::DigiPot::MCP4XXXX';

my @events;

my $m = Mock::Sub->new;
my $mock_setup    = $m->mock("${mod}::wiringPiSetupGpio");
my $mock_spisetup = $m->mock("${mod}::wiringPiSPISetup");
my $mock_pinmode  = $m->mock("${mod}::pinMode");
my $mock_dw  = $m->mock("${mod}::digitalWrite", side_effect => sub { push @events, ['dw', @_]; });
my $mock_spi = $m->mock("${mod}::spiDataRW",    side_effect => sub { push @events, ['spi', @_]; });

my $cs = 5;
my $dpot = $mod->new($cs, 0);
isa_ok $dpot, $mod, "new() constructs off-board with the wiringPi calls mocked";

# --- set(): control/data framing + CS order ---

@events = ();
$dpot->set(127);
is_deeply
    \@events,
    [
        ['dw',  $cs, 0],
        ['spi', 0, [0x11, 127], 2],
        ['dw',  $cs, 1],
    ],
    "set(127): CS LOW, spiDataRW(chan 0, [0x11, 127], len 2), CS HIGH";

@events = ();
$dpot->set(255, 3);
is_deeply
    $events[1],
    ['spi', 0, [0x13, 255], 2],
    "set(255, pot 3): control byte 0x13 (cmd 1 | pot 3), data 255";

# --- shutdown(): data is always 0, cmd nibble is 0x02 ---

@events = ();
$dpot->shutdown;
is_deeply
    \@events,
    [
        ['dw',  $cs, 0],
        ['spi', 0, [0x21, 0], 2],
        ['dw',  $cs, 1],
    ],
    "shutdown(): CS LOW, spiDataRW(chan 0, [0x21, 0], len 2), CS HIGH";

@events = ();
$dpot->shutdown(2);
is_deeply
    $events[1],
    ['spi', 0, [0x22, 0], 2],
    "shutdown(pot 2): control byte 0x22 (cmd 2 | pot 2), data 0";

# --- validation croaks fire before any SPI write ---

for my $bad (-1, 256) {
    @events = ();
    eval { $dpot->set($bad); };
    like $@, qr/0-255 as the data param/, "set($bad) dies on out-of-range data";
    is scalar @events, 0, "...and no SPI write happened";
}

for my $bad (0, 4) {
    eval { $dpot->set(127, $bad); };
    like $@, qr/pot param must be 1-3/, "set(127, $bad) dies on bad pot";
}

eval { $dpot->shutdown(4); };
like $@, qr/pot param must be 1-3/, "shutdown(4) dies on bad pot";

done_testing();
