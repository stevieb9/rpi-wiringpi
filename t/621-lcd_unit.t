# TESTDOC: RPi::LCD unit (HW-free)
use strict;
use warnings;
use Test::More;

use RPi::LCD;

# Mirror of RPi::LCD's HW-free tests (its t/05-unit.t), run here against the
# INSTALLED module. init()'s required-key checks and the _fd/alias behaviour are
# pure Perl; we bless a bare object (never new(), which calls wiringPi setup) and
# mock the inherited lcd_init() for init()'s one wiringPi call. The module has no
# DESTROY, so a bare object is safe to drop. t/620-lcd.t drives the real LCD on
# board-5.

my $mod = 'RPi::LCD';

my @required = qw(rows cols bits rs strb d0 d1 d2 d3 d4 d5 d6 d7);

sub full_params { return map { $_ => 1 } @required }

# --- init(): each required key, when missing, dies before lcd_init ---
for my $missing (@required){
    my %p = full_params();
    delete $p{$missing};
    my $o = bless {}, $mod;
    eval { $o->init(%p) };
    like $@, qr/'$missing' is a required param/, "init(): missing '$missing' dies";
}

# --- valid init(): with lcd_init mocked, stores and returns the fd ---
{
    no warnings qw(redefine once);
    local *RPi::LCD::lcd_init = sub { 42 };
    my $o = bless {}, $mod;
    is $o->init(full_params()), 42, 'init(): returns the fd from lcd_init()';
    is $o->_fd, 42, '  ...and stores it via _fd()';
}

# --- _fd(): -1 confesses, otherwise round-trips ---
{
    my $o = bless {}, $mod;
    eval { $o->_fd(-1) };
    like $@, qr/Maximum number of LCDs/, '_fd(-1): confesses at the 8-LCD limit';

    is $o->_fd(7), 7, '_fd(7): sets and returns';
    is $o->_fd, 7, '_fd(): getter returns the stored value';
}

# --- alias identity ---
is \&RPi::LCD::print, \&RPi::LCD::puts, 'print() is a true alias of puts()';
is \&RPi::LCD::print_char, \&RPi::LCD::put_char, 'print_char() is a true alias of put_char()';

done_testing();
