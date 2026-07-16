# TESTDOC: RPi::TFT::ST7735S unit (HW-free)
use strict;
use warnings;

use Test::More;

# Mirror of RPi::TFT::ST7735S's HW-free tests (its t/05-params.t + t/06-draw.t),
# run here against the INSTALLED module. Post-XS the drawing engine is a C
# framebuffer: rasterizing is checked by peeking pixels back out of it, and the
# flush framing (window addressing, RGB565 order, chunking) is checked by
# stubbing the two hardware seams - the D/C GPIO write is neutered, and a fake
# SPI records every byte frame rw() is handed. We never call new() (which would
# open the bus), but build a bare object configured the way new() leaves it,
# with a real C framebuffer behind it and auto-flush on. t/447-tft_st7735s.t
# drives a real ST7735S through $pi->tft.
#
# Non-gated: needs no hardware and runs anywhere. Skips cleanly only when the
# (as-yet-unreleased) family leaf isn't installed.

BEGIN {
    if (! eval { require RPi::TFT::ST7735S; 1 }){
        plan skip_all => "RPi::TFT::ST7735S not installed";
    }
}

{
    no warnings 'redefine';
    *RPi::TFT::ST7735S::_write = sub { 1 };
}

{
    package Fake::SPI;
    sub new { bless { sent => [] }, shift }
    sub rw {
        my ($self, $buf, $len) = @_;
        push @{ $self->{sent} }, [@$buf];
        return @$buf;
    }
}

# ===========================================================================
# Parameter validation (mirror of dist t/05-params.t)
# ===========================================================================
#
# Every new() case below croaks before setup_gpio() or the SPI bus is ever
# reached, and the method cases run against a bare blessed object that never
# opened any hardware, so no Pi (nor native GPIO) is touched.

# --- new() ---

eval { RPi::TFT::ST7735S->new; };
like $@, qr/requires the dc param/, "new() requires the dc pin param";

eval { RPi::TFT::ST7735S->new(dc => 'abc'); };
like $@, qr/requires the dc param/, "new() rejects a non-integer dc pin";

eval { RPi::TFT::ST7735S->new(dc => 25, channel => 'abc'); };
like $@, qr/channel param/, "new() rejects a bad channel";

eval { RPi::TFT::ST7735S->new(dc => 25, rst => 'abc'); };
like $@, qr/rst param/, "new() rejects a non-integer rst pin";

eval { RPi::TFT::ST7735S->new(dc => 25, bl => 'abc'); };
like $@, qr/bl param/, "new() rejects a non-integer bl pin";

eval { RPi::TFT::ST7735S->new(dc => 25, speed => 0); };
like $@, qr/speed param/, "new() rejects a zero speed";

eval { RPi::TFT::ST7735S->new(dc => 25, rotation => 4); };
like $@, qr/rotation param/, "new() rejects an out-of-range rotation";

eval { RPi::TFT::ST7735S->new(dc => 25, colstart => 'x'); };
like $@, qr/colstart and rowstart/, "new() rejects a bad colstart";

# --- methods, on a bare object ---

{
    my $bare = bless {}, 'RPi::TFT::ST7735S';

    eval { $bare->pixel('x', 0, 0xF800); };
    like $@, qr/\$x and \$y params must be integers/, "pixel() validates coords";

    eval { $bare->pixel(0, 0, 'x'); };
    like $@, qr/\$colour param/, "pixel() validates the colour";

    eval { $bare->fill_screen(0x1FFFF); };
    like $@, qr/\$colour param/, "fill_screen() validates the colour range";

    eval { $bare->rect(0, 0, 'x', 1, 0xF800); };
    like $@, qr/\$x, \$y, \$w and \$h params must be integers/, "rect() validates coords";

    eval { $bare->horizontal_line('x', 0, 5, 0xF800); };
    like $@, qr/\$x, \$y and \$length params must be integers/, "horizontal_line() validates coords";

    eval { $bare->vertical_line(0, 'x', 5, 0xF800); };
    like $@, qr/\$x, \$y and \$length params must be integers/, "vertical_line() validates coords";

    eval { $bare->line('x', 0, 1, 1, 0xF800); };
    like $@, qr/params must be integers/, "line() validates coords";

    eval { $bare->char(0, 0, 'A', 'x'); };
    like $@, qr/\$colour param/, "char() validates the foreground colour";

    eval { $bare->char(0, 0, 'A', 0xFFFF, undef, 0); };
    like $@, qr/\$size param/, "char() validates the size";

    eval { $bare->string(0, 0, undef, 0xFFFF); };
    like $@, qr/\$string param/, "string() requires a defined string";

    eval { $bare->rotation(4); };
    like $@, qr/\$rotation param/, "rotation() validates its param";

    eval { $bare->backlight(1); };
    like $@, qr/needs the bl pin/, "backlight() croaks without a bl pin";

    eval { $bare->color565(256, 0, 0); };
    like $@, qr/params must be integers 0-255/, "color565() rejects out-of-range channels";

    eval { $bare->color565('x', 0, 0); };
    like $@, qr/params must be integers 0-255/, "color565() rejects non-integers";
}

