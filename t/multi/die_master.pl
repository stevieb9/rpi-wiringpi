use strict;
use warnings;
use 5.010;

use lib 't/';

use RPiTest;
use Data::Dumper;
use RPi::WiringPi;
use Test::More;

rpi_running_test('t/113-multi_die.t');

my $f = 'ready.multi';

my $pi = RPi::WiringPi->new(label => 'multi_die');

print "*** Single pin: Local & Remote ***\n\n";

is exists($pi->metadata->{objects}{$pi->uuid}), 1, "$$ set in meta ok";
is $pi->metadata->{objects}{$pi->uuid}{proc}, $$, "UUID proc set to procID $$ in meta ok";
is keys %{ $pi->metadata->{objects} }, 2, "both procs have registered in meta";

$pi->pin(12, "112-die_master");

is exists($pi->metadata->{pins}{12}), 1, "pin 12 exists for master proc ok";
is $pi->metadata->{pins}{12}{users}{$pi->uuid}, 1, "pin 12 has local UUID as user ok";
is exists($pi->metadata->{pins}{18}), 1, "pin 18 exists for slave ok";
is $pi->metadata->{pins}{18}{users}{$pi->uuid}, undef, "pin 18 doesn't have local UUID as user ok";

is keys %{ $pi->metadata->{pins} }, 2, "three pins registered so far ok";

mywait();
unlink $f or die $!;

sleep 1;

print "*** External script: died() ***\n\n";

is exists($pi->metadata->{objects}{$pi->uuid}), 1, "$$ set in meta ok";
is $pi->metadata->{objects}{$pi->uuid}{proc}, $$, "UUID proc set to procID $$ in meta ok";
is keys %{ $pi->metadata->{objects} }, 1, "back to one object";

is exists($pi->metadata->{pins}{12}), 1, "pin 12 exists for master proc ok";
is $pi->metadata->{pins}{12}{users}{$pi->uuid}, 1, "pin 12 has local UUID as user ok";
is exists($pi->metadata->{pins}{18}), '', "pin 18 no longer exists in slave";

is keys %{ $pi->metadata->{pins} }, 1, "one pin registered after slave die()";

$pi->cleanup;

rpi_check_pin_status();
rpi_metadata_clean();

done_testing();

sub mywait {
    while (1){
        last if -e $f;
        select(undef, undef, undef, 0.2);
    }
}
