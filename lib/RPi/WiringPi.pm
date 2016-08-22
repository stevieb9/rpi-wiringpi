package RPi::WiringPi;

use strict;
use warnings;

use parent 'RPi::WiringPi::Util';

use RPi::WiringPi::Constant qw(:all);
use RPi::WiringPi::LCD;
use RPi::WiringPi::Pin;
use RPi::WiringPi::Interrupt;

our $VERSION = '0.99_06';

my $fatal_exit = 1;

BEGIN {
    sub error {
        my $err = shift;
        print "\ndie() caught... ".  __PACKAGE__ ." is cleaning up\n",
        RPi::WiringPi::Util::cleanup();
        print "\ncleaned up, exiting...\n";
        print "\noriginal error: $err\n";
        exit if $fatal_exit;
    }

    $SIG{__DIE__} = \&error;
    $SIG{INT} = \&error;
};

# core

sub new {
    my ($self, %args) = @_;
    $self = bless {%args}, $self;

    if (! $ENV{NO_BOARD}){

        if (my $scheme = $ENV{RPI_SCHEME}){
            # this checks if another application has already run
            # a setup routine

            $self->pin_scheme($scheme);
        }
        else {
            # we default to wpi mode

            if (! defined $self->{setup}) {
                $self->SUPER::setup_gpio();
                $self->pin_scheme(RPI_MODE_GPIO);
            }
            else {
                if ($self->_setup =~ /^s/) {
                    $self->SUPER::setup_sys();
                    $self->pin_scheme(RPI_MODE_GPIO_SYS);
                }
                elsif ($self->_setup =~ /^w/) {
                    $self->SUPER::setup();
                    $self->pin_scheme(RPI_MODE_WPI);
                }
                elsif ($self->_setup =~ /^g/) {
                    $self->SUPER::setup_gpio();
                    $self->pin_scheme(RPI_MODE_GPIO);
                }
                elsif ($self->_setup =~ /^p/) {
                    $self->SUPER::setup_phys();
                    $self->pin_scheme(RPI_MODE_PHYS);
                }
                else {
                    $self->pin_scheme(RPI_MODE_UNINIT);
                }
            }
        }
        # set the env var so we can catch multiple
        # setup calls properly

        $ENV{RPI_SCHEME} = $self->pin_scheme;
    }
    $self->_fatal_exit;
    return $self;
}
sub pin {
    my ($self, $pin_num) = @_;

    my $pins_in_use = $self->registered_pins;
    my $gpio = $self->pin_to_gpio($pin_num);

    if (defined $ENV{RPI_PINS} && grep {$gpio == $_} split /,/, $pins_in_use){
        die "\npin $pin_num is already in use... can't create second object\n";
    }

    my $pin = RPi::WiringPi::Pin->new($pin_num);
    $self->register_pin($pin);
    return $pin;
}
sub board {
    my $self = shift;
    my $board = RPi::WiringPi::Board->new;
    return $board;
}
sub lcd {
    my $self = shift;
    my $lcd = RPi::WiringPi::LCD->new;
    return $lcd;
}
sub interrupt {
    my $self = shift;
    my $interrupt = RPi::WiringPi::Interrupt->new;
    return $interrupt;
}
sub rev {
    return $_[0]->board_rev;
}
sub pwm_range {
    my ($self, $range) = @_;
    if (defined $range){
       $self->{pwm_range} = $range;
        $self->pwm_set_range($range);
    }
    return defined $self->{pwm_range} ? $self->{pwm_range} : 1023;
}

# private

sub _fatal_exit {
    my $self = shift;
    $fatal_exit = $self->{fatal_exit} if defined $self->{fatal_exit};
}
sub _setup {
    return $_[0]->{setup};
}

sub _vim{1;};
1;
__END__

=head1 NAME

RPi::WiringPi - Perl interface to Raspberry Pi's board, GPIO, LCDs and other
various items

=head1 SYNOPSIS

    use RPi::WiringPi;
    use RPi::WiringPi::Constant qw(:all);

    my $pi = RPi::WiringPi->new;

    my $board_revision = $pi->rev;

    # pin

    my $pin = $pi->pin(5);
    $pin->mode(OUTPUT);
    $pin->write(ON);


    my $num = $pin->num;
    my $mode = $pin->mode;
    my $state = $pin->read;

    # LCD

    my $lcd = $pi->lcd;

    $lcd->init(...);

    # first column, first row
    
    $lcd->position(0, 0); 
    $lcd->print("Pi rev: $board_revision");

    # first column, second row
    
    $lcd->position(0, 1);
    $lcd->print("pin $num... mode: $mode, state: $state");

    $lcd->clear;
    $lcd->display(OFF);

    $pi->cleanup;

=head1 DESCRIPTION

This (v0.99_06) will be the last unstable release before v1.00 becomes
available. Things may be broken and documentation may be inaccurate.

This is the root module for the C<RPi::WiringPi> system. It interfaces to a
Raspberry Pi board, its accessories and its GPIO pins via the
L<wiringPi|http://wiringpi.com> library through the Perl wrapper
L<WiringPi::API|https://metacpan.org/pod/WiringPi::API>
module.

