package RPi::WiringPi;

use strict;
use warnings;

use parent 'RPi::WiringPi::Core';

use Carp qw(carp croak);
use RPi::WiringPi::Constant qw(:all);
use RPi::WiringPi::Pin;

our $VERSION = '0.03';

sub new {
    my ($self, %args) = @_;
    $self = bless {%args}, $self;

    if (! $ENV{NO_BOARD}){
        if ($self->_setup =~ /^w/){
            $self->SUPER::setup();
        }
        elsif ($self->_setup =~ /^g/){
            $self->SUPER::setup_gpio();
        }
        elsif ($self->_setup =~ /^p/){
            $self->SUPER::setup_phys();
        }
    }
    return $self;
}
sub pin {
    my ($self, $pin_num) = @_;
    my $pin = RPi::WiringPi::Pin->new($pin_num);
    $self->register_pin($pin);
    return $pin;
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
            croak "pin $num is already in use\n";
        }
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
        carp "pin ". $pin->num ." is not registered, and can't be unregistered\n";
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
sub _setup {
    return $_[0]->{setup};
}
sub _vim{1;};
1;
__END__

=head1 NAME

RPi::WiringPi - Perl interface to Raspberry Pi's board/GPIO pin functionality

=head1 SYNOPSIS

    use RPi::WiringPi;

    use constant {
        INPUT => 0,
        OUTPUT => 1,
        ON => 1,
        OFF => 0,
    };

    my $pi = RPi::WiringPi->new;

    my $gpio_pin_1 = $pi->pin(1);
    my $gpio_pin_2 = $pi->pin(2);

    $gpio_pin_1->mode(INPUT);
    $gpio_pin_2->mode(OUTPUT)

    my $is_hot = $gpio_pin_1->read;

    if ($is_hot){
        $gpio_pin_2->write(ON);
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

L<wiringPi|http://wiringpi.com> must be installed prior to installing/using
this module.

By default, we use C<wiringPi>'s interpretation of GPIO pin mapping. See
C<new> method to change this behaviour.

=head1 PUBLIC METHODS

=head2 new(setup => $value)

Returns a new C<RPi::WiringPi> object. 

Parameters:

    $value

Optional. This option specifies which GPIO pin mapping (numbering scheme) to
use. C<wiringPi> for wiringPi's mapping, C<physical> to use the pin numbers
labelled on the board itself, or C<gpio> use the Broadcom (BCM) pin numbers.

=head2 pin($pin_num)

Returns a L<RPi::WiringPi::Pin> object, mapped to a specified GPIO pin.

Parameters:

    $pin_num

Mandatory: The pin number to attach to.

=head2 cleanup()

Resets all registered pins back to default settings (off). It's important that
this method be called in each application.

=head1 HELPER METHODS 

These methods aren't normally needed by end-users. They're available for those
who want to write their own libraries.

=head2 registered_pins()

Returns an array of L<RPi::WiringPi::Pin> objects that are currently
registered, and deemed to be in use.

=head2 register_pin($pin_obj)

Registers a GPIO pin within the system for error checking, and proper resetting
of the pins in use when required.

Parameters:

    $pin_obj

Mandatory: An object instance of L<RPi::WiringPi::Pin> class.

=head2 unregister_pin($pin_obj)

Exactly the opposite of C<register_pin()>.

=head1 ENVIRONMENT VARIABLES

There are certain environment variables available to aid in testing on
non-Raspberry Pi boards.

=head2 NO_BOARD

Set to true, will bypass the C<wiringPi> board checks. False will re-enable
them.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
