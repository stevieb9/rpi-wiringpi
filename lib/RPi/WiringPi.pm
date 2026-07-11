package RPi::WiringPi;

use strict;
use warnings;

# Method resolution order: this class tree uses Perl's default depth-first
# MRO. The effective search order from this class is:
#
#   RPi::WiringPi -> Core -> WiringPi::API -> Exporter -> Meta -> Util
#                 -> RPi::SysInfo
#
# WiringPi::API (reached through Core, which lists it first) is searched
# BEFORE Meta and Util, even though both are direct parents below. Do NOT
# define a method in Meta/Util/RPi::SysInfo whose name spans two branches
# (e.g. a Util sub named after a WiringPi::API sub) without revisiting the
# MRO -- depth-first search would silently dispatch to the WiringPi::API
# version. A symbol table audit (2026-06-11) found no meaningful
# cross-branch collisions: only identical RPi::Const/Carp imports, XS
# bootstrap glue, and new() (WiringPi::API vs RPi::SysInfo), which is
# shadowed by this class's own new() for all callers.
#
# Switching to `use mro 'c3'` is NOT a drop-in change: the current parent
# ordering is C3-inconsistent (Util lists Exporter before WiringPi::API,
# which itself inherits Exporter; Core lists WiringPi::API before Util,
# its own subclass) and Perl dies with "Inconsistent hierarchy". @ISA in
# Util.pm, Core.pm and this file would need reordering first.
use parent 'RPi::WiringPi::Core';
use parent 'RPi::WiringPi::Util';
use parent 'RPi::WiringPi::Meta';

use Carp qw(croak confess);
use Data::Dumper;
use RPi::Const qw(:all);
use Scalar::Util qw(weaken);

our $VERSION = '3.1803';

# class variables

my %sig_handlers;
my %prev_sig;
my $signal_debug = 0;

# Weak registry of live, registered objects (keyed by uuid) so the END block
# below can clean up anything the user never explicitly cleanup()'d while the
# IPC::Shareable segment is still alive — before global destruction tears it
# down. The strong refs in %sig_handlers keep these objects alive until exit.

my %objects;

# Core

