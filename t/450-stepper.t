use warnings;
use strict;

use lib 't/';

use RPiTest;
use RPi::Const qw(:all);
use RPi::WiringPi;
use RPi::StepperMotor;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);
use Test::More;

# ===========================================================================
# t/450-stepper.t - stepper / I2C expander timing integration test
# ===========================================================================
#
# WHAT THIS PROVES
#
#   The expander's C/XS *output* path drives a sequenced step train correctly
#   and promptly. We command a fixed number of steps and time how long the
#   motor takes to physically reach a fixed magnet. If the expander drops,
#   re-orders, or mis-paces steps, the magnet is reached late/early/never and
#   the measured edge falls outside its window. The switches are read on the
#   Pi's NATIVE GPIO (not through the expander), so the measurement is
#   decoupled from the thing under test - a pass is not a self-confirming loop.
#
# HOW THE RIG IS PINNED
#
#   Stepper motor (4-wire)
#       Driven through an MCP23017 I2C I/O expander at address 0x21, BANK A
#       pins A0-A3 (= expander pins 0-3). Step mode (full/half) and per-step
#       delay are varied per pass - see @PASSES below.
#
#   CW limit       - magnetic switch on Pi native GPIO 17 (BCM), pulled down.
#   CCW limit      - magnetic switch on Pi native GPIO 27 (BCM), pulled down.
#       Each magnet aligns at a FIXED travel extreme and raises its line; we
#       arm a rising-edge background_interrupt on each. The handler runs in a
#       forked ISR child and, via the results channel, returns the edge's
#       CLOCK_MONOTONIC microsecond timestamp to us.
#
#   Centre         - NO physical switch. Centre is the geometric midpoint
#       between the two magnets, reached by symmetric tick counts (the cycle
#       nets zero ticks, so it returns to centre). Confirmed by the operator's
#       eyes via the centre LED.
#
#   Centre LED     - GPIO 19 (BCM), OUTPUT. Flashed through a one-shot worker
#       (off the main path) on each return to centre.
#
# TIMING
#
#   The ISR stamps each edge in CLOCK_MONOTONIC microseconds. We read the same
#   clock at the start of each out-sweep, so (edge_ts - sweep_start) is a true
#   latency. pi_micros64() is NOT used: wiringPiSetup resets its epoch, which
#   does not match the ISR's boot-based clock.
#
# PRECONDITION
#
#   The rig MUST start physically centred (there is no centre sensor to assert
#   it). The symmetric cycle keeps it centred between passes.
#
# ===========================================================================

# Hardware gates - this test requires, at minimum:
#   - a Pi board    (RPI_BOARD, enforced by RPiTest at use-time above)
#   - an MCP23017   (RPI_MCP23017 - the rig's expander at 0x21 drives the coils)
#   - the stepper   (RPI_STEPPER - the motor + magnet-limit rig)
# Skip cleanly if any is absent.
if (! $ENV{RPI_MCP23017}){
    plan(skip_all => "RPI_MCP23017 environment variable not set");
}

if (! $ENV{RPI_STEPPER}){
    plan(skip_all => "RPI_STEPPER environment variable not set");
}

rpi_running_test(__FILE__);

use constant {
    CCW_TICKS => 190,
    CW_TICKS  => 180,
    DEBOUNCE  => 5000,    # Kernel debounce (microseconds) for the switch ISRs
    TOLERANCE => 0.05,    # Edge must land within +/-5% of its measured mean
    FLASH     => 0.15,    # Centre-LED hold (seconds)
};

# Expected edge-trip latency (ms) from out-sweep start to magnet, per
# "speed/delay" config. Measured on-rig as the mean of 4 iterations; run-to-run
# jitter was under ~1%, so the +/-5% window has comfortable headroom.
my %EXPECT = (
    'full/0.00' => { ccw => 2088.5,  cw => 2048.1 },
    'full/0.01' => { ccw => 8925.7,  cw => 8604.1 },
    'half/0.01' => { ccw => 17815.7, cw => 17176.0 },
    'half/0.00' => { ccw => 4170.0,  cw => 4028.3 },
);

# The five passes, in run order. full/0.00 runs twice (repeatability); the
# 0.01 and half-step passes exercise the expander write path at slower cadences
# and the half-step pattern, surfacing rate-dependent XS bugs.
my @PASSES = (
    { speed => 'full', delay => 0.00 },
    { speed => 'full', delay => 0.00 },
    { speed => 'full', delay => 0.01 },
    { speed => 'half', delay => 0.01 },
    { speed => 'half', delay => 0.00 },
);

my $pi  = RPi::WiringPi->new(label => 't/450-stepper.t', shm_key => 'rpit');
my $exp = $pi->expander(0x21);

$pi->auto_dispatch_interrupts(1);

# Centre LED (driven on a computed centre, not a switch)
my $c_led = $pi->pin(19);
$c_led->mode(OUTPUT);
$c_led->write(LOW);

