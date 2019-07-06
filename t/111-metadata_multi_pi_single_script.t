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

my $pi_a = $mod->new(label => 't/111-metadata_multi_pi_single_script.t: pi_A');

is keys %{ $pi_a->metadata->{objects} }, 1, "only one object in meta";

is ref $pi_a->metadata->{objects}{$pi_a->uuid}, 'HASH', "...and is a hashref";
is $pi_a->metadata->{objects}{$pi_a->uuid}{proc}, $$, "object A proc is proper";
is
    $pi_a->metadata->{objects}{$pi_a->uuid}{label},
    't/111-metadata_multi_pi_single_script.t: pi_A',
    "object A label is correct";

my $pi_b = $mod->new(label => 't/111-metadata_multi_pi_single_script.t: pi_B');

is keys %{ $pi_b->metadata->{objects} }, 2, "two objects now in registry";

is ref $pi_b->metadata->{objects}{$pi_b->uuid}, 'HASH', "...and is a hashref";
is $pi_b->metadata->{objects}{$pi_b->uuid}{proc}, $$, "object B proc is proper";
is
    $pi_b->metadata->{objects}{$pi_b->uuid}{label},
    't/111-metadata_multi_pi_single_script.t: pi_B',
    "object B label is correct";

$pi_b->dump_metadata;


$pi_a->cleanup();

is keys %{ $pi_b->metadata->{objects} }, 1, "back down to 1 object after pi_a cleanup";
is $pi_a->metadata->{objects}{$pi_a->uuid}, undef, "...pi_a has definitely been removed";
is $pi_b->metadata->{objects}{$pi_b->uuid}{proc}, $$, "...pi_B has the proper uuid still";

$pi_b->cleanup();

is keys %{ $pi_b->metadata->{objects} }, 0, "no more objects stored after pi_b cleanup";
is $pi_a->metadata->{objects}{$pi_a->uuid}, undef, "...pi_a has definitely been removed";
is $pi_b->metadata->{objects}{$pi_b->uuid}, undef, "...pi_b has definitely been removed";

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();

