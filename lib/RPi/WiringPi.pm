package RPi::WiringPi;

use strict;
use warnings;

use parent 'RPi::WiringPi::Core';
use parent 'RPi::WiringPi::Util';
use parent 'RPi::WiringPi::Meta';

use GPSD::Parse;
use RPi::ADC::ADS;
use RPi::ADC::MCP3008;
use RPi::BMP180;
use Carp qw(croak confess);
use Data::Dumper;
use RPi::Const qw(:all);
use RPi::DAC::MCP4922;
use RPi::DigiPot::MCP4XXXX;
use RPi::EEPROM::AT24C32;
use RPi::GPIOExpander::MCP23017;
use RPi::HCSR04;
use RPi::I2C;
use RPi::LCD;
use RPi::OLED::SSD1306::128_64;
use RPi::Pin;
use RPi::RTC::DS3231;
use RPi::Serial;
use RPi::SPI;
use RPi::StepperMotor;

our $VERSION = '2.3633_02';

# class variables

my $fatal_exit = 1;
my %sig_handlers;
my $signal_debug = 1;
my $meta_data;

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
                if ($self->_setup =~ /^w/i) {
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
                else {
                    $self->pin_scheme(RPI_MODE_UNINIT);
                }
            }
        }
        # set the env var so we can catch multiple
        # setup calls properly

        $ENV{RPI_PIN_MODE} = $self->pin_scheme;
    }

    $self->_fatal_exit($args{fatal_exit});
    $self->meta_spawn;
    $meta_data = $self->{meta};

    $self->{proc} = $$;

    while (! defined $self->{uuid}){
        my $uuid = $self->checksum;
        next if exists $self->{meta}{objects}{$uuid};
        $self->{uuid} = $uuid;
    }

    $self->{meta}{objects}->{$self->uuid} = {
        proc  => $self->{proc},
        label => $self->{label}
    };
    $self->{meta}{object_count}++;
    $self->_generate_signal_handlers;

    return $self;
}
sub adc {
    my ($self, %args) = @_;

    if (defined $args{model} && $args{model} eq 'MCP3008'){
        my $pin = $self->pin($args{channel}, "MCP3008 ADC CS");
        return RPi::ADC::MCP3008->new($pin->num);
    }
    else {
        # ADSxxxx ADCs don't require any pins
        return RPi::ADC::ADS->new(%args);
    }
}
sub bmp {
    return RPi::BMP180->new($_[1]);
}
sub dac {
    my ($self, %args) = @_;
    $self->pin($args{cs}, 'MCP4922 DAC CS');
    $self->pin($args{shdn}, 'MCP4922 DAC Shutdown') if defined $args{shdn};
    $args{model} = 'MCP4922' if ! defined $args{model};
    return RPi::DAC::MCP4922->new(%args);
}
sub dpot {
    my ($self, $cs, $channel) = @_;
    $self->pin($cs, 'MCP4XXXX Digital Potentiometer CS');
    return RPi::DigiPot::MCP4XXXX->new($cs, $channel);
}
sub eeprom {
    my ($self, %args) = @_;
    return RPi::EEPROM::AT24C32->new(%args);
}
sub expander {
    my ($self, $addr, $expander) = @_;

    if (! defined $expander || $expander eq 'MCP23017'){
        $addr = 0x20 if ! defined $addr;
        return RPi::GPIOExpander::MCP23017->new($addr);
    }
}
sub gps {
    my ($self, %args) = @_;
    return GPSD::Parse->new(%args);
}
sub hcsr04 {
    my ($self, $t, $e) = @_;
    $self->pin($t, "HCSR04 Ultrasonic Distance Sensor Trigger");
    $self->pin($e, "HCSR04 Ultrasonic Distance Sensor Echo");
    return RPi::HCSR04->new($t, $e);
}
sub hygrometer {
    my ($self, $pin) = @_;
    $self->register_pin($pin, 'DHT11 Hygrometer Signal');
    return RPi::DHT11->new($pin);
}
sub i2c {
    my ($self, $addr, $i2c_device) = @_;
    return RPi::I2C->new($addr, $i2c_device);
}
sub lcd {
    my ($self, %args) = @_;

    # pre-register all pins so we can clean them up
    # accordingly upon cleanup

    for (qw(rs strb d0 d1 d2 d3 d4 d5 d6 d7)){
        if (! exists $args{$_} || $args{$_} !~ /^\d+$/){
            die "lcd() requires pin configuration within a hash\n";
        }
        next if $args{$_} == 0;
        $self->pin($args{$_}, "LCD $_");
    }

    my $lcd = RPi::LCD->new;
    $lcd->init(%args);
    return $lcd;
}
sub oled {
    my ($self, $model, $i2c_addr, $display_splash_page) = @_;

    $model //= '128x64';
    $i2c_addr //= 0x3C;

    my %models = (
        '128x64'  => 1,
        '128x32'  => 1,
        '96x16'   => 1,
    );

    if (! exists $models{$model}){
        die "oled() requires one of the following models sent in: " .
              "128x64, 128x32 or 96x16\n";
    }

    if ($model eq '128x64'){
        return RPi::OLED::SSD1306::128_64->new($i2c_addr, $display_splash_page);
    }
}
sub pin {
    my ($self, $pin_num, $comment) = @_;

    my $gpio = $self->pin_to_gpio($pin_num);

    if (grep {$gpio == $_} @{ $self->registered_pins }){
        croak "\npin $pin_num is already in use... can't create second object\n";
    }

    my $pin = RPi::Pin->new($pin_num, $comment);

    $self->register_pin($pin);

    return $pin;
}
sub rtc {
    my ($self, $rtc_addr) = @_;
    return RPi::RTC::DS3231->new($rtc_addr);
}
sub serial {
    my ($self, $device, $baud) = @_;
    return RPi::Serial->new($device, $baud);
}
sub servo {
    my ($self, $pin_num, %config) = @_;

    if ($> != 0){
        die "\n\nat this time, servo() requires PWM functionality, and PWM " .
            "requires your script to be run as the 'root' user (sudo)\n\n";
    }

    my $servo = $self->pin($pin_num, "Servo PWM");

    $config{clock} = exists $config{clock} ? $config{clock} : 192;
    $config{range} = exists $config{range} ? $config{range} : 2000;

    $self->_pwm_in_use(1);

    $servo->mode(PWM_OUT);

    $self->pwm_mode(PWM_MODE_MS);
    $self->pwm_clock($config{clock});
    $self->pwm_range($config{range});

    return $servo;
}
sub shift_register {
    my ($self, $base, $num_pins, $data, $clk, $latch) = @_;

    my @pin_nums;
    my @pin_comments = (
        'Shift Register Data',
        'Shift Register Clock',
        'Shift Register Latch',
    );
    my $pin_count = 0;

    for ($data, $clk, $latch){
        my $pin = $self->pin($_, $pin_comments[$pin_count]);
        push @pin_nums, $pin->num;
        $pin_count++;
    }
    $self->shift_reg_setup($base, $num_pins, @pin_nums);
}
sub spi {
    my ($self, $chan, $speed) = @_;
    my $spi = RPi::SPI->new($chan, $speed);
    return $spi;
}
sub stepper_motor {
    my ($self, %args) = @_;

    if (! exists $args{pins}){
        die "steppermotor() requires an arrayref of pins sent in\n";
    }

    my @pin_comments = (
        'Stepper IN1',
        'Stepper IN2',
        'Stepper IN3',
        'Stepper IN4'
    );
    my $pin_count = 0;

    if (! exists $args{expander}) {
        for (@{$args{pins}}) {
            $self->pin($_, $pin_comments[$pin_count]);
            $pin_count++;
        }
    }

    return RPi::StepperMotor->new(%args);
}
sub DESTROY {
#    my ($self) = @_;
#
#    print Dumper $self;
#    return if $self->{clean};
#
#    if (! $self->{meta}{_tidy}){
#        $self->cleanup;
#    }
#    $self->{meta}{_tidy} = 0;
#
#    if (keys %{ $self->{meta}{objects} } == 0){
#        print "NO OBJECTS\n";
#        IPC::Shareable->clean_up_all;
#        print "DONE REMOVING SHARE\n";
#    }
}

