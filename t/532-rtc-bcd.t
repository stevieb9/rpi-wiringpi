use strict;
use warnings;

use RPi::RTC::DS3231;
use Test::More;

# Hardware-free, comprehensive proof of the DS3231 BCD-encoding requirement.
#
# The DS3231 stores time/date registers in packed BCD (DS3231 datasheet,
# Figure 1). Writing a raw binary value corrupts every value whose decimal
# form lands a nibble above 9: 10/11/12 become 0x0A/0x0B/0x0C (illegal BCD).
# This file proves the codec end to end and needs no chip, so it adjudicates
# the encoding logic on every test run. The on-silicon falsification (raw byte
# read back through $pi->rtc) lives in t/530-rtc.t.

my $dec2bcd = \&RPi::RTC::DS3231::dec2bcd;
my $bcd2dec = \&RPi::RTC::DS3231::bcd2dec;

{ # Every RTC field value (0..99) must encode to valid BCD and round-trip
    for my $v (0 .. 99) {
        my $bcd = $dec2bcd->($v);
        ok is_valid_bcd($bcd), "dec2bcd($v) is valid BCD";
        is $bcd2dec->($bcd), $v, "...and bcd2dec() round-trips back to $v";
    }
}

{ # The raw-binary write is illegal BCD exactly where the old code corrupted
  # the calendar: 10..15 (months 10/11/12 are the real-world hits)
    for my $v (10 .. 15) {
        ok ! is_valid_bcd($v),
            "raw $v is illegal BCD (what the old raw write stored)";
        isnt $dec2bcd->($v), $v,
            "...and dec2bcd($v) must change it to legal BCD";
    }
}

{ # Named callouts for the calendar/clock values that actually reach the chip
    is $dec2bcd->(10), 0x10, 'month/day 10 encodes to BCD 0x10 (not raw 0x0A)';
    is $dec2bcd->(11), 0x11, 'month/day 11 encodes to BCD 0x11 (not raw 0x0B)';
    is $dec2bcd->(12), 0x12, 'month/hour 12 encodes to BCD 0x12 (not raw 0x0C)';
}

{ # 0..9 are identical raw and BCD -- this is why the bug stayed invisible
    for my $v (0 .. 9) {
        is $dec2bcd->($v), $v, "value $v is identical raw and BCD (bug hidden)";
    }
}

done_testing();

sub is_valid_bcd {
    my ($byte) = @_;
    return (($byte & 0x0F) <= 9) && ((($byte >> 4) & 0x0F) <= 9);
}
