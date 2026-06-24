use strict;
use warnings;

use RPi::ADC::ADS;
use Test::More;

# Mirror of RPi::ADC::ADS's HW-free register/validation tests (its t/26, t/56,
# t/925 bad-param block), run here in the canonical suite. t/405 and t/420-421
# drive the ADS on hardware; this adds the config-register bit machinery + arg-validation
# checks against the INSTALLED module, ungated (no RPiTest, no shm, no Pi).
# (The volts/percent FSR scaling is welded to the HW read -> B2.)
#
# NOTE: tests the installed module, so the register over-range croak is matched
# version-agnostically (the "msg"->"msb" wording fix is asserted in the dist's
# own t/26 against its source).

my $mod = 'RPi::ADC::ADS';

my $o = $mod->new;

# --- register(): argument validation ---

eval { $o->register(0) };
like $@, qr/requires \$msb and \$lsb/, "register() with only msb dies";

eval { $o->register(300, 0) };
like $@, qr/param requires an int 0\.\.255/, "register() msb > 255 dies";

eval { $o->register(0, 300) };
like $@, qr/lsb param requires an int 0\.\.255/, "register() lsb > 255 dies";

# --- register() set -> bits round-trip ---

{
    my @r = $o->register(0xFF, 0xFF);
    is_deeply \@r, [0xFF, 0xFF], "register() returns the [msb, lsb] pair it set";
    is $o->bits, 0xFFFF, "bits() merges to 0xFFFF";
}

$o->register(0x12, 0x34);
is $o->bits, 0x1234, "bits() = (msb << 8) | lsb";

# --- _bit_set(): clear field, set value, preserve the rest ---

$o->register(0xFF, 0xFF);
$o->_bit_set(0x0200, 0x0E00);
is $o->bits, 0xF3FF, "_bit_set clears the 0xE00 field, sets 0x200, preserves rest";

# --- gain() bad-param validation ---

eval { $o->gain(8) };
like $@, qr/gain param requires/, "gain(8) dies on an out-of-range gain index";

# --- _samples() per-call validation ---

for my $bad (0, -1, 'x') {
    eval { $o->_samples($bad) };
    like $@, qr/samples must be a positive integer/, "_samples('$bad') dies";
}
is $o->_samples(5), 5, "_samples(5) returns 5";
is $o->_samples(undef), 1, "_samples(undef) falls back to the default (1)";

done_testing();
