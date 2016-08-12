package RPi::WiringPi;

use strict;
use warnings;

use parent 'RPi::WiringPi::Core';

use RPi::WiringPi::Constant qw(:all);
use RPi::WiringPi::Core;
use RPi::WiringPi::LCD;
use RPi::WiringPi::Pin;

our $VERSION = '0.05';

my $fatal_exit = 1;

BEGIN {
    sub error {
        my $err = shift;
        print "\ndie() caught... ".  __PACKAGE__ ." is cleaning up\n",
        RPi::WiringPi::_shutdown();
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
        if (! defined $self->{setup}) {
            $self->SUPER::setup();
            $self->gpio_scheme( 'WPI' );
        }
        else {
            if ($self->_setup =~ /^w/){
                $self->SUPER::setup();
                $self->gpio_scheme('WPI');
            }
            elsif ($self->_setup =~ /^g/){
                $self->SUPER::setup_gpio();
                $self->gpio_scheme('BCM');
            }
            elsif ($self->_setup =~ /^s/){
                $self->SUPER::setup_sys();
                $self->gpio_scheme('BCM');
            }
            elsif ($self->_setup =~ /^p/){
                $self->SUPER::setup_phys();
                $self->gpio_scheme('PHYS');
            }
            elsif ($self->_setup =~ /^n/){
                $self->gpio_scheme('NULL');
            }
        }
    }
    $self->_fatal_exit;
    return $self;
}
sub pin {
    my ($self, $pin_num) = @_;
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

# helper

sub gpio_map {
    my ($self, $scheme) = @_;

    $scheme = $self->gpio_scheme if ! defined $scheme;

    return {} if $scheme eq 'NULL';
    if (defined $self->{gpio_map_cache}{$scheme}){
        return $self->{gpio_map_cache}{$scheme};
    }

    return {} if $scheme eq 'NULL';

    my %map;

    for (0..63){
        my $gpio;
        if ($scheme eq 'WPI') {
            $gpio = RPi::WiringPi::Core::phys_to_wpi($_);
        }
        elsif ($scheme eq 'BCM'){
            $gpio = RPi::WiringPi::Core::phys_to_gpio($_);
        }
        elsif ($scheme eq 'PHYS'){
            $gpio = $_;
        }
        $map{$_} = $gpio;
    }
    $self->{gpio_map_cache}{$scheme} = \%map;
}
sub gpio_scheme {
    my ($self, $scheme) = @_;
    if (defined $scheme){
        $self->{gpio_scheme} = $scheme;
    }
    return defined $self->{gpio_scheme}
        ? $self->{gpio_scheme}
        : 'NULL';
}
sub registered_pins {
    my $self = shift;
    my @pin_nums;
    for (@{ $self->{registered_pins} }){
        push @pin_nums, $_;
    }
    return @pin_nums;
}
sub register_pin {
    my ($self, $pin) = @_;
    my @current_pins = $self->registered_pins;
    for (@current_pins){
        if ($pin->num == $_->num){
            my $num = $pin->num;
            die "pin $num is already in use\n";
        }
    }
    if (! defined $ENV{RPI_PINS}){
        $ENV{RPI_PINS} = $pin->num;
    }
    else {
        $ENV{RPI_PINS} = $ENV{RPI_PINS} . $pin->num;
    }
    push @{ $self->{registered_pins} }, $pin;
}
sub unregister_pin {
    my ($self, $pin) = @_;
    my @pins;
    for ($self->registered_pins){
        if ($_->num != $pin->num){
            push @pins, $_;
        }
        else {
            # disable the pin before unregistering
            $pin->write(0);
            $pin->mode(0);
        }
    }
    if (@pins == $self->registered_pins){
        warn "pin ". $pin->num ." is not registered, and can't be " .
             "unregistered\n";
    }
    @{ $self->{registered_pins} } = @pins;
    return $self->registered_pins;
}
sub cleanup {
    my $self = shift;
    for ($self->registered_pins){
        $self->unregister_pin($_);
        if ($_->mode){
            my $num = $_->num;
            warn "\npin $num couldn't be disabled/unregistered!\n";
        }
    }
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
            RPi::WiringPi::Core->write_pin( $_, LOW );
            RPi::WiringPi::Core->pin_mode( $_, INPUT );
        }
    }
}

sub _vim{1;};
1;
__END__

=head1 NAME

RPi::WiringPi - Perl interface to Raspberry Pi's board and GPIO pin
functionality

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
L<RPi::WiringPi::Core|https://metacpan.org/pod/RPi::WiringPi::Core>
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

=head1 OPERATIONAL METHODS

=head2 new(%args)

Returns a new C<RPi::WiringPi> object. 

Parameters:

=over 8

=item   setup => $value

Optional. This option specifies which GPIO pin mapping (numbering scheme) to
use. C<wiringPi> for wiringPi's mapping, C<physical> or C<system> to use the pin
numbers labelled on the board itself, or C<gpio> use the Broadcom (BCM) pin
numbers. You can also specify C<none> for testing purposes. This will bypass
running the setup routines.

See L<wiringPi setup reference|http://wiringpi.com/reference/setup> for
important details on the differences.

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

=head2 cleanup()

Resets all registered pins back to default settings (off). It's important that
this method be called in each application.

=head1 HELPER METHODS 

These methods aren't normally needed by end-users. They're available for those
who want to write their own libraries.

=head2 gpio_scheme()

Returns the current pin mapping in use. Returns C<"NULL"> it has not yet been
set, C<"WPI"> if using C<wiringPi> mapping, C<"BCM"> for standard GPIO map and
C<"PHYS"> if using the physical pin map directly.

=head2 gpio_map($scheme)

Returns a hash reference in the following format:

    $map => {
        phys_pin_num => gpio_pin_num,
        ...
    };

If no scheme is in place, return will be an empty hash reference.

Parameters:

=over 8

=item    $scheme

Optional: By default, we'll check if you've already run a setup routine, and
if so, we'll use the scheme currently in use. If one is not in use and no
C<$scheme> has been sent in, we'll use C<'NULL'>, otherwise if a scheme is sent
in, the return will be:

For C<'WPI'> scheme (wiringPi's numbering scheme):

    $map = {
        phys_pin_num => wiringPi_gpio_pin_num,
        ....
    };

For C<'BCM'> scheme (Broadcom's numbering scheme (printed on the board)):

    $map = {
        phys_pin_num => Broadcom_gpio_pin_num,
        ...
    };

=back

=head2 registered_pins()

Returns an array of L<RPi::WiringPi::Pin> objects that are currently
registered, and deemed to be in use.

=head2 register_pin($pin_obj)

Registers a GPIO pin within the system for error checking, and proper resetting
of the pins in use when required.

Parameters:

=over 8

=item    $pin_obj

Mandatory: An object instance of L<RPi::WiringPi::Pin> class.

=back

=head2 unregister_pin($pin_obj)

Exactly the opposite of C<register_pin()>.

=head1 ENVIRONMENT VARIABLES

There are certain environment variables available to aid in testing on
non-Raspberry Pi boards.

=head2 NO_BOARD

Set to true, will bypass the C<wiringPi> board checks. False will re-enable
them.

=head1 IMPORTANT NOTES

=over 4

=item - L<wiringPi|http://wiringpi.com> must be installed prior to
installing/using this module.

=item - By default, we use C<wiringPi>'s interpretation of GPIO pin mapping.
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
