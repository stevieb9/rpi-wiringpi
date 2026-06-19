use warnings;
use strict;

use lib 't/';

use StepperSeek qw(seek_limit home_target);
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

done_testing();

# SUBROUTINES

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
