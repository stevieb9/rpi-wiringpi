package RPi::WiringPi::Pin;

use strict;
use warnings;

use parent 'RPi::WiringPi::Core';

our $VERSION = '0.04';

sub new {
    my ($class, $pin) = @_;

    if (! defined $pin || ($pin > 40 || $pin < 0)){
        die "pin number must be between 0 and 40\n";
    }

    my $self = bless {}, $class;

    $self->{pin} = $pin;
    return $self;
}
sub mode {
    my ($self, $mode) = @_;
    if (! defined $mode){
        return $self->get_alt($self->num);
    }
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
sub pull {
    my ($self, $direction) = @_;
    $self->pull_up_down($self->num, $direction);
}
sub pwm {
    my ($self, $value) = @_;
    if ($self->mode != 2){
        my $num = $self->num;
        die "\npin $num isn't set to mode 2 (PWM). pwm() can't be set\n";
    }
    $self->pwm_write($self->num, $value);
}
sub num {
    return $_[0]->{pin};
}
sub _vim{1;};
1;
__END__

=head1 NAME

RPi::WiringPi::Pin - Access and manipulate Raspberry Pi GPIO pins

=head1 SYNOPSIS

    use RPi::WiringPi;
    use RPi::Constant qw(:all);

    my $pi = RPi::WiringPi->new;

    my $pin = $pi->pin(5);

    $pin->mode(OUTPUT);
    $pin->write(HIGH);

    my $num = $pin->num;
    my $mode = $pin->mode;
    my $state = $pin->read;

    print "pin number $num is in mode $mode with state $state\n";

=head1 DESCRIPTION

Through a L<RPi::WiringPi> object, creates objects that directly attach to
Raspberry Pi GPIO pins.

Using the pin object's methods, the GPIO pins can be controlled and monitored.

=head1 METHODS

=head2 new($pin_num)

Takes the number representing the Pi's GPIO pin you want to use, and returns
an object for that pin.

Parameters:

    $pin_num

Mandatory. 

Mandatory: The pin number to attach to.

=head2 mode($mode)

Puts the GPIO pin into either INPUT or OUTPUT mode. If C<$mode> is not sent in,
we'll return the pin's current mode.

Parameters:

    $mode

Optional: If not sent in, we'll simply return the current mode of the pin.
Otherwise, send in: C<0> for INPUT, C<1> for OUTPUT, C<2> for PWM_OUT and C<3>
for GPIO_CLOCK (clock) mode.

=head2 read()

Returns C<1> if the pin is HIGH (on) and C<0> if the pin is LOW (off).

=head2 write($state)

For pins in OUTPUT mode, will turn on (HIGH) the pin, or off (LOW).

Parameters:

    $state

Send in C<1> to turn the pin on, and C<0> to turn it off.

=head2 pull($direction)

Used to set the internal pull-up or pull-down resistor for a pin.

Parameter:

    $direction

Mandatory: C<2> for UP, C<1> for DOWN and C<0> to turn off the resistor.

=head2 pwm($value)

Sets the level of the Pulse Width Modulation (PWM) of the pin. Dies if the
pin's C<mode()> is not set to PWM (C<2>).

Parameter:

    $value

Mandatory: values range from 0-1023. C<0> for 0% (off) and C<1023> for 100% (fully on).

=head2 num()

Returns the pin number associated with the pin object.

=head1 SEE ALSO

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
