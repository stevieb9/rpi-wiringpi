# NAME

RPi::WiringPi::Core - Core methods for RPi::WiringPi Raspberry Pi
interface

# DESCRIPTION

This module contains various utilities for [RPi::WiringPi](https://metacpan.org/pod/RPi%3A%3AWiringPi) that don't
necessarily fit anywhere else. It is a base class, and is not designed to be
used independently.

# METHODS

Besides the methods listed below, we also make available through inheritance
all methods provided by [RPi::SysInfo](https://metacpan.org/pod/RPi%3A%3ASysInfo). Please see that documentation for
usage details.

## gpio\_layout

Returns the GPIO layout which indicates the board revision number.

## identify($seconds)

This method wraps the [io\_led()](#io_led-tweak) and
[pwr\_led()](#pwr_led-tweak) methods.

Parameters:

    $seconds

Optional, Integer: The number of seconds to remain in "identify" state. Defaults
to `5`.

In "identify" state, the green disk I/O LED will remain on constantly, and the
red power LED will stay off for the duration.

## io\_led($tweak)

This is a helper method to better help you identify which Raspberry Pi board
you're currently working on, by allowing you to turn the green disk IO LED
on constantly.

WARNING: This method calls system command line commands using `sudo`
internally.

Parameters:

    $tweak

Optional: Sending in a true value (eg `1`) will turn the green disk activity
LED on constantly (ie. no blinking on activity). Sending in a false value or
omitting the parameter will restore the disk activity LED back to default state.

## pwr\_led($tweak)

This is a helper method to better help you identify which Raspberry Pi board
you're currently working on, by allowing you to turn the red power LED off.

WARNING: This method calls system command line commands using `sudo`
internally.

Parameters:

    $tweak

Optional: Sending in a true value (eg: `1`) will turn the red power LED off.
Sending in a false value (or omitting the parameter) will restore the power LED
back to default state.

## label($label)

Allows you to set and retrieve a label (aka name) for your Raspberry Pi object.

Parameters:

    $label

Optional, String: Send in a string parameter to set a label/name for your Pi
object.

Return: The label/name you've previously set. If one has not been set, return
will be the empty string.

## pin\_scheme(\[$scheme\])

Returns the current pin mapping in use. Returns `0` for `wiringPi` scheme,
`1` for GPIO, and `-1` if a scheme has not yet been configured (ie. one of
the `setup*()` methods has not yet been called).

If using [RPi::Const](https://metacpan.org/pod/RPi%3A%3AConst), these map out to:

    0  => RPI_MODE_WPI
    1  => RPI_MODE_GPIO
    -1 => RPI_MODE_UNINIT

## pin\_to\_gpio($pin, \[$scheme\])

Dynamically converts the specified pin from the specified scheme
`RPI_MODE_WPI` (wiringPi) to the GPIO number format.

If `$scheme` is not sent in, we'll attempt to fetch the scheme currently in
use and use that.

Example:

    my $num = pin_to_gpio(6, RPI_MODE_WPI);

That will understand the pin number `6` to be the wiringPi representation, and
will return the GPIO representation.

## wpi\_to\_gpio($pin\_num)

Converts a pin number from `wiringPi` notation to GPIO notation.

Parameters:

    $pin_num

Mandatory: The `wiringPi` representation of a pin number.

## phys\_to\_gpio($pin\_num)

Converts a pin number as physically documented on the Raspberry Pi board
itself to GPIO notation, and returns it.

Parameters:

    $pin_num

Mandatory: The pin number printed on the physical Pi board.

## pwm\_range($range)

Changes the range of Pulse Width Modulation (PWM). The default is `0` through
`1023`.

Parameters:

    $range

Mandatory: An integer specifying the high-end of the range. The range always
starts at `0`. Eg: if `$range` is `359`, if you incremented PWM by `1`
every second, you'd rotate a step motor one complete rotation in exactly one
minute.

## pwm\_mode($mode)

Each PWM channel can run in either Balanced or Mark-Space mode. In Balanced
mode, the hardware sends a combination of clock pulses that results in an
overall DATA pulses per RANGE pulses. In Mark-Space mode, the hardware sets the
output HIGH for DATA clock pulses wide, followed by LOW for RANGE-DATA clock
pulses.

Raspberry Pi's default mode is balanced mode.

Parameters:

    $mode

Mandatory, Integer: `0` for Mark-Space mode, or `1` for Balanced mode.
Note: If using [RPi::Const](https://metacpan.org/pod/RPi%3A%3AConst), you can use `PWM_MODE_MS` or
`PWM_MODE_BAL`.

## pwm\_clock($divisor)

The PWM clock can be set to control the PWM pulse widths. The PWM clock is
derived from a 19.2MHz clock. You can set any divider.

For example, say you wanted to drive a DC motor with PWM at about 1kHz, and
control the speed in 1/1024 increments from 0/1023 (stopped) through to
1023/1023 (full on). In that case you might set the clock divider to be 16, and
the RANGE to 1023. The pulse repetition frequency will be
1.2MHz/1024 = 1171.875Hz.

Parameters:

    $divisor

Mandatory, Integer: An unsigned integer to set the pulse width to.

## registered\_pins()

Returns an array reference where each element is the GPIO pin number of each
currently registerd pin.

## register\_pin($pin\_obj, $comment)

Registers a pin within the system for error checking, and proper resetting of
the pins in use when required.

Parameters:

    $pin_obj

Mandatory: An object instance of [RPi::Pin](https://metacpan.org/pod/RPi%3A%3APin) class.

    $comment

Optional, String: A descriptive string to help identify the pin's purpose.

## unregister\_pin($pin\_obj)

Removes an already registered pin from the registry. This method shouldn't be
used in the normal course of operation, but is available for convenience
anyhow.

Parameters:

    $pin_obj

Mandatory: An object instance of [RPi::Pin](https://metacpan.org/pod/RPi%3A%3APin) class.

## unregister\_object

Removes an object from the shared memory data store.

**NOTE**: This should only be used for testing purposes. It's simply a way to
remove objects from the register while bypassing the entire `cleanup()`
routine.

## cleanup

Resets all registered pins back to default settings as they were before your
program started. It also stops and cleans up any active interrupt handlers and
worker threads.

**Note**: It's important that this method be called in each application.

# ENVIRONMENT VARIABLES

There are certain environment variables available to aid in testing on
non-Raspberry Pi boards.

## NO\_BOARD

Set to true, will bypass the `wiringPi` board checks. False will re-enable
them.

## RPI\_BOARD

Useful only for unit testing. Tells us that we're on Pi hardware.

# AUTHOR

Steve Bertrand, <steveb@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2016-2026 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
