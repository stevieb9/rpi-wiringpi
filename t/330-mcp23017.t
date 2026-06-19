use strict;
use warnings;
use Test::More;

# Note: A0, A1 and A2 MUST be died to Gnd

BEGIN {

    if (! $ENV{RPI_MCP23017}){
        plan(skip_all => "RPI_MCP23017 environment variable not set");
    }

    use_ok( 'RPi::GPIOExpander::MCP23017' ) || print "Bail out!\n";
}

use lib 't/';

use RPiTest;
use RPi::Const qw(:all);
use RPi::WiringPi;

use constant {
    BANK_A => 0,
    BANK_B => 1,
};

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(
    fatal_exit => 0,
    label => 't/330-mcp23017.t',
    shm_key => 'rpit'
);

my $o = $pi->expander(0x20);

test_registers()         if ! @ARGV || $ARGV[0] == 1;
test_register_bit()      if ! @ARGV || $ARGV[0] == 2;
test_mode()              if ! @ARGV || $ARGV[0] == 3;
test_write()             if ! @ARGV || $ARGV[0] == 4;
test_bank_mode()         if ! @ARGV || $ARGV[0] == 5;
test_bank_write()        if ! @ARGV || $ARGV[0] == 6;
test_pullup()            if ! @ARGV || $ARGV[0] == 7;
test_pullup_bank()       if ! @ARGV || $ARGV[0] == 8;
test_mode_all()          if ! @ARGV || $ARGV[0] == 9;
test_write_all()         if ! @ARGV || $ARGV[0] == 10;
test_pullup_all()        if ! @ARGV || $ARGV[0] == 11;
test_named_pins()        if ! @ARGV || $ARGV[0] == 12;
test_default_registers() if ! @ARGV || $ARGV[0] == 13;

$o->cleanup;
$pi->cleanup;

rpi_check_pin_status();

done_testing();

sub test_registers {

    # writable registers

    for my $reg (0x00 .. 0x09, 0x0C .. 0x0D, 0x14 .. 0x15) {
        for my $data (0 .. 255) {
            my $ret = $o->register($reg, $data);
            is $ret, $data, "register $reg set to $data ok";
        }
    }

    # reset the interrupt capture registers

    $o->register(MCP23017_INTCAPA);
    $o->register(MCP23017_INTCAPB);

    {
        # non writable: 0x0A-0x0B, 0x0E-0x11

        local $SIG{__WARN__} = sub {};

        for my $reg (0x0A .. 0x0B, 0x0E .. 0x11) {
            is eval {
                    $o->register($reg, 0xFF);
                    1;
                }, undef, "writing to reg $reg croaks ok";
        }
    }
}
sub test_register_bit {
    my @bits = (1, 2, 4, 8, 16, 32, 64, 128);

    for my $reg (0x00 .. 0x09, 0x0C .. 0x0D, 0x14 .. 0x15) {
        # skip read-only registers

        for my $bit (0 .. $#bits) {
            is
                $o->register($reg, $bits[$bit]),
                $bits[$bit],
                "bit '$bit' in reg '$reg' set to $bits[$bit] ok";

            for (0 .. $bit - 1) {
                is $o->register_bit($reg, $_), 0,
                    "bit '$_' in reg '$reg' is off ok";
            }
            is $o->register_bit($reg, $bit), 1,
                "bit '$bit' in reg '$reg' is on ok";
        }
    }

    # reset the interrupt capture registers

    $o->register(MCP23017_INTCAPA);
    $o->register(MCP23017_INTCAPB);
}

