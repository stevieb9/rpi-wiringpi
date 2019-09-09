#!/usr/bin/env perl

use warnings;
use strict;

use Net::SMTP;
use RPi::WiringPi;

use constant {
    DEBUG       => 0,
    DEBUG_SMTP  => 0,

    SEND_TEXT   => 1,

    PIR_OFF     => 50,
    PIR_ON      => 51,

    BSMT_CLOSED => 60,
    BSMT_OPEN   => 61,

    TRIP_CLOSED => 70,
    TRIP_OPEN   => 71,
};

my $pir_state = 0;

my $security_devices = {
    5   => { code => \&pir, name => 'PIR' },
};

my $pi = RPi::WiringPi->new(label => 'hc12_security_monitor.pl');
my $s = $pi->serial('/dev/ttyUSB0', 9600);

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
        print "Motion detected on the PIR!\n" if ! $pir_state;

        if (! $pir_state){
            text("PIR motion detected!");
        }
        $pir_state = 1;
    }
    else {
        print "...motion stopped\n" if $pir_state;
        $pir_state = 0;
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
sub text {
    my ($message) = @_;

    return if ! SEND_TEXT;

    if (! $ENV{GMAIL_PW}){
        warn "You need to set your GMail password in the GMAIL_PW env var!\n";
        return;
    }
    if (! $ENV{GMAIL_ADDR}){
        warn "You need to set your GMail address in the GMAIL_ADDR env var!\n";
        return;
    }
    if (! $ENV{GMAIL_TO}){
        warn "You need to set your GMail recipient in the GMAIL_TO env var!\n";
        return;
    }
    if (! $ENV{GMAIL_SERVER}){
        warn "You need to set your GMail server in the GMAIL_SERVER env var!\n";
        return;
    }

    my $smtp = Net::SMTP->new(
        $ENV{GMAIL_SERVER},
        Hello => 'local.example.com',
        Timeout => 30,
        Debug   => DEBUG_SMTP,
        SSL     => 1,
    );

    $smtp->auth($ENV{GMAIL_ADDR}, $ENV{GMAIL_PW})
        or die $!;
    $smtp->mail($ENV{GMAIL_ADDR});
    $smtp->to($ENV{GMAIL_TO});
    $smtp->data();
    $smtp->datasend($message);
    $smtp->quit();
}
