package RPi::WiringPi::Meta;

use strict;
use warnings;

use Carp qw(croak);
use IPC::ShareLite qw(:flock);
use JSON::XS;

our $VERSION = '2.3634';

sub meta {
    my ($self) = @_;

    return $self->{meta_shm} if exists $self->{meta_shm};

    my $shm = IPC::ShareLite->new(
        -key     => $self->{shm_key},
        -create  => 1,
        -destroy => 0,
    ) or die "can't create shared memory segment: $!";

    $self->{meta_shm} = $shm;
}
sub meta_key_check {
    # this is a class method, and must be called on the class prior to creating
    # a Pi object

    my ($class, $key) = @_;

    if (! defined $key){
        croak "meta_key_check() requires a key sent in...\n";
    }

    $key = unpack('i', pack('A4', $key));
    my $shm_check = shmget($key, 65536, 0);
    return defined $shm_check ? 1 : 0;
}
sub meta_key {
    my ($self) = @_;
    return $self->meta->key;
}
sub meta_lock {
    my ($self, $flags) = @_;
    $flags = LOCK_EX if ! defined $flags;
    $self->meta->lock($flags);
}
sub meta_unlock {
    my ($self) = @_;
    $self->meta->unlock;
}
sub meta_fetch {
    my ($self) = @_;
    my $json;
    $json = $self->meta->fetch;
    $json = "{}" if $json eq '';
    my $perl = decode_json $json;
    return $perl
}
sub meta_store {
    my ($self, $data) = @_;

    if (! defined $data){
        croak "meta_store() requires a hash reference sent in...\n";
    }

    $self->meta->store(encode_json $data) or die $!;
}
sub meta_delete {
    my ($self, $name) = @_;

    if (! defined $name){
        croak "when setting a metadata slot, you must send in a name\n";
    }

    $self->meta_lock;
    my $shm = $self->meta_fetch;
    delete $shm->{storage}{$name};
    $self->meta_store($shm);
    $self->meta_unlock;
}
sub meta_set {
    my ($self, $name, $data) = @_;

    if (! defined $name){
        croak "when setting a metadata slot, you must send in a name\n";
    }

    if (ref $data ne 'HASH'){
        croak "when setting a metadata slot, you must supply a hash reference\n";
    }

    $self->meta_lock;
    my $shm = $self->meta_fetch;
    $shm->{storage}{$name} = { %$data };
    $self->meta_store($shm);
    $self->meta_unlock;
}
sub meta_get {
    my ($self, $name) = @_;

    if (! defined $name){
        croak "when getting a metadata slot, you must send in a name\n";
    }

    $self->meta_lock;
    my $shm = $self->meta_fetch;
    my $data = { %{ $shm->{storage}{$name} }};
    $self->meta_unlock;

    return $data;
}
sub meta_erase {
    my ($self) = @_;

    $self->meta_lock;
    $self->meta_store({});
    $self->meta_unlock;
}
sub _vim{1;};

1;

__END__

=head1 NAME

RPi::WiringPi::Meta - Shared memory meta data management for RPI::WiringPi

=head1 DESCRIPTION

This module contains various utilities for the shared memory storage area.

=head1 METHODS

=head2 meta

Instantiates and returns a shared memory object that stores the meta data.

=head2 meta_set($name, $href)

Adds a user-defined hash reference to the shared memory segment with it's key
named C<$name>.

Parameters:

    $name

Mandatory, String: Any value that is a legitimate value for a hash key.

    $href

Mandatory, Hash Reference: A hash reference that contains your data.

=head2 meta_get($name)

Retrieves a user-defined hash reference from the shared memory.

Parameters:

    $name

Mandatory, String: The key name for the user defined data.

Returns: Hash reference.

=head2 meta_delete($name)

Deletes a user-defined shared memory segment.

Parameters:

    $name

Mandatory, String: The key name for the user defined data to delete.

=head2 meta_fetch

NOTE: For most use cases, users should use the L</meta_get($name)> method as
opposed to this one.

Fetches and returns the shared memory data as a hash reference.

=head2 meta_store($data)

NOTE: For most use cases, users should use the L</meta_set($name, $href)> and
L</meta_delete($name)> methods as opposed to this one.

Serializes and stores the shared data.

Parameters:

    $data

Mandatory, Hash Reference. The data to store (should be a modified version that
was retrieved using C<meta_fetch()>).

=head2 meta_lock($flags)

Although we do locking on each transaction internally, use this as a wrapper
around bulk transactions.

Parameters:

    $flags

Mandatory, Integer. See L<flock|http://man7.org/linux/man-pages/man2/flock.2.html>
for details as to what's available here.

Default: If C<$flags> is not sent in, we default to an exclusive lock
(C<LOCK_EX>).

=head2 meta_unlock

Performs an unlock after you're done with C<meta_lock()>.

=head2 meta_key

Returns the shared memory key that links the object to the shared memory
segment.

=head2 meta_key_check($key)

Checks whether a shared memory segment with the key C<$key> exists or not.

Parameters:

    $key

Mandatory, String: A four letter key to validate against. This will be converted
into its integer form internally.

Returns: True C<1> if the shared memory segment exists, and false C<0>
otherwise.

=head2 meta_erase

Completely erases and resets all meta data. Do not use this method lightly.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016-2019 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