sub test_mode {
    for my $reg (MCP23017_IODIRA .. MCP23017_IODIRB) {
        is $o->register($reg, 0xFF), 0xFF, "pins in bank $reg are INPUT ok";

        if ($reg == MCP23017_IODIRA) {
            for my $pin (0 .. 7) {
                $o->mode($pin, MCP23017_OUTPUT);
                is
                    $o->register_bit($reg, $pin),
                    MCP23017_OUTPUT,
                    "pin $pin is now in OUTPUT ok";
            }
            is $o->register($reg, 0xFF), 0xFF,
                "pins in bank $reg back to INPUT ok";
        }

        if ($reg == MCP23017_IODIRB) {
            for my $pin (8 .. 15) {
                $o->mode($pin, MCP23017_OUTPUT);
                is
                    $o->register_bit($reg, $pin),
                    MCP23017_OUTPUT,
                    "pin $pin is now in OUTPUT ok";
            }
            is $o->register($reg, 0xFF), 0xFF,
                "pins in bank $reg back to INPUT ok";
        }
    }

    {
        # get

        $o->cleanup;

        for (0 .. 15) {
            is $o->mode($_), MCP23017_INPUT, "pin $_ INPUT ok";
            $o->mode($_, MCP23017_OUTPUT);

            is $o->mode($_), MCP23017_OUTPUT, "pin $_ OUTPUT ok";

            $o->mode($_, MCP23017_INPUT);
            is $o->mode($_), MCP23017_INPUT, "pin $_ back to INPUT ok";
        }
    }
}

sub test_write {
     for my $reg (MCP23017_IODIRA .. MCP23017_IODIRB){
        is $o->register($reg, 0xFF), 0xFF, "pins in bank $reg are INPUT ok";

        if ($reg == MCP23017_IODIRA){
            for my $pin (0 .. 7){
                $o->mode($pin, MCP23017_OUTPUT);
                is
                    $o->register_bit($reg, $pin),
                    MCP23017_OUTPUT,
                    "pin $pin is now in OUTPUT ok";

                $o->write($pin, HIGH);
                is $o->read($pin), HIGH, "pin $pin is HIGH ok";
                $o->write($pin, LOW);
                is $o->read($pin), LOW, "pin $pin is LOW ok";


            }

            is
                $o->register($reg, 0xFF),
                0xFF,
                "pins in bank $reg back to INPUT ok";
        }

        if ($reg == MCP23017_IODIRB) {
            for my $pin (8..15) {
                $o->mode($pin, MCP23017_OUTPUT);
                is
                    $o->register_bit($reg, $pin),
                    MCP23017_OUTPUT,
                    "pin $pin is now in OUTPUT ok";

                $o->write($pin, HIGH);
                is $o->read($pin), HIGH, "pin $pin is HIGH ok";
                $o->write($pin, LOW);
                is $o->read($pin), LOW, "pin $pin is LOW ok";
            }

            is
                $o->register($reg, 0xFF),
                0xFF,
                "pins in bank $reg back to INPUT ok";
        }
    }

    { # bad params

        is eval { $o->write(5); 1; }, undef, "fails on no state param";
        is eval { $o->write(5, 5); 1; }, undef, "fails on invalid state";
    }
}

