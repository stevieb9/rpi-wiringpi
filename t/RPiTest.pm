package RPiTest;

use warnings;
use strict;

use Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
    rpi_legal_object_count
    rpi_legal_pin_count
    rpi_sudo_check
    rpi_multi_check
    rpi_pod_check
    rpi_running_test
    rpi_oled_available
    rpi_oled_unavailable
    rpi_check_pin_status
    rpi_verify_pin_status
    rpi_default_pin_config
    rpi_board_tag
    rpi_reset
);

use RPi::WiringPi;
use Carp qw(croak);
use Test::More;
use WiringPi::API qw(:perl);

# validate that tests can run

if (! $ENV{PI_BOARD} && ! $ENV{SUDO_USER}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board";
}
if (! defined $ENV{RPI_OBJECT_COUNT} && ! $ENV{SUDO_USER}){
    plan skip_all => "RPI_OBJECT_COUNT env var not set";
}

# relevant testing variables

my $oled_lock = '/dev/shm/oled_unavailable.rpi-wiringpi';

# fetch the number of pre-existing objects and pins in use

sub rpi_legal_object_count {
    return $ENV{RPI_OBJECT_COUNT}; # crontab-run scripts
}
sub rpi_legal_pin_count {
    return $ENV{RPI_PIN_COUNT}; # crontab-run scripts
}

# various test run checks

sub rpi_sudo_check {
    if (! $ENV{RPI_SUDO} && $> != 0){
        plan skip_all => "RPI_SUDO env var not set\n";
    }
}
sub rpi_multi_check {
    if (!$ENV{RPI_MULTI}) {
        plan skip_all => "RPI_MULTI environment variable not set\n";
    }
}
sub rpi_pod_check {
    if (!$ENV{RPI_POD}) {
        plan skip_all => "RPI_POD environment variable not set\n";
    }
}

# fetch the current running test file number

sub rpi_running_test {
    (my $test) = @_;

    my $pi = RPi::WiringPi->new(label => 't/RPiTest.pm', shm_key => 'rpit');
    $pi->meta_lock;
    my $meta = $pi->meta_fetch;
    
    if ($test =~ m|t/(\d+)-(.*)\.t|){
        $meta->{testing}{test_num} = $1;
        $meta->{testing}{test_name} = $2;
        $pi->meta_store($meta);
        $pi->meta_unlock;
        $pi->cleanup;
        return 0;
    }
    elsif ($test =~ /^-\d+/){
        $meta->{testing}{test_num} = -1;
        $meta->{testing}{test_name} = '';
        $pi->meta_store($meta);
        $pi->meta_unlock;
        $pi->cleanup;
        return 0;
    }

    croak
        "rpi_running_test() couldn't translate '$test' to a usable shared format\n";
}

# get and set the availability of the OLED

sub rpi_oled_available {
    my ($available) = @_;

    if ($available) {
        if (-e $oled_lock) {
            unlink $oled_lock or die $!;
        }
    }

    return -e $oled_lock ? 0 : 1;
}
sub rpi_oled_unavailable {
    open my $wfh, '>', $oled_lock or die $!;
    close $wfh;

    return -e $oled_lock ? 1 : 0;
}

# test whether all pins have been reset to program start defaults

sub rpi_check_pin_status {
    setup_gpio();

    # pins 4, 5, 6, 17, 22, 27 removed because of LCD

    my $oled_locked = -e '/dev/shm/oled_in_use';

    note "I2C locked due to external OLED software running; skipping pins 2 and 3";

    my @gpio_pins;

    if ($oled_locked) {
        @gpio_pins = qw(
            14 15 18 23 24 10 9 25 11 8 7 0 1 13 19 16 20 21
        );
    }
    else {
        @gpio_pins = qw(
            2 3 14 15 18 23 24 10 9 25 11 8 7 0 1 13 19 16 20 21
        );
    }
    my $config = rpi_default_pin_config();

    for (@gpio_pins){
        if ($_ == 14 || $_ == 15){
            # serial pins
            my $alt = get_alt($_);
            ok $alt == $config->{$_}{alt} || $alt == 2, "pin $_ set back to default mode ($alt) ok";
            is read_pin($_), $config->{$_}{state}, "pin $_ set back to default state ($config->{$_}{state}) ok";
            next;
        }
        is get_alt($_), $config->{$_}{alt}, "pin $_ set back to default mode ($config->{$_}{alt}) ok";
        is read_pin($_), $config->{$_}{state}, "pin $_ set back to default state ($config->{$_}{state}) ok";
    }
}

# verify whether all pins have been reset to program start defaults

