# TESTDOC: RPi::BMP180 unit (HW-free)
use strict;
use warnings;

use RPi::BMP180;
use Test::More;

# Mirror of RPi::BMP180's HW-free tests (its t/05-unit.t), run here against the
# INSTALLED module. _pin_base() is pure Perl, so we bless a bare object to
# exercise its validation without new()'s wiringPi setup(); the module has no
# DESTROY, so a bare object is safe to drop. t/531-bmp.t drives the real sensor
# on board-4. (The temperature/pressure compensation + oversampling math is not
# in this dist - it lives in wiringPi's devLib bmp180.c - so it is not covered
# here; see B9.)

my $mod = 'RPi::BMP180';

{
    my $o = bless {}, $mod;

    for my $bad ('x', -1, 3.5, '12a'){
        eval { $o->_pin_base($bad) };
        like $@, qr/requires an integer/, "_pin_base('$bad'): non-integer rejected";
    }

    my $unset = bless {}, $mod;
    eval { $unset->_pin_base };
    like $@, qr/has not yet been set/, '_pin_base(): unset getter rejected';

    is $o->_pin_base(200), 200, '_pin_base(200): sets and returns';
    is $o->_pin_base, 200, '_pin_base(): getter returns the set value';
    is $o->_pin_base(0), 0, '_pin_base(0): zero is a valid pin base';
}

{
    my $ok = eval { $mod->new; 1 };
    ok ! $ok, 'new() with no pin_base dies before wiringPi setup';
}

done_testing();