sub test_bank_mode {

     { # set on bank A (0)

        $o->cleanup;

        is
            $o->register(MCP23017_IODIRA, 0xFF),
            0xFF,
            "IODIR pins in bank A are INPUT ok";

        is
            $o->register(MCP23017_IODIRB, 0xFF),
            0xFF,
            "IODIR pins in bank B are INPUT ok";

        $o->mode_bank(BANK_A, MCP23017_OUTPUT);
        is $o->register(MCP23017_IODIRA), 0x00, "pins in bank 0 are OUTPUT ok";

        $o->mode_bank(BANK_B, MCP23017_INPUT);
        is $o->register(MCP23017_IODIRB), 0xFF, "pins in bank 1 are INPUT ok";

        for (0..7){
            # Loopback wired per datasheet 1-28,2-27,..,8-21: A(n) <-> B(7-n),
            # so bank A pin $_ pairs with bank B pin (15 - $_)
            my ($pin_a, $pin_b) = ($_, 15 - $_);

            # B7 (pin 15) is output-only on the MCP23017; skip reading it
            next if $pin_b == 15;

            $o->write($pin_a, HIGH);
            is
                $o->read($pin_b),
                HIGH,
                "reading bank A pin $pin_a from bank B $pin_b is HIGH ok";

            $o->write($pin_a, LOW);
            is
                $o->read($pin_b),
                LOW,
                "reading bank A pin $pin_a from bank B $pin_b is LOW ok";
        }
    }

    { # set on bank B (1)
        $o->cleanup;

        is
            $o->register(MCP23017_IODIRA, 0xFF),
            0xFF,
            "IODIR pins in bank A are INPUT ok";

        is
            $o->register(MCP23017_IODIRB, 0xFF),
            0xFF,
            "IODIR pins in bank B are INPUT ok";

        $o->mode_bank(BANK_B, MCP23017_OUTPUT);
        is $o->register(MCP23017_IODIRB), 0x00, "pins in bank 1(B) are OUTPUT ok";

        $o->mode_bank(BANK_A, MCP23017_INPUT);
        is $o->register(MCP23017_IODIRA), 0xFF, "pins in bank 0(A) are INPUT ok";

        for (0..7){
            # Loopback wired per datasheet 1-28,2-27,..,8-21: A(n) <-> B(7-n),
            # so bank A pin $_ pairs with bank B pin (15 - $_)
            my ($pin_a, $pin_b) = ($_, 15 - $_);

            # A7 (pin 7) is output-only on the MCP23017; skip reading it
            next if $pin_a == 7;

            $o->write($pin_b, HIGH);
            is
                $o->read($pin_a),
                HIGH,
                "reading bank B pin $pin_b from bank A $pin_a is HIGH ok";

            $o->write($pin_b, LOW);
            is
                $o->read($pin_a),
                LOW,
                "reading bank B pin $pin_b from bank A $pin_a is LOW ok";
        }

        $o->cleanup;
    }

    { # bad params

        is eval { $o->mode_bank(5); 1; }, undef, "fails on invalid bank";
        is eval { $o->mode_bank(BANK_A, 5); 1; }, undef, "fails on invalid state";

    }
    { # return if no state sent

        is $o->mode_bank(BANK_A), 0xFF, "returns bank register if no state sent";
    }

}

