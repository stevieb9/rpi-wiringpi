# TESTDOC: RPi::TFT::ST7735S unit (HW-free)
use strict;
use warnings;

use Test::More;

# Mirror of RPi::TFT::ST7735S's HW-free tests (its t/05-params.t + t/06-draw.t),
# run here against the INSTALLED module. The driver writes to the panel over
# RPi::SPI and drives the D/C line through WiringPi::API. Stubbing the D/C write
# to a no-op and injecting a fake SPI that records every byte frame captures the
# window addressing, RGB565 framing, clipping, rotation MADCTL and font geometry
# with no panel, no SPI bus and no Pi. t/447-tft_st7735s.t drives a real ST7735S
# through $pi->tft.
#
# Non-gated: needs no hardware and runs anywhere. Skips cleanly only when the
# (as-yet-unreleased) family leaf isn't installed.

BEGIN {
    if (! eval { require RPi::TFT::ST7735S; 1 }){
        plan skip_all => "RPi::TFT::ST7735S not installed";
    }
}

my $mod = 'RPi::TFT::ST7735S';

# Neuter the D/C GPIO write so no native GPIO is touched
{
    no warnings 'redefine';
    *RPi::TFT::ST7735S::_write = sub { 1 };
}

# --- validation croaks (mirror of dist t/05-params.t) ---

eval { $mod->new; };
like $@, qr/requires the dc param/, "new() requires the dc pin";

eval { $mod->new(dc => 'abc'); };
like $@, qr/requires the dc param/, "new() rejects a non-integer dc pin";

eval { $mod->new(dc => 25, rotation => 4); };
like $@, qr/rotation param/, "new() rejects an out-of-range rotation";

{
    my $bare = bless {}, $mod;

    eval { $bare->pixel('x', 0, 0xF800); };
    like $@, qr/\$x and \$y params must be integers/, "pixel() validates coords";

    eval { $bare->fill_screen(0x1FFFF); };
    like $@, qr/\$colour param/, "fill_screen() validates the colour range";

    eval { $bare->rect(0, 0, 'x', 1, 0xF800); };
    like $@, qr/params must be integers/, "rect() validates coords";

    eval { $bare->char(0, 0, 'A', 0xFFFF, undef, 0); };
    like $@, qr/\$size param/, "char() validates the size";

    eval { $bare->backlight(1); };
    like $@, qr/needs the bl pin/, "backlight() croaks without a bl pin";

    eval { $bare->color565(256, 0, 0); };
    like $@, qr/params must be integers 0-255/, "color565() rejects out-of-range channels";
}

# --- color565: 8-8-8 packed down to 5-6-5 ---

is $mod->color565(255, 0, 0),     0xF800, 'color565() red';
is $mod->color565(0, 255, 0),     0x07E0, 'color565() green';
is $mod->color565(0, 0, 255),     0x001F, 'color565() blue';
is $mod->color565(255, 255, 255), 0xFFFF, 'color565() white';

# --- framing (mirror of dist t/06-draw.t) ---

my $tft = make_tft();
$tft->pixel(10, 20, 0xF800);
is_deeply sent($tft), [
    [0x2A],
    [0x00, 12, 0x00, 12],   # column 10 + colstart 2
    [0x2B],
    [0x00, 23, 0x00, 23],   # row    20 + rowstart 3
    [0x2C],
    [0xF8, 0x00],           # RED, high byte then low
], 'pixel() addresses the offset window and streams one RGB565 pixel';

my $off = make_tft();
$off->pixel(200, 0, 0xF800);
is_deeply sent($off), [], 'pixel() off the panel draws nothing';

my $rect = make_tft();
$rect->rect(0, 0, 2, 1, 0x001F);
is_deeply sent($rect), [
    [0x2A],
    [0x00, 2, 0x00, 3],
    [0x2B],
    [0x00, 3, 0x00, 3],
    [0x2C],
    [0x00, 0x1F, 0x00, 0x1F],
], 'rect() fills its window with a repeated RGB565 pair';

my $clip = make_tft();
$clip->rect(126, 0, 10, 1, 0xFFFF);
is_deeply sent($clip)->[1], [0x00, 128, 0x00, 129],
    'rect() clips an over-wide rectangle to the panel edge';
is_deeply sent($clip)->[5], [0xFF, 0xFF, 0xFF, 0xFF],
    'rect() streams only the pixels that remain visible';

# rotation sets MADCTL, OR'ing in the colour-order (BGR) bit
for my $case ([0, 0xC8], [1, 0xA8], [2, 0x08], [3, 0x68]){
    my ($rot, $madctl) = @$case;

    my $r = make_tft();
    $r->rotation($rot);

    is_deeply sent($r)->[-2], [0x36],     "rotation($rot) issues the MADCTL command";
    is_deeply sent($r)->[-1], [$madctl],  "rotation($rot) MADCTL byte";
}

# fill_screen chunks the framebuffer to spidev's per-transfer limit
my $fill = make_tft();
$fill->fill_screen(0x0000);
is scalar(@{ sent($fill) }), 13,
    'fill_screen() splits 32768 bytes into 8 chunks after the 5 setup frames';
is scalar(@{ sent($fill)->[5] }), 4096, 'each pixel chunk is at most MAX_XFER bytes';

# the font: '!' lights six pixels in its one active column
my $bang = make_tft();
$bang->char(0, 0, '!', 0x07E0);
is scalar(@{ sent($bang) }), 36, "char('!') emits exactly its six lit pixels";

done_testing();

# Build a bare object configured the way new() leaves it, with a fake SPI in
# place of the real bus.

sub make_tft {
    my $tft = bless {
        width      => 128,
        height     => 128,
        colstart   => 2,
        rowstart   => 3,
        colororder => 0x08,
        xstart     => 2,
        ystart     => 3,
        rotation   => 0,
        pin        => { dc => 25 },
    }, 'RPi::TFT::ST7735S';

    $tft->{spi} = Fake::SPI->new;

    return $tft;
}
sub sent {
    my ($tft) = @_;
    return $tft->{spi}{sent};
}

# Fake SPI: records every byte frame rw() is handed.

package Fake::SPI;

sub new { bless { sent => [] }, shift }
sub rw {
    my ($self, $buf, $len) = @_;
    push @{ $self->{sent} }, [@$buf];
    return @$buf;
}
