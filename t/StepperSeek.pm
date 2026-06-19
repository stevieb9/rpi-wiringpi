package StepperSeek;

use warnings;
use strict;

use Carp qw(croak);
use Exporter 'import';

our @EXPORT_OK = qw(seek_limit home_target);

# seek_limit(\&at_limit, \&step, $max_ticks)
#
# Step toward a limit one tick at a time until the limit reads true, bounded by
# $max_ticks. \&at_limit returns true when the limit switch is active; \&step
# advances the motor one tick. Returns the tick count at which the limit tripped
# (0 if already at the limit before any step), or undef if $max_ticks ticks
# elapsed without it tripping.
#
# The undef return is the safety bound: a caller MUST treat it as a hard fault
# and stop driving - never continue stepping into the mechanical hard stop. The
# callbacks are injected so the bound is unit-testable without real hardware.
sub seek_limit {
    my ($at_limit, $step, $max_ticks) = @_;

    if (ref $at_limit ne 'CODE') {
        croak "seek_limit() requires \$at_limit as a code ref";
    }

    if (ref $step ne 'CODE') {
        croak "seek_limit() requires \$step as a code ref";
    }

    if (! defined $max_ticks || $max_ticks !~ /^\d+$/ || $max_ticks < 1) {
        croak "seek_limit() requires \$max_ticks as a positive integer";
    }

    # Already at the limit - never drive a step into the hard stop
    return 0 if $at_limit->();

    for my $tick (1 .. $max_ticks) {
        $step->();
        return $tick if $at_limit->();
    }

    # Bound hit: the switch never tripped within $max_ticks
    return undef;
}

# home_target($to_ccw, $span, $min_span)
#
# Decide the outcome of a homing attempt from its two bounded-seek results:
# $to_ccw (the CCW-home seek) and $span (the CCW->CW span seek), each a tick
# count or undef when seek_limit hit its bound. $min_span is the smallest
# plausible span (a stuck-high switch reads as ~0 ticks). Returns
# ($ok, $centre, $reason): on success $ok is true and $centre = int($span / 2)
# (the move back to mid-travel); on failure $ok is false, $centre is undef, and
# $reason names the guard that tripped. Pure, so the out-of-bounds and re-centre
# paths are unit-testable without a motor.
sub home_target {
    my ($to_ccw, $span, $min_span) = @_;

    return (0, undef, 'ccw_out_of_bounds') if ! defined $to_ccw;
    return (0, undef, 'cw_out_of_bounds')  if ! defined $span;
    return (0, undef, 'span_too_small')    if $span <= $min_span;

    return (1, int($span / 2), 'ok');
}

1;
