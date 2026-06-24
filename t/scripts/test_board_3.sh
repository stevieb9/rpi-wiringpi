#!/usr/bin/env bash
#
# test_board_3 - run the board-3 hardware test suite, in order.
#
# Board 3 (I2C expanders + stepper) is exercised by these two hardware files.
# Exporting RPI_BOARD_3=1 auto-enables every env gate they need (see the BEGIN
# block at the top of each file), so you don't have to set RPI_MCP23017 /
# RPI_STEPPER by hand.
#
# t/351-stepper-seek.t is a pure-software unit test (no hardware, no RPI_* gate)
# and is deliberately not part of this rig runner -- run it any time with
# `prove t/351-stepper-seek.t`.
#
# Serial only: the suite shares physical pins and one shared-memory segment, so
# it must never run under prove's -j parallelism.
#
# Usage:  t/scripts/test_board_3 [extra prove args, e.g. -v]

set -euo pipefail

# Run from the repository root so each test's `use lib 't/'` and the blib/ tree
# resolve regardless of where this script was invoked from.
cd "$(dirname "$0")/../.."

tests=(
    t/355-mcp23017.t
    t/350-stepper.t
)

RPI_BOARD_3=1 exec prove -Iblib/lib -Ilib "$@" "${tests[@]}"
