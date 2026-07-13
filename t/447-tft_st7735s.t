# TESTDOC: ST7735S 128x128 SPI TFT display (live, through $pi->tft)
use warnings;
use strict;

use lib 't/';

# Convenience: RPI_ST7735S=1 flips on the master RPI_BOARD gate this file needs,
# so you don't export it by hand. Runs in BEGIN so it lands before RPiTest's
# compile-time RPI_BOARD skip_all. The TFT isn't tied to a test-platform board,
# so there's no RPI_BOARD_N switch here - it's a bench-wired device gated purely
# by RPI_ST7735S.
BEGIN {
    if ($ENV{RPI_ST7735S}){
        $ENV{RPI_BOARD} = 1;
    }
}

use RPiTest;
use RPi::WiringPi;
use Test::More;

# ===========================================================================
# t/447-tft_st7735s.t - RPi::TFT::ST7735S live integration, driven over SPI
#                       through $pi->tft
# ===========================================================================
#
# WHAT THIS PROVES
#
#   The ST7735S driver, reached through RPi::WiringPi's tft() accessor, runs a
#   real 1.44" 128x128 panel end to end. The bus is write-only - there's no
#   readback wire - so, like the stepper test, we verify what we CAN observe:
#   the accessor returns the right object, the panel initialises without
#   croaking, and every drawing and control call (fill, shapes, text, rotation,
#   invert, backlight, on/off) runs to completion returning its documented 1.
#   Watch the panel to confirm the pixels; the test confirms the software path.
#
# WIRING (bench; NOT tied to a test-platform board)
#
#   A 4-wire SPI ST7735S module on the hardware CE0 chip select, with its D/C,
#   RES and BLK lines on the GPIO pins below. Every pin is overridable via env
#   (RPI_ST7735S_CHANNEL, ..._DC, ..._RST, ..._BL) so the bench wiring can move
#   without an edit.
#
#     VCC -> 3V3            SDA/MOSI -> GPIO 10 (MOSI)
#     GND -> GND            SCL/SCK  -> GPIO 11 (SCLK)
#     CS  -> GPIO 8 (CE0)   D/C      -> GPIO 25
#     RES -> GPIO 24        BLK      -> GPIO 23
#
#   The module's SDA/SCL silk-screen are this SPI bus's data (MOSI) and clock
#   (SCLK) pins, wired to GPIO 10/11 as above. Backlight on but nothing drawn
#   is the classic symptom of the data/clock wires on the wrong header pins.
#
# GATE
#
#   RPI_ST7735S    - the ST7735S panel is wired to the SPI bus and powered.
#   Skips cleanly when unset, or when the driver isn't installed.
#
# ===========================================================================

if (! $ENV{RPI_ST7735S}){
    plan skip_all => "RPI_ST7735S environment variable not set\n";
}

# Loaded at runtime, after the gate: the module is an as-yet-unreleased family
# leaf, so a checkout without it installed still parses and skips rather than
# dying at compile time.
if (! eval { require RPi::TFT::ST7735S; 1 }){
    plan skip_all => "RPi::TFT::ST7735S not installed\n";
}

rpi_running_test(__FILE__);

my $channel = $ENV{RPI_ST7735S_CHANNEL} // 0;
my $dc      = $ENV{RPI_ST7735S_DC}      // 25;
my $rst     = $ENV{RPI_ST7735S_RST}     // 24;
my $bl      = $ENV{RPI_ST7735S_BL}      // 23;

my $pi = RPi::WiringPi->new(label => 't/447-tft_st7735s.t', shm_key => 'rpit');

my $tft;
my $cleaned = 0;

my $cleanup = sub {
    return if $cleaned;
    $cleaned = 1;
    $tft->cleanup if $tft;
    $pi->cleanup;
};

local $SIG{INT}  = sub { $cleanup->(); exit 1; };
local $SIG{TERM} = sub { $cleanup->(); exit 1; };

my $ok = eval {
    # Build through the RPi::WiringPi facade's model dispatch
    $tft = $pi->tft(
        model   => 'ST7735S',
        channel => $channel,
        dc      => $dc,
        rst     => $rst,
        bl      => $bl,
    );

    isa_ok $tft, 'RPi::TFT::ST7735S',
        "tft() returns an ST7735S driver";

    is $tft->rotation, 0, "the panel comes up in rotation 0";

    # Fills
    is $tft->clear, 1, "clear() returns 1";
    is $tft->fill_screen(0xF800), 1, "fill_screen() red returns 1";
    is $tft->fill_screen(0x07E0), 1, "fill_screen() green returns 1";
    is $tft->fill_screen(0x001F), 1, "fill_screen() blue returns 1";
    is $tft->clear, 1, "clear() back to black";

    # Shapes
    is $tft->rect(10, 10, 40, 30, 0xFFE0), 1, "rect() returns 1";
    is $tft->line(0, 0, 127, 127, 0xFFFF), 1, "line() returns 1";
    is $tft->horizontal_line(0, 64, 128, 0x07FF), 1, "horizontal_line() returns 1";
    is $tft->vertical_line(64, 0, 128, 0xF81F), 1, "vertical_line() returns 1";
    is $tft->pixel(64, 64, 0xFFFF), 1, "pixel() returns 1";

    # Text
    is $tft->string(6, 6, "RPi::TFT", 0xFFFF, 0x0000), 1, "string() returns 1";
    is $tft->string(6, 20, "ST7735S", 0xFC00, 0x0000, 2), 1, "string() at 2x returns 1";

    # Colour packing
    is $tft->color565(128, 0, 200), 0x8019, "color565() packs a 24-bit colour";
    is $tft->fill_screen($tft->color565(128, 0, 200)), 1, "fill_screen() a packed colour";

    # Display control
    is $tft->invert(1), 1, "invert() on returns 1";
    is $tft->invert(0), 1, "invert() off returns 1";

    is $tft->rotation(1), 1, "rotation(1) returns the new rotation";
    is $tft->clear, 1, "clear() in the rotated orientation";
    is $tft->rotation(0), 0, "rotation(0) restores the orientation";

    is $tft->backlight(0), 1, "backlight() off returns 1";
    is $tft->backlight(1), 1, "backlight() on returns 1";

    is $tft->off, 1, "off() returns 1";
    is $tft->on,  1, "on() returns 1";

    1;
};

my $err = $@;

$cleanup->();

if (! $ok){
    fail("ST7735S live test died before completion: $err");
}

done_testing();
