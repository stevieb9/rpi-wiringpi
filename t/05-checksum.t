use strict;
use warnings;
use feature 'say';

use RPi::WiringPi;
use Test::More;

my $pi = RPi::WiringPi->new;

my $c = $pi->checksum;

is length($c), 32, "random checksum length ok";

my %valid_chars = map {$_ => 1} (0..9, 'a'..'f');

for (split //, $c){
    is exists $valid_chars{$_}, 1, "checksum char $_ is valid";
}

done_testing();

