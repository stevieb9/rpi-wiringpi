# TESTDOC: Serial loopback
use strict;
use warnings;

use lib 't/';

# Board-5 convenience: set RPI_BOARD_5=1 and every env gate the board-5 suite
# needs is enabled automatically, instead of exporting each one by hand. Runs in
# BEGIN so it lands before RPiTest's compile-time RPI_BOARD skip_all gate.
BEGIN {
    if ($ENV{RPI_BOARD_5}) {
        $ENV{$_} = 1 for qw(RPI_BOARD RPI_ARDUINO RPI_SERIAL RPI_LCD);
    }
}

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

# This exercises the whole RPi::Serial surface over a physical loopback: the
# serial TX pin (GPIO 14) must be wired directly to RX (GPIO 15) so everything
# the Pi transmits is what it reads back. Requires RPi::Serial 3.03 (tx()/rx()/
# flush()/write() fixes).

my $mod = 'RPi::WiringPi';

if (! $ENV{RPI_SERIAL}){
    plan skip_all => "RPI_SERIAL environment variable not set\n";
}

rpi_running_test(__FILE__);

my $pi  = $mod->new(label => 't/610-serial.t', shm_key => 'rpit');
my $dev = rpi_serial_device();
my $s   = $pi->serial($dev, 115200);

# --- object + descriptor ---
isa_ok $s, 'RPi::Serial';
ok defined $s->fd && $s->fd >= 0, "fd(): opened $dev with a valid descriptor";

# --- putc()/getc(): the character interface - send a char, read its ordinal ---
# putc() takes a character (its XS 'char' arg is the first byte of the string);
# integer byte values are the job of write(), tested below.
$s->flush;
my $byte_failures = 0;
for my $v (0 .. 255){
    $s->putc(chr($v));
    my $got = _recv_byte($s);
    $byte_failures++ if ! defined $got || $got != $v;
}
is $byte_failures, 0, 'putc()/getc(): all 256 byte values round-trip';

# --- write()/getc(): the integer-byte interface - write() packs a 0-255 value ---
$s->flush;
for my $v (0, 1, 65, 127, 200, 255){
    $s->write($v);
    is _recv_byte($s), $v, "write($v): integer byte round-trips";
}

# write() rejects out-of-range / non-integer values
eval { $s->write(256) };
like $@, qr/between 0 and 255/, 'write(256): out-of-range croaks (no silent wrap)';

eval { $s->write(-1) };
like $@, qr/between 0 and 255/, 'write(-1): croaks';

eval { $s->write() };
like $@, qr/between 0 and 255/, 'write(undef): croaks';

# --- puts()/gets(): string round-trip + short read ---
$s->flush;
$s->puts("hello, world!");
select(undef, undef, undef, 0.05);
is $s->gets(13), "hello, world!", 'puts()/gets(): full string round-trip';

$s->flush;
$s->puts("hi");
select(undef, undef, undef, 0.05);
is $s->gets(10), "hi", 'gets(N): returns the bytes available on a short read';

# --- crc(): CRC-16 checksum ---
is $s->crc(""), 0, 'crc(""): empty payload is 0';
is $s->crc("AB"), 0xEF31, 'crc("AB"): known vector';
is $s->crc("AB"), $s->crc("AB"), 'crc(): deterministic for the same input';
isnt $s->crc("AB"), $s->crc("AC"), 'crc(): differs for different input';

# --- avail()/flush(): buffer accounting ---
$s->flush;
$s->puts("12345");
select(undef, undef, undef, 0.05);
is $s->avail, 5, 'avail(): reflects the buffered byte count';
$s->flush;
is $s->avail, 0, 'flush(): discards the buffered bytes';

# --- Real-world example: CRC-framed reliable messaging -----------------------
#
# tx()/rx() implement a small, robust wire protocol: each message is wrapped
# between a start and an end delimiter and followed by a CRC-16 of the payload.
# The receiver assembles bytes until it sees a complete frame, then accepts the
# payload ONLY if the CRC matches. This is how you move structured data - a
# sensor reading, a command, a status packet - across a noisy UART and know it
# arrived intact. Below the Pi talks to itself over the TX->RX loopback; on a
# real link the two ends would be different devices. Payloads must not contain
# the delimiter characters ('<' / '>').
for my $msg ("PING", "temp=23.5C", "cmd:led=on;pin=17", "\x01\x02\x03data"){
    $s->flush;
    $s->tx($msg, "<", ">");
    select(undef, undef, undef, 0.05);
    is _recv_frame($s, "<", ">"), $msg, "tx()/rx(): CRC-framed round-trip of '$msg'";
}

# The CRC is what makes the link trustworthy: a frame whose CRC does not match
# its payload is rejected (with a warning), never handed back as good data. Here
# we transmit a well-formed frame but corrupt its CRC on the wire.
{
    my $payload = "sensor:42";
    my $crc     = $s->crc($payload);

    $s->flush;
    $s->putc($_) for split //, "<$payload>";
    $s->write((($crc >> 8) ^ 0xFF));   # corrupt the CRC high byte
    $s->write($crc & 0xFF);
    select(undef, undef, undef, 0.05);

    my $warn = '';
    local $SIG{__WARN__} = sub { $warn .= $_[0] };
    my $frame = _recv_frame($s, "<", ">");

    is $frame, undef, 'rx(): rejects a frame whose CRC does not match the payload';
    like $warn, qr/mismatching CRC/, 'rx(): warns when it discards a corrupt frame';
}

$s->close;
$pi->cleanup;

rpi_check_pin_status();

done_testing();

# Poll the loopback until one byte is available, then return it (its ordinal
# value); returns undef if nothing arrives within the timeout.
sub _recv_byte {
    my ($s) = @_;

    for (1 .. 500){
        return $s->getc if $s->avail >= 1;
        select(undef, undef, undef, 0.001);
    }

    return undef;
}

# Drive rx() until it returns a complete frame or the buffered bytes run out.
# The whole frame is buffered before this is called (tx() + settle), so we only
# feed rx() while there is data to consume, avoiding an empty-buffer read.
sub _recv_frame {
    my ($s, $start, $end) = @_;

    my $frame;

    for (1 .. 500){
        last if $s->avail < 1;
        $frame = $s->rx($start, $end);
        last if defined $frame;
    }

    return $frame;
}
