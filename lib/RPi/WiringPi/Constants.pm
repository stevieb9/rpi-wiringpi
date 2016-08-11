package RPi::WiringPi::Constants;

use strict;
use warnings;

our $VERSION = '0.03';

require Exporter;
use base qw( Exporter );
our @EXPORT_OK = ();
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use constant {
    INPUT => 0,
    OUTPUT => 1,
    PWM_OUT => 2,
    GPIO_CLK => 3,
};

{ # pinmodes
    my @const = qw(
        INPUT
        OUTPUT
        PWM_OUT
        GPIO_CLK
    );

    push @EXPORT_OK, @const;
    $EXPORT_TAGS{pinmode} = \@const;
}

sub _vim{1;};
1;
__END__

=head1 NAME

RPi::WiringPi::Constant - Constant variables for RPi::WiringPi

=head1 SYNOPSIS

    use RPi::WiringPi::Constant (:all);

    # or...

    use RPi::WiringPi::Constant (:pinmode);

    # etc

=head1 DESCRIPTION

This module optionally exports selections or all constant variables used within
the C<RPi::WiringPi> suite.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