# private

sub _generate_signal_handlers {
    my $self = shift;

    if (! %sig_handlers){
        # set up the signal handler class structure only once
        $SIG{INT} = \&_class_signal_handler('INT');
        $SIG{TERM} = \&_class_signal_handler('TERM');
        $SIG{__DIE__} = sub { _class_signal_handler('__DIE__', @_) };
    }

    $sig_handlers{'__DIE__'}{$self->uuid} = sub {
        my @err = @_;
        print "$_\n" for @err;
        $self->_cleanup_handler('__DIE__', @err)
    };
    $sig_handlers{'INT'}{$self->uuid} = sub {
        $self->_cleanup_handler('INT')
    };
    $sig_handlers{'TERM'}{$self->uuid} = sub {
        $self->_cleanup_handler('TERM')
    };
}
sub _class_signal_handler {
    # populates the class level signal handler structure

    my $signal = shift;

    for (keys %{ $sig_handlers{$signal} }){
        &{ $sig_handlers{$signal}->{$_} }(@_);
    }
}
sub _cleanup_handler {
    # the actual sig handler methods

    print "CLEANUP PROC: $$\n";

    my ($self, $sig, @err) = @_;

    print "$_\n" for @err;
    
    if ($signal_debug){
        print "running '$sig' handler for: " . $self->uuid .
            " with fatal_exit = " . $self->_fatal_exit . "\n";
    }

    $self->cleanup;
#    IPC::Shareable->clean_up_all;
    print "REMOVE PROC: $$\n";
    print $self->{$$};
    if ($self->_fatal_exit){
        delete $sig_handlers{$sig}{$self->uuid};
    
        if (scalar(keys %{ $sig_handlers{$sig} }) == 0){
            exit;
        }
    }
}
sub _signal_handlers {
    return \%sig_handlers;
}
sub _fatal_exit {
    my ($self, $fatal) = @_;
    if (defined $fatal){
        $fatal_exit = $fatal;
    }
    $self->{fatal_exit} = $fatal_exit;
    return $self->{fatal_exit};
}
sub _pwm_in_use {
    my $self = shift;
    if ($_[0]){
        $self->{meta}{pwm}{in_use} = 1;
    }
}
sub _setup {
    return $_[0]->{setup};
}