sub rpi_verify_pin_status {
    setup_gpio();

    # pins 4, 5, 6, 17, 22, 27 removed because of LCD

    my $oled_locked = -e '/dev/shm/oled_in_use';

    my @gpio_pins;

    if ($oled_locked) {
        @gpio_pins = qw(
            14 15 18 23 24 10 9 25 11 8 7 0 1 13 19 16 20 21
        );
    }
    else {
        @gpio_pins = qw(
            2 3 14 15 18 23 24 10 9 25 11 8 7 0 1 13 19 16 20 21
        );
    }
    my $config = rpi_default_pin_config();

    my $incorrect_config = 0;

    for (@gpio_pins){
        if ($_ == 14 || $_ == 15){
            # serial pins
            my $alt = get_alt($_);

            $incorrect_config++ if $alt != $config->{$_}{alt} && $alt != 2;
            $incorrect_config++ if read_pin($_) != $config->{$_}{state};
            next;
        }
        
        $incorrect_config++ if get_alt($_) != $config->{$_}{alt};
        $incorrect_config++ if read_pin($_) != $config->{$_}{state};

        return 0 if $incorrect_config;
    }

    return $incorrect_config ? 0 : 1;
}

# identify which board family we're running on, so the correct default pin
# config table can be loaded. The legacy BCM boards (Pi 3, Pi 4) share the
# classic 0-7 alt-mode encoding from get_alt(); the Pi 5 / RP1 peripheral uses
# a different funcsel scheme (e.g. 31 == "null / no peripheral function").

sub rpi_board_tag {
    return 'pi5' if WiringPi::API::pi_rp1_model();

    my $info  = WiringPi::API::pi_board_id();
    my $model = ref $info ? $info->{model} : -1;

    # wiringPi model codes: 17 == 4B, 19 == 400, 20 == CM4
    return 'pi4' if grep { $model == $_ } (17, 19, 20);

    # everything else legacy (3B/3B+/3A+/CM3/Zero etc.)
    return 'pi3';
}

# fetch the default pin state and mode for the detected board