# Clockwise magnetic switch
my $cw_pin = $pi->pin(17);
$cw_pin->pull(PUD_DOWN);

# Counter-clockwise magnetic switch
my $ccw_pin = $pi->pin(27);
$ccw_pin->pull(PUD_DOWN);

# Arm both switch interrupts with a results channel: the ISR child ships each
# edge's CLOCK_MONOTONIC timestamp (microseconds) back for latency measurement
my $cw_proc = $cw_pin->background_interrupt(
    EDGE_RISING,
    sub { my ($edge, $ts_us) = @_; return $ts_us; },
    DEBOUNCE,
    { results => 1 },
);
my $ccw_proc = $ccw_pin->background_interrupt(
    EDGE_RISING,
    sub { my ($edge, $ts_us) = @_; return $ts_us; },
    DEBOUNCE,
    { results => 1 },
);

my $pass_num = 0;

for my $pass (@PASSES) {
    run_pass(++$pass_num, $pass);
}

$cw_proc->stop;
$ccw_proc->stop;

$exp->cleanup;
$pi->cleanup;

rpi_check_pin_status();

done_testing();

# SUBROUTINES

sub drain_edge {
    my ($proc, $t0) = @_;

    # The edge fires mid-sweep, so by the time the blocking move returns the
    # child has usually written it. Poll briefly for the first timestamp at or
    # after the sweep start and return its latency in microseconds
    for (1 .. 20) {
        while (defined(my $ts = $proc->read)) {
            return $ts - $t0 if $ts >= $t0;
        }
        select(undef, undef, undef, 0.005);
    }

    return undef;
}

sub edge_ok {
    my ($actual_us, $expect_ms, $label) = @_;

    if (! defined $actual_us) {
        fail "$label: no edge timestamp captured";
        return;
    }

    my $actual_ms = $actual_us / 1000;
    my $lo = $expect_ms * (1 - TOLERANCE);
    my $hi = $expect_ms * (1 + TOLERANCE);

    ok $actual_ms >= $lo && $actual_ms <= $hi,
        sprintf '%s: %.1fms within %.1f-%.1fms (expect %.1f +/-5%%)',
            $label, $actual_ms, $lo, $hi, $expect_ms;
}

sub flash_centre {

    # Hold the centre LED visibly without stalling the main path: the flash
    # plays out entirely in a one-shot forked worker
    $pi->worker(
        sub {
            $c_led->write(HIGH);
            select(undef, undef, undef, FLASH);
            $c_led->write(LOW);
        },
        { once => 1 },
    );
}

sub run_pass {
    my ($num, $pass) = @_;

    my $speed  = $pass->{speed};
    my $delay  = $pass->{delay};
    my $key    = sprintf '%s/%.2f', $speed, $delay;
    my $expect = $EXPECT{$key};

    note "==== pass $num: speed=$speed delay=$delay ====";

    my $sm = RPi::StepperMotor->new(
        pins     => [A0, A1, A2, A3],
        expander => $exp,
        speed    => $speed,
        delay    => $delay,
    );

    # Phase 1: sweep out counter-clockwise (trips the ccw magnet)
    my $t0 = _now_us();
    $sm->ccw(CCW_TICKS);
    my $ccw_out  = _now_us() - $t0;
    my $ccw_edge = drain_edge($ccw_proc, $t0);

    # Phase 2: sweep back clockwise to centre
    $t0 = _now_us();
    $sm->cw(CCW_TICKS);
    my $ccw_back = _now_us() - $t0;

    flash_centre();

    # Phase 3: sweep out clockwise (trips the cw magnet)
    $t0 = _now_us();
    $sm->cw(CW_TICKS);
    my $cw_out  = _now_us() - $t0;
    my $cw_edge = drain_edge($cw_proc, $t0);

    # Phase 4: sweep back counter-clockwise to centre
    $t0 = _now_us();
    $sm->ccw(CW_TICKS);
    my $cw_back = _now_us() - $t0;

    flash_centre();

    # Full timing table (diagnostics); only the edge latencies are asserted
    note sprintf '  ccw_out  %8.1fms   ccw_edge %s', $ccw_out / 1000, _ms($ccw_edge);
    note sprintf '  ccw_back %8.1fms', $ccw_back / 1000;
    note sprintf '  cw_out   %8.1fms   cw_edge  %s', $cw_out / 1000, _ms($cw_edge);
    note sprintf '  cw_back  %8.1fms', $cw_back / 1000;

    edge_ok($ccw_edge, $expect->{ccw}, "$key ccw edge");
    edge_ok($cw_edge,  $expect->{cw},  "$key cw edge");

    $sm->cleanup;
}

sub _ms {
    my ($us) = @_;
    return defined $us ? sprintf('%.1fms', $us / 1000) : 'n/a';
}

sub _now_us {

    # The ISR stamps edges in CLOCK_MONOTONIC microseconds; read the same clock
    # here so edge timestamps and sweep-start markers are directly comparable
    return clock_gettime(CLOCK_MONOTONIC) * 1_000_000;
}
