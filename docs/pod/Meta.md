# NAME

RPi::WiringPi::Meta - Shared memory meta data management for RPI::WiringPi

# DESCRIPTION

This module contains various utilities for the shared memory storage area. This
area allows both the software and you, the user, to share Perl variables across
different scripts and processes easily.

# SYNOPSIS

    my $pi = RPi::WiringPi;

    my %data = (a => 1, b => 2, c => [1, 2, 3]);

    # add a new or set an existing storage slot (must be an href)

    $pi->meta_set('my_data', \%data);

    # retrieve an existing storage slot (always an href)

    my $stats = $pi->meta_get('stats');

    # delete an existing storage slot

    $pi->meta_delete('stats');

# METHODS

## meta

Instantiates and returns the shared memory object that stores the meta data.

Internally, we tie a scalar to [IPC::Shareable](https://metacpan.org/pod/IPC%3A%3AShareable) holding a single JSON-encoded
string, which keeps the entire meta data blob within one shared memory segment.
The returned object is the [IPC::Shareable](https://metacpan.org/pod/IPC%3A%3AShareable) "knot" (the tied object).

## meta\_set($name, $href)

Adds a user-defined hash reference to the shared memory segment with it's key
named `$name`.

Parameters:

    $name

Mandatory, String: Any value that is a legitimate value for a hash key.

    $href

Mandatory, Hash Reference: A hash reference that contains your data.

## meta\_get($name)

Retrieves a user-defined hash reference from the shared memory.

Parameters:

    $name

Mandatory, String: The key name for the user defined data.

Returns: Hash reference.

## meta\_delete($name)

Deletes a user-defined shared memory segment.

Parameters:

    $name

Mandatory, String: The key name for the user defined data to delete.

## meta\_fetch

**NOTE**: For most use cases, users should use the ["meta\_get($name)"](#meta_get-name) method as
opposed to this one. The data held in the shared memory is critical to proper
operation of the software.

Fetches and returns the shared memory data as a hash reference.

**NOTE**: You should always wrap the `meta_fetch()` call with calls to
`meta_lock()` and `meta_unlock()`.

## meta\_store($data)

**NOTE**: For most use cases, users should use the ["meta\_get($name)"](#meta_get-name) method as
opposed to this one. The data held in the shared memory is critical to proper
operation of the software.

Serializes and stores the shared data.

Parameters:

    $data

Mandatory, Hash Reference. The data to store (should be a modified version that
was retrieved using `meta_fetch()`).

**NOTE**: You should always wrap the `meta_store()` call with calls to
`meta_lock()` and `meta_unlock()`.

## meta\_lock($flags)

`meta_fetch()` and `meta_store()` do not lock on their own, so you must wrap
your fetch/mutate/store transactions with `meta_lock()` and `meta_unlock()`
to keep them atomic across processes.

Parameters:

    $flags

Mandatory, Integer. See [flock](http://man7.org/linux/man-pages/man2/flock.2.html)
for details as to what's available here.

Default: If `$flags` is not sent in, we default to an exclusive lock
(`LOCK_EX`).

## meta\_unlock

Performs an unlock after you're done with `meta_lock()`.

## meta\_key

Returns the integer shared memory key that links the object to the shared memory
segment.

**NOTE**: This integer is derived by [IPC::Shareable](https://metacpan.org/pod/IPC%3A%3AShareable) from the string `shm_key`
via a CRC32 hash (with signed 32-bit overflow correction), so it is **not** the
raw byte-packed value of the string. For example, the default `rpiw` string key
resolves to `1323166506`.

## meta\_key\_check($key)

Checks whether a shared memory segment with the key `$key` exists or not.

Parameters:

    $key

Mandatory, String: The string key to validate against (eg. `rpiw`). This is
converted to its integer segment key internally using the same CRC32 derivation
that [IPC::Shareable](https://metacpan.org/pod/IPC%3A%3AShareable) uses, then probed for existence without creating it.

Returns: True `1` if the shared memory segment exists, and false `0`
otherwise.

## meta\_erase($all)

Erases and resets all meta data. Do not use this method lightly.

Parameters:

    $all

Optional, Bool: If true, we'll delete the user-based `storage` shared memory
data along with the software's internal data, and if false, we'll leave that
user data intact. Defaults to false (`0`).

## meta\_remove

Removes the underlying shared memory segment (and its semaphore set) entirely,
freeing the SysV resources so the segment no longer appears in `ipcs`.

This differs from ["meta\_erase($all)"](#meta_erase-all), which only empties the stored data but
leaves the segment allocated (it's created with `destroy => 0` so it
persists across processes). Use `meta_remove()` when you're truly finished with
the segment and want to reclaim it.

**NOTE**: A subsequent call to any `meta_*` method transparently creates a fresh,
empty segment, so this is safe to call mid-process.

Returns: True `1` if a segment was removed, or `undef` if there was no live
segment to remove.

Steve Bertrand, <steveb@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2016-2026 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
