package RPi::WiringPi::Meta;

use strict;
use warnings;

use Carp qw(croak);
use Data::Dumper;
use IPC::Shareable;
use IPC::SpawnShared;

our $VERSION = '2.3633_02';

sub meta_spawn {
    my ($self) = @_;
    if ($self->{shared}){
        my $hv = IPC::SpawnShared->spawn('rpiw', 1);
        $self->meta_data($hv);
    }
    else {
        $self->{meta} = {};
    }
}
sub meta_data {
    $_[0]->{meta} = $_[1] if defined $_[1];
    return %{ $_[0]->{meta} };
}
sub meta_cleanup {
    my ($self) = @_;
    IPC::SpawnShared->unspawn('rpiw', 1) if keys %{ $self->{meta}{objects} } == 0;
}
sub _vim{1;};

1;

__END__

=head1 NAME

RPi::WiringPi::Meta - Shared memory meta data management for RPI::WiringPi

=head1 DESCRIPTION

This module contains various utilities for the shared memory storage area.

=head1 METHODS

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016-2019 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
