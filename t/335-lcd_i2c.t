# TESTDOC: I2C LCD via PCF8574 backpack
use warnings;
use strict;

use lib 't/';

# Board-1 convenience: set RPI_BOARD_1=1 and the board-1 gates are enabled
# automatically (board 1 carries the I2C LCD). Runs in BEGIN so it lands before
# RPiTest's compile-time RPI_BOARD skip_all gate.
BEGIN {
    if ($ENV{RPI_BOARD_1}) {
        $ENV{$_} = 1 for qw(RPI_BOARD RPI_LCD_I2C);
    }
}

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

if (! $ENV{RPI_LCD_I2C}){
    plan skip_all => "RPI_LCD_I2C environment variable not set\n";
}

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(
    fatal_exit => 0,
    label      => 't/335-lcd_i2c.t',
    shm_key    => 'rpit',
);

# Belt-and-braces: if an assertion or library call dies mid-run, release the
# pins/registration this object holds (the library END reap is best-effort)

END { $pi->cleanup if $pi && ! $pi->{clean}; }

use constant LCD_ADDR => 0x27;   # PCF8574 backpack default (all straps high)

# --- parameter validation (HW-free: each dies before pcf8574Setup/lcd_init) ---

eval { $pi->lcd(i2c => 'x', rows => 4, cols => 20) };
like $@, qr/i2c.*address/, "lcd(i2c => non-integer) dies";

eval { $pi->lcd(i2c => 0x02, rows => 4, cols => 20) };
like $@, qr/0x03-0x77/, "lcd(i2c => out-of-range address) dies";

eval { $pi->lcd(i2c => LCD_ADDR, cols => 20) };
like $@, qr/requires 'rows'/, "lcd(i2c) without rows dies";

eval { $pi->lcd(i2c => LCD_ADDR, rows => 4) };
like $@, qr/requires 'cols'/, "lcd(i2c) without cols dies";

eval { $pi->lcd(i2c => LCD_ADDR, rows => 4, cols => 20, rs => 5) };
like $@, qr/takes no GPIO pin/, "lcd(i2c) mixed with GPIO pin params dies";

eval { $pi->lcd(i2c => LCD_ADDR, rows => 4, cols => 20, pin_base => 10) };
like $@, qr/pin_base/, "lcd(i2c) with pin_base < 64 dies";

# --- the I2C LCD itself (mirrors t/620-lcd.t's ops, driven over the backpack) ---

my $lcd = $pi->lcd(i2c => LCD_ADDR, rows => 4, cols => 20);
isa_ok $lcd, 'RPi::LCD', "lcd(i2c => ...) returns an RPi::LCD object";

# Backlight (I2C): on by default, gettable, toggleable (eyeball the panel)
is $lcd->backlight, 1, "backlight is on (1) by default";
$lcd->backlight(0);
is $lcd->backlight, 0, "backlight(0) turns it off (getter reflects it)";
sleep 1;
$lcd->backlight(1);
is $lcd->backlight, 1, "backlight(1) turns it back on";

eval { $lcd->backlight(2) };
like $@, qr/must be 1/, "backlight(invalid state) dies";

$lcd->position(0, 0);
$lcd->print("hello, world!");

$lcd->position(0, 1);
$lcd->print("line two!");

# Deliberate human-visible pause (not a settle window) - the text just printed
# is meant to be eyeballed on the panel before it's cleared

sleep 2;

$lcd->clear;

is 1, 1, "ok";

# Re-initialising past wiringPi's LCD limit must die. We re-init the existing
# handle directly with the same virtual-pin map lcd(i2c => 0x27) built (PCF8574
# pins at base 64), so we don't re-run pcf8574Setup each pass.

my $ok = eval {
    while (1){
        $lcd->init(
            rows => 4, cols => 20, bits => 4,
            rs => 64, strb => 66,
            d0 => 68, d1 => 69, d2 => 70, d3 => 71,
            d4 => 0, d5 => 0, d6 => 0, d7 => 0,
        );
    }
    1;
};
is $ok, undef, "initialising too many LCD objects dies ok";
like $@, qr/Maximum number of LCD/, "...with the expected error";

$lcd->position(0, 0);
$lcd->print("Testing in progress");

$pi->cleanup;

rpi_check_pin_status();

done_testing();