# ===========================================================================
# Drawing path (mirror of dist t/06-draw.t)
# ===========================================================================

# --- color565: 8-8-8 packed down to 5-6-5 ---

is(RPi::TFT::ST7735S->color565(255, 0, 0),     0xF800, 'color565() red');
is(RPi::TFT::ST7735S->color565(0, 255, 0),     0x07E0, 'color565() green');
is(RPi::TFT::ST7735S->color565(0, 0, 255),     0x001F, 'color565() blue');
is(RPi::TFT::ST7735S->color565(255, 255, 255), 0xFFFF, 'color565() white');
is(RPi::TFT::ST7735S->color565(0, 0, 0),       0x0000, 'color565() black');

# --- pixel: lands in the framebuffer, then flushes its window ---

my $tft = make_tft();
$tft->pixel(10, 20, 0xF800);
is peek($tft, 10, 20), 0xF800, 'pixel() sets the framebuffer';
is_deeply sent($tft), [
    [0x2A],
    [0x00, 12, 0x00, 12],   # column 10 + colstart 2
    [0x2B],
    [0x00, 23, 0x00, 23],   # row    20 + rowstart 3
    [0x2C],
    [0xF8, 0x00],           # RED, high byte then low
], 'pixel() flush addresses the offset window and streams one RGB565 pixel';

# --- off-screen pixels are silently clipped to nothing ---

my $off = make_tft();
$off->pixel(200, 0, 0xF800);
$off->pixel(-1, 0, 0xF800);
is_deeply sent($off), [], 'pixel() off the panel draws nothing';

# --- rect: fills the framebuffer, flushes its window ---

my $rect = make_tft();
$rect->rect(0, 0, 2, 1, 0x001F);
is peek($rect, 0, 0), 0x001F, 'rect() fills its first pixel';
is peek($rect, 1, 0), 0x001F, 'rect() fills its last pixel';
is peek($rect, 2, 0), 0x0000, 'rect() leaves the pixel past its width alone';
is_deeply sent($rect), [
    [0x2A],
    [0x00, 2, 0x00, 3],     # x 0..1 + colstart 2
    [0x2B],
    [0x00, 3, 0x00, 3],     # y 0..0 + rowstart 3
    [0x2C],
    [0x00, 0x1F, 0x00, 0x1F],
], 'rect() flushes its window with a repeated RGB565 pair';

# --- rect clips to the panel ---

my $clip = make_tft();
$clip->rect(126, 0, 10, 1, 0xFFFF);
is peek($clip, 126, 0), 0xFFFF, 'rect() fills the last visible column';
is peek($clip, 127, 0), 0xFFFF, 'rect() fills up to the panel edge';
is_deeply sent($clip)->[1], [0x00, 128, 0x00, 129],
    'rect() clips an over-wide rectangle to the panel edge';
is_deeply sent($clip)->[5], [0xFF, 0xFF, 0xFF, 0xFF],
    'rect() streams only the two pixels that remain visible';

my $gone = make_tft();
$gone->rect(200, 0, 10, 10, 0xFFFF);
is_deeply sent($gone), [], 'a fully off-screen rect draws nothing';

# --- the line helpers delegate to a one-pixel-thick rect ---

my $hl = make_tft();
$hl->horizontal_line(0, 0, 3, 0x07E0);
is_deeply sent($hl)->[1], [0x00, 2, 0x00, 4], 'horizontal_line() spans the length';
is_deeply sent($hl)->[3], [0x00, 3, 0x00, 3], 'horizontal_line() is one row tall';

my $vl = make_tft();
$vl->vertical_line(0, 0, 3, 0x07E0);
is_deeply sent($vl)->[1], [0x00, 2, 0x00, 2], 'vertical_line() is one column wide';
is_deeply sent($vl)->[3], [0x00, 3, 0x00, 5], 'vertical_line() spans the length';

# --- rotation sets MADCTL, OR'ing in the colour-order bit ---

for my $case (
    [0, 0xC8],   # MX | MY | BGR
    [1, 0xA8],   # MY | MV | BGR
    [2, 0x08],   #           BGR
    [3, 0x68],   # MX | MV | BGR
) {
    my ($rot, $madctl) = @$case;

    my $r = make_tft();
    $r->rotation($rot);

    is_deeply sent($r)->[-2], [0x36], "rotation($rot) issues the MADCTL command";
    is_deeply sent($r)->[-1], [$madctl], "rotation($rot) MADCTL byte";
    is $r->rotation, $rot, "rotation($rot) is remembered";
}

# --- rgb => 1 clears the BGR bit ---

my $rgb = make_tft();
$rgb->{colororder} = 0x00;
$rgb->rotation(2);
is_deeply sent($rgb)->[-1], [0x00], 'rgb colour order clears the BGR bit in MADCTL';