sub test_bank_write {

     $o->cleanup;

    { # 0 OUTPUT/HIGH, 1 INPUT/read
        is
            $o->register(MCP23017_IODIRA, 0xFF),
            0xFF,
            "IODIR pins in bank A are INPUT ok";

        is
            $o->register(MCP23017_IODIRB, 0xFF),
            0xFF,
            "IODIR pins in bank B are INPUT ok";

        $o->mode_bank(BANK_A, MCP23017_OUTPUT);

        is
            $o->register(MCP23017_IODIRA, MCP23017_OUTPUT),
            MCP23017_OUTPUT,
            "pins in bank 0 are OUTPUT ok";

        $o->mode_bank(BANK_B, MCP23017_INPUT);

        is
            $o->register(MCP23017_IODIRB),
            0xFF,
            "pins in bank 1 are INPUT ok";

        $o->write_bank(BANK_A, HIGH);

        is $o->register(MCP23017_GPIOA), 0xFF, "pins in bank 0 are HIGH ok";

        for (0..7){
            # Loopback wired per datasheet 1-28,2-27,..,8-21: A(n) <-> B(7-n),
            # so bank A pin $_ pairs with bank B pin (15 - $_)
            my ($pin_a, $pin_b) = ($_, 15 - $_);

            # B7 (pin 15) is output-only on the MCP23017; skip reading it
            next if $pin_b == 15;

            is
                $o->read($pin_b),
                HIGH,
                "reading bank A pin $pin_a from bank B $pin_b is HIGH ok";
        }

        $o->write_bank(BANK_A, LOW);
        is $o->register(MCP23017_GPIOA), LOW, "pins in bank 0 are LOW ok";

        for (0..7){
            # Loopback wired per datasheet 1-28,2-27,..,8-21: A(n) <-> B(7-n),
            # so bank A pin $_ pairs with bank B pin (15 - $_)
            my ($pin_a, $pin_b) = ($_, 15 - $_);

            # B7 (pin 15) is output-only on the MCP23017; skip reading it
            next if $pin_b == 15;

            is
                $o->read($pin_b),
                LOW,
                "reading bank A pin $pin_a from bank B $pin_b is LOW ok";
        }
    }

    { # 0 INPUT/read, 1 OUTPUT/HIGH

        $o->cleanup;

        is
            $o->register(MCP23017_IODIRA, 0xFF),
            0xFF,
            "IODIR pins in bank A are INPUT ok";

        is
            $o->register(MCP23017_IODIRB, 0xFF),
            0xFF,
            "IODIR pins in bank B are INPUT ok";

        $o->mode_bank(BANK_B, MCP23017_OUTPUT);
        is $o->register(MCP23017_IODIRB), 0, "pins in bank 1(B) are OUTPUT ok";

        $o->mode_bank(BANK_A, MCP23017_INPUT);
        is $o->register(MCP23017_IODIRA), 0xFF, "pins in bank 0(A) are INPUT ok";

        $o->write_bank(BANK_B, HIGH);
        is $o->register(MCP23017_GPIOB), 255, "pins in bank 1(B) are HIGH ok";

        for (0..7){
            # Loopback wired per datasheet 1-28,2-27,..,8-21: A(n) <-> B(7-n),
            # so bank A pin $_ pairs with bank B pin (15 - $_)
            my ($pin_a, $pin_b) = ($_, 15 - $_);

            # A7 (pin 7) is output-only on the MCP23017; skip reading it
            next if $pin_a == 7;

            is
                $o->read($pin_a),
                HIGH,
                "reading bank B pin $pin_b from bank A $pin_a is HIGH ok";
        }

        $o->write_bank(BANK_B, LOW);
        is $o->register(MCP23017_GPIOB), 0, "pins in bank 1 are LOW ok";

        for (0..7){
            # Loopback wired per datasheet 1-28,2-27,..,8-21: A(n) <-> B(7-n),
            # so bank A pin $_ pairs with bank B pin (15 - $_)
            my ($pin_a, $pin_b) = ($_, 15 - $_);

            # A7 (pin 7) is output-only on the MCP23017; skip reading it
            next if $pin_a == 7;

            is
                $o->read($pin_a),
                LOW,
                "reading bank B pin $pin_b from bank A $pin_a is LOW ok";
        }

        $o->cleanup;
    }

    { # bad params

        is eval { $o->write_bank(5); 1; }, undef, "fails on invalid bank";
        is eval { $o->write_bank(BANK_B); 1; }, undef, "fails on missing state";
        is
            eval { $o->write_bank(BANK_A, 5); 1; },
            undef,
            "fails on invalid state";

    }
}

sub test_pullup {

     for my $reg (MCP23017_GPPUA .. MCP23017_GPPUB){
        is $o->register($reg, 0x00), 0x00, "pullups in bank $reg are off ok";

        if ($reg == MCP23017_GPPUA){
            for my $pin (0 .. 7) {
                $o->pullup($pin, HIGH);
                is
                    $o->register_bit($reg, $pin),
                    HIGH,
                    "pin $pin pullup is now on";

                $o->pullup($pin, LOW);
                is
                    $o->register_bit($reg, $pin),
                    LOW,
                    "pin $pin pullup is now off";
            }
            is $o->register($reg, 0x00), 0x00, "pullups in bank $reg to off ok";
        }


        if ($reg == MCP23017_GPPUB){
            for my $pin (8..15) {
                $o->pullup($pin, HIGH);
                is
                    $o->register_bit($reg, $pin),
                    HIGH,
                    "$pin pullup is now on ok";

                $o->pullup($pin, LOW);
                is
                    $o->register_bit($reg, $pin),
                    LOW,
                    "pin $pin pullup is now off";
            }
            is $o->register($reg, 0x00), 0x00, "pullups in bank $reg to off ok";
        }
    }

    { # get

        $o->cleanup;

        for (0..15){
            is $o->pullup($_), LOW, "pin $_ pullup off ok";

            $o->pullup($_, HIGH);
            is $o->pullup($_), HIGH, "pin $_ pullup on ok";

            $o->pullup($_, LOW);
            is $o->pullup($_), LOW, "pin $_ pullup back to off ok";
        }

        $o->cleanup;
    }

    { # bad params

        is eval { $o->mode_bank(5); 1; }, undef, "fails on invalid bank";
        is eval { $o->mode_bank(BANK_A, 5); 1; }, undef, "fails on invalid state";

    }
    { # return if no state sent

        is $o->mode_bank(BANK_A), 0xFF, "returns bank register if no state sent";
    }

}

