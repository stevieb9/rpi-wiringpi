# TESTDOC: A4988 stepper driver (live, through an MCP23017 expander)
use warnings;
use strict;

use lib 't/';

# Convenience: RPI_A4988=1 flips on the board + expander gates this file needs,
# so you don't export each by hand. Runs in BEGIN so it lands before RPiTest's
# compile-time RPI_BOARD skip_all gate.
BEGIN {
    if ($ENV{RPI_A4988}){
        $ENV{$_} = 1 for qw(RPI_BOARD RPI_MCP23017);
    }
}

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

# ===========================================================================
# t/353-a4988.t - RPi::StepperMotor::A4988 live integration, driven from an
#                 MCP23017 I2C expander via $pi->stepper_motor(model => 'A4988')
# ===========================================================================
#
# WHAT THIS PROVES
#
#   The A4988 driver, reached through RPi::WiringPi's stepper_motor() model
#   dispatch and driven from an MCP23017 expander, manipulates REAL expander
#   pins the way its HW-free unit test (t/354-a4988_unit.t) only proves against
#   a mock. A stepper is open-loop with no feedback wire, so we verify what we
#   CAN observe: every steady-state control line (DIR, MS1-3, ENABLE, SLEEP,
#   RESET) reaches the level the module drives it to, READ BACK through the same
#   expander; the degree/step math returns the right microstep counts; and real
#   rotations run end to end without croaking. STEP itself pulses too fast (2 us)
#   to sample by polling, so we assert only that it idles low between and after
#   motion.
#
# WIRING (bench; NOT tied to a test-platform board)
#
#   An MCP23017 at RPI_A4988_ADDR (default 0x22) drives the A4988's logic
#   inputs from its BANK A pins. Power the A4988 (VDD 3-5 V; VMOT 8-35 V with a
#   bulk cap). A motor is optional - with none attached the readbacks still
#   pass; attach one to watch it turn.
#
#     expander 0 -> STEP     expander 5 -> ENABLE   (ENABLE/SLEEP/RESET
#     expander 1 -> DIR      expander 6 -> SLEEP     are active low)
#     expander 2 -> MS1      expander 7 -> RESET
#     expander 3 -> MS2
#     expander 4 -> MS3
#
#   Every pin is overridable via env (RPI_A4988_STEP, ..._DIR, ..._MS1, etc.)
#   so the bench wiring can move without an edit.
#
# GATE
#
#   RPI_A4988      - the A4988 is wired to the expander and powered.
#   RPI_MCP23017   - the expander is present on I2C (enabled by RPI_A4988).
#   Skips cleanly when unset, or when the installed driver predates the
#   expander interface.
#
# ===========================================================================

if (! $ENV{RPI_A4988}){
    plan skip_all => "RPI_A4988 environment variable not set\n";
}

if (! $ENV{RPI_MCP23017}){
    plan skip_all => "RPI_MCP23017 environment variable not set\n";
}

# Loaded at runtime, after the gates: the module is an as-yet-unreleased family
# leaf, so a checkout without it installed still parses and skips rather than
# dying at compile time.
if (! eval { require RPi::StepperMotor::A4988; 1 }){
    plan skip_all => "RPi::StepperMotor::A4988 not installed\n";
}

# The redesigned (expander) build dropped the pi() accessor its earlier
# injected-transport version carried; skip cleanly on the older build.
if (RPi::StepperMotor::A4988->can('pi')){
    plan skip_all => "installed RPi::StepperMotor::A4988 predates the expander interface\n";
}

rpi_running_test(__FILE__);

# Expander pin map (bank A), each overridable so the bench wiring can move
my %pin = (
    step   => $ENV{RPI_A4988_STEP}   // 0,
    dir    => $ENV{RPI_A4988_DIR}    // 1,
    ms1    => $ENV{RPI_A4988_MS1}    // 2,
    ms2    => $ENV{RPI_A4988_MS2}    // 3,
    ms3    => $ENV{RPI_A4988_MS3}    // 4,
    enable => $ENV{RPI_A4988_ENABLE} // 5,
    sleep  => $ENV{RPI_A4988_SLEEP}  // 6,
    reset  => $ENV{RPI_A4988_RESET}  // 7,
);

my $addr = $ENV{RPI_A4988_ADDR} // 0x22;

