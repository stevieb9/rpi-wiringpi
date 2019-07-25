package RPi::WiringPi::Meta;

use strict;
use warnings;

use Carp qw(croak);
use Data::Dumper;
use IPC::ShareLite qw(:flock);
use JSON::XS;

our $VERSION = '2.3633_02';

sub _meta {
    my ($self) = @_;

    return $self->{meta_shm} if exists $self->{meta_shm};

    my $shm = IPC::ShareLite->new(
        -key     => 'rpiw',
        -create  => 1,
        -destroy => 0,
    ) or die "can't create shared memory segment: $!";

    $self->{meta_shm} = $shm;
}
sub meta_lock {
    my ($self, $flags) = @_;
    $flags = LOCK_EX if ! defined $flags;
    $self->_meta->lock($flags);
}
sub meta_unlock {
    my ($self) = @_;
    $self->_meta->unlock;
}
sub meta_fetch {
    my ($self) = @_;
    my $json;
    $json = $self->_meta->fetch;
    $json = "{}" if $json eq '';
    my $perl = decode_json $json;
    return $perl
}
sub meta_store {
    my ($self, $data) = @_;
    $self->_meta->store(encode_json $data) or die $!;
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
