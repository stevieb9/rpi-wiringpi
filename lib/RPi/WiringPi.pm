package RPi::WiringPi;

use strict;
use warnings;

use parent 'RPi::WiringPi::Util';

use RPi::ADC::ADS;
use RPi::SPI;
use RPi::WiringPi::Constant qw(:all);
use RPi::WiringPi::BMP180;
use RPi::WiringPi::Interrupt;
use RPi::WiringPi::LCD;
use RPi::WiringPi::Pin;

our $VERSION = '2.36.3';

my $fatal_exit = 1;

BEGIN {
    sub error {
        my $err = shift;
        print "\ndie() caught... ".  __PACKAGE__ ." is cleaning up\n",
        RPi::WiringPi::Util::cleanup();
        print "\ncleaned up, exiting...\n";
        print "\noriginal error: $err\n";
        exit if $fatal_exit;
    }

    $SIG{__DIE__} = \&error;
    $SIG{INT} = \&error;
};

# core

sub new {
    my ($self, %args) = @_;
    $self = bless {%args}, $self;

    if (! $ENV{NO_BOARD}){
        if (my $scheme = $ENV{RPI_PIN_MODE}){
            # this checks if another application has already run
            # a setup routine

            $self->pin_scheme($scheme);
        }
        else {
            # we default to gpio mode

            if (! defined $self->{setup}) {
                $self->SUPER::setup_gpio();
                $self->pin_scheme(RPI_MODE_GPIO);
            }
            else {
                if ($self->_setup =~ /^w/) {
                    $self->SUPER::setup();
                    $self->pin_scheme(RPI_MODE_WPI);
                }
                elsif ($self->_setup =~ /^g/) {
                    $self->SUPER::setup_gpio();
                    $self->pin_scheme(RPI_MODE_GPIO);
                }
                elsif ($self->_setup =~ /^p/) {
                    $self->SUPER::setup_phys();
                    $self->pin_scheme(RPI_MODE_PHYS);
                }
                elsif ($self->_setup =~ /^W/){
                    $self->pin_scheme(RPI_MODE_WPI);
                }
                else {
                    $self->pin_scheme(RPI_MODE_UNINIT);
                }
            }
        }
        # set the env var so we can catch multiple
        # setup calls properly

        $ENV{RPI_SCHEME} = $self->pin_scheme;
    }
    $self->_fatal_exit;
    return $self;
}
sub adc {
    my ($self, %args) = @_;
    my $adc = RPi::ADC::ADS->new(%args);
    return $adc;
}
sub pin {
    my ($self, $pin_num) = @_;

    my $pins_in_use = $self->registered_pins;
    my $gpio = $self->pin_to_gpio($pin_num);

    if (defined $ENV{RPI_PINS} && grep {$gpio == $_} split /,/, $pins_in_use){
        die "\npin $pin_num is already in use... can't create second object\n";
    }

    my $pin = RPi::WiringPi::Pin->new($pin_num);
    $self->register_pin($pin);
    return $pin;
}
sub lcd {
    my $self = shift;
    my $lcd = RPi::WiringPi::LCD->new;
    return $lcd;
}
sub bmp {
    my ($self, $base) = @_;
    return RPi::WiringPi::BMP180->new($base);
}
sub interrupt {
    my $self = shift;
    my $interrupt = RPi::WiringPi::Interrupt->new;
    return $interrupt;
}
sub spi {
    my ($self, $chan, $speed) = @_;
    my $spi = RPi::SPI->new($chan, $speed);
    return $spi;
}
sub shift_register {
    my ($self, $base, $num_pins, $data, $clk, $latch) = @_;

    $self->shift_reg_setup($base, $num_pins, $data, $clk, $latch);
}

# private

sub _fatal_exit {
    my $self = shift;
    $fatal_exit = $self->{fatal_exit} if defined $self->{fatal_exit};
}
sub _setup {
    return $_[0]->{setup};
}

sub _vim{1;};
1;
__END__

=head1 NAME

RPi::WiringPi - Perl interface to Raspberry Pi's board, GPIO, LCDs and other
various items

=head1 SYNOPSIS

    use RPi::WiringPi;
    use RPi::WiringPi::Constant qw(:all);

    my $pi = RPi::WiringPi->new;

    #
    # pin
    #

    my $pin = $pi->pin(5);
    $pin->mode(OUTPUT);
    $pin->write(ON);

    my $num = $pin->num;
    my $mode = $pin->mode;
    my $state = $pin->read;

    #
    # analog to digital converter
    #

    my $adc = $pi->adc;
   
    # read channel A0 on the ADC

    my $v = $adc->volts(0);
    my $p = $adc->percent(0);

    #
    # SPI
    #

    my $channel = 0; # SPI channel /dev/spidev0.0

    my $spi = $pi->spi($channel);

    my $buf = [0x01, 0x02];
    my $len = scalar @$buf;

    $spi->rw($buf, $len);

    #
    # shift register
    #
    
    my ($base, $num_pins, $data, $clk, $latch)
      = (100, 8, 5, 6, 13);

    $pi->shift_register(
        $base, $num_pins, $data, $clk, $latch
    );

    # now we can access the new 8 pins of the
    # register commencing at new pin 100-107

    for (100..107){
        my $pin = $pi->pin($_);
        $pin->write(HIGH);
    }

    #
    # BMP180 barometric pressure sensor
    #
    
    my $base = 300; 

    my $bmp = $pi->bmp($base);

    my $farenheit = $bmp->temp;
    my $celcius   = $bmp->temp('c');
    my $pressure  = $bmp->pressure; # kPa

    #
    # LCD
    #

    my $lcd = $pi->lcd;

    $lcd->init(...);

    # first column, first row
    
    $lcd->position(0, 0); 
    $lcd->print("hi there!");

    # first column, second row
    
    $lcd->position(0, 1);
    $lcd->print("pin $num... mode: $mode, state: $state");

    $lcd->clear;
    $lcd->display(OFF);

    $pi->cleanup;

