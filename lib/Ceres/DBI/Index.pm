package Ceres::DBI::Index;

=head1 NAME

Ceres::DBI::Index - DB interface to Ceres index

=head1 SYNOPSIS

 use Ceres::DBI::Index;

 my $db = Ceres::DBI::Index->new( '/database/file' );

=cut
use strict;
use warnings;

=head1 METHODS

See Vulcan::SQLiteDB.

=cut
use base qw( Vulcan::SQLiteDB );

=head1 DATABASE

A SQLITE db has a <ceres> table of I<four> columns:

 host : hostname
 time : collection time/flag
 key : md5 key
 md5 : current md5

=cut
our $TABLE  = 'ceres';

sub define
{
    host => 'TEXT NOT NULL PRIMARY KEY',
    key => 'TEXT NOT NULL',
    md5 => 'TEXT NOT NULL',
};

sub new
{
    my $self = shift;
    $self = $self->SUPER::new( @_, $TABLE );
    return $self;
}

=head1 METHODS

=head3 update( $host, $key, $md5 )

Update record if I<key> or I<md5> changed.

=cut
sub update
{
    my ( $self, $host, $key, $md5 ) = splice @_;

    $self->delete( $TABLE, host => [ 0, $host ], key => [ 1, $key ] );
    $self->delete( $TABLE, host => [ 1, $host ], key => [ 0, $key ] );

    my ( $record ) = $self->select( $TABLE => '*', host => [ 1, $host ] );
    $self->insert( $TABLE, $host, $key, $md5 )
        unless $record && $record->[2] eq $md5;
}

=head3 index( $host, $md5 )

Select I<key> by $host, and by failed I<md5> match if $md5 is defined.
Return last two characters of I<key>, or undef if $host does not exist.

=cut
sub index
{
    my ( $self, $host, $md5 ) = splice @_;
    my %query = ( host => [ 1, $host ] );

    $query{md5} = [ 0, $md5 ] if defined $md5;
    my ( $record ) = $self->select( $TABLE => '*', %query );
    return $record ? substr $record->[1], -2, 2 : undef;
}

1;
