package RPi::WiringPi;

use strict;
use warnings;

use parent 'RPi::WiringPi::Util';

use RPi::WiringPi::Constant qw(:all);
use RPi::WiringPi::LCD;
use RPi::WiringPi::Pin;
use RPi::WiringPi::Interrupt;

our $VERSION = '0.99_05';

my $fatal_exit = 1;

BEGIN {
    sub error {
        my $err = shift;
        print "\ndie() caught... ".  __PACKAGE__ ." is cleaning up\n",
        _shutdown();
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
            if (! defined $self->{setup}) {
                $self->SUPER::setup();
                $self->pin_scheme(RPI_MODE_WPI);
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
    my $pin = RPi::WiringPi::Pin->new($pin_num);
    #$self->register_pin($pin);
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

# private

sub _fatal_exit {
    my $self = shift;
    $fatal_exit = $self->{fatal_exit} if defined $self->{fatal_exit};
}
sub _setup {
    return $_[0]->{setup};
}
sub _shutdown {
    # emergency die() handler cleanup
    if (defined $ENV{RPI_PINS}) {
        my @pins = split ',', $ENV{RPI_PINS};
        for (@pins) {
            #FIXME: WiringPi::API->write_pin( $_, LOW );
            #FIXME: WiringPi::API->pin_mode( $_, INPUT );
        }
    }
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

    # board

    my $board = $pi->board;
    my $revision = $pi->rev;
    print "Raspberry Pi board revision: $revision"\n";

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
    $lcd->print("Pi rev: $revision");

    # first column, second row
    
    $lcd->position(0, 1);
    $lcd->print("pin $num... mode: $mode, state: $state");

    $lcd->clear;
    $lcd->display(OFF);

    $pi->cleanup;

=head1 DESCRIPTION

WARNING: Until version 1.00 is released, the API and other functionality of
this module may change, and things may break from time-to-time.

This is the root module for the C<RPi::WiringPi> system. It interfaces to a
Raspberry Pi board, its accessories and its GPIO pins via the 
L<wiringPi|http://wiringpi.com> library through the Perl wrapper
L<WiringPi::API|https://metacpan.org/pod/WiringPi::API>
module.

This module is essentially a 'manager' for the sub-modules (ie. components).
You can use the component modules directly, but retrieving components through
this module instead has many benefits. We maintain a registry of pins and other
data. We also trap C<$SIG{__DIE__}> and C<$SIG{INT}>, so that in the event of a
crash, we can reset the Pi back to default settings, so components are not left
in an inconsistent state. Component modules do none of these things.

This module also calls the setup initialization routines automatically, where
in the component modules, you have to do this manually. You also need to clean
up after yourself.

There are a basic set of constants that can be imported. See
L<RPi::WiringPi::Constant>.

L<wiringPi|http://wiringpi.com> must be installed prior to installing/using
this module.

It's handy to have access to a pin mapping conversion chart. There's an
excellent pin scheme map for reference at
L<pinout.xyz|https://pinout.xyz/pinout/wiringpi>. You can also run
C<gpio readall> at the command line to get a pin chart.

=head1 OPERATIONAL METHODS

See L<RPi::WiringPi::Util> for utility/helper methods that are imported into
an C<RPi::WiringPi> object.

=head2 new(%args)

Returns a new C<RPi::WiringPi> object. Calls C<setup()> by default, setting
pin numbering scheme to C<WPI> (wiringPi scheme).

Parameters:

=over 8

=item   setup => $value

Optional. This option specifies which GPIO pin mapping (numbering scheme) to
use. C<wiringPi> for wiringPi's mapping, C<physical> to use the pin
numbers labelled on the board itself, or C<gpio> use the Broadcom (BCM) pin
numbers. You can also specify C<none> for testing purposes. This will bypass
running the setup routines.

C<system> will also use C<BCM> pin numbering, but in this setup mode, we don't
require root privileges to run.

See L<wiringPi setup reference|http://wiringpi.com/reference/setup> for
important details on the differences.

There's an excellent pin scheme map for reference at
L<pinout.xyz|https://pinout.xyz/pinout/wiringpi>.

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

=head2 board()

Returns a L<RPi::WiringPi::Board> object which has access to various
attributes of the Raspberry Pi physical board itself.

=head2 lcd()

Returns a L<RPi::WiringPi::LCD> object, which allows you to fully manipulate
LCD displays connected to your Raspberry Pi.

=head2 interrupt($pin, $edge, $callback)

Returns a L<RPi::WiringPi::Interrupt> object, which allows you to act when
certain events occur (eg: a button press). This module is better used through
the L<RPi::WiringPi::Pin> object.

=head1 IMPORTANT NOTES

=over 4

=item - L<wiringPi|http://wiringpi.com> must be installed prior to
installing/using this module.

=item - By default, we use C<BCM> interpretation of GPIO pin mapping.
See C<new> method to change this behaviour.

=item - This module hijacks fatal errors with C<$SIG{__DIE__}>, as well as
C<$SIG{INT}>. This is so that in the case of a fatal error, the Raspberry Pi
pins are never left in an inconsistent state. By default, we trap the C<die()>,
reset all pins to their default (INPUT, LOW), then we C<exit()>. Look at the
C<fatal_exit> param in C<new()> to change the behaviour.

=back

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
