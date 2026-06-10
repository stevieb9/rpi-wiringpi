# NAME

RPi::WiringPi::WORKERS - concurrency & background-worker examples for RPi::WiringPi

# DESCRIPTION

Worked, runnable examples for running background work concurrently with your main
program using the object-oriented [RPi::WiringPi](https://metacpan.org/pod/RPi%3A%3AWiringPi). The `$pi->worker` method
described here is a thin proxy onto `WiringPi::API::worker()` (shipped in
`WiringPi::API` 3.18 and verified on Pi 5 hardware); the snippets run as written.

`$pi->worker` is **fork-based by default and needs no** `use threads` **and no
threaded Perl** - an ithread mechanism is a documented opt-in only. For reacting to
GPIO _edges_ in the background, see `$pi->background_interrupts` and
[RPi::WiringPi::INTERRUPTS](https://metacpan.org/pod/RPi%3A%3AWiringPi%3A%3AINTERRUPTS).

This is the OO companion to [WiringPi::API::WORKERS](https://metacpan.org/pod/WiringPi%3A%3AAPI%3A%3AWORKERS); that one
covers the low-level functional API, this one the `$pi` object. See the
`worker(\&body, \%opts)` entry in [RPi::WiringPi](https://metacpan.org/pod/RPi%3A%3AWiringPi) for the per-method reference.

# ABOUT THESE EXAMPLES

This document covers running work **concurrently** with the main program - distinct
from reacting to interrupts.

- **Prefer** `$pi->worker`. It hides the spawn mechanism, the loop **and** the
lifecycle: your body carries no `fork`, no `use threads`, no `detach`, no
`while (1)` and no cleanup. It is the general-purpose sibling of
`$pi->background_interrupts`.
- **The object owns the lifecycle.** Every handle returned by `$pi->worker` is
tracked on the object; `$pi->cleanup` (and therefore `DESTROY`) stops them
all. You can `$w->stop` a worker yourself, but you never have to.
- **No threads required.** `$pi->worker` forks by default and works on **any**
Perl, threaded or not. The ithread mechanism (scenario 6) is an opt-in for users
who specifically want shared-memory ergonomics on a threaded Perl.
- **Pin numbering** follows the object's scheme (BCM/GPIO by default). Configure pins
through the object - `my $pin = $pi->pin($n); $pin->mode(OUTPUT)` - once, in
the parent, before starting a worker.
- Sections 7-8 (["UNDER THE HOOD"](#under-the-hood)) show the raw `fork` / `threads->create`
plumbing that `$pi->worker` packages up - read them to understand what happens
beneath the method, but most programs only need `$pi->worker`.

# DECISION GUIDE

None of these need `use threads` except scenario 6. To hide the most plumbing,
use `$pi->worker` (scenarios 1-5).

**fork vs thread in one line:** the default `fork` worker is crash-isolated and
works on any Perl but **can't touch main's variables** (hand data back with
`results`/`shared`); a `mechanism => 'thread'` worker shares memory directly
but needs a threaded Perl and `pi_lock` discipline. No shared-memory need? Use the
default fork.

- Run a background task and forget it (its own GPIO) - scenario 1.
- Sample periodically; main reads the latest value - scenario 2
(`interval`/`shared`).
- Stream every value the worker produces back to main - scenario 3 (`results`).
- Do one background job once, then exit - scenario 4 (`once`).
- Several independent workers, each on its own pin - scenario 5.
- Share memory directly between main and the worker - scenario 6
(`mechanism => 'thread'`).
- React to a pin edge in the background - `$pi->background_interrupts`.
- Understand/hand-roll the raw mechanism - scenarios 7, 8.

# BACKGROUND WORKERS ($pi->worker)

## 1. Heartbeat LED - a worker on its own pin

**Why/when:** Run a self-contained background task on its own GPIO while main does
its own work; the simplest possible case.

**Real-world:** A status heartbeat LED blinking on its own cadence while the main
program does its real work.

**Main & background:** The method owns the loop and the lifecycle. You write only
the body; `$pi->worker` repeats it until you `stop` - or until
`$pi->cleanup` reaps it for you.

    use strict;
    use warnings;
    use RPi::WiringPi;
    use RPi::Const qw(:all);

    my $pi  = RPi::WiringPi->new;
    my $pin = $pi->pin(2);
    $pin->mode(OUTPUT);               # once, in main

    my $w = $pi->worker(sub {
        $pin->write(HIGH); sleep 1;
        $pin->write(LOW);  sleep 1;
    });

    # ... main does its own work ...

    $pi->cleanup;                     # stops $w (and every other worker) for you

No `use threads`, no `fork`, no `detach`, no `while (1)`, no `waitpid`. You
could also `$w->stop` the heartbeat by hand (idempotent); `cleanup` just
makes it automatic.

## 2. Periodic sampler handing data back (interval + shared)

**Why/when:** Timer-driven sampling where main only ever wants the **latest**
reading, not every sample.

**Real-world:** Polling a sensor every second into a value the main app (a web
handler or display loop) reads on demand.

**Main & background:** `{ interval => $secs }` paces the loop (the body needs
no `sleep`); `{ shared => 1 }` publishes the body's return value as a lossy
latest value the parent reads with `$w->value`.

    use strict;
    use warnings;
    use RPi::WiringPi;
    use RPi::Const qw(:all);

    my $pi  = RPi::WiringPi->new;
    my $pin = $pi->pin(4);
    $pin->mode(INPUT);                # once, in main

    my $w = $pi->worker(sub { $pin->read }, { interval => 1, shared => 1 });

    for (1 .. 5) {
        my $latest = $w->value;       # most recent sample, or undef until the first
        print "latest: ", (defined $latest ? $latest : 'n/a'), "\n";
        sleep 5;
    }

    $pi->cleanup;

The channel is **lossy** - the worker never blocks on a slow reader, so `value()`
gives you the most recent sample and discards the ones you didn't read.

## 3. Streaming every result (results)

**Why/when:** When you need **every** value the worker produces, in order, not just
the latest.

**Real-world:** A logger that records each reading, or a counter feeding an
event-loop via `select`.

**Main & background:** `{ results => 1 }` length-frames every defined return
value back over a pipe. Drain it with `$w->read` (non-blocking), or select on
`$w->fh`.

    use strict;
    use warnings;
    use RPi::WiringPi;
    use RPi::Const qw(:all);

    my $pi  = RPi::WiringPi->new;
    my $pin = $pi->pin(4);
    $pin->mode(INPUT);                # once, in main

    my $w = $pi->worker(sub { $pin->read }, { interval => 0.5, results => 1 });

    for (1 .. 20) {
        while (defined(my $v = $w->read)) {   # drain everything pending
            print "sample: $v\n";
        }
        sleep 1;
    }

    $pi->cleanup;

This is identical to `$pi->background_interrupts`' `{ results => 1 }`
channel.

## 4. A one-shot background task (once)

**Why/when:** A single background job - run it off the main path and let it exit on
its own.

**Real-world:** Firing a one-shot solenoid pulse, or taking a single sensor reading,
without blocking main.

**Main & background:** `{ once => 1 }` runs the body exactly once; the child
then exits and `$w->running` becomes false. You can still `stop` (idempotent)
or just let `$pi->cleanup` clean up.

    use strict;
    use warnings;
    use RPi::WiringPi;
    use RPi::Const qw(:all);

    my $pi  = RPi::WiringPi->new;
    my $pin = $pi->pin(5);
    $pin->mode(OUTPUT);               # once, in main

    my $w = $pi->worker(sub {
        $pin->write(HIGH);
        select(undef, undef, undef, 0.2);     # 200ms pulse
        $pin->write(LOW);
    }, { once => 1 });

    # ... main carries on; the pulse fires in the background ...

    $pi->cleanup;                     # the pulse has usually already finished

## 5. Several workers on distinct pins

**Why/when:** Multiple independent background tasks at once, each owning its own
pin.

**Real-world:** A multi-channel relay board where each channel toggles on its own
cadence while main runs the control logic.

**Main & background:** Configure every pin **once in main**, then start one worker
per pin. Each runs independently and returns its own handle; all of them are
tracked on the object and stopped together by `$pi->cleanup`.

    use strict;
    use warnings;
    use RPi::WiringPi;
    use RPi::Const qw(:all);

    my $pi = RPi::WiringPi->new;

    my @pins = map { my $p = $pi->pin($_); $p->mode(OUTPUT); $p } (23, 24, 25);

    my @workers = map {
        my $pin = $_;
        $pi->worker(sub { $pin->write(HIGH); sleep 1; $pin->write(LOW); sleep 1 });
    } @pins;

    # ... main's own work ...

    $pi->cleanup;                     # stops all @workers at once

Workers must drive **distinct** pins - see ["THE SETUP-ONCE-IN-MAIN CONTRACT"](#the-setup-once-in-main-contract).

## 6. Shared memory - the opt-in ithread mechanism

**Why/when:** You specifically want to share memory directly between main and the
worker (no IPC), and you have a threaded Perl.

**Real-world:** A counter or state machine the worker mutates and main reads in the
same address space.

**Main & background:** `{ mechanism => 'thread' }` runs the body in an ithread
instead of a fork. It **requires** `use threads` (croaks otherwise) and rejects
the `results`/`shared` pipe channels - share a `:shared` variable and serialize
it with `WiringPi::API::pi_lock`/`WiringPi::API::pi_unlock` (keys 0-3) instead.
There is **no** OO proxy for the lock - thread mode is a niche opt-in, so you call
the `WiringPi::API` functions directly. `$w->stop` sets the stop flag and
joins the thread.

    use strict;
    use warnings;
    use threads;                      # required for mechanism => 'thread'
    use threads::shared;
    use RPi::WiringPi;
    use WiringPi::API qw(pi_lock pi_unlock);

    my $pi = RPi::WiringPi->new;

    my $count :shared = 0;

    my $w = $pi->worker(sub {
        pi_lock(0);
        $count++;
        pi_unlock(0);
        select(undef, undef, undef, 0.1);
    }, { mechanism => 'thread' });

    for (1 .. 5) {
        pi_lock(0);
        my $n = $count;
        pi_unlock(0);
        print "count: $n\n";
        sleep 1;
    }

    $w->stop;                         # sets the stop flag and joins

Check for a threaded Perl with `perl -V:useithreads` (Raspberry Pi OS ships one).
The fork default (scenarios 1-5) never locks and never needs `threads`.

# REACTING TO INTERRUPTS IN THE BACKGROUND

`$pi->worker` is for _running_ background work, not for reacting to GPIO
**edges**. To handle an edge in the background - fire a callback even while main is
blocked - use **`$pi->background_interrupts`**, the interrupt-side sibling of
`worker`. It forks a single child that arms one or more pins and runs your
callback on each edge, and returns a handle with the same `stop`/`pid`/`running`
shape (plus `arm`/`disarm`):

    use RPi::WiringPi;
    use RPi::Const qw(:all);

    my $pi  = RPi::WiringPi->new;
    my $pin = $pi->pin(4);
    $pin->mode(INPUT);

    my $h = $pi->background_interrupts(
        [4, EDGE_RISING, \&on_edge, 0],
    );

    # ... main does its own work; the handler fires on its own ...

    $pi->cleanup;                     # stops interrupts and workers together

    sub on_edge { ... }               # runs in the background child on each edge

The full interrupt story is in [RPi::WiringPi::INTERRUPTS](https://metacpan.org/pod/RPi%3A%3AWiringPi%3A%3AINTERRUPTS) and the interrupt
methods in [RPi::WiringPi](https://metacpan.org/pod/RPi%3A%3AWiringPi).

# THE SETUP-ONCE-IN-MAIN CONTRACT

The rule that keeps concurrent GPIO safe: do all configuration **once, in main,
before** starting any worker; afterwards each context does only steady-state I/O on
**distinct** pins.

- Construct the object and configure every pin (`$pi->pin($n)`,
`$pin->mode(...)`) and any device **once, in the parent, before** the first
`$pi->worker`.
- A fork worker inherits that configuration; a thread worker shares it.
- Afterwards, workers may freely read/write on **distinct** pins. **Never** configure
pins or set up devices concurrently - they read-modify-write shared registers.
- For shared Perl data under `mechanism => 'thread'`, guard every access with
`WiringPi::API::pi_lock`/`WiringPi::API::pi_unlock` (or `threads::shared`'s
`lock`).
- A forked worker shares the `$pi` object but must not tear it down: the
process-guard in `cleanup()` ensures only the parent stops workers and restores
pins, so a worker exiting never disturbs the parent's state.

# UNDER THE HOOD

These are the raw mechanisms `$pi->worker` packages up. You rarely need them
directly; they are here to show what the method does and to cover cases it doesn't.

## 7. Manual fork

**Why/when:** The fork worker (scenario 1) without the method - full control over
the child, at the cost of writing the loop, the signal handling and the reaping
yourself.

**Main & background:** The child is a separate process: truly concurrent and
crash-isolated, but it **cannot** touch main's variables - pass data back via a
pipe, and reap it yourself.

    use strict;
    use warnings;
    use RPi::WiringPi;
    use RPi::Const qw(:all);

    my $pi  = RPi::WiringPi->new;
    my $pin = $pi->pin(2);
    $pin->mode(OUTPUT);                      # before fork

    my $kid = fork // die "fork: $!";

    if ($kid == 0) {
        while (1) {                          # child: heartbeat forever
            $pin->write(HIGH); sleep 1;
            $pin->write(LOW);  sleep 1;
        }
        exit 0;
    }

    # ... parent's own work ...

    kill 'TERM', $kid;                       # on shutdown
    waitpid $kid, 0;

`$pi->worker(sub {...})` is exactly this - the fork, the loop, the `TERM`
handler and the `waitpid` - done for you, with an idempotent `stop`, automatic
reaping in `$pi->cleanup`, and an END-block safety net in `WiringPi::API`.

## 8. Raw ithreads (threads->create)

**Why/when:** The thread worker (scenario 6) without the method - when you want to
manage the thread object yourself.

**Main & background:** The body runs in its **own** interpreter; it can't see main's
lexicals - share only via `:shared` variables guarded by `pi_lock`/`lock`.

    use strict;
    use warnings;
    use threads;
    use threads::shared;
    use RPi::WiringPi;
    use WiringPi::API qw(pi_lock pi_unlock);

    my $pi  = RPi::WiringPi->new;
    my $pin = $pi->pin(4);
    $pin->mode(INPUT);

    my $latest :shared = 0;

    my $thr = threads->create(sub {
        while (1) {
            my $v = $pin->read;
            pi_lock(0); $latest = $v; pi_unlock(0);
            select(undef, undef, undef, 0.05);
        }
    });

    # ... main reads $latest under pi_lock(0) ...

    # To stop a hand-rolled thread you need your own shared flag + join;
    # $pi->worker({mechanism=>'thread'}) provides exactly that.
    $thr->detach;

`$pi->worker(sub {...}, { mechanism => 'thread' })` wraps this with a shared
stop flag and a clean `stop`/join, so you don't hand-roll the lifecycle.

# ANTI-PATTERNS TO AVOID

- **Reaching for** `use threads` **first.** `$pi->worker` is fork-based and needs
no threaded Perl. Only use `mechanism => 'thread'` when you specifically want
shared memory.
- **Putting a loop inside the body.** `$pi->worker` owns the loop - the body is
one pass. Use `{ interval => $secs }` for pacing and `{ once => 1 }` for
a single pass; a `while (1)` inside the body defeats `stop`/`once`/`interval`.
- **Concurrent pin configuration / device setup.** Read-modify-write on shared
registers; do them once, in main, before starting any worker. Only reads/writes on
distinct pins are safe concurrently.
- **Expecting a fork worker to see main's variables.** Separate memory - hand data
back with `{ results => 1 }` / `{ shared => 1 }`, not a shared Perl
variable.
- **Touching** `:shared` **data without a lock (thread mode).** Guard every access
with `pi_lock`/`pi_unlock` (or `lock`). A bare `$shared++` from two threads
races.
- **Combining** `mechanism => 'thread'` **with** `results`/`shared`. Those are
fork pipe channels and are rejected under thread mode - share a `:shared` variable
with `pi_lock` instead.

# API REFERENCE FOR THESE EXAMPLES

- `RPi::WiringPi->new`

    Construct the Pi object (GPIO/BCM numbering by default).

- `$pi->pin($num)` / `$pin->mode($mode)`

    Register a pin and set its mode (`INPUT`/`OUTPUT` from [RPi::Const](https://metacpan.org/pod/RPi%3A%3AConst)).

- `$pin->write($val)` / `$pin->read`

    Pin I/O; `read` returns the pin level (`0`/`1`).

- `$pi->worker(\&body [, \%opts])`

    Run `\&body` in the background. `\%opts`: `{once, interval, results, shared,
    mechanism}`. Returns a handle `$w` with `stop` / `pid` / `running` / `read` /
    `fh` / `value`. The handle is tracked on `$pi` and stopped by `$pi->cleanup`.

- `$pi->cleanup`

    Normal teardown: stops every tracked worker, releases interrupts, and restores
    pins. Also runs from `DESTROY`.

- `WiringPi::API::pi_lock($key)` / `WiringPi::API::pi_unlock($key)`

    Mutex (keys 0-3) for shared state under thread mode. Called directly - there is no
    OO proxy.

- `$pi->background_interrupts(...)`

    Background **edge** handler (the interrupt-side sibling). Returns a handle `$h`.

# SEE ALSO

[RPi::WiringPi](https://metacpan.org/pod/RPi%3A%3AWiringPi), [WiringPi::API](https://metacpan.org/pod/WiringPi%3A%3AAPI), and [WiringPi::API::WORKERS](https://metacpan.org/pod/WiringPi%3A%3AAPI%3A%3AWORKERS) for the
low-level functional API.

# AUTHOR

Steve Bertrand, <steveb@cpan.org>
