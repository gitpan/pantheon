package Vulcan::Cruft;

=head1 NAME

Vulcan::Cruft - Keep directories clean of cruft.

=cut
use strict;
use warnings;

use Carp;
use File::Spec;
use File::Basename;
use Time::HiRes qw( time );

use constant KILO => 1024;
use constant BYTE => qw( B K M G T P E Z Y );
use constant TIME => qw( S 1 M 60 H 3600 D 86400 W 604800 );

=head1 SYNOPSIS

 use Vulcan::Cruft;

 my $cruft = Vulcan::Cruft->new( @logdir );

 unlink $cruft->cruft
 ( 
    count => 20,
    regex => qr/^foobar/,
    size => '100MB',
    age => '10days',
 );
 
=cut
sub new
{
    my ( $class, @path ) = shift;

    for my $path ( @_ )
    {
        $path = readlink $path if -l $path;
        push @path, $path if -d $path;
    }

    bless \@path, ref $class || $class;
}

=head1 METHODS

=head3 cruft( %param )

Purge files according to %param. Returns a list of 'cruft'.

 regex: pattern of file name.
 count: number of files to keep.
 size: total file size.
 age: age of file.
 remove: remove cruft.

=cut
sub cruft
{
    my $self = shift;
    my ( %param, %stat, @file, @cruft ) = @_;
    my ( $count, $regex ) = @param{ qw( count regex ) };
    my $size = $self->convert( size => $param{size} );
    my $age = $self->convert( time => $param{age} );

    for my $path ( @$self )
    {
        my ( $now, $sum ) = ( time, 0 );

        for my $file ( glob File::Spec->join( $path, '*' ) )
        {
            next unless -f $file;
            next if $regex && File::Basename::basename( $file ) !~ $regex;

            my ( $size, $ctime ) = ( stat $file )[7,10];
            if ( $age && $now > $ctime + $age ) { push @cruft, $file }
            else { $stat{$file} = [ $size, $ctime, $file ] }
        }

        for my $file ( sort { $stat{$b}[1] <=> $stat{$a}[1] } keys %stat )
        {
            $sum += $stat{$file}[0];
            if ( $size && $sum > $size ) { push @cruft, $file }
            else { unshift @file, $file }
        }

        push @cruft, splice @file, $count, $#file if $count && @file > $count;
    }

    unlink @cruft if $param{remove};
    return wantarray ? @cruft : \@cruft;
}

=head3 convert( $type, $expr )

Convert an $expr of $type to a number of base units. $type can be

I<time>: base unit 1 second, units can be

 s[econd] m[inutea h[our] d[ay] w[eek]

I<size>: base unit 1 byte, units can be B K M G T P E Z Y

An expression may consist of multiple units, e.g.

 '2h,3m,20s' or '2MB 10K'

=cut
sub convert
{
    my ( $class, $type, $expr ) = splice @_;
    return undef unless defined $expr;

    my @token = split /(\D+)/, $expr;
    return undef if $token[0] !~ /\d/;

    my ( $sum, %unit ) = 0;

    if ( $type eq 'time' )
    {
        push @token, 'S' if @token % 2;
        %unit = (TIME);
    }
    else
    {
        push @token, 'B' if @token % 2;
        %unit = map { (BYTE)[$_] => KILO ** $_ } 0 .. (BYTE) - 1;
    }

    while ( @token )
    {
        my ( $num, $unit ) = splice @token, 0, 2;
        $sum += $num * $unit if $unit = $unit{ uc substr $unit, 0, 1 };
    }
    return $sum;
}

1;