sub test_pullup_bank {

     for my $reg (MCP23017_GPPUA .. MCP23017_GPPUB){
        is $o->register($reg, 0x00), 0x00, "pullups in bank $reg are off ok";

        if ($reg == MCP23017_GPPUA){
            for (0x00..0xFF){
                is $o->register($reg, $_), $_, "bank A pullup register set to $_";
            }
            is $o->register($reg, 0x00), 0x00, "pullups in bank $reg to off ok";
        }

        if ($reg == MCP23017_GPPUB){
            for (0x00..0xFF){
                is $o->register($reg, $_), $_, "bank B pullup register set to $_";
            }
            is $o->register($reg, 0x00), 0x00, "pullups in bank $reg to off ok";
        }
    }

    { # bad params

        is eval { $o->pullup_bank(5); 1; }, undef, "fails on invalid bank";
        is eval { $o->pullup_bank(BANK_A, 5); 1; }, undef, "fails on invalid state";

    }
    { # return if no state sent

        is $o->mode_bank(BANK_A), 0xFF, "returns bank register if no state sent";
    }
}

sub test_mode_all {

    my @regs = (MCP23017_IODIRA .. MCP23017_IODIRB);

    { # set/unset
        for (@regs){
            is $o->register($_), 0xFF, "register $_ set to 0xFF ok";
        }

        $o->mode_all(MCP23017_OUTPUT);

        for (@regs){
            is $o->register($_), 0x00, "register $_ set to 0x00 ok";
        }

        $o->mode_all(MCP23017_INPUT);

        for (@regs){
            is $o->register($_), 0xFF, "register $_ set back to default 0xFF ok";
        }
    }

    { # bad params
        is eval { $o->mode_all(5); 1; }, undef, "fails on invalid mode";
    }
}

sub test_write_all {

     my @regs = (MCP23017_GPIOA .. MCP23017_GPIOB);

    { # set/unset

        $o->mode_all(MCP23017_OUTPUT);
        for (MCP23017_IODIRA .. MCP23017_IODIRB){
            is $o->register($_), 0x00, "IODIR register $_ set to OUTPUT ok";
        }

        $o->write_all(HIGH);

        for (@regs){
            is $o->register($_), 0xFF, "register $_ set to 0xFF (all HIGH) ok";
        }

        $o->write_all(LOW);

        for (@regs){
            is $o->register($_), 0x00, "register $_ set to 0x00 (all LOW) ok";
        }

        $o->mode_all(MCP23017_INPUT);
        for (MCP23017_IODIRA .. MCP23017_IODIRB){
            is $o->register($_), 0xFF, "IODIR register $_ set back to INPUT ok";
        }
    }

    { # bad params
        is eval { $o->write_all(5); 1; }, undef, "fails on invalid state";
    }
}

sub test_pullup_all {
    my @regs = (MCP23017_GPPUA .. MCP23017_GPPUB);

    { # set/unset

        $o->mode_all(MCP23017_OUTPUT);
        for (MCP23017_IODIRA .. MCP23017_IODIRB){
            is $o->register($_), 0x00, "IODIR register $_ set to OUTPUT ok";
        }

        $o->pullup_all(HIGH);

        for (@regs){
            is $o->register($_), 0xFF, "register $_ set to 0xFF (all HIGH) ok";
        }

        $o->pullup_all(LOW);

        for (@regs){
            is $o->register($_), 0x00, "register $_ set to 0x00 (all LOW) ok";
        }

        $o->mode_all(MCP23017_INPUT);
        for (MCP23017_IODIRA .. MCP23017_IODIRB){
            is $o->register($_), 0xFF, "IODIR register $_ set back to INPUT ok";
        }
    }

    { # bad params
        is eval { $o->pullup_all(5); 1; }, undef, "fails on invalid state";
    }
}

