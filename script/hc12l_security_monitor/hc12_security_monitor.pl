#!/usr/bin/env perl

use warnings;
use strict;

use RPi::Serial;

use constant {
    DEBUG   => 0,

    PIR_OFF     => 50,
    PIR_ON      => 51,

    BSMT_CLOSED => 60,
    BSMT_OPEN   => 61,

    TRIP_CLOSED => 70,
    TRIP_OPEN   => 71,
};

my $security_devices = {
    5   => { code => \&pir, name => 'PIR' },
};

my $s = RPi::Serial->new('/dev/ttyUSB0', 9600);

my $data;
my $start_char = '[';
my $end_char = ']';

my ($rx_started, $rx_ended) = (0, 0);

while (1){
    if ($s->avail){
        my $data_populated = rx($start_char, $end_char);

        if ($data_populated){
            # print "$data\n";
            execute_command($data);
            rx_reset();
        }
    }
}

sub execute_command {
    my ($command) = @_;

    my ($dev, $state) = split //, $command;

    print "$security_devices->{$dev}{name}: STATE: $state\n" if DEBUG;
    $security_devices->{$dev}{code}($state);
}

sub pir {
    my ($state) = @_;

    if ($state){
        print "Motion detected on the PIR!\n";
    }
    else {
        print "...motion stopped\n";
    }
}

sub rx {
    my ($start, $end) = @_;

    my $c = chr $s->getc; # getc() returns the ord() val on a char* perl-wise

    if ($c ne $start && ! $rx_started){
        rx_reset();
        return;
    }

    if ($c eq $start){
        $rx_started = 1;
        return;
    }

    if ($c eq $end){
        $rx_ended = 1;
    }

    if ($rx_started && ! $rx_ended){
        $data .= $c;
    }

    if ($rx_started && $rx_ended){
        return local_crc($data)  == remote_crc($data) ? 1 : 0;
    }
}
sub local_crc {
    return $s->crc($_[0], length $_[0]);
}
sub remote_crc {

    while ($s->avail < 2){} # loop until we have two bytes to make up the CRC

    my $msb = $s->getc;
    my $lsb = $s->getc;
    my $crc = ($msb << 8) | $lsb;

    return if $msb == -1 || $lsb == -1;
    return $crc;
}
sub rx_reset {
    $rx_started = 0;
    $rx_ended = 0;
    $data = '';
}