sub new {
    my ($self, %args) = @_;
    $self = bless {%args}, $self;

    if (! $ENV{NO_BOARD}){
        if (defined $ENV{RPI_PIN_MODE}){
            # This checks if another application has already run a setup
            # routine. Must be a defined check: RPI_MODE_WPI is 0, which is
            # falsy, and a truthy test would silently re-init WPI mode to GPIO
            $self->pin_scheme($ENV{RPI_PIN_MODE});
        }
        else {
            # We default to gpio mode

            if (! defined $self->{setup}) {
                $self->SUPER::setup_gpio();
                $self->pin_scheme(RPI_MODE_GPIO);
            }
            else {
                if ($self->_setup =~ /^w/i) {
                    $self->SUPER::setup();
                    $self->pin_scheme(RPI_MODE_WPI);
                }
                elsif ($self->_setup =~ /^g/i) {
                    $self->SUPER::setup_gpio();
                    $self->pin_scheme(RPI_MODE_GPIO);
                }
                elsif ($self->_setup =~ /^n/i) {
                    # 'none': deliberately skip the C library setup call; the
                    # pin scheme stays uninitialized (the test suite uses this)
                    $self->pin_scheme(RPI_MODE_UNINIT);
                }
                else {
                    croak "unrecognized 'setup' param value '" . $self->_setup .
                          "'; valid values are 'wiringpi', 'gpio' or 'none'\n";
                }
            }
        }

        # Set the env var so we can catch multiple setup calls properly
        $ENV{RPI_PIN_MODE} = $self->pin_scheme;
    }

    $self->{proc} = $$;

    $self->_fatal_exit($args{fatal_exit});

    $self->{shm_key} //= 'rpiw';
    $self->meta($self->{shm_key});

    if ($self->_rpi_register) {
        # Register all objects for collision detection and safety shutdown

        $self->_meta_txn(sub {
            my $meta = $self->meta_fetch;

            while (! defined $self->{uuid}) {
                my $uuid = $self->checksum;
                next if exists $meta->{objects}{$uuid};
                $self->{uuid} = $uuid;
            }

            $meta->{objects}{$self->uuid} = {
                proc  => $self->{proc},
                label => $self->{label}
            };

            $meta->{object_count}++;

            $self->meta_store($meta);
        });

        $self->_generate_signal_handlers;

        # Track for END-time cleanup (weak, so we never extend the object's
        # life ourselves — %sig_handlers already holds it until exit).

        $objects{$self->uuid} = $self;
        weaken $objects{$self->uuid};
    }

    return $self;
}
sub accelerometer {
    my ($self, %args) = @_;
    require RPi::Accelerometer::ADXL335;
    RPi::Accelerometer::ADXL335->import;
    return RPi::Accelerometer::ADXL335->new(%args);
}
sub adc {
    my ($self, %args) = @_;

    if (defined $args{model} && $args{model} eq 'MCP3008'){
        require RPi::ADC::MCP3008;
        RPi::ADC::MCP3008->import;

        my $pin = $self->pin($args{channel}, "MCP3008 ADC CS");

        return RPi::ADC::MCP3008->new($pin->num);
    }
    else {
        # ADSxxxx ADCs don't require any pins
        require RPi::ADC::ADS;
        RPi::ADC::ADS->import;
        return RPi::ADC::ADS->new(%args);
    }
}
sub bmp {
    require RPi::BMP180;
    RPi::BMP180->import;
    return RPi::BMP180->new($_[1]);
}
sub dac {
    my ($self, %args) = @_;

    $self->pin($args{cs}, 'MCP4922 DAC CS');
    $self->pin($args{shdn}, 'MCP4922 DAC Shutdown') if defined $args{shdn};

    $args{model} = 'MCP4922' if ! defined $args{model};

    require RPi::DAC::MCP4922;
    RPi::DAC::MCP4922->import;

    return RPi::DAC::MCP4922->new(%args);
}
sub dpot {
    my ($self, $cs, $channel) = @_;
    $self->pin($cs, 'MCP4XXXX Digital Potentiometer CS');
    require RPi::DigiPot::MCP4XXXX;
    RPi::DigiPot::MCP4XXXX->import;
    return RPi::DigiPot::MCP4XXXX->new($cs, $channel);
}
sub eeprom {
    my ($self, %args) = @_;
    require RPi::EEPROM::AT24C32;
    RPi::EEPROM::AT24C32->import;
    return RPi::EEPROM::AT24C32->new(%args);
}
sub expander {
    my ($self, $addr, $expander) = @_;

    if (! defined $expander || $expander eq 'MCP23017'){
        $addr = 0x20 if ! defined $addr;
        require RPi::GPIOExpander::MCP23017;
        RPi::GPIOExpander::MCP23017->import;
        return RPi::GPIOExpander::MCP23017->new($addr);
    }

    croak "expander() type '$expander' is unrecognized; only 'MCP23017' is " .
          "currently supported\n";
}
sub gps {
    my ($self, %args) = @_;
    require GPSD::Parse;
    GPSD::Parse->import;
    return GPSD::Parse->new(%args);
}
sub gyro {
    my ($self, %args) = @_;
    require RPi::Gyro::MPU6050;
    RPi::Gyro::MPU6050->import;
    return RPi::Gyro::MPU6050->new(%args);
}
sub hcsr04 {
    my ($self, $t, $e) = @_;
    $self->pin($t, "HCSR04 Ultrasonic Distance Sensor Trigger");
    $self->pin($e, "HCSR04 Ultrasonic Distance Sensor Echo");
    require RPi::HCSR04;
    RPi::HCSR04->import;
    return RPi::HCSR04->new($t, $e);
}
sub hygrometer {
    my ($self, $pin) = @_;
    $self->pin($pin, "DHT11 Hygrometer Signal");
    require RPi::DHT11;
    RPi::DHT11->import;
    return RPi::DHT11->new($pin);
}
sub i2c {
    my ($self, $addr, $i2c_device) = @_;
    require RPi::I2C;
    RPi::I2C->import;
    return RPi::I2C->new($addr, $i2c_device);
}
sub lcd {
    my ($self, %args) = @_;

    # I2C-backpack LCD: an HD44780 behind a PCF8574 I2C I/O expander. Passing an
    # 'i2c' address switches to that mode; we register the expander's 8 pins as
    # virtual GPIOs and drive the panel through the very same lcd_init/lcd_*
    # path as a parallel LCD - the virtual pins route digitalWrite() to the
    # expander over I2C.

    return $self->_lcd_i2c(%args) if exists $args{i2c};

    # Parallel (direct-GPIO) LCD: pre-register all pins so we can clean them up
    # accordingly upon cleanup.

    for (qw(rs strb d0 d1 d2 d3 d4 d5 d6 d7)){
        if (! exists $args{$_} || $args{$_} !~ /^\d+$/){
            die "lcd() requires pin configuration within a hash\n";
        }
        next if $args{$_} == 0;
        $self->pin($args{$_}, "LCD $_");
    }

    require RPi::LCD;
    RPi::LCD->import;
    my $lcd = RPi::LCD->new;
    $lcd->init(%args);
    return $lcd;
}
sub _lcd_i2c {
    my ($self, %args) = @_;

    # Standard PCF8574 LCD-backpack wiring: P0=RS, P1=RW, P2=E, P3=backlight,
    # P4-P7=D4-D7. We register the 8 pins at $pin_base, then map them onto a
    # 4-bit lcd_init() - in which the four data lines occupy d0-d3 (d4-d7 = 0).

    my $addr = $args{i2c};
    if (! defined $addr || $addr !~ /^\d+$/ || $addr < 0x03 || $addr > 0x77){
        die "lcd() 'i2c' must be an I2C address (integer 0x03-0x77)\n";
    }

    for my $gpio_param (qw(rs strb d0 d1 d2 d3 d4 d5 d6 d7)){
        if (exists $args{$gpio_param}){
            die "lcd() i2c mode takes no GPIO pin params (got '$gpio_param'); " .
                "the PCF8574 backpack supplies them\n";
        }
    }

    for my $req (qw(rows cols)){
        if (! exists $args{$req} || $args{$req} !~ /^\d+$/ || $args{$req} < 1){
            die "lcd() i2c mode requires '$req' as a positive integer\n";
        }
    }

    my $base = exists $args{pin_base} ? $args{pin_base} : 64;
    if ($base !~ /^\d+$/ || $base < 64){
        die "lcd() i2c 'pin_base' must be an integer >= 64 (wiringPi pin " .
            "extensions live above the native GPIO range)\n";
    }

    # Register the expander's pins as virtual GPIOs, then hold RW low
    # (write-only) and the backlight on; the PCF8574 latch keeps both across
    # subsequent LCD writes.

    WiringPi::API::pcf8574Setup($base, $addr);
    WiringPi::API::digitalWrite($base + 1, 0);   # P1 RW -> write-only

    require RPi::LCD;
    RPi::LCD->import;

    my $lcd = RPi::LCD->new;
    $lcd->init(
        rows => $args{rows},
        cols => $args{cols},
        bits => 4,
        rs   => $base + 0,   # P0
        strb => $base + 2,   # P2 (E)
        d0   => $base + 4,   # P4 -> HD44780 D4
        d1   => $base + 5,   # P5 -> D5
        d2   => $base + 6,   # P6 -> D6
        d3   => $base + 7,   # P7 -> D7
        d4   => 0,
        d5   => 0,
        d6   => 0,
        d7   => 0,
    );

    # Record the backlight pin (PCF8574 P3) on the handle so $lcd->backlight()
    # can toggle it later, and switch it on now.
    $lcd->_backlight_pin($base + 3);
    $lcd->backlight(1);

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
        require RPi::OLED::SSD1306::128_64;
        RPi::OLED::SSD1306::128_64->import;
        return RPi::OLED::SSD1306::128_64->new($i2c_addr, $display_splash_page);
    }

    # The remaining whitelisted sizes don't have a driver class yet; dying
    # beats silently handing the caller undef

    die "oled() model '$model' is not yet implemented; only 128x64 is " .
        "currently supported\n";
}
sub pin {
    my ($self, $pin_num, $comment) = @_;

    require RPi::Pin;
    RPi::Pin->import;

    my $gpio = $self->pin_to_gpio($pin_num);

    if ($self->_rpi_register && $self->_rpi_register_pins) {
        # Both object and pin registration is enabled

        if (grep {$gpio == $_} @{$self->registered_pins}) {
            croak "\npin $pin_num is already in use... can't create second object\n";
        }
    }

    my $pin = RPi::Pin->new($pin_num, $comment);

    if ($self->_rpi_register && $self->_rpi_register_pins) {
        # Register the pin
        $self->register_pin($pin);
    }

    return $pin;
}
sub radar {
    my ($self, %args) = @_;

    # The RCWL-0516 reports motion by driving its OUT terminal high; register
    # the GPIO pin we read it on so the metadata tracks it. The driver sets the
    # pin to INPUT itself
    $self->pin($args{pin}, 'RCWL0516 Radar OUT') if defined $args{pin};

    require RPi::Radar::RCWL0516;
    RPi::Radar::RCWL0516->import;

    return RPi::Radar::RCWL0516->new(%args);
}
sub rtc {
    my ($self, $rtc_addr) = @_;
    require RPi::RTC::DS3231;
    RPi::RTC::DS3231->import;
    return RPi::RTC::DS3231->new($rtc_addr);
}
sub serial {
    my ($self, $device, $baud) = @_;
    require RPi::Serial;
    RPi::Serial->import;
    return RPi::Serial->new($device, $baud);
}
sub servo {
    my ($self, $pin_num, %config) = @_;

    if ($> != 0) {
        die "\n\nAt this time, servo() requires PWM functionality, and PWM " .
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
    require RPi::SPI;
    RPi::SPI->import;
    my $spi = RPi::SPI->new($chan, $speed);
    return $spi;
}
sub stepper_motor {
    my ($self, %args) = @_;

    # Which driver: the original 28BYJ-48/ULN2003 (the default) or the
    # A4988 microstepping driver. Named for the driver chip, the same way
    # adc() and dac() pick their part
    my $model = delete $args{model} // 'ULN2003';

    if (uc $model eq 'A4988') {
        require RPi::StepperMotor::A4988;
        RPi::StepperMotor::A4988->import;

        # The A4988 has named, roled control lines rather than a flat
        # four-pin array. Register the ones we drive directly on the Pi so
        # the metadata tracks them; an expander owns its own pins
        if (! exists $args{expander}) {
            my %pin_comment = (
                step   => 'A4988 STEP',
                dir    => 'A4988 DIR',
                ms1    => 'A4988 MS1',
                ms2    => 'A4988 MS2',
                ms3    => 'A4988 MS3',
                enable => 'A4988 ENABLE',
                sleep  => 'A4988 SLEEP',
                reset  => 'A4988 RESET',
            );

            for my $role (qw(step dir ms1 ms2 ms3 enable sleep reset)) {
                next if ! exists $args{$role};
                $self->pin($args{$role}, $pin_comment{$role});
            }
        }

        return RPi::StepperMotor::A4988->new(%args);
    }

    require RPi::StepperMotor;
    RPi::StepperMotor->import;

    if (! exists $args{pins}) {
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
sub tft {
    my ($self, %args) = @_;

    # Named for the controller chip, the same way adc() and dac() pick
    # their part
    $args{model} = 'ST7735S' if ! defined $args{model};

    if (uc $args{model} ne 'ST7735S') {
        die "tft() model '$args{model}' is not recognized; only 'ST7735S' " .
            "is currently supported\n";
    }

    # Register the control lines we drive directly on the Pi. D/C is
    # mandatory (the driver croaks without it); RES and BLK are optional.
    # A hardware chip select (channel 0/1) is framed by the SPI bus
    # globally, but a GPIO chip select (any channel above 1) is a pin we
    # drive, so track it too
    $self->pin($args{dc},  'ST7735S TFT D/C')       if defined $args{dc};
    $self->pin($args{rst}, 'ST7735S TFT Reset')     if defined $args{rst};
    $self->pin($args{bl},  'ST7735S TFT Backlight') if defined $args{bl};

    if (defined $args{channel} && ref $args{channel} ne 'HASH'
        && $args{channel} =~ /^\d+$/ && $args{channel} > 1) {
        $self->pin($args{channel}, 'ST7735S TFT CS');
    }

    require RPi::TFT::ST7735S;
    RPi::TFT::ST7735S->import;

    return RPi::TFT::ST7735S->new(%args);
}

# Interrupts

sub auto_dispatch_interrupts {
    my ($self, $enable, $signal) = @_;
    return WiringPi::API::auto_dispatch_interrupts($enable, $signal);
}
sub background_interrupts {
    my ($self, @specs) = @_;
    return WiringPi::API::background_interrupts(@specs);
}
sub dispatch_interrupts {
    my ($self) = @_;
    return WiringPi::API::dispatch_interrupts();
}
sub interrupt_buffer {
    my ($self, $bytes) = @_;
    return WiringPi::API::interrupt_buffer($bytes);
}
sub interrupt_dropped {
    my ($self) = @_;
    return WiringPi::API::interrupt_dropped();
}
sub last_interrupt {
    my ($self) = @_;
    return WiringPi::API::last_interrupt();
}
sub run_interrupt_loop {
    my ($self, $timeout_ms, $max) = @_;
    return WiringPi::API::run_interrupt_loop($timeout_ms, $max);
}
sub stop_interrupt_loop {
    my ($self) = @_;
    return WiringPi::API::stop_interrupt_loop();
}
sub stop_interrupts {
    my ($self) = @_;
    return WiringPi::API::stop_interrupts();
}
sub wait_interrupts {
    my ($self, $timeout_ms) = @_;
    return WiringPi::API::wait_interrupts($timeout_ms);
}

# Threads

sub worker {
    my ($self, $body, $opts) = @_;

    # Track the returned handle on the object so cleanup()/DESTROY can reap it

    my $handle = WiringPi::API::worker($body, $opts);
    push @{ $self->{workers} }, $handle;
    return $handle;
}

# Private

sub _class_signal_handler {
    # The process-global INT/TERM handler. Cleans up every live object, chains
    # to any handler the caller had installed before us, then honours fatal_exit

    my ($signal, @args) = @_;

    # During global destruction the object graph is torn down in an arbitrary
    # order; dispatching per-object handlers here would call methods on
    # already-freed objects. Bail out — END-time cleanup has already run.

    return if ${^GLOBAL_PHASE} eq 'DESTRUCT';

    # Reset every live object's hardware first (the safety guarantee).

    for (keys %{ $sig_handlers{$signal} }){
        &{ $sig_handlers{$signal}->{$_} }(@args);
    }

    # Chain to a handler the caller installed before we took over, so we don't
    # silently swallow their signal handling.

    if (ref $prev_sig{$signal} eq 'CODE'){
        $prev_sig{$signal}->(@args);
    }

    # fatal_exit (default true): once cleanup is done, terminate with the
    # signal's default disposition so the exit status is correct (and END still
    # runs). The setting is per-object: if ANY live object was created with
    # fatal_exit => 0, the process is allowed to carry on

    my $fatal = 1;

    for my $uuid (keys %objects) {
        my $obj = $objects{$uuid} or next;
        $fatal = 0 if ! $obj->{fatal_exit};
    }

    if ($fatal) {
        $SIG{$signal} = 'DEFAULT';
        kill $signal, $$;
    }
}
sub _cleanup_handler {
    # Per-object signal cleanup. The terminate/continue decision lives in
    # _class_signal_handler (after all objects are cleaned), not here.

    my ($self, $sig) = @_;

    if ($signal_debug) {
        print "running '$sig' handler for: " . $self->uuid .
              " with fatal_exit = " . $self->_fatal_exit . "\n";
    }

    delete $sig_handlers{$sig}{$self->uuid};
    $self->cleanup;
}
sub _fatal_exit {
    my ($self, $fatal) = @_;

    # Strictly per-object; _class_signal_handler honours a fatal_exit => 0
    # from any live object instead of a process-global last-writer-wins

    $self->{fatal_exit} = $fatal if defined $fatal;
    $self->{fatal_exit} = 1 if ! defined $self->{fatal_exit};

    return $self->{fatal_exit};
}
sub _generate_signal_handlers {
    my $self = shift;

    if (! %sig_handlers){
        # Install our INT/TERM handlers once. We deliberately do NOT trap
        # $SIG{__DIE__}: resetting the hardware on a crash or normal exit is
        # already handled by the END block and DESTROY, so trapping every die
        # would only risk tearing things down on a caught, handled exception.
        # Preserve any handler the caller already set so we can chain to it.

        for my $sig (qw(INT TERM)){
            # Preserve whatever disposition was in place (a CODE ref, a sub
            # name, 'IGNORE'/'DEFAULT', or undef) so it can be restored once
            # the last object is cleaned up. Only CODE refs are chained
            # mid-signal in _class_signal_handler

            $prev_sig{$sig} = $SIG{$sig};
            $SIG{$sig} = sub { _class_signal_handler($sig, @_) };
        }
    }

    $sig_handlers{'INT'}{$self->uuid} = sub {
        $self->_cleanup_handler('INT')
    };

    $sig_handlers{'TERM'}{$self->uuid} = sub {
        $self->_cleanup_handler('TERM')
    };
}
sub _release_signal_handlers {
    # Drops this object's per-signal cleanup entries (releasing the strong
    # closure that keeps the object alive). When the last object for a signal
    # is gone, restore the handler that was in place before we took over,
    # including non-CODE dispositions ('IGNORE', 'DEFAULT', sub names)

    my ($self) = @_;

    for my $sig (qw(INT TERM)){
        delete $sig_handlers{$sig}{$self->uuid};

        if (! keys %{ $sig_handlers{$sig} }){
            $SIG{$sig} = defined $prev_sig{$sig} ? $prev_sig{$sig} : 'DEFAULT';
            delete $sig_handlers{$sig};
            delete $prev_sig{$sig};
        }
    }
}
sub _setup {
    return $_[0]->{setup};
}
sub _signal_handlers {
    return \%sig_handlers;
}

sub DESTROY {
    my ($self) = @_;

    # At global destruction the IPC::Shareable segment may already be gone, so
    # cleanup() can't run reliably; the END block has already reaped any live
    # objects. Skip here to avoid noisy teardown warnings.

    return if ${^GLOBAL_PHASE} eq 'DESTRUCT';

    $self->cleanup if ! $self->{clean};
}
END {
    # Reap any object that was never explicitly cleaned. Running here (END
    # phase) keeps the shared-memory segment intact, so cleanup() actually
    # resets the pins and unregisters the object, and leaves DESTROY nothing
    # to do at global destruction — avoiding "during global destruction"
    # warnings from operating on a half-torn-down segment.

    for my $uuid (keys %objects) {
        my $obj = $objects{$uuid} or next;
        next if $obj->{clean};
        eval { $obj->cleanup; 1 };
    }
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
    my $pi_model    = $pi->pi_model;

    # Pin
 
    my $pin = $pi->pin(5);
    $pin->mode(OUTPUT);
    $pin->write(ON);
 
    my $num     = $pin->num;
    my $mode    = $pin->mode;
    my $state   = $pin->read;
 
    # Cleanup all pins and reset them to default before exiting your program
 
    $pi->cleanup;
 
=head1 DESCRIPTION
 
This is the root module for the C<RPi::WiringPi> system. It interfaces to a
Raspberry Pi board, its accessories and its GPIO pins via the
L<wiringPi|https://github.com/WiringPi/WiringPi> library through the Perl wrapper
L<WiringPi::API|https://metacpan.org/pod/WiringPi::API>
module, and various other custom device specific  modules.
 
L<wiringPi|https://github.com/WiringPi/WiringPi> must be installed prior to installing/using
this module. The required minimum version is the family-wide constant
L<RPi::Const/WIRINGPI_MIN_VERSION> (currently 3.18), enforced at build time by
L<RPi::Const::BuildCheck> in each distribution's C<Makefile.PL> - so the
minimum is defined in exactly one place.
 
By default we use the C<GPIO> (Broadcom (BCM) GPIO) pin numbering scheme;
wiringPi's own (WPI) scheme is also available via C<< setup => 'wiringpi' >>.
 
This module is essentially a 'manager' for the sub-modules (ie. components).
You can use the component modules directly, but retrieving components through
this module instead has many benefits. We maintain a registry of pins and other
data, and reset the Pi back to default settings when your program ends (on
normal exit, on an uncaught C<die()>, and on C<SIGINT>/C<SIGTERM>), so components
are not left in an inconsistent state. Component modules do none of these things.
 
There are a basic set of constants that can be imported. See L<RPi::Const>.
 
It's handy to have access to a pin mapping conversion chart. There's an
excellent pin scheme map for reference at
L<pinout.xyz|https://pinout.xyz/pinout/wiringpi>. You can also run the C<pinmap>
command that was installed by this module, or C<wiringPi>'s C<gpio readall>
command.
 
=head1 BASE METHODS
 
=head2 new([%args])
 
Returns a new C<RPi::WiringPi> object. By default we use the C<GPIO>
(Broadcom (BCM) GPIO) pin numbering scheme; see the C<setup> parameter below
to select wiringPi's own (WPI) numbering instead.

Parameters:

    setup => $string

Optional, String: Which C<wiringPi> setup routine (and therefore pin numbering
scheme) to initialize the board with. Matching is case-insensitive on the
first letter:

    'gpio'      - GPIO (BCM) numbering; the default if not sent in
    'wiringpi'  - WiringPi's own (WPI) numbering
    'none'      - Skip board setup entirely (the pin scheme remains
                  uninitialized; primarily for testing)

Any other value will croak. Note that if another application in the process
has already run a setup routine (signalled via the C<RPI_PIN_MODE> environment
variable), that existing scheme is honoured and this parameter is ignored.

    shm_key => $string

By default, we use the key C<rpiw> as the shared memory segment key. You can
change this if desired. Useful for separating "groups" of Pi objects from one
another (for example, production scripts can operate at the same time as test
scripts, and both use their own shared memory pool).

    fatal_exit => $bool

Optional: Controls what happens when we trap a C<SIGINT> (Ctrl-C) or C<SIGTERM>.
In both cases we first reset the Pi hardware to a safe state. By default
(C<fatal_exit> true), we then re-raise the signal so the program terminates as it
normally would. Set C<fatal_exit> to false (C<0>) to perform the cleanup and then
B<continue running> your script (eg. for unit-test work, or to allow your own
signal handling to take over).

With multiple Pi objects in a single process, the signal is re-raised only if
every live object has C<fatal_exit> true; any object created with
C<fatal_exit =E<gt> 0> keeps the process running.

Note that this only affects trapped signals. Hardware cleanup on a normal exit or
on an uncaught C<die()> always happens automatically (via the object's C<END>/
C<DESTROY> handling); we do B<not> trap C<$SIG{__DIE__}>, so a C<die()> you catch
yourself with C<eval> will not disturb your pins. Any C<$SIG{INT}>/C<$SIG{TERM}>
handler you installed before creating the object is chained to, not replaced.

    rpi_register => $bool

Optional: Set this value to false (C<0>) to bypass the Pi object registration in
the meta data. This will also prevent pins from being registered as well. If set
to false, no object or pin cleanup will take place at the end of a program run.

    rpi_register_pins => $bool

Optional: Similar to C<rpi_register>, but only bypasses the pin registration.
Object registration will still occur, and the object will be cleaned up after
but the pins will not. Should only be used for testing.

=head2 accelerometer(%args)

Returns an L<RPi::Accelerometer::ADXL335> object for an ADXL335 three-axis
analog accelerometer, reporting acceleration in g and tilt angle in degrees.

The Pi has no analog inputs, so the sensor's three outputs go through an ADC.
You build the ADC yourself (see L</adc>) and hand it in, along with the ADC
channel each axis is wired to. All parameters are passed straight through to
the driver's constructor:

    adc => $object

Mandatory, Object: An ADC object providing a C<volts()> or C<percent()> method,
such as the one returned by L</adc>.

    x => $int
    y => $int
    z => $int

Mandatory, Integer: The ADC input channels wired to the sensor's C<XOUT>,
C<YOUT> and C<ZOUT> pins.

    vs => $num

Optional, Number: The sensor's supply voltage, which sets the ratiometric
sensitivity and the zero-g point. Defaults to C<3.3>.

    vref => $num

Optional, Number: The ADC's full-scale reference voltage, used to scale
percent-only ADCs. Defaults to C<vs>.

    sensitivity => $num
    zero_g      => $href

Optional: Override the volts-per-g sensitivity, or the per-axis zero-g voltage
(C<< { x =E<gt> ..., y =E<gt> ..., z =E<gt> ... } >>, as produced by the
driver's C<calibrate>).

Example:

    my $adc = $pi->adc(model => 'ADS1115');

    my $accel = $pi->accelerometer(
        adc => $adc,
        x   => 0,
        y   => 1,
        z   => 2,
    );

    my ($gx, $gy, $gz) = $accel->g;      # Acceleration, in g
    my ($pitch, $roll) = $accel->tilt;   # Tilt, in degrees

See the linked documentation for the full method set, or the
L<RPi::WiringPi::FAQ> for usage examples.

=head2 adc
 
There are two different ADCs that you can select from. The default is the
ADS1x15 series:
 
=head3 ADS1015
 
Returns a L<RPi::ADC::ADS> object, which allows you to read the four analog
input channels on an Adafruit ADS1xxx analog to digital converter.
 
Parameters:
 
The default (no parameters) is almost always enough, but please do review
the documentation in the link above for further information, and have a
look at the
L<ADC tutorial section|RPi::WiringPi::FAQ/ANALOG TO DIGITAL CONVERTERS (ADC)> in
this distribution.
 
=head3 MCP3008
 
You can also use an L<RPi::ADC::MCP3008> ADC.
 
Parameters:
 
    model => 'MCP3008'
 
Mandatory, String. The exact quoted string above.
 
    channel => $channel
 
Mandatory, Integer. C<0> or C<1> for the Pi's onboard hardware CS/SS CE0 and CE1
pins, or any GPIO number above C<1> in order to use an arbitrary GPIO pin for
the CS pin, and we'll do the bit-banging of the SPI bus automatically.
 
=head2 bmp($pin_base)

Returns a L<RPi::BMP180> object, which allows you to return the
current temperature in farenheit or celcius, along with the ability to retrieve
the barometric pressure in kPa.

Parameters:

    $pin_base

Mandatory, Integer. The number at which to start the 'pseudo' GPIO pins used to
communicate with the sensor. Use any value above the highest-numbered physical
GPIO pin (eg. C<100> or C<200>). See L<RPi::BMP180/new> for details.

=head2 dac
 
Returns a L<RPi::DAC::MCP4922> object (supports all 49x2 series DACs). These
chips provide analog output signals from the Pi's digital output. Please
see the documentation of that module for further information on both the
configuration and use of the DAC object.
 
Parameters:
 
    model => 'MCP4922'
 
Optional, String. The model of the DAC you're using. Defaults to C<MCP4922>.
 
    channel => 0|1
 
Mandatory, Bool. The SPI channel to use.
 
    cs => $pin
 
Mandatory, Integer. A valid GPIO pin that the DAC's Chip Select is connected to.
 
There are a handful of other parameters that aren't required. For those, please
refer to the L<RPi::DAC::MCP4922> documentation.
 
=head2 dpot($cs, $channel)
 
Returns a L<RPi::DigiPot::MCP4XXXX> object, which allows you to manage a
digital potentiometer (only the MCP4XXXX versions are currently supported).
 
See the linked documentation for full documentation on usage, or the
L<RPi::WiringPi::FAQ> for usage examples.
 
=head2 gps
 
Returns a L<GPSD::Parse> object, allowing you to track your location.
 
The GPS distribution requires C<gpsd> to be installed and running. All
parameters for the GPS can be sent in here and we'll pass them along. Please see
the link above for the full documentation on that module.

=head2 gyro(%args)

Returns an L<RPi::Gyro::MPU6050> object for an MPU-6050 six-axis (accelerometer
+ gyroscope) IMU on the I2C bus. It reads tilt angle from gravity, angular rate
from the gyroscope, and die temperature, with software gyro calibration and a
deadband smoothing filter.

All parameters are passed straight through to the driver's constructor; all are
optional:

    device => $str

Optional, String: The I2C device path. Defaults to C</dev/i2c-1>.

    addr => $int

Optional, Integer: The I2C address, C<0x68> (AD0 low, the default) or C<0x69>
(AD0 high).

    accel_range => $int
    gyro_range  => $int

Optional, Integer: The full-scale accelerometer range (C<2>, C<4>, C<8> or
C<16> g) and gyroscope range (C<250>, C<500>, C<1000> or C<2000> deg/s). Each
defaults to the chip's most sensitive setting.

    gyro_offsets => $href

Optional, Hash Reference: Per-axis gyro zero-rate offsets (C<< { x =E<gt> ...,
y =E<gt> ..., z =E<gt> ... } >>), as produced by the driver's
C<calibrate_gyro>.

See the linked documentation for the full method set, or the
L<RPi::WiringPi::FAQ> for usage examples.

=head2 hcsr04($trig, $echo)
 
Returns a L<RPi::HCSR04> ultrasonic distance measurement sensor object, allowing
you to retrieve the distance from the sensor in inches, centimetres or raw data.
 
Parameters:
 
    $trig
 
Mandatory, Integer: The trigger pin number, in GPIO numbering scheme.
 
    $echo
 
Mandatory, Integer: The echo pin number, in GPIO numbering scheme.
 
=head2 hygrometer($pin)
 
Returns a L<RPi::DHT11> temperature/humidity sensor object, allows you to fetch
the temperature (celcius or farenheit) as well as the current humidity level.
 
Parameters:
 
    $pin
 
Mandatory, Integer: The GPIO pin the sensor is connected to.
 
=head2 i2c($addr, [$device])
 
Creates a new L<RPi::I2C> device object which allows you to communicate with
the devices on an I2C bus.
 
See the linked documentation for full documentation on usage, or the
L<RPi::WiringPi::FAQ> for usage examples.
 
Aruino note: If using I2C with an Arduino, the Pi may speak faster than the
Arduino can. If this is the case, try lowering the I2C bus speed on the Pi:
 
    dtparam=i2c_arm_baudrate=10000
 
=head2 lcd(...)
 
Returns a L<RPi::LCD> object for an HD44780-compatible character LCD. Two
wiring schemes are supported; see L<RPi::LCD> for the display methods.

B<Parallel (direct GPIO)> - drive the LCD's control and data lines straight
from the Pi's GPIO. Send the pin configuration (BCM numbers) plus geometry:

    my $lcd = $pi->lcd(
        rows => 4, cols => 20, bits => 4,
        rs => 5, strb => 6,
        d0 => 4, d1 => 17, d2 => 27, d3 => 22,
        d4 => 0, d5 => 0, d6 => 0, d7 => 0,
    );

B<I2C backpack (PCF8574)> - for an LCD behind a PCF8574 I2C backpack, pass
C<i2c> with the backpack's address instead of any pin configuration:

    my $lcd = $pi->lcd(i2c => 0x27, rows => 4, cols => 20);

We register the backpack's eight expander pins as virtual GPIOs (standard
wiring: P0=RS, P1=RW, P2=E, P3=backlight, P4-P7=D4-D7) and drive the panel
through the same path as a parallel LCD. The backlight comes on automatically
and can be switched with C<< $lcd->backlight(0|1) >> (see L<RPi::LCD/backlight>).

I2C-mode parameters: C<i2c> (mandatory, the backpack address, an integer
0x03-0x77, e.g. C<0x27> or C<0x3F>); C<rows> and C<cols> (mandatory, the panel
geometry); and C<pin_base> (optional, integer >= 64, default 64 - the wiringPi
virtual-pin base for the expander; change it only if it collides with another
pin extension). I2C mode is 4-bit and takes no GPIO pin params.
 
=head2 oled([$model], [$i2c_addr], [$display_splash_page])

Returns a specific C<RPi::OLED::SSD1306> OLED display object, allowing you to
display text, characters and shapes to the screen.

Currently, only the C<128x64> size model is offered, see the
L<RPi::OLED::SSD1306::128_64> documentation for full usage details.

Parameters:

    $model

Optional, String: The screen size of the OLED you've got. Valid options are
C<128x64>, C<128x32> and C<96x16>. Currently, only the C<128x64> option is
valid, and it's the default if not sent in.

    $i2c_addr

Optional, Integer: The I2C address of your display. Defaults to C<0x3C> if not
sent in.

    $display_splash_page

Optional, Bool: Whether to display the splash page when the display is
initialized. Defaults to true (C<1>); send in C<0> to skip it.

=head2 pin($pin_num, $comment)

Returns a L<RPi::Pin> object, mapped to a specified GPIO pin, which
you can then perform operations on. See that documentation for full usage
details.

Parameters:

    $pin_num

Mandatory, Integer: The pin number to attach to.

    $comment

Optional, String: A label stored alongside the pin's registration (visible in
the metadata store and used by the test suite). Defaults to none.

=head2 radar(%args)

Returns an L<RPi::Radar::RCWL0516> object for an RCWL-0516 microwave motion
sensor, which drives its C<OUT> pin high while it detects movement. See the
L<RPi::Radar::RCWL0516> documentation for full usage details.

Parameters:

    pin

Mandatory, Integer: The BCM GPIO pin wired to the sensor's C<OUT> terminal.

    poll

Optional, Float: The interval, in seconds, between reads when polling with
C<wait_for_motion>/C<wait_for_clear>. Defaults to C<0.1>.

Example:

    my $radar = $pi->radar(pin => 26);

    if ($radar->motion){
        print "movement detected\n";
    }

    $radar->wait_for_motion;        # block until movement
    $radar->wait_for_clear(10);     # then until clear, or 10s elapse

=head2 rtc
 
Creates a new L<RPi::RTC::DS3231> object which provides access to the C<DS3231>
or C<DS1307> real-time clock modules.
 
See the linked documentation for full documentation on usage, or the
L<RPi::WiringPi::FAQ> for some usage examples.
 
Parameters:
 
    $i2c_addr
 
Optional, Integer: The I2C address of the RTC module. Defaults to C<0x68> for
the C<DS3231> unit.

=head2 eeprom

Creates and returns a new L<RPi::EEPROM::AT24C32> object for reading and writing
to.

See the linked documentation for full documentation on usage, parameters or the
L<RPi::WiringPi::FAQ> for some usage examples.

=head2 expander
 
Creates a new L<RPi::GPIOExpander::MCP23017> GPIO expander chip object. This
adds an additional 16 pins across two banks (8 pins per bank).
 
See the linked documentation for full documentation on usage, or the
L<RPi::WiringPi::FAQ> for some usage examples.
 
Parameters:
 
    $i2c_addr
 
Optional, Integer: The I2C address of the device. Defaults to C<0x20>.
 
    $expander
 
Optional, String: The GPIO expander device type. Defaults to C<MCP23017>, and
currently, this is the only option available.
 
=head2 serial($device, $baud)
 
Creates a new L<RPi::Serial> object which allows basic read/write access to a
serial bus.
 
See the linked documentation for full documentation on usage, or the
L<RPi::WiringPi::FAQ> for usage examples.
 
NOTE: On the Pi 3 and Pi 4, Bluetooth occupies the primary UART, leaving the
header pins (14, 15) on the mini-UART (C</dev/ttyS0>). To put the full PL011
UART back on the header you must disable Bluetooth in the
C</boot/firmware/config.txt> file (C</boot/config.txt> on releases before
Bookworm):

    dtoverlay=pi3-disable-bt-overlay

On the Pi 5, Bluetooth has its own dedicated UART, so no C<disable-bt> overlay
is needed; simply enable the header UART (C</dev/ttyAMA0>) with C<enable_uart=1>.

=head2 servo($pin_num)
 
This method configures PWM clock and divisor to operate a typical 50Hz servo,
and returns a special L<RPi::Pin> object. These servos have a C<left> pulse of
C<50>, a C<centre> pulse of C<150> and a C<right> pulse of C<250>. On exit of
the program (or a crash), we automatically clean everything up properly.
 
Parameters:
 
    $pin_num
 
Mandatory, Integer: The pin number (technically, this *must* be C<18> on the
Raspberry Pi 3, as that's the only hardware PWM pin.
 
    %pwm_config
 
Optional, Hash. This parameter should only be used if you know what you're
doing and are having very specific issues.
 
Keys are C<clock> with a value that coincides with the PWM clock speed. It
defaults to C<192>. The other key is C<range>, the value being an integer that
sets the range of the PWM. Defaults to C<2000>.
 
Example:
 
    my $servo = $pi->servo(18);
 
    $servo->pwm(50);  # all the way left
    $servo->pwm(250); # all the way right
 
=head2 shift_register($base, $num_pins, $data, $clk, $latch)
 
Allows you to access the output pins of up to four 74HC595 shift registers in
series, for a total of eight new output pins per register. Numerous chains of
four registers are permitted, each chain uses three GPIO pins.
 
Parameters:
 
    $base
 
Mandatory: Integer, represents the number at which you want to start
referencing the new output pins attached to the register(s). For example, if
you use C<100> here, output pin C<0> of the register will be C<100>, output
C<1> will be C<101> etc.
 
    $num_pins
 
Mandatory: Integer, the number of output pins on the registers you want to use.
Each register has eight outputs, so if you have a single register in use, the
maximum number of additional pins would be eight.
 
    $data
 
Mandatory: Integer, the GPIO pin number attached to the C<DS> pin (14) on the
shift register.
 
    $clk
 
Mandatory: Integer, the GPIO pin number attached to the C<SHCP> pin (11) on the
shift register.
 
    $latch
 
Mandatory: Integer, the GPIO pin number attached to the C<STCP> pin (12) on the
shift register.
 
=head2 spi($channel, $speed)
 
Creates a new L<RPi::SPI> object which allows you to communicate on the Serial
Peripheral Interface (SPI) bus with attached devices.
 
See the linked documentation for full documentation on usage, or the
L<RPi::WiringPi::FAQ> for usage examples.
 
=head2 stepper_motor(%args)

Creates a stepper motor driver object. Two drivers are supported, selected
by the C<model> parameter:

=over 4

=item * C<ULN2003> (the default) - an L<RPi::StepperMotor> object driving a
28BYJ-48 unipolar motor through a ULN2003.

=item * C<A4988> - an L<RPi::StepperMotor::A4988> object driving a bipolar
motor through an Allegro A4988 microstepping driver, with software microstep
selection and power-state control.

=back

Both drivers can run either straight off the Pi's GPIO header, or off an
L<RPi::GPIOExpander::MCP23017> passed as the C<expander> param, in which case
the pin numbers name the expander's C<0-15> lines instead of Pi GPIOs.

See the linked driver documentation for full usage instructions and every
optional parameter. The common parameters are:

    model => 'ULN2003'|'A4988'

Optional, String: Which driver to build. Defaults to C<ULN2003> (the original
28BYJ-48 driver). Case-insensitive.

    expander => $object

Optional, Object: An L<RPi::GPIOExpander::MCP23017> instance (see
L</expander>). When supplied, the motor is driven from the expander's pins
rather than the Pi's own GPIO.

B<C<ULN2003> parameters>

    pins => $aref

Mandatory, Array Reference: The ULN2003 has four data pins, IN1, IN2, IN3 and
IN4. Send in the GPIO pin numbers in the array reference which correlate to the
driver pins in the listed order.

    speed => 'half'|'full'

Optional, String: By default we run in "half speed" mode. Essentially, in this
mode we run through all eight steps. Send in 'full' to double the speed of the
motor. We do this by skipping every other step.

    delay => Float|Int

Optional, Float or Int: By default, between each step, we delay by C<0.01>
seconds. Send in a float or integer for the number of seconds to delay each step
by. The smaller this number, the faster the motor will turn.

B<C<A4988> parameters>

    step => $int
    dir  => $int

Mandatory, Integer: The GPIO (or expander) pins wired to the A4988's C<STEP>
and C<DIR> inputs.

    ms1 => $int
    ms2 => $int
    ms3 => $int

Optional, Integer: The pins wired to the microstep-select inputs, all three
together or none. With them wired, the resolution is selectable from software.

    enable => $int
    sleep  => $int
    reset  => $int

Optional, Integer: The pins wired to the active-low C<ENABLE>, C<SLEEP> and
C<RESET> lines, enabling the matching power-state methods.

    rpm           => $num
    steps_per_rev => $int
    mode          => $str

Optional: The stepping speed in motor RPM (default C<60>), the motor's full
steps per revolution (default C<200>), and the initial microstep resolution
(C<full>, C<half>, C<quarter>, C<eighth> or C<sixteenth>; default C<full>).

Example:

    my $sm = $pi->stepper_motor(
        model => 'A4988',
        step  => 23,
        dir   => 24,
        ms1   => 17,
        ms2   => 27,
        ms3   => 22,
        rpm   => 120,
    );

    $sm->cw(360);   # One full turn clockwise
    $sm->mode('sixteenth');
    $sm->ccw(90);

=head2 tft(%args)

Returns an L<RPi::TFT::ST7735S> object for a 1.44" 128x128 RGB TFT LCD driven
by the ST7735S controller over the 4-wire SPI bus, allowing you to draw
pixels, shapes and text to the screen in 16-bit colour.

See the L<RPi::TFT::ST7735S> documentation for full usage details and every
optional parameter. The common ones:

    model

Optional, String: Which controller to build. Defaults to C<ST7735S>, the only
one currently supported. Case-insensitive.

    dc

Mandatory, Integer: The GPIO pin wired to the display's C<D/C> (data/command)
line.

    channel

Optional, Integer or hashref. Default C<0>. The SPI channel: C<0> or C<1> for
the hardware chip select pins C<CE0>/C<CE1>, any GPIO pin above C<1> to use as
the chip select instead, or a hashref of L<RPi::SPI> bit-bang parameters.

    rst

Optional, Integer: The GPIO pin wired to the display's C<RES> reset line.

    bl

Optional, Integer: The GPIO pin wired to the display's C<BLK> backlight line.

Example:

    my $tft = $pi->tft(
        dc  => 25,
        rst => 24,
        bl  => 23,
    );

    $tft->clear;
    $tft->fill_screen(0x001F);              # blue
    $tft->string(6, 6, "Hello, Pi!", 0xFFFF, 0x0000);

=head2 CORE PI SYSTEM METHODS
 
Core methods are inherited in and documented in L<RPi::WiringPi::Core>. See
that documentation for full details of each one. I've included a basic
description of them here.
 
=head3 gpio_layout
 
Returns the GPIO layout, which in essence is the Pi board revision number.
 
=head3 io_led
 
Turn the disk IO (green) LED on or off.
 
=head3 pwr_led
 
Turn the power (red) LED on or off.
 
=head3 identify
 
Toggles the power led off and disk IO led on which allows external physical
identification of the Pi you're running on.
 
=head3 label
 
Sets an internal label/name to your L<RPi::WiringPi> Pi object.
 
=head3 pin_scheme
 
Returns the current pin mapping scheme in use within the object.
 
=head3 pin_map
 
Returns a hash reference mapping of the physical pin numbers to a pin scheme's
pin numbers.
 
=head3 pin_to_gpio
 
Converts a pin number from any non-GPIO (BCM) scheme to GPIO (BCM) scheme.
 
=head3 wpi_to_gpio
 
Converts a wiringPi pin number to GPIO pin number.
 
=head3 phys_to_gpio
 
Converts a physical pin number to the GPIO pin number.
 
=head3 pwm_range
 
Set/get the PWM range.
 
=head3 pwm_mode
 
Set/get the PWM mode.
 
=head3 pwm_clock
 
Set/get the PWM clock.
 
=head3 registered_pins
 
Returns an array reference of all pin numbers currently registered in the
system. Used primarily for cleanup functionality.
 
=head3 register_pin
 
Registers a pin with the system for error checking, and proper resetting in the
cleanup routines.
 
=head3 unregister_pin
 
Removes an already registered pin.
 
=head3 cleanup

Cleans up the entire system, resetting all pins and devices back to the state
we found them in when we initialized the system. It also releases any armed
interrupts (via C<< WiringPi::API::stop_interrupts() >>) - stopping the wiringPi
ISR threads and closing the event pipe - so you don't have to do that yourself
at teardown.

Only the process that created the object performs the cleanup: in a forked
child the call is a no-op, so a child can't reset pins or mutate the shared
metadata on the parent's behalf when it exits.
 
=head2 ADDITIONAL PI SYSTEM METHODS
 
We also include in the Pi object several hardware-type methods brought in from
L<RPi::SysInfo>. They are loaded through L<RPi::WiringPi::Core> via
inheritance. See the L<RPi::SysInfo> documentation for full method details.
 
    my $mem_percent = $pi->mem_percent;
    my $cpu_percent = $pi->cpu_percent;
    my $cpu_temp    = $pi->core_temp;
    my $gpio_info   = $pi->gpio_info;
    my $raspi_conf  = $pi->raspi_config;
    my $net_info    = $pi->network_info;
    my $file_system = $pi->file_system;
    my $hw_details  = $pi->pi_details;
 
=head3 cpu_percent
 
Returns the current CPU usage.
 
=head3 mem_percent
 
Returns the current memory usage.
 
=head3 core_temp
 
Returns the current temperature of the CPU core.
 
=head3 gpio_info
 
Returns the current status and configuration of one, many or all of the GPIO
pins.
 
=head3 raspi_config
 
Returns the live C<vcgencmd get_config> values plus the non-comment directives
from the active C<config.txt> (C</boot/firmware/config.txt> on Bookworm and
later, falling back to C</boot/config.txt> on older releases).
 
=head3 network_info
 
Returns the network configuration of the Pi, via C<ifconfig> where the
C<net-tools> package is installed, falling back to C<ip addr> where it is not
(as on current Raspberry Pi OS Lite).
 
=head3 file_system
 
Returns current disk and mount information.
 
=head3 pi_details
 
Returns various information on both the hardware and OS aspects of the Pi.

=head3 pi_model

Returns the normalized Raspberry Pi board name (eg. C<Raspberry Pi 5 Model B
Rev 1.1>), read from the devicetree model with a C</proc/cpuinfo> revision-code
decode fallback. Works across the Pi 0 through 5.
 
=head2 INTERRUPT METHODS

Arm an interrupt on a pin with C<< $pin->set_interrupt($edge, $callback) >>
(see L<RPi::Pin>). As of C<WiringPi::API> 3.18 the callback must be a code
reference, and it runs in your own interpreter when you service the interrupt
rather than in the wiringPi ISR thread. The following methods drive that
dispatch. See L<Interrupt usage|RPi::WiringPi::FAQ/Interrupt usage> in the
L<FAQ|RPi::WiringPi::FAQ> for a complete example.

=head3 wait_interrupts($timeout_ms)

Blocks until an edge arrives or C<$timeout_ms> milliseconds elapse, then runs
all pending interrupt callbacks. Returns the number of callbacks dispatched.
Call it in a loop to handle interrupts:

    $pi->wait_interrupts(1000) while 1;

=head3 run_interrupt_loop($timeout_ms, $max)

A blocking dispatch loop, so you don't have to write the
C<< wait_interrupts ... while 1 >> yourself. Repeatedly dispatches and returns
the total number of events handled. It runs until C<< $pi->stop_interrupt_loop >>
is called (from a callback or a signal handler) or, if you pass C<$max>, until
that many events have been dispatched.

    $pi->run_interrupt_loop;        # block, dispatching, until stop_interrupt_loop

Parameters:

    $timeout_ms

Optional, Integer: The per-iteration poll granularity in milliseconds (how long
each underlying C<wait_interrupts> blocks waiting for an edge). Defaults to
C<1000>.

    $max

Optional, Integer: The maximum number of events to dispatch before returning. If
omitted, the loop only ends when C<< $pi->stop_interrupt_loop >> is called.

=head3 stop_interrupt_loop

Breaks out of C<run_interrupt_loop> at the next iteration. Safe to call from a
callback or a signal handler.

=head3 dispatch_interrupts

Runs all pending interrupt callbacks without blocking, and returns the number
dispatched. Use this instead of C<wait_interrupts> when you already block
elsewhere (eg. in your own event loop).

=head3 stop_interrupts

Releases every armed interrupt: stops the wiringPi ISR threads and closes the
event pipe. The object's C<cleanup> calls this for you automatically, so you
only need it to disarm interrupts while the program keeps running.

=head3 last_interrupt

Returns a hash reference describing the most recently dispatched interrupt event
- C<{ pin, pin_bcm, edge, status, ts_us }> - or C<undef> if none has fired yet.
Because the callback only receives C<($edge, $timestamp_us)>, this lets it (or
your main loop) recover the BCM pin and status; useful when one handler is armed
on several pins. Like C<auto_dispatch_interrupts>, it reports a process-wide
value (the last event on any pin), so it lives on the Pi object.

=head3 auto_dispatch_interrupts($bool, $signal)

Enables (C<1>) or disables (C<0>) async auto-dispatch for the whole process.
When enabled, C<< $pin->set_interrupt >> callbacks fire B<automatically> at Perl
safe points (via C<SIGIO>) with no C<wait_interrupts>/C<dispatch_interrupts>
loop, and may touch your program's variables with no locking. The optional
C<$signal> picks the delivery signal (default C<SIGIO>; pass eg C<'USR1'> to
avoid clashing with other C<SIGIO> users). This is a
process-global switch (it affects every armed pin), which is why it lives on the
Pi object rather than on an individual pin. A long, non-yielding C/XS call defers
the callback until it returns - use C<< $pin->background_interrupt >> (see
L<RPi::Pin>) if you need it to fire even then.

=head3 interrupt_buffer($bytes)

Gets (no argument) or sets the capacity of the interrupt queue - the kernel pipe
that absorbs edge bursts. On overflow the newest edges are dropped (never merged
or blocked) and counted, so raise this if a fast source outpaces your dispatch.
May be set before arming and persists across teardown. Process-wide, so it lives
on the Pi object. See C<interrupt_buffer> in L<WiringPi::API> for details.

=head3 interrupt_dropped

Returns the running total of interrupt events dropped because the queue (see
C<interrupt_buffer>) overflowed. A non-zero count means a source is outpacing
your dispatch - raise C<interrupt_buffer> or dispatch more often. Process-wide,
so it lives on the Pi object. See C<interrupt_dropped> in L<WiringPi::API> for
details.

=head3 background_interrupts([$pin, $edge, $callback, $debounce], ...)

Handles B<many> pins in a B<single> background child (rather than one child per
pin via C<< $pin->background_interrupt >>). Pass one array-ref spec per pin; the
returned handle adds C<< $h->arm($pin) >> / C<< $h->disarm($pin) >> (toggling
pins registered at creation) to the usual C<stop>/C<pid>/C<running>. Because it
spans several pins it lives on the Pi object, not on a single pin. See
C<background_interrupts> in L<WiringPi::API> for details.

B<Dependency note:> the per-pin C<< $pin->background_interrupt >> form referenced
above requires L<RPi::Pin> C<3.1802> or greater (the version this distribution
already requires). To drive multiple pins from a single background child rather
than one child per pin, use this C<< $pi->background_interrupts >> method.

=head3 worker(\&body, \%opts)

Runs C<\&body> as a hands-off background task, hiding the spawn mechanism, the
loop, and the lifecycle - the GPIO sibling of C<background_interrupts>. By
default it forks a child (no C<use threads> required) that runs C<body>
repeatedly, and returns a C<WiringPi::API::Worker> handle:

    pin_mode(2, 1);                                   # OUTPUT, once in main

    my $w = $pi->worker(sub {
        digital_write(2, 1); sleep 1;
        digital_write(2, 0); sleep 1;
    });

    # ... main does its own work ...

    $w->stop;                                         # idempotent

The handle carries C<< $w->stop >> (idempotent), C<< $w->pid >>, and
C<< $w->running >>, matching the interrupt handle. You normally need not call
C<stop> at all: C<< $pi->cleanup >> (and therefore C<DESTROY>) automatically
stops every worker started through this method, and a forked child never reaps
the parent's workers.

C<\%opts> mirrors C<WiringPi::API::worker()> exactly:

=over 4

=item * C<< once => 1 >> - run C<body> a single time instead of looping.

=item * C<< interval => $secs >> - pace each pass (periodic sampler/blink)
instead of letting C<body> set its own cadence.

=item * C<< shared => 1 >> - publish C<body>'s return value as a lossy latest
value; read it from the parent with C<< $w->value >>.

=item * C<< results => 1 >> - stream every defined return value back; drain it
with C<< $w->read >> or select on C<< $w->fh >>.

=item * C<< mechanism => 'fork' | 'thread' >> - default C<fork> (works on any
Perl). C<thread> uses an ithread for shared-memory ergonomics and requires
C<threads> to be loaded (croaks otherwise). Under C<thread> mode, serialise
shared GPIO access yourself with C<< WiringPi::API::pi_lock >> /
C<< WiringPi::API::pi_unlock >>; the fork default never locks. See
L<RPi::WiringPi::WORKERS> for the full OO threads/worker story.

=back

All argument validation happens in the low-level layer, so an invalid C<body>,
C<interval>, or C<mechanism> croaks before anything is spawned. See
C<worker> in L<WiringPi::API> and L<RPi::WiringPi::WORKERS> for full details.

=head1 RUNNING TESTS

Please see L<RUNNING TESTS|RPi::WiringPi::FAQ/RUNNING TESTS> in the
L<FAQ|RPi::WiringPi::FAQ>.
 
=head1 TROUBLESHOOTING
 
Please read through the L<SETUP|RPi::WiringPi::FAQ/SETUP> section in the
L<FAQ|RPi::WiringPi::FAQ>.
 
=head1 AUTHOR
 
Steve Bertrand, E<lt>steveb@cpan.orgE<gt>
 
=head1 COPYRIGHT AND LICENSE
 
Copyright (C) 2016-2026 by Steve Bertrand
 
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
