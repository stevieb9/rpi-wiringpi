#!/usr/bin/env bash
#
# test_board_4.sh - run the board-4 hardware test suite, in order.
#
# Board 4 (I2C sensors: DS3231 RTC + on-module AT24C32 EEPROM, BMP180, SSD1306
# OLED) is exercised by these hardware files. Exporting RPI_BOARD_4=1 auto-enables
# every env gate they need (see the BEGIN block at the top of each file), so you
# don't have to set RPI_RTC / RPI_BMP / RPI_EEPROM / RPI_OLED by hand.
#
# t/520-oled_cleanup.t exercises the OLED lock-file cleanup rather than the display
# itself, but it still needs the OLED present, so it stays in this rig runner.
#
# Serial only: the suite shares physical pins and one shared-memory segment, so
# it must never run under prove's -j parallelism.
#
# Usage:  t/scripts/test_board_4.sh [extra prove args, e.g. -v]

set -euo pipefail

# Run from the repository root so each test's `use lib 't/'` and the blib/ tree
# resolve regardless of where this script was invoked from.
cd "$(dirname "$0")/../.."

tests=(
    t/530-rtc.t
    t/531-bmp.t
    t/540-eeprom_args.t
    t/541-eeprom_read_write_byte_croak.t
    t/542-eeprom_read_write_byte.t
    t/500-oled_new.t
    t/501-oled_string.t
    t/502-oled_rect.t
    t/503-oled_dim.t
    t/504-oled_splash_screen.t
    t/505-oled_invert_display.t
    t/506-oled_pixel.t
    t/507-oled_char.t
    t/508-oled_vertical_line.t
    t/509-oled_horizontal_line.t
    t/520-oled_cleanup.t
)

RPI_BOARD_4=1 exec prove -Iblib/lib -Ilib "$@" "${tests[@]}"
