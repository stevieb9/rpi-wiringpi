# TESTDOC: WiringPi::API unit (HW-free)
use strict;
use warnings;

use Test::More;
use WiringPi::API qw(spi_data phys_to_gpio wpi_to_gpio);

# Mirror of the foundational HW-free WiringPi::API unit tests (its t/91 spi_data
# + t/92 pin-map bounds), run here against the INSTALLED binding - the base
# class rpi-wiringpi depends on. Ungated (no RPiTest, no shm, no Pi). The
# dist's own suite also covers shift_reg/serial/lcd/bmp180; those aren't
# mirrored (less central to rpi-wiringpi's paths).

# --- spi_data() validation (croaks before any SPI) ---

eval { spi_data(2, [1], 1) };
like $@, qr/channel param must be 0 or 1/, "spi_data: bad channel croaks";

eval { spi_data(0, 'not_a_ref', 1) };
like $@, qr/must be an array reference/, "spi_data: non-arrayref data croaks";

eval { spi_data(0, [1, 2], 1) };
like $@, qr/must have \$len param count/, "spi_data: \@data/\$len mismatch croaks";

eval { spi_data(0, [256], 1) };
like $@, qr/out of range/, "spi_data: byte > 255 croaks";

# --- pin-map bounds guard (F5) ---

for my $fn_name (qw(phys_to_gpio wpi_to_gpio)) {
    my $fn = WiringPi::API->can($fn_name);
    is $fn->(-1),    -1, "$fn_name(-1) -> -1 (no OOB read)";
    is $fn->(64),    -1, "$fn_name(64) -> -1";
    is $fn->(undef), -1, "$fn_name(undef) -> -1";
}

done_testing();
