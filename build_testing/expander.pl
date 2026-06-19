use warnings;
use strict;

use RPi::Const qw(:all);
use RPi::GPIOExpander::MCP23017;

my $mcp23017_i2c_addr = 0x21;
my $exp = RPi::GPIOExpander::MCP23017->new($mcp23017_i2c_addr);

# Wired loopback pairs (datasheet pins 1-28, 2-27, 3-26, 4-25):
# GPA0-3 <-> GPB0-3, which are library pins 0-3 (bank A) <-> 8-11 (bank B).
# Drive the bank A side and read its wired bank B partner. The original
# version drove pin 4 (GPA4, not wired here) and read pins 8-15 while
# GPA0-3 floated, so the bank B pins read randomly.

for my $pin_a (0 .. 3) {
    my $pin_b = $pin_a + 8;

    $exp->mode($pin_a, MCP23017_OUTPUT);
    $exp->mode($pin_b, MCP23017_INPUT);

    $exp->write($pin_a, HIGH);
    print "drove pin $pin_a HIGH, pin $pin_b reads: ", $exp->read($pin_b), "\n";

    $exp->write($pin_a, LOW);
    print "drove pin $pin_a LOW,  pin $pin_b reads: ", $exp->read($pin_b), "\n";
}

$exp->cleanup;
