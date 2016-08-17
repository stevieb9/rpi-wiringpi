package RPi::WiringPi::Board;

use strict;
use warnings;

use parent 'WiringPi::API';
use RPi::WiringPi::Constant qw(:all);

our $VERSION = '0.99_05';

sub new {
    return bless {}, shift;
}
sub rev {
    return $_[0]->board_rev;
}
sub pwm_range {
    my ($self, $range) = @_;
    $self->pwm_set_range($range);
}
sub _vim{1;};
1;
__END__

=head1 NAME

RPi::WiringPi::Board - Access and manipulate Raspberry Pi board attributes

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

=head2 pwm_range($range)

Changes the range of Pulse Width Modulation (PWM). The default is C<0> through
C<1024>.

Parameters:

    $range

Mandatory: An integer specifying the high-end of the range. The range always
starts at C<0>. Eg: if C<$range> is C<359>, if you incremented PWM by C<1>
every second, you'd rotate a step motor one complete rotation in exactly one
minute.

=head1 SEE ALSO

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
