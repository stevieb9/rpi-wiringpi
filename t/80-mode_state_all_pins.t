use warnings;
use strict;

use Test::More;
use WiringPi::API qw(:perl);

setup_gpio();

if (! $ENV{PI_BOARD}){
    warn "\n*** PI_BOARD is not set! ***\n";
    $ENV{NO_BOARD} = 1;
    plan skip_all => "not on a pi board\n";
}

my @gpio_pins = qw(
    2 3 4 14 15 17 18 27 22 23 24 10 9 25 11 8 7 0 1 5 6 12 13 19 16 26 20 21
);

my $conf;

my $config = default_pin_config();

for (@gpio_pins){
    is get_alt($_), $config->{$_}{alt}, "pin $_ set back to default mode ok";
    is read_pin($_), $config->{$_}{state}, "pin $_ set back to default state ok";
}

done_testing();

sub default_pin_config {
    # default pin configurations

    return {
      '3' => {
               'alt' => 4,
               'state' => 1
             },
      '4' => {
               'state' => 1,
               'alt' => 0
             },
      '17' => {
                'state' => 0,
                'alt' => 0
              },
      '15' => {
                'state' => 1,
                'alt' => 2
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
                'state' => 0,
                'alt' => 0
              },
      '1' => {
               'state' => 1,
               'alt' => 0
             },
      '27' => {
                'state' => 0,
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
                'state' => 0
              },
      '26' => {
                'state' => 0,
                'alt' => 0
              },
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
                'state' => 1,
                'alt' => 2
              },
      '11' => {
                'alt' => 4,
                'state' => 0
              },
      '12' => {
                'alt' => 0,
                'state' => 0
              },
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
}

