package RPi::WiringPi::Util;

use strict;
use warnings;

use parent 'WiringPi::API';

use RPi::WiringPi::Constant qw(:all);

our $VERSION = '0.99_03';

sub pin_to_gpio {
    my ($self, $pin, $scheme) = @_;

    $scheme = defined $scheme
        ? $scheme
        : $self->gpio_scheme;

    if ($scheme eq 'WPI'){
        return WiringPi::API::wpi_to_gpio($pin);
    }
    elsif ($scheme eq 'PHYS'){
        return WiringPi::API::phys_to_gpio($pin);
    }
    elsif ($scheme eq 'BCM'){
        return $pin;
    }
    if ($scheme eq 'NULL'){
        die "can't determine pin mapping\n";
    }
}
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
            $gpio = WiringPi::API::phys_to_wpi($_);
        }
        elsif ($scheme eq 'BCM'){
            $gpio = WiringPi::API::phys_to_gpio($_);
        }
        elsif ($scheme eq 'PHYS'){
            $gpio = $_;
        }
        $map{$_} = $gpio;
    }
    $self->{gpio_map_cache}{$scheme} = \%map;

    return \%map;
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
sub export_pin {
    my ($self, $pin) = @_;
    system "sudo", "gpio", "export", $pin;
}
sub unexport_pin {
    my ($self, $pin) = @_;
    system "sudo", "gpio", "unexport", $pin;
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
        $ENV{RPI_PINS} = "$ENV{RPI_PINS}," . $pin->num;
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

sub _vim{1;};
1;

__END__

=head1 NAME

RPi::WiringPi::Util - Utility methods for RPi::WiringPi Raspberry Pi
interface

=head1 DESCRIPTION

WARNING: Until version 1.00 is released, the API and other functionality of
this module may change, and things may break from time-to-time.

This module contains various utilities for L<RPi::WiringPi> that don't
necessarily fit anywhere else. It is a base class, and is not designed to be
used independently.

=head1 METHODS

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

=head2 pin_to_gpio($pin, $scheme)

Converts the specified pin from the specified scheme (C<WPI>, C<PHYS>, C<BCM>)
to the C<BCM> number format.

If C<$scheme> is not sent in, we'll attempt to fetch the scheme currently in
use and use that.

Example:

    my $num = pin_to_gpio(6, 'WPI');

That will understand the pin number 6 to be the wiringPi representation, and
will return the C<BCM> representation.

=head2 export_pin($pin_num)

Exports a pin. Not needed if using the C<setup()> initialization method.

Pin number must be the C<BCM> pin number representation.

=head2 unexport_pin($pin_num)

Unexports a pin.

Pin number must be the C<BCM> pin number representation.

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

=head2 cleanup()

Resets all registered pins back to default settings (off). It's important that
this method be called in each application.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