IMPORTANT (C<root> vs C<sudo>):

Using this software requires root privileges. There are two separate modes you
can select from... one where you must run your scripts as C<root>, the other
where you can use a non-root user. For the latter, we do make a few calls with
C<sudo>, so when in this mode, your user account must have password-less
C<sudo> access to at minimum the C<gpio> command line utility. The default user
account (C<pi>) on Raspbian OS has this right by default. We default to using
the C<gpio> configuration, which requires root. See the details in the C<new> 
method below for further details.

This module is essentially a 'manager' for the sub-modules (ie. components).
You can use the component modules directly, but retrieving components through
this module instead has many benefits. We maintain a registry of pins and other
data. We also trap C<$SIG{__DIE__}> and C<$SIG{INT}>, so that in the event of a
crash, we can reset the Pi back to default settings, so components are not left
in an inconsistent state. Component moduls do none of these things.

There are a basic set of constants that can be imported. See
L<RPi::WiringPi::Constant>.

L<wiringPi|http://wiringpi.com> must be installed prior to installing/using
this module.

It's handy to have access to a pin mapping conversion chart. There's an
excellent pin scheme map for reference at
L<pinout.xyz|https://pinout.xyz/pinout/wiringpi>. You can also run
C<gpio readall> at the command line to get a pin chart, or from the command
line, run the C<pinmap> command that was installed by this module.

=head1 OPERATIONAL METHODS

See L<RPi::WiringPi::Util> for utility/helper methods that are imported into
an C<RPi::WiringPi> object.

=head2 new(%args)

Returns a new C<RPi::WiringPi> object. Calls C<setup()> by default, setting
pin numbering scheme to C<WPI> (wiringPi scheme).

Parameters:

=over 8

=item   setup => $value

Optional. This option specifies which pin mapping (numbering scheme) to use.

    wiringPi:   wiringPi's numbering
    physical:   physical pin numbering
    gpio:       GPIO numbering          # default if not sent in
    system:     GPIO numbering (root not required)

You can also specify C<none> for testing purposes. This will bypass running
the setup routines.

!!! C<system> mode uses C<sudo> !!!

C<system> mode is the only mode where you do not need to run your application
as the C<root> user. To this end, in C<wiringPi> when using C<system> mode,
you have to export and manually manipulate the pins with the C<gpio>
application prior to using them. I have wrapped around this limitation by
making these calls with C<sudo> for you, so that you don't have to do anything
different no matter the mode you're using.

When using C<system> mode, the user running your application should be able
to at minimum call the C<gpioc> application without supplying a password.
The default Raspberry Pi user C<pi> can do this by default.

See L<wiringPi setup reference|http://wiringpi.com/reference/setup> for
important details on the differences.

There's an excellent pin scheme map for reference at
L<pinout.xyz|https://pinout.xyz/pinout/wiringpi>. You can also run the C<pinmap>
application that was included in this distribution from the command line to get
a printout of pin mappings.

=back

=over 8 

=item   fatal_exit => $bool

Optional: We trap all C<die()> calls and clean up for safety reasons. If a
call to C<die()> is trapped, by default, we clean up, and then C<exit()>. Set
C<fatal_exit> to false (C<0>) to perform the cleanup, and then continue running
your script. This is for unit testing purposes only.

=back

=head2 pin($pin_num)

Returns a L<RPi::WiringPi::Pin> object, mapped to a specified GPIO pin.

Parameters:

=over 8

=item    $pin_num

Mandatory: The pin number to attach to.

=back

=head2 lcd()

Returns a L<RPi::WiringPi::LCD> object, which allows you to fully manipulate
LCD displays connected to your Raspberry Pi.

=head2 interrupt($pin, $edge, $callback)

Returns a L<RPi::WiringPi::Interrupt> object, which allows you to act when
certain events occur (eg: a button press). This module is better used through
the L<RPi::WiringPi::Pin> object.

=head2 rev()

Returns the revision of the Pi board.

=head2 pwm_range($range)

Changes the range of Pulse Width Modulation (PWM). The default is C<0> through
C<1023>.

Parameters:

    $range

Mandatory: An integer specifying the high-end of the range. The range always
starts at C<0>. Eg: if C<$range> is C<359>, if you incremented PWM by C<1>
every second, you'd rotate a step motor one complete rotation in exactly one
minute.

=head1 RUNNING TESTS

This distribution does not have a typical set of unit tests. This is because to
ensure proper functionality, you need to be running on a Rasbperry Pi board that
has a couple of very basic circuits set up.

The tests are in individual Perl scripts inside of the C<test/> directory inside
this distribution.

Each test, when run without any command line arguments, will print out what you
need to do. Most tests require a single LED connected to a single GPIO pin, then
you select the test number to run (1-4) and pass that in as an argument.

The number of the test correlates with a specific setup mode.

Example:

    $ perl test/10-pwm.pl

    need test number as arg: 1-WPI, 2-GPIO, 3-PHYS, 4-SYS

    this test tests the pwm() pin function. Connect an LED to physical pin *12*.
    The LED should gradually get brighter for each test.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
