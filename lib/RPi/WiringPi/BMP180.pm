package RPi::WiringPi::BMP180;

use strict;
use warnings;

our $VERSION = '2.36.3';

use parent 'WiringPi::API';
use RPi::WiringPi::Constant qw(:all);

sub new {
    my ($class, $pin_base) = @_;
    my $self = bless {}, $class;
    $self->_pin_base($pin_base);
    $self->bmp180_setup($pin_base);

    return $self;
}
sub temp {
    my ($self, $want) = @_;
    return $self->bmp180_temp($self->_pin_base + 0, $want);
}
sub pressure {
    my ($self) = @_;
    return $self->bmp180_pressure($self->_pin_base + 1);
}
sub _pin_base {
    my ($self, $base) = @_;

    if (defined $base){
        if ($base !~ /^\d+$/){
            die "_pin_base() requires an integer\n";
        }
        $self->{bmp_pin_base} = $base;
    }

    if (! defined $self->{bmp_pin_base}){
        die "_pin_base() has not yet been set...\n";
    }
    return $self->{bmp_pin_base};
}
sub _vim{};

1;
__END__

=head1 NAME

RPi::WiringPi::BMP180 - Perl interface to the BMP180 barometric pressure sensor

=head1 SYNOPSIS

    use RPi::WiringPi::BMP180;

    my $base = 300;

    my $bmp = RPi::WiringPi::BMP180($base);

    my $f = $bmp->temp;
    my $c = $bmp->temp('c');
    my $p = $bmp->pressure; # kPa

=head1 DESCRIPTION

This module allows you to interface with a BMP180 barometric and temperature
sensor. It is best used through a L<RPi::WiringPi> object, but will work as a
standalone module.

=head1 METHODS

=head2 new($pin_base)

Returns a new C<RPi::WiringPi::BMP180> object.

Parameters:

    $pin_base

Mandatory: Integer, the number at which to start the 'pseudo' GPIO pins for
communication to the sensor. Anything above the highest numbered GPIO pin will
do. For example, C<100> or C<200>.

=head2 temp

Fetches the temperature from the sensor.

Parameters:

    $want

Optional: String. By default, we return Farenheit. To get Celcius, pass in
C<'c'>.

Returns a floating point number.

=head2 pressure

Fetches the barometric pressure in kPa.

Takes no parameters, returns a floating point number.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
