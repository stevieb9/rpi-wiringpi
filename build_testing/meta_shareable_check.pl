#!/usr/bin/env perl

# No-XS functional gate for the IPC::Shareable (tie-a-scalar) backend in
# RPi::WiringPi::Meta. Blesses a bare object into the Meta mixin (no WiringPi
# XS) and exercises the full meta_* surface: lock/fetch/store, set/get/delete,
# erase(0/1), key, key_check(present/absent), nested-mutation detachment, a
# cross-process fork, and the single-segment (no fan-out) guarantee.
#
# Run:  perl -Ilib build_testing/meta_shareable_check.pl
#
# The segment is intentionally left intact (destroy => 0). Re-running attaches
# to the same segment and reports the persisted __runs counter.

use strict;
use warnings;

use POSIX ();
use Test::More;

use lib 'lib';
use RPi::WiringPi::Meta;

my $KEY    = 'rpit';
my $ABSENT = 'blah';

my $obj = bless { shm_key => $KEY }, 'RPi::WiringPi::Meta';

# Persistence across actual reruns (informational): read any marker left by a
# previous invocation before we reset the segment.
{
    my $runs = $obj->meta_fetch->{storage}{__runs} // 0;
    diag "segment persisted from a prior run: __runs = $runs" if $runs;
}

# Reset to a known-empty blob so the rest of the assertions are deterministic
# regardless of what a prior run left behind.
$obj->meta_lock;
$obj->meta_store({});
$obj->meta_unlock;

# --- key + key_check ---------------------------------------------------------
is($obj->meta_key, 1473559184, "meta_key returns the CRC32-derived int for '$KEY'");
is(RPi::WiringPi::Meta->meta_key_check($KEY), 1, "meta_key_check('$KEY') sees the live segment");
is(RPi::WiringPi::Meta->meta_key_check($ABSENT), 0, "meta_key_check('$ABSENT') reports absent");

# --- lock / fetch / store round-trip ----------------------------------------
$obj->meta_lock;
my $m = $obj->meta_fetch;
is_deeply($m, {}, 'fetch on a freshly-reset segment is empty');
$m->{objects}{'uuid-a'} = { proc => $$, label => 'p' };
$m->{object_count} = 1;
$obj->meta_store($m);
$obj->meta_unlock;
is_deeply(
    $obj->meta_fetch->{objects}{'uuid-a'},
    { proc => $$, label => 'p' },
    'lock/fetch/store round-trips a nested value'
);

# --- nested-mutation detachment: a fetched copy is detached until stored -----
$obj->meta_lock;
my $a = $obj->meta_fetch;
$a->{pins}{17} = {
    alt     => 0,
    state   => 1,
    mode    => 1,
    comment => 'c',
    users   => { 'uuid-a' => 1 },
};
my $b = $obj->meta_fetch;       # second fetch, BEFORE the store
ok(! exists $b->{pins}, 'mutating a fetched copy does not touch the segment (detached)');
$obj->meta_store($a);
$obj->meta_unlock;
ok(exists $obj->meta_fetch->{pins}{17}, 'nested mutation persists only after meta_store');

# --- single segment for the whole nested blob (no fan-out) -------------------
my $segs = IPC::Shareable::global_register();
is(scalar keys %$segs, 1, 'exactly one shm segment backs the whole nested blob (no fan-out)');

# --- meta_set / meta_get / meta_delete (user storage slots) -----------------
my %data = (a => 1, b => [1, 2, 3]);
$obj->meta_set('mydata', \%data);
is_deeply($obj->meta_get('mydata'), \%data, 'meta_set then meta_get round-trips user data');
$obj->meta_delete('mydata');
is($obj->meta_get('mydata'), undef, 'meta_delete removes the storage slot');

# --- meta_erase(0): keep user storage, wipe software keys --------------------
$obj->meta_set('keepme', { x => 1 });
$obj->meta_erase(0);
{
    my $after = $obj->meta_fetch;
    is_deeply($after->{storage}{keepme}, { x => 1 }, 'erase(0) preserves user storage');
    ok(! exists $after->{objects}, 'erase(0) wipes software keys (objects)');
    ok(! exists $after->{pins},    'erase(0) wipes software keys (pins)');
}

# --- meta_erase(1): wipe everything -----------------------------------------
$obj->meta_erase(1);
is_deeply($obj->meta_fetch, {}, 'erase(1) wipes the entire blob');

# --- cross-process fork: child sees parent write; parent sees child write
#     after the child has exited (segment survives process death) ------------
$obj->meta_lock;
my $pm = $obj->meta_fetch;
$pm->{storage}{from_parent} = 'hello-child';
$obj->meta_store($pm);
$obj->meta_unlock;

my $pid = fork;
defined $pid or die "fork failed: $!";

if ($pid == 0) {
    # child process
    $obj->meta_lock;
    my $cm  = $obj->meta_fetch;
    my $saw = $cm->{storage}{from_parent} // '(nothing)';
    $cm->{storage}{from_child} = "child-saw:$saw";
    $obj->meta_store($cm);
    $obj->meta_unlock;
    POSIX::_exit(0);                 # skip parent END blocks (no stray TAP)
}

waitpid $pid, 0;
is(
    $obj->meta_fetch->{storage}{from_child},
    'child-saw:hello-child',
    'fork: child read parent write, parent read child write after child exit'
);

# Leave a persistence marker (increment a run counter) and DO NOT destroy the
# segment, so a subsequent run attaches to the same segment and sees this.
$obj->meta_lock;
my $final = $obj->meta_fetch;
$final->{storage}{__runs} = ($final->{storage}{__runs} // 0) + 1;
$obj->meta_store($final);
$obj->meta_unlock;
pass('segment left intact (destroy => 0); rerun to watch __runs increment');

done_testing();
