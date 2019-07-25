use warnings;
use strict;

use Benchmark qw(timethis timethese cmpthese);
use Data::Dumper;
use IPC::ShareLite;
use JSON::XS;
use Storable qw(freeze thaw);

die "need run count" if ! $ARGV[0];

my $s = IPC::ShareLite->new(
    -key     => 1234,
    -create  => 1,
    -destroy => 0,
) or die "can't create share: $!";

my $f = '/dev/shm/data';

cmpthese $ARGV[0], {
    json_file => \&json_file,
    json_share => \&json_share,
    stor_file => \&stor_file,
    stor_share => \&stor_share,
};

sub json_file {
    my $p = {a => 1, b => 'string', c => {x => 'this', y => 'that'}};
    open my $fh, '>', $f or die $!;
    print $fh encode_json($p);
    close $fh;

    {
        local $/;
        open $fh, '<', $f or die $!;
        $p = decode_json <$fh>;
        close $fh;
    }
    open $fh, '>', $f or die $!;
    print $fh encode_json($p);
    close $fh;
}
sub stor_file {
    my $p = {a => 1, b => 'string', c => {x => 'this', y => 'that'}};
    open my $fh, '>', $f or die $!;
    print $fh freeze($p);
    close $fh;

    {
        local $/;
        open $fh, '<', $f or die $!;
        $p = thaw <$fh>;
        close $fh;
    }
    open $fh, '>', $f or die $!;
    print $fh freeze($p);
    close $fh;
}
sub json_share {
    my $p = {a => 1, b => 'string', c => {x => 'this', y => 'that'}};
    $s->store(encode_json $p);
    $p = decode_json $s->fetch;
    $s->store(encode_json $p);
}
sub stor_share {
    my $p = {a => 1, b => 'string', c => {x => 'this', y => 'that'}};
    $s->store(freeze $p);
    $p = thaw $s->fetch;
    $s->store(freeze $p);
}

__END__

# perl sharelite_vs_memfile.pl 100000

Rate  stor_file  json_file stor_share json_share
    stor_file  2194/s         --       -41%       -43%       -77%
    json_file  3717/s        69%         --        -4%       -62%
    stor_share 3882/s        77%         4%         --       -60%
    json_share 9681/s       341%       160%       149%         --

