package RPi::WiringPi::Pin;

use strict;
use warnings;

use Carp qw(croak);
use parent 'RPi::WiringPi::Core';

our $VERSION = '0.01';

sub new {
    my ($class, $pin) = @_;

    if (! defined $pin || ($pin > 40 || $pin < 0)){
        croak "pin number must be between 0 and 40\n";
    }

    my $self = bless {}, $class;

    $self->{pin} = $pin;
    return $self;
}
sub mode {
    my ($self, $mode) = @_;
    $self->pin_mode($self->num, $mode);
}
sub read {
    my $state = $_[0]->read_pin($_[0]->num);
    return $state;
}
sub write {
    my ($self, $value) = @_;
    $self->write_pin($self->num, $value);
}
sub num {
    return $_[0]->{pin};
}

1;
__END__

=head1 NAME

RPi::WiringPi::Pin - GPIO wiringPi pin module

=head1 SYNOPSIS

    use RPi::WiringPi::Pin;
    
    use constant {
        INPUT => 0,
        OUTPUT => 1,
        ON => 1,
        OFF => 0,
    };

    my $pin = RPi::WiringPi::Pin->new(5);
    $pin->mode(OUTPUT);
    $pin->write(ON);

    my $pin_num = $pin->num;
    my $pin_state = $pin->read;

    print "pin number $pin_num is in state $pin_state\n";

=head1 DESCRIPTION

This module creates objects that directly attach to Raspberry Pi GPIO pins.

Using the object's methods, the GPIO pins can be controlled and monitored.

=head1 METHODS

=head2 new($pin_num)

Takes the number representing the Pi's GPIO pin you want to use, and returns
an object for that pin.

Parameters:

    $pin_num

Mandatory. 

The L<wiringPi|http://wiringpi.com> representation of a pin number.

=head2 mode($mode)

Puts the GPIO pin into either INPUT or OUTPUT mode.

Parameters:

    $mode

Mandatory: C<0> to have the pin listen on INPUT, and C<1> for OUTPUT.

=head2 read()

Returns C<1> if the pin is HIGH (on) and C<0> if the pin is LOW (off).

=head2 write($state)

For pins in OUTPUT mode, will turn on (HIGH) the pin, or off (LOW).

Parameters:

    $state

Send in C<1> to turn the pin on, and C<0> to turn it off.

=head2 num()

Returns the L<wiringPi|http://wiringPi> numeric representation of the GPIO pin
number attached to this pin object.

=head1 SEE ALSO

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
