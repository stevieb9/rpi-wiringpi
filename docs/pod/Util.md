# NAME

RPi::WiringPi::Util - Utility methods outside of Pi hardware functionality

## Table of Contents

- [DESCRIPTION](#description)
- [METHODS](#methods)
  - [checksum](#checksum)
  - [pin\_map($scheme)](#pin_mapscheme)
  - [uuid](#uuid)
  - [signal\_handlers](#signal_handlers)
  - [dump\_signal\_handlers](#dump_signal_handlers)
- [AUTHOR](#author)
- [COPYRIGHT AND LICENSE](#copyright-and-license)

# DESCRIPTION

This module contains various utilities for [RPi::WiringPi](https://metacpan.org/pod/RPi%3A%3AWiringPi) that don't
necessarily fit anywhere else. It is a base class, and is not designed to be
used independently.

# METHODS

## checksum

Returns a randomly generated 32-byte hexidecimal MD5 checksum. We use this
internally to generate a UUID for each Pi object.

## pin\_map($scheme)

Returns a hash reference in the following format:

    $map => {
        phys_pin_num => pin_num,
        ...
    };

If no scheme is in place or one isn't sent in, return will be an empty hash
reference.

Parameters:

    $scheme

Optional: By default, we'll check if you've already run a setup routine, and
if so, we'll use the scheme currently in use. If one is not in use and no
`$scheme` has been sent in, we'll return an empty hash reference, otherwise
if a scheme is sent in, the return will be:

For `'wiringPi'` scheme:

    $map = {
        phys_pin_num => wiringPi_pin_num,
        ....
    };

For `'GPIO'` scheme:

    $map = {
        phys_pin_num => gpio_pin_num,
        ...
    };

## uuid

Returns the Pi object's 32-byte hexidecimal unique identifier.

## signal\_handlers

Returns a hash reference of the currently set signal handlers.

## dump\_signal\_handlers

Prints, using [Data::Dumper](https://metacpan.org/pod/Data%3A%3ADumper), the structure holding the class' signal handling
data.

# AUTHOR

Steve Bertrand, <steveb@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2016-2026 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
