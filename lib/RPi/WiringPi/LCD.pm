package RPi::WiringPi::LCD;

use strict;
use warnings;

our $VERSION = '0.99_03';

use parent 'WiringPi::API';
use RPi::WiringPi::Constant qw(:all);

sub new {
    return bless {}, shift;
}
sub init {
    my ($self, %params) = @_;

    my @required_args = qw(
        rows cols bits rs strb
        d0 d1 d2 d3 d4 d5 d6 d7
    );
    
    my @args;
    for (@required_args){
        if (! defined $params{$_}) {
            die "\n'$_' is a required param for Core::lcd_init()\n";
        }
        push @args, $params{$_};
    }

    my $fd = $self->lcd_init(@args);

    $self->_fd($fd);
}
sub home {
    $_[0]->lcd_home($_[0]->_fd);
}
sub clear {
    $_[0]->lcd_clear($_[0]->_fd);
}
sub display {
    my ($self, $state) = @_;
    $self->lcd_display($self->_fd, $state);
}
sub cursor {
    my ($self, $state) = @_;
    $self->lcd_cursor($self->_fd, $state);
}
sub cursor_blink {
    my ($self, $state) = @_;
    $self->lcd_cursor_blink($self->_fd, $state);
}
sub send_cmd {
    my ($self, $cmd) = @_;
    warn "\nlcdSendCommand() wiringPi function isn't documented!\n";
    $self->lcd_send_cmd($self->_fd, $cmd);
}
sub position {
    my ($self, $x, $y) = @_;
    $self->lcd_position($self->_fd, $x, $y);
}
sub char_def {
    my ($self, $index, $data) = @_;
    $self->lcd_char_def($self->_fd, $index, $data);
}
sub print_char {
    my ($self, $data) = @_;
    $self->lcd_put_char($self->_fd, $data);
}
sub print {
    my ($self, $string) = @_;
    $self->lcd_puts($self->_fd, $string);
}
sub _fd {
    my ($self, $fd) = @_;
    if (defined $fd){
        $self->{fd} = $fd;
    }
    return $self->{fd}
}
1;
__END__

=head1 NAME

RPi::WiringPi::LCD - Perl interface to Raspberry Pi LCD displays via the GPIO pins

=head1 DESCRIPTION

WARNING: Until version 1.00 has been released, the API along with functionality
may change at any time without any notice. If you happen to be testing with 
this software and find something broken, please contact me.

=head1 METHODS

=head2 new()

Returns a new C<WiringPi::API> object.

=head2 init(%args)

Initializes the LCD library, and returns an integer representing the handle
handle (file descriptor) of the device. The return is supposed to be constant,
so DON'T change it.

Parameters:

    %args = (
        rows => $num,       # number of rows. eg: 16 or 20
        cols => $num,       # number of columns. eg: 2 or 4
        bits => 4|8,        # width of the interface (4 or 8)
        rs => $pin_num,     # pin number of the LCD's RS pin
        strb => $pin_num,   # pin number of the LCD's strobe (E) pin
        d0 => $pin_num,     # pin number for LCD data pin 1
        ...
        d7 => $pin_num,     # pin number for LCD data pin 8
    );

Mandatory: All entries must have a value. If you're only using four (4) bit
width, C<d4> through C<d7> must be set to C<0>.

=head2 home()

Moves the LCD cursor to the home position (top row, leftmost column).

=head2 clear()

Clears the LCD display of all data.

=head2 display($state)

Turns the LCD display on and off.

Parameters:

    $state

Mandatory: C<0> to turn the display off, and C<1> for on.

=head2 cursor($state)

Turns the LCD cursor on and off.

Parameters:

    $state

Mandatory: C<0> to turn the cursor off, C<1> for on.

=head2 cursor_blink($state)

Parameters:

    $state

Mandatory: C<0> to stop blinking, C<1> to enable.

=head2 send_cmd($command)

Sends any arbitrary command to the LCD. (I've never tested this!).

Parameters:

    $command

Mandatory: A command to submit to the LCD.

=head2 position($x, $y)

Moves the cursor to the specified position on the LCD display.

Parameters:

    $x

Mandatory: Column position. C<0> is the left-most edge.

    $y

Mandatory: Row position. C<0> is the top row.

=head2 char_def($index, $data)

This allows you to re-define one of the 8 user-definable characters in the
display. The data array is 8 bytes which represent the character from the
top-line to the bottom line. Note that the characters are actually 5×8, so
only the lower 5 bits are used. The index is from 0 to 7 and you can
subsequently print the character defined using the lcdPutchar() call.

Parameters:

    $index

Mandatory: Index of the display character. Values are C<0-7>.

    $data

Mandatory: See above description.

=head2 print_char($char)

Writes a single ASCII character to the LCD display, at the current cursor
position.

Parameters:

    $char

Mandatory: A single ASCII character.

=head2 print($string)

Parameters:

    $string

Mandatory: A string to display.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Steve Bertrand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
