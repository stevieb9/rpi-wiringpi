# TESTDOC: RPi::SPI unit (HW-free)
use strict;
use warnings;

use RPi::SPI;
use Test::More;

# Mirror of RPi::SPI's HW-free tests (its t/05-unit.t), run here in the canonical
# suite against the INSTALLED module. Covers channel/CS routing, speed default,
# bit-bang param validation, and the rw() framing sequence for the plain,
# GPIO-CS (with/without SPI_NO_CS), and bit-bang paths - by blessing a bare
# object and stubbing the transport funcs, so new() (which opens the bus) is
# never called.
#
# NOTE: the dist's t/05-unit.t also asserts the 3.1802 _speed()-croak (F13) and
# rw() argument validation. Those live only in the dist mirror until the fixed
# RPi::SPI is installed/released, so they are intentionally omitted here to keep
# this green against the currently-installed module.

my $mod = 'RPi::SPI';

# --- _channel routing: 0/1 hardware CE, above 1 a GPIO chip select ---
{
    my $s = bless {}, $mod;
    is $s->_channel(0), 0, '_channel(0): hardware CE0';
    ok ! defined $s->_cs, '  channel 0: no GPIO CS';
}
{
    my $s = bless {}, $mod;
    is $s->_channel(1), 1, '_channel(1): hardware CE1';
}
{
    my $s = bless {}, $mod;
    is $s->_channel(26), 0, '_channel(26): GPIO CS routes to hardware channel 0';
    is $s->_cs, 26, '  GPIO 26 recorded as the CS';
}

# --- _cs round-trip + _speed default ---
{
    my $s = bless {}, $mod;
    is $s->_cs(19), 19, '_cs(): round-trips';
    is $s->_speed, 1000000, '_speed(): defaults to 1MHz';
    is $s->_speed(500000), 500000, '_speed(500000): honored';
}

# --- _bitbang pin validation ---
{
    my $s = bless {}, $mod;
    for my $missing (qw(clk mosi miso cs)){
        my %pins = (clk => 21, mosi => 20, miso => 19, cs => 26);
        delete $pins{$missing};
        eval { $s->_bitbang({ %pins }) };
        like $@, qr/bit-bang mode requires an integer '$missing'/,
            "bit-bang: missing $missing croaks";
    }
    my $bb = $s->_bitbang({ clk => 21, mosi => 20, miso => 19, cs => 26 });
    is $bb->{mode}, 0, 'bit-bang: mode defaults to 0';
    is $bb->{delay}, 0, 'bit-bang: delay defaults to 0';
}

# --- rw() framing via stubbed transport funcs ---
{
    no warnings 'redefine';

    my @calls;
    local *RPi::SPI::spiDataRW    = sub { push @calls, ['spiDataRW', $_[0]]; return @{$_[1]} };
    local *RPi::SPI::spiNoCS      = sub { push @calls, ['spiNoCS', $_[0], $_[1]] };
    local *RPi::SPI::digitalWrite = sub { push @calls, ['digitalWrite', $_[0], $_[1]] };
    local *RPi::SPI::spiBitBang   = sub { push @calls, ['spiBitBang', @_[0 .. 3]]; return @{$_[4]} };

    {
        @calls = ();
        my $s = bless { channel => 0 }, $mod;
        $s->rw([0x01, 0x02], 2);
        is_deeply \@calls, [['spiDataRW', 0]], 'rw() plain: spiDataRW only';
    }
    {
        @calls = ();
        my $s = bless { channel => 0, cs => 26, spi_no_cs => 1 }, $mod;
        $s->rw([0x01], 1);
        is_deeply \@calls, [
            ['spiNoCS', 0, 1],
            ['digitalWrite', 26, 0],
            ['spiDataRW', 0],
            ['digitalWrite', 26, 1],
            ['spiNoCS', 0, 0],
        ], 'rw() GPIO-CS (SPI_NO_CS on): isolate + frame + de-isolate';
    }
    {
        @calls = ();
        my $s = bless { channel => 0, cs => 26, spi_no_cs => 0 }, $mod;
        $s->rw([0x01], 1);
        is_deeply \@calls, [
            ['digitalWrite', 26, 0],
            ['spiDataRW', 0],
            ['digitalWrite', 26, 1],
        ], 'rw() GPIO-CS (no SPI_NO_CS): CS framing only';
    }
    {
        @calls = ();
        my $s = bless {
            bitbang => { clk => 21, mosi => 20, miso => 19, cs => 26, mode => 0, delay => 0 },
        }, $mod;
        $s->rw([0x01], 1);
        is_deeply $calls[0], ['spiBitBang', 21, 20, 19, 26],
            'rw() bit-bang: spiBitBang with the configured pins';
    }
}

done_testing();
