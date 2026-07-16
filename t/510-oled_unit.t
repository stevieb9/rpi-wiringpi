# TESTDOC: RPi::OLED::SSD1306 unit (HW-free)
use strict;
use warnings;
use Test::More;

use RPi::OLED::SSD1306::128_64;

# Mirror of RPi::OLED::SSD1306::128_64's HW-free tests (its t/05-unit.t), run here
# against the INSTALLED module. Each validating method croaks before its XS draw
# call, so a bare blessed object covers the bounds/integer checks with no panel;
# the singleton test stubs the XS init so new() runs HW-free. t/500-520 drive the
# real OLED on board-4.
#
# NOTE: the 3.1802 warn-on-mismatched-address behaviour (F16) is dist-only until
# 3.1802 is installed (installed is 3.1801, which silently ignores it), so only
# the "returns the same instance" half of the singleton is asserted here.

my $mod = 'RPi::OLED::SSD1306::128_64';

{
    my $o = bless {}, $mod;

    eval { $o->text_size('x') };
    like $@, qr/must be an integer/, 'text_size(non-integer): croaks';

    eval { $o->rect(-1, 0, 1, 1) };  like $@, qr/X must be between 0 and 127/,     'rect: X < 0 croaks';
    eval { $o->rect(128, 0, 1, 1) }; like $@, qr/X must be between 0 and 127/,     'rect: X > 127 croaks';
    eval { $o->rect(0, -1, 1, 1) };  like $@, qr/y must be between 0 and 63/,      'rect: y < 0 croaks';
    eval { $o->rect(0, 64, 1, 1) };  like $@, qr/y must be between 0 and 63/,      'rect: y > 63 croaks';
    eval { $o->rect(0, 0, -1, 1) };  like $@, qr/width must be between 0 and 128/, 'rect: w < 0 croaks';
    eval { $o->rect(0, 0, 129, 1) }; like $@, qr/width must be between 0 and 128/, 'rect: w > 128 croaks';
    eval { $o->rect(0, 0, 1, -1) };  like $@, qr/height must be between 0 and 64/, 'rect: h < 0 croaks';
    eval { $o->rect(0, 0, 1, 65) };  like $@, qr/height must be between 0 and 64/, 'rect: h > 64 croaks';

    eval { $o->pixel(-1, 0) };  like $@, qr/X must be between 0 and 127/, 'pixel: X < 0 croaks';
    eval { $o->pixel(128, 0) }; like $@, qr/X must be between 0 and 127/, 'pixel: X > 127 croaks';
    eval { $o->pixel(0, -1) };  like $@, qr/0 and 63/,                    'pixel: Y < 0 croaks';
    eval { $o->pixel(0, 64) };  like $@, qr/0 and 63/,                    'pixel: Y > 63 croaks';

    eval { $o->dim(-1) }; like $@, qr/either 1 or 0/, 'dim(-1): croaks';
    eval { $o->dim(2) };  like $@, qr/either 1 or 0/, 'dim(2): croaks';
    eval { $o->invert_display(-1) }; like $@, qr/either 1 or 0/, 'invert_display(-1): croaks';
    eval { $o->invert_display(2) };  like $@, qr/either 1 or 0/, 'invert_display(2): croaks';
}

{
    no warnings qw(redefine once);
    local *RPi::OLED::SSD1306::128_64::ssd1306_begin        = sub { };
    local *RPi::OLED::SSD1306::128_64::ssd1306_display      = sub { };
    local *RPi::OLED::SSD1306::128_64::ssd1306_clearDisplay = sub { };

    my $first = $mod->new(0x3C);
    isa_ok $first, $mod;
    is $mod->new, $first, 'new(): returns the same singleton instance';
}

# --- sleep()/wake(): the exact SSD1306 command sequences, captured HW-free ---
# Needs RPi::OLED::SSD1306::128_64 >= 3.1802 installed; skipped against older
# installs, mirroring the F16 singleton install-lag note at the top of this file.
SKIP: {
    skip "installed RPi::OLED::SSD1306::128_64 lacks sleep() (pre-3.1802)", 4
        unless $mod->can('sleep');

    my @cmd;
    no warnings qw(redefine once);
    local *RPi::OLED::SSD1306::128_64::ssd1306_command = sub { push @cmd, $_[0] };

    my $o = bless {}, $mod;

    @cmd = ();
    is $o->sleep, 1, 'sleep(): returns 1';
    is_deeply \@cmd, [0x8D, 0x10, 0xAE],
        'sleep(): charge pump off (0x8D 0x10) then display off (0xAE)';

    @cmd = ();
    is $o->wake, 1, 'wake(): returns 1';
    is_deeply \@cmd, [0x8D, 0x14, 0xAF],
        'wake(): charge pump on (0x8D 0x14) then display on (0xAF)';
}

done_testing();
