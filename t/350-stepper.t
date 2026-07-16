# TESTDOC: Stepper motor (timed limit switches)
use warnings;
use strict;

use lib 't/';

# Board-3 convenience: set RPI_BOARD_3=1 and every env gate the board-3 suite
# needs is enabled automatically, instead of exporting each one by hand. Runs in
# BEGIN so it lands before RPiTest's compile-time RPI_BOARD skip_all gate.
BEGIN {
    if ($ENV{RPI_BOARD_3}) {
        $ENV{$_} = 1 for qw(RPI_BOARD RPI_MCP23017 RPI_STEPPER);
    }
}

use RPiTest;
use RPi::Const qw(:all);
use RPi::WiringPi;
use RPi::StepperMotor;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);
use Test::More;
use StepperSeek qw(seek_limit home_target stepper_calibrate stepper_skew SKEW_LIMIT_PCT);

# ===========================================================================
# t/350-stepper.t - stepper / I2C expander timing integration test
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
    SEEK_STEP => 12,      # Degrees per homing tick (one full-step quantum)
};

# Homing steps by SEEK_STEP degrees per tick, never one degree: $sm->ccw(1)
# rounds to ZERO movement (int(1 / 11.25 + 0.5) * 64 == 0), so a per-degree seek
# would never move the motor. SEEK_STEP (~one 11.25-degree full-step quantum) is
# the smallest amount that actually rotates; all homing counts and bounds below
# are expressed in these ticks.
#
# Seek bound in SEEK_STEP-degree ticks: ~1.25x the full designed travel
# (CCW_TICKS + CW_TICKS degrees), so a dead switch fails fast instead of driving
# the motor into the hard stop.
use constant SEEK_MAX => int((CCW_TICKS + CW_TICKS) * 1.25 / SEEK_STEP);

# Expected edge-trip latency (ms) from out-sweep start to magnet, per
# "speed/delay" config. Measured on-rig as the mean of 4 iterations; run-to-run
# jitter was under ~1%, so the +/-5% window has comfortable headroom.
my %EXPECT = (
    'full/0.00' => { ccw => 2088.5,  cw => 2048.1 },
    'full/0.01' => { ccw => 8925.7,  cw => 8604.1 },
    'half/0.01' => { ccw => 17815.7, cw => 17176.0 },
    'half/0.00' => { ccw => 4170.0,  cw => 4028.3 },
);

# The five passes, in run order. full/0.00 runs twice (repeatability); the 0.01
# and half-step passes exercise the expander write path at slower cadences and
# the half-step pattern, surfacing rate-dependent XS bugs.
#
#   Pass   speed/delay   ccw edge    cw edge      (expected means; +/-5% window)
#   ----   -----------   --------   --------
#   1, 2   full/0.00      2088 ms    2048 ms
#   3      full/0.01      8926 ms    8604 ms
#   4      half/0.01     17816 ms   17176 ms
#   5      half/0.00      4170 ms    4028 ms
my @PASSES = (
    { speed => 'full', delay => 0.00 },
    { speed => 'full', delay => 0.00 },
    { speed => 'full', delay => 0.01 },
    { speed => 'half', delay => 0.01 },
    { speed => 'half', delay => 0.00 },
);

my $pi  = RPi::WiringPi->new(label => 't/350-stepper.t', shm_key => 'rpit');
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

# Establish a known base before timing anything: home against the two magnetic
# limits, measure the travel span, and move to the computed centre. Each move is
# bounded (seek_limit) so a dead switch fails the test instead of driving into a
# hard stop. The timed passes are skipped if homing fails (no known base).
if (home($exp)) {

    # Centring gate: one quick sweep up front to measure how far off centre the
    # homed rest point sits. A persistent skew is gear backlash (the edges
    # should be equidistant from a true centre); if it exceeds spec the timed
    # passes cannot be trusted, so report the operator action and skip them
    # rather than burn ~90s on passes that will all fail the same way.
    my $cal = stepper_calibrate(\&measure_skew, CW_TICKS);

    if (! $cal->{ok}) {
        fail "centring gate: could not capture both edges ($cal->{reason})";
    }
    elsif (! ok $cal->{within_spec},
        sprintf 'centring gate: skew %.1f%% within %.1f%% spec '
              . '(%.1f deg / %.2f teeth toward %s)',
            $cal->{skew_pct}, SKEW_LIMIT_PCT,
            $cal->{skew_deg}, $cal->{quanta}, $cal->{biased_to})
    {
        diag "ACTION REQUIRED: $cal->{action}";
        diag "skipping the timed passes until the rig is recentred";
    }
    else {
        for my $pass (@PASSES) {
            run_pass(++$pass_num, $pass);
        }
    }
}
else {
    note "homing failed - skipping the timed passes (no known base position)";
}

