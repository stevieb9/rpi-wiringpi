use warnings;
use strict;

use RPi::DHT11::EnvControl;
use RPi::WiringPi;
use RPi::WiringPi::Constant qw(:all);

my $continue = 1;
$SIG{INT} = sub { $continue = 0; };

use constant {
    SENSOR_PIN => 29,
    TEMP_PIN => 27,
    HUMIDITY_PIN => 26,
};

my $temp_high = 74.2;
my $humidity_low = 20.0;

# get an environment object

my $env = RPi::DHT11::EnvControl->new(
    spin => SENSOR_PIN,
    tpin => TEMP_PIN,
    hpin => HUMIDITY_PIN,
);

# get a Pi & LCD object

my $pi = RPi::WiringPi->new;
my $lcd = $pi->lcd;

# initialize the LCD

my %lcd_args = (
    rows => 2, cols => 16,
    bits => 4, rs => 6, strb => 5,
    d0 => 4, d1 => 2, d2 => 1, d3 => 3,
    d4 => 0, d5 => 0, d6 => 0, d7 => 0,
);

$lcd->init(%lcd_args);

while ($continue){
    my $temp = $env->temp;
    my $humidity = $env->humidity;

    # temp is too hot

    $lcd->position(0, 0); # first column, first row
    
    if ($temp > $temp_high){
        if (! $env->status(TEMP_PIN)){
            $env->control(TEMP_PIN, ON);
            print "turned on temp control device\n";
        }
        $lcd->print("temp: $temp F  *");
    }
    else {
        if ($env->status(TEMP_PIN)){
            $env->control(TEMP_PIN, OFF);
            print "turned off temp control device\n";
        }
        $lcd->print("temp: $temp F");
    }

    # humidity is too low

    $lcd->position(0, 1); # first column, second row

    if ($humidity < $humidity_low){
        if (! $env->status(HUMIDITY_PIN)){
            $env->control(HUMIDITY_PIN, ON);
            print "turned on humidifier\n";
        }
        $lcd->print("humi: $humidity %     *");
    }
    else {
        if ($env->status(HUMIDITY_PIN)){
            $env->control(HUMIDITY_PIN, OFF);
            print "turned off humidifier";
        }
        $lcd->print("humi: $humidity %");
    }
    sleep 300;
}

$pi->cleanup;
