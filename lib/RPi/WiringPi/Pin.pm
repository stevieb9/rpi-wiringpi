package RPi::WiringPi::Pin;

use strict;
use warnings;

use parent 'WiringPi::API';
use parent 'RPi::WiringPi::Util';

use RPi::WiringPi::Constant qw(:all);
use RPi::WiringPi::Interrupt;

our $VERSION = '0.99_05';

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
    if ($mode != 0 && $mode != 1 && $mode != 2 && $mode != 3){
        die "Core::pin_mode() mode param must be either 0 (input), 1 " .
            "(output), 2 (PWM output) or 3 (GPIO CLOCK output)\n";
    }

    # shell out to 'gpio' if in SYS mode

    if ($self->pin_scheme == RPI_MODE_GPIO_SYS){
        $mode = $mode == 0 ? 'in' : 'out';
        my $num = $self->num;
        `sudo gpio -g $num $mode`;
    }
    else {
        $self->pin_mode($self->num, $mode);
    }
}
sub read {
    my $state = $_[0]->read_pin($_[0]->num);
    return $state;
}
sub write {
    my ($self, $value) = @_;
    if ($value != 0 && $value != 1){
        die "Core::write_pin value must be 0 or 1\n";
    }
    $self->write_pin($self->num, $value);
}
sub pull {
    my ($self, $direction) = @_;

    # 0 == down, 1 == up, 2 == off

    if ($direction != 0 && $direction != 1 && $direction != 2){
        die "Core::pull_up_down requires either 0, 1 or 2 for direction";
    }

    # shell out to 'gpio' if in SYS mode

    if ($self->pin_scheme == RPI_MODE_GPIO_SYS){

        if ($direction == 0){
            $direction = 'down';
        }
        elsif ($direction == 1){
            $direction = 'up';
        }
        else {
            $direction = 'tri';
        }

        my $num = $self->num;

        `sudo gpio -g $num $direction`;
    }
    else {
        $self->pull_up_down($self->num, $direction);
    }
}
sub pwm {
    my ($self, $value) = @_;
    if ($self->mode != 2){
        my $num = $self->num;
        die "\npin $num isn't set to mode 2 (PWM). pwm() can't be set\n";
    }
    if ($value > 1023 || $value < 0){
        die "Core::pwm_write value must be 0-1023";
    }
    $self->pwm_write($self->num, $value);
}
sub num {
    return $_[0]->{pin};
}
sub interrupt_set {
    my ($self, $edge, $callback) = @_;
    my $int = RPi::WiringPi::Interrupt->new;
    $int->set($self->num, $edge, $callback);
    $self->{interrupt} = $int;
}
sub interrupt_unset {
    my $self = shift;
    if (! defined $self->{interrupt}){
        die "pin " . $self->num ." doesn't have an interrupt to unset\n";
    }
    $self->{interrupt}->unset($self->num);
}
sub _vim{1;};
1;
__END__

=head1 NAME

RPi::WiringPi::Pin - Access and manipulate Raspberry Pi GPIO pins

=head1 SYNOPSIS

    use RPi::WiringPi::Pin;
    use RPi::Constant qw(:all);

    my $pin = RPi::WiringPi::Pin->new(5);

    $pin->setup;

    $pin->mode(INPUT);
    $pin->write(LOW);

    $pin->set_interrupt(EDGE_RISING, 'pin5_interrupt_handler');

    my $num = $pin->num;
    my $mode = $pin->mode;
    my $state = $pin->read;

    print "pin number $num is in mode $mode with state $state\n";

    sub pin5_interrupt_handler {
        print "in interrupt handler\n";
    }

=head1 DESCRIPTION

An object that represents a physical GPIO pin.

Using the pin object's methods, the GPIO pins can be controlled and monitored.

Using this module outside of the base L<RPi::WiringPi> object requires you
to run one of the L<WiringPi::API>'s C<setup*> methods.

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

=head2 interrupt_set($edge, $callback)

Listen for an interrupt on a pin, and do something if it is triggered.

Parameters:

    $edge

Mandatory: C<1> (falling), C<2> (rising), or C<3> for both.

    $callback

The string name of a Perl subroutine that you've already written within your
code. This is the interrupt handler. When an interrupt is triggered, the code
in this subroutine will run.

=head2 interrupt_unset()

Removes an interrupt from the pin, if set.

=head2 pwm($value)

Sets the level of the Pulse Width Modulation (PWM) of the pin. Dies if the
pin's C<mode()> is not set to PWM (C<2>).

Parameter:

    $value

Mandatory: values range from 0-1023. C<0> for 0% (off) and C<1023> for 100%
(fully on).

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
