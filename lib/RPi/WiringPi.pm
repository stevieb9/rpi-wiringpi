package RPi::WiringPi;

use 5.018002;
use strict;
use warnings;

use parent 'RPi::WiringPi::Core';

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ('all' => [qw()]);

our @EXPORT_OK = (@{ $EXPORT_TAGS{'all'} });

our $VERSION = '0.01';

#require XSLoader;
#XSLoader::load('RPi::WiringPi', $VERSION);

sub new {
    return bless {}, shift;
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