sub test_named_pins {

    # Wired loopback per datasheet 1-28,2-27,..,8-21: A(n) <-> B(7-n),
    # i.e. A0<->B7, A1<->B6, .. A7<->B0
    my @pairs = (
        [A0, B7],
        [A1, B6],
        [A2, B5],
        [A3, B4],
        [A4, B3],
        [A5, B2],
        [A6, B1],
        [A7, B0],
    );

    { # bank A OUTPUT, bank B INPUT: drive the A pin, read its B partner

        $o->cleanup;
        $o->mode_bank(BANK_A, MCP23017_OUTPUT);
        $o->mode_bank(BANK_B, MCP23017_INPUT);

        for my $pair (@pairs) {
            my ($pin_a, $pin_b) = @$pair;

            # B7 (pin 15) is output-only on the MCP23017; skip reading it
            next if $pin_b == B7;

            $o->write($pin_a, HIGH);
            is
                $o->read($pin_b),
                HIGH,
                "A/B constants: A pin $pin_a HIGH read on B pin $pin_b ok";

            $o->write($pin_a, LOW);
            is
                $o->read($pin_b),
                LOW,
                "A/B constants: A pin $pin_a LOW read on B pin $pin_b ok";
        }
    }

    { # bank B OUTPUT, bank A INPUT: drive the B pin, read its A partner

        $o->cleanup;
        $o->mode_bank(BANK_B, MCP23017_OUTPUT);
        $o->mode_bank(BANK_A, MCP23017_INPUT);

        for my $pair (@pairs) {
            my ($pin_a, $pin_b) = @$pair;

            # A7 (pin 7) is output-only on the MCP23017; skip reading it
            next if $pin_a == A7;

            $o->write($pin_b, HIGH);
            is
                $o->read($pin_a),
                HIGH,
                "A/B constants: B pin $pin_b HIGH read on A pin $pin_a ok";

            $o->write($pin_b, LOW);
            is
                $o->read($pin_a),
                LOW,
                "A/B constants: B pin $pin_b LOW read on A pin $pin_a ok";
        }

        $o->cleanup;
    }
}

sub test_default_registers {

    # The live-state registers below are excluded from the "back to default"
    # check. cleanup() cannot drive them to 0x00 on a board with real wiring:
    #   GPIOA/GPIOB (0x12/0x13) mirror live pin levels, so floating loopback
    #     inputs read as noise rather than 0x00.
    #   INTCAPA/INTCAPB (0x10/0x11) are read-only interrupt-capture latches.
    #     cleanup() skips them (they cannot be written), so a capture triggered
    #     by the earlier register write tests stays frozen until the next
    #     interrupt-on-change event.

    my %live_state = (
        MCP23017_GPIOA()   => 1,
        MCP23017_GPIOB()   => 1,
        MCP23017_INTCAPA() => 1,
        MCP23017_INTCAPB() => 1,
    );

    # Poll (bounded ~6s) until the controllable registers reset after the
    # pullup toggling above, instead of a fixed sleep; the per-register
    # assertions below still run in full

    for (1 .. 60){
        my $settled = 1;

        for my $reg (0x00 .. 0x15){
            next if $live_state{$reg};

            my $want =
                ($reg == MCP23017_IODIRA || $reg == MCP23017_IODIRB)
                ? 0xFF
                : 0x00;

            if ($o->register($reg) != $want){
                $settled = 0;
                last;
            }
        }

        last if $settled;
        select(undef, undef, undef, 0.1);
    }

    for (0x00..0x15){
        next if $live_state{$_};

        if ($_ == MCP23017_IODIRA || $_ == MCP23017_IODIRB){
            is $o->register($_), 0xFF, "register $_ back to 0xFF ok";
        }
        else {
            is $o->register($_), 0x00, "register $_ back to 0x00 ok";
        }
    }
}
