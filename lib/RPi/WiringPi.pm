package RPi::WiringPi;

use strict;
use warnings;

use parent 'RPi::WiringPi::Core';

use RPi::WiringPi::Constant qw(:all);
use RPi::WiringPi::LCD;
use RPi::WiringPi::Pin;

our $VERSION = '0.04';

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
        if (defined $self->{setup}){
            if ($self->_setup =~ /^w/){
                $self->SUPER::setup();
                $self->pin_map('wiringPi');
            }
            elsif ($self->_setup =~ /^g/){
                $self->SUPER::setup_gpio();
                $self->pin_map('GPIO');
            }
            elsif ($self->_setup =~ /^s/){
                $self->SUPER::setup_sys();
                $self->pin_map('BCM');
            }
            elsif ($self->_setup =~ /^p/){
                $self->SUPER::setup_phys();
                $self->pin_map('PHYS GPIO');
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
sub pin_map {
    my ($self, $map) = @_;
    if (defined $map){
        $self->{pin_map} = $map;
    }
    return defined $self->{pin_map}
        ? $self->{pin_map}
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
    if (defined $ENV{RPI_PINS}){
        my @pins = split ',', $ENV{RPI_PINS};
        for (@pins){
            RPi::WiringPi::Core->write_pin($_, LOW);
            RPi::WiringPi::Core->pin_mode($_, INPUT);
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

    my $board = $pi->board;

    print "Raspberry Pi board revision: ". $board->rev ."\n";

    my $gpio_pin_1 = $pi->pin(1);
    my $gpio_pin_2 = $pi->pin(2);

    $gpio_pin_1->mode(INPUT);
    $gpio_pin_2->mode(OUTPUT);

    my $pin1_on = $gpio_pin_1->read;

    if ($pin1_on){
        $gpio_pin_2->write(HIGH);
    }

    $pi->cleanup;

=head1 DESCRIPTION

WARNING: Until version 1.00 is released, the API and other functionality of
this module may change, and things may break from time-to-time.

This is the root module for the C<RPi::WiringPi> system. It interfaces to a
Raspberry Pi board, its accessories and its GPIO pins via the 
L<wiringPi|http://wiringpi.com> library through the Perl wrapper
L<RPi::WiringPi::Core|https://metacpan.org/pod/RPi::WiringPi::Core>
module.

There are a basic set of constants that can be imported. See
L<RPi::WiringPi::Constant>.

L<wiringPi|http://wiringpi.com> must be installed prior to installing/using
this module.

By default, we use C<wiringPi>'s interpretation of GPIO pin mapping. See
C<new> method to change this behaviour.

=head1 OPERATIONAL METHODS

=head2 new(%args)

Returns a new C<RPi::WiringPi> object. 

Parameters:

=over 8

=item   setup => $value

Optional. This option specifies which GPIO pin mapping (numbering scheme) to
use. C<wiringPi> for wiringPi's mapping, C<physical> or C<system> to use the pin
numbers labelled on the board itself, or C<gpio> use the Broadcom (BCM) pin
numbers.

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

=head2 pin_map()

Returns the current pin mapping in use. Returns C<"NULL"> it has not yet been
set.

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
