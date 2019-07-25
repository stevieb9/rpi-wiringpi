use warnings;
use strict;

use Data::Dumper;
use IPC::ShareLite;
use JSON::XS;

my $s = IPC::ShareLite->new(
    -key     => 1235,
    -create  => 1,
    -destroy => 0,
) or die "can't create share: $!";

my $p;

$s->lock;
$p = meta_fetch();
$p->{a}++;
meta_store($p);
$s->unlock;

$s->lock;
$p = meta_fetch();
$s->unlock;

print Dumper $p;


