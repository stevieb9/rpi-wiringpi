use strict;
use warnings;

use lib 't/';

use Data::Dumper;
use RPiTest;
use RPi::WiringPi;
use Test::More;
use feature 'say';

if (! $ENV{RPI_MULTI}){
    plan skip_all => "RPI_MULTIPLE environment variable not set\n";
}

if (! $ENV{PI_BOARD}){
    $ENV{NO_BOARD} = 1;
    plan skip_all => "Not on a Pi board\n";
}

rpi_running_test(__FILE__);

my $mod = 'RPi::WiringPi';

my $pi_a = $mod->new;

is keys %{ $pi_a->metadata->{objects} }, 1, "only one object in meta";
is $pi_a->metadata->{objects}{$pi_a->uuid}, $$, "...and it has the proper uuid";

my $pi_b = $mod->new;

$pi_b->dump_metadata;

is keys %{ $pi_a->metadata->{objects} }, 2, "two objects now in registry";
is $pi_a->metadata->{objects}{$pi_a->uuid}, $$, "...pi_A has the proper uuid";
is $pi_b->metadata->{objects}{$pi_b->uuid}, $$, "...pi_B has the proper uuid";

$pi_a->cleanup();

is keys %{ $pi_b->metadata->{objects} }, 1, "back down to 1 object after pi_a cleanup";
is $pi_a->metadata->{objects}{$pi_a->uuid}, undef, "...pi_a has definitely been removed";
is $pi_b->metadata->{objects}{$pi_b->uuid}, $$, "...pi_B has the proper uuid still";

$pi_b->cleanup();

is keys %{ $pi_b->metadata->{objects} }, 0, "no more objects stored after pi_b cleanup";
is $pi_a->metadata->{objects}{$pi_a->uuid}, undef, "...pi_a has definitely been removed";
is $pi_b->metadata->{objects}{$pi_b->uuid}, undef, "...pi_b has definitely been removed";

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();

