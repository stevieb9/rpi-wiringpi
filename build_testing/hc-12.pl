use warnings;
use strict;

use RPi::Serial;

if (! $ARGV[0]){
    print "usage: hc-12.pl BAUDRATE\n";
    exit;
}
my $baud = $ARGV[0];
my $dev = '/dev/ttyS0';

my $s = RPi::Serial->new($dev, $baud);

$s->puts("AT+RX");

sleep 1;

my $r = $s->gets($s->avail);
print "$r\n";
