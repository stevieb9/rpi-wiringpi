package Main;

use lib '.';
use parent 'One';

sub new {
    return bless {}, shift;
}

1;
