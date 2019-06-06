#!/usr/bin/env perl

use warnings;
use strict;

use 5.10.0;

use DateTime;
use RPi::WiringPi;

my $pi = RPi::WiringPi->new;
my $oled = RPi::WiringPi->oled('128x64', 0x3C, 0);
my $bmp = $pi->bmp(400);

my $dt = DateTime->now(time_zone => 'local');

my $Tc = sprintf('%.02f', $bmp->temp('c'));
my $Tf = sprintf('%.02f', $bmp->temp);
my $p = $bmp->pressure;

$oled->text_size(2);

$oled->string(str_format($dt->ymd));

$oled->string(str_format($dt->hms(':')));

$oled->string(str_format($Tc . " C"));
$oled->string(str_format($p . "kPa", 1));

$oled->display;

sub str_format {
    my $str = shift;

    my $str_len = length $str;

    return $str if $str_len == 10;

    my $to_add = 10 - $str_len;

    $str .= " " x $to_add;

    return $str;
}