END {
#    my $done_cleanup = eval {
#        if (! %{ $meta_data }){
#            exit;
#        };
#    };

#    if (keys %{ $meta_data->{objects} } == 0){
#        IPC::Shareable->clean_up_all;
#    }

}

sub _vim{};
1;
__END__

=head1 NAME

RPi::WiringPi - Perl interface to Raspberry Pi's board, GPIO, LCDs and other
various items

=head1 SYNOPSIS

Please see the L<FAQ|RPi::WiringPi::FAQ> for full usage details.

    use RPi::WiringPi;
    use RPi::Const qw(:all);

    my $pi = RPi::WiringPi->new;

    # For the below handful of system methods, see RPi::SysInfo

    my $mem_percent = $pi->mem_percent;
    my $cpu_percent = $pi->cpu_percent;
    my $cpu_temp    = $pi->core_temp;
    my $gpio_info   = $pi->gpio_info;
    my $raspi_conf  = $pi->raspi_config;
    my $net_info    = $pi->network_info;
    my $file_system = $pi->file_system;
    my $hw_details  = $pi->pi_details;

    # pin

    my $pin = $pi->pin(5);
    $pin->mode(OUTPUT);
    $pin->write(ON);

    my $num = $pin->num;
    my $mode = $pin->mode;
    my $state = $pin->read;

    # cleanup all pins and reset them to default before exiting your program

    $pi->cleanup;

=head1 DESCRIPTION

This is the root module for the C<RPi::WiringPi> system. It interfaces to a
Raspberry Pi board, its accessories and its GPIO pins via the
L<wiringPi|http://wiringpi.com> library through the Perl wrapper
L<WiringPi::API|https://=head2 uuid

Returns the Pi object's 32-byte hexidecimal unique identifier.

=head2 clean_shared

Overwrites the shared memory storage area.

=head1 ADDITIONAL PI SYSTEM METHODS

We also include in the Pi object several hardware-type methods brought in from
L<RPi::SysInfo>. They are loaded through L<RPi::WiringPi::Core> via
inheritance. See the L<RPi::SysInfo> documentation for full method details.

    my $cpu_percent = $pi->cpu_percent;
    my $mem_percent = $pi->mem_percent;
    my $cpu_temp    = $pi->core_temp;
    my $gpio_info   = $pi->gpio_info;
    my $raspi_conf  = $pi->raspi_config;
    my $net_info    = $pi->network_info;
    my $file_system = $pi->file_system;
    my $hw_details  = $pi->pi_details;

=head2 cpu_percent

Returns the current CPU usage.

=head2 mem_percent

Returns the current memory usage.

=head2 core_temp

Returns the current temperature of the CPU core.

=head2 gpio_info

Returns the current status and configuration of one, many or all of the GPIO
pins.

=head2 raspi_config

Returns a list of all configured parameters in the C</boot/config.txt> file.

=head2 network_info

Returns the network configuration of the Pi.

=head2 file_system

Returns current disk and mount information.

=head2 pi_details

Returns various information on both the hardware and OS aspects of the Pi.

=head1 RUNNING TESTS

Please see L<RUNNING TESTS|RPi::WiringPi::FAQ/RUNNING TESTS> in the
L<FAQ|RPi::WiringPi::FAQ>.

=head1 TROUBLESHOOTING

Please read through the L<SETUP|RPi::WiringPi::FAQ/SETUP> section in the
L<FAQ|RPi::WiringPi::FAQ>.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016-2019 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
