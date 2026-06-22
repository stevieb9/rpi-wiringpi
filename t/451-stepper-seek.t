use warnings;
use strict;

use lib 't/';

use StepperSeek qw(seek_limit home_target stepper_calibrate stepper_skew SKEW_LIMIT_PCT);
use Test::More;

# Pure unit tests for the homing bound used by t/450 (StepperSeek::seek_limit).
# They verify the bound is hit / not hit correctly using mock switch + step
# callbacks, so no hardware (and no RPI_* gate) is needed - the destructive
# "switch never trips" case can be exercised safely here, never on a real motor.

# 1. Trips well within the bound -> returns the trip tick, no over-stepping
{
    my ($at, $step, $n) = mocks(5);
    is seek_limit($at, $step, 100), 5, "limit found at tick 5 (within bound)";
    is $$n, 5, "stepped exactly 5 times (no overshoot)";
}

# 2. Already at the limit -> 0 ticks, never steps into the stop
{
    my ($at, $step, $n) = mocks(0);
    is seek_limit($at, $step, 100), 0, "already at limit -> 0 ticks";
    is $$n, 0, "no steps issued when already home";
}

# 3. Never trips -> bound hit -> undef, stepped exactly the bound (no runaway)
{
    my ($at, $step, $n) = mocks(undef);
    is seek_limit($at, $step, 50), undef, "bound hit -> undef when limit never trips";
    is $$n, 50, "stepped exactly the bound (50), did not run away";
}

# 4. Trips on the final allowed tick -> success at the boundary
{
    my ($at, $step, $n) = mocks(50);
    is seek_limit($at, $step, 50), 50, "trip on the final tick still succeeds";
    is $$n, 50, "stepped exactly 50";
}

# 5. Would trip one tick past the bound -> bound hit -> undef, capped
{
    my ($at, $step, $n) = mocks(51);
    is seek_limit($at, $step, 50), undef, "trip one past the bound -> undef";
    is $$n, 50, "capped at 50 ticks (never reached 51)";
}

# 6. Argument validation (croaks, in order)
{
    eval { seek_limit('x',    sub {}, 10) }; ok $@, "non-coderef \$at_limit croaks";
    eval { seek_limit(sub {}, 'x',    10) }; ok $@, "non-coderef \$step croaks";
    eval { seek_limit(sub {}, sub {}, 0)  }; ok $@, "\$max_ticks of 0 croaks";
    eval { seek_limit(sub {}, sub {}, -5) }; ok $@, "negative \$max_ticks croaks";
    eval { seek_limit(sub {}, sub {}, 'z') }; ok $@, "non-integer \$max_ticks croaks";
}

# --- home_target(): the homing decision + re-centre math, exercised directly ---

# 7. CCW home seek out of bounds -> fail, no centre target
{
    my ($ok, $centre, $reason) = home_target(undef, undef, 185);
    is $ok,     0,                   "ccw out-of-bounds -> not ok";
    is $centre, undef,               "no centre target when the ccw seek hit its bound";
    is $reason, 'ccw_out_of_bounds', "reason names the ccw bound";
}

# 8. CW span seek out of bounds -> fail (CCW homed, then the span seek capped)
{
    my ($ok, $centre, $reason) = home_target(10, undef, 185);
    is $ok,     0,                  "cw out-of-bounds -> not ok";
    is $reason, 'cw_out_of_bounds', "reason names the cw bound";
}

# 9. Stuck-high switch: span <= min plausible -> fail
{
    my ($ok, $centre, $reason) = home_target(10, 0, 185);
    is $ok,     0,                "stuck-high switch (span 0) -> not ok";
    is $reason, 'span_too_small', "reason names the implausible span";
}

# 10. Real traversal -> ok, and re-centre to half the measured span
{
    my ($ok, $centre, $reason) = home_target(10, 370, 185);
    is $ok,     1,    "real traversal -> ok";
    is $centre, 185,  "re-centre to half the measured span (370 -> 185)";
    is $reason, 'ok', "reason ok";
}

# 11. Odd span re-centres with integer division (rounds down)
{
    my ($ok, $centre, $reason) = home_target(10, 371, 185);
    is $centre, 185, "odd span 371 -> centre 185 (int division)";
}

# --- stepper_skew(): the centring math, exercised directly (no hardware) ---

# 12. Equal edges -> truly centred: zero skew, no bias
{
    my $m = stepper_skew(2_000_000, 2_000_000, 3_600_000, 180);
    is $m->{skew_us},   0,         "equal edges -> zero skew";
    is $m->{skew_pct},  0,         "equal edges -> 0% skew";
    is $m->{skew_deg},  0,         "equal edges -> 0 deg off centre";
    is $m->{biased_to}, 'centred', "equal edges -> not biased to either limit";
}

