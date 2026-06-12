# NAME

RPi::WiringPi::INTERRUPTS - interrupt (edge event) usage examples for RPi::WiringPi

## Table of Contents

- [DESCRIPTION](#description)
- [THE MODEL](#the-model)
- [QUICK START](#quick-start)
- [DRIVING DISPATCH](#driving-dispatch)
- [HANDS-OFF: FIRE CALLBACKS WITH NO LOOP](#hands-off-fire-callbacks-with-no-loop)
- [BACKGROUND HANDLING (ONE PROCESS, FIRES EVEN WHILE MAIN IS BUSY)](#background-handling-one-process-fires-even-while-main-is-busy)
- [MANY PINS IN ONE BACKGROUND CHILD](#many-pins-in-one-background-child)
- [INSPECTING THE MOST RECENT EVENT](#inspecting-the-most-recent-event)
- [QUEUE SIZING AND DROPPED EDGES](#queue-sizing-and-dropped-edges)
- [FORKING AND CLEANUP](#forking-and-cleanup)
- [METHOD REFERENCE](#method-reference)
- [SEE ALSO](#see-also)
- [AUTHOR](#author)

# DESCRIPTION

A practical, runnable guide to handling GPIO interrupts (edge events) with the
object-oriented [RPi::WiringPi](https://metacpan.org/pod/RPi%3A%3AWiringPi). The interrupt API described here is built on
`WiringPi::API` 3.18 and verified on Pi 5 hardware; the snippets run as written.

This document is **edge-only and uses no** `use threads` - general
concurrency/worker examples (`$pi->worker`) live in
[RPi::WiringPi::WORKERS](https://metacpan.org/pod/RPi%3A%3AWiringPi%3A%3AWORKERS) / `docs/examples/threads-examples.md`. Callbacks fire in your
own interpreter when you service dispatch, so they work on **any** Perl, threaded
or not.

This is the `perldoc` form of `docs/examples/interrupt-examples.md`. See [RPi::WiringPi](https://metacpan.org/pod/RPi%3A%3AWiringPi)
for the per-method reference, and the underlying [WiringPi::API](https://metacpan.org/pod/WiringPi%3A%3AAPI) for the
low-level functional API.

# THE MODEL

Interrupts are **armed on a pin** and **driven from the Pi object**:

- **Arm** on a pin object: `$pin->set_interrupt(...)` (or, when [RPi::Pin](https://metacpan.org/pod/RPi%3A%3APin)
ships it, `$pin->background_interrupt(...)`).
- **Drive and control** dispatch on the Pi object `$pi`: `wait_interrupts`,
`run_interrupt_loop`, `dispatch_interrupts`, `auto_dispatch_interrupts`,
`stop_interrupts`, `last_interrupt`, `interrupt_buffer`,
`background_interrupts`.

The split is deliberate: arming concerns a single pin, but the dispatch queue and
signal wiring are **process-wide** (one shared event pipe), so those live on
`$pi`, not on individual pins.

**The #1 gotcha:** as of `WiringPi::API` 3.18 a callback does **not** auto-fire.
It runs in _your_ interpreter only when you service dispatch. So after arming you
must drive dispatch (a loop, or `auto_dispatch_interrupts`, or a background
process). The callback **must be a code reference** - string sub names are no
longer accepted.

# QUICK START

    use RPi::WiringPi;
    use RPi::Const qw(:all);

    my $pi  = RPi::WiringPi->new;
    my $pin = $pi->pin(18);
    $pin->mode(INPUT);

    # Arm: callback gets ($edge, $timestamp_us)

    $pin->set_interrupt(
        EDGE_RISING,
        sub {
            my ($edge, $ts_us) = @_;
            print "rising edge at $ts_us us\n";
        }
    );

    # Drive dispatch (callbacks fire here, in this process)

    $pi->wait_interrupts(1000) while 1;

# DRIVING DISPATCH

Pick whichever fits your program. All of these live on `$pi`:

    # 1) Block until an edge (or timeout ms), then dispatch:

    $pi->wait_interrupts(1000) while 1;

    # 2) The built-in loop helper (so you don't write the 'while 1' yourself):

    $pi->run_interrupt_loop(1000);          # Forever
    $pi->run_interrupt_loop(1000, 50);      # ... or until 50 events

    # Break out from a callback or signal handler with:

    $pi->stop_interrupt_loop;

    # 3) Non-blocking, from inside your own event loop:

    $pi->dispatch_interrupts; # Run any pending callbacks, return count

# HANDS-OFF: FIRE CALLBACKS WITH NO LOOP

`auto_dispatch_interrupts` wires the event pipe to a signal so callbacks fire
automatically, in your own process, at safe points - no dispatch loop, and the
callback can touch your program's variables with no locking. It is a
**process-wide** switch (it affects every armed pin), which is why it lives on
`$pi`.

    $pi->auto_dispatch_interrupts(1); # On (default SIGIO)

    $pin->set_interrupt(EDGE_RISING, sub { $count++ });

    # ... your program runs; the callback fires on its own ...

    $pi->auto_dispatch_interrupts(0); # Off

    # Choose a different delivery signal to avoid clashing with other SIGIO users:

    $pi->auto_dispatch_interrupts(1, 'USR1');

You can also opt in while arming, instead of a separate call:

    $pin->set_interrupt(EDGE_RISING, \&handler, { auto_dispatch => 1 });
    # or:  { auto_dispatch => 'USR1' }

Caveat: a long, non-yielding C/XS call defers the callback until it returns. If
you need it to fire even then, use a background process (below).

# BACKGROUND HANDLING (ONE PROCESS, FIRES EVEN WHILE MAIN IS BUSY)

**Dependency note:** the per-pin `$pin->background_interrupt` form shown in
this section requires [RPi::Pin](https://metacpan.org/pod/RPi%3A%3APin) `2.3609` or greater (the version this
distribution already requires). To handle several pins, the multi-pin
`$pi->background_interrupts` form (["MANY PINS IN ONE BACKGROUND CHILD"](#many-pins-in-one-background-child))
runs them all from a single child instead of one child per pin.

`$pin->background_interrupt` forks a child that runs the handler on each edge
while your main program does anything it likes. The handler runs in the child, so
it **can't** touch your main variables - use it for independent work (drive a pin,
log, notify).

    my $h = $pin->background_interrupt(
        EDGE_RISING,
        sub {
            my ($edge, $ts_us) = @_;
            # Independent work, in the background
        }
    );

    # ... main carries on ...

    $h->stop;        # stop + reap (idempotent); $h->pid / $h->running too

To get values back from the handler, enable the **results channel** and _return_
a value:

    my $h = $pin->background_interrupt(
        EDGE_RISING,
        sub {
            my ($edge, $ts_us) = @_;
            return "$edge\@$ts_us";
        },
        { results => 1 }
    );

    while (defined(my $msg = $h->read)) {
        # Non-blocking drain in the parent
        print "handler said: $msg\n";
    }

    # $h->fh is the read filehandle, for select / IO::Select

This results channel is identical to `$pi->worker`'s `{ results => 1 }`
(see [RPi::WiringPi::WORKERS](https://metacpan.org/pod/RPi%3A%3AWiringPi%3A%3AWORKERS)).

# MANY PINS IN ONE BACKGROUND CHILD

`$pi->background_interrupts` is the multi-pin version: **one** child services
several pins (instead of one child per pin), with runtime arm/disarm. Because it
spans several pins it lives on `$pi`.

    my $h = $pi->background_interrupts(
        [18, EDGE_RISING, \&on_button],
        [23, EDGE_BOTH,   \&on_sensor, 5000],   # Optional debounce (us)
    );

    $h->disarm(23);   # Stop servicing pin 23 (child keeps running for pin 18)
    $h->arm(23);      # Resume it
    $h->stop;         # Tear down + reap the single child

The callbacks are fixed when the child forks, so `arm`/`disarm` only toggle pins
that were in the initial list (arming an unregistered pin croaks).

# INSPECTING THE MOST RECENT EVENT

The callback only receives `($edge, $timestamp_us)`. If one shared handler is
armed on several pins, `$pi->last_interrupt` tells you which fired:

    my $cb = sub {
        my $i = $pi->last_interrupt;   # { pin, pin_bcm, edge, status, ts_us }
        printf "pin %d (BCM %d) edge %d\n", $i->{pin}, $i->{pin_bcm}, $i->{edge};
    };

    $pi->pin($_)->set_interrupt(EDGE_BOTH, $cb) for (18, 23);

It returns the most recently dispatched event (or `undef`), and is published
_before_ the callback runs, so the callback can read it.

# QUEUE SIZING AND DROPPED EDGES

Edges are FIFO-queued in a kernel pipe. If a fast source outruns your dispatching
the queue fills and the **newest** edges are dropped (never merged, never blocked)
and counted - so loss is never silent:

    my $lost = $pi->interrupt_dropped; # 0 unless the pipe overflowed
    $pi->interrupt_buffer(1 << 20);    # Enlarge the queue (~1 MiB)
    my $size = $pi->interrupt_buffer;  # Read the current capacity

`interrupt_buffer` may be set before arming and persists across teardown. Other
mitigations: dispatch faster, use a background process, or debounce.

# FORKING AND CLEANUP

`$pi->cleanup` (called automatically at object destruction) resets pins **and**
releases armed interrupts (it calls `stop_interrupts` for you). It is
**fork-aware**: in a forked child the call is a no-op, so a child can't reset the
parent's pins or tear down its interrupts on exit. You can also disarm explicitly
while running:

    $pin->set_interrupt(EDGE_RISING, \&handler);

    # ... later ...

    $pi->stop_interrupts;   # Release every armed interrupt
    $pi->cleanup;           # Full teardown (also releases interrupts)

# METHOD REFERENCE

Arming methods live on a **pin** object (`my $pin = $pi->pin($n)`):

- `$pin->set_interrupt($edge, $cb [, $debounce_us] [, \%opts])`

    Arm an interrupt; `\%opts` may include `{ auto_dispatch => 1 | $signal }`.

- `$pin->background_interrupt($edge, $cb [, $debounce_us] [, \%opts])`

    Handle it in a forked child; `\%opts` may include `{ results => 1 }`;
    returns a handle. (Pending an [RPi::Pin](https://metacpan.org/pod/RPi%3A%3APin) release - see the dependency note above.)

Dispatch and control methods live on the **Pi** object (`$pi`):

- `$pi->wait_interrupts($timeout_ms)`

    Block until an edge/timeout, then dispatch.

- `$pi->run_interrupt_loop($timeout_ms [, $max])` / `$pi->stop_interrupt_loop`

    Built-in blocking dispatch loop.

- `$pi->dispatch_interrupts`

    Non-blocking: run pending callbacks.

- `$pi->auto_dispatch_interrupts($bool [, $signal])`

    Fire callbacks automatically (no loop).

- `$pi->background_interrupts([$pin, $edge, $cb [, $deb]], ...)`

    One shared child for many pins (+ `arm`/`disarm`).

- `$pi->last_interrupt`

    Hashref of the most recent dispatched event.

- `$pi->interrupt_buffer([$bytes])`

    Get/set the event-queue capacity.

- `$pi->interrupt_dropped`

    Running count of edges dropped on queue overflow.

- `$pi->stop_interrupts`

    Release every armed interrupt.

Edge constants (`EDGE_FALLING`=1, `EDGE_RISING`=2, `EDGE_BOTH`=3) and `INPUT`
come from `RPi::Const qw(:all)`.

# SEE ALSO

[RPi::WiringPi](https://metacpan.org/pod/RPi%3A%3AWiringPi), [RPi::WiringPi::WORKERS](https://metacpan.org/pod/RPi%3A%3AWiringPi%3A%3AWORKERS) (running background work with
`$pi->worker`), the [RPi::WiringPi::FAQ](https://metacpan.org/pod/RPi%3A%3AWiringPi%3A%3AFAQ) "Interrupt usage" section,
`docs/examples/interrupt-examples.md`, and the underlying [WiringPi::API](https://metacpan.org/pod/WiringPi%3A%3AAPI).

# AUTHOR

Steve Bertrand, <steveb@cpan.org>
