# TESTDOC: RCWL-0516 radar motion sensor (live, through $pi->radar)
use warnings;
use strict;

use lib 't/';

# Convenience: RPI_RADAR=1 flips on the master RPI_BOARD gate this file needs,
# so you don't export it by hand. Runs in BEGIN so it lands before RPiTest's
# compile-time RPI_BOARD skip_all. The sensor isn't tied to a test-platform
# board - it's a bench-wired device gated purely by RPI_RADAR.
BEGIN {
    if ($ENV{RPI_RADAR}){
        $ENV{RPI_BOARD} = 1;
    }
}

use RPiTest;
use RPi::WiringPi;
use Test::More;

# ===========================================================================
# t/361-radar.t - RPi::Radar::RCWL0516 live integration, driven through
#                 $pi->radar
# ===========================================================================
#
# WHAT THIS PROVES
#
#   The RCWL-0516 driver, reached through RPi::WiringPi's radar() accessor,
#   reads a real sensor on a real GPIO. The sensor is a single OUT line with no
#   command channel, and its motion state can't be forced from software, so we
#   verify what we CAN observe without a person waving at it: the accessor
#   returns the right object, motion() reports a clean boolean, poll() reads
#   back and re-sets, pin() exposes the transport, and the zero-timeout
#   wait_for_* calls take exactly one look and return a boolean. Wave a hand to
#   watch motion() flip; the test confirms the software path.
#
# WIRING (bench; NOT tied to a test-platform board)
#
#   An RCWL-0516 powered from 4-28V (the Pi's 5V is fine), GND common, and its
#   OUT terminal to the GPIO below (3.3V logic - the module's OUT is 3.3V).
#   Override the pin via RPI_RADAR_PIN.
#
#     VIN -> 5V     GND -> GND     OUT -> GPIO 26
#
# GATE
#
#   RPI_RADAR      - the RCWL-0516 is wired to the GPIO and powered.
#   Skips cleanly when unset, or when the driver isn't installed.
#
# ===========================================================================

if (! $ENV{RPI_RADAR}){
    plan skip_all => "RPI_RADAR environment variable not set\n";
}

# Loaded at runtime, after the gate: the module is an as-yet-unreleased family
# leaf, so a checkout without it installed still parses and skips rather than
# dying at compile time.
if (! eval { require RPi::Radar::RCWL0516; 1 }){
    plan skip_all => "RPi::Radar::RCWL0516 not installed\n";
}

rpi_running_test(__FILE__);

my $pin = $ENV{RPI_RADAR_PIN} // 26;

my $pi = RPi::WiringPi->new(label => 't/361-radar.t', shm_key => 'rpit');

my $radar;
my $cleaned = 0;

my $cleanup = sub {
    return if $cleaned;
    $cleaned = 1;
    $pi->cleanup;
};

local $SIG{INT}  = sub { $cleanup->(); exit 1; };
local $SIG{TERM} = sub { $cleanup->(); exit 1; };

my $ok = eval {
    $radar = $pi->radar(pin => $pin);

    isa_ok $radar, 'RPi::Radar::RCWL0516',
        "radar() returns an RCWL0516 driver";

    my $m = $radar->motion;
    ok $m == 0 || $m == 1, "motion() reports a clean boolean (got $m)";

    is $radar->poll, 0.1, "poll() defaults to 0.1 seconds";
    is $radar->poll(0.05), 0.05, "poll() sets and returns a new interval";

    isa_ok $radar->pin, 'RPi::Pin', "pin() exposes the underlying transport";

    my $wm = $radar->wait_for_motion(0);
    ok $wm == 0 || $wm == 1, "wait_for_motion(0) takes one look, returns a boolean (got $wm)";

    my $wc = $radar->wait_for_clear(0);
    ok $wc == 0 || $wc == 1, "wait_for_clear(0) takes one look, returns a boolean (got $wc)";

    1;
};

my $err = $@;

$cleanup->();

if (! $ok){
    fail("RCWL-0516 live test died before completion: $err");
}

done_testing();
