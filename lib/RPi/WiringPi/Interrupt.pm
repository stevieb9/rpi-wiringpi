package RPi::WiringPi::Interrupt;

use strict;
use warnings;
use threads;

use parent 'RPi::WiringPi::Core';
use parent 'RPi::WiringPi::Util';

use Config;
use RPi::WiringPi::Constant qw(:all);

our $VERSION = '0.06';

my %callbacks;


sub new {
    $Config{useithreads}
      or die "Perl is not compiled with threads, Interrupts not available\n";
    return bless {}, shift;
}
sub set {
    my ($self, $pin, $edge, $cref) = @_;
    $self->{$pin}{$edge}{value} = $edge;
    $self->{$pin}{$edge}{cref} = $cref;
    $self->_thread($pin, $edge, $cref);
}
sub unset {
    my ($self, $pin, $edge) = @_;
    if ($edge eq 'all'){
        for my $pin (keys %$self){
            for my $edge (keys %{ $self->{$pin} }){
                $self->unset($pin, $edge);
            }
        }
    }
    else {
        $self->{$pin}{$edge}{thread}->kill('SIGUSR1');
    }
}
sub _thread {
    my ($self, $pin, $edge, $cref);
    $self->{$pin}{$edge}{thread} = threads->create(\&_handler, $pin, $edge, $cref);
    #$self->{$pin}{$edge}{thread}->detach;
    print "$pin, $edge handler thread created\n";
}
sub _handler {
    my ($pin, $edge, $cref) = @_;

    my $cmd = 'gpio ';

    if ($self->gpio_scheme eq 'WPI'){
        $pin = $self->wpi_to_gpio($pin);
    }
    if ($self->gpio_scheme eq 'PHYS'){
        $cmd .= '-1 ';
    }

    $cmd .= "edge $pin $edge";

    while (1){
        my $ret = `$cmd`;
        $cref->();
    }
}
sub DESTROY {
    threads->exit();
}

sub _vim{1;};
1;
__END__

=head1 NAME

RPi::WiringPi::Interrupt - Raspberry Pi GPIO pin interrupts

=head1 SYNOPSIS

    use RPi::WiringPi::Interrupt;
    
    my $int = RPi::WiringPi::Interrupt->new;

    my $pin = 6;
    my $edge = 'rising';

    $int->set($pin, $rising, sub { print "edge rising detected on pin $pin!\n"; });

=head1 DESCRIPTION

Threaded GPIO pin edge detection interrupts. I'm not experienced enough in C to
write them with that language yet, so use at your own risk.

=head1 METHODS

=head2 new()

Returns a new C<RPi::WiringPi::Interrupt> object.

=head2 set($pin, $edge, $cref)

Starts a new thread that waits for an interrupt on the specified pin, when the
selected edge is triggered.

Parameters:

    $pin

Mandatory: The pin number to set the interrupt on. We'll convert the pin number
appropriately regardless of which pin mapping you're currently using.

    $edge

Mandatory: One of C<rising> (HIGH), C<falling> (LOW) or C<both>.

    $cref

Mandatory: This is a subroutine reference that contains the code you want to
execute when the edge change is detected on the pin.

=head2 unset($pin, $edge)

Terminates an interrupt thread, and stops monitoring for more.

Parameters:

    $pin

Mandatory: The pin number.

    $edge

Mandatory: see C<set()> for details. Send in C<all> to stop all interrupts.

=head1 SEE ALSO

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
