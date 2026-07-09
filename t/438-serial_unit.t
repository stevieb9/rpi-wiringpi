# TESTDOC: RPi::Serial unit (HW-free)
use strict;
use warnings;

use RPi::Serial;
use Test::More;

# Mirror of RPi::Serial's HW-free tests (its t/05-unit.t), run here against the
# INSTALLED module. Only the crc() vectors are mirrored: the installed 3.02
# predates the 3.03 tx()/rx()/write()/new()/flush() fixes (and its tx/rx are
# broken), so the framing + validation + flush coverage lives only in the dist's
# t/05-unit.t until RPi::Serial 3.03 is installed/released. crc16 is unchanged,
# so these vectors are stable. Live TX-wired-to-RX coverage is the dist's gated
# t/10-loopback.t (and the rig runs it via t/610-serial.t here).
#
# tty_close is neutralized so DESTROY on a bare test object never closes a real
# fd (the installed 3.02 DESTROY is unguarded).
{
    no warnings 'redefine';
    *RPi::Serial::tty_close = sub { };
}

# Pure-Perl reference of crc16.c (POLY 0x8408, init 0xFFFF, reflected, ~out, then
# a final byte-swap).
sub ref_crc16 {
    my ($data) = @_;
    return 0 if length($data) == 0;   # crc16.c: length 0 returns ~0xFFFF == 0

    my $crc = 0xFFFF;
    for my $ch (split //, $data){
        my $byte = ord($ch) & 0xFF;
        for (1 .. 8){
            if (($crc & 1) ^ ($byte & 1)){
                $crc = (($crc >> 1) ^ 0x8408) & 0xFFFF;
            }
            else {
                $crc = ($crc >> 1) & 0xFFFF;
            }
            $byte >>= 1;
        }
    }
    $crc = (~$crc) & 0xFFFF;
    return ((($crc & 0xFF) << 8) | (($crc >> 8) & 0xFF)) & 0xFFFF;
}

for my $vec ('', 'A', '123456789', "\x00\x01\x02\xff", 'RPi::Serial'){
    my $obj = bless {}, 'RPi::Serial';
    is $obj->crc($vec), ref_crc16($vec),
        sprintf('crc(%s) matches reference', $vec eq '' ? "''" : "'$vec'");
}

done_testing();
