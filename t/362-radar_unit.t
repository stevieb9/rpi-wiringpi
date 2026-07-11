# TESTDOC: RPi::Radar::RCWL0516 unit (HW-free)
use strict;
use warnings;
use Time::HiRes qw(time);

use Test::More;

# Mirror of RPi::Radar::RCWL0516's HW-free tests (its t/05-params.t +
# t/10-logic.t), run here against the INSTALLED module. The driver reads the
# sensor's OUT line through an RPi::Pin. Standing a MockPin in for RPi::Pin
# before the module requires it captures the pin number, mode, motion reads and
# the wait_for_* polling with no sensor, no wiringPi and no Pi. t/361-radar.t
# reads a real RCWL-0516 through $pi->radar.
#
# Non-gated: needs no hardware and runs anywhere. Skips cleanly only when the
# (as-yet-unreleased) family leaf isn't installed.

BEGIN {
    if (! eval { require RPi::Radar::RCWL0516; 1 }){
        plan skip_all => "RPi::Radar::RCWL0516 not installed";
    }

    # Stand in for the RPi::Pin GPIO transport the driver loads at runtime
    no warnings 'once', 'redefine';
    $INC{'RPi/Pin.pm'} = __FILE__;
    *RPi::Pin::new = sub {
        my (undef, @args) = @_;
        return MockPin->new(@args);
    };
}

my $mod = 'RPi::Radar::RCWL0516';

# --- validation croaks (mirror of dist t/05-params.t) ---

eval { $mod->new; };
like $@, qr/pin param/, "new() dies without a pin param";

eval { $mod->new(pin => 'abc'); };
like $@, qr/pin param/, "new() rejects a non-integer pin";

eval { $mod->new(pin => 23, poll => 'abc'); };
like $@, qr/\$seconds param/, "new() rejects a non-numeric poll";

eval { $mod->new(pin => 23, poll => 0); };
like $@, qr/\$seconds param/, "new() rejects a zero poll";

{
    my $fake = bless {}, $mod;

    eval { $fake->poll('abc'); };
    like $@, qr/\$seconds param/, "poll() validates the seconds value";

    eval { $fake->wait_for_motion('abc'); };
    like $@, qr/\$timeout param/, "wait_for_motion() validates the timeout";

    eval { $fake->wait_for_motion(-1); };
    like $@, qr/\$timeout param/, "wait_for_motion() rejects a negative timeout";

    eval { $fake->wait_for_clear(-1); };
    like $@, qr/\$timeout param/, "wait_for_clear() rejects a negative timeout";
}

# --- logic (mirror of dist t/10-logic.t) ---

my $radar = $mod->new(pin => 23, poll => 0.01);
my $mock  = $MockPin::instance;

isa_ok $radar, $mod;
is $mock->num, 23, "new() hands the pin number to the RPi::Pin transport";
is $mock->{mode}, 0, "new() puts the pin into INPUT mode";

MockPin->set_reads(0);
is $radar->motion, 0, "motion() returns 0 while the output is low";

MockPin->set_reads(1);
is $radar->motion, 1, "motion() returns 1 while the output is high";

MockPin->set_reads(42);
is $radar->motion, 1, "motion() normalises any true read to 1";

is $radar->poll, 0.01, "poll() returns the interval set through new()";
is $radar->poll(0.02), 0.02, "poll() sets and returns a new interval";
is $radar->pin, $mock, "pin() exposes the underlying transport object";

my $default = $mod->new(pin => 5);
is $default->poll, 0.1, "the poll interval defaults to 0.1 seconds";

MockPin->set_reads(1);
is $radar->wait_for_motion, 1,
    "wait_for_motion() returns immediately when the output is already high";

MockPin->set_reads(0, 0, 0, 1);
is $radar->wait_for_motion(5), 1, "wait_for_motion() polls until the output goes high";

MockPin->set_reads(0);
is $radar->wait_for_motion(0), 0, "wait_for_motion(0) still reads the pin once";

MockPin->set_reads(0);
my $start = time();
is $radar->wait_for_motion(0.1), 0, "wait_for_motion() times out when no motion arrives";
cmp_ok time() - $start, '>=', 0.1, "...after the requested timeout has elapsed";

MockPin->set_reads(1, 1, 0);
is $radar->wait_for_clear(5), 1, "wait_for_clear() polls until the output drops low";

MockPin->set_reads(1);
is $radar->wait_for_clear(0.1), 0, "wait_for_clear() returns 0 while the output stays high";

done_testing();

# In-memory pin: read() walks the queue set by set_reads(), the final value
# sticks, mimicking a level that has settled.

package MockPin;

my @reads;
our $instance;

sub new {
    my ($class, $pin, $comment) = @_;
    $instance = bless { pin => $pin, comment => $comment, mode => undef }, $class;
    return $instance;
}
sub mode {
    my ($self, $mode) = @_;
    $self->{mode} = $mode if defined $mode;
    return $self->{mode};
}
sub num {
    return $_[0]->{pin};
}
sub read {
    return @reads > 1 ? shift @reads : $reads[0];
}
sub set_reads {
    my (undef, @values) = @_;
    @reads = @values;
}