=head1 DESCRIPTION

This is the root module for the C<RPi::WiringPi> system. It interfaces to a
Raspberry Pi board, its accessories and its GPIO pins via the
L<wiringPi|http://wiringpi.com> library through the Perl wrapper
L<WiringPi::API|https://metacpan.org/pod/WiringPi::API>
module.

L<wiringPi|http://wiringpi.com> must be installed prior to installing/using
this module (v2.36+).

By default, we set up using the C<GPIO> numbering scheme for pins. See C<new()>
method for information on how to change this.

This module is essentially a 'manager' for the sub-modules (ie. components).
You can use the component modules directly, but retrieving components through
this module instead has many benefits. We maintain a registry of pins and other
data. We also trap C<$SIG{__DIE__}> and C<$SIG{INT}>, so that in the event of a
crash, we can reset the Pi back to default settings, so components are not left
in an inconsistent state. Component moduls do none of these things.

There are a basic set of constants that can be imported. See
L<RPi::WiringPi::Constant>.

It's handy to have access to a pin mapping conversion chart. There's an
excellent pin scheme map for reference at
L<pinout.xyz|https://pinout.xyz/pinout/wiringpi>. You can also run the C<pinmap>
command that was installed by this module, or C<wiringPi>'s C<gpio readall>
command.

=head1 METHODS

See L<RPi::WiringPi::Util> for utility/helper methods that are imported into
an C<RPi::WiringPi> object.

=head2 new(%args)

Returns a new C<RPi::WiringPi> object. By default, we set the pin numbering
scheme to C<GPIO> (Broadcom (BCM) GPIO scheme).

Parameters:

=over 8
=item   setup => $value
=back

Optional. This option specifies which pin mapping (numbering scheme) to use.

    wpi:    wiringPi's numbering
    phys:   physical pin numbering
    gpio:   GPIO numbering

You can also specify C<none> for testing purposes. This will bypass running
the setup routines.

See L<wiringPi setup reference|http://wiringpi.com/reference/setup> for
the full details on the differences.

There's an excellent pin scheme map for reference at
L<pinout.xyz|https://pinout.xyz/pinout/wiringpi>. You can also run the C<pinmap>
application that was included in this distribution from the command line to get
a printout of pin mappings.

=over 8 
=item   fatal_exit => $bool
=back

Optional: We trap all C<die()> calls and clean up for safety reasons. If a
call to C<die()> is trapped, by default, we clean up, and then C<exit()>. Set
C<fatal_exit> to false (C<0>) to perform the cleanup, and then continue running
your script. This is for unit testing purposes only.

=head2 pin($pin_num)

Returns a L<RPi::WiringPi::Pin> object, mapped to a specified GPIO pin, which
you can then perform operations on.

Parameters:

=over 8
=item    $pin_num
=back

Mandatory: The pin number to attach to.

=head2 lcd()

Returns a L<RPi::WiringPi::LCD> object, which allows you to fully manipulate
LCD displays connected to your Raspberry Pi.

=head2 interrupt($pin, $edge, $callback)

Returns a L<RPi::WiringPi::Interrupt> object, which allows you to act when
certain events occur (eg: a button press). This functionality is better used
through the L<RPi::WiringPi::Pin> object you created with C<pin()>.

=head2 spi($channel, $speed);

Creates a new L<RPi::SPI> object which allows you to communicate on the Serial
Peripheral Interface (SPI) bus with attached devices.

See the linked documentation for full documentation on usage, or the
L<RPi::WiringPi::FAQ-Tutorial> for usage examples.

=head2 shift_register($base, $num_pins, $data, $clk, $latch)

Allows you to access the output pins of up to four 74HC595 shift registers in
series, for a total of eight new output pins per register. Numerous chains of
four registers are permitted, each chain uses three GPIO pins.

Parameters:

=over 8
=item   $base
=back

Mandatory: Integer, represents the number at which you want to start
referencing the new output pins attached to the register(s). For example, if
you use C<100> here, output pin C<0> of the register will be C<100>, output
C<1> will be C<101> etc.

=over 8
=item    $num_pins
=back

Mandatory: Integer, the number of output pins on the registers you want to use.
Each register has eight outputs, so if you have a single register in use, the
maximum number of additional pins would be eight.

=over 8
=item   $data
=back

Mandatory: Integer, the GPIO pin number attached to the C<DS> pin (14) on the
shift register.

=over 8
=item    $clk
=back

Mandatory: Integer, the GPIO pin number attached to the C<SHCP> pin (11) on the
shift register.

=over 8
=item    $latch
=back

Mandatory: Integer, the GPIO pin number attached to the C<STCP> pin (12) on the
shift register.

=head2 adc()

Returns a L<RPi::ADC::ADS> object, which allows you to read the four analog
input channels on an Adafruit ADS1xxx analog to digital converter.

Parameters:

The default (no parameters) is almost always enough, but please do review
the documentation in the link above for further information, and have a
look at the 
L<ADC tutorial section|RPi::WiringPi::FAQ/ANALOG TO DIGITAL CONVERTERS> in
this distribution.

=head2 bmp()

Returns a L<RPi::WiringPi::BMP180> object, which allows you to return the
current temperature in farenheit or celcius, along with the ability to retrieve
the barometric pressure in kPa.

=head1 RUNNING TESTS

Please see L<RUNNING TESTS|RPi::WiringPi::FAQ/RUNNING-TESTS> in the
L<FAQ|RPi::WiringPi::FAQ-Tutorial>.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
