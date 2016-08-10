package RPi::WiringPi;

use strict;
use warnings;

use RPi::WiringPi::Pin;

our $VERSION = '0.01';


sub new {
    return bless {}, shift;
}
sub pin {
    my ($self, $pin) = @_;
    my $pin = RPi::WiringPi::Pin->new($pin);
    $self->_register_pin($pin);
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
sub _register_pin {
    my ($self, $pin) = @_;
    push @{ $self->{registered_pins} };
}

1;
__END__

=head1 NAME

RPi::WiringPi - Perl-ized quasi-wrapper for Raspberry Pi's wiringPi library functionality

=head1 SYNOPSIS

  use RPi::WiringPi;

=head1 DESCRIPTION

=head1 SEE ALSO

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by steve02

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
