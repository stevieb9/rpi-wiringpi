# TESTDOC: RPi::StepperMotor unit (HW-free)
use strict;
use warnings;

use RPi::StepperMotor;
use RPi::Const qw(:all);
use Test::More;

# Mirror of RPi::StepperMotor's HW-free tests (its t/05-unit.t), run here against
# the INSTALLED module. new() makes one WiringPi call (setup_gpio) - stubbed - and
# everything else is driven through an injected mock expander whose write()/mode()
# calls we capture, so the step patterns, counter wrap, gearing math and
# validation croaks all run with no motor and no Pi. t/350-stepper.t drives the
# real motor on board-3.
#
# NOTE: the installed 3.1801 predates the 3.1802 speed() fix (its validation was
# dead code), so the "speed('turbo') croaks" assertion lives only in the dist's
# t/05-unit.t until 3.1802 is installed.
{
    no warnings 'redefine';
    *RPi::StepperMotor::setup_gpio = sub { };
}

{
    package Mock::Expander;
    sub new   { bless { writes => [], modes => [] }, shift }
    sub mode  { push @{ $_[0]{modes} },  [$_[1], $_[2]] }
    sub write { push @{ $_[0]{writes} }, [$_[1], $_[2]] }
}

my $mod = 'RPi::StepperMotor';

my @SEQ = (
    [1, 0, 0, 1], [1, 0, 0, 0], [1, 1, 0, 0], [0, 1, 0, 0],
    [0, 1, 1, 0], [0, 0, 1, 0], [0, 0, 1, 1], [0, 0, 0, 1],
);

sub motor {
    my (%extra) = @_;
    return $mod->new(
        pins     => [0, 1, 2, 3],
        expander => Mock::Expander->new,
        delay    => 0,
        %extra,
    );
}

# --- construction + validation croaks ---
eval { $mod->new(expander => Mock::Expander->new) };
like $@, qr/'pins' parameter is required/, 'new(): missing pins croaks';

eval { $mod->new(pins => [1, 2, 3], expander => Mock::Expander->new) };
like $@, qr/four elements/, 'new(): pins aref must have exactly four elements';

{
    my $sm = motor;
    eval { $sm->cw() };
    like $@, qr/degrees must be specified/, 'cw(): missing degrees croaks';
}

# --- speed(): defaults + acceptance (rejection is dist-only, see note) ---
{
    my $sm = motor;
    is $sm->speed, 'half', 'speed(): defaults to half';
    is $sm->speed('full'), 'full', "speed('full'): accepted";
    is $sm->speed('half'), 'half', "speed('half'): accepted";
}

# --- _turns(): 64:1 gearing with round-half-up ---
{
    my $sm = motor(speed => 'half');
    is $sm->_turns(180), 2048, '_turns(180) half';
    is $sm->_turns(1), 0, '_turns(1) half rounds to zero';

    $sm->speed('full');
    is $sm->_turns(180), 1024, '_turns(180) full';
}

# --- cw()/ccw() step patterns + counter wrap ---
{
    my $sm = motor;

    my @first = @{ steps_raw($sm, 'cw', 6) }[0 .. 3];
    is_deeply [map { $_->[0] } @first], [0, 1, 2, 3],
        'cw(): drives the four pins in IN1..IN4 order';
    is_deeply [map { $_->[1] } @first], [HIGH, LOW, LOW, HIGH],
        'cw(): step 0 sets the pins per sequence [1,0,0,1]';

    is_deeply [ (step_indices($sm, 'cw',  6))[0 .. 8] ], [0, 1, 2, 3, 4, 5, 6, 7, 0],
        'cw half: step index advances by one and wraps at 8';

    is_deeply [ (step_indices($sm, 'ccw', 6))[0 .. 8] ], [0, 7, 6, 5, 4, 3, 2, 1, 0],
        'ccw half: step index decrements and wraps at 0';

    $sm->speed('full');
    is_deeply [ (step_indices($sm, 'cw', 12))[0 .. 7] ], [0, 2, 4, 6, 0, 2, 4, 6],
        'cw full: step index advances by two';
}

done_testing();

sub steps_raw {
    my ($sm, $dir, $degrees) = @_;
    @{ $sm->_expander->{writes} } = ();
    $sm->$dir($degrees);
    return $sm->_expander->{writes};
}

sub step_indices {
    my ($sm, $dir, $degrees) = @_;

    my @w = @{ steps_raw($sm, $dir, $degrees) };
    my @indices;

    for (my $i = 0; $i + 3 < @w; $i += 4){
        my @pat = map { $w[$i + $_][1] ? 1 : 0 } 0 .. 3;
        my ($idx) = grep { "@{ $SEQ[$_] }" eq "@pat" } 0 .. $#SEQ;
        push @indices, $idx;
    }

    return @indices;
}