my $pi  = RPi::WiringPi->new(label => 't/353-a4988.t', shm_key => 'rpit');
my $exp = $pi->expander($addr);

my $motor;
my $cleaned = 0;

my $cleanup = sub {
    return if $cleaned;
    $cleaned = 1;
    $motor->cleanup if $motor;
    $exp->cleanup;
    $pi->cleanup;
};

local $SIG{INT}  = sub { $cleanup->(); exit 1; };
local $SIG{TERM} = sub { $cleanup->(); exit 1; };

my %ms_levels = (
    full      => [LOW,  LOW,  LOW ],
    half      => [HIGH, LOW,  LOW ],
    quarter   => [LOW,  HIGH, LOW ],
    eighth    => [HIGH, HIGH, LOW ],
    sixteenth => [HIGH, HIGH, HIGH],
);

my $ok = eval {
    # Build through the RPi::WiringPi facade's model dispatch, on the expander
    $motor = $pi->stepper_motor(
        model    => 'A4988',
        expander => $exp,
        step     => $pin{step},
        dir      => $pin{dir},
        ms1      => $pin{ms1},
        ms2      => $pin{ms2},
        ms3      => $pin{ms3},
        enable   => $pin{enable},
        sleep    => $pin{sleep},
        reset    => $pin{reset},
        rpm      => 120,
    );

    isa_ok $motor, 'RPi::StepperMotor::A4988',
        "stepper_motor(model => 'A4988') returns an A4988 driver";

    # new() brings every line up at its documented safe idle level
    is level('dir'),    HIGH, "new() leaves DIR high (default cw)";
    is level('reset'),  HIGH, "new() leaves RESET high (out of reset)";
    is level('sleep'),  HIGH, "new() leaves SLEEP high (awake)";
    is level('enable'), LOW,  "new() leaves ENABLE low (outputs on)";
    is level('step'),   LOW,  "new() leaves STEP low (idle)";
    is_deeply [map { level($_) } qw(ms1 ms2 ms3)], [LOW, LOW, LOW],
        "new() defaults to full step (MS1/MS2/MS3 low)";

    # direction() drives DIR both ways
    $motor->direction('ccw');
    is level('dir'), LOW, "direction('ccw') drives DIR low";
    $motor->direction('cw');
    is level('dir'), HIGH, "direction('cw') drives DIR high";

    # mode() drives the MS pins to the datasheet Table 1 levels
    for my $res (qw(full half quarter eighth sixteenth)){
        $motor->mode($res);
        is_deeply [map { level($_) } qw(ms1 ms2 ms3)], $ms_levels{$res},
            "mode('$res') drives MS1/MS2/MS3 to the datasheet levels";
    }

    $motor->mode('full');

    # Power pins, all active low
    $motor->disable;
    is level('enable'), HIGH, "disable() drives ENABLE high";
    $motor->enable;
    is level('enable'), LOW, "enable() drives ENABLE low";

    $motor->sleep;
    is level('sleep'), LOW, "sleep() drives SLEEP low";
    $motor->wake;
    is level('sleep'), HIGH, "wake() drives SLEEP high";

    $motor->reset;
    is level('reset'), HIGH, "reset() leaves RESET high after its low pulse";

    # Motion: exact counts, a real rotation on live silicon, STEP idles low
    is $motor->cw(360), 200, "cw(360) returns 200 microsteps at full step";
    is level('step'), LOW, "STEP idles low after a rotation";
    is $motor->ccw(180), 100, "ccw(180) returns 100 microsteps";
    is $motor->step(0), 0, "step(0) is a no-op";

    # Finer resolution scales the count, not the angle
    $motor->mode('sixteenth');
    is $motor->cw(18), 160, "cw(18) is 160 microsteps in sixteenth step";
    is level('step'), LOW, "STEP still idles low";

    # cleanup() is a no-op with an expander: the expander owns its own pins
    is $motor->cleanup, 0, "cleanup() returns 0 and leaves the expander pins alone";

    1;
};

my $err = $@;

$cleanup->();

if (! $ok){
    fail("A4988 live test died before completion: $err");
}

done_testing();

# level($role) - read the current level of one of the A4988's control lines
# back through the expander it's driven from.

sub level {
    my ($role) = @_;
    return $exp->read($pin{$role});
}