# --- the odd rotations swap the visible-area offsets ---

my $swap = make_tft();
$swap->rotation(1);
@{ $swap->{spi}{sent} } = ();
$swap->pixel(0, 0, 0x0000);
is_deeply sent($swap)->[1], [0x00, 3, 0x00, 3], 'rotation(1) takes x offset from rowstart';
is_deeply sent($swap)->[3], [0x00, 2, 0x00, 2], 'rotation(1) takes y offset from colstart';

# --- the font: '!' lights six pixels in its one active column ---

my $bang = make_tft();
$bang->char(0, 0, '!', 0x07E0);
is_deeply
    [map { peek($bang, 2, $_) } 0 .. 6],
    [(0x07E0) x 5, 0x0000, 0x07E0],
    "char('!') lights column 2's six set rows and leaves the clear row alone";
is_deeply sent($bang)->[1], [0x00, 4, 0x00, 4],
    "char() flush addresses glyph column 2 + xstart";
is_deeply sent($bang)->[3], [0x00, 3, 0x00, 9],
    "char() flush spans the glyph's dirty rows + ystart";
is scalar(@{ sent($bang) }), 6,
    "char('!') flushes its glyph bounding box as a single window";

# --- a space with no background is fully transparent ---

my $space = make_tft();
$space->char(0, 0, ' ', 0xFFFF);
is_deeply sent($space), [], 'a blank glyph with no background draws nothing';

# --- a background colour fills the whole scaled cell ---

my $solid = make_tft();
$solid->char(0, 0, ' ', 0xFFFF, 0x001F);
is peek($solid, 0, 0), 0x001F, "char() with a background paints the clear pixels";
is peek($solid, 4, 6), 0x001F, "char() background covers the 5x7 cell";

# --- string advances the cursor six columns per character ---

my $str = make_tft();
$str->string(0, 0, "!!", 0x07E0);
is peek($str, 2, 0), 0x07E0, "string() draws the first glyph at column 2";
is peek($str, 8, 0), 0x07E0,
    "string() advances the cursor 6 px (glyph col 2 -> x 8) for the second char";

# --- fill_screen chunks the framebuffer to spidev's per-transfer limit ---

my $fill = make_tft();
$fill->fill_screen(0x0000);
is_deeply sent($fill)->[1], [0x00, 2, 0x00, 129], 'fill_screen() column window covers the panel';
is_deeply sent($fill)->[3], [0x00, 3, 0x00, 130], 'fill_screen() row window covers the panel';
is scalar(@{ sent($fill) }), 13,
    'fill_screen() splits 32768 bytes into 8 chunks after the 5 setup frames';
is scalar(@{ sent($fill)->[5] }), 4096, 'each pixel chunk is at most MAX_XFER bytes';

# --- line walks each point into the framebuffer, flushed as one window ---

my $dot = make_tft();
$dot->line(0, 0, 0, 0, 0xFFFF);
is peek($dot, 0, 0), 0xFFFF, 'line() of zero length sets a single pixel';
is scalar(@{ sent($dot) }), 6, 'line() of zero length flushes a single-pixel window';

my $seg = make_tft();
$seg->line(0, 0, 2, 0, 0xFFFF);
is_deeply
    [map { peek($seg, $_, 0) } 0 .. 2],
    [0xFFFF, 0xFFFF, 0xFFFF],
    'line() draws every point along its length';
is scalar(@{ sent($seg) }), 6, 'line() flushes its bounding box as a single window';

# --- sleep()/wake(): the SLPIN/SLPOUT deep-power commands ---
# Needs RPi::TFT::ST7735S >= 3.1802 installed; skipped against older installs.
SKIP: {
    skip "installed RPi::TFT::ST7735S lacks sleep() (pre-3.1802)", 4
        unless RPi::TFT::ST7735S->can('sleep');

    no warnings 'redefine';
    local *RPi::TFT::ST7735S::_nap = sub { };   # Skip the ~120ms settle in the test

    my $s = make_tft();
    is $s->sleep, 1, 'sleep() returns 1';
    is_deeply sent($s), [[0x10]], 'sleep() sends SLPIN (0x10)';

    my $w = make_tft();
    is $w->wake, 1, 'wake() returns 1';
    is_deeply sent($w), [[0x11]], 'wake() sends SLPOUT (0x11)';
}

done_testing();

# Build a bare object configured the way new() leaves it, with a real C
# framebuffer behind it and a fake SPI in place of the real bus.

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
        buffered   => 0,
        pin        => { dc => 25 },
    }, 'RPi::TFT::ST7735S';

    $tft->{dev} = RPi::TFT::ST7735S::st7735s_create(128, 128);
    $tft->{spi} = Fake::SPI->new;

    return $tft;
}
sub peek {
    my ($tft, $x, $y) = @_;
    return RPi::TFT::ST7735S::st7735s_peek($tft->{dev}, $x, $y);
}
sub sent {
    my ($tft) = @_;
    return $tft->{spi}{sent};
}
</content>
