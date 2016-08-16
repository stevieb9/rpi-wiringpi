package RPi::WiringPi::Interrupt;

use strict;
use warnings;
use threads;

use parent 'WiringPi::API';
use parent 'RPi::WiringPi::Util';

use Config;
use RPi::WiringPi::Constant qw(:all);

our $VERSION = '0.06';

my $interrupts = {};

sub new {
    $Config{useithreads}
      or die "Perl is not compiled with threads, Interrupts not available\n";
    return bless {}, shift;
}
sub set {
    my ($self, $pin, $edge, $callback) = @_;
    $interrupts->{$pin}{$edge}{value} = $edge;
    $interrupts->{$pin}{$edge}{callback} = $callback;
    $interrupts->set_interrupt($pin, $edge, $callback);
}
sub unset {
    my ($self, $pin) = @_;
    if ($pin eq 'all'){
        for my $pin (keys %$interrupts){
            for my $edge (keys %{ $interrupts->{$pin} }){
                $interrupts->unset($pin);
            }
        }
    }
    else {
        system "gpio", "edge", $pin, "none";
    }
}
sub DESTROY {
    my $self = shift;
    $self->unset('all');
}

sub _vim{1;};
1;
__END__

=head1 NAME

RPi::WiringPi::Interrupt - Raspberry Pi GPIO pin interrupts

=head1 SYNOPSIS

    use RPi::WiringPi::Interrupt;
    use RPi::WiringPi::Constant qw(:all);

    my $int = RPi::WiringPi::Interrupt->new;

    my $pin = 6;

    $int->set($pin, EDGE_HIGH, 'interrupt_handler');

    sub interrupt_handler {
        print "in handler";
        # turn a pin on, or do other things
    }

    $int->unset($pin);

=head1 DESCRIPTION

This module allows you to set up, and un-set GPIO pin edge detection
interrupts where you can supply the name of a Perl subroutine that you write
that will act as the interrupt handler.

The backend is written in C and is threaded, so it doesn't block the main
program thread from running while waiting for the interrupt to occur.

=head1 METHODS

=head2 new()

Returns a new C<RPi::WiringPi::Interrupt> object.

=head2 set($pin, $edge, $callback)

Starts a new thread that waits for an interrupt on the specified pin, when the
selected edge is triggered. The name of the Perl subroutine in C<$callback>
will be the code executed as the interrupt handler.

Parameters:

    $pin

Mandatory: The pin number to set the interrupt on. We'll convert the pin number
appropriately regardless of which pin mapping you're currently using.

    $edge

Mandatory: One of C<1> (LOW), C<2> (HIGH) or C<3> for both HIGH and LOW.

    $callback

Mandatory: This is the name of a user-written Perl subroutine that contains
the code you want to execute when the edge change is detected on the pin.
(ie. the Interrupt Handler).

=head2 unset($pin)

Terminates an interrupt thread, and stops monitoring for more.

Parameters:

    $pin

Mandatory: The pin number. You can also send in C<'all'>, which will disable
all currently implemented interrupts.

    $edge

Mandatory: see C<set()> for details.

=head1 SEE ALSO

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
