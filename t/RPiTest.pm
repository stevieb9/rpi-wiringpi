package RPiTest;

use warnings;
use strict;

use Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(check_pin_status);

use Test::More;
use WiringPi::API qw(:perl);

sub check_pin_status {
    setup_gpio();

    my @gpio_pins = qw(
        2 3 4 14 15 17 18 27 22 23 24 10 9 25 11 8 7 0 1 5 6 13 19 16 20 21
    );

    my $conf;

    my $config = default_pin_config();

    for (@gpio_pins){
        is get_alt($_), $config->{$_}{alt}, "pin $_ set back to default mode ok";
        is read_pin($_), $config->{$_}{state}, "pin $_ set back to default state ok";
    }
}

sub default_pin_config {
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
                # hot due to LCD
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
                'state' => 0,
                'alt' => 0
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
                'state' => 0
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

    if ($ENV{BB_RPI_LCD}){

        # if we're in BrewBuild testing with LCD, we
        # need to set some pins up appropriately

        $pin_conf->{4}{alt} = 1;
        $pin_conf->{4}{state} = 0;

        $pin_conf->{5}{alt} = 1;
        $pin_conf->{5}{state} = 0;

        $pin_conf->{6}{alt} = 1;
        $pin_conf->{6}{state} = 0;

        $pin_conf->{22}{alt} = 1;
        $pin_conf->{22}{state} = 0;

        $pin_conf->{27}{alt} = 1;
        $pin_conf->{27}{state} = 0;

        $pin_conf->{17}{alt} = 1;
        $pin_conf->{17}{state} = 0;


    }

    return $pin_conf;
}
