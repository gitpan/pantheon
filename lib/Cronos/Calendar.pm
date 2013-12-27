package Cronos::Calendar;

use strict;
use warnings;

use constant WEEK => 'Su Mo Tu We Th Fr Sa';
use constant MONTH => qw( _ January February March April May
    June July August September October November December );

our ( $HEADER, @HEADER );

format MONTH_HEADER =
@|||||||||||||||||||||
$HEADER
@|||||||||||||||||||||
WEEK
.

format QUARTER_HEADER =
@|||||||||||||||||||||@|||||||||||||||||||||@|||||||||||||||||||||
@HEADER 
@|||||||||||||||||||||@|||||||||||||||||||||@|||||||||||||||||||||
WEEK, WEEK, WEEK
.

format YEAR_HEADER =
@|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
$HEADER

.
=head1 SYNOPSIS

 use Cronos::Calendar;
 
 Cronos::Calendar->new( $year, %block )->print( $month );

=cut
sub new
{
    my ( $class, $year, %block ) = @_;

    while ( my ( $month, $block ) = each %block )
    {
        my $ref = $block ? ref $block : '';
        if ( $ref eq 'ARRAY' ) { $block{$month} = { map { $_ => 1 } @$block } }
        elsif ( $ref ne 'HASH' ) { delete $block{$month} };
    }
    bless [ $year => %block ], ref $class || $class;
}

sub print
{
    my ( $self, $month ) = splice @_;
    my ( $year, %select ) = @$self;

    return $self->month( $month ) if $month;

    $HEADER = $year;
    $~ = 'YEAR_HEADER';
    write;

    map { $self->quarter( $_ ) } 1 .. 4;
    return $self;
}

sub quarter
{
    my ( $self, $index ) = splice @_;
    my ( $year, %block ) = @$self;
    my %month = map { $_ => Cronos::Calendar::Month->new( $year, $_ ) }
    my @month = map { $_ + ( $index - 1 ) * 3 } 1 .. 3;

    @HEADER = ( MONTH )[@month];
    $~ = 'QUARTER_HEADER';
    write;

    for my $w ( 0 .. 5 )
    {
        for my $m ( sort keys %month )
        {
            if ( my $week = $month{$m}->week( $w ) )
            {
                my $block = $block{$m} || {};
                map { printf '%3s', $block->{$_} ? '' : $_ } @$week;
                print ' ';
            }
            else
            {
                print ' ' x 22;
            }
        }
        print "\n";
    }
    return $self;
}

sub month
{
    my ( $self, $index ) = splice @_;
    my ( $year, %block ) = @$self;
    my $block = $block{$index} || {};
    my $month = Cronos::Calendar::Month->new( $year, $index );

    $HEADER = sprintf '%s %s', ( MONTH )[$index], $year;
    $~ = 'MONTH_HEADER';
    write;

    for my $w ( 0 .. 5 )
    {
        if ( my $week = $month->week( $w ) )
        {
            map { printf '%3s', $block->{$_} ? '' : $_ } @$week;
        }
        print "\n";
    }
    return $self;
}

package Cronos::Calendar::Month;

use strict;
use warnings;

use Carp;
use DateTime;

sub new
{
    my ( $class, $year, $month ) = splice @_;
    my $offset = DateTime->new( year => $year, month => $month, day => 1 )
        ->dow % 7;

    my @count = ( 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
    my $count = $month == 2 ? $year % 100 && ! ( $year % 4 && $year % 400 )
        ? 29 : 28 : $count[$month];

    bless [ $offset, $count ], ref $class || $class;
}

sub week
{
    my ( $self, $index ) = @_;
    my ( $offset, $count ) = @$self;
    my ( $day, @sun, @day ) = ( $offset <= 0 ? 1 : 8 ) - $offset;

    while ( $day <= $count )
    {
        push @sun, $day;
        $day += 7;
    }

    unshift @sun, '' if $sun[0] != 1;

    if ( $index )
    {
        return unless my $day = $sun[$index];
        map { push @day, $day <= $count ? $day ++ : '' } 0 .. 6;
    }
    else
    {
        map { $day[$_] = '' } 0 .. $offset - 1;
        map { $day[$_] = $_ - $offset + 1 } $offset .. 6;
    }
    return wantarray ? @day : \@day;
}

1;
