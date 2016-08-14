package RPi::WiringPi::Interrupt;

use strict;
use warnings;

use parent 'RPi::WiringPi::Core';
use RPi::WiringPi::Constant qw(:all);

our $VERSION = '0.06';

my %callbacks;

sub new {
    return bless {}, shift;
}
sub set {
    my ($self, $pin, $int_num, $edge_type, $cref) = @_;
    $callbacks{$int_num} = $cref;
    RPi::WiringPi::Core::registerInterrupt($pin, $edge_type, $int_num);
}
sub interrupt_one {
    print "in interrupt2\n";
    $callbacks{1}->();
}
sub interrupt_two {
    print "in interrupt2\n";
    $callbacks{2}->();
}

sub _vim{1;};
1;
__END__

=head1 NAME

RPi::WiringPi::Interrupt - Raspberry Pi GPIO pin interrupts

=head1 SYNOPSIS

    use RPi::WiringPi;
    
    my $pi = RPi::WiringPi->new;

    my $board = $pi->board;

    my $board_revision = $board->rev;

    my $pin_num = 5;
    my $wpi_to_gpio = $board->wpi_to_gpio($pin_num);
    my $phys_to_gpio = $board->phys_to_gpio($pin_num);

    print "rev: $board_revision\n" .
          "wiringPi pin $pin_num translated to gpio pin num: $wpi_to_gpio\n" .
          "physical pin $pin_num translated to gpio pin num: $phys_to_gpio";

    # change the Pulse Width Modulation (PWM) range maximum

    $board->pwm_range(512);

=head1 DESCRIPTION

Through a L<RPi::WiringPi> object, creates objects that has direct access to
various attributes on the Rasperry Pi board itself.

=head1 METHODS

=head2 new()

Returns a new C<RPi::WiringPi::Board> object.

=head2 rev()

Returns the revision of the Pi board.

=head2 wpi_to_gpio($pin_num)

Converts a pin number from C<wiringPi> notation to Broadcom (BCM) notation,
and returns the BCM representation.

Parameters:

    $pin_num

Mandatory: The C<wiringPi> representation of a pin number.

=head2 phys_to_gpio($pin_num)

Converts a pin number as physically documented on the Raspberry Pi board
itself to Broadcom (BCM) notation, and returns it.

Parameters:

    $pin_num

Mandatory: The pin number printed on the physical Pi board.

=head1 SEE ALSO

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
