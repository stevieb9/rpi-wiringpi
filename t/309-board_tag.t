# TESTDOC: Board-family detection (rpi_board_tag)
use warnings;
use strict;

use lib 't/';

use RPiTest;
use WiringPi::API;
use Test::More;

# ===========================================================================
# t/309-board_tag.t - board-family detection (rpi_board_tag)
# ===========================================================================
#
# Verifies the harness identifies the running board AND does so regardless of
# call order. The trigger this guards against: pi_rp1_model() - the RP1 probe -
# only reports the RP1 *after* a wiringPi setup*() routine has run. Queried
# cold, it reads falsey, so a Pi 5 would otherwise fall through to the legacy
# 'pi3' tag. rpi_board_tag() now runs setup_gpio() itself to defend against it.
#
# Run on each board to confirm:
#   - a Pi 5 tags as 'pi5'
#   - a Pi 3 tags as 'pi3'
# ===========================================================================

# Cold reads, BEFORE rpi_running_test() (or anything else) sets wiringPi up
my $rp1_before = WiringPi::API::pi_rp1_model();
my $cold_tag   = rpi_board_tag();

rpi_running_test(__FILE__);

# Warm reads, after wiringPi has been set up
my $rp1_after = WiringPi::API::pi_rp1_model();
my $warm_tag  = rpi_board_tag();

my ($model, $rev, $mem, $maker, $over_volted) = WiringPi::API::pi_board_id();

note "board tag (cold call):           $cold_tag";
note "board tag (warm call):           $warm_tag";
note "pi_rp1_model() before setup:     " . (defined $rp1_before ? $rp1_before : 'undef');
note "pi_rp1_model() after setup:      " . (defined $rp1_after  ? $rp1_after  : 'undef');
note "pi_board_id model/rev/mem/maker: $model / $rev / $mem / $maker";
note "serial device:                   " . rpi_serial_device();

# 1. The tag is a known board family
like $warm_tag, qr/^pi[345]$/, "board tags as a known family ($warm_tag)";

# 2. Order independence (the fix): a cold query must match the warm one. Pre-fix
# a Pi 5 queried cold returned 'pi3', so this is the regression guard.
is $cold_tag, $warm_tag,
    "rpi_board_tag() is call-order independent (cold '$cold_tag' == warm '$warm_tag')";

# 3. Once setup has run, the RP1 probe and the tag must agree
if ($rp1_after){
    is $warm_tag, 'pi5', "RP1 present, so the board tags as pi5";

    # The cold call got pi5 right even though the RP1 probe read falsey before
    # setup - precisely the misdetection the fix addresses
    is $cold_tag, 'pi5',
        "cold rpi_board_tag() returned pi5 despite pi_rp1_model() reading falsey before setup";
}
else {
    like $warm_tag, qr/^pi[34]$/, "no RP1, so the board tags as legacy (pi3/pi4)";
}

# 4. A default pin-config table exists for the detected board
ok defined rpi_default_pin_config(), "a default pin-config table exists for '$warm_tag'";

# 5. The serial device matches the detected family
my %serial = (
    pi3 => '/dev/ttyS0',
    pi4 => '/dev/ttyS0',
    pi5 => '/dev/ttyAMA0',
);

is rpi_serial_device(), $serial{$warm_tag},
    "serial device matches '$warm_tag' ($serial{$warm_tag})";

done_testing();
