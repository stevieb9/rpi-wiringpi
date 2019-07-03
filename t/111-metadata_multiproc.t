use strict;
use warnings;

use lib 't/';

use Data::Dumper;
use RPiTest qw(check_pin_status running_test);
use RPi::WiringPi;
use Test::More;
use feature 'say';

use constant {
    MAX_PROCS => 3
};

BEGIN {

    local $SIG{__DIE__} = sub {}; # mask RPi::WiringPi's die() handler

    if (! $ENV{RPI_MULTIPLE}){
        plan skip_all => "RPI_MULTIPLE environment variable not set\n";
    }

    if (! $ENV{PI_BOARD}){
        $ENV{NO_BOARD} = 1;
        plan skip_all => "Not on a Pi board\n";
    }

    my $load_pmfork_ok = eval {
        require Parallel::ForkManager;
        Parallel::ForkManager->import;
        1;
    };

    if (! $load_pmfork_ok){
        plan skip_all => "Parallel::ForkManager couldn't be loaded...";
    }
}

running_test(__FILE__);

my $mod = 'RPi::WiringPi';

my $fm = Parallel::ForkManager->new(MAX_PROCS);

my $pi = RPi::WiringPi->new;


my @procs = qw(26 12 18);
my @pis;

for my $proc (@procs){
       
    $fm->start and next;

    $pis[$proc] = RPi::WiringPi->new;

    $pis[$proc]->pin($_);
#    is exists $pi->metadata->{pins}{26}, 1, "proc 1 has set pin 26";
#    is exists $pi->metadata->{pins}{12}, '', "proc 1 can't see pin 12";
#    is exists $pi->metadata->{pins}{18}, '', "proc 1 can't see pin 18";
   
    print Dumper $pi->registered_pins;
    $fm->finish;
}

$fm->wait_all_children;

$pi->cleanup();
$pi->clean_shared;

# check_pin_status();

done_testing();

