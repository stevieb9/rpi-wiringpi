use strict;
use warnings;
use feature 'say';

use IPC::Shareable;
use RPi::WiringPi;
use Test::More;

tie my %shared_pi_info, 'IPC::Shareable', {
    key => 'rpiw',
    create => 1
};

my $pi = RPi::WiringPi->new;
#use Data::Dumper;
#print Dumper \%shared_pi_info;
is exists $shared_pi_info{objects}->{$pi->uuid}, 1, "shared memory has the object's uuid";

my $c = $pi->checksum;

check_checksum($c, 'checksum');
check_checksum($pi->uuid, 'uuid');

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

$pi->cleanup;

is
    exists $shared_pi_info{objects}->{$pi->uuid},
    '',
    "shared memory removed the object's uuid after cleanup";

is exists $shared_pi_info{objects}, 1, "objects container in shared memory ok";

done_testing();

