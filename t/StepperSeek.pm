package StepperSeek;

use warnings;
use strict;

use Carp qw(croak);
use Exporter 'import';

our @EXPORT_OK = qw(seek_limit home_target stepper_calibrate stepper_skew SKEW_LIMIT_PCT);

use constant {
    SKEW_LIMIT_PCT => 3.0,     # Max centre skew (% of mean edge) before the rig needs mechanical attention
    QUANTUM_DEG    => 11.25,    # One full-step quantum (degrees) - the "one tooth" unit for the readout
};

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

# stepper_calibrate(\&measure, $cw_ticks)
#
# The operator-facing centring tool. \&measure performs ONE quick out-and-back
# sweep on the real rig and returns ($ccw_us, $cw_us, $cw_out_us) - the two edge
# latencies (microseconds from the rest point to each magnet) and the cw
# out-sweep time. The callback is injected so this is unit-testable without a
# motor (t/451) and reusable by anything that can drive a sweep.
#
# Returns the stepper_skew() metrics hashref augmented with:
#
#   ok           1 (use this to tell a real reading from the failure below)
#   within_spec  true when skew_pct <= SKEW_LIMIT_PCT (no mechanical action)
#   action       a one-line operator instruction ('none' when within spec)
#
# If the sweep could not capture both edges (dead switch / dropped step train)
# returns { ok => 0, reason => 'no_edges' }, so a caller can tell "off centre"
# apart from "could not measure".
sub stepper_calibrate {
    my ($measure, $cw_ticks) = @_;

    if (ref $measure ne 'CODE') {
        croak "stepper_calibrate() requires \$measure as a code ref";
    }

    if (! defined $cw_ticks || $cw_ticks !~ /^\d+$/ || $cw_ticks < 1) {
        croak "stepper_calibrate() requires \$cw_ticks as a positive integer";
    }

    my ($ccw_us, $cw_us, $cw_out_us) = $measure->();

    if (! defined $ccw_us || ! defined $cw_us || ! defined $cw_out_us) {
        return { ok => 0, reason => 'no_edges' };
    }

    my $m = stepper_skew($ccw_us, $cw_us, $cw_out_us, $cw_ticks);

    $m->{ok}          = 1;
    $m->{within_spec} = $m->{skew_pct} <= SKEW_LIMIT_PCT;

    if ($m->{within_spec}) {
        $m->{action} = 'none';
    }
    else {
        # State the direction (factual); the corrective lever is reducing gear
        # backlash, NOT a fixed tooth count - homing re-centres between the
        # magnets every run, so the rest point cannot be dialled in by nudging
        # the gear to a particular tooth (see t/450 header).
        $m->{action} = sprintf
            'rest point ~%.1f deg (%.1f%%) toward %s - reduce gear backlash / '
          . 'recentre until skew <= %.1f%%',
            $m->{skew_deg}, $m->{skew_pct}, $m->{biased_to}, SKEW_LIMIT_PCT;
    }

    return $m;
}

# stepper_skew($ccw_us, $cw_us, $cw_out_us, $cw_ticks)
#
# Pure centring math. Given the two edge latencies (microseconds from the rest
# point to each magnet) plus the cw out-sweep time and its commanded tick count
# (to convert elapsed time into degrees of travel), return a metrics hashref:
#
#   skew_us    signed half-difference of the edges (+ => biased toward CCW)
#   skew_pct   |skew| as a percentage of the mean edge (speed-independent)
#   skew_deg   |skew| expressed in degrees of travel
#   quanta     skew_deg in full-step quanta (~one tooth each)
#   biased_to  'CCW', 'CW', or 'centred' - which limit the rest point favours
#
# When the rig is truly centred the magnets are equidistant from the rest point,
# so the two edges match and the skew is ~0; a persistent non-zero skew is an
# off-centre rest point. Speed-independent by construction (skew_pct is a ratio;
# skew_deg uses this sweep's own pace), so it is comparable across every config.
sub stepper_skew {
    my ($ccw_us, $cw_us, $cw_out_us, $cw_ticks) = @_;

    if (! defined $ccw_us || $ccw_us !~ /^-?\d+(?:\.\d+)?$/) {
        croak "stepper_skew() requires \$ccw_us as a number";
    }

    if (! defined $cw_us || $cw_us !~ /^-?\d+(?:\.\d+)?$/) {
        croak "stepper_skew() requires \$cw_us as a number";
    }

    if (! defined $cw_out_us || $cw_out_us !~ /^-?\d+(?:\.\d+)?$/) {
        croak "stepper_skew() requires \$cw_out_us as a number";
    }

    if (! defined $cw_ticks || $cw_ticks !~ /^\d+$/ || $cw_ticks < 1) {
        croak "stepper_skew() requires \$cw_ticks as a positive integer";
    }

    # Signed: + means the cw edge is later than the ccw edge, i.e. the rest point
    # sits closer to the CCW magnet (biased toward the CCW limit).
    my $skew_us  = ($cw_us - $ccw_us) / 2;
    my $mean_us  = ($cw_us + $ccw_us) / 2;
    my $skew_pct = $mean_us ? abs($skew_us) / $mean_us * 100 : 0;

    # Convert the time skew to degrees using THIS sweep's own pace (out-sweep
    # time / commanded ticks), so the figure is speed- and delay-independent.
    my $deg_per_ms = $cw_out_us ? $cw_ticks / ($cw_out_us / 1000) : 0;
    my $skew_deg   = abs($skew_us) / 1000 * $deg_per_ms;

    my $biased_to = $skew_us > 0 ? 'CCW'
                  : $skew_us < 0 ? 'CW'
                  :                'centred';

    return {
        skew_us   => $skew_us,
        skew_pct  => $skew_pct,
        skew_deg  => $skew_deg,
        quanta    => $skew_deg / QUANTUM_DEG,
        biased_to => $biased_to,
    };
}

1;
