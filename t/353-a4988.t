# TESTDOC: A4988 stepper driver (live GPIO readback)
use warnings;
use strict;

use lib 't/';

# Convenience: RPI_A4988=1 flips on the board + sudo gates this file needs, so
# you don't export each by hand. Runs in BEGIN so it lands before RPiTest's
# compile-time RPI_BOARD skip_all gate.
BEGIN {
    if ($ENV{RPI_A4988}){
        $ENV{$_} = 1 for qw(RPI_BOARD RPI_SUDO);
    }
}

use RPiTest;
use RPi::WiringPi;
use RPi::Const qw(:all);
use Test::More;

# ===========================================================================
# t/353-a4988.t - RPi::StepperMotor::A4988 live-GPIO integration test
# ===========================================================================
#
# WHAT THIS PROVES
#
#   The driver manipulates REAL GPIO the way its HW-free unit test
#   (t/354-a4988_unit.t) only proves against mocks. A stepper is open-loop with
#   no feedback wire, so we verify what we CAN observe: every steady-state
#   control line (DIR, MS1-3, ENABLE, SLEEP, RESET) reaches the level the module
#   drives it to, read back through the module's own live RPi::Pin object; the
#   degree/step math returns the right microstep counts; and a real rotation
#   runs end to end without croaking. STEP itself pulses too fast (2 us) to
#   sample by polling, so we assert only that it idles low between and after
#   motion.
#
# WIRING (bench; NOT tied to a test-platform board)
#
#   Wire each A4988 logic input to the BCM GPIO below (override any via env),
#   and power the board (VDD 3-5 V; VMOT 8-35 V with a bulk cap). A motor is
#   optional - with none attached the readbacks still pass; attach one to watch
#   it turn.
#
#     STEP -> GPIO23   ENABLE -> GPIO5    (ENABLE/SLEEP/RESET are active low)
#     DIR  -> GPIO24   SLEEP  -> GPIO6
#     MS1  -> GPIO17   RESET  -> GPIO13
#     MS2  -> GPIO27
#     MS3  -> GPIO22
#
# GATE
#
#   RPI_A4988 - the A4988 is wired and powered. Needs a Pi (RPI_BOARD) and root
#   (RPI_SUDO / sudo) for GPIO. Skips cleanly when unset.
#
# ===========================================================================

rpi_sudo_check();

if ($> == 0){
    # Under the sudo re-exec below, sudo strips RPI_A4988 from the environment;
    # restore the gate (running as root is itself the intent to run) so the
    # checks that follow don't wrongly skip.
    $ENV{RPI_A4988} = 1;
    $ENV{RPI_BOARD} = 1;
}

if (! $ENV{RPI_A4988}){
    plan skip_all => "RPI_A4988 environment variable not set\n";
}

if (! $ENV{RPI_BOARD}){
    plan skip_all => "RPI_BOARD environment variable not set\n";
}

if ($> != 0){
    print "enforcing sudo for live GPIO tests...\n";
    # Re-exec with $^X (the running perl) so sudo doesn't fall back to the
    # system perl, which lacks our perlbrew-installed prerequisites
    system("sudo", $^X, "-I", "blib/lib", "-I", "lib", $0);
    exit;
}

# Loaded at runtime, after the gates: the module is an as-yet-unreleased family
# leaf, so a checkout without it installed still parses and skips this file
# rather than dying at compile time
if (! eval { require RPi::StepperMotor::A4988; 1 }){
    plan skip_all => "RPi::StepperMotor::A4988 not installed\n";
}

rpi_running_test(__FILE__);

# Pin map (BCM), each overridable so the bench wiring can move without an edit
my %pin = (
    step   => $ENV{RPI_A4988_STEP}   // 23,
    dir    => $ENV{RPI_A4988_DIR}    // 24,
    ms1    => $ENV{RPI_A4988_MS1}    // 17,
    ms2    => $ENV{RPI_A4988_MS2}    // 27,
    ms3    => $ENV{RPI_A4988_MS3}    // 22,
    enable => $ENV{RPI_A4988_ENABLE} // 5,
    sleep  => $ENV{RPI_A4988_SLEEP}  // 6,
    reset  => $ENV{RPI_A4988_RESET}  // 13,
);

my $pi = RPi::WiringPi->new(label => 't/353-a4988.t', shm_key => 'rpit');

my $motor;
my $cleaned = 0;

my $cleanup = sub {
    return if $cleaned;
    $cleaned = 1;
    $motor->cleanup if $motor;
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
    $motor = RPi::StepperMotor::A4988->new(
        pi     => $pi,
        step   => $pin{step},
        dir    => $pin{dir},
        ms1    => $pin{ms1},
        ms2    => $pin{ms2},
        ms3    => $pin{ms3},
        enable => $pin{enable},
        sleep  => $pin{sleep},
        reset  => $pin{reset},
        rpm    => 120,
    );

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

    1;
};

my $err = $@;

$cleanup->();

if (! $ok){
    fail("A4988 live test died before completion: $err");
}

done_testing();

# level($role) - read back the current level of one of the motor's own live
# pins (the same RPi::Pin object the module drives), so we don't register the
# GPIO a second time in the shared meta and corrupt the pin counts.

sub level {
    my ($role) = @_;
    return $motor->{pin}{$role}->read;
}