# 13. cw edge later than ccw -> rest point biased toward the CCW limit
{
    # ccw 1.8s, cw 2.2s: skew = +200ms, mean 2.0s -> 10%; pace 180t / 3600ms
    # = 0.05 deg/ms -> 10 deg -> 10/11.25 quanta
    my $m = stepper_skew(1_800_000, 2_200_000, 3_600_000, 180);
    is    $m->{skew_us},   200_000, "cw later -> +skew (toward CCW)";
    about($m->{skew_pct},  10,         "skew_pct = 10% of the mean edge");
    about($m->{skew_deg},  10,         "skew_deg = 10 deg via this sweep's pace");
    about($m->{quanta},    10 / 11.25, "quanta = skew_deg / one full-step quantum");
    is    $m->{biased_to}, 'CCW',   "biased toward the CCW limit";
}

# 14. ccw edge later than cw -> mirror image, biased toward the CW limit
{
    my $m = stepper_skew(2_200_000, 1_800_000, 3_600_000, 180);
    is    $m->{skew_us},   -200_000, "ccw later -> -skew (toward CW)";
    about($m->{skew_pct},  10, "magnitude is direction-independent (10%)");
    about($m->{skew_deg},  10, "skew_deg magnitude is direction-independent");
    is    $m->{biased_to}, 'CW',     "biased toward the CW limit";
}

# 15. skew_pct is speed-independent: same edges at half the pace -> same percent
{
    my $fast = stepper_skew(1_800_000, 2_200_000, 3_600_000, 180);
    my $slow = stepper_skew(3_600_000, 4_400_000, 7_200_000, 180);
    about($slow->{skew_pct}, $fast->{skew_pct},
        "skew_pct identical when the rig is equally off at any speed");
}

# 16. Argument validation (croaks, in order)
{
    eval { stepper_skew(undef, 1, 1, 180) }; ok $@, "undef \$ccw_us croaks";
    eval { stepper_skew('x',   1, 1, 180) }; ok $@, "non-numeric \$ccw_us croaks";
    eval { stepper_skew(1, 'x', 1,   180) }; ok $@, "non-numeric \$cw_us croaks";
    eval { stepper_skew(1, 1, 'x',   180) }; ok $@, "non-numeric \$cw_out_us croaks";
    eval { stepper_skew(1, 1, 1,       0) }; ok $@, "\$cw_ticks of 0 croaks";
}

# --- stepper_calibrate(): the operator tool, with an injected sweep ---

# 17. Within spec -> ok, within_spec true, no action needed
{
    # ~1.2% skew, comfortably under SKEW_LIMIT_PCT
    my $cal = stepper_calibrate(sub { (2_000_000, 2_050_000, 3_600_000) }, 180);
    is $cal->{ok},          1,      "real reading -> ok";
    ok $cal->{within_spec},         "skew under spec -> within_spec true";
    is $cal->{action},      'none', "within spec -> no operator action";
    ok $cal->{skew_pct} <= SKEW_LIMIT_PCT, "reported skew is within the limit";
}

# 18. Off spec -> ok reading, but within_spec false + an actionable instruction
{
    # 10% skew toward CCW, well over spec
    my $cal = stepper_calibrate(sub { (1_800_000, 2_200_000, 3_600_000) }, 180);
    is $cal->{ok},          1,     "off-centre is still a real reading -> ok";
    ok ! $cal->{within_spec},      "skew over spec -> within_spec false";
    is $cal->{biased_to},   'CCW', "names the biased-toward limit";
    like $cal->{action}, qr/backlash/, "action tells the operator to reduce slop";
    like $cal->{action}, qr/CCW/,      "action names the direction";
}

# 19. Sweep captured no edge -> distinguishable failure, not a bogus 'centred'
{
    my $cal = stepper_calibrate(sub { (undef, 2_000_000, 3_600_000) }, 180);
    is $cal->{ok},     0,          "missing edge -> not ok";
    is $cal->{reason}, 'no_edges', "reason names the missing measurement";
}

# 20. Argument validation
{
    eval { stepper_calibrate('x',     180) }; ok $@, "non-coderef \$measure croaks";
    eval { stepper_calibrate(sub {},    0) }; ok $@, "\$cw_ticks of 0 croaks";
}

done_testing();

# SUBROUTINES

# Float-tolerant equality for the derived skew metrics
sub about {
    my ($got, $exp, $msg) = @_;
    ok abs($got - $exp) < 1e-9, $msg;
}

# Build a mock pair: the limit reads true once $trip_at steps have been taken
# (undef = never trips). Returns ($at_limit, $step, \$steps) so a test can
# assert how many steps were actually issued.
sub mocks {
    my ($trip_at) = @_;

    my $steps = 0;
    my $at_limit = sub { defined $trip_at && $steps >= $trip_at };
    my $step     = sub { $steps++ };

    return ($at_limit, $step, \$steps);
}
