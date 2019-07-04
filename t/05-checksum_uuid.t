use strict;
use warnings;
use feature 'say';

use RPi::WiringPi;
use Test::More;

my $pi = RPi::WiringPi->new;
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
done_testing();

