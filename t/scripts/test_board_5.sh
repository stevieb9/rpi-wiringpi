#!/usr/bin/env bash
#
# test_board_5.sh - run the board-5 hardware test suite, in order.
#
# Board 5 (5V logic: LCD / Arduino / UART) is exercised by these three hardware
# files. Exporting RPI_BOARD_5=1 auto-enables every env gate they need (see the
# BEGIN block at the top of each file), so you don't have to set RPI_ARDUINO /
# RPI_SERIAL / RPI_LCD by hand.
#
# t/600-i2c_exceptions.t is board-5-gated (RPI_ARDUINO) but only tests the
# absent-device error path, not a real chip, so it is deliberately not part of
# this rig runner -- run it directly any time with `prove t/600-i2c_exceptions.t`.
#
# Serial only: the suite shares physical pins and one shared-memory segment, so
# it must never run under prove's -j parallelism.
#
# Usage:  t/scripts/test_board_5.sh [extra prove args, e.g. -v]

set -euo pipefail

# Run from the repository root so each test's `use lib 't/'` and the blib/ tree
# resolve regardless of where this script was invoked from.
cd "$(dirname "$0")/../.."

tests=(
    t/605-i2c.t
    t/610-serial.t
    t/620-lcd.t
)

RPI_BOARD_5=1 exec prove -Iblib/lib -Ilib "$@" "${tests[@]}"
