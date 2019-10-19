use warnings;
use strict;

use lib 't/';

use Data::Dumper;
use RPi::WiringPi;
use RPiTest;
use Test::More;

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(
    label   => '120-metadata_set_get.t',
    shm_key => 'rpit'
);

$pi->meta_set('set_get_test', {a => 1, b => 2, c => [1, 2, 3]});
my $data = $pi->meta_get('set_get_test');

is $data->{a}, 1, "set/get ok with 'a'";
is $data->{b}, 2, "set/get ok with 'a'";
is $data->{c}[2], 3, "set/get ok with 'c->[3]'";

my $shm;

$pi->meta_lock;
$shm = $pi->meta_fetch;
$pi->meta_unlock;

is exists $shm->{storage}, 1, "storage key in shm exists ok";
is exists $shm->{storage}{set_get_test}, 1, "the set() key exists too";

$pi->meta_delete('set_get_test');

$pi->meta_lock;
$shm = $pi->meta_fetch;
$pi->meta_unlock;

is exists $shm->{storage}{set_get_test}, '', "meta_delete() removes the data";

$pi->cleanup;

done_testing();

