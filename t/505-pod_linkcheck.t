use warnings;
use strict;
 
use Test::More;
 
eval "use Test::Pod::LinkCheck";
if ($@) {
    plan skip_all => 'Test::Pod::LinkCheck required for testing POD links';
} 

unless ( $ENV{RPI_RELEASE_TESTING} ) {
    plan( skip_all => "Author test: RPI_RELEASE_TESTING not set" );
}

Test::Pod::LinkCheck->new->all_pod_ok;
