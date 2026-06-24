use warnings;
use strict;

use Test::More;

use RPi::DAC::MCP4922;

# Mirror of RPi::DAC::MCP4922's own t/register.t, run here in the canonical
# suite. t/310-dac.t drives the DAC on real hardware; this adds HW-free
# verification of the pure register word-builders and the accessor/constructor
# validation, against the INSTALLED module, ungated (no RPiTest, no shm, no Pi).
# (The core _set word assembly writes-and-returns-void -> B1 before it's
# unit-testable.)

my $mod = 'RPi::DAC::MCP4922';

# --- _reg_init(buf, gain): BUF(14) | GAIN(13) | SHDN(12, always on) ---

is RPi::DAC::MCP4922::_reg_init(0, 0), 0x1000, "_reg_init(0,0): SHDN only";
is RPi::DAC::MCP4922::_reg_init(0, 1), 0x3000, "_reg_init(0,1): GAIN + SHDN";
is RPi::DAC::MCP4922::_reg_init(1, 0), 0x5000, "_reg_init(1,0): BUF + SHDN";
is RPi::DAC::MCP4922::_reg_init(1, 1), 0x7000, "_reg_init(1,1): BUF + GAIN + SHDN";

# --- __set_dac(buf, dac): sets/clears DAC-select bit 15, preserves the rest ---

is RPi::DAC::MCP4922::__set_dac(0x0000, 0), 0x0000, "__set_dac: DAC A leaves bit 15 clear";
is RPi::DAC::MCP4922::__set_dac(0x0000, 1), 0x8000, "__set_dac: DAC B sets bit 15";
is RPi::DAC::MCP4922::__set_dac(0x7000, 1), 0xF000, "__set_dac: DAC B preserves the control bits";
is RPi::DAC::MCP4922::__set_dac(0x8000, 0), 0x0000, "__set_dac: DAC A clears bit 15";

# --- model -> bits -> lsb chain ---

my %model_bits = (MCP4922 => 12, MCP4912 => 10, MCP4902 => 8, 4922 => 12);
for my $model (sort keys %model_bits) {
    my $d = bless {}, $mod;
    is $d->_model($model), $model_bits{$model}, "_model('$model') -> $model_bits{$model} bits";
}

for my $pair ([12, 0], [10, 2], [8, 4]) {
    my ($bits, $lsb) = @$pair;
    my $d = bless { model => $bits }, $mod;
    is $d->_lsb,      $lsb, "_lsb for $bits-bit model = $lsb";
    is $d->_data_lsb, $lsb, "_data_lsb for $bits-bit model = $lsb";
}

{
    my $d = bless {}, $mod;
    eval { $d->_model('MCP4999') };
    like $@, qr/invalid model/, "_model() dies on a known-format but unmapped model";

    $d = bless {}, $mod;
    eval { $d->_model };
    like $@, qr/no model specified/, "_model() dies when no model is set";
}

# --- accessor validation (dies before any hardware) ---

my %bad = (
    _buf      => [2, -1],
    _channel  => [2, -1],
    _gain     => [2, -1],
    _cs       => [64, -1],
    _shdn_pin => [64, -1],
);
for my $acc (sort keys %bad) {
    for my $val (@{ $bad{$acc} }) {
        my $d = bless {}, $mod;
        eval { $d->$acc($val) };
        ok $@, "$acc($val) dies (out of range)";
    }
}

{
    my $d = bless {}, $mod;
    is $d->_buf,  0, "_buf defaults to 0";
    is $d->_gain, 1, "_gain defaults to 1";
}

# --- register() accessor: set / get / default ---

{
    my $d = bless {}, $mod;
    is $d->register, 0, "register() defaults to 0";
    is $d->register(0x3000), 0x3000, "register() sets and returns the value";
    is $d->register, 0x3000, "register() persists the value";
}

# --- enable/disable guards (die before any SPI write) ---

{
    my $d = bless {}, $mod;
    eval { $d->disable_sw }; like $@, qr/no DAC specified/, "disable_sw() requires a DAC";
    eval { $d->enable_sw };  like $@, qr/no DAC specified/, "enable_sw() requires a DAC";
    eval { $d->disable_hw }; like $@, qr/SHDN pin/,         "disable_hw() requires a SHDN pin";
    eval { $d->enable_hw };  like $@, qr/SHDN pin/,         "enable_hw() requires a SHDN pin";
}

# --- new() validates args before touching hardware ---

eval { $mod->new(channel => 0, cs => 18) };
like $@, qr/no model specified/, "new() without a model dies before hardware";

eval { $mod->new(model => 'MCP4999', channel => 0, cs => 18) };
like $@, qr/invalid model/, "new() with an unmapped model dies before hardware";

eval { $mod->new(model => 'MCP4922', channel => 0, cs => 18, buf => 2) };
like $@, qr/buf must be/, "new() with a bad buf dies before hardware";

done_testing();
