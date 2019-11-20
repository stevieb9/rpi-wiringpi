package RPiTest;

use warnings;
use strict;

use Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
    rpi_sudo_check
    rpi_multi_check
    rpi_pod_check
    rpi_running_test
    rpi_default_pin_config
    rpi_check_pin_status
    rpi_verify_pin_status
    rpi_oled_available
    rpi_oled_unavailable
    rpi_metadata_clean
    rpi_legal_object_count
    rpi_legal_pin_count
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

# gather relevant details for testing

my $legal_object_count = $ENV{RPI_OBJECT_COUNT};
my $legal_pin_count = $ENV{RPI_PIN_COUNT};
my $oled_lock = '/dev/shm/oled_unavailable.rpi-wiringpi';

# fetch the number of pre-existing objects and pins in use

sub rpi_legal_object_count {
    return $legal_object_count; # crontab-run scripts
}
sub rpi_legal_pin_count {
    return $legal_pin_count; # crontab-run scripts
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

# fetch the default pin state and mode

sub rpi_default_pin_config {
    # default pin configurations

    my $pin_conf = {
      '3' => {
               'alt' => 4,
               'state' => 1
             },
      '4' => {
               'state' => 1,
               'alt' => 0
             },
      '17' => {
                'state' => 1,
                'alt' => 0
              },
      '15' => {
                # alt 4 (ALT0) when Serial bluetooth disabled
                'state' => 1,
                'alt' => 4
              },
      '23' => {
                'state' => 0,
                'alt' => 0
              },
      '25' => {
                'state' => 0,
                'alt' => 0
              },
      '24' => {
                'alt' => 0,
                'state' => 0
              },
      '13' => {
                'state' => 0, # state: HIGH:   due to the dpot test (t/50)
                'alt' => 0    # mode:  OUTPUT: due to the dpot test (t/50)
              },
      '1' => {
               'state' => 1,
               'alt' => 0
             },
      '27' => {
                # hot due to LCD
                'state' => 1,
                'alt' => 0
              },
      '16' => {
                'state' => 0,
                'alt' => 0
              },
      '18' => {
                'state' => 0,
                'alt' => 0
              },
      '22' => {
                'alt' => 0,
                'state' => 1
              },
#FIXME: removed due to inherent flipping
#      '26' => {
#                #FIXME: don't know why this one goes from
#                # INPUT to ALT0
#                'state' => 0,
#                'alt' => 4
#              },
      '6' => {
               'state' => 1,
               'alt' => 0
             },
      '7' => {
               'alt' => 1,
               'state' => 1
             },
      '0' => {
               'alt' => 0,
               'state' => 1
             },
      '2' => {
               'state' => 1,
               'alt' => 4
             },
      '21' => {
                'alt' => 0,
                'state' => 0
              },
      '20' => {
                'alt' => 0,
                'state' => 0
              },
      '14' => {
                # alt 4 (ALT0) when Serial bluetooth disabled
                'state' => 1,
                'alt' => 4
              },
      '11' => {
                'alt' => 4,
                'state' => 0
              },

#FIXME: removed due to inherent flipping
#      '12' => {
#                'alt' => 0,
#                'state' => 0
#              },
      '10' => {
                'alt' => 4,
                'state' => 0
              },
              '5' => {
               'alt' => 0,
               'state' => 1
             },
      '9' => {
               'alt' => 4,
               'state' => 0
             },
      '8' => {
               'state' => 1,
               'alt' => 1
             },
      '19' => {
                'alt' => 0,
                'state' => 0
            },
    };

    return $pin_conf;
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
            WiringPi::API::pinModeAlt($pin, $pin_defaults->{$pin}{alt});
            WiringPi::API::digitalWrite($pin, $pin_defaults->{$pin}{state});
        }
    }
}

1;
