use strict;
use warnings;

use lib 't/';

use Data::Dumper;
use RPiTest;
use Test::More;

rpi_running_test(__FILE__);

my $pi = RPi::WiringPi->new(
    label => 't/02-meta.t',
    shm_key => 'rpit'
);

{ # store/fetch

    my $test_name = 'meta';

    $pi->meta_lock;

    my $m = $pi->meta_fetch;

    is $m->{testing}{test_name}, $test_name, "meta_fetch() has 'test name ok";
    is $m->{testing}{test_num}, '03', "meta_fetch() has 'test num ok";
    is $m->{objects}{$pi->uuid}{label}, 't/02-meta.t', "meta_fetch() has proper object info";

    $m->{testing}{test_name} = 'blah';

    $pi->meta_store($m);
    $m = $pi->meta_fetch;
    is $m->{testing}{test_name}, 'blah',  "meta_store() does the right thing";
    $m->{testing}{test_name} = $test_name;
    $pi->meta_store($m);

    $m = $pi->meta_fetch;
    is $m->{testing}{test_name}, $test_name,  "meta_store() restores ok";

    $pi->meta_unlock;
}

{ # set/get

    $pi->meta_set('set_get_test', { a => 1, b => 2, c => [ 1, 2, 3 ] });
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
}

{ # erase

    $pi->meta_set('erase', { a => 1, b => 2, c => [ 1, 2, 3 ] });
    my $data = $pi->meta_get('erase');

    is $data->{a}, 1, "set/get ok with 'a'";
    is $data->{b}, 2, "set/get ok with 'a'";
    is $data->{c}[2], 3, "set/get ok with 'c->[3]'";

    $pi->meta_erase;

    $pi->meta_lock;
    my $shm = $pi->meta_fetch;
    $pi->meta_unlock;

    is exists $shm->{storage}{erase}, 1, "meta_erase() w/o all works ok";

    $data = $pi->meta_get('erase');

    is $data->{a}, 1, "erase w/o 'all' on a ok";
    is $data->{b}, 2, "erase w/o 'all' on b ok";
    is $data->{c}[2], 3, "erase w/o 'all' on c ok";

    $pi->meta_erase(1);

    $pi->meta_lock;
    $shm = $pi->meta_fetch;
    $pi->meta_unlock;

    is exists $shm->{storage}, '', "meta_erase() w/o all works ok";

    $data = $pi->meta_get('erase');

    is $data->{a}, undef, "erase with 'all' on a ok";
    is $data->{b}, undef, "erase with 'all' on b ok";
    is $data->{c}[2], undef, "erase with 'all' on c ok";
}

$pi->cleanup;

rpi_check_pin_status();

done_testing();