sub rpi_default_pin_config {

    # Pi 3 (BCM2837) - classic 0-7 alt-mode encoding (ALT0 == 4)
    my $pi3 = {
      '0'  => { 'alt' => 0, 'state' => 1 },
      '1'  => { 'alt' => 0, 'state' => 1 },
      '2'  => { 'alt' => 4, 'state' => 1 },
      '3'  => { 'alt' => 4, 'state' => 1 },
      '4'  => { 'alt' => 0, 'state' => 1 },
      '5'  => { 'alt' => 0, 'state' => 1 },
      '6'  => { 'alt' => 0, 'state' => 1 },
      '7'  => { 'alt' => 1, 'state' => 1 },
      '8'  => { 'alt' => 1, 'state' => 1 },
      '9'  => { 'alt' => 4, 'state' => 0 },
      '10' => { 'alt' => 4, 'state' => 0 },
      '11' => { 'alt' => 4, 'state' => 0 },
#FIXME: 12 removed due to inherent flipping
      '13' => { 'alt' => 0, 'state' => 0 }, # OUTPUT/HIGH due to the dpot test (t/50)
      # 14/15: alt 4 (ALT0) when Serial bluetooth disabled
      '14' => { 'alt' => 4, 'state' => 1 },
      '15' => { 'alt' => 4, 'state' => 1 },
      '16' => { 'alt' => 0, 'state' => 0 },
      '17' => { 'alt' => 0, 'state' => 1 },
      '18' => { 'alt' => 0, 'state' => 0 },
      '19' => { 'alt' => 0, 'state' => 0 },
      '20' => { 'alt' => 0, 'state' => 0 },
      '21' => { 'alt' => 0, 'state' => 0 },
      '22' => { 'alt' => 0, 'state' => 1 },
      '23' => { 'alt' => 0, 'state' => 0 },
      '24' => { 'alt' => 0, 'state' => 0 },
      '25' => { 'alt' => 0, 'state' => 0 },
#FIXME: 26 removed due to inherent flipping
      '27' => { 'alt' => 0, 'state' => 1 }, # hot due to LCD
    };

    # Pi 4 (BCM2711) - shares the legacy 0-7 alt-mode encoding with the Pi 3
    my $pi4 = {
      '0'  => { 'alt' => 0, 'state' => 1 },
      '1'  => { 'alt' => 0, 'state' => 1 },
      '2'  => { 'alt' => 4, 'state' => 1 },
      '3'  => { 'alt' => 4, 'state' => 1 },
      '4'  => { 'alt' => 0, 'state' => 1 },
      '5'  => { 'alt' => 0, 'state' => 1 },
      '6'  => { 'alt' => 0, 'state' => 1 },
      '7'  => { 'alt' => 1, 'state' => 1 },
      '8'  => { 'alt' => 1, 'state' => 1 },
      '9'  => { 'alt' => 4, 'state' => 0 },
      '10' => { 'alt' => 4, 'state' => 0 },
      '11' => { 'alt' => 4, 'state' => 0 },
#FIXME: 12 removed due to inherent flipping
      '13' => { 'alt' => 0, 'state' => 0 }, # OUTPUT/HIGH due to the dpot test (t/50)
      # 14/15: alt 4 (ALT0) when Serial bluetooth disabled
      '14' => { 'alt' => 4, 'state' => 1 },
      '15' => { 'alt' => 4, 'state' => 1 },
      '16' => { 'alt' => 0, 'state' => 0 },
      '17' => { 'alt' => 0, 'state' => 1 },
      '18' => { 'alt' => 0, 'state' => 0 },
      '19' => { 'alt' => 0, 'state' => 0 },
      '20' => { 'alt' => 0, 'state' => 0 },
      '21' => { 'alt' => 0, 'state' => 0 },
      '22' => { 'alt' => 0, 'state' => 1 },
      '23' => { 'alt' => 0, 'state' => 0 },
      '24' => { 'alt' => 0, 'state' => 0 },
      '25' => { 'alt' => 0, 'state' => 0 },
#FIXME: 26 removed due to inherent flipping
      '27' => { 'alt' => 0, 'state' => 1 }, # hot due to LCD
    };

    # Pi 5 (RP1) - RP1 funcsel encoding; 31 == "null / no peripheral function"
    my $pi5 = {
      '0'  => { 'alt' => 0,  'state' => 1 },
      '1'  => { 'alt' => 0,  'state' => 1 },
      '2'  => { 'alt' => 0,  'state' => 1 },
      '3'  => { 'alt' => 0,  'state' => 1 },
      '4'  => { 'alt' => 31, 'state' => 0 },
      '5'  => { 'alt' => 31, 'state' => 0 },
      '6'  => { 'alt' => 31, 'state' => 0 },
      '7'  => { 'alt' => 1,  'state' => 1 },
      '8'  => { 'alt' => 1,  'state' => 1 },
      '9'  => { 'alt' => 0,  'state' => 0 },
      '10' => { 'alt' => 0,  'state' => 0 },
      '11' => { 'alt' => 0,  'state' => 0 },
#FIXME: 12 removed due to inherent flipping
      '13' => { 'alt' => 31, 'state' => 0 }, # OUTPUT/HIGH due to the dpot test (t/50)
      # 14/15: RP1 reports null funcsel (31) at default, not ALT0
      '14' => { 'alt' => 31, 'state' => 0 },
      '15' => { 'alt' => 31, 'state' => 0 },
      '16' => { 'alt' => 31, 'state' => 0 },
      '17' => { 'alt' => 1,  'state' => 0 },
      '18' => { 'alt' => 0,  'state' => 0 },
      '19' => { 'alt' => 31, 'state' => 0 },
      '20' => { 'alt' => 31, 'state' => 0 },
      '21' => { 'alt' => 31, 'state' => 0 },
      '22' => { 'alt' => 1,  'state' => 0 },
      '23' => { 'alt' => 1,  'state' => 0 },
      '24' => { 'alt' => 31, 'state' => 0 },
      '25' => { 'alt' => 31, 'state' => 0 },
#FIXME: 26 removed due to inherent flipping
      '27' => { 'alt' => 1,  'state' => 0 }, # hot due to LCD
    };

    my %config = (
        pi3 => $pi3,
        pi4 => $pi4,
        pi5 => $pi5,
    );

    return $config{ rpi_board_tag() };
}

# reset the pins and meta data to default

sub rpi_reset {
    # reset pins and meta data

    my ($all) = @_;

    $all //= 0;

    my $pi = RPi::WiringPi->new(
        label           => 'rpi_reset',
        shm_key         => 'rpit',
        rpi_register    => 0,
    );

    $pi->meta_erase($all);

    my $meta = $pi->meta_fetch;
    $pi->cleanup;

    is keys %{ $meta }, 0, "meta data store has been reset ok";

    my $pin_defaults = rpi_default_pin_config();
    my $valid_pin_config = rpi_verify_pin_status();

    warn "pin configuration is not valid, resetting..." if ! $valid_pin_config;

    if (! $valid_pin_config){
        for my $pin (keys %$pin_defaults) {
            # pinModeAlt() can't set alt 31 ("no function", the Pi 5/RP1 default
            # for many pins); fall back to pinctrl for that case so the reset
            # actually restores those pins. Legacy boards never hit this branch.
            if ($pin_defaults->{$pin}{alt} == 31 && WiringPi::API::pi_rp1_model()){
                system('pinctrl', 'set', $pin, 'no');
            }
            else {
                WiringPi::API::pinModeAlt($pin, $pin_defaults->{$pin}{alt});
            }
            WiringPi::API::digitalWrite($pin, $pin_defaults->{$pin}{state});
        }
    }
}

1;
