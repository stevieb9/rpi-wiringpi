package RPi::WiringPi::Util;

use strict;
use warnings;

use parent 'WiringPi::API';
use Carp qw(croak);
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use IPC::Shareable;
use RPi::Const qw(:all);

our $VERSION = '2.3633_02';

my %shared_pi_info;

#BEGIN {
#    local $SIG{__WARN__} = sub { 
#        my $warn = shift;
#        print "$warn\n" if $warn !~ /Storable/;
#    };
#
#    my $init_shared = eval {
#        local $SIG{__DIE__} = sub {};
#        tie %shared_pi_info, 'IPC::Shareable', {
#            key => 'rpiw',
#            create => 0
#        };
#        1;
#    };
#
#    if (! defined $init_shared){
#        tie %shared_pi_info, 'IPC::Shareable', {
#            key => 'rpiw',
#            create => 1
#        };
#    }
#}
sub _shared {
    my ($self) = @_;

    return \%shared_pi_info if %shared_pi_info;

    local $SIG{__WARN__} = sub { 
        my $warn = shift;
        print "$warn\n" if $warn !~ /Storable/;
    };

    my $init_shared = eval {
        local $SIG{__DIE__} = sub {};
        $self->{$$} = tie %shared_pi_info, 'IPC::Shareable', {
            key => 'rpiw',
            create => 0,
            delete => 0
        };
        1;
    };

    if (! defined $init_shared){
        $self->{$$} = tie %shared_pi_info, 'IPC::Shareable', {
            key => 'rpiw',
            create => 1,
            delete => 0
        };
    }

    return \%shared_pi_info;
}
sub meta_lock {
    my ($self, %args) = @_;

    my $name   = $args{name};
    my $state  = $args{state};
    my $delete = $args{delete};

    return keys %{ $shared_pi_info{locks} } if ! defined $name;

    if (defined $name && defined $state){
        $shared_pi_info{locks}->{$name}{state} = $state;
    }

    return '' if ! exists $shared_pi_info{locks}->{$name};

    if (defined $delete && $delete){
        delete $shared_pi_info{locks}{$name};
        return keys %{ $shared_pi_info{locks} };

    }

    return $shared_pi_info{locks}->{$name}{state};
}
sub checksum {
     return md5_hex(rand());
}
sub dump_signal_handlers {
    my ($self) = @_;
    print Dumper $self->_signal_handlers;
}
sub dump_metadata {
    my ($self) = @_;
    print Dumper $self->metadata;
}
sub dump_object {
    my ($self) = @_;
    print Dumper $self;
}
sub metadata {
    my %meta = %shared_pi_info;
    return \%meta;
}
sub pin_map {
    my ($self, $scheme) = @_;

    $scheme = $self->pin_scheme if ! defined $scheme;

    return {} if $scheme eq RPI_MODE_UNINIT;

    if (defined $self->{pin_map_cache}{$scheme}){
        return $self->{pin_map_cache}{$scheme};
    }

    my %map;

    for (0..63){
        my $pin;
        if ($scheme == RPI_MODE_WPI) {
            $pin = $self->phys_to_wpi($_);
        }
        elsif ($scheme == RPI_MODE_GPIO){
            $pin = $self->phys_to_gpio($_);
        }
        elsif ($scheme == RPI_MODE_PHYS){
            $pin = $_;
        }
        $map{$_} = $pin;
    }
    $self->{pin_map_cache}{$scheme} = \%map;

    return \%map;
}
sub signal_handlers {
    my ($self) = @_;
    return $self->_signal_handlers;
}
sub uuid {
    my ($self) = @_;
    return $self->{uuid};
}
sub clean_shared {
    %shared_pi_info = ();
}
sub _vim{1;};
1;

__END__

=head1 NAME

RPi::WiringPi::Util - Utility methods outside of Pi hardware functionality

=head1 DESCRIPTION

This module contains various utilities for L<RPi::WiringPi> that don't
necessarily fit anywhere else. It is a base class, and is not designed to be
used independently.

=head1 METHODS

=head2 meta_lock(%args)

Fetches and sets software "locks". Useful for when you've got multiple
processes trying to use a single-use-only feature (such as serial).

Parameters:

All parameters are sent in as a hash.

    name => 'string'

Optional, String: The name of the lock. If this is not sent in, we'll return an
array with the names of all existing locks.

    state => 0|1

Optional, Bool: The state of the lock. If this is sent in, we'll set the lock
supplied in the C<name> parameter to this value.

    delete => 1

Optional, Bool: Deletes a lock from the shared memory. You must also supply the
C<name> parameter for this to have any effect.

Returns: Array of all existing lock names if a name isn't sent in, and the
current state of the lock if it is. If using C<delete>, we'll return a list of
all existing lock names after the deletion occurs. Will return C<''> if a name
is sent in, but no lock exists by that name.

=head2 checksum

Returns a randomly generated 32-byte hexidecimal MD5 checksum. We use this
internally to generate a UUID for each Pi object.

=head2 dump_metadata

Used for troubleshooting/development, dumps the system's meta data within the
shared memory storage using L<Data::Dumper>.

=head2 dump_object

Used for troubleshooting/development, dumps the object using L<Data::Dumper>.

=head2 metadata

During operation, we store several pieces of meta data of both the Pi object
as well as operational status information in shared memory.

Call this method to get a copy of this meta information.

Return: Hash reference containing the meta data.

=head2 pin_map($scheme)

Returns a hash reference in the following format:

    $map => {
        phys_pin_num => pin_num,
        ...
    };

If no scheme is in place or one isn't sent in, return will be an empty hash
reference.

Parameters:

    $scheme

Optional: By default, we'll check if you've already run a setup routine, and
if so, we'll use the scheme currently in use. If one is not in use and no
C<$scheme> has been sent in, we'll return an empty hash reference, otherwise
if a scheme is sent in, the return will be:

For C<'wiringPi'> scheme:

    $map = {
        phys_pin_num => wiringPi_pin_num,
        ....
    };

For C<'GPIO'> scheme:

    $map = {
        phys_pin_num => gpio_pin_num,
        ...
    };

=head2 uuid

Returns the Pi object's 32-byte hexidecimal unique identifier.

=head2 clean_shared

Overwrites the shared memory storage area.

=head2 signal_handlers

Returns a hash reference of the currently set signal handlers.

=head2 dump_signal_handlers

Prints, using L<Data::Dumper>, the structure holding the class' signal handling
data.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016-2019 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
