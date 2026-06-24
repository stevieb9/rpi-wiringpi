#!/usr/bin/env bash
#
# test_board_2 - run the board-2 hardware test suite, in order.
#
# Board 2 (analog loop-back + servo) is exercised by these six files. Exporting
# RPI_BOARD_2=1 auto-enables every env gate they need (see the BEGIN block at
# the top of each file), so you don't have to set RPI_ADC / RPI_I2C / RPI_SUDO /
# ... by hand. The sudo-requiring files (109/140/325) re-exec themselves under
# sudo, so passwordless sudo must be configured.
#
# Serial only: the suite shares physical pins and one shared-memory segment, so
# it must never run under prove's -j parallelism.
#
# Usage:  t/scripts/test_board_2 [extra prove args, e.g. -v]

set -euo pipefail

# Run from the repository root so each test's `use lib 't/'` and the blib/ tree
# resolve regardless of where this script was invoked from.
cd "$(dirname "$0")/../.."

tests=(
    t/300-pwm_hw_mods.t
    t/305-pwm_i2c_adc.t
    t/310-dac.t
    t/325-servo.t
    t/335-shift_reg_adc.t
    t/345-dpot.t
)

RPI_BOARD_2=1 exec prove -Iblib/lib -Ilib "$@" "${tests[@]}"
