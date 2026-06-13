# Interrupts in RPi::WiringPi — usage examples

> **The #1 gotcha:** as of `WiringPi::API` 3.18 a callback does **not** auto-fire.
> It runs in *your* interpreter only when you service dispatch. So after arming a
> pin you must drive dispatch (a loop, or `auto_dispatch_interrupts`, or a
> background process). The callback **must be a code reference** — string sub
> names are no longer accepted. None of these examples need `use threads`.

Interrupts are **armed on a pin** and **driven from the Pi object**:

- **Arm** on a pin object: `$pin->set_interrupt(...)` or
  `$pin->background_interrupt(...)` (see [RPi::Pin](https://metacpan.org/pod/RPi::Pin)).
- **Drive and control** dispatch on the Pi object `$pi`: `wait_interrupts`,
  `run_interrupt_loop`, `dispatch_interrupts`, `auto_dispatch_interrupts`,
  `stop_interrupts`, `last_interrupt`, `interrupt_buffer`, `interrupt_dropped`,
  `background_interrupts`.

The split is deliberate: arming concerns a single pin, but the dispatch queue
and signal wiring are **process-wide** (one shared event pipe), so those live on
`$pi`, not on individual pins.

## Table of contents

- [About these examples](#about-these-examples)
- [Decision guide](#decision-guide)
- [Reacting to interrupts](#reacting-to-interrupts)
  - [1. Cooperative dispatch in your main loop](#1-cooperative-dispatch-in-your-main-loop)
  - [2. Blocking wait loop](#2-blocking-wait-loop)
  - [3. Multiple pins and callbacks](#3-multiple-pins-and-callbacks)
  - [4. Edge types and debounce](#4-edge-types-and-debounce)
  - [5. Teardown and cleanup](#5-teardown-and-cleanup)
- [Hands-off handling (no dispatch loop)](#hands-off-handling-no-dispatch-loop)
  - [6. Fire with no loop (auto_dispatch_interrupts)](#6-fire-with-no-loop-auto_dispatch_interrupts)
  - [7. A background process (background_interrupt)](#7-a-background-process-background_interrupt)
  - [8. Many pins in one background child (background_interrupts)](#8-many-pins-in-one-background-child-background_interrupts)
- [Anti-patterns to avoid](#anti-patterns-to-avoid)
- [Method reference for these examples](#method-reference-for-these-examples)

## About these examples

- **Interrupts never require `use threads`.** wiringPi runs its own C threads
  internally and writes events to a pipe; your Perl reads that pipe. Hands-off
  handling uses an in-process signal (scenario 6) or a forked process
  (scenarios 7–8) — never threads.
- **Arm on `$pin`, drive on `$pi`.** Get a pin with `my $pin = $pi->pin($n)`,
  set its mode with `$pin->mode(INPUT)`, then arm it. Everything that touches the
  shared dispatch queue lives on `$pi`.
- **Callbacks receive `($edge, $timestamp_us)`** — the edge that fired
  (`EDGE_FALLING`=1 / `EDGE_RISING`=2 / `EDGE_BOTH`=3) and a microsecond
  timestamp.
- **The callback must be a code reference** (`sub { ... }` or `\&handler`) — string
  sub names are no longer accepted.
- **Edge and mode constants** come from `RPi::Const qw(:all)` — `EDGE_RISING`,
  `EDGE_FALLING`, `EDGE_BOTH`, and `INPUT`. Used by name throughout (no bare
  `1`/`2`/`3`).
- **To hide the most work, prefer the hands-off options.**
  `auto_dispatch_interrupts` (scenario 6) fires callbacks in your own process
  with no loop; `background_interrupts` (scenario 8) runs handlers in their own
  process. Sections 1–5 (cooperative) explain the explicit dispatch model that 6
  and 8 hide — read them to understand what happens under the hands-off calls,
  but **most programs only need 6 or 8.**
- For **running** background work (not reacting to edges), see `$pi->worker` in
  [threads-examples.md](threads-examples.md).

## Decision guide

None of these need `use threads`. To hide the most plumbing, prefer the first two
(hands-off) rows.

> **6 vs 7/8 in one line:** `auto_dispatch_interrupts` (6) gives you lock-free
> shared state but *defers* during a long non-yielding C call;
> `background_interrupt(s)` (7/8) fire regardless of what main is doing but
> **can't touch main's variables**. No long C calls? Pick 6. Long C calls? Pick
> 7/8.

| What you want | Scenario |
|---|---|
| Attach a handler and forget it; it updates my program's state | [6](#6-fire-with-no-loop-auto_dispatch_interrupts) (`auto_dispatch_interrupts`) |
| Independent handler that fires even during long/blocking work | [7](#7-a-background-process-background_interrupt) (`background_interrupt`) |
| The same, but several pins in one background process | [8](#8-many-pins-in-one-background-child-background_interrupts) (`background_interrupts`) |
| React to a pin while running my own loop, on my terms | [1](#1-cooperative-dispatch-in-your-main-loop) |
| A program whose only job is reacting to pins | [2](#2-blocking-wait-loop) |
| Several pins, each with its own handler | [3](#3-multiple-pins-and-callbacks) |
| Specific edges / debounce a noisy input | [4](#4-edge-types-and-debounce) |
| Tear down or clean up on exit | [5](#5-teardown-and-cleanup) |

---

## Reacting to interrupts

### 1. Cooperative dispatch in your main loop

**Why/when:** You already have a main loop and want to control exactly when
callbacks run. Simplest model, works on any Perl — but a callback only fires when
you call `$pi->dispatch_interrupts`, so keep the loop snappy. (Want it fully
hands-off? See scenario 6.)

**Real-world:** A rover whose main loop steers and reads sensors every tick, while
a front bumper microswitch triggers an obstacle-avoidance routine — serviced once
per loop pass.

**Main & interrupt:** One thread. The callback runs *inside*
`$pi->dispatch_interrupts`, so it can read/write any of main's variables with no
locking — but it only fires when main calls dispatch, and it blocks main while it
runs.

Do your own work, and fire any pending interrupt callbacks each pass.

```perl
use strict;
use warnings;
use RPi::WiringPi;
use RPi::Const qw(:all);

my $pi  = RPi::WiringPi->new;
my $pin = $pi->pin(18);
$pin->mode(INPUT);

$pin->set_interrupt(EDGE_RISING, sub {
    my ($edge, $ts_us) = @_;
    print "pin 18 rising at ${ts_us}us\n";
});

while (1) {
    do_other_work();
    $pi->dispatch_interrupts;   # non-blocking: runs callbacks for any events that arrived
}

sub do_other_work {
    # ... your periodic work ...
}
```

Tradeoff: if `do_other_work()` blocks for a long time, callbacks wait until the
next `dispatch_interrupts`. Conversely, if `do_other_work()` returns instantly
with nothing to do, this loop **busy-spins at 100% CPU** — pace it with real
periodic work, a short `sleep`, or block in `wait_interrupts` instead (scenario 2).

### 2. Blocking wait loop

**Why/when:** Reacting to pins *is* the whole job — there's no other work to do.
The process sleeps efficiently until an edge arrives.

**Real-world:** A doorbell or panic button — the Pi idles at near-zero CPU until
the button fires, then sends a notification.

**Main & interrupt:** One thread. Main is blocked in `wait_interrupts` until an
edge, then runs the callback inline (full access to program state). Main does no
other work while it waits.

When reacting to pins *is* the program. `wait_interrupts` blocks until an event
arrives (or the timeout in ms), then dispatches.

```perl
use strict;
use warnings;
use RPi::WiringPi;
use RPi::Const qw(:all);

my $pi  = RPi::WiringPi->new;
my $pin = $pi->pin(18);
$pin->mode(INPUT);

$pin->set_interrupt(EDGE_BOTH, \&on_change);

while (1) {
    $pi->wait_interrupts(1000);  # block up to 1000ms, dispatch whatever fired
}

sub on_change {
    my ($edge, $ts_us) = @_;
    print "edge $edge at ${ts_us}us\n";
}
```

**Shortcut.** If the loop is literally just `wait_interrupts while 1`, call the
built-in helper instead of writing it yourself:

```perl
$pi->run_interrupt_loop(1000);        # blocks, dispatching, forever
$pi->run_interrupt_loop(1000, 50);    # ... or until 50 events have fired
```

It returns the number of events dispatched and stops when
`$pi->stop_interrupt_loop` is called (from inside a callback, or a signal
handler) or after the optional event cap. When nothing is armed it sleeps the
poll interval instead of busy-spinning.

### 3. Multiple pins and callbacks

**Why/when:** Several inputs, each with its own handler, serviced by one loop.
(Same mechanics as 1–2; this just shows the fan-out.)

**Real-world:** A control panel with Start/Stop/Up/Down buttons, each wired to its
own handler.

**Main & interrupt:** Still one servicing thread — callbacks run one at a time with
full access to main's state; no callback runs concurrently with another or with
main.

One pipe, one loop, many pins — each with its own callback.

```perl
use strict;
use warnings;
use RPi::WiringPi;
use RPi::Const qw(:all);

my $pi = RPi::WiringPi->new;

my %pin;
$pin{$_} = $pi->pin($_) for (18, 23, 24);
$pin{$_}->mode(INPUT)   for (18, 23, 24);

$pin{18}->set_interrupt(EDGE_RISING,  sub { print "button A\n" });
$pin{23}->set_interrupt(EDGE_FALLING, sub { print "button B\n" });
$pin{24}->set_interrupt(EDGE_BOTH,    \&sensor);

while (1) {
    $pi->wait_interrupts(1000);
}

sub sensor {
    my ($edge, $ts_us) = @_;
    print "sensor edge=$edge\n";
}
```

**One shared handler for several pins.** The callback only receives
`($edge, $ts_us)`, not the pin. If you arm the *same* coderef on multiple pins,
call `$pi->last_interrupt` inside it to recover which pin (and the BCM number)
fired:

```perl
my $cb = sub {
    my $i = $pi->last_interrupt;   # { pin, pin_bcm, edge, status, ts_us }
    printf "pin %d (BCM %d) edge %d\n", $i->{pin}, $i->{pin_bcm}, $i->{edge};
};
$pi->pin($_)->set_interrupt(EDGE_BOTH, $cb) for (18, 23, 24);
```

`last_interrupt` returns a hash reference describing the most recently dispatched
event (or `undef` if none yet); it is published *before* the callback runs, so
the callback can read it.

### 4. Edge types and debounce

**Why/when:** You care about a specific edge, or the input is electrically noisy
(a button) and you want the kernel to suppress bounce so the callback fires once
per press.

**Real-world:** Counting items on a conveyor with a microswitch (or reading a
rotary encoder) — debounce gives one event per actuation instead of a burst from
contact bounce.

**Main & interrupt:** Orthogonal to where the callback runs — debounce drops bounce
edges in the kernel before they're ever queued, so fewer events reach your
dispatch point.

Edge constants: `EDGE_FALLING`=1, `EDGE_RISING`=2, `EDGE_BOTH`=3. An optional
argument after the callback sets a **kernel debounce period** in
**microseconds** (default 0 = off). wiringPi applies it as a Linux **GPIO-v2
line attribute** at arm time, so the kernel drops bounce edges before they reach
the pipe — it is *not* a hardware debounce.

```perl
use strict;
use warnings;
use RPi::WiringPi;
use RPi::Const qw(:all);

my $pi  = RPi::WiringPi->new;
my $pin = $pi->pin(18);
$pin->mode(INPUT);

# Debounce a noisy button: ignore repeat edges within 5ms
$pin->set_interrupt(EDGE_FALLING, \&pressed, 5 * 1000);   # micros -> millis

$pi->wait_interrupts(1000) while 1;

sub pressed {
    print "clean press\n";
}
```

### 5. Teardown and cleanup

**Why/when:** You need to stop watching pins, swap a handler at runtime, or clean
up on exit.

**Real-world:** A handheld with a mode button — swap its handler when switching
screens, and release every line on shutdown.

**Main & interrupt:** Re-arm and stop run in main and edit the registration; after
a stop the callback can't fire, and re-arming swaps it cleanly (the old listener
is stopped first).

```perl
$pin->set_interrupt(EDGE_RISING, \&handler_a);

# Re-arm the same pin with a different handler — the old listener is stopped
# automatically first, so no stacked/duplicate registration
$pin->set_interrupt(EDGE_RISING, \&handler_b);

$pi->stop_interrupts;   # release every armed interrupt, drain + close the pipe
```

**Forking and cleanup.** `$pi->cleanup` (called automatically at object
destruction) resets pins **and** releases armed interrupts (it calls
`stop_interrupts` for you). It is **fork-aware**: in a forked child the call is a
no-op, so a child can't reset the parent's pins or tear down its interrupts on
exit.

```perl
$pin->set_interrupt(EDGE_RISING, \&handler);
# ... later ...
$pi->stop_interrupts;     # release every armed interrupt
$pi->cleanup;             # full teardown (also releases interrupts)
```

**Bursts and dropped edges.** Edges are FIFO-queued in a kernel pipe until you
dispatch them. If a fast source outruns your dispatching the queue fills, and the
**newest** edges are dropped — never merged, never blocked — and counted, so loss
is never silent:

```perl
my $lost = $pi->interrupt_dropped;   # 0 unless the pipe overflowed
```

If you expect bursts, enlarge the queue with `interrupt_buffer($bytes)` (it may
be set before arming and persists across teardown):

```perl
$pi->interrupt_buffer(1 << 20);      # ~1 MiB of queue; returns the granted size
my $size = $pi->interrupt_buffer;    # read the current capacity
```

The kernel rounds up to a page and caps at `/proc/sys/fs/pipe-max-size`. Other
mitigations: dispatch faster, use a background process (scenarios 7–8), or
debounce (scenario 4) to cut the edge rate.

---

## Hands-off handling (no dispatch loop)

### 6. Fire with no loop (auto_dispatch_interrupts)

**Why/when:** The most hands-off in-process option — "attach a handler and forget
it," closest to Arduino's `attachInterrupt`. The callback runs in *your* program
(it can read/update your variables, no locking) and fires on its own while your
code runs, with no dispatch loop. Best when a handler must touch your program's
state. Caveat: a long non-yielding C/XS call can delay it.

**Real-world:** A weather station counting anemometer/rain-gauge pulses into a
counter your main loop reads and uploads every few seconds — the handler updates
your in-program state directly.

**Main & interrupt:** The callback runs in **main's interpreter** at op boundaries
(and on interrupted sleeps), so it can read/write main's variables with **no
locking** — but a long non-yielding C call defers it until that call returns.

`auto_dispatch_interrupts(1)` wires the event pipe to a signal and installs the
handler for you, so `set_interrupt` callbacks fire **automatically, in your own
process**, with no `dispatch_interrupts`/`wait_interrupts` loop. It is a
**process-wide** switch (it affects every armed pin), which is why it lives on
`$pi`.

```perl
use strict;
use warnings;
use RPi::WiringPi;
use RPi::Const qw(:all);

my $pi  = RPi::WiringPi->new;
my $pin = $pi->pin(18);
$pin->mode(INPUT);

$pi->auto_dispatch_interrupts(1);   # callbacks now fire on their own — no loop to write

my $count = 0;
$pin->set_interrupt(EDGE_RISING, sub { $count++ });   # updates your own variable

while (1) {
    do_main_work();        # the callback fires between ops, and during the sleep
    print "edges so far: $count\n";
    sleep 1;
}

sub do_main_work {
    # ...
}
```

No dispatch loop, no fork, no threads — and the callback shares your program's
state directly. The one caveat: a long, non-yielding C/XS call delays the
callback until it returns (it fires at Perl's safe points). To fire even during
such work, use scenario 7 or 8.

**Choosing the signal.** By default the pipe is wired to `SIGIO`. If your program
already uses `SIGIO`/`O_ASYNC`, pass a different signal so they don't clash:

```perl
$pi->auto_dispatch_interrupts(1, 'USR1');   # deliver via SIGUSR1 instead

# turn it off again:
$pi->auto_dispatch_interrupts(0);
```

**Opt in while arming.** Instead of a separate `auto_dispatch_interrupts(1)`
call, you can turn it on as part of `set_interrupt` — this enables the same
process-wide switch:

```perl
$pin->set_interrupt(EDGE_RISING, sub { $count++ }, { auto_dispatch => 1 });
# or pick the signal:  { auto_dispatch => 'USR1' }
```

### 7. A background process (background_interrupt)

**Why/when:** True fire-while-busy with zero servicing, even during long blocking
work — because the handler runs in a *separate process*. Best for **independent**
handlers (drive a pin, log, notify) that don't need your main program's variables.

**Real-world:** An emergency-stop button that drops a motor relay immediately — it
must fire even while main is mid-way through a long upload or computation, and the
handler just drives a GPIO.

**Main & interrupt:** The callback runs in a **separate process**, truly
concurrently — it fires even while main blocks, but **cannot** see or change
main's variables (separate memory; share via IPC). Neither can corrupt the other.

`$pin->background_interrupt` forks a child that runs the handler on each edge
while your main program does anything it likes. The handler runs in the child, so
it **can't** touch your main variables — use it for independent work (drive a pin,
log, notify).

```perl
use strict;
use warnings;
use RPi::WiringPi;
use RPi::Const qw(:all);

my $pi  = RPi::WiringPi->new;
my $pin = $pi->pin(18);
$pin->mode(INPUT);

my $h = $pin->background_interrupt(EDGE_RISING, sub {
    my ($edge, $ts_us) = @_;
    # runs in the background on each rising edge — independent work only
});

# main carries on; the handler fires on its own
for (1 .. 10) {
    do_other_work();
    sleep 1;
}

$h->stop;        # stop + reap (idempotent); $h->pid / $h->running too

sub do_other_work {
    # ...
}
```

No `pipe`, no `fork`, no `select`, no `waitpid` — the library owns all of it (and
an `END` hook reaps the child even if you forget `stop`). `$h->stop` is
**idempotent**: safe to call more than once, and safe after the child has already
exited.

**Reporting values back (the `results` channel).** For a handler that just needs
to report a value to the parent, enable the results channel and **return** a value
from the handler; the parent drains it:

```perl
my $h = $pin->background_interrupt(EDGE_RISING, sub {
    my ($edge, $ts_us) = @_;
    return "$edge\@$ts_us";          # returned to the parent
}, { results => 1 });

while (defined(my $msg = $h->read)) {   # non-blocking drain in the parent
    print "handler said: $msg\n";
}
# $h->fh is the read filehandle, for select / IO::Select
```

### 8. Many pins in one background child (background_interrupts)

**Why/when:** You want background handling (scenario 7) for *several* pins, but a
separate child per pin is wasteful. `$pi->background_interrupts` forks **one**
child that services them all, and lets you arm/disarm individual pins at runtime.
Because it spans several pins it lives on `$pi`. **This form works today.**

**Real-world:** A control box with several buttons and sensors, all handled off
the main program in a single helper process.

**Main & interrupt:** Each callback runs in the one shared child (separate memory
from main, as in scenario 7). The callbacks are fixed when the child forks —
`fork` can't carry new code — so `arm`/`disarm` only toggle pins registered in the
initial call.

```perl
use strict;
use warnings;
use RPi::WiringPi;
use RPi::Const qw(:all);

my $pi = RPi::WiringPi->new;
$pi->pin($_)->mode(INPUT) for (18, 23);

my $h = $pi->background_interrupts(
    [18, EDGE_RISING, \&on_button],
    [23, EDGE_BOTH,   \&on_sensor, 5 * 1000],   # optional debounce (us)
);

# ... main does its own thing; both pins are handled in the one child ...

$h->disarm(23);   # stop servicing pin 23 (the child keeps running for pin 18)
$h->arm(23);      # resume it
$h->stop;         # tear down and reap the single child

sub on_button { ... }
sub on_sensor { ... }
```

The handle has the same `stop`/`pid`/`running` as scenario 7, plus
`arm($pin)`/`disarm($pin)`. The callbacks are fixed when the child forks, so
`arm`/`disarm` only toggle pins that were in the initial list (arming an
unregistered pin croaks).

---

## Anti-patterns to avoid

- **Forgetting to service dispatch in cooperative mode.** If you never call
  `$pi->dispatch_interrupts`/`$pi->wait_interrupts`, callbacks never fire — there
  is no background process doing it for you unless you set one up (scenarios 6–8).
- **Passing a string sub name as the callback.** Only a code reference
  (`sub { ... }` or `\&handler`) is accepted now.
- **Forking *after* arming interrupts.** wiringPi's ISR pthreads don't survive
  `fork`, and a mutex held at fork time is left locked in the child. Let the
  library do the forking for you (scenarios 7–8).
- **Relying on `auto_dispatch_interrupts` during a long non-yielding C/XS call.**
  Its callbacks fire at Perl's safe points (op boundaries, interrupted sleeps); a
  long C call that never yields delays them. Use a background process (scenarios
  7–8) if a handler must fire during such work.
- **Enabling `auto_dispatch_interrupts` when your program already uses
  `SIGIO`/`O_ASYNC`.** It claims that signal; pick one owner, or choose a
  different delivery signal (e.g. `$pi->auto_dispatch_interrupts(1, 'USR1')`).
- **Busy-spinning a `do_work + dispatch` loop.** A `while (1) { do_other_work();
  $pi->dispatch_interrupts }` (scenario 1) burns 100% CPU if the work returns
  instantly. Pace it, sleep, or block in `wait_interrupts` instead.

## Method reference for these examples

Arming methods live on a **pin** object (`my $pin = $pi->pin($n)`):

| Method (on `$pin`) | What it does |
|---|---|
| `mode($mode)` | set pin mode (`INPUT` / `OUTPUT`) |
| `set_interrupt($edge, $cb [, $debounce_us] [, \%opts])` | arm an interrupt; `$cb->($edge, $ts_us)`; `\%opts` may include `{auto_dispatch => 1\|$signal}` |
| `background_interrupt($edge, $cb [, $debounce_us] [, \%opts])` | handle it in a forked child; `\%opts` may include `{results => 1}`; returns a handle (`stop`/`pid`/`running`/`read`/`fh`) |

Dispatch and control methods live on the **Pi** object (`$pi`):

| Method (on `$pi`) | What it does |
|---|---|
| `wait_interrupts($timeout_ms)` | block until an edge/timeout, then dispatch |
| `run_interrupt_loop($timeout_ms [, $max])` / `stop_interrupt_loop` | built-in blocking dispatch loop |
| `dispatch_interrupts` | non-blocking: run pending callbacks, return count |
| `auto_dispatch_interrupts($bool [, $signal])` | fire callbacks automatically, in-process (no loop) |
| `background_interrupts([$pin,$edge,$cb[,$deb]], ...)` | one shared child for many pins (+ `arm`/`disarm`) |
| `last_interrupt` | hashref of the most recent dispatched event `{pin, pin_bcm, edge, status, ts_us}` |
| `interrupt_buffer([$bytes])` | get/set the event-queue capacity |
| `interrupt_dropped` | running count of edges dropped on queue overflow |
| `stop_interrupts` | release every armed interrupt |
| `cleanup` | full teardown (resets pins and releases interrupts; fork-aware) |

Edge constants (`EDGE_FALLING`=1, `EDGE_RISING`=2, `EDGE_BOTH`=3) and `INPUT`
come from `RPi::Const qw(:all)`.

See also `perldoc RPi::WiringPi::INTERRUPTS` (this guide in perldoc form),
[threads-examples.md](threads-examples.md) for running background work with
`$pi->worker`, the
[RPi::WiringPi::FAQ](https://metacpan.org/pod/RPi::WiringPi::FAQ) "Interrupt usage"
section, and the underlying [WiringPi::API](https://metacpan.org/pod/WiringPi::API)
documentation.