$cw_proc->stop;
$ccw_proc->stop;

# De-energize the motor before tearing down the bus, so the coils aren't left
# holding current after the run (the timed passes above may leave a coil driven).
# Guarded for the install lag: off() needs RPi::StepperMotor >= 3.1802, and the
# $exp->cleanup below releases the coil pins anyway on older installs.
$sm->off if $sm->can('off');

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

sub home {
    my ($exp) = @_;

    note "==== homing: seek limits, measure span, move to centre ====";

    my $sm = RPi::StepperMotor->new(
        pins     => [A0, A1, A2, A3],
        expander => $exp,
        speed    => 'full',
        delay    => 0.00,
    );

    # Bounded seeks: undef means the switch never tripped within SEEK_MAX (a hard
    # fault). Home to the CCW limit, then seek CW counting ticks = the travel
    # span. Skip the span seek if the CCW home already failed (don't keep driving).
    my $to_ccw = seek_limit(sub { $ccw_pin->read }, sub { $sm->ccw(SEEK_STEP) }, SEEK_MAX);
    my $span   = defined $to_ccw
        ? seek_limit(sub { $cw_pin->read }, sub { $sm->cw(SEEK_STEP) }, SEEK_MAX)
        : undef;

    # Decide outcome + centre (pure; StepperSeek::home_target, unit-tested in
    # t/351): out-of-bounds on either seek, or a stuck-high switch (tiny span),
    # fails; otherwise centre = half the measured span. min_span is in seek ticks.
    my ($ok, $centre, $reason) =
        home_target($to_ccw, $span, int((CCW_TICKS + CW_TICKS) / 2 / SEEK_STEP));

    ok $ok, "homed and centred within bounds (reason: $reason"
        . (defined $span ? ", span ${span}t" : '') . ')';

    if (! $ok) {
        $sm->cleanup;
        return 0;
    }

    # Move from the CW limit back to centre = half the measured span. $centre is
    # in seek ticks; scale by SEEK_STEP back to degrees for the move.
    $sm->ccw($centre * SEEK_STEP);
    $sm->cleanup;

    # The homing sweep tripped both switches; drain those edges so the timed
    # passes start with empty results channels.
    1 while defined $cw_proc->read;
    1 while defined $ccw_proc->read;

    note "centred: span ${span}t, centre = " . int($span / 2) . "t from the CW limit";

    return 1;
}

sub measure_skew {

    # One quick full/0.00 out-and-back on each side, feeding the centring gate
    # via stepper_calibrate(). Mirrors run_pass's geometry but asserts nothing
    # and ends back at centre, ready for the timed passes. Returns the triple
    # stepper_skew()/stepper_calibrate() consume: ($ccw_us, $cw_us, $cw_out_us).
    my $sm = RPi::StepperMotor->new(
        pins     => [A0, A1, A2, A3],
        expander => $exp,
        speed    => 'full',
        delay    => 0.00,
    );

    # CCW out to the ccw magnet (timed edge), then back to centre
    my $t0 = _now_us();
    $sm->ccw(CCW_TICKS);
    my $ccw_edge = drain_edge($ccw_proc, $t0);
    $sm->cw(CCW_TICKS);

    # CW out to the cw magnet (timed edge + out-sweep pace), then back to centre
    $t0 = _now_us();
    $sm->cw(CW_TICKS);
    my $cw_out  = _now_us() - $t0;
    my $cw_edge = drain_edge($cw_proc, $t0);
    $sm->ccw(CW_TICKS);

    $sm->cleanup;

    return ($ccw_edge, $cw_edge, $cw_out);
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

    # Per-pass centring readout (diagnostic only; the up-front gate is the hard
    # check). A skew over spec here corroborates an off-centre rest point.
    if (defined $ccw_edge && defined $cw_edge) {
        my $m = stepper_skew($ccw_edge, $cw_edge, $cw_out, CW_TICKS);

        diag sprintf '%s centre skew: %.1f%% (~%.1f deg / %.2f teeth toward %s)',
            $key, $m->{skew_pct}, $m->{skew_deg}, $m->{quanta}, $m->{biased_to}
            if $m->{skew_pct} > SKEW_LIMIT_PCT;
    }

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
