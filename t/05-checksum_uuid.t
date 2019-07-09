use strict;
use warnings;
use feature 'say';

use lib 't/';

use RPi::WiringPi;
use RPiTest;
use Test::More;

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(label => 't/05-checksum_uuid.t');

is exists $RPi::WiringPi::Util::shared_pi_info{objects}->{$pi->uuid}, 1, "shared memory has the object's uuid";
is exists $RPi::WiringPi::Util::shared_pi_info{objects}->{$pi->uuid}{proc}, 1, "shared memory has the object's proc";
is exists $RPi::WiringPi::Util::shared_pi_info{objects}->{$pi->uuid}{label}, 1, "shared memory has the object's label";

is ref $RPi::WiringPi::Util::shared_pi_info{objects}->{$pi->uuid}, 'HASH', "object is a hash ref";
is $RPi::WiringPi::Util::shared_pi_info{objects}->{$pi->uuid}{label}, 't/05-checksum_uuid.t', "object's label is correct";
is $RPi::WiringPi::Util::shared_pi_info{objects}->{$pi->uuid}{proc}, $$, "object's proc is ok";

my $c = $pi->checksum;

check_checksum($c, 'checksum');
check_checksum($pi->uuid, 'uuid');

$pi->cleanup;

is
    exists $RPi::WiringPi::Util::shared_pi_info{objects}->{$pi->uuid},
    '',
    "shared memory removed the object's uuid after cleanup";

is exists $RPi::WiringPi::Util::shared_pi_info{objects}, 1, "objects container in shared memory ok";
is keys( %{ $RPi::WiringPi::Util::shared_pi_info{objects} }), 0, "objects has no objects";

# rpi_check_pin_status();
rpi_metadata_clean();

done_testing();

sub check_checksum {
    my ($c, $text) = @_;

    is length($c), 32, "'$text' checksum length ok";

    my %valid_chars = map {$_ => 1} (0..9, 'a'..'f');

    my $u_count = 1;

    for (split //, $c){
        is exists $valid_chars{$_}, 1, "'$text' char $_ in position $u_count valid";
        $u_count++;
    }
}
